# lib/features/local/views/local_model_page.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | One local model on this device: what it is, whether it is here, |
| `const LocalModelPage({super.key, required this.modelId});` | Create the page. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the page. |
| `Future<void> _confirmDownload(` | Ask before downloading, naming the size and the host. |
| `Future<void> _confirmRemove(` | Ask before removing the model's files. |
| `Future<void> _verify(` | Hash the installed files and say whether they are intact. |
| `const _RouteCard({` | Create the card. |
| `Widget build(BuildContext context) {` | Build the card. |
| `const _Field(this.label, this.value);` | Create a field row. |
| `Widget build(BuildContext context) {` | Build the row. |
