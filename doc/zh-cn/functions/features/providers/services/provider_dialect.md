# lib/features/providers/services/provider_dialect.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | Turn one transcription request into an HTTP request, and one HTTP |
| `const KnownSpeaker({required this.id, required this.sample});` | Create a known speaker reference. |
| `const TranscriptionRequest({` | Describe one window to transcribe. |
| `const RawSegment({` | Create a raw segment. |
| `const TranscriptionResult({` | Create a result. |
| `const TranscriptionException(` | Create a transcription exception. |
| `const ProviderDialectHandler();` | Allow subclasses to be const. |
| `Future<http.BaseRequest> buildRequest(` | Build the HTTP request for one window. |
| `TranscriptionResult parseResponse(String body, String format);` | Read one reply. |
| `String responseFormatFor(TranscriptionRequest request, ModelConfig model);` | Say which reply format this request should ask for. |
| `bool needsJsonBody(TranscriptionRequest request, ModelConfig model) => false;` | Say whether this request must travel as JSON rather than |
| `String mimeTypeForPath(String path) {` | Guess a media type from a file extension. |
| `String audioFormatForPath(String path) {` | Name the audio format the way a JSON request expects it. |
| `Map<String, String> authHeaders(ProviderConfig provider, String? apiKey) {` | Build the authentication headers for a source. |
