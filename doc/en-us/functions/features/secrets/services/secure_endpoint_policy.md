# lib/features/secrets/services/secure_endpoint_policy.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `shared.EndpointVerdict evaluateSecretsEndpoint(` | Evaluate a secret endpoint. Inputs: url, trustedHosts. Returns: Verdict. |
| `String? normalizeTrustedHost(String value) =>` | Normalize a trusted host. Inputs: value. Returns: Host or null. |
