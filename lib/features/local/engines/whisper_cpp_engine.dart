/// Purpose: The whisper.cpp adapter: the first real on-device engine.
/// Inputs: Installed GGML packages; PCM windows.
/// Returns: Routes, prepared sessions and transcription events, through the
/// `LocalAsrEngine` protocol.
/// Side effects: Starts a long-lived worker isolate that loads the native
/// library and owns every loaded model.
/// Notes: Every native call blocks, so none runs on the UI isolate: the
/// worker owns each model handle, and the main isolate only sends it requests
/// (decision D16 of the local-models plan). Cancelling writes a flag in native
/// memory the running call polls, then waits for the call to return before
/// anything is released. See `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:local_asr_whisper/local_asr_whisper.dart';
import 'package:path/path.dart' as p;

import '../../../shared/utils/platform_capabilities.dart';
import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import '../services/local_asr_engine.dart';
import '../services/local_model_templates.dart';
import '../services/pcm_window_cutter.dart';
import '../services/tested_here.dart';

/// The shim's own version, part of every check key: a change to the shim can
/// change what a route produces as surely as a new whisper.cpp can.
const _shimVersion = 'lasr1';

/// What the worker learned about the native library.
class WhisperRuntimeInfo {
  /// Whether the library loaded at all.
  final bool loaded;

  /// whisper.cpp's version.
  final String version;

  /// whisper.cpp's system-info line.
  final String systemInfo;

  /// The devices ggml found.
  final List<WhisperDevice> devices;

  /// Purpose: Create a runtime description.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const WhisperRuntimeInfo({
    required this.loaded,
    this.version = '',
    this.systemInfo = '',
    this.devices = const [],
  });

  /// The CPU device's description, for the check key.
  String get cpuName {
    for (final device in devices) {
      if (device.type == 0) return device.description;
    }
    return 'CPU';
  }

  /// Whether ggml found a GPU.
  bool get hasGpu => devices.any((d) => d.type == 1 || d.type == 2);

  /// The GPU's name, or empty.
  String get gpuName {
    for (final device in devices) {
      if (device.type == 1 || device.type == 2) return device.description;
    }
    return '';
  }
}

/// The whisper.cpp engine.
class WhisperCppEngine implements LocalAsrEngine {
  /// Purpose: Create the engine.
  /// Inputs: Optional [testedHere], the table of routes this project verified
  /// on this device's class, and [threads] for tests.
  /// Returns: A new engine; the worker starts on first use.
  /// Side effects: None.
  /// Notes: None.
  WhisperCppEngine({bool Function(EngineRoute route)? testedHere, int? threads})
    : _testedHere = testedHere ?? isTestedHere,
      _threads = threads ?? localEngineThreads(Platform.numberOfProcessors);

  final bool Function(EngineRoute) _testedHere;
  final int _threads;

  @override
  String get adapterId => whisperCppAdapterId;

  _Worker? _worker;
  WhisperRuntimeInfo? _info;
  final _sessions = <String, _Session>{};
  final _running = <String, ({WhisperControl control, Future<void> done})>{};

  /// Purpose: Start the worker and learn what the library has.
  /// Inputs: None.
  /// Returns: The runtime description.
  /// Side effects: Spawns the worker isolate once.
  /// Notes: A library that does not load — a target the build skipped — is
  /// reported, not thrown.
  Future<WhisperRuntimeInfo> runtime() async {
    final known = _info;
    if (known != null) return known;
    final worker = _worker ??= await _Worker.spawn();
    final info = await worker.call(const _Info()) as WhisperRuntimeInfo;
    return _info = info;
  }

  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async {
    final info = await runtime();
    final routes = <EngineRoute>[];
    for (final manifest in manifests) {
      if (manifest.adapterId != adapterId) continue;
      final model = _modelFile(manifest);
      final base = EngineRoute(
        adapterId: adapterId,
        modelId: manifest.modelId,
        artifactId: manifest.artifactId,
        device: ComputeDevice.cpu,
        backend: 'cpu',
        evidence: cpuEvidence,
        available: info.loaded && model != null,
        unavailableReason: !info.loaded
            ? 'whisper.cpp is not built for this device.'
            : model == null
            ? 'The package has no GGML model file.'
            : null,
        segmentTimestamps: Capability.supported,
        wordTimestamps: Capability.unknown,
        memoryBytes: manifest.minimumRamBytes,
        memorySource: manifest.ramEstimateSource,
        smokeKey: _key(info, manifest, model, gpu: false),
      );
      routes.add(_withTested(base));
      if (info.loaded && info.hasGpu && hasMetalBackend) {
        routes.add(
          _withTested(
            EngineRoute(
              adapterId: adapterId,
              modelId: manifest.modelId,
              artifactId: manifest.artifactId,
              device: ComputeDevice.gpu,
              backend: 'metal',
              evidence: EvidenceLevel.community,
              available: model != null,
              segmentTimestamps: Capability.supported,
              wordTimestamps: Capability.unknown,
              memoryBytes: manifest.minimumRamBytes,
              memorySource: manifest.ramEstimateSource,
              smokeKey: _key(info, manifest, model, gpu: true),
            ),
          ),
        );
      }
    }
    return routes;
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
        )
      : route;

  @override
  Future<PreparedSession> prepare(PrepareRequest request) async {
    final info = await runtime();
    if (!info.loaded) {
      throw const LocalAsrException(
        LocalAsrErrorCode.backendNotBuilt,
        'whisper.cpp is not built for this device.',
      );
    }
    final model = _modelFile(request.manifest);
    if (model == null) {
      throw const LocalAsrException(
        LocalAsrErrorCode.modelFormatMismatch,
        'The package has no GGML model file.',
      );
    }
    final path = p.join(request.artifactDir.path, model.path);
    if (!File(path).existsSync()) {
      throw LocalAsrException(
        LocalAsrErrorCode.modelMissing,
        'The model file is not on this device: ${model.path}.',
      );
    }
    // The memory guard: a package whose documented need exceeds what this
    // process can still get is refused with the numbers, rather than loaded
    // until the system kills the app.
    final need = request.manifest.minimumRamBytes;
    if (need != null) {
      final free = await _worker!.call(const _Memory());
      if (free is int && free < need) {
        throw LocalAsrException(
          LocalAsrErrorCode.outOfMemory,
          'This model needs about ${_gb(need)} of memory; '
          '${_gb(free)} is free on this device.',
        );
      }
    }
    final useGpu = !request.route.isCpu;
    final encoder = Directory(
      '${path.substring(0, path.length - 4)}-encoder.mlmodelc',
    );
    final watch = Stopwatch()..start();
    final id = await _worker!.call(_Load(path, useGpu));
    watch.stop();
    if (id is! int) {
      throw LocalAsrException(
        LocalAsrErrorCode.modelCorrupt,
        'The model did not load: $id',
      );
    }
    final sessionId = 'whisper-$id';
    final placement = !useGpu
        ? PlacementKind.cpu
        : encoder.existsSync()
        ? PlacementKind.mixed
        : PlacementKind.gpu;
    _sessions[sessionId] = _Session(id, placement);
    return PreparedSession(
      sessionId: sessionId,
      artifactRevision: request.manifest.revision,
      requestedDevice: request.route.device,
      placement: placement,
      prepareTime: watch.elapsed,
    );
  }

  @override
  Stream<AsrEvent> transcribe(TranscribeRequest request) async* {
    final session = _sessions[request.sessionId];
    var sequence = 0;
    AsrEvent event(
      AsrEventType type, {
      double? progress,
      AsrSegment? segment,
      LocalAsrException? error,
      PlacementKind? placement,
    }) => AsrEvent(
      jobId: request.jobId,
      sequence: sequence++,
      type: type,
      progress: progress,
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

    final control = WhisperControl();
    final done = Completer<void>();
    _running[request.jobId] = (control: control, done: done.future);
    yield event(AsrEventType.started);
    try {
      final call = _worker!.call(
        _Transcribe(
          session.id,
          request.pcmWindow.path,
          request.languages.isEmpty ? null : request.languages.first,
          request.prompt,
          _threads,
          control.address,
        ),
      );
      var last = -1;
      while (true) {
        final finished = await Future.any([
          call.then((_) => true),
          Future<bool>.delayed(const Duration(milliseconds: 250), () => false),
        ]);
        final progress = control.progress;
        if (progress != last) {
          last = progress;
          yield event(AsrEventType.progress, progress: progress / 100);
        }
        if (finished) break;
      }
      final result = await call;
      if (result is _Cancelled || control.isCancelled) {
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
      yield event(AsrEventType.completed, placement: session.placement);
    } finally {
      _running.remove(request.jobId);
      done.complete();
      control.dispose();
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    final running = _running[jobId];
    if (running == null) return;
    running.control.cancel();
    await running.done;
  }

  @override
  Future<void> release(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session == null) return;
    await _worker?.call(_Release(session.id));
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
    _info = null;
  }

  /// Purpose: Build a route's check key.
  /// Inputs: The runtime [info], the [manifest], its [model] file, and
  /// whether the route uses the GPU.
  /// Returns: The encoded key.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _key(
    WhisperRuntimeInfo info,
    ArtifactManifest manifest,
    ArtifactFile? model, {
    required bool gpu,
  }) => SmokeTestKey(
    adapterVersion: 'whisper.cpp ${info.version} $_shimVersion',
    modelHash: model?.sha256 ?? '',
    osVersion: Platform.operatingSystemVersion,
    driverVersion: gpu ? info.gpuName : '',
    deviceId: gpu ? info.gpuName : info.cpuName,
    precision: manifest.quantization,
  ).encode();
}

/// Purpose: Find the GGML model file in a package.
/// Inputs: [manifest].
/// Returns: The file entry, or null.
/// Side effects: None.
/// Notes: The one `.bin` file; the Core ML encoder beside it is found by
/// whisper.cpp itself, by name.
ArtifactFile? _modelFile(ArtifactManifest manifest) {
  for (final file in manifest.files) {
    if (file.path.endsWith('.bin')) return file;
  }
  return null;
}

/// Purpose: Format bytes as gigabytes for a message.
/// Inputs: [bytes].
/// Returns: e.g. `3.9 GB`.
/// Side effects: None.
/// Notes: Internal helper used within this file only; decimal gigabytes, as
/// the model publishers state them.
String _gb(int bytes) => '${(bytes / 1e9).toStringAsFixed(1)} GB';

/// One loaded model, as the main isolate knows it.
class _Session {
  _Session(this.id, this.placement);

  /// The worker's handle.
  final int id;

  /// Where it runs.
  final PlacementKind placement;
}

// ── The worker isolate ──

/// A request to the worker.
sealed class _Request {
  const _Request();
}

class _Info extends _Request {
  const _Info();
}

class _Load extends _Request {
  const _Load(this.path, this.useGpu);
  final String path;
  final bool useGpu;
}

class _Transcribe extends _Request {
  const _Transcribe(
    this.session,
    this.wavPath,
    this.language,
    this.prompt,
    this.threads,
    this.control,
  );
  final int session;
  final String wavPath;
  final String? language;
  final String? prompt;
  final int threads;
  final int control;
}

class _Memory extends _Request {
  const _Memory();
}

class _Release extends _Request {
  const _Release(this.session);
  final int session;
}

/// The worker's answer to a cancelled transcription.
class _Cancelled {
  const _Cancelled();
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
    ), debugName: 'whisper.cpp');
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
/// Side effects: Loads the native library; owns every model.
/// Notes: Internal helper used within this file only. Every request is
/// answered with a value, never with an exception crossing the isolate
/// boundary: a string is a failure, [_Cancelled] a cancellation.
void _workerMain((SendPort, SendPort) ports) {
  final (handshake, replies) = ports;
  final requests = ReceivePort();
  handshake.send(requests.sendPort);
  final models = <int, WhisperModel>{};
  var next = 0;

  requests.listen((message) async {
    final (id, request) = message as (int, _Request);
    Object? answer;
    try {
      answer = switch (request) {
        _Info() => _info(),
        _Load(:final path, :final useGpu) => () {
          final key = next++;
          models[key] = WhisperModel.load(path, useGpu: useGpu);
          return key;
        }(),
        _Transcribe() => await _run(models[request.session], request),
        _Memory() => WhisperLibrary.availableMemory(),
        _Release(:final session) => () {
          models.remove(session)?.release();
          return null;
        }(),
      };
    } on WhisperCancelled {
      answer = const _Cancelled();
    } catch (error) {
      answer = '$error';
    }
    replies.send((id, answer));
  });
}

/// Purpose: Describe the native library, loading it.
/// Inputs: None.
/// Returns: A [WhisperRuntimeInfo].
/// Side effects: Loads the library.
/// Notes: Internal helper used within this file only.
WhisperRuntimeInfo _info() {
  if (WhisperLibrary.load() == null) {
    return const WhisperRuntimeInfo(loaded: false);
  }
  return WhisperRuntimeInfo(
    loaded: true,
    version: WhisperLibrary.version(),
    systemInfo: WhisperLibrary.systemInfo(),
    devices: WhisperLibrary.devices(),
  );
}

/// Purpose: Run one window on the worker.
/// Inputs: The [model] and the [request].
/// Returns: The segments.
/// Side effects: Reads the window; runs the model.
/// Notes: Internal helper used within this file only.
Future<List<WhisperSegment>> _run(
  WhisperModel? model,
  _Transcribe request,
) async {
  if (model == null) throw const WhisperException('No such session.');
  final window = await readPcmWindow(File(request.wavPath));
  final samples = await window.readSamples();
  return model.transcribe(
    samples,
    language: request.language,
    prompt: request.prompt,
    threads: request.threads,
    control: WhisperControl.fromAddress(request.control),
  );
}
