# lib/features/providers/services/shared_online_adapter.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `shared.OnlineTranscriptionRequest onlineRequest(TranscriptionRequest request) =>` | Convert window request. Inputs: request. Returns: Shared request. |
| `shared.OnlineProvider onlineProvider(ProviderConfig provider) =>` | Convert endpoint configuration. Inputs: provider. Returns: Provider. |
| `shared.OnlineTranscriptionModel onlineModel(ModelConfig model) =>` | Convert model capabilities. Inputs: model. Returns: Shared model. |
