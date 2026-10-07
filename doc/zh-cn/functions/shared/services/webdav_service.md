# lib/shared/services/webdav_service.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | MyTranscribe's WebDAV sync API, a thin facade over the shared |
| `const SyncResult({` | Create a sync result instance. |
| `bool get hasConflicts => pending != null;` | Report whether the result carries unresolved conflicts. |
| `SyncResult withSecrets(SecretsSyncOutcome outcome) => SyncResult(` | Attach the keys outcome to a finished sync. |
| `SyncResult withAudio(AudioSyncOutcome outcome) => SyncResult(` | Attach the audio outcome to a finished sync. |
| `SyncResult withWarnings(List<String> extra) => extra.isEmpty` | Add the warnings the transcript apply step produced. |
| `const PendingSync({` | Create a pending sync instance. |
| `List<RecordConflict<SettingsRecord>> get allConflicts => [` | List every settings conflict. |
| `List<SyncConflictView> get conflictViews => [` | Describe every conflict the user has to decide, in order. |
| `static bool consumeLocalDataChanged() => _engine.consumeLocalDataChanged();` | Read and clear the "local data changed" signal. |
| `static Future<shared.WebDAVConfig?> loadConfig() => _engine.loadConfig();` | Load the saved WebDAV configuration. |
| `static Future<void> saveConfig(shared.WebDAVConfig config) =>` | Save the WebDAV configuration. |
| `static Future<void> deleteConfig() => _engine.deleteConfig();` | Delete the saved WebDAV configuration. |
| `static Future<bool> testConnection(shared.WebDAVConfig config) async =>` | Check that the server is reachable with these credentials. |
| `static Future<SyncResult> sync(` | Run a full two-way sync under the remote upload lock. |
| `static Future<bool> finalizePendingSync(` | Finalize sync by applying the user's conflict resolutions. |
| `static Future<SyncResult> forceUpload(shared.WebDAVConfig config) async {` | Overwrite remote data with local data, without merging. |
| `static Future<SyncResult> forceDownload(shared.WebDAVConfig config) async {` | Overwrite local data with remote data, without merging. |
| `static Future<TranscriptApplyOutcome> _applyTranscripts({` | Write whatever the engine produced back into the job folders. |
| `static Future<AudioSyncOutcome> _exchangeAudio(` | Exchange the converted audio after a sync, when asked to. |
| `static Future<SecretsSyncOutcome> _exchangeSecrets(` | Exchange the API keys after a sync, when the address allows it. |
| `static SyncResult _toSyncResult(shared.EngineSyncResult result) {` | Convert an engine result into the app-typed result. |
