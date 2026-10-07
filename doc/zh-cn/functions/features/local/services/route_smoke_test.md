# lib/features/local/services/route_smoke_test.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `const SmokeClip({` | Describe check audio. Inputs: wav, text, duration, language. |
| `RouteSmokeTester({` | Create tester. Inputs: state, clock, stopwatch. Returns: Tester. |
| `Future<SmokeTestRecord> run({` | Check one route. Inputs: engine, route, artifact, clip. |
