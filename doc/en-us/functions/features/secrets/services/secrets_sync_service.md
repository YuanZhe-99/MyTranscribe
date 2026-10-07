# lib/features/secrets/services/secrets_sync_service.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `const SecretsSyncOutcome({` | Describe an exchange. Inputs: outcome fields. Returns: Outcome. |
| `SecretsSyncService._();` | Prevent construction. Inputs: None. Returns: None. |
| `static Future<SecretsSyncOutcome> exchange(` | Exchange keys. Inputs: config, trustedHosts, clientFactory, mode. |
