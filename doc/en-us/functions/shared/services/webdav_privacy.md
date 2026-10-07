# lib/shared/services/webdav_privacy.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `static Future<bool> allowed() async =>` | Gate network access. Inputs: None. Returns: Consent. |
| `static Future<WebDavPrivacyStatus> status(bool configured) async =>` | Explain sync readiness. Inputs: configured. Returns: Status. |
| `static Future<bool> ensure(BuildContext context, WebDAVConfig config) async {` | Ask before sync or connection tests. Inputs: context, config. |
