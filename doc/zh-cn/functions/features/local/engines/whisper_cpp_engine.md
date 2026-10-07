# lib/features/local/engines/whisper_cpp_engine.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `WhisperCppEngine({` | Create a runtime. Inputs: family, threads. Returns: Engine. |
| `Future<shared.WhisperRuntimeInfo> runtime() =>` | Read runtime diagnostics. Inputs: None. Returns: Runtime info. |
| `Future<void> dispose() => (engine as shared.WhisperCppEngine).dispose();` | Shut down the worker. Inputs: None. Returns: Completion. |
