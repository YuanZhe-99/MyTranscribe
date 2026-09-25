/// Purpose: What the job runner talks to when a job's model runs on the
/// device: it chooses the route, loads the model once per job, runs each PCM
/// window, and moves to the CPU when the user's policy allows and a route
/// fails.
/// Inputs: The engine registry, and optionally the route checker and its clip.
/// Returns: A `LocalJobSession` per job; window results shaped like an
/// uploaded window's, so the runner's merge, resume and rendering are reused
/// unchanged (decision D4 of the local-models plan).
/// Side effects: Loads and runs models; writes the in-flight marker around
/// every native call; holds a lease on the package for the job's length.
/// Notes: Every move away from the route asked for comes back as a
/// `JobFallback` for the job record — never silently (D6). See
/// `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';

import '../../jobs/models/transcription_job.dart';
import '../../providers/services/provider_dialect.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';
import 'artifact_manager.dart';
import 'engine_registry.dart';
import 'engine_router.dart';
import 'local_asr_engine.dart';
import 'route_smoke_test.dart';

/// One local window's result.
class LocalWindowResult {
  /// The text and segments, in the shape an uploaded window returns.
  final TranscriptionResult result;

  /// Where the runtime says the window ran.
  final PlacementKind placement;

  /// The route that ran it.
  final String routeKey;

  /// The fallback taken to finish this window, when one was.
  final JobFallback? fallback;

  /// Purpose: Create a window result.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LocalWindowResult({
    required this.result,
    required this.placement,
    required this.routeKey,
    this.fallback,
  });
}

/// Opens local job sessions.
class LocalTranscriptionBackend {
  /// Purpose: Create the backend.
  /// Inputs: The [registry]; optionally the route [smokeTester] and the
  /// [smokeClip] it runs, and a [clock] for tests.
  /// Returns: A new backend.
  /// Side effects: None.
  /// Notes: Without a checker and a clip, a route that has not been checked
  /// runs unchecked. That is the state of a build with no check clip bundled;
  /// once one is, every route passes its check before its first job (D20).
  LocalTranscriptionBackend({
    required this.registry,
    this.smokeTester,
    this.smokeClip,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The adapters, packages and engine state.
  final EngineRegistry registry;

  /// Runs a route's check on this device.
  final RouteSmokeTester? smokeTester;

  /// The clip checks run on, when this build carries one.
  final Future<SmokeClip?> Function()? smokeClip;

  final DateTime Function() _clock;

  /// Purpose: Choose a route for a job and get it ready to prepare.
  /// Inputs: The [job] and its [model].
  /// Returns: A [LocalJobSession].
  /// Side effects: May run a route's check; leases the package.
  /// Notes: Throws [LocalAsrException] when no route can run under the
  /// user's policy. When the route the job last ran on has since been recorded
  /// as crashed — the in-flight marker found it at startup — the change of
  /// route is recorded as a fallback with `ROUTE_CRASHED`, so the job says
  /// what happened to it.
  Future<LocalJobSession> open({
    required TranscriptionJob job,
    required LocalModelConfig model,
  }) async {
    final state = await registry.state.load();
    final fallbacks = <JobFallback>[];

    RoutingRequest request(List<EngineRoute> routes, Set<String> installed) =>
        RoutingRequest(
          model: model,
          languages: job.options.languages,
          routes: routes,
          installedArtifacts: installed,
          builtAdapters: {
            for (final engine in registry.engines) engine.adapterId,
          },
          requested: job.options.device,
          policy: state.fallbackPolicy,
        );

    Future<(RoutingRequest, RouteDecision)> decide() async {
      final routes = await registry.routes();
      final installed = {
        for (final manifest in await registry.artifacts.installedAll())
          manifest.artifactId,
      };
      final routing = request(routes, installed);
      return (routing, EngineRouter.choose(routing));
    }

    var (routing, decision) = await decide();

    // A route that has not been checked here is checked now, and the choice
    // made again if it failed.
    final tester = smokeTester;
    final clipSource = smokeClip;
    for (var attempt = 0; attempt < 4; attempt++) {
      final route = decision.route;
      if (route == null || !decision.needsSmokeTest) break;
      if (tester == null || clipSource == null) break;
      final clip = await clipSource();
      if (clip == null) break;
      final engine = registry.engine(route.adapterId);
      final manifest = await manifestOf(registry.artifacts, route);
      if (engine == null || manifest == null) break;
      await tester.run(
        engine: engine,
        route: route,
        manifest: manifest,
        artifactDir: await registry.artifacts.artifactDir(route.artifactId),
        clip: clip,
      );
      (routing, decision) = await decide();
    }

    final route = decision.route;
    if (route == null) {
      throw LocalAsrException(
        decision.failure ?? LocalAsrErrorCode.deviceUnavailable,
        decision.failureDetail ?? 'No route can run this model here.',
      );
    }

    final previous = job.route?.routeKey;
    if (decision.fallback case final fallback?) {
      fallbacks.add(
        JobFallback(
          from: fallback.from,
          to: fallback.toRouteKey,
          reason: fallback.reason.wire,
          at: _clock().toUtc(),
          atWindow: job.chunks.isEmpty ? null : job.chunks.length,
        ),
      );
    } else if (previous != null &&
        previous != route.key &&
        state.smokeTests.values.any(
          (record) =>
              record.routeKey == previous &&
              record.outcome == SmokeTestOutcome.crashed,
        )) {
      fallbacks.add(
        JobFallback(
          from: previous,
          to: route.key,
          reason: LocalAsrErrorCode.routeCrashed.wire,
          at: _clock().toUtc(),
          atWindow: job.chunks.isEmpty ? null : job.chunks.length,
        ),
      );
    }

    final engine = registry.engine(route.adapterId);
    final manifest = await manifestOf(registry.artifacts, route);
    if (engine == null || manifest == null) {
      throw LocalAsrException(
        engine == null
            ? LocalAsrErrorCode.backendNotBuilt
            : LocalAsrErrorCode.modelMissing,
        engine == null
            ? 'This build has no ${route.adapterId} engine.'
            : '${model.displayName} is not downloaded on this device.',
      );
    }

    return LocalJobSession._(
      backend: this,
      jobId: job.id,
      routing: routing,
      route: route,
      engine: engine,
      manifest: manifest,
      artifactDir: await registry.artifacts.artifactDir(route.artifactId),
      lease: registry.artifacts.lease(route.artifactId),
      openingFallbacks: fallbacks,
    );
  }
}

/// One job's hold on a loaded local model.
class LocalJobSession {
  /// Purpose: Create a session.
  /// Inputs: Everything [LocalTranscriptionBackend.open] resolved.
  /// Returns: A new session.
  /// Side effects: None.
  /// Notes: Created only by [LocalTranscriptionBackend.open].
  LocalJobSession._({
    required LocalTranscriptionBackend backend,
    required this.jobId,
    required RoutingRequest routing,
    required EngineRoute route,
    required LocalAsrEngine engine,
    required ArtifactManifest manifest,
    required Directory artifactDir,
    required ArtifactLease lease,
    required this.openingFallbacks,
  }) : _backend = backend,
       _routing = routing,
       _route = route,
       _engine = engine,
       _manifest = manifest,
       _artifactDir = artifactDir,
       _lease = lease;

  final LocalTranscriptionBackend _backend;
  final RoutingRequest _routing;

  /// The job this session serves.
  final String jobId;

  /// Fallbacks taken while choosing the first route.
  final List<JobFallback> openingFallbacks;

  EngineRoute _route;
  LocalAsrEngine _engine;
  ArtifactManifest _manifest;
  Directory _artifactDir;
  ArtifactLease _lease;
  PreparedSession? _session;
  bool _cancelled = false;

  /// The route in use now.
  EngineRoute get route => _route;

  /// The package loaded.
  ArtifactManifest get manifest => _manifest;

  /// Purpose: Load the model, once for the job.
  /// Inputs: None.
  /// Returns: The prepared session.
  /// Side effects: Loads native resources; writes the in-flight marker around
  /// the load.
  /// Notes: A second call returns the session already loaded.
  Future<PreparedSession> prepare() async {
    final existing = _session;
    if (existing != null) return existing;
    final session = await _native(
      () => _engine.prepare(
        PrepareRequest(
          route: _route,
          manifest: _manifest,
          artifactDir: _artifactDir,
          jobId: jobId,
        ),
      ),
    );
    _session = session;
    return session;
  }

  /// Purpose: Transcribe one window.
  /// Inputs: The window's [index], its [pcm] file and [seconds], the job's
  /// [options], and optional [onProgress].
  /// Returns: A [LocalWindowResult].
  /// Side effects: Runs the model; may move to the CPU route.
  /// Notes: A route problem — a lost device, a driver, memory on an
  /// accelerator — is answered by the router within the user's policy: the
  /// CPU route is loaded and the same window is run again there, and the move
  /// is returned as a fallback. Anything else, and a failure on the CPU
  /// itself, is thrown as [LocalAsrException].
  Future<LocalWindowResult> transcribe({
    required int index,
    required File pcm,
    required double seconds,
    required JobOptions options,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final result = await _run(pcm, seconds, options, onProgress);
      return LocalWindowResult(
        result: result.$1,
        placement: result.$2,
        routeKey: _route.key,
      );
    } on LocalAsrException catch (error) {
      if (_cancelled || error.code == LocalAsrErrorCode.cancelled) rethrow;
      final decision = EngineRouter.fallbackAfter(_routing, _route, error.code);
      final next = decision.route;
      if (next == null) rethrow;

      final from = _route.key;
      await _switchTo(next);
      final result = await _run(pcm, seconds, options, onProgress);
      return LocalWindowResult(
        result: result.$1,
        placement: result.$2,
        routeKey: _route.key,
        fallback: JobFallback(
          from: from,
          to: next.key,
          reason: error.code.wire,
          atWindow: index,
          at: _backend._clock().toUtc(),
        ),
      );
    }
  }

  /// Purpose: Stop the running window.
  /// Inputs: None.
  /// Returns: A future completing when the native call has returned.
  /// Side effects: Asks the engine to stop.
  /// Notes: None.
  Future<void> cancel() async {
    _cancelled = true;
    await _engine.cancel(jobId);
  }

  /// Purpose: Unload the model and let go of the package.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Frees native resources; releases the lease.
  /// Notes: Safe to call more than once.
  Future<void> close() async {
    final session = _session;
    _session = null;
    try {
      if (session != null) await _engine.release(session.sessionId);
    } finally {
      _lease.release();
    }
  }

  /// Purpose: Run one window on the current route.
  /// Inputs: The [pcm] file, its [seconds], the [options], [onProgress].
  /// Returns: The result and the placement reported.
  /// Side effects: Runs the model.
  /// Notes: Internal helper used within this file only.
  Future<(TranscriptionResult, PlacementKind)> _run(
    File pcm,
    double seconds,
    JobOptions options,
    void Function(double)? onProgress,
  ) async {
    final session = await prepare();
    return _native(() async {
      final segments = <RawSegment>[];
      var timed = false;
      var placement = session.placement;
      LocalAsrException? error;
      var cancelled = false;
      await for (final event in _engine.transcribe(
        TranscribeRequest(
          jobId: jobId,
          sessionId: session.sessionId,
          pcmWindow: pcm,
          windowSeconds: seconds,
          languages: options.languages,
          prompt: options.prompt,
          keywords: options.keywords,
        ),
      )) {
        switch (event.type) {
          case AsrEventType.progress:
            if (event.progress != null) onProgress?.call(event.progress!);
          case AsrEventType.segment:
            final segment = event.segment;
            if (segment != null) {
              segments.add(
                RawSegment(
                  startSeconds: segment.startSeconds,
                  endSeconds: segment.endSeconds,
                  text: segment.text.trim(),
                ),
              );
            }
          case AsrEventType.completed:
            timed = event.hasRealTimestamps;
            placement = event.placement ?? placement;
          case AsrEventType.cancelled:
            cancelled = true;
          case AsrEventType.error:
            error = event.error;
          case AsrEventType.preparing ||
              AsrEventType.started ||
              AsrEventType.fallback:
            break;
        }
      }
      if (cancelled || _cancelled) {
        throw const LocalAsrException(
          LocalAsrErrorCode.cancelled,
          'Cancelled.',
        );
      }
      if (error != null) throw error;
      final text = segments
          .map((s) => s.text)
          .where((t) => t.isNotEmpty)
          .join(' ');
      return (
        TranscriptionResult(
          text: text,
          segments: segments,
          hasRealTimestamps: timed,
        ),
        placement,
      );
    });
  }

  /// Purpose: Move the session to another route of the same model.
  /// Inputs: The [next] route.
  /// Returns: None.
  /// Side effects: Releases the current model, leases and loads the next.
  /// Notes: Internal helper used within this file only. The model never
  /// changes, only the route — the router only offers this record's own
  /// packages.
  Future<void> _switchTo(EngineRoute next) async {
    final artifacts = _backend.registry.artifacts;
    final engine = _backend.registry.engine(next.adapterId);
    final manifest = await manifestOf(artifacts, next);
    if (engine == null || manifest == null) {
      throw LocalAsrException(
        LocalAsrErrorCode.deviceUnavailable,
        'The fallback route ${next.key} is not available.',
      );
    }
    await close();
    _route = next;
    _engine = engine;
    _manifest = manifest;
    _artifactDir = await artifacts.artifactDir(next.artifactId);
    _lease = artifacts.lease(next.artifactId);
  }

  /// Purpose: Run a native call with the in-flight marker around it.
  /// Inputs: The [call].
  /// Returns: Whatever it returns.
  /// Side effects: Writes and clears the marker.
  /// Notes: Internal helper used within this file only. The marker is cleared
  /// on success, failure and cancellation alike; only a process that dies
  /// inside the call leaves it behind, which is the point (D20).
  Future<T> _native<T>(Future<T> Function() call) async {
    final state = _backend.registry.state;
    await state.markInFlight(
      routeKey: _route.key,
      smokeKey: _route.smokeKey,
      jobId: jobId,
    );
    try {
      return await call();
    } finally {
      await state.clearInFlight();
    }
  }
}

/// Purpose: The package a route runs.
/// Inputs: The [artifacts] manager and the [route].
/// Returns: The installed manifest, or [systemRecognizerManifest] for the
/// system recogniser, which has nothing to install; null when a package is
/// missing.
/// Side effects: Reads the installed manifest.
/// Notes: Every place that loads a route asks this rather than the manager.
Future<ArtifactManifest?> manifestOf(
  ArtifactManager artifacts,
  EngineRoute route,
) async => route.adapterId == systemRecognizerAdapterId
    ? systemRecognizerManifest
    : await artifacts.installed(route.artifactId);
