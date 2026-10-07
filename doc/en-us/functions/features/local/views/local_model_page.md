# lib/features/local/views/local_model_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

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
