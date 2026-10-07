# lib/features/secrets/models/provider_secrets.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | The API keys file, and the rule for merging two copies of it. |
| `const ProviderSecret({` | Create a stored key. |
| `bool get hasKey => apiKey != null && apiKey!.isNotEmpty;` | Report whether a usable key is present. |
| `factory ProviderSecret.fromJson(Map<String, dynamic> json) {` | Parse one entry. |
| `Map<String, dynamic> toJson() => {` | Serialize one entry. |
| `const SecretsFile({this.keys = const {}, this.extraJson = const {}});` | Create a secrets file. |
| `factory SecretsFile.fromJson(Map<String, dynamic> json) {` | Parse the file. |
| `Map<String, dynamic> toJson() => {` | Serialize the file. |
| `String? keyFor(String providerId) {` | Read one source's key. |
| `SecretsFile withKey(String providerId, String? apiKey, {DateTime? now}) {` | Set or clear one source's key. |
| `Set<String> get configuredProviders => {` | List the sources that currently have a key. |
| `SecretsFile mergeSecrets(SecretsFile local, SecretsFile remote) {` | Merge two copies of the keys file, per source, by recency. |
