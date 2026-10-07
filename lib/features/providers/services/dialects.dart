import 'package:http/http.dart' as http;
import 'package:myapps_ai_online/myapps_ai_online.dart' as shared;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'provider_dialect.dart';
import 'response_parsers.dart';
import 'shared_online_adapter.dart';

const transcriptionPath = 'audio/transcriptions';

/// Purpose: Select request dialect. Inputs: dialect. Returns: Handler.
/// Side effects: None. Notes: Wire shapes belong to shared transport.
ProviderDialectHandler dialectHandler(ProviderDialect dialect) =>
    switch (dialect) {
      ProviderDialect.openai => const OpenAiDialect(),
      ProviderDialect.openrouter => const OpenRouterDialect(),
      ProviderDialect.openaiCompatible => const OpenAiCompatibleDialect(),
    };

/// Shared dialect facade used by the application planner.
class _SharedDialect extends ProviderDialectHandler {
  final shared.OnlineDialect dialect;

  /// Purpose: Bind a dialect. Inputs: dialect. Returns: Handler.
  /// Side effects: None. Notes: Stateless.
  const _SharedDialect(this.dialect);

  /// Purpose: Choose response format. Inputs: request, model. Returns: Format.
  /// Side effects: None. Notes: Uses declared model capabilities.
  @override
  String responseFormatFor(TranscriptionRequest request, ModelConfig model) =>
      shared.transcriptionResponseFormat(
        dialect,
        onlineRequest(request),
        onlineModel(model),
      );

  /// Purpose: Choose upload shape. Inputs: request, model. Returns: JSON requirement.
  /// Side effects: None. Notes: Planner accounts for base64 size.
  @override
  bool needsJsonBody(TranscriptionRequest request, ModelConfig model) =>
      shared.transcriptionNeedsJsonBody(
        dialect,
        onlineRequest(request),
        onlineModel(model),
      );

  /// Purpose: Build upload. Inputs: request, provider, model, key. Returns: HTTP request.
  /// Side effects: Reads audio. Notes: Does not send it.
  @override
  Future<http.BaseRequest> buildRequest(
    TranscriptionRequest request,
    ProviderConfig provider,
    ModelConfig model,
    String? apiKey,
  ) => shared.buildTranscriptionRequest(
    onlineRequest(request),
    onlineProvider(provider),
    onlineModel(model),
    apiKey,
  );

  /// Purpose: Parse response. Inputs: body, format. Returns: Transcript.
  /// Side effects: None. Notes: Duration supplied by transport for real requests.
  @override
  TranscriptionResult parseResponse(String body, String format) =>
      parseTranscriptionBody(body, format, 0);
}

class OpenAiDialect extends _SharedDialect {
  /// Purpose: Bind OpenAI. Inputs: None. Returns: Handler.
  /// Side effects: None. Notes: None.
  const OpenAiDialect() : super(shared.OnlineDialect.openai);
}

class OpenRouterDialect extends _SharedDialect {
  /// Purpose: Bind OpenRouter. Inputs: None. Returns: Handler.
  /// Side effects: None. Notes: None.
  const OpenRouterDialect() : super(shared.OnlineDialect.openrouter);
}

class OpenAiCompatibleDialect extends _SharedDialect {
  /// Purpose: Bind compatible endpoint. Inputs: None. Returns: Handler.
  /// Side effects: None. Notes: None.
  const OpenAiCompatibleDialect()
    : super(shared.OnlineDialect.openaiCompatible);
}
