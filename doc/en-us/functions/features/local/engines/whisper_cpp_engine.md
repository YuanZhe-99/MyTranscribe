# lib/features/local/engines/whisper_cpp_engine.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `WhisperCppEngine({` | Create a runtime. Inputs: family, threads. Returns: Engine. |
| `Future<shared.WhisperRuntimeInfo> runtime() =>` | Read runtime diagnostics. Inputs: None. Returns: Runtime info. |
| `Future<void> dispose() => (engine as shared.WhisperCppEngine).dispose();` | Shut down the worker. Inputs: None. Returns: Completion. |
