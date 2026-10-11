# lib/features/local/services/local_models_controller.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.


## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | What the pages know about local models on this device, and the |
| `const LocalModelActivity({this.progress, this.checking = false, this.error});` | Create an activity value. |
| `LocalModelsController(this.ref) : super(const {});` | Create the controller. |
| `List<ArtifactManifest> downloadableFor(LocalModelConfig model) {` | The packages of [model] this build can use. |
| `Future<void> download(LocalModelConfig model) async {` | Install files without probing or testing native engines; return to idle. |
| `void cancel(LocalModelConfig model) => _cancels[model.id]?.cancel();` | Stop a download. |
| `Future<void> remove(LocalModelConfig model) async {` | Remove a model's packages from this device. |
| `Future<bool> verify(LocalModelConfig model) async {` | Read installation state from disk and check hashes; return false when no package is installed. |
| `Future<void> checkAll(LocalModelConfig model) async {` | Check only available unchecked CPU routes; skip failed, crashed and GPU routes. |
| `Future<void> check(LocalModelConfig model, EngineRoute route) async {` | Check one route on this device. |
| `void _set(String id, LocalModelActivity activity) {` | Record one model's activity. |
| `void _refreshInstalled() {` | Make every page re-read what is installed. |
