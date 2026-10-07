# lib/shared/views/webdav_config_page.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Configure the user's WebDAV server and run syncs by hand. |
| `const WebDAVConfigPage({super.key});` | Create a WebDAV config page instance. |
| `ConsumerState<WebDAVConfigPage> createState() => _WebDAVConfigPageState();` | Create the mutable state object for this widget. |
| `void initState() {` | Subscribe to sync status and start the configuration read. |
| `void _refreshSyncStatus() {` | Refresh this page when background sync status changes. |
| `Future<void> _loadConfig() async {` | Fill the form from the stored configuration. |
| `void dispose() {` | Release listeners and controllers. |
| `WebDAVConfig get _currentConfig => WebDAVConfig(` | Build a config from what the form currently holds. |
| `Future<void> _saveConfig() async {` | Persist the form and start a sync when auto-sync is on. |
| `Future<void> _testConnection() async {` | Check that the server answers with these credentials. |
| `Future<void> _syncNow() async {` | Run a two-way sync now. |
| `Future<void> _showSyncResult(SyncResult result) async {` | Present a non-conflict sync or force result to the user. |
| `Future<void> _forceUpload() async {` | Confirm and run a force upload (local overwrites remote). |
| `Future<void> _forceDownload() async {` | Confirm and run a force download (remote overwrites local). |
| `Future<bool?> _confirmForceAction({` | Ask the user to confirm a destructive force upload or download. |
| `String _progressText(AppLocalizations l10n, SyncProgress progress) {` | Map a sync progress snapshot to a localized status line. |
| `Future<void> _resolveConflicts(SyncResult result) async {` | Ask the user to resolve each pending conflict, then upload. |
| `Future<void> _disconnect() async {` | Forget the stored server and clear the form. |
| `void _fillNextcloud() {` | Prefill the form with Nextcloud's URL shape. |
| `String? _syncStatusText(AppLocalizations l10n) {` | Build a short sync health summary for display. |
| `Widget build(BuildContext context) {` | Build the current widget subtree for the active UI state. |
