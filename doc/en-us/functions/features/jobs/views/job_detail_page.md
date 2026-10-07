# lib/features/jobs/views/job_detail_page.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.


## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | Show one transcription — what it is doing, how it was divided, what |
| `const JobDetailPage({` | Create a detail page. |
| `ConsumerState<JobDetailPage> createState() => _JobDetailPageState();` | Create the mutable state object for this widget. |
| `TranscriptionJob? _freshest(JobQueueState queue, TranscriptionJob? stored) {` | Choose which copy of the job to believe. |
| `Widget build(BuildContext context) {` | Build the page. |
| `Future<void> showJobRenameDialog(` | Ask what to call one transcription. |
| `const _RenameDialog({required this.job});` | Create the dialog. |
| `State<_RenameDialog> createState() => _RenameDialogState();` | Create the dialog's state. |
| `void dispose() {` | Release the text controller. |
| `Widget build(BuildContext context) {` | Build the dialog. |
| `const _RenameButton({required this.job});` | Create the rename button. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the button. |
| `const _Body({` | Create the body. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the contents. |
| `String _placementSummary(AppLocalizations l10n, TranscriptionJob job) {` | Say where a local job's windows ran. |
| `const _StatusCard({required this.job, required this.queued});` | Create the status card. |
| `Widget build(BuildContext context) {` | Build the card. |
| `const _Actions({required this.job, required this.queued});` | Create the action row. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the buttons. |
| `Future<void> _confirmRunAgain(` | Ask before transcribing a finished recording again. |
| `const _StorageRow({required this.job});` | Create the storage row. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the row. |
| `Future<void> _confirm(` | Ask before removing the converted copy. |
| `const _DeleteButton({required this.job, required this.onDeleted});` | Create the delete button. |
| `Widget build(BuildContext context, WidgetRef ref) {` | Build the button. |
| `const _SectionTitle(this.text);` | Create a heading. |
| `Widget build(BuildContext context) => Padding(` | Build the heading. |
| `const _Field(this.label, this.value);` | Create a field row. |
| `Widget build(BuildContext context) {` | Build the row. |
