/// Purpose: A transcription model, and what it can actually do.
/// Inputs: The `payload` of a settings record of kind `model`.
/// Returns: The `ModelConfig` value type and its enums.
/// Side effects: None.
/// Notes: The capability fields are not documentation — the chunk planner reads
/// them to decide how to split a recording, and the request builder reads them
/// to decide what to send. Every one is editable, because a service can raise a
/// limit or gain a feature between releases and the user should not have to
/// wait for a new build. See `doc/en-us/features/provider-library.md`.
library;

/// Whether a model can do something.
///
/// Three values, not two. **Unknown is a real answer**: for an endpoint the
/// user configured themselves the app genuinely does not know, and the honest
/// thing is to offer the feature with a warning rather than hide it or promise
/// it.
enum Capability {
  /// The model does this.
  supported,

  /// The model does not.
  unsupported,

  /// Nobody has established either way.
  unknown;

  /// Purpose: Parse a persisted capability.
  /// Inputs: [value].
  /// Returns: The capability; anything unrecognised reads as [unknown].
  /// Side effects: None.
  /// Notes: Unknown is the right fallback for an unreadable value too — it is
  /// exactly the state "we cannot say".
  static Capability parse(Object? value) {
    for (final capability in Capability.values) {
      if (capability.name == value) return capability;
    }
    return unknown;
  }

  /// Purpose: Report whether the app should offer this feature.
  /// Inputs: None.
  /// Returns: `bool` — true unless the model is known not to do it.
  /// Side effects: None.
  /// Notes: Unknown counts as offerable, with a warning at the point of use.
  bool get mayOffer => this != unsupported;
}

/// How a model takes a language hint.
enum LanguageParamStyle {
  /// A list, so a recording that switches language can say so. What
  /// `gpt-transcribe` wants.
  languages,

  /// A single code, which is what most endpoints accept.
  language,

  /// No hint at all.
  none;

  /// Purpose: Parse a persisted style.
  /// Inputs: [value].
  /// Returns: The style; unrecognised values read as [language].
  /// Side effects: None.
  /// Notes: The single code is the fallback because it is the most widely
  /// accepted form, and sending one where none was wanted is usually ignored.
  static LanguageParamStyle parse(Object? value) {
    for (final style in LanguageParamStyle.values) {
      if (style.name == value) return style;
    }
    return language;
  }
}

/// Keys this build writes into a model payload.
const _knownKeys = {
  'providerId',
  'templateId',
  'modelName',
  'displayName',
  'maxFileBytes',
  'maxDurationSeconds',
  'diarization',
  'wordTimestamps',
  'segmentTimestamps',
  'supportsPrompt',
  'supportsKeywords',
  'languageParamStyle',
  'responseFormats',
  'inputFormats',
  'maxKnownSpeakers',
  'requiresChunkingStrategy',
  'overriddenFields',
  'templateVersion',
};

/// The formats a model can be asked to reply in, where none is stated.
const _defaultResponseFormats = ['json'];

/// The container formats the OpenAI audio API documents, used where a model
/// states nothing more specific.
const _defaultInputFormats = [
  'mp3',
  'mp4',
  'mpeg',
  'mpga',
  'm4a',
  'wav',
  'webm',
];

/// One transcription model offered by a source.
class ModelConfig {
  /// The settings record id, e.g. `model:openai:gpt-transcribe`.
  final String id;

  /// The source this belongs to.
  final String providerId;

  /// The template this came from, or null when the user added it.
  final String? templateId;

  /// The identifier sent on the wire as `model`.
  final String modelName;

  /// What the user sees.
  final String displayName;

  /// The largest upload this model accepts, in bytes, or null for no limit.
  final int? maxFileBytes;

  /// The longest audio one request may carry, in seconds, or null for none.
  ///
  /// Some of these are documented and some are established by trying; either
  /// way the user can correct the value, which is why it lives here rather than
  /// in a constant.
  final int? maxDurationSeconds;

  /// Whether the model can say who is speaking.
  final Capability diarization;

  /// Whether it can return a time for each word.
  final Capability wordTimestamps;

  /// Whether it can return a time range for each segment.
  ///
  /// Separate from [wordTimestamps] because most models that time anything time
  /// segments and not words, and segment times are what the transcript viewer
  /// and the subtitle exports actually need.
  final Capability segmentTimestamps;

  /// Whether it accepts free-text context.
  final bool supportsPrompt;

  /// Whether it accepts a list of terms to listen for.
  final bool supportsKeywords;

  /// How it takes a language hint.
  final LanguageParamStyle languageParamStyle;

  /// The reply formats it accepts, most preferred first.
  final List<String> responseFormats;

  /// The container formats it accepts as input.
  ///
  /// Read by the planner: a recording already in one of these, and small
  /// enough, is uploaded untouched with no FFmpeg involved at all.
  final List<String> inputFormats;

  /// How many known speakers a request may carry, where that is supported.
  final int? maxKnownSpeakers;

  /// Whether a diarizing request must state a chunking strategy.
  final bool requiresChunkingStrategy;

  /// Fields the user changed away from the template.
  final Set<String> overriddenFields;

  /// The template version this record was last refreshed from.
  final int templateVersion;

  /// Payload fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a model configuration.
  /// Inputs: All fields; [id], [providerId] and [modelName] are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: Capabilities default to [Capability.unknown], which is the honest
  /// state for a model nobody has described.
  const ModelConfig({
    required this.id,
    required this.providerId,
    required this.modelName,
    String? displayName,
    this.templateId,
    this.maxFileBytes,
    this.maxDurationSeconds,
    this.diarization = Capability.unknown,
    this.wordTimestamps = Capability.unknown,
    this.segmentTimestamps = Capability.unknown,
    this.supportsPrompt = false,
    this.supportsKeywords = false,
    this.languageParamStyle = LanguageParamStyle.language,
    this.responseFormats = _defaultResponseFormats,
    this.inputFormats = _defaultInputFormats,
    this.maxKnownSpeakers,
    this.requiresChunkingStrategy = false,
    this.overriddenFields = const {},
    this.templateVersion = 0,
    this.extraJson = const {},
  }) : displayName = displayName ?? modelName;

  /// Purpose: Read a model from a settings record payload.
  /// Inputs: [id] the record id, [payload] its fields.
  /// Returns: A [ModelConfig].
  /// Side effects: None.
  /// Notes: Every field falls back rather than throwing, for the same reason
  /// [ProviderConfig.fromPayload] does.
  factory ModelConfig.fromPayload(String id, Map<String, dynamic> payload) {
    final modelName = _string(payload['modelName']) ?? '';
    return ModelConfig(
      id: id,
      providerId: _string(payload['providerId']) ?? '',
      templateId: _string(payload['templateId']),
      modelName: modelName,
      displayName: _string(payload['displayName']) ?? modelName,
      maxFileBytes: _positiveInt(payload['maxFileBytes']),
      maxDurationSeconds: _positiveInt(payload['maxDurationSeconds']),
      diarization: Capability.parse(payload['diarization']),
      wordTimestamps: Capability.parse(payload['wordTimestamps']),
      segmentTimestamps: Capability.parse(payload['segmentTimestamps']),
      supportsPrompt: payload['supportsPrompt'] == true,
      supportsKeywords: payload['supportsKeywords'] == true,
      languageParamStyle: LanguageParamStyle.parse(
        payload['languageParamStyle'],
      ),
      responseFormats: _stringList(
        payload['responseFormats'],
        _defaultResponseFormats,
      ),
      inputFormats: _stringList(payload['inputFormats'], _defaultInputFormats),
      maxKnownSpeakers: _positiveInt(payload['maxKnownSpeakers']),
      requiresChunkingStrategy: payload['requiresChunkingStrategy'] == true,
      overriddenFields: _stringSet(payload['overriddenFields']),
      templateVersion: _positiveInt(payload['templateVersion']) ?? 0,
      extraJson: {
        for (final e in payload.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Write the model as a settings record payload.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Unknown fields first, so a known key wins a collision.
  Map<String, dynamic> toPayload() => {
    ...extraJson,
    'providerId': providerId,
    if (templateId != null) 'templateId': templateId,
    'modelName': modelName,
    'displayName': displayName,
    if (maxFileBytes != null) 'maxFileBytes': maxFileBytes,
    if (maxDurationSeconds != null) 'maxDurationSeconds': maxDurationSeconds,
    'diarization': diarization.name,
    'wordTimestamps': wordTimestamps.name,
    'segmentTimestamps': segmentTimestamps.name,
    'supportsPrompt': supportsPrompt,
    'supportsKeywords': supportsKeywords,
    'languageParamStyle': languageParamStyle.name,
    'responseFormats': responseFormats,
    'inputFormats': inputFormats,
    if (maxKnownSpeakers != null) 'maxKnownSpeakers': maxKnownSpeakers,
    'requiresChunkingStrategy': requiresChunkingStrategy,
    if (overriddenFields.isNotEmpty)
      'overriddenFields': (overriddenFields.toList()..sort()),
    'templateVersion': templateVersion,
  };

  /// Purpose: Return a copy with some fields replaced, marking what changed.
  /// Inputs: The fields to change, and a `clear` flag per nullable one.
  /// Returns: A new [ModelConfig].
  /// Side effects: None.
  /// Notes: Every changed field joins [overriddenFields] unless
  /// `markOverridden` is false, which only the template refresh passes.
  ModelConfig copyWith({
    String? modelName,
    String? displayName,
    int? maxFileBytes,
    bool clearMaxFileBytes = false,
    int? maxDurationSeconds,
    bool clearMaxDurationSeconds = false,
    Capability? diarization,
    Capability? wordTimestamps,
    Capability? segmentTimestamps,
    bool? supportsPrompt,
    bool? supportsKeywords,
    LanguageParamStyle? languageParamStyle,
    List<String>? responseFormats,
    List<String>? inputFormats,
    int? maxKnownSpeakers,
    bool? requiresChunkingStrategy,
    Set<String>? overriddenFields,
    int? templateVersion,
    bool markOverridden = true,
  }) {
    final changed = <String>{
      if (modelName != null) 'modelName',
      if (displayName != null) 'displayName',
      if (maxFileBytes != null || clearMaxFileBytes) 'maxFileBytes',
      if (maxDurationSeconds != null || clearMaxDurationSeconds)
        'maxDurationSeconds',
      if (diarization != null) 'diarization',
      if (wordTimestamps != null) 'wordTimestamps',
      if (segmentTimestamps != null) 'segmentTimestamps',
      if (supportsPrompt != null) 'supportsPrompt',
      if (supportsKeywords != null) 'supportsKeywords',
      if (languageParamStyle != null) 'languageParamStyle',
      if (responseFormats != null) 'responseFormats',
      if (inputFormats != null) 'inputFormats',
      if (maxKnownSpeakers != null) 'maxKnownSpeakers',
      if (requiresChunkingStrategy != null) 'requiresChunkingStrategy',
    };
    return ModelConfig(
      id: id,
      providerId: providerId,
      templateId: templateId,
      modelName: modelName ?? this.modelName,
      displayName: displayName ?? this.displayName,
      maxFileBytes: clearMaxFileBytes
          ? null
          : (maxFileBytes ?? this.maxFileBytes),
      maxDurationSeconds: clearMaxDurationSeconds
          ? null
          : (maxDurationSeconds ?? this.maxDurationSeconds),
      diarization: diarization ?? this.diarization,
      wordTimestamps: wordTimestamps ?? this.wordTimestamps,
      segmentTimestamps: segmentTimestamps ?? this.segmentTimestamps,
      supportsPrompt: supportsPrompt ?? this.supportsPrompt,
      supportsKeywords: supportsKeywords ?? this.supportsKeywords,
      languageParamStyle: languageParamStyle ?? this.languageParamStyle,
      responseFormats: responseFormats ?? this.responseFormats,
      inputFormats: inputFormats ?? this.inputFormats,
      maxKnownSpeakers: maxKnownSpeakers ?? this.maxKnownSpeakers,
      requiresChunkingStrategy:
          requiresChunkingStrategy ?? this.requiresChunkingStrategy,
      overriddenFields:
          overriddenFields ??
          (markOverridden
              ? {...this.overriddenFields, ...changed}
              : this.overriddenFields),
      templateVersion: templateVersion ?? this.templateVersion,
      extraJson: extraJson,
    );
  }

  /// Purpose: Report whether a recording in this format could be sent as it is.
  /// Inputs: [extension] without its dot, in any case.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: One half of the planner's fast path; the other half is size.
  bool acceptsInputFormat(String extension) =>
      inputFormats.contains(extension.toLowerCase().replaceFirst('.', ''));

  /// Purpose: Choose the reply format to ask for.
  /// Inputs: [wanted] the formats the caller would like, best first.
  /// Returns: The first one this model accepts, or its own first format.
  /// Side effects: None.
  /// Notes: Asking for a format a model rejects is a wasted round trip that
  /// fails with a 400, so the caller states a preference and takes what is
  /// available rather than assuming.
  String chooseResponseFormat(List<String> wanted) {
    for (final format in wanted) {
      if (responseFormats.contains(format)) return format;
    }
    return responseFormats.isEmpty ? 'json' : responseFormats.first;
  }
}

/// Purpose: Read a non-empty string field.
/// Inputs: [value].
/// Returns: The trimmed string, or null.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String? _string(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Purpose: Read a positive integer field.
/// Inputs: [value].
/// Returns: The value, or null when absent or not positive.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
int? _positiveInt(Object? value) {
  final parsed = switch (value) {
    final int n => n,
    final num n => n.round(),
    final String s => int.tryParse(s),
    _ => null,
  };
  return parsed != null && parsed > 0 ? parsed : null;
}

/// Purpose: Read a list of strings, falling back when it is absent or empty.
/// Inputs: [value], [fallback].
/// Returns: The strings, or [fallback].
/// Side effects: None.
/// Notes: Internal helper used within this file only. An empty list falls back
/// rather than being taken literally: "this model accepts no formats at all"
/// is never what a config meant, and taking it literally would make the model
/// unusable with no way to see why.
List<String> _stringList(Object? value, List<String> fallback) {
  if (value is! List) return fallback;
  final items = [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
  return items.isEmpty ? fallback : items;
}

/// Purpose: Read a set of strings.
/// Inputs: [value].
/// Returns: The string entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Set<String> _stringSet(Object? value) {
  if (value is! List) return const {};
  return {
    for (final item in value)
      if (item is String) item,
  };
}
