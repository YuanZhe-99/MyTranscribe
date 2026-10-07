import 'package:myapps_ai_asr/myapps_ai_asr.dart' as shared;
import 'package:myapps_ai_models/myapps_ai_models.dart' as models;

import '../../providers/models/model_config.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import 'local_asr_engine.dart';

/// Converts the application's persisted contracts into shared runtime contracts.
class SharedAsrAdapter implements LocalAsrEngine {
  /// Purpose: Wrap a shared engine. Inputs: engine. Returns: Adapter.
  /// Side effects: None. Notes: Ownership remains with the application.
  SharedAsrAdapter(this.engine);

  final shared.AsrEngine engine;

  /// Purpose: Identify the runtime. Inputs: None. Returns: ID.
  /// Side effects: None. Notes: Existing IDs are preserved.
  @override
  String get adapterId => engine.adapterId;

  /// Purpose: Probe installed models. Inputs: manifests. Returns: Routes.
  /// Side effects: Queries runtime. Notes: Fingerprints remain byte compatible.
  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async => [
    for (final route in await engine.probe([
      for (final manifest in manifests)
        models.ArtifactManifest.fromJson(manifest.toJson()),
    ]))
      appRoute(route),
  ];

  /// Purpose: Load a session. Inputs: request. Returns: Session.
  /// Side effects: Loads native resources. Notes: Maps shared failures.
  @override
  Future<PreparedSession> prepare(PrepareRequest request) async {
    try {
      final session = await engine.prepare(
        shared.AsrPrepareRequest(
          route: sharedRoute(request.route),
          manifest: models.ArtifactManifest.fromJson(request.manifest.toJson()),
          artifactDir: request.artifactDir,
          jobId: request.jobId,
        ),
      );
      return PreparedSession(
        sessionId: session.sessionId,
        artifactRevision: session.artifactRevision,
        requestedDevice: ComputeDevice.parse(session.requestedDevice.name),
        placement: PlacementKind.parse(session.placement.name),
        prepareTime: session.prepareTime,
        usedCompileCache: session.usedCompileCache,
      );
    } on shared.AsrException catch (error) {
      throw appError(error);
    }
  }

  /// Purpose: Transcribe a window. Inputs: request. Returns: Events.
  /// Side effects: Runs native inference. Notes: Terminal events are preserved.
  @override
  Stream<AsrEvent> transcribe(TranscribeRequest request) async* {
    try {
      await for (final event in engine.transcribe(
        shared.AsrRequest(
          jobId: request.jobId,
          sessionId: request.sessionId,
          pcmWindow: request.pcmWindow,
          windowSeconds: request.windowSeconds,
          languages: request.languages,
          prompt: request.prompt,
          keywords: request.keywords,
        ),
      )) {
        final segment = event.segment;
        yield AsrEvent(
          jobId: event.jobId,
          sequence: event.sequence,
          type: AsrEventType.values.byName(event.type.name),
          progress: event.progress,
          segment: segment == null
              ? null
              : AsrSegment(
                  startSeconds: segment.startSeconds,
                  endSeconds: segment.endSeconds,
                  text: segment.text,
                ),
          hasRealTimestamps: event.hasRealTimestamps,
          placement: event.placement == null
              ? null
              : PlacementKind.parse(event.placement!.name),
          error: event.error == null ? null : appError(event.error!),
          detail: event.detail,
        );
      }
    } on shared.AsrException catch (error) {
      throw appError(error);
    }
  }

  /// Purpose: Stop a job. Inputs: jobId. Returns: Completion.
  /// Side effects: Cancels inference. Notes: Waits for native completion.
  @override
  Future<void> cancel(String jobId) => engine.cancel(jobId);

  /// Purpose: Unload a session. Inputs: sessionId. Returns: Completion.
  /// Side effects: Frees native resources. Notes: Cancel must finish first.
  @override
  Future<void> release(String sessionId) => engine.release(sessionId);
}

/// Purpose: Map failures. Inputs: error. Returns: Application exception.
/// Side effects: None. Notes: Wire codes and retryability are preserved.
LocalAsrException appError(shared.AsrException error) => LocalAsrException(
  LocalAsrErrorCode.parse(error.code.wire),
  error.message,
  retryable: error.retryable,
);

/// Purpose: Convert a runtime route. Inputs: route. Returns: App route.
/// Side effects: None. Notes: Keys, health and capabilities are preserved.
EngineRoute appRoute(shared.AsrRoute route) => EngineRoute(
  adapterId: route.adapterId,
  modelId: route.modelId,
  artifactId: route.artifactId,
  device: ComputeDevice.parse(route.device.name),
  backend: route.backend,
  evidence: EvidenceLevel.parse(route.evidence.name),
  testedHere: route.testedHere,
  smokeKey: route.fingerprint.encode(),
  smokeTest: SmokeTestSummary(
    SmokeTestOutcome.parse(route.health.outcome.name),
    realTimeFactor: route.health.realTimeFactor,
    reason: route.health.reason,
  ),
  available: route.available,
  unavailableReason: route.unavailableReason,
  segmentTimestamps: Capability.parse(
    route.capabilities.segmentTimestamps.name,
  ),
  wordTimestamps: Capability.parse(route.capabilities.wordTimestamps.name),
  maxWindowSeconds: route.maxWindowSeconds,
  memoryBytes: route.memoryBytes,
  memorySource: EstimateSource.parse(route.memorySource.name),
);

/// Purpose: Convert an application route. Inputs: route. Returns: Shared route.
/// Side effects: None. Notes: Only original six fingerprint parts are used.
shared.AsrRoute sharedRoute(EngineRoute route) {
  final parts = route.smokeKey.split('|');
  final key = parts.length == 6 ? parts : List.filled(6, '');
  return shared.AsrRoute(
    adapterId: route.adapterId,
    modelId: route.modelId,
    artifactId: route.artifactId,
    device: shared.ComputeDevice.parse(route.device.name),
    backend: route.backend,
    evidence: shared.EvidenceLevel.parse(route.evidence.name),
    testedHere: route.testedHere,
    fingerprint: models.HealthFingerprint(
      runtimeVersion: key[0],
      modelHash: key[1],
      osVersion: key[2],
      driverVersion: key[3],
      deviceId: key[4],
      precision: key[5],
    ),
    health: shared.RouteHealth(
      models.SelfTestOutcome.parse(route.smokeTest.outcome.name),
      realTimeFactor: route.smokeTest.realTimeFactor,
      reason: route.smokeTest.reason,
    ),
    available: route.available,
    unavailableReason: route.unavailableReason,
    capabilities: shared.AsrCapabilities(
      segmentTimestamps: shared.AsrCapability.parse(
        route.segmentTimestamps.name,
      ),
      wordTimestamps: shared.AsrCapability.parse(route.wordTimestamps.name),
    ),
    maxWindowSeconds: route.maxWindowSeconds,
    memoryBytes: route.memoryBytes,
    memorySource: models.EstimateSource.parse(route.memorySource.name),
    modelIndependent: route.adapterId == 'system',
  );
}

/// Bridges application test engines into shared orchestration contracts.
class AppAsrAdapter implements shared.AsrEngine {
  /// Purpose: Wrap an app engine. Inputs: engine. Returns: Adapter.
  /// Side effects: None. Notes: Used by registry and self-tests.
  AppAsrAdapter(this.engine);
  final LocalAsrEngine engine;
  final Map<String, EngineRoute> probedRoutes = {};

  /// Purpose: Identify adapter. Inputs: None. Returns: ID.
  /// Side effects: None. Notes: None.
  @override
  String get adapterId => engine.adapterId;

  /// Purpose: Probe artifacts. Inputs: manifests. Returns: Routes.
  /// Side effects: Probes runtime. Notes: Converts compatible manifest JSON.
  @override
  Future<List<shared.AsrRoute>> probe(
    List<models.ArtifactManifest> manifests,
  ) async {
    final routes = await engine.probe([
      for (final manifest in manifests)
        ArtifactManifest.fromJson(manifest.toJson()),
    ]);
    probedRoutes.clear();
    for (final route in routes) {
      probedRoutes[route.key] = route;
    }
    return routes.map(sharedRoute).toList();
  }

  /// Purpose: Load model. Inputs: request. Returns: Session.
  /// Side effects: Native resources. Notes: Preserves placement.
  @override
  Future<shared.AsrSession> prepare(shared.AsrPrepareRequest request) async {
    try {
      final session = await engine.prepare(
        PrepareRequest(
          route: appRoute(request.route),
          manifest: ArtifactManifest.fromJson(request.manifest.toJson()),
          artifactDir: request.artifactDir,
          jobId: request.jobId,
        ),
      );
      return shared.AsrSession(
        sessionId: session.sessionId,
        artifactRevision: session.artifactRevision,
        requestedDevice: shared.ComputeDevice.parse(
          session.requestedDevice.name,
        ),
        placement: shared.PlacementKind.parse(session.placement.name),
        prepareTime: session.prepareTime,
        usedCompileCache: session.usedCompileCache,
      );
    } on LocalAsrException catch (error) {
      throw shared.AsrException(
        shared.AsrErrorCode.parse(error.code.wire),
        error.message,
        retryable: error.retryable,
      );
    }
  }

  /// Purpose: Stream transcription. Inputs: request. Returns: Events.
  /// Side effects: Inference. Notes: Preserves errors and terminal events.
  @override
  Stream<shared.AsrEvent> transcribe(shared.AsrRequest request) async* {
    await for (final event in engine.transcribe(
      TranscribeRequest(
        jobId: request.jobId,
        sessionId: request.sessionId,
        pcmWindow: request.pcmWindow,
        windowSeconds: request.windowSeconds,
        languages: request.languages,
        prompt: request.prompt,
        keywords: request.keywords,
      ),
    )) {
      final segment = event.segment;
      final error = event.error;
      yield shared.AsrEvent(
        jobId: event.jobId,
        sequence: event.sequence,
        type: shared.AsrEventType.values.byName(event.type.name),
        progress: event.progress,
        segment: segment == null
            ? null
            : shared.AsrSegment(
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                text: segment.text,
              ),
        hasRealTimestamps: event.hasRealTimestamps,
        placement: event.placement == null
            ? null
            : shared.PlacementKind.parse(event.placement!.name),
        error: error == null
            ? null
            : shared.AsrException(
                shared.AsrErrorCode.parse(error.code.wire),
                error.message,
                retryable: error.retryable,
              ),
        detail: event.detail,
      );
    }
  }

  /// Purpose: Stop inference. Inputs: jobId. Returns: Completion.
  /// Side effects: Cancellation. Notes: Waits for native return.
  @override
  Future<void> cancel(String jobId) => engine.cancel(jobId);

  /// Purpose: Unload model. Inputs: sessionId. Returns: Completion.
  /// Side effects: Frees resources. Notes: None.
  @override
  Future<void> release(String sessionId) => engine.release(sessionId);
}
