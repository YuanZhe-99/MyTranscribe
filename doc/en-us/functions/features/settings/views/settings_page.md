# lib/features/settings/views/settings_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | The settings tab — appearance, transcription defaults, data, and |
| `const SettingsPage({super.key});` | Create a settings page instance. |
| `ConsumerState<SettingsPage> createState() => _SettingsPageState();` | Create the mutable state object for this widget. |
| `void initState() {` | Start the asynchronous reads the page needs. |
| `Future<void> _loadVersion() async {` | Read the app version for the About section. |
| `void _open(_SettingsDetail detail) {` | Open a sub-page, in the detail pane or as a pushed route. |
| `Widget _detailPage(_SettingsDetail detail) => switch (detail) {` | Build the widget for one sub-page. |
| `Future<void> _exportZip() async {` | Write the sources and models to a ZIP file the user chooses. |
| `Future<void> _importZip() async {` | Replace the sources and models from a ZIP file. |
| `Future<void> _removeAllAudio() async {` | Free space by removing every finished transcription's audio. |
| `Widget build(BuildContext context) {` | Build the settings tab. |
| `Widget _buildDetailPane(AppLocalizations l10n) {` | Build the detail pane beside the settings list. |
| `Widget _buildSettingsList(AppLocalizations l10n) {` | Build the scrolling list of settings rows. |
| `Widget _section(String title, List<Widget> children) =>` | Render one titled group of rows. |
