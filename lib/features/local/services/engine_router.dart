/// Purpose: Choose the route a local job runs on — or say, with a code, why
/// none can — from the model, the job, the routes this device has, and what
/// the user asked for.
/// Inputs: A `RoutingRequest`.
/// Returns: A `RouteDecision`.
/// Side effects: None — pure, so every rule is a test case.
/// Notes: Three promises live here. The router never substitutes a model: it
/// only ever considers the chosen record's own packages (decision D6 of the
/// local-models plan). A fallback happens only within the user's policy, and
/// is returned as a separate, visible decision. And Auto follows D20: an
/// accelerator route this project tested on this kind of device, else one with
/// A or B evidence that passed its check here and beat the CPU in it, else the
/// CPU — never an untested E or U route. See
/// `doc/en-us/algorithms/engine-routing.md`, whose worked examples are the
/// tests.
library;

import '../../providers/models/model_config.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';
import 'local_asr_engine.dart';

/// The adapter id of the operating system's recogniser.
///
/// Its routes serve no particular model, so they are the one kind of route
/// the router may offer for a model that is not theirs — and only as a
/// fallback the user's policy names.
const systemRecognizerAdapterId = 'system';

/// Why a route was not chosen, for the diagnostics page and the new-job page.
enum RouteRejection {
  /// The model's package for it is not installed.
  notInstalled,

  /// The backend is missing or its driver does not answer.
  unavailable,

  /// Its check on this device failed.
  checkFailed,

  /// The app stopped while it was running.
  crashed,

  /// It does not keep the timestamps the job needs.
  lacksTimestamps,

  /// Auto passed it over: not tested on this kind of device, and its evidence
  /// is E or U.
  untestedForAuto,

  /// Auto passed it over: it has not been checked on this device yet.
  notChecked,

  /// Auto passed it over: in its check it was no faster than the CPU, or the
  /// speeds could not be compared.
  notFasterThanCpu,
}

/// Everything the router looks at.
class RoutingRequest {
  /// The model the user chose.
  final LocalModelConfig model;

  /// The job's language hints; empty to detect.
  final List<String> languages;

  /// Whether the job needs segment times.
  final bool requireSegmentTimestamps;

  /// Every route this device has, with its check results attached.
  final List<EngineRoute> routes;

  /// The packages installed on this device.
  final Set<String> installedArtifacts;

  /// The adapters this build contains.
  ///
  /// Adapters only describe routes for installed packages, so with nothing
  /// installed a model has no routes at all; this is what tells "not
  /// downloaded" apart from "this build cannot run it".
  final Set<String> builtAdapters;

  /// What the user asked for.
  final RouteRequest requested;

  /// What the user allows when that cannot run.
  final FallbackPolicy policy;

  /// Purpose: Create a routing request.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const RoutingRequest({
    required this.model,
    required this.routes,
    required this.installedArtifacts,
    this.builtAdapters = const {},
    this.languages = const [],
    this.requireSegmentTimestamps = false,
    this.requested = RouteRequest.auto,
    this.policy = FallbackPolicy.sameModelOnCpu,
  });
}

/// A move away from the route asked for, within the user's policy.
class FallbackDecision {
  /// What was asked for: a route key, or `auto`/`cpu`.
  final String from;

  /// The route taken instead.
  final String toRouteKey;

  /// Why.
  final LocalAsrErrorCode reason;

  /// Purpose: Create a fallback decision.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FallbackDecision({
    required this.from,
    required this.toRouteKey,
    required this.reason,
  });
}

/// What the router decided.
class RouteDecision {
  /// The route to run on, or null when none can.
  final EngineRoute? route;

  /// Whether that route must pass its check on this device first.
  final bool needsSmokeTest;

  /// The fallback taken to reach [route], when there was one.
  final FallbackDecision? fallback;

  /// Why nothing can run, when [route] is null.
  final LocalAsrErrorCode? failure;

  /// A sentence explaining [failure].
  final String? failureDetail;

  /// Why each route of this model that was passed over was, by route key.
  final Map<String, RouteRejection> rejected;

  /// Purpose: Create a decision.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: Use the named constructors.
  const RouteDecision._({
    this.route,
    this.needsSmokeTest = false,
    this.fallback,
    this.failure,
    this.failureDetail,
    this.rejected = const {},
  });

  /// Purpose: Decide on a route.
  /// Inputs: [route], optional [fallback] and [rejected].
  /// Returns: A decision that runs.
  /// Side effects: None.
  /// Notes: [needsSmokeTest] follows from the route's own check result.
  factory RouteDecision.run(
    EngineRoute route, {
    FallbackDecision? fallback,
    Map<String, RouteRejection> rejected = const {},
  }) => RouteDecision._(
    route: route,
    needsSmokeTest: route.smokeTest.outcome == SmokeTestOutcome.notRun,
    fallback: fallback,
    rejected: rejected,
  );

  /// Purpose: Decide that nothing can run.
  /// Inputs: [failure], [detail], optional [rejected].
  /// Returns: A decision that fails.
  /// Side effects: None.
  /// Notes: None.
  const RouteDecision.fail(
    LocalAsrErrorCode failure,
    String detail, {
    Map<String, RouteRejection> rejected = const {},
  }) : this._(failure: failure, failureDetail: detail, rejected: rejected);

  /// Whether a route was chosen.
  bool get runs => route != null;
}

/// Chooses routes.
class EngineRouter {
  /// Purpose: Prevent instantiation; the entry points are static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: None.
  const EngineRouter._();

  /// Purpose: Choose the route for a job before it starts.
  /// Inputs: [request].
  /// Returns: A [RouteDecision].
  /// Side effects: None.
  /// Notes: The rules, in order: language; this model's own routes only;
  /// installed; available; check not failed or crashed; timestamps; then the
  /// request — the CPU, a named route, or Auto. Each rule's reason is kept, so
  /// the page can say why a route is not offered instead of hiding it.
  static RouteDecision choose(RoutingRequest request) {
    final model = request.model;
    if (!model.acceptsLanguages(request.languages)) {
      return RouteDecision.fail(
        LocalAsrErrorCode.unsupportedLanguage,
        '${model.displayName} does not transcribe '
        '${request.languages.join(', ')}; it covers '
        '${model.languages.join(', ')}.',
      );
    }

    final rejected = <String, RouteRejection>{};
    final usable = _usableRoutes(request, rejected);
    final ownRoutes = _ownRoutes(request);
    if (ownRoutes.isEmpty) {
      final canRun = model.artifacts.keys.any(request.builtAdapters.contains);
      if (canRun &&
          !model.artifactIds.any(request.installedArtifacts.contains)) {
        return RouteDecision.fail(
          LocalAsrErrorCode.modelMissing,
          '${model.displayName} is not downloaded on this device.',
          rejected: rejected,
        );
      }
      return RouteDecision.fail(
        LocalAsrErrorCode.backendNotBuilt,
        'This build has no engine for ${model.displayName}.',
        rejected: rejected,
      );
    }
    if (!ownRoutes.any(
      (route) => request.installedArtifacts.contains(route.artifactId),
    )) {
      return RouteDecision.fail(
        LocalAsrErrorCode.modelMissing,
        '${model.displayName} is not downloaded on this device.',
        rejected: rejected,
      );
    }

    final cpu = _bestCpu(usable);

    // ── The CPU, by name ──
    if (request.requested.isCpu) {
      if (cpu != null) return RouteDecision.run(cpu, rejected: rejected);
      return _fallbackOrFail(
        request,
        from: 'cpu',
        reason: _reasonFor(ownRoutes.where((r) => r.isCpu), rejected),
        cpu: null,
        rejected: rejected,
      );
    }

    // ── One named route ──
    final key = request.requested.routeKey;
    if (key != null) {
      for (final route in usable) {
        if (route.key == key) {
          return RouteDecision.run(route, rejected: rejected);
        }
      }
      return _fallbackOrFail(
        request,
        from: key,
        reason: _reasonFor(ownRoutes.where((r) => r.key == key), rejected),
        cpu: cpu,
        rejected: rejected,
      );
    }

    // ── Auto (D20) ──
    final accelerators = <EngineRoute>[];
    for (final route in usable) {
      if (route.isCpu) continue;
      if (route.smokeTest.outcome != SmokeTestOutcome.passed) {
        rejected[route.key] = RouteRejection.notChecked;
        continue;
      }
      if (route.testedHere) {
        accelerators.add(route);
        continue;
      }
      if (!route.evidence.allowsUntestedAuto) {
        rejected[route.key] = RouteRejection.untestedForAuto;
        continue;
      }
      if (!_fasterThan(route, cpu)) {
        rejected[route.key] = RouteRejection.notFasterThanCpu;
        continue;
      }
      accelerators.add(route);
    }
    accelerators.sort(_preferForAuto);
    if (accelerators.isNotEmpty) {
      return RouteDecision.run(accelerators.first, rejected: rejected);
    }
    if (cpu != null) return RouteDecision.run(cpu, rejected: rejected);
    return RouteDecision.fail(
      _reasonFor(ownRoutes, rejected),
      'No route for ${model.displayName} can run on this device.',
      rejected: rejected,
    );
  }

  /// Purpose: Decide what to do when a running route fails mid-job.
  /// Inputs: The original [request], the [failed] route and the error [code].
  /// Returns: A decision naming the CPU route as a fallback, or a failure.
  /// Side effects: None.
  /// Notes: Only a route problem — a lost device, a driver, memory on an
  /// accelerator — can be answered by the CPU; a damaged model or an
  /// unsupported language fails the same way everywhere, so it fails here. A
  /// failure on the CPU itself has nowhere further to go.
  static RouteDecision fallbackAfter(
    RoutingRequest request,
    EngineRoute failed,
    LocalAsrErrorCode code,
  ) {
    if (!code.isRouteProblem || failed.isCpu) {
      return RouteDecision.fail(code, 'The ${failed.backend} route failed.');
    }
    final rejected = <String, RouteRejection>{};
    final cpu = _bestCpu(
      _usableRoutes(request, rejected).where((r) => r.key != failed.key),
    );
    return _fallbackOrFail(
      request,
      from: failed.key,
      reason: code,
      cpu: cpu,
      rejected: rejected,
    );
  }

  /// Purpose: Apply the user's fallback policy.
  /// Inputs: The [request], what the job asked for ([from]), the [reason] it
  /// cannot run, the best [cpu] route, and the rejections so far.
  /// Returns: A running decision with a [FallbackDecision], or a failure.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static RouteDecision _fallbackOrFail(
    RoutingRequest request, {
    required String from,
    required LocalAsrErrorCode reason,
    required EngineRoute? cpu,
    required Map<String, RouteRejection> rejected,
  }) {
    switch (request.policy) {
      case FallbackPolicy.sameModelOnCpu:
        if (cpu != null && cpu.key != from) {
          return RouteDecision.run(
            cpu,
            fallback: FallbackDecision(
              from: from,
              toRouteKey: cpu.key,
              reason: reason,
            ),
            rejected: rejected,
          );
        }
      case FallbackPolicy.systemRecognizer:
        for (final route in request.routes) {
          if (route.adapterId == systemRecognizerAdapterId &&
              route.available &&
              route.smokeTest.outcome.allowsUse) {
            return RouteDecision.run(
              route,
              fallback: FallbackDecision(
                from: from,
                toRouteKey: route.key,
                reason: reason,
              ),
              rejected: rejected,
            );
          }
        }
      case FallbackPolicy.none:
        break;
    }
    return RouteDecision.fail(
      reason,
      'The route asked for ($from) cannot run here, and the fallback policy '
      '(${request.policy.name}) allows nothing else.',
      rejected: rejected,
    );
  }

  /// Purpose: List this model's own routes.
  /// Inputs: [request].
  /// Returns: The routes whose model and package belong to the record.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. This filter is the
  /// "never substitute a model" rule.
  static List<EngineRoute> _ownRoutes(RoutingRequest request) {
    final artifacts = request.model.artifactIds;
    return [
      for (final route in request.routes)
        if (route.modelId == request.model.id &&
            artifacts.contains(route.artifactId))
          route,
    ];
  }

  /// Purpose: List the model's routes that could run a job at all.
  /// Inputs: [request], and the [rejected] map to record reasons in.
  /// Returns: The usable routes.
  /// Side effects: Adds to [rejected].
  /// Notes: Internal helper used within this file only.
  static List<EngineRoute> _usableRoutes(
    RoutingRequest request,
    Map<String, RouteRejection> rejected,
  ) {
    final usable = <EngineRoute>[];
    for (final route in _ownRoutes(request)) {
      final reason = switch (route) {
        _ when !request.installedArtifacts.contains(route.artifactId) =>
          RouteRejection.notInstalled,
        _ when !route.available => RouteRejection.unavailable,
        _ when route.smokeTest.outcome == SmokeTestOutcome.crashed =>
          RouteRejection.crashed,
        _ when route.smokeTest.outcome == SmokeTestOutcome.failed =>
          RouteRejection.checkFailed,
        _
            when request.requireSegmentTimestamps &&
                route.segmentTimestamps == Capability.unsupported =>
          RouteRejection.lacksTimestamps,
        _ => null,
      };
      if (reason == null) {
        usable.add(route);
      } else {
        rejected[route.key] = reason;
      }
    }
    return usable;
  }

  /// Purpose: Pick the CPU route to use.
  /// Inputs: The [usable] routes.
  /// Returns: The best CPU route, or null.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A checked route before
  /// an unchecked one, then one tested here, then the better evidence — so a
  /// device with two CPU packages of one model uses the one known to work.
  static EngineRoute? _bestCpu(Iterable<EngineRoute> usable) {
    final cpu = [
      for (final route in usable)
        if (route.isCpu) route,
    ];
    if (cpu.isEmpty) return null;
    cpu.sort((a, b) {
      final checked =
          _rank(b.smokeTest.outcome == SmokeTestOutcome.passed) -
          _rank(a.smokeTest.outcome == SmokeTestOutcome.passed);
      if (checked != 0) return checked;
      final tested = _rank(b.testedHere) - _rank(a.testedHere);
      if (tested != 0) return tested;
      final evidence = a.evidence.index - b.evidence.index;
      if (evidence != 0) return evidence;
      return a.key.compareTo(b.key);
    });
    return cpu.first;
  }

  /// Purpose: Order Auto's accelerator candidates.
  /// Inputs: Two routes.
  /// Returns: A comparison, best first.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Tested here first,
  /// then the faster check, then the better evidence, then the key, so the
  /// choice is stable.
  static int _preferForAuto(EngineRoute a, EngineRoute b) {
    final tested = _rank(b.testedHere) - _rank(a.testedHere);
    if (tested != 0) return tested;
    final speedA = a.smokeTest.realTimeFactor ?? double.infinity;
    final speedB = b.smokeTest.realTimeFactor ?? double.infinity;
    final speed = speedA.compareTo(speedB);
    if (speed != 0) return speed;
    final evidence = a.evidence.index - b.evidence.index;
    if (evidence != 0) return evidence;
    return a.key.compareTo(b.key);
  }

  /// Purpose: Report whether a route beat the CPU in its check.
  /// Inputs: The [route] and the [cpu] route.
  /// Returns: `bool` — false when either speed is unknown.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. An unknown speed is
  /// not a win: D20 lets an untested route earn Auto only by a measurement.
  static bool _fasterThan(EngineRoute route, EngineRoute? cpu) {
    final mine = route.smokeTest.realTimeFactor;
    final theirs = cpu?.smokeTest.realTimeFactor;
    if (mine == null || theirs == null) return false;
    return mine < theirs;
  }

  /// Purpose: Name the error for routes that cannot run.
  /// Inputs: The [routes] concerned and the [rejected] reasons.
  /// Returns: The most specific code.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static LocalAsrErrorCode _reasonFor(
    Iterable<EngineRoute> routes,
    Map<String, RouteRejection> rejected,
  ) {
    final reasons = {for (final route in routes) rejected[route.key]};
    if (routes.isEmpty) return LocalAsrErrorCode.backendNotBuilt;
    if (reasons.contains(RouteRejection.crashed)) {
      return LocalAsrErrorCode.routeCrashed;
    }
    if (reasons.contains(RouteRejection.notInstalled)) {
      return LocalAsrErrorCode.modelMissing;
    }
    if (reasons.contains(RouteRejection.lacksTimestamps)) {
      return LocalAsrErrorCode.unsupportedFeature;
    }
    if (reasons.contains(RouteRejection.unavailable)) {
      return LocalAsrErrorCode.driverMissing;
    }
    return LocalAsrErrorCode.deviceUnavailable;
  }

  /// Purpose: Turn a flag into a sort rank.
  /// Inputs: [flag].
  /// Returns: 1 or 0.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static int _rank(bool flag) => flag ? 1 : 0;
}
