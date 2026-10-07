# lib/features/local/models/local_engine_state.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | The device-local state of the local engines — what each route's |
| `const SmokeTestKey({` | Create a key. |
| `String encode() => [` | Render the key as the string results are filed under. |
| `const SmokeTestRecord({` | Create a check record. |
| `SmokeTestSummary get summary =>` | Summarise the record for the router. |
| `factory SmokeTestRecord.fromJson(Map<String, dynamic> json) =>` | Parse a check record. |
| `Map<String, dynamic> toJson() => {` | Serialize a check record. |
| `const InFlightMarker({` | Create a marker. |
| `factory InFlightMarker.fromJson(Map<String, dynamic> json) => InFlightMarker(` | Parse a marker. |
| `Map<String, dynamic> toJson() => {` | Serialize a marker. |
| `const LocalEngineState({` | Create a state document. |
| `SmokeTestSummary smokeTestFor(String smokeKey) =>` | Find the check result for a key. |
| `LocalEngineState copyWith({` | Return a copy with some fields replaced. |
| `factory LocalEngineState.fromJson(Map<String, dynamic> json) {` | Parse the state document. |
| `Map<String, dynamic> toJson() => {` | Serialize the state document. |
