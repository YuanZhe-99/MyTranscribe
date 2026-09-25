/// Purpose: An on-device engine that runs no model, for every test of the
/// local-model path.
/// Inputs: The routes it claims, and a script saying what each window
/// returns.
/// Returns: `FakeLocalAsrEngine`, `FakeWindow`, and helpers that build routes
/// and install a package without downloading anything.
/// Side effects: The install helper writes a manifest into a models folder.
/// Notes: Scripts segments, delays, errors and placement per call, so the
/// runner's cancel, fallback and resume rules can be driven exactly. A cancel
/// completes only after the scripted window has stopped, as a real adapter's
/// does after its native call returns.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/local_asr_engine.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:path/path.dart' as p;

/// What one window of the fake returns.
class FakeWindow {
  /// The segments it emits, in window-local seconds.
  final List<AsrSegment> segments;

  /// The error it ends with instead of completing, if any.
  final LocalAsrException? error;

  /// How long it takes; a cancel cuts it short.
  final Duration delay;

  /// The placement it reports.
  final PlacementKind? placement;

  /// Purpose: Create a scripted window.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FakeWindow({
    this.segments = const [],
    this.error,
    this.delay = Duration.zero,
    this.placement,
  });

  /// Purpose: A window that says [text] over its first five seconds.
  /// Inputs: [text].
  /// Returns: A [FakeWindow].
  /// Side effects: None.
  /// Notes: None.
  factory FakeWindow.text(String text, {PlacementKind? placement}) =>
      FakeWindow(
        segments: [AsrSegment(startSeconds: 0, endSeconds: 5, text: text)],
        placement: placement,
      );
}

/// Purpose: Build a route for the fake.
/// Inputs: The [modelId], [artifactId], [device], [backend] and the rest.
/// Returns: An [EngineRoute] of the given adapter.
/// Side effects: None.
/// Notes: The smoke key is derived from the route key, so each route's check
/// result is filed separately.
EngineRoute fakeRoute({
  required String adapterId,
  required String modelId,
  required String artifactId,
  ComputeDevice device = ComputeDevice.cpu,
  String? backend,
  EvidenceLevel evidence = EvidenceLevel.official,
  bool testedHere = false,
  bool available = true,
  SmokeTestSummary smokeTest = SmokeTestSummary.notRun,
  Capability segmentTimestamps = Capability.supported,
}) {
  final name = backend ?? device.name;
  return EngineRoute(
    adapterId: adapterId,
    modelId: modelId,
    artifactId: artifactId,
    device: device,
    backend: name,
    evidence: evidence,
    testedHere: testedHere,
    available: available,
    smokeTest: smokeTest,
    smokeKey: 'fake|$artifactId|$name',
    segmentTimestamps: segmentTimestamps,
  );
}

/// Purpose: Put a package's manifest in place as if it had been installed.
/// Inputs: The [modelsDir] and the [manifest].
/// Returns: None.
/// Side effects: Writes `models/<artifactId>/manifest.json`.
/// Notes: Nothing is downloaded; the fake engine never opens a model file.
Future<void> fakeInstall(Directory modelsDir, ArtifactManifest manifest) async {
  final dir = Directory(p.join(modelsDir.path, manifest.artifactId));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'manifest.json')).writeAsString(
    const JsonEncoder.withIndent('  ').convert(
      manifest.asInstalled(const [], DateTime.utc(2026, 9, 24)).toJson(),
    ),
  );
}

/// A scripted engine.
class FakeLocalAsrEngine implements LocalAsrEngine {
  /// Purpose: Create a fake engine.
  /// Inputs: Its [adapterId], the [routes] it offers, and a [script] that
  /// says what each window returns, given the route and the call number.
  /// Returns: A new engine.
  /// Side effects: None.
  /// Notes: [prepareError] makes the next prepare on a route key fail.
  FakeLocalAsrEngine({
    required this.adapterId,
    required this.routes,
    FakeWindow Function(String routeKey, int call)? script,
  }) : script = script ?? ((_, call) => FakeWindow.text('window $call'));

  @override
  final String adapterId;

  /// The routes it offers when their package is installed.
  final List<EngineRoute> routes;

  /// What each window returns.
  FakeWindow Function(String routeKey, int call) script;

  /// Errors to throw from prepare, by route key.
  final Map<String, LocalAsrException> prepareError = {};

  /// The route of every prepare, in order.
  final List<String> prepared = [];

  /// The session ids released, in order.
  final List<String> released = [];

  /// The route of every window run, in order.
  final List<String> windows = [];

  /// The job ids cancelled.
  final List<String> cancelled = [];

  final _sessions = <String, EngineRoute>{};
  final _running = <String, Completer<void>>{};
  final _finished = <String, Completer<void>>{};

  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async {
    final installed = {for (final m in manifests) m.artifactId};
    return [
      for (final route in routes)
        if (installed.contains(route.artifactId)) route,
    ];
  }

  @override
  Future<PreparedSession> prepare(PrepareRequest request) async {
    final error = prepareError[request.route.key];
    if (error != null) throw error;
    prepared.add(request.route.key);
    final id = 'session-${prepared.length}';
    _sessions[id] = request.route;
    return PreparedSession(
      sessionId: id,
      artifactRevision: request.manifest.revision,
      requestedDevice: request.route.device,
      placement: request.route.isCpu ? PlacementKind.cpu : PlacementKind.gpu,
    );
  }

  @override
  Stream<AsrEvent> transcribe(TranscribeRequest request) async* {
    final route = _sessions[request.sessionId]!;
    windows.add(route.key);
    final window = script(route.key, windows.length - 1);
    var sequence = 0;
    AsrEvent event(AsrEventType type, {AsrSegment? segment}) => AsrEvent(
      jobId: request.jobId,
      sequence: sequence++,
      type: type,
      segment: segment,
      hasRealTimestamps: type == AsrEventType.completed,
      placement: type == AsrEventType.completed
          ? (window.placement ??
                (route.isCpu ? PlacementKind.cpu : PlacementKind.gpu))
          : null,
      error: type == AsrEventType.error ? window.error : null,
    );

    final stop = Completer<void>();
    final done = Completer<void>();
    _running[request.jobId] = stop;
    _finished[request.jobId] = done;
    try {
      yield event(AsrEventType.started);
      if (window.delay > Duration.zero) {
        await Future.any([Future<void>.delayed(window.delay), stop.future]);
      }
      if (stop.isCompleted) {
        yield event(AsrEventType.cancelled);
        return;
      }
      for (final segment in window.segments) {
        yield event(AsrEventType.segment, segment: segment);
      }
      if (window.error != null) {
        yield event(AsrEventType.error);
      } else {
        yield event(AsrEventType.completed);
      }
    } finally {
      _running.remove(request.jobId);
      _finished.remove(request.jobId);
      done.complete();
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    cancelled.add(jobId);
    final stop = _running[jobId];
    final done = _finished[jobId];
    if (stop != null && !stop.isCompleted) stop.complete();
    if (done != null) await done.future;
  }

  @override
  Future<void> release(String sessionId) async {
    released.add(sessionId);
    _sessions.remove(sessionId);
  }
}
