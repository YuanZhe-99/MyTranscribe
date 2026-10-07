# lib/features/providers/services/online_privacy.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `static WebDavPrivacyAcknowledgementStore _store(ProviderConfig provider) {` | Locate host consent. Inputs: provider. Returns: Store. |
| `static Future<bool> allowed(ProviderConfig provider) async =>` | Gate audio requests. Inputs: provider. Returns: Consent. |
| `static Future<bool> ensure(` | Ask before online audio upload. Inputs: context, provider. |
