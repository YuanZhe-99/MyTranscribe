# lib/features/local/services/engine_registry.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Know which local engine adapters this build has, what routes they |
| `EngineRegistry({` | Create a registry. |
| `LocalAsrEngine? engine(String adapterId) {` | Find an adapter by id. |
| `Future<List<EngineRoute>> routes({bool refresh = false}) async {` | List every route this device has, with its check results. |
| `void invalidate() => _registry.invalidate();` | Forget the cached probe results. |
