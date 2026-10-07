# lib/features/secrets/services/secrets_sync_service.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `const SecretsSyncOutcome({` | Describe an exchange. Inputs: outcome fields. Returns: Outcome. |
| `SecretsSyncService._();` | Prevent construction. Inputs: None. Returns: None. |
| `static Future<SecretsSyncOutcome> exchange(` | Exchange keys. Inputs: config, trustedHosts, clientFactory, mode. |
