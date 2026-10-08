# lib/features/providers/views/online_sources_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.


## Declarations

| Declaration | Purpose |
|---|---|
| `const OnlineSourcesPage({super.key});` | Create source page. Inputs: None. Returns: Page. |
| `ConsumerState<OnlineSourcesPage> createState() => _OnlineSourcesPageState();` | Create state. Inputs: None. Returns: State. |
| `void didChangeDependencies() {` | Initialize localized controller. Inputs: None. Returns: None. |
| `void dispose() {` | Release controller. Inputs: None. Returns: None. |
| `Widget build(BuildContext context) {` | Render the shared online library (provider icons, models under each source, searchable template grid, model picker, aliases, two panes on wide windows). Inputs: context. Returns: Page. |
| `MyAppsOnlineLabels transcribeOnlineLabels(AppLocalizations l) =>` | Build all shared online-library labels (sources, templates, search, models, fetch, aliases, picker); also used by the privacy dialog. Inputs: localizations. Returns: Labels. |
