# lib/features/local/engines/sherpa_onnx_engine.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `SherpaOnnxEngine({int? threads})` | Create a runtime. Inputs: threads. Returns: Engine. |
| `Future<void> dispose() => (engine as shared.SherpaOnnxEngine).dispose();` | Shut down the worker. Inputs: None. Returns: Completion. |
