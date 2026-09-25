/// Purpose: The sherpa-onnx adapter: Qwen3-ASR on the CPU.
/// Inputs: Installed sherpa-onnx packages; PCM windows.
/// Returns: Routes, prepared sessions and transcription events, through the
/// `LocalAsrEngine` protocol.
/// Side effects: Starts a long-lived worker isolate that loads the native
/// library and owns every loaded model.
/// Notes: The same shape as the whisper.cpp adapter (decision D16): the
/// worker owns each model, the main isolate sends it requests. sherpa-onnx's C
/// API decodes a window in one call with no abort hook and no progress, so a
/// cancel takes effect when the window ends, and Qwen3-ASR gives no
/// timestamps: each window comes back as one segment spanning it, marked as
/// not really timed (decision D22). See `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:local_asr_sherpa/local_asr_sherpa.dart';

import '../../../shared/utils/platform_capabilities.dart';
import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import '../services/local_asr_engine.dart';
import '../services/local_model_templates.dart';
import '../services/pcm_window_cutter.dart';
import '../services/tested_here.dart';

/// Which binary set and bindings the engine runs, part of every check key.
const _bindingsVersion = 'prebuilt1';

/// The longest window Qwen3-ASR is given, in seconds.
///
/// sherpa-onnx's exported decoder takes 512 tokens, audio and text together.
/// Measured on the development machine on 2026-09-25 with the JFK clip
/// repeated: 33 seconds came back whole, 55 seconds came back as one word.
const qwenMaxWindowSeconds = 30;

/// The sherpa-onnx engine.
class SherpaOnnxEngine implements LocalAsrEngine {
  /// Purpose: Create the engine.
  /// Inputs: Optional [testedHere] and [threads], for tests.
  /// Returns: A new engine; the worker starts on first use.
  /// Side effects: None.
  /// Notes: None.
  SherpaOnnxEngine({bool Function(EngineRoute route)? testedHere, int? threads})
    : _testedHere = testedHere ?? isTestedHere,
      _threads = threads ?? localEngineThreads(Platform.numberOfProcessors);

  final bool Function(EngineRoute) _testedHere;
  final int _threads;

  @override
  String get adapterId => sherpaOnnxAdapterId;

  _Worker? _worker;
  String? _version;
  var _probed = false;
  final _sessions = <String, int>{};
  final _running = <String, Future<void>>{};
  final _cancelled = <String>{};

  /// Purpose: Start the worker and learn whether the library loads.
  /// Inputs: None.
  /// Returns: The library's version, or null when this build has none.
  /// Side effects: Spawns the worker isolate once.
  /// Notes: A library that does not load is reported, not thrown.
  Future<String?> runtime() async {
    if (_probed) return _version;
    final worker = _worker ??= await _Worker.spawn();
    final answer = await worker.call(const _Info());
    _probed = true;
    // A library that loads but does not match its bindings answers with a
    // failure, and is treated as not built.
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
              device: ComputeDevice.cpu,
              backend: 'cpu',
              evidence: cpuEvidence,
              available: version != null,
              unavailableReason: version == null
                  ? 'sherpa-onnx is not built for this device.'
                  : null,
              segmentTimestamps: Capability.unsupported,
              wordTimestamps: Capability.unsupported,
              maxWindowSeconds: qwenMaxWindowSeconds,
              memoryBytes: manifest.minimumRamBytes,
              memorySource: manifest.ramEstimateSource,
              smokeKey: SmokeTestKey(
                adapterVersion:
                    'sherpa-onnx ${version ?? ''} $_bindingsVersion',
                modelHash: manifest.files.isEmpty
                    ? ''
                    : manifest.files.first.sha256,
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
        'sherpa-onnx is not built for this device.',
      );
    }
    final files = findQwenFiles(request.artifactDir);
    if (files == null) {
      throw const LocalAsrException(
        LocalAsrErrorCode.modelMissing,
        'The Qwen3-ASR files are not on this device.',
      );
    }
    final watch = Stopwatch()..start();
    final id = await _worker!.call(_Load(files, _threads, const []));
    watch.stop();
    if (id is! int) {
      throw LocalAsrException(
        LocalAsrErrorCode.modelCorrupt,
        'The model did not load: $id',
      );
    }
    final sessionId = 'qwen-$id';
    _sessions[sessionId] = id;
    return PreparedSession(
      sessionId: sessionId,
      artifactRevision: request.manifest.revision,
      requestedDevice: request.route.device,
      placement: PlacementKind.cpu,
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
        _Transcribe(session, request.pcmWindow.path, request.keywords),
      );
      if (_cancelled.remove(request.jobId)) {
        yield event(AsrEventType.cancelled);
        return;
      }
      if (result is! String || result.startsWith(_failure)) {
        yield event(
          AsrEventType.error,
          error: LocalAsrException(
            LocalAsrErrorCode.deviceUnavailable,
            result is String ? result.substring(_failure.length) : '$result',
          ),
        );
        return;
      }
      if (result.isNotEmpty) {
        yield event(
          AsrEventType.segment,
          segment: AsrSegment(
            startSeconds: 0,
            endSeconds: request.windowSeconds,
            text: result,
          ),
        );
      }
      yield event(AsrEventType.completed, placement: PlacementKind.cpu);
    } finally {
      _running.remove(request.jobId);
      done.complete();
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    final running = _running[jobId];
    if (running == null) return;
    // The C API cannot stop a window midway: the window finishes, and its
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

/// Purpose: Find a Qwen3-ASR package's files under its folder.
/// Inputs: The package's [dir].
/// Returns: The files, or null when any is missing.
/// Side effects: Lists the folder.
/// Notes: sherpa-onnx's archive unpacks into a folder of its own name, so the
/// files are looked for at the top and one level down.
QwenAsrFiles? findQwenFiles(Directory dir) {
  if (!dir.existsSync()) return null;
  for (final candidate in [dir, ...dir.listSync().whereType<Directory>()]) {
    String at(String name) => '${candidate.path}${Platform.pathSeparator}$name';
    if (File(at('encoder.int8.onnx')).existsSync() &&
        File(at('decoder.int8.onnx')).existsSync() &&
        File(at('conv_frontend.onnx')).existsSync() &&
        Directory(at('tokenizer')).existsSync()) {
      return QwenAsrFiles(
        convFrontend: at('conv_frontend.onnx'),
        encoder: at('encoder.int8.onnx'),
        decoder: at('decoder.int8.onnx'),
        tokenizer: at('tokenizer'),
      );
    }
  }
  return null;
}

/// How the worker marks a failed transcription's answer.
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
  const _Load(this.files, this.threads, this.hotwords);
  final QwenAsrFiles files;
  final int threads;
  final List<String> hotwords;
}

class _Transcribe extends _Request {
  const _Transcribe(this.session, this.wavPath, this.hotwords);
  final int session;
  final String wavPath;
  final List<String> hotwords;
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
    ), debugName: 'sherpa-onnx');
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

/// One loaded model on the worker, with what it was loaded with.
class _Loaded {
  _Loaded(this.model, this.files, this.threads, this.hotwords);
  QwenAsrModel model;
  final QwenAsrFiles files;
  final int threads;
  List<String> hotwords;
}

/// Purpose: The worker isolate's entry point.
/// Inputs: The handshake port and the reply port.
/// Returns: None.
/// Side effects: Loads the native library; owns every model.
/// Notes: Internal helper used within this file only. Every request is
/// answered with a value, never with an exception crossing the isolate
/// boundary. Qwen3-ASR takes its hotwords when it loads, so a window whose
/// job has other keywords than the loaded model reloads it first — once per
/// job, since every window of a job carries the same keywords.
void _workerMain((SendPort, SendPort) ports) {
  final (handshake, replies) = ports;
  final requests = ReceivePort();
  handshake.send(requests.sendPort);
  final models = <int, _Loaded>{};
  var next = 0;

  Future<void> handle(Object? message) async {
    final (id, request) = message as (int, _Request);
    Object? answer;
    try {
      answer = switch (request) {
        _Info() => SherpaLibrary.load() ?? '',
        _Load(:final files, :final threads, :final hotwords) => () {
          final key = next++;
          models[key] = _Loaded(
            QwenAsrModel.load(files, threads: threads, hotwords: hotwords),
            files,
            threads,
            hotwords,
          );
          return key;
        }(),
        _Transcribe(:final session, :final wavPath, :final hotwords) =>
          await () async {
            final loaded = models[session];
            if (loaded == null) return '${_failure}No such session.';
            if (!_sameWords(loaded.hotwords, hotwords)) {
              loaded.model.release();
              loaded.model = QwenAsrModel.load(
                loaded.files,
                threads: loaded.threads,
                hotwords: hotwords,
              );
              loaded.hotwords = hotwords;
            }
            final window = await readPcmWindow(File(wavPath));
            return loaded.model.transcribe(await window.readSamples());
          }(),
        _Release(:final session) => () {
          models.remove(session)?.model.release();
          return null;
        }(),
      };
    } catch (error) {
      answer = '$_failure$error';
    }
    replies.send((id, answer));
  }

  // One request at a time: a handler that awaits file I/O must not let the
  // next request — a release — reach the model it is still using.
  var queue = Future<void>.value();
  requests.listen((message) {
    queue = queue.then((_) => handle(message));
  });
}

/// Purpose: Compare two keyword lists.
/// Inputs: [a] and [b].
/// Returns: Whether they hold the same words in the same order.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _sameWords(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
