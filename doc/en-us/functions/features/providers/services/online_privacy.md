# lib/features/providers/services/online_privacy.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `static WebDavPrivacyAcknowledgementStore _store(ProviderConfig provider) {` | Locate host consent. Inputs: provider. Returns: Store. |
| `static Future<bool> allowed(ProviderConfig provider) async =>` | Gate audio requests. Inputs: provider. Returns: Consent. |
| `static Future<bool> ensure(` | Ask before online audio upload. Inputs: context, provider. |

The privacy dialog now takes its labels from `transcribeOnlineLabels` in `online_sources_page.dart`.
