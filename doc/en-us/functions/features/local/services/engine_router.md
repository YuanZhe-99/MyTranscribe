# lib/features/local/services/engine_router.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `const RoutingRequest({` | Describe a job. Inputs: Model, routes, preferences. Returns: Request. |
| `const FallbackDecision({` | Record a fallback. Inputs: from, toRouteKey, reason. |
| `const RouteDecision._({` | Build a decision. Inputs: Result fields. Returns: Decision. |
| `factory RouteDecision.run(` | Select a route. Inputs: route, fallback, rejected. |
| `const RouteDecision.fail(` | Fail selection. Inputs: failure, detail, rejected. |
| `bool get runs => route != null;` | Check selection. Inputs: None. Returns: Whether a route exists. |
| `const EngineRouter._();` | Prevent construction. Inputs: None. Returns: None. |
| `static RouteDecision choose(RoutingRequest request) =>` | Choose a route. Inputs: request. Returns: Decision. |
| `static RouteDecision fallbackAfter(` | Resolve a runtime failure. Inputs: request, failed, code. |
| `static shared.AsrRoutingRequest _request(RoutingRequest request) =>` | Convert routing inputs. Inputs: request. Returns: Shared request. |
| `static RouteDecision _decision(` | Convert routing outputs. Inputs: request, result. Returns: Decision. |
