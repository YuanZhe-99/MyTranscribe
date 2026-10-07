# lib/features/local/services/local_models_controller.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。


## 声明

| Declaration | Purpose |
|---|---|
| `library;` | What the pages know about local models on this device, and the |
| `const LocalModelActivity({this.progress, this.checking = false, this.error});` | Create an activity value. |
| `LocalModelsController(this.ref) : super(const {});` | Create the controller. |
| `List<ArtifactManifest> downloadableFor(LocalModelConfig model) {` | The packages of [model] this build can use. |
| `Future<void> download(LocalModelConfig model) async {` | Download a model's packages, then check its routes. |
| `void cancel(LocalModelConfig model) => _cancels[model.id]?.cancel();` | Stop a download. |
| `Future<void> remove(LocalModelConfig model) async {` | Remove a model's packages from this device. |
| `Future<bool> verify(LocalModelConfig model) async {` | Check a model's installed files against their hashes. |
| `Future<void> checkAll(LocalModelConfig model) async {` | Check every route of a model on this device. |
| `Future<void> check(LocalModelConfig model, EngineRoute route) async {` | Check one route on this device. |
| `void _set(String id, LocalModelActivity activity) {` | Record one model's activity. |
| `void _refreshInstalled() {` | Make every page re-read what is installed. |
