# lib/features/secrets/services/secure_endpoint_policy.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `shared.EndpointVerdict evaluateSecretsEndpoint(` | Evaluate a secret endpoint. Inputs: url, trustedHosts. Returns: Verdict. |
| `String? normalizeTrustedHost(String value) =>` | Normalize a trusted host. Inputs: value. Returns: Host or null. |
