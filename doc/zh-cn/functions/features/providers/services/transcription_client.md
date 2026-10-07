# lib/features/providers/services/transcription_client.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `TranscriptionClient({` | Create transport. Inputs: clientFactory, sleep. Returns: Client. |
| `Future<TranscriptionResult> transcribe({` | Transcribe a window. Inputs: request, provider, model, key, duration. |
| `void cancel() => _client.cancel();` | Stop the request. Inputs: None. Returns: None. |
