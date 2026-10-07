# lib/features/providers/views/provider_editor_page.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Edit one source — its address, how to authenticate, and its key. |
| `const ProviderEditorPage({super.key, required this.providerId});` | Create the source editor. |
| `ConsumerState<ProviderEditorPage> createState() => _ProviderEditorPageState();` | Create the mutable state object for this widget. |
| `void dispose() {` | Release the text controllers. |
| `void _fill(ProviderConfig provider) {` | Fill the fields from the record, once. |
| `Future<void> _save() async {` | Save the edited source. |
| `Future<void> _reset() async {` | Put this source back to its built-in values. |
| `Future<void> _importModels(ProviderConfig provider) async {` | Ask the source what models it offers and add the chosen ones. |
| `Future<void> _delete() async {` | Delete this source and its models. |
| `Future<void> _addModel(ProviderConfig provider) async {` | Add an empty model to this source. |
| `Widget build(BuildContext context) {` | Build the source editor. |
| `const _ModelPickerDialog({required this.entries});` | Create the picker. |
| `Widget build(BuildContext context) {` | Build the picker. |
