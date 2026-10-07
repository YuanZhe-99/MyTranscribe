# lib/features/providers/services/transcription_client.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `TranscriptionClient({` | Create transport. Inputs: clientFactory, sleep. Returns: Client. |
| `Future<TranscriptionResult> transcribe({` | Transcribe a window. Inputs: request, provider, model, key, duration. |
| `void cancel() => _client.cancel();` | Stop the request. Inputs: None. Returns: None. |
