/// Purpose: The FluidAudio adapter: Parakeet on the Apple Neural Engine.
/// Inputs: Installed Core ML packages; PCM windows.
/// Returns: Routes, prepared sessions and transcription events, through the
/// `LocalAsrEngine` protocol.
/// Side effects: Starts a long-lived worker isolate that loads the bridge and
/// owns every loaded model.
/// Notes: The same shape as the other adapters (decision D16). The bridge —
/// FluidAudio behind five C functions — is prebuilt (D21) and exists on macOS
/// and iOS only; the registry adds this engine there alone. Core ML does not
/// say where each operation ran, so the placement is `mixed` (configured for
/// the CPU and the Neural Engine), never "all on the Neural Engine". The
/// bridge has no abort, so a cancel waits for the window, like sherpa-onnx's.
/// See `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:local_asr_apple/local_asr_apple.dart';
import 'package:local_asr_whisper/local_asr_whisper.dart'
    show ParakeetToken, WhisperSegment, sentences;

import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import '../services/local_asr_engine.dart';
import '../services/local_model_templates.dart';
import '../services/pcm_window_cutter.dart';
import '../services/tested_here.dart';

/// The FluidAudio engine.
class FluidAudioEngine implements LocalAsrEngine {
  /// Purpose: Create the engine.
  /// Inputs: Optional [testedHere], for tests.
  /// Returns: A new engine; the worker starts on first use.
  /// Side effects: None.
  /// Notes: None.
  FluidAudioEngine({bool Function(EngineRoute route)? testedHere})
    : _testedHere = testedHere ?? isTestedHere;

  final bool Function(EngineRoute) _testedHere;

  @override
  String get adapterId => fluidAudioAdapterId;

  _Worker? _worker;
  String? _version;
  var _probed = false;
  final _sessions = <String, int>{};
  final _running = <String, Future<void>>{};
  final _cancelled = <String>{};

  /// Purpose: Start the worker and learn whether the bridge loads.
  /// Inputs: None.
  /// Returns: The bridge's version, or null when this build has none.
  /// Side effects: Spawns the worker isolate once.
  /// Notes: A bridge that does not load is reported, not thrown.
  Future<String?> runtime() async {
    if (_probed) return _version;
    final worker = _worker ??= await _Worker.spawn();
    final answer = await worker.call(const _Info());
    _probed = true;
    return _version =
        answer is String && answer.isNotEmpty && !answer.startsWith(_failure)
        ? answer
        : null;
  }

  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async {
    final version = await runtime();
    return [
      for (final manifest in manifests)
        if (manifest.adapterId == adapterId)
          _withTested(
            EngineRoute(
              adapterId: adapterId,
              modelId: manifest.modelId,
              artifactId: manifest.artifactId,
              device: ComputeDevice.npu,
              backend: 'ane',
              evidence: EvidenceLevel.community,
              available: version != null,
              unavailableReason: version == null
                  ? 'The Neural Engine bridge is not built for this device.'
                  : null,
              segmentTimestamps: Capability.supported,
              wordTimestamps: Capability.unknown,
              memoryBytes: manifest.minimumRamBytes,
              memorySource: manifest.ramEstimateSource,
              smokeKey: SmokeTestKey(
                adapterVersion: version ?? '',
                modelHash: manifest.files.isEmpty
                    ? ''
                    : manifest.files
                          .map((f) => f.sha256.substring(0, 8))
                          .join(),
                osVersion: Platform.operatingSystemVersion,
                driverVersion: '',
                deviceId: currentDeviceClass(),
                precision: manifest.quantization,
              ).encode(),
            ),
          ),
    ];
  }

  /// Purpose: Set a route's tested-here flag from the table.
  /// Inputs: [route].
  /// Returns: The route, flagged.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  EngineRoute _withTested(EngineRoute route) => _testedHere(route)
      ? EngineRoute(
          adapterId: route.adapterId,
          modelId: route.modelId,
          artifactId: route.artifactId,
          device: route.device,
          backend: route.backend,
          evidence: route.evidence,
          testedHere: true,
          smokeKey: route.smokeKey,
          available: route.available,
          unavailableReason: route.unavailableReason,
          segmentTimestamps: route.segmentTimestamps,
          wordTimestamps: route.wordTimestamps,
          memoryBytes: route.memoryBytes,
          memorySource: route.memorySource,
          maxWindowSeconds: route.maxWindowSeconds,
        )
      : route;

  @override
  Future<PreparedSession> prepare(PrepareRequest request) async {
    if (await runtime() == null) {
      throw const LocalAsrException(
        LocalAsrErrorCode.backendNotBuilt,
        'The Neural Engine bridge is not built for this device.',
      );
    }
    final folder = request.artifactDir;
    if (!Directory('${folder.path}/Encoder.mlmodelc').existsSync()) {
      throw const LocalAsrException(
        LocalAsrErrorCode.modelMissing,
        'The Core ML files are not on this device.',
      );
    }
    final watch = Stopwatch()..start();
    final id = await _worker!.call(_Load(folder.path));
    watch.stop();
    if (id is! int) {
      throw LocalAsrException(
        LocalAsrErrorCode.modelCorrupt,
        'The model did not load: $id',
      );
    }
    final sessionId = 'ane-$id';
    _sessions[sessionId] = id;
    return PreparedSession(
      sessionId: sessionId,
      artifactRevision: request.manifest.revision,
      requestedDevice: request.route.device,
      placement: PlacementKind.mixed,
      prepareTime: watch.elapsed,
    );
  }

  @override
  Stream<AsrEvent> transcribe(TranscribeRequest request) async* {
    final session = _sessions[request.sessionId];
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

    if (session == null) {
      yield event(
        AsrEventType.error,
        error: const LocalAsrException(
          LocalAsrErrorCode.modelMissing,
          'No model is loaded for this session.',
        ),
      );
      return;
    }

    final done = Completer<void>();
    _running[request.jobId] = done.future;
    yield event(AsrEventType.started);
    try {
      final result = await _worker!.call(
        _Transcribe(session, request.pcmWindow.path),
      );
      if (_cancelled.remove(request.jobId)) {
        yield event(AsrEventType.cancelled);
        return;
      }
      if (result is String) {
        yield event(
          AsrEventType.error,
          error: LocalAsrException(
            LocalAsrErrorCode.deviceUnavailable,
            result.startsWith(_failure)
                ? result.substring(_failure.length)
                : result,
          ),
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
      yield event(AsrEventType.completed, placement: PlacementKind.mixed);
    } finally {
      _running.remove(request.jobId);
      done.complete();
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    final running = _running[jobId];
    if (running == null) return;
    // The bridge cannot stop a window midway: the window finishes, and its
    // result is discarded.
    _cancelled.add(jobId);
    await running;
  }

  @override
  Future<void> release(String sessionId) async {
    final id = _sessions.remove(sessionId);
    if (id == null) return;
    await _worker?.call(_Release(id));
  }

  /// Purpose: Stop the worker.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees every loaded model and kills the isolate.
  /// Notes: For tests; the app keeps its engine for its whole life.
  Future<void> dispose() async {
    for (final id in _sessions.keys.toList()) {
      await release(id);
    }
    _worker?.close();
    _worker = null;
    _probed = false;
    _version = null;
  }
}

/// Purpose: Turn the bridge's result into sentence segments.
/// Inputs: The [result]'s text and timed tokens, and the window's [seconds].
/// Returns: Sentences cut from the token times, or one segment spanning the
/// window when the bridge gave no times.
/// Side effects: None.
/// Notes: FluidAudio's tokens are Parakeet's own SentencePiece pieces, so the
/// same grouping as whisper.cpp's Parakeet applies.
List<WhisperSegment> segmentsFrom(
  ({String text, List<AppleToken> tokens}) result,
  double seconds,
) {
  if (result.tokens.isEmpty) {
    final text = result.text.trim();
    return text.isEmpty ? const [] : [WhisperSegment(0, seconds, text)];
  }
  return sentences([
    for (final token in result.tokens)
      ParakeetToken(token.piece, token.start, token.end),
  ]);
}

/// How the worker marks a failed answer.
const _failure = '\u0000error:';

// ── The worker isolate ──

/// A request to the worker.
sealed class _Request {
  const _Request();
}

class _Info extends _Request {
  const _Info();
}

class _Load extends _Request {
  const _Load(this.folder);
  final String folder;
}

class _Transcribe extends _Request {
  const _Transcribe(this.session, this.wavPath);
  final int session;
  final String wavPath;
}

class _Release extends _Request {
  const _Release(this.session);
  final int session;
}

/// The main isolate's end of the worker.
class _Worker {
  _Worker._(this._isolate, this._send, this._receive) {
    _receive.listen((message) {
      final (id, result) = message as (int, Object?);
      _pending.remove(id)?.complete(result);
    });
  }

  final Isolate _isolate;
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
    final isolate = await Isolate.spawn(_workerMain, (
      receive.sendPort,
      replies.sendPort,
    ), debugName: 'fluidaudio');
    final send = await handshake.future;
    receive.close();
    return _Worker._(isolate, send, replies);
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

  /// Purpose: Kill the worker.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Kills the isolate; closes the port.
  /// Notes: None.
  void close() {
    _isolate.kill();
    _receive.close();
  }
}

/// Purpose: The worker isolate's entry point.
/// Inputs: The handshake port and the reply port.
/// Returns: None.
/// Side effects: Loads the bridge; owns every model.
/// Notes: Internal helper used within this file only. Every request is
/// answered with a value, never with an exception crossing the isolate
/// boundary; requests are handled one at a time.
void _workerMain((SendPort, SendPort) ports) {
  final (handshake, replies) = ports;
  final requests = ReceivePort();
  handshake.send(requests.sendPort);
  final models = <int, AppleParakeetModel>{};
  var next = 0;

  Future<void> handle(Object? message) async {
    final (id, request) = message as (int, _Request);
    Object? answer;
    try {
      answer = switch (request) {
        _Info() => AppleAsrLibrary.version() ?? '',
        _Load(:final folder) => () {
          final key = next++;
          models[key] = AppleParakeetModel.load(folder);
          return key;
        }(),
        _Transcribe(:final session, :final wavPath) => await () async {
          final model = models[session];
          if (model == null) return '${_failure}No such session.';
          final window = await readPcmWindow(File(wavPath));
          final samples = await window.readSamples();
          return segmentsFrom(
            model.transcribe(samples),
            samples.length / 16000,
          );
        }(),
        _Release(:final session) => () {
          models.remove(session)?.release();
          return null;
        }(),
      };
    } catch (error) {
      answer = '$_failure$error';
    }
    replies.send((id, answer));
  }

  // One request at a time, as in the other adapters.
  var queue = Future<void>.value();
  requests.listen((message) {
    queue = queue.then((_) => handle(message));
  });
}
