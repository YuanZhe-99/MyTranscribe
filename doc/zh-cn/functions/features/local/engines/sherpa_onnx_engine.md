# lib/features/local/engines/sherpa_onnx_engine.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `SherpaOnnxEngine({int? threads})` | Create a runtime. Inputs: threads. Returns: Engine. |
| `Future<void> dispose() => (engine as shared.SherpaOnnxEngine).dispose();` | Shut down the worker. Inputs: None. Returns: Completion. |
