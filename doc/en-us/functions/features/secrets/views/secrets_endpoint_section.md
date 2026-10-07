# lib/features/secrets/views/secrets_endpoint_section.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

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
