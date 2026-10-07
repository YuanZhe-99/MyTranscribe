# lib/features/secrets/views/secrets_endpoint_section.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Tell the user, on the WebDAV page, whether their API keys will |
| `String endpointReasonText(AppLocalizations l10n, EndpointReason reason) =>` | Put a policy reason into words for the user. |
| `const SecretsEndpointSection({` | Create the section. |
| `State<SecretsEndpointSection> createState() => _SecretsEndpointSectionState();` | Create the mutable state object for this widget. |
| `void initState() {` | Read this device's trusted hosts. |
| `Future<void> _load() async {` | Load the trusted hosts. |
| `Future<void> _save(List<String> hosts) async {` | Save the trusted hosts. |
| `Widget build(BuildContext context) {` | Build the section. |
| `Future<void> _add(AppLocalizations l10n) async {` | Ask for a host to trust. |
| `bool _isHost(String entry) =>` | Check that an entry is a host or a wildcard, not a URL. |
| `const _AddHostDialog();` | Create the dialog. |
| `State<_AddHostDialog> createState() => _AddHostDialogState();` | Create the dialog's state. |
| `void dispose() {` | Release the text controller. |
| `Widget build(BuildContext context) {` | Build the dialog. |
