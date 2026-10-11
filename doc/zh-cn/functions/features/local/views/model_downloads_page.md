# lib/features/local/views/model_downloads_page.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

`build` 观察安装状态和控制器活动，不探测引擎。已安装表示已下载，不表示可运行。
网络、存储、损坏和解压失败使用不同文案。安装阶段提供取消，操作异常显示在界面。
运行检查仍由详情页显式触发。

| Declaration | Purpose |
|---|---|
| `const ModelDownloadsPage({super.key});` | Create downloads page. Inputs: None. Returns: Page. |
| `ConsumerState<ModelDownloadsPage> createState() => _ModelDownloadsPageState();` | Create state. Inputs: None. Returns: State. |
| `void dispose() {` | Release observations. Inputs: None. Returns: None. |
| `Widget build(BuildContext context) {` | Render shared model tiles. Inputs: context. Returns: Page. |
