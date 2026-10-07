# lib/features/local/services/shared_asr_adapter.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `SharedAsrAdapter(this.engine);` | Wrap a shared engine. Inputs: engine. Returns: Adapter. |
| `String get adapterId => engine.adapterId;` | Identify the runtime. Inputs: None. Returns: ID. |
| `Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async => [` | Probe installed models. Inputs: manifests. Returns: Routes. |
| `Future<PreparedSession> prepare(PrepareRequest request) async {` | Load a session. Inputs: request. Returns: Session. |
| `Stream<AsrEvent> transcribe(TranscribeRequest request) async* {` | Transcribe a window. Inputs: request. Returns: Events. |
| `Future<void> cancel(String jobId) => engine.cancel(jobId);` | Stop a job. Inputs: jobId. Returns: Completion. |
| `Future<void> release(String sessionId) => engine.release(sessionId);` | Unload a session. Inputs: sessionId. Returns: Completion. |
| `LocalAsrException appError(shared.AsrException error) => LocalAsrException(` | Map failures. Inputs: error. Returns: Application exception. |
| `EngineRoute appRoute(shared.AsrRoute route) => EngineRoute(` | Convert a runtime route. Inputs: route. Returns: App route. |
| `shared.AsrRoute sharedRoute(EngineRoute route) {` | Convert an application route. Inputs: route. Returns: Shared route. |
| `AppAsrAdapter(this.engine);` | Wrap an app engine. Inputs: engine. Returns: Adapter. |
| `String get adapterId => engine.adapterId;` | Identify adapter. Inputs: None. Returns: ID. |
| `Future<List<shared.AsrRoute>> probe(` | Probe artifacts. Inputs: manifests. Returns: Routes. |
| `Future<shared.AsrSession> prepare(shared.AsrPrepareRequest request) async {` | Load model. Inputs: request. Returns: Session. |
| `Stream<shared.AsrEvent> transcribe(shared.AsrRequest request) async* {` | Stream transcription. Inputs: request. Returns: Events. |
| `Future<void> cancel(String jobId) => engine.cancel(jobId);` | Stop inference. Inputs: jobId. Returns: Completion. |
| `Future<void> release(String sessionId) => engine.release(sessionId);` | Unload model. Inputs: sessionId. Returns: Completion. |
