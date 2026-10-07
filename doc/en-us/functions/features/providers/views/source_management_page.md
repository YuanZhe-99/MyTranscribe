# lib/features/providers/views/source_management_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | The library tab — the services the app can use, and the models each |
| `const LibrarySelection();` | Allow subclasses only. |
| `const ProviderSelection(this.providerId);` | Select a source. |
| `const ModelSelection(this.modelId);` | Select a model. |
| `const LocalModelSelection(this.modelId);` | Create the selection. |
| `const SourceManagementPage({` | Create a library page instance. |
| `ConsumerState<SourceManagementPage> createState() => _LibraryPageState();` | Create the mutable state object for this widget. |
| `void _open(LibrarySelection selection) {` | Open a source or model, in the pane or as a pushed route. |
| `Widget _editor(LibrarySelection selection) => switch (selection) {` | Build the editor for a selection. |
| `Widget build(BuildContext context) {` | Build the library tab. |
| `Widget _addButton(AppLocalizations l10n) => FloatingActionButton.extended(` | Build the button that adds a source. |
| `Future<void> _addSource() async {` | Add a source from one of the starter presets. |
| `Widget _buildList(AppLocalizations l10n) {` | Build the grouped list of sources and their models. |
| `List<Widget> _thisDeviceSection(AppLocalizations l10n, SettingsLibrary data) {` | Build the section of models that run on this device. |
| `List<Widget> _sourceSection(` | Build one source header and its models. |
| `Widget? _modelBadges(ModelConfig model) {` | Show at a glance what a model can do. |
| `Widget _buildEditorPane(AppLocalizations l10n) {` | Build the editor pane beside the list. |
