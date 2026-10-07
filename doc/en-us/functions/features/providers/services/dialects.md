# lib/features/providers/services/dialects.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `ProviderDialectHandler dialectHandler(ProviderDialect dialect) =>` | Select request dialect. Inputs: dialect. Returns: Handler. |
| `const _SharedDialect(this.dialect);` | Bind a dialect. Inputs: dialect. Returns: Handler. |
| `String responseFormatFor(TranscriptionRequest request, ModelConfig model) =>` | Choose response format. Inputs: request, model. Returns: Format. |
| `bool needsJsonBody(TranscriptionRequest request, ModelConfig model) =>` | Choose upload shape. Inputs: request, model. Returns: JSON requirement. |
| `Future<http.BaseRequest> buildRequest(` | Build upload. Inputs: request, provider, model, key. Returns: HTTP request. |
| `TranscriptionResult parseResponse(String body, String format) =>` | Parse response. Inputs: body, format. Returns: Transcript. |
| `const OpenAiDialect() : super(shared.OnlineDialect.openai);` | Bind OpenAI. Inputs: None. Returns: Handler. |
| `const OpenRouterDialect() : super(shared.OnlineDialect.openrouter);` | Bind OpenRouter. Inputs: None. Returns: Handler. |
| `const OpenAiCompatibleDialect()` | Bind compatible endpoint. Inputs: None. Returns: Handler. |
