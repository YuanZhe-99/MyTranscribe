import 'package:myapps_ai_asr/myapps_ai_asr.dart' as shared;

import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';
import 'local_asr_engine.dart';
import 'shared_asr_adapter.dart';

const systemRecognizerAdapterId = 'system';
const systemRecognizerManifest = ArtifactManifest(
  artifactId: 'system-recognizer',
  modelId: 'system',
  adapterId: systemRecognizerAdapterId,
  format: ArtifactFormat.unknown,
  revision: 'os',
  files: [],
  licenseId: 'OS',
);

enum RouteRejection {
  notInstalled,
  unavailable,
  checkFailed,
  crashed,
  lacksTimestamps,
  untestedForAuto,
  notChecked,
  notFasterThanCpu,
}

/// Application job selection and device-local fallback preference.
class RoutingRequest {
  final LocalModelConfig model;
  final List<String> languages;
  final bool requireSegmentTimestamps;
  final List<EngineRoute> routes;
  final Set<String> installedArtifacts;
  final Set<String> builtAdapters;
  final RouteRequest requested;
  final FallbackPolicy policy;

  /// Purpose: Describe a job. Inputs: Model, routes, preferences. Returns: Request.
  /// Side effects: None. Notes: No model substitution is permitted.
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

class FallbackDecision {
  final String from;
  final String toRouteKey;
  final LocalAsrErrorCode reason;

  /// Purpose: Record a fallback. Inputs: from, toRouteKey, reason.
  /// Returns: Decision. Side effects: None. Notes: Stored visibly on the job.
  const FallbackDecision({
    required this.from,
    required this.toRouteKey,
    required this.reason,
  });
}

class RouteDecision {
  final EngineRoute? route;
  final bool needsSmokeTest;
  final FallbackDecision? fallback;
  final LocalAsrErrorCode? failure;
  final String? failureDetail;
  final Map<String, RouteRejection> rejected;

  /// Purpose: Build a decision. Inputs: Result fields. Returns: Decision.
  /// Side effects: None. Notes: Internal constructor.
  const RouteDecision._({
    this.route,
    this.needsSmokeTest = false,
    this.fallback,
    this.failure,
    this.failureDetail,
    this.rejected = const {},
  });

  /// Purpose: Select a route. Inputs: route, fallback, rejected.
  /// Returns: Decision. Side effects: None. Notes: Unchecked routes need a test.
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

  /// Purpose: Fail selection. Inputs: failure, detail, rejected.
  /// Returns: Decision. Side effects: None. Notes: No route is selected.
  const RouteDecision.fail(
    LocalAsrErrorCode failure,
    String detail, {
    Map<String, RouteRejection> rejected = const {},
  }) : this._(failure: failure, failureDetail: detail, rejected: rejected);

  /// Purpose: Check selection. Inputs: None. Returns: Whether a route exists.
  /// Side effects: None. Notes: None.
  bool get runs => route != null;
}

/// Adapts application preferences into the shared pure router.
class EngineRouter {
  /// Purpose: Prevent construction. Inputs: None. Returns: None.
  /// Side effects: None. Notes: Static facade.
  const EngineRouter._();

  /// Purpose: Choose a route. Inputs: request. Returns: Decision.
  /// Side effects: None. Notes: Preserves route object identity for app callers.
  static RouteDecision choose(RoutingRequest request) =>
      _decision(request, shared.AsrRouter.choose(_request(request)));

  /// Purpose: Resolve a runtime failure. Inputs: request, failed, code.
  /// Returns: Decision. Side effects: None. Notes: Uses only authorized fallback.
  static RouteDecision fallbackAfter(
    RoutingRequest request,
    EngineRoute failed,
    LocalAsrErrorCode code,
  ) => _decision(
    request,
    shared.AsrRouter.fallbackAfter(
      _request(request),
      sharedRoute(failed),
      shared.AsrErrorCode.parse(code.wire),
    ),
  );

  /// Purpose: Convert routing inputs. Inputs: request. Returns: Shared request.
  /// Side effects: None. Notes: Application owns policy selection.
  static shared.AsrRoutingRequest _request(RoutingRequest request) =>
      shared.AsrRoutingRequest(
        model: shared.AsrModel(
          id: request.model.id,
          displayName: request.model.displayName,
          languages: request.model.languages,
          artifacts: request.model.artifacts,
        ),
        routes: request.routes.map(sharedRoute).toList(),
        installedArtifacts: request.installedArtifacts,
        builtAdapters: request.builtAdapters,
        languages: request.languages,
        requireSegmentTimestamps: request.requireSegmentTimestamps,
        requested: shared.RouteRequest(request.requested.value),
        fallback: shared.AsrFallbackPolicy(switch (request.policy) {
          FallbackPolicy.none => const [],
          FallbackPolicy.sameModelOnCpu => const [
            shared.SameModelCpuFallback(),
          ],
          FallbackPolicy.systemRecognizer => const [
            shared.ModelIndependentFallback('system'),
          ],
        }, name: request.policy.name),
      );

  /// Purpose: Convert routing outputs. Inputs: request, result. Returns: Decision.
  /// Side effects: None. Notes: Reuses original route objects by key.
  static RouteDecision _decision(
    RoutingRequest request,
    shared.AsrRouteDecision result,
  ) {
    final rejected = {
      for (final entry in result.rejected.entries)
        entry.key: RouteRejection.values.byName(entry.value.name),
    };
    final route = result.route;
    if (route == null) {
      return RouteDecision.fail(
        LocalAsrErrorCode.parse(result.failure?.wire),
        result.failureDetail ?? '',
        rejected: rejected,
      );
    }
    final original = request.routes.firstWhere((item) => item.key == route.key);
    final fallback = result.fallback;
    return RouteDecision.run(
      original,
      rejected: rejected,
      fallback: fallback == null
          ? null
          : FallbackDecision(
              from: fallback.from,
              toRouteKey: fallback.toRouteKey,
              reason: LocalAsrErrorCode.parse(fallback.reason.wire),
            ),
    );
  }
}
