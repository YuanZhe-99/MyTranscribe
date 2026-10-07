# lib/features/local/services/engine_registry.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | Know which local engine adapters this build has, what routes they |
| `EngineRegistry({` | Create a registry. |
| `LocalAsrEngine? engine(String adapterId) {` | Find an adapter by id. |
| `Future<List<EngineRoute>> routes({bool refresh = false}) async {` | List every route this device has, with its check results. |
| `void invalidate() => _registry.invalidate();` | Forget the cached probe results. |
