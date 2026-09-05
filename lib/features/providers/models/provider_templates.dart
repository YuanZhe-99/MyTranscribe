/// Purpose: The sources and models the app knows about before the user
/// configures anything.
/// Inputs: None; this is data.
/// Returns: Template sources and models, and the starter presets the "add a
/// source" flow offers.
/// Side effects: None.
/// Notes: **Ids here are a compatibility contract.** They are derived, not
/// generated, so two fresh devices seed byte-identical records and the first
/// sync merges them instead of leaving two of everything. A shipped id is never
/// changed; changing one orphans every device's overrides for that record.
///
/// The capability values are what the services documented or were observed to
/// do at [templateVersion]. They will go stale — a limit is raised, a model
/// gains speaker labels — and that is expected: every field is editable, and a
/// user who corrects one keeps their correction through later template
/// refreshes. See `doc/en-us/features/provider-library.md`.
library;

import 'model_config.dart';
import 'provider_config.dart';

/// The version of the template data below.
///
/// Raise it when a template's *values* change, so
/// `SettingsRepository.applyTemplateUpdates` refreshes the fields a user has
/// not overridden. Do not raise it for a purely additive change.
const templateVersion = 1;

/// The id of the built-in OpenAI source.
const openaiProviderId = 'provider:openai';

/// The id of the built-in OpenRouter source.
const openrouterProviderId = 'provider:openrouter';

/// Purpose: Derive a model's record id from its source and wire name.
/// Inputs: [providerId], [modelName].
/// Returns: The id.
/// Side effects: None.
/// Notes: Derived so two devices agree. The source id already carries its own
/// `provider:` prefix, which is stripped here so the result reads
/// `model:openai:gpt-transcribe` rather than `model:provider:openai:…`.
String templateModelId(String providerId, String modelName) {
  final source = providerId.startsWith('provider:')
      ? providerId.substring('provider:'.length)
      : providerId;
  return 'model:$source:$modelName';
}

/// A source and the models it ships with.
class ProviderTemplate {
  /// The source itself.
  final ProviderConfig provider;

  /// Its models, in the order the library lists them.
  final List<ModelConfig> models;

  /// Purpose: Create a template.
  /// Inputs: [provider], [models].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ProviderTemplate({required this.provider, required this.models});
}

/// Purpose: Build the sources and models a fresh install starts with.
/// Inputs: None.
/// Returns: The templates, in the order the library lists them.
/// Side effects: None.
/// Notes: Only OpenAI and OpenRouter are seeded. The compatible dialect is not
/// seeded as a source because there is no address to seed it with — it is
/// offered instead as a starter preset when the user adds one.
List<ProviderTemplate> buildProviderTemplates() => [
  _openaiTemplate(),
  _openrouterTemplate(),
];

/// Purpose: The official OpenAI audio API and its transcription models.
/// Inputs: None.
/// Returns: The template.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ProviderTemplate _openaiTemplate() {
  const providerId = openaiProviderId;
  ModelConfig model(
    String wireName, {
    required String display,
    int? maxDurationSeconds,
    Capability diarization = Capability.unsupported,
    Capability wordTimestamps = Capability.unsupported,
    Capability segmentTimestamps = Capability.unsupported,
    bool prompt = false,
    bool keywords = false,
    LanguageParamStyle languageStyle = LanguageParamStyle.language,
    List<String> responseFormats = const ['json'],
    int? maxKnownSpeakers,
    bool requiresChunkingStrategy = false,
  }) => ModelConfig(
    id: templateModelId(providerId, wireName),
    providerId: providerId,
    templateId: wireName,
    modelName: wireName,
    displayName: display,
    maxFileBytes: _twentyFiveMegabytes,
    maxDurationSeconds: maxDurationSeconds,
    diarization: diarization,
    wordTimestamps: wordTimestamps,
    segmentTimestamps: segmentTimestamps,
    supportsPrompt: prompt,
    supportsKeywords: keywords,
    languageParamStyle: languageStyle,
    responseFormats: responseFormats,
    maxKnownSpeakers: maxKnownSpeakers,
    requiresChunkingStrategy: requiresChunkingStrategy,
    templateVersion: templateVersion,
  );

  return ProviderTemplate(
    provider: const ProviderConfig(
      id: providerId,
      name: 'OpenAI',
      templateId: 'openai',
      dialect: ProviderDialect.openai,
      baseUrl: 'https://api.openai.com/v1',
      maxFileBytes: _twentyFiveMegabytes,
      defaultModelId: 'model:openai:gpt-transcribe',
      templateVersion: templateVersion,
    ),
    models: [
      // Takes a *list* of languages rather than one, which is the whole reason
      // `languageParamStyle` exists as a field. No timestamps of any kind.
      model(
        'gpt-transcribe',
        display: 'GPT Transcribe',
        prompt: true,
        keywords: true,
        languageStyle: LanguageParamStyle.languages,
        responseFormats: const ['json', 'text'],
      ),
      // The per-request audio cap on this family is reported rather than
      // documented, which is exactly why it is a field the user can correct.
      model(
        'gpt-4o-transcribe',
        display: 'GPT-4o Transcribe',
        maxDurationSeconds: 1500,
        prompt: true,
        responseFormats: const ['json', 'text'],
      ),
      model(
        'gpt-4o-mini-transcribe',
        display: 'GPT-4o mini Transcribe',
        maxDurationSeconds: 1500,
        prompt: true,
        responseFormats: const ['json', 'text'],
      ),
      // The only model here that returns times, and the only one that can
      // produce subtitles without the app inventing them.
      model(
        'whisper-1',
        display: 'Whisper',
        prompt: true,
        wordTimestamps: Capability.supported,
        segmentTimestamps: Capability.supported,
        responseFormats: const ['verbose_json', 'json', 'text'],
      ),
      // Speaker labels, and reference clips so a speaker keeps one identity
      // across windows. Takes no prompt.
      model(
        'gpt-4o-transcribe-diarize',
        display: 'GPT-4o Transcribe (speakers)',
        maxDurationSeconds: 1500,
        diarization: Capability.supported,
        segmentTimestamps: Capability.supported,
        responseFormats: const ['diarized_json', 'json', 'text'],
        maxKnownSpeakers: 4,
        requiresChunkingStrategy: true,
      ),
    ],
  );
}

/// Purpose: OpenRouter and a few of its transcription models.
/// Inputs: None.
/// Returns: The template.
/// Side effects: None.
/// Notes: Internal helper used within this file only. The source carries a
/// `maxRequestSeconds` because the gateway gives up on a long upstream request
/// regardless of the model behind it — a limit that belongs to the provider,
/// not to any one model, and the reason that field exists.
ProviderTemplate _openrouterTemplate() {
  const providerId = openrouterProviderId;
  ModelConfig model(
    String wireName, {
    required String display,
    int? maxDurationSeconds,
    Capability diarization = Capability.unknown,
    Capability wordTimestamps = Capability.unknown,
    Capability segmentTimestamps = Capability.unknown,
    bool keywords = false,
    List<String> responseFormats = const ['json'],
  }) => ModelConfig(
    id: templateModelId(providerId, wireName),
    providerId: providerId,
    templateId: wireName,
    modelName: wireName,
    displayName: display,
    maxFileBytes: _twentyFiveMegabytes,
    maxDurationSeconds: maxDurationSeconds,
    diarization: diarization,
    wordTimestamps: wordTimestamps,
    segmentTimestamps: segmentTimestamps,
    // The gateway accepts a prompt field and ignores it, which is worse than
    // rejecting it: the user would see their context accepted and have no idea
    // it was dropped. Marked unsupported so the app does not offer it.
    supportsPrompt: false,
    supportsKeywords: keywords,
    responseFormats: responseFormats,
    inputFormats: const [
      'mp3',
      'wav',
      'flac',
      'm4a',
      'ogg',
      'webm',
      'aac',
      'mp4',
    ],
    templateVersion: templateVersion,
  );

  return ProviderTemplate(
    provider: const ProviderConfig(
      id: providerId,
      name: 'OpenRouter',
      templateId: 'openrouter',
      dialect: ProviderDialect.openrouter,
      baseUrl: 'https://openrouter.ai/api/v1',
      maxFileBytes: _twentyFiveMegabytes,
      // The gateway stops waiting on a long upstream request, so every model
      // behind it needs shorter windows than the model itself would take.
      maxRequestSeconds: 600,
      defaultModelId: 'model:openrouter:microsoft/mai-transcribe-2',
      templateVersion: templateVersion,
    ),
    models: [
      // Speaker labels and keyword biasing, both through the gateway's
      // provider-options mechanism, which needs a JSON request rather than a
      // multipart one.
      model(
        'microsoft/mai-transcribe-2',
        display: 'MAI-Transcribe 2',
        diarization: Capability.supported,
        wordTimestamps: Capability.supported,
        segmentTimestamps: Capability.supported,
        keywords: true,
        responseFormats: const ['verbose_json', 'json'],
      ),
      model('microsoft/mai-transcribe-1.5', display: 'MAI-Transcribe 1.5'),
      model(
        'openai/gpt-transcribe',
        display: 'GPT Transcribe',
        diarization: Capability.unsupported,
      ),
      model(
        'openai/gpt-4o-transcribe',
        display: 'GPT-4o Transcribe',
        maxDurationSeconds: 1500,
        diarization: Capability.unsupported,
      ),
      model(
        'openai/whisper-large-v3',
        display: 'Whisper large v3',
        segmentTimestamps: Capability.supported,
        responseFormats: const ['verbose_json', 'json'],
      ),
    ],
  );
}

/// A prefilled source the "add a source" sheet offers.
///
/// Not seeded, because the user may want none of them, and an unwanted source
/// with no key is clutter in a list they will look at often.
class ProviderPreset {
  /// What to call it in the sheet.
  final String label;

  /// One line saying what it is.
  final String description;

  /// The source, minus its id, which is generated when it is added.
  final ProviderConfig template;

  /// A model to add alongside it, or null to start empty.
  final ModelConfig? model;

  /// Purpose: Create a starter preset.
  /// Inputs: [label], [description], [template], optional [model].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ProviderPreset({
    required this.label,
    required this.description,
    required this.template,
    this.model,
  });
}

/// Purpose: The prefilled sources offered when adding one.
/// Inputs: None.
/// Returns: The presets, in the order the sheet lists them.
/// Side effects: None.
/// Notes: Every one is marked *unverified* in the interface: they are a
/// starting point for an address and a model name, not a promise about what
/// that service does. Their capabilities are deliberately left unknown, which
/// is what makes the app offer a feature with a warning rather than hide it.
List<ProviderPreset> buildProviderPresets() => [
  ProviderPreset(
    label: 'Local server',
    description:
        'whisper.cpp, faster-whisper, or anything else on this machine or '
        'your own network. Usually needs no key.',
    template: const ProviderConfig(
      id: '',
      name: 'Local server',
      dialect: ProviderDialect.openaiCompatible,
      baseUrl: 'http://127.0.0.1:8080/v1',
      authScheme: AuthScheme.none,
      templateVersion: templateVersion,
    ),
    model: const ModelConfig(
      id: '',
      providerId: '',
      modelName: 'whisper-1',
      displayName: 'Whisper',
      segmentTimestamps: Capability.unknown,
      responseFormats: ['verbose_json', 'json'],
    ),
  ),
  ProviderPreset(
    label: 'Groq',
    description: 'A fast hosted Whisper.',
    template: const ProviderConfig(
      id: '',
      name: 'Groq',
      dialect: ProviderDialect.openaiCompatible,
      baseUrl: 'https://api.groq.com/openai/v1',
      maxFileBytes: _twentyFiveMegabytes,
      templateVersion: templateVersion,
    ),
    model: const ModelConfig(
      id: '',
      providerId: '',
      modelName: 'whisper-large-v3-turbo',
      displayName: 'Whisper large v3 turbo',
      maxFileBytes: _twentyFiveMegabytes,
      segmentTimestamps: Capability.unknown,
      responseFormats: ['verbose_json', 'json'],
    ),
  ),
  ProviderPreset(
    label: 'Mistral',
    description: 'Voxtral.',
    template: const ProviderConfig(
      id: '',
      name: 'Mistral',
      dialect: ProviderDialect.openaiCompatible,
      baseUrl: 'https://api.mistral.ai/v1',
      templateVersion: templateVersion,
    ),
    model: const ModelConfig(
      id: '',
      providerId: '',
      modelName: 'voxtral-mini-latest',
      displayName: 'Voxtral mini',
    ),
  ),
  ProviderPreset(
    label: 'Something else',
    description: 'Any endpoint that speaks the OpenAI transcription protocol.',
    template: const ProviderConfig(
      id: '',
      name: '',
      dialect: ProviderDialect.openaiCompatible,
      baseUrl: '',
      templateVersion: templateVersion,
    ),
  ),
];

/// The upload limit every one of these services states.
const _twentyFiveMegabytes = 25 * 1024 * 1024;
