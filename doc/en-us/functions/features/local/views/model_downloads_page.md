# lib/features/local/views/model_downloads_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

`build` observes install status and controller activity without probing engines.
Installed means downloaded, not runtime-ready. Network, storage, corruption and
unpack failures have separate labels. Install phases expose cancellation and action
exceptions are displayed. Route checking remains an explicit detail-page action.

| Declaration | Purpose |
|---|---|
| `const ModelDownloadsPage({super.key});` | Create downloads page. Inputs: None. Returns: Page. |
| `ConsumerState<ModelDownloadsPage> createState() => _ModelDownloadsPageState();` | Create state. Inputs: None. Returns: State. |
| `void dispose() {` | Release observations. Inputs: None. Returns: None. |
| `Widget build(BuildContext context) {` | Render shared model tiles. Inputs: context. Returns: Page. |
