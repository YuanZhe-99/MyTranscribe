# lib/features/local/services/local_engine_state_store.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `LocalEngineStateStore({` | Create a state store. Inputs: file, clock. Returns: Store. |
| `Future<LocalEngineState> load() async =>` | Read state. Inputs: None. Returns: App state. |
| `Future<LocalEngineState> update(` | Mutate state atomically. Inputs: change. Returns: Saved state. |
| `Future<void> markInFlight({` | Mark native work. Inputs: routeKey, smokeKey, jobId. Returns: Completion. |
| `Future<void> clearInFlight() => sharedStore.clearInFlight();` | Clear native marker. Inputs: None. Returns: Completion. |
| `Future<void> recordSmokeTest(String smokeKey, SmokeTestRecord record) async {` | Store a route check. Inputs: smokeKey, record. Returns: Completion. |
| `Future<InFlightMarker?> recoverFromCrash() async {` | Recover a crashed route. Inputs: None. Returns: Previous marker. |
