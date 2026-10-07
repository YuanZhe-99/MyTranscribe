# lib/features/providers/widgets/api_key_field.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Enter, replace or remove one source's API key. |
| `const ApiKeyField({super.key, required this.providerId});` | Create the key field. |
| `ConsumerState<ApiKeyField> createState() => _ApiKeyFieldState();` | Create the mutable state object for this widget. |
| `void dispose() {` | Release the controller. |
| `Future<void> _save() async {` | Store what the user typed. |
| `Future<void> _clear() async {` | Remove the stored key. |
| `Widget build(BuildContext context) {` | Build the key field and its status. |
