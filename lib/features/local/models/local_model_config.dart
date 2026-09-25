/// Purpose: A model that runs on the device, as the synced library knows it.
/// Inputs: The `payload` of a settings record of kind `localModel`.
/// Returns: The `LocalModelConfig` value type and `LocalModelFamily`.
/// Side effects: None.
/// Notes: Identity, languages, limits and capabilities only — nothing about
/// this device. Which packages are installed here, where they are, and which
/// processor runs them live in device-local files (decision D2 of the
/// local-models plan), so a model added on the desktop shows on the phone as
/// "not downloaded" instead of as a promise. See
/// `doc/en-us/features/local-models.md`.
library;

import '../../providers/models/model_config.dart';

/// The prefix every local model record id carries.
///
/// Built-in records derive the rest from the template
/// (`local:whisper-large-v3-turbo`); a model the user adds from a file gets
/// `local:` and a uuid. The prefix is load-bearing: a 0.2.x build writes a
/// record kind it does not know back as `unknown`, and the prefix is how this
/// build recognises such a record as a local model again.
const localModelIdPrefix = 'local:';

/// The provider id a local job records in place of a source.
///
/// Not a provider record — there is no endpoint and no key — but a job needs
/// something in that field, and an older build that reads the job finds no
/// source by this id and says so, which is the truth from its point of view.
const localProviderId = 'local';

/// Which family a local model belongs to.
enum LocalModelFamily {
  /// OpenAI Whisper, in whisper.cpp's GGML format or another conversion.
  whisper,

  /// NVIDIA Parakeet TDT.
  parakeet,

  /// Qwen's open ASR release.
  qwen,

  /// Added by the user from a file.
  custom,

  /// A family this build does not know. Preserved, never interpreted.
  unknown;

  /// Purpose: Parse a persisted family.
  /// Inputs: [value].
  /// Returns: The family, or [unknown].
  /// Side effects: None.
  /// Notes: None.
  static LocalModelFamily parse(Object? value) {
    for (final family in LocalModelFamily.values) {
      if (family != unknown && family.name == value) return family;
    }
    return unknown;
  }
}

/// Keys this build writes into a local model payload.
const _knownKeys = {
  'templateId',
  'displayName',
  'family',
  'languages',
  'maxDurationSeconds',
  'diarization',
  'wordTimestamps',
  'segmentTimestamps',
  'supportsPrompt',
  'supportsKeywords',
  'artifacts',
  'overriddenFields',
  'templateVersion',
};

/// One model that can run on the device.
class LocalModelConfig {
  /// The settings record id, always starting with [localModelIdPrefix].
  final String id;

  /// The template this came from, or null when the user added it.
  final String? templateId;

  /// What the user sees.
  final String displayName;

  /// Which family it is.
  final LocalModelFamily family;

  /// The languages it transcribes, as lower-case codes.
  ///
  /// Empty means the record states no restriction — Whisper and Qwen detect
  /// dozens. A non-empty list is a restriction the router enforces: Parakeet
  /// lists the European languages it was trained on, so a Chinese job never
  /// reaches it.
  final List<String> languages;

  /// The longest window the model itself handles well, in seconds, or null
  /// when it has no limit of its own.
  final int? maxDurationSeconds;

  /// Whether it can say who is speaking. Unsupported for every family this
  /// plan ships (D18).
  final Capability diarization;

  /// Whether it can time each word.
  final Capability wordTimestamps;

  /// Whether it can time each segment.
  final Capability segmentTimestamps;

  /// Whether it takes free-text context (Whisper's initial prompt).
  final bool supportsPrompt;

  /// Whether it takes a list of terms to listen for (Qwen's hotwords).
  final bool supportsKeywords;

  /// The packages this record may use, by adapter id.
  ///
  /// One record, several packages: Whisper turbo lists a GGML file for
  /// whisper.cpp and a Qualcomm package; Parakeet lists an ONNX one and a
  /// Core ML one. The router picks the package; the user picks the model.
  final Map<String, List<String>> artifacts;

  /// Fields the user changed away from the template.
  final Set<String> overriddenFields;

  /// The template version this record was last refreshed from.
  final int templateVersion;

  /// Payload fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a local model configuration.
  /// Inputs: All fields; [id] and [displayName] are required.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: Capabilities default to unknown, the honest state for a model
  /// nobody has described; diarization defaults to unsupported because no
  /// local model in this plan labels speakers.
  const LocalModelConfig({
    required this.id,
    required this.displayName,
    this.templateId,
    this.family = LocalModelFamily.custom,
    this.languages = const [],
    this.maxDurationSeconds,
    this.diarization = Capability.unsupported,
    this.wordTimestamps = Capability.unknown,
    this.segmentTimestamps = Capability.unknown,
    this.supportsPrompt = false,
    this.supportsKeywords = false,
    this.artifacts = const {},
    this.overriddenFields = const {},
    this.templateVersion = 0,
    this.extraJson = const {},
  });

  /// Purpose: Read a local model from a settings record payload.
  /// Inputs: [id] the record id, [payload] its fields.
  /// Returns: A [LocalModelConfig].
  /// Side effects: None.
  /// Notes: Every field falls back rather than throwing, so one bad value in a
  /// synced file cannot make the library unopenable.
  factory LocalModelConfig.fromPayload(
    String id,
    Map<String, dynamic> payload,
  ) => LocalModelConfig(
    id: id,
    templateId: _string(payload['templateId']),
    displayName: _string(payload['displayName']) ?? id,
    family: LocalModelFamily.parse(payload['family']),
    languages: [
      for (final code in _stringList(payload['languages'])) code.toLowerCase(),
    ],
    maxDurationSeconds: _positiveInt(payload['maxDurationSeconds']),
    diarization: Capability.parse(payload['diarization']),
    wordTimestamps: Capability.parse(payload['wordTimestamps']),
    segmentTimestamps: Capability.parse(payload['segmentTimestamps']),
    supportsPrompt: payload['supportsPrompt'] == true,
    supportsKeywords: payload['supportsKeywords'] == true,
    artifacts: _artifactMap(payload['artifacts']),
    overriddenFields: _stringList(payload['overriddenFields']).toSet(),
    templateVersion: _positiveInt(payload['templateVersion']) ?? 0,
    extraJson: {
      for (final e in payload.entries)
        if (!_knownKeys.contains(e.key)) e.key: e.value,
    },
  );

  /// Purpose: Write the model as a settings record payload.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Unknown fields first, so a known key wins a collision. Adapter ids
  /// and override names are sorted, so an unchanged record serialises to the
  /// same bytes and sync keeps its raw-equality fast path.
  Map<String, dynamic> toPayload() => {
    ...extraJson,
    if (templateId != null) 'templateId': templateId,
    'displayName': displayName,
    'family': family.name,
    'languages': languages,
    if (maxDurationSeconds != null) 'maxDurationSeconds': maxDurationSeconds,
    'diarization': diarization.name,
    'wordTimestamps': wordTimestamps.name,
    'segmentTimestamps': segmentTimestamps.name,
    'supportsPrompt': supportsPrompt,
    'supportsKeywords': supportsKeywords,
    'artifacts': {
      for (final adapter in (artifacts.keys.toList()..sort()))
        adapter: artifacts[adapter],
    },
    if (overriddenFields.isNotEmpty)
      'overriddenFields': (overriddenFields.toList()..sort()),
    'templateVersion': templateVersion,
  };

  /// Every package id this record may use, across adapters.
  Set<String> get artifactIds => {for (final ids in artifacts.values) ...ids};

  /// Purpose: Report whether a job in these languages may use this model.
  /// Inputs: [requested] the job's language codes; empty means "detect".
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Every requested language must be one the model lists. A model
  /// with no list takes anything, and a job with no language takes any model —
  /// the model then detects, which a restricted model does only within its own
  /// list, so the router still says what it covers.
  bool acceptsLanguages(List<String> requested) {
    if (languages.isEmpty) return true;
    for (final code in requested) {
      if (!languages.contains(_primaryLanguage(code))) return false;
    }
    return true;
  }

  /// Purpose: Return a copy with some fields replaced, marking what changed.
  /// Inputs: The fields to change.
  /// Returns: A new [LocalModelConfig].
  /// Side effects: None.
  /// Notes: Every changed field joins [overriddenFields] unless
  /// `markOverridden` is false, which only the template refresh passes.
  LocalModelConfig copyWith({
    String? displayName,
    List<String>? languages,
    int? maxDurationSeconds,
    bool clearMaxDurationSeconds = false,
    Capability? wordTimestamps,
    Capability? segmentTimestamps,
    Map<String, List<String>>? artifacts,
    Set<String>? overriddenFields,
    int? templateVersion,
    bool markOverridden = true,
  }) {
    final changed = <String>{
      if (displayName != null) 'displayName',
      if (languages != null) 'languages',
      if (maxDurationSeconds != null || clearMaxDurationSeconds)
        'maxDurationSeconds',
      if (wordTimestamps != null) 'wordTimestamps',
      if (segmentTimestamps != null) 'segmentTimestamps',
      if (artifacts != null) 'artifacts',
    };
    return LocalModelConfig(
      id: id,
      templateId: templateId,
      displayName: displayName ?? this.displayName,
      family: family,
      languages: languages ?? this.languages,
      maxDurationSeconds: clearMaxDurationSeconds
          ? null
          : (maxDurationSeconds ?? this.maxDurationSeconds),
      diarization: diarization,
      wordTimestamps: wordTimestamps ?? this.wordTimestamps,
      segmentTimestamps: segmentTimestamps ?? this.segmentTimestamps,
      supportsPrompt: supportsPrompt,
      supportsKeywords: supportsKeywords,
      artifacts: artifacts ?? this.artifacts,
      overriddenFields:
          overriddenFields ??
          (markOverridden
              ? {...this.overriddenFields, ...changed}
              : this.overriddenFields),
      templateVersion: templateVersion ?? this.templateVersion,
      extraJson: extraJson,
    );
  }
}

/// Purpose: Reduce a language tag to its primary subtag.
/// Inputs: [code], e.g. `zh-Hant` or `EN`.
/// Returns: The lower-case primary subtag, e.g. `zh`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. A job asking for
/// `zh-TW` is asking for Chinese as far as a model's language list goes.
String _primaryLanguage(String code) =>
    code.toLowerCase().split(RegExp('[-_]')).first;

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

/// Purpose: Read a list of non-empty strings.
/// Inputs: [value].
/// Returns: The trimmed entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}

/// Purpose: Read the per-adapter package lists.
/// Inputs: [value].
/// Returns: A map from adapter id to package ids.
/// Side effects: None.
/// Notes: Internal helper used within this file only. An adapter whose list is
/// empty or unreadable is dropped rather than kept as an empty promise.
Map<String, List<String>> _artifactMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final e in value.entries)
      if (e.key is String && _stringList(e.value).isNotEmpty)
        e.key as String: _stringList(e.value),
  };
}
