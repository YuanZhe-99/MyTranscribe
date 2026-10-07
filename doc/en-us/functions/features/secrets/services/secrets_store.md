# lib/features/secrets/services/secrets_store.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `SecretsStore._();` | Prevent construction. Inputs: None. Returns: None. |
| `static Future<SecretsFile> load() async =>` | Read keys. Inputs: None. Returns: Secrets. |
| `static Future<T> withLock<T>(Future<T> Function() action) =>` | Serialize a mutation. Inputs: action. Returns: Result. |
| `static Future<SecretsFile> loadForWrite() async =>` | Read before mutation. Inputs: None. Returns: Secrets. |
| `static Future<void> save(SecretsFile secrets) =>` | Save and notify sync. Inputs: secrets. Returns: Completion. |
| `static Future<void> saveQuiet(SecretsFile secrets) =>` | Save without notification. Inputs: secrets. Returns: Completion. |
| `static Future<String?> keyFor(String providerId) =>` | Read one key. Inputs: providerId. Returns: Key. |
| `static Future<void> setKey(String providerId, String? apiKey) =>` | Set or clear a key. Inputs: providerId, apiKey. Returns: Completion. |
| `static Future<void> deleteAll() => sharedStore.deleteAll();` | Forget all local keys. Inputs: None. Returns: Completion. |
| `String encodeSecrets(SecretsFile secrets) =>` | Encode compatible secret bytes. Inputs: secrets. Returns: JSON. |
