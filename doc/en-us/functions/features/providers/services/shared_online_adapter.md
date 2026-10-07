# lib/features/providers/services/shared_online_adapter.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `shared.OnlineTranscriptionRequest onlineRequest(TranscriptionRequest request) =>` | Convert window request. Inputs: request. Returns: Shared request. |
| `shared.OnlineProvider onlineProvider(ProviderConfig provider) =>` | Convert endpoint configuration. Inputs: provider. Returns: Provider. |
| `shared.OnlineTranscriptionModel onlineModel(ModelConfig model) =>` | Convert model capabilities. Inputs: model. Returns: Shared model. |
