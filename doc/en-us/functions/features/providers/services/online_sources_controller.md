# lib/features/providers/services/online_sources_controller.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.


## Declarations

| Declaration | Purpose |
|---|---|
| `TranscribeOnlineSources(` | Bind repository. Inputs: repository, notice text. Returns: Controller. |
| `Future<void> reload() async {` | Reload records. Inputs: None. Returns: Completion. |
| `void dispose() {` | End observations. Inputs: None. Returns: None. |
| `List<shared.OnlineProvider> get providers => [` | List providers. Inputs: None. Returns: Providers. |
| `Listenable get changes => this;` | Observe state. Inputs: None. Returns: Listenable. |
| `shared.OnlineProviderTemplateRegistry get templates =>` | Register protocol presets. Inputs: None. Returns: Registry. |
| `String newProviderId() => repository.newProviderId();` | Allocate record ID. Inputs: None. Returns: ID. |
| `Future<bool> hasKey(String providerId) async =>` | Check saved key. Inputs: providerId. Returns: Presence. |
| `ProviderConfig _record(shared.OnlineProvider draft) {` | Convert draft to app record. Inputs: draft. Returns: Record. |
| `Future<void> save(` | Save provider and key. Inputs: provider, newKey, clearKey. |
| `Future<void> remove(String providerId) async {` | Delete source and key. Inputs: providerId. Returns: Completion. |
| `Future<GenAiStatusReport> testConnection(` | Test endpoint explicitly. Inputs: draft, draftKey. Returns: Status. |
| `shared.OnlinePrivacyNotice? privacyNotice(shared.OnlineProvider provider) {` | Describe sent data. Inputs: provider. Returns: Notice. |
| `WebDavPrivacyAcknowledgementStore _consent(String id) {` | Locate consent. Inputs: id. Returns: Store. |
| `WebDavPrivacyAcknowledgementStore _consentForDraft(` | Locate draft permission. Inputs: provider. Returns: Store. |
| `Future<shared.OnlinePrivacyAcknowledgement?> acknowledgement(` | Read device consent. Inputs: providerId. Returns: Acknowledgement. |
| `Future<void> acknowledge(` | Record device consent. Inputs: providerId, record. Returns: Completion. |
