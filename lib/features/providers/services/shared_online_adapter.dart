import 'package:myapps_ai_online/myapps_ai_online.dart' as shared;

import '../models/model_config.dart';
import '../models/provider_config.dart';
import 'provider_dialect.dart';

/// Purpose: Convert window request. Inputs: request. Returns: Shared request.
/// Side effects: None. Notes: Preserves the caller's selected speaker samples.
shared.OnlineTranscriptionRequest onlineRequest(TranscriptionRequest request) =>
    shared.OnlineTranscriptionRequest(
      audioPath: request.file.path,
      languages: request.languages,
      prompt: request.prompt,
      keywords: request.keywords,
      diarize: request.diarize,
      wantTimestamps: request.wantTimestamps,
      knownSpeakers: [
        for (final speaker in request.knownSpeakers)
          shared.OnlineKnownSpeaker(
            id: speaker.id,
            samplePath: speaker.sample.path,
          ),
      ],
    );

/// Purpose: Convert endpoint configuration. Inputs: provider. Returns: Provider.
/// Side effects: None. Notes: Persistence remains application-owned.
shared.OnlineProvider onlineProvider(ProviderConfig provider) =>
    shared.OnlineProvider(
      id: provider.id,
      name: provider.name,
      templateId: provider.templateId,
      dialect: shared.OnlineDialect.values.byName(provider.dialect.name),
      baseUrl: provider.baseUrl,
      authScheme: shared.OnlineAuthScheme.values.byName(
        provider.authScheme.name,
      ),
      authHeaderName: provider.authHeaderName,
      headers: provider.extraHeaders,
      requestTimeoutSeconds: provider.requestTimeoutSeconds,
    );

/// Purpose: Convert model capabilities. Inputs: model. Returns: Shared model.
/// Side effects: None. Notes: Unknown capabilities remain unknown.
shared.OnlineTranscriptionModel onlineModel(ModelConfig model) =>
    shared.OnlineTranscriptionModel(
      modelName: model.modelName,
      diarization: shared.OnlineCapability.values.byName(
        model.diarization.name,
      ),
      segmentTimestamps: shared.OnlineCapability.values.byName(
        model.segmentTimestamps.name,
      ),
      supportsPrompt: model.supportsPrompt,
      supportsKeywords: model.supportsKeywords,
      languageStyle: shared.OnlineLanguageStyle.values.byName(
        model.languageParamStyle.name,
      ),
      responseFormats: model.responseFormats,
      maxKnownSpeakers: model.maxKnownSpeakers,
      requiresChunkingStrategy: model.requiresChunkingStrategy,
    );
