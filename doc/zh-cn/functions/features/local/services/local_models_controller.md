# lib/features/local/services/local_models_controller.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。


## 声明

| Declaration | Purpose |
|---|---|
| `library;` | What the pages know about local models on this device, and the |
| `const LocalModelActivity({this.progress, this.checking = false, this.error});` | Create an activity value. |
| `LocalModelsController(this.ref) : super(const {});` | Create the controller. |
| `List<ArtifactManifest> downloadableFor(LocalModelConfig model) {` | The packages of [model] this build can use. |
| `Future<void> download(LocalModelConfig model) async {` | 安装文件后恢复空闲，不探测或测试原生引擎。 |
| `void cancel(LocalModelConfig model) => _cancels[model.id]?.cancel();` | Stop a download. |
| `Future<void> remove(LocalModelConfig model) async {` | Remove a model's packages from this device. |
| `Future<bool> verify(LocalModelConfig model) async {` | 从磁盘读取安装状态并校验哈希；没有已安装包时返回 false。 |
| `Future<void> checkAll(LocalModelConfig model) async {` | 仅检查可用且未检查的 CPU 路线，跳过失败、崩溃和 GPU 路线。 |
| `Future<void> check(LocalModelConfig model, EngineRoute route) async {` | Check one route on this device. |
| `void _set(String id, LocalModelActivity activity) {` | Record one model's activity. |
| `void _refreshInstalled() {` | Make every page re-read what is installed. |
