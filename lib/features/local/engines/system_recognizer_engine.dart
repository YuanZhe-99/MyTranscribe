/// Purpose: The operating system's on-device recogniser, as the fallback the
/// user may choose (L6 of the local-models plan; Apple only).
/// Inputs: PCM windows.
/// Returns: One route — for no particular model — and transcription events,
/// through the `LocalAsrEngine` protocol.
/// Side effects: Starts a worker isolate that calls the prebuilt bridge.
/// Notes: `SFSpeechRecognizer` with on-device recognition required, so audio
/// never goes to Apple's servers (decision D15). It is never picked on its
/// own: the router offers its route only as the fallback the user's policy
/// names. Permission to recognise speech is asked the first time it runs,
/// which is only after the user chose it. Registered on iOS and macOS only.
/// See `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:local_asr_apple/local_asr_apple.dart';
import 'package:local_asr_whisper/local_asr_whisper.dart' show WhisperSegment;

import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import '../services/engine_router.dart';
import '../services/local_asr_engine.dart';
import '../services/pcm_window_cutter.dart';
import 'fluid_audio_engine.dart' show segmentsFrom;

/// The longest window the recogniser is given, in seconds: Apple documents
/// no limit for on-device recognition, and a minute keeps each call short.
const systemRecognizerMaxWindowSeconds = 60;

/// The system recogniser engine.
class SystemRecognizerEngine implements LocalAsrEngine {
  /// Purpose: Create the engine.
  /// Inputs: None.
  /// Returns: A new engine; the worker starts on first use.
  /// Side effects: None.
  /// Notes: None.
  SystemRecognizerEngine();

  @override
  String get adapterId => systemRecognizerAdapterId;

  _Worker? _worker;
  bool? _available;
  final _running = <String, Future<void>>{};
  final _cancelled = <String>{};

  /// Purpose: Learn whether the device's own language has an on-device
  /// recogniser.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: Spawns the worker isolate once.
  /// Notes: Asks for no permission.
  Future<bool> runtime() async {
    final known = _available;
    if (known != null) return known;
    final worker = _worker ??= await _Worker.spawn();
    return _available = await worker.call(const _Info()) == true;
  }

  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async {
    final available = await runtime();
    return [
      EngineRoute(
        adapterId: adapterId,
        modelId: systemRecognizerManifest.modelId,
        artifactId: systemRecognizerManifest.artifactId,
        device: ComputeDevice.cpu,
        backend: 'speech',
        evidence: EvidenceLevel.official,
        available: available,
        unavailableReason: available
            ? null
            : 'This device has no on-device recogniser for its language.',
        segmentTimestamps: Capability.supported,
        wordTimestamps: Capability.supported,
        maxWindowSeconds: systemRecognizerMaxWindowSeconds,
        smokeKey: SmokeTestKey(
          adapterVersion: 'SFSpeechRecognizer',
          modelHash: '',
          osVersion: Platform.operatingSystemVersion,
          driverVersion: '',
          deviceId: 'os',
          precision: '',
        ).encode(),
      ),
    ];
  }

  @override
  Future<PreparedSession> prepare(PrepareRequest request) async {
    if (!await runtime()) {
      throw const LocalAsrException(
        LocalAsrErrorCode.backendNotBuilt,
        'This device has no on-device recogniser for its language.',
      );
    }
    return PreparedSession(
      sessionId: 'system',
      artifactRevision: systemRecognizerManifest.revision,
      requestedDevice: request.route.device,
      placement: PlacementKind.unknown,
      prepareTime: Duration.zero,
    );
  }

  @override
  Stream<AsrEvent> transcribe(TranscribeRequest request) async* {
    var sequence = 0;
    AsrEvent event(
      AsrEventType type, {
      AsrSegment? segment,
      LocalAsrException? error,
      PlacementKind? placement,
    }) => AsrEvent(
      jobId: request.jobId,
      sequence: sequence++,
      type: type,
      segment: segment,
      error: error,
      placement: placement,
      hasRealTimestamps: type == AsrEventType.completed,
    );

    final done = Completer<void>();
    _running[request.jobId] = done.future;
    yield event(AsrEventType.started);
    try {
      final result = await _worker!.call(
        _Transcribe(
          request.pcmWindow.path,
          request.languages.isEmpty ? null : request.languages.first,
        ),
      );
      if (_cancelled.remove(request.jobId)) {
        yield event(AsrEventType.cancelled);
        return;
      }
      if (result is String) {
        yield event(
          AsrEventType.error,
          error: LocalAsrException(LocalAsrErrorCode.deviceUnavailable, result),
        );
        return;
      }
      for (final segment in result as List<WhisperSegment>) {
        yield event(
          AsrEventType.segment,
          segment: AsrSegment(
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            text: segment.text,
          ),
        );
      }
      // The recogniser says nothing about where it ran.
      yield event(AsrEventType.completed, placement: PlacementKind.unknown);
    } finally {
      _running.remove(request.jobId);
      done.complete();
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    final running = _running[jobId];
    if (running == null) return;
    _cancelled.add(jobId);
    await running;
  }

  @override
  Future<void> release(String sessionId) async {}
}

// ── The worker isolate ──

/// A request to the worker.
sealed class _Request {
  const _Request();
}

class _Info extends _Request {
  const _Info();
}

class _Transcribe extends _Request {
  const _Transcribe(this.wavPath, this.language);
  final String wavPath;
  final String? language;
}

/// The main isolate's end of the worker.
class _Worker {
  _Worker._(this._send, this._receive) {
    _receive.listen((message) {
      final (id, result) = message as (int, Object?);
      _pending.remove(id)?.complete(result);
    });
  }

  final SendPort _send;
  final ReceivePort _receive;
  final _pending = <int, Completer<Object?>>{};
  var _next = 0;

  /// Purpose: Start the worker.
  /// Inputs: None.
  /// Returns: A connected [_Worker].
  /// Side effects: Spawns an isolate.
  /// Notes: None.
  static Future<_Worker> spawn() async {
    final receive = ReceivePort();
    final handshake = Completer<SendPort>();
    final replies = ReceivePort();
    receive.listen((message) {
      if (message is SendPort && !handshake.isCompleted) {
        handshake.complete(message);
      }
    });
    await Isolate.spawn(_workerMain, (
      receive.sendPort,
      replies.sendPort,
    ), debugName: 'system-recogniser');
    final send = await handshake.future;
    receive.close();
    return _Worker._(send, replies);
  }

  /// Purpose: Send a request and wait for its answer.
  /// Inputs: [request].
  /// Returns: Whatever the worker answered.
  /// Side effects: None beyond the worker's.
  /// Notes: Requests run one after another on the worker.
  Future<Object?> call(_Request request) {
    final id = _next++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _send.send((id, request));
    return completer.future;
  }
}

/// Purpose: The worker isolate's entry point.
/// Inputs: The handshake port and the reply port.
/// Returns: None.
/// Side effects: Calls the bridge.
/// Notes: Internal helper used within this file only. A failure is answered
/// as a string; requests are handled one at a time.
void _workerMain((SendPort, SendPort) ports) {
  final (handshake, replies) = ports;
  final requests = ReceivePort();
  handshake.send(requests.sendPort);

  Future<void> handle(Object? message) async {
    final (id, request) = message as (int, _Request);
    Object? answer;
    try {
      answer = switch (request) {
        _Info() => AppleSpeech.available(),
        _Transcribe(:final wavPath, :final language) => await () async {
          final window = await readPcmWindow(File(wavPath));
          final samples = await window.readSamples();
          return segmentsFrom(
            AppleSpeech.transcribe(samples, language: language),
            samples.length / 16000,
          );
        }(),
      };
    } catch (error) {
      answer = '$error';
    }
    replies.send((id, answer));
  }

  var queue = Future<void>.value();
  requests.listen((message) {
    queue = queue.then((_) => handle(message));
  });
}
