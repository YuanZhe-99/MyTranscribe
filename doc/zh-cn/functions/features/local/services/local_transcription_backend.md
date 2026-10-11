# lib/features/local/services/local_transcription_backend.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。


## 声明

`_native` 与自检共用设备状态的独占执行队列，避免并发调用覆盖彼此的崩溃标记。

| Declaration | Purpose |
|---|---|
| `library;` | What the job runner talks to when a job's model runs on the |
| `const LocalWindowResult({` | Create a window result. |
| `LocalTranscriptionBackend({` | Create the backend. |
| `Future<LocalJobSession> open({` | Choose a route for a job and get it ready to prepare. |
| `LocalJobSession._({` | Create a session. |
| `Future<PreparedSession> prepare() async {` | Load the model, once for the job. |
| `Future<LocalWindowResult> transcribe({` | Transcribe one window. |
| `Future<void> cancel() async {` | Stop the running window. |
| `Future<void> close() async {` | Unload the model and let go of the package. |
| `Future<(TranscriptionResult, PlacementKind)> _run(` | Run one window on the current route. |
| `Future<void> _switchTo(EngineRoute next) async {` | Move the session to another route of the same model. |
| `Future<T> _native<T>(Future<T> Function() call) async {` | Run a native call with the in-flight marker around it. |
| `Future<ArtifactManifest?> manifestOf(` | The package a route runs. |
