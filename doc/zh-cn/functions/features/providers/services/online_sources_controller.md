# lib/features/providers/services/online_sources_controller.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。


## 声明

| Declaration | Purpose |
|---|---|
| `TranscribeOnlineSources(` | Bind repository. Inputs: repository, notice text, optional onSaved, clientFactory and jobModelIds (tests). Returns: Controller. |
| `Future<void> reload() async {` | Reload records. Inputs: None. Returns: Completion. |
| `void dispose() {` | End observations. Inputs: None. Returns: None. |
| `List<shared.OnlineProvider> get providers => [` | List providers with each source's ASR model records as the editor's `models` (alias only when the display name differs). Returns: Providers. |
| `Listenable get changes => this;` | Observe state. Inputs: None. Returns: Listenable. |
| `shared.OnlineProviderTemplateRegistry get templates =>` | Register protocol presets. Inputs: None. Returns: Registry. |
| `String newProviderId() => repository.newProviderId();` | Allocate record ID. Inputs: None. Returns: ID. |
| `Future<bool> hasKey(String providerId) async =>` | Check saved key. Inputs: providerId. Returns: Presence. |
| `ProviderConfig _record(shared.OnlineProvider draft) {` | Convert draft to app record. Inputs: draft. Returns: Record. |
| `Future<void> save(` | Save provider, its model records and key. New models get unknown capabilities and display name = alias or model name; existing records only change display name; removed models are deleted via `_removeDropped`. Inputs: provider, newKey, clearKey. |
| `Future<void> _removeDropped(` | Delete records of models removed in the editor, except the source default, the app default and any model a job uses; deletes nothing if jobs cannot be read. Inputs: library, previous records, kept names, default id, provider id. |
| `static Future<Set<String>> _storedJobModelIds() async => {` | Collect model ids used by saved jobs. Returns: Ids. |
| `Future<List<shared.OnlineModelEntry>> fetchModels(` | List the source's models (OpenRouter with `output_modalities=transcription`); only ids matching `_asrId` (whisper, transcribe, asr, stt, ...) are marked shown by default. Inputs: draft, draftKey. Returns: Entries. |
| `static final _asrId = RegExp(` | Recognize transcription model ids. |
| `List<shared.OnlineModelEntry> catalogModels(shared.OnlineProvider provider) =>` | Built-in catalog models; this app has none. Returns: Empty list. |
| `Future<void> remove(String providerId) async {` | Delete source and key. Inputs: providerId. Returns: Completion. |
| `Future<GenAiStatusReport> testConnection(` | Test endpoint explicitly. Inputs: draft, draftKey. Returns: Status. |
| `shared.OnlinePrivacyNotice? privacyNotice(shared.OnlineProvider provider) {` | Describe sent data. Inputs: provider. Returns: Notice. |
| `WebDavPrivacyAcknowledgementStore _consent(String id) {` | Locate consent. Inputs: id. Returns: Store. |
| `WebDavPrivacyAcknowledgementStore _consentForDraft(` | Locate draft permission. Inputs: provider. Returns: Store. |
| `Future<shared.OnlinePrivacyAcknowledgement?> acknowledgement(` | Read device consent. Inputs: providerId. Returns: Acknowledgement. |
| `Future<void> acknowledge(` | Record device consent. Inputs: providerId, record. Returns: Completion. |
