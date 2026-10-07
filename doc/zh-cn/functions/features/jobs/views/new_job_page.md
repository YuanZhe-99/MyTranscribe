# lib/features/jobs/views/new_job_page.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Set up one transcription — the recording, the model, the hints, and |
| `const NewJobPage({super.key});` | Create the new-job page. |
| `ConsumerState<NewJobPage> createState() => _NewJobPageState();` | Create the mutable state object for this widget. |
| `void dispose() {` | Release the text controllers. |
| `Future<void> _pick() async {` | Pick a recording and read what can be read about it. |
| `PlanResult? _preview(` | Work out how the chosen recording would be sent. |
| `bool get _localSpeakers =>` | Say whether a local job labels speakers. |
| `Future<void> _start(SettingsLibrary library) async {` | Create the job and start it. |
| `List<String> _split(String text) => [` | Split a comma-separated field into a list. |
| `ArtifactManifest? _installedFor(` | Find the installed package a local model would load. |
| `Widget build(BuildContext context) {` | Build the page. |
| `Widget _recordingCard(AppLocalizations l10n) {` | Build the recording chooser. |
| `Widget _sourceAndModel(AppLocalizations l10n, SettingsLibrary library) {` | Build the source and model pickers. |
| `Widget _deviceChooser(AppLocalizations l10n) {` | Build the chooser of what a local model runs on. |
| `List<Widget> _localNotes(` | Say what a local model needs before it can run, and where the |
| `Widget _optionFields(` | Build the language, context and keyword fields. |
| `Widget _switches(` | Build the speaker and keep-audio switches. |
| `Widget _planCard(AppLocalizations l10n, PlanResult? plan) {` | Build the plan preview. |
