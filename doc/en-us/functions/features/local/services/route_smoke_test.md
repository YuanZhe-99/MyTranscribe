# lib/features/local/services/route_smoke_test.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `const SmokeClip({` | Describe check audio. Inputs: wav, text, duration, language. |
| `RouteSmokeTester({` | Create tester. Inputs: state, clock, stopwatch. Returns: Tester. |
| `Future<SmokeTestRecord> run({` | Check one route. Inputs: engine, route, artifact, clip. |
