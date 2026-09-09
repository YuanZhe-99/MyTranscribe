/// Purpose: The values a new transcription starts from.
/// Inputs: The `payload` of the single settings record of kind `defaults`.
/// Returns: The `TranscribeDefaults` value type.
/// Side effects: None.
/// Notes: Synced, unlike the device-local preferences in `storage_config.json`,
/// because these describe how the user likes their transcriptions done rather
/// than anything about a particular machine. A per-job override never touches
/// this record.
library;

/// Keys this build writes into the defaults payload.
const _knownKeys = {
  'providerId',
  'modelId',
  'languages',
  'prompt',
  'keywords',
  'diarize',
  'plainOverlapSeconds',
  'diarizedOverlapSeconds',
  'enrollmentEnabled',
  'knownSpeakerNames',
};

/// The overlap between windows when speakers were not requested, in seconds.
///
/// Five, as the original scripts used. Its only job is to stop a word being cut
/// in half at a boundary, and the merge removes the duplication afterwards.
const defaultPlainOverlapSeconds = 5;

/// The overlap when speaker labels were requested, in seconds.
///
/// Longer, because here the overlap does a second job: it is the evidence that
/// connects a speaker in one window to the same speaker in the next. Too short
/// and a quiet speaker says nothing inside it, and comes back as a stranger.
const defaultDiarizedOverlapSeconds = 20;

/// What a new transcription starts with.
class TranscribeDefaults {
  /// The source a new job selects, or null for the first one.
  final String? providerId;

  /// The model a new job selects, or null for the source's own default.
  final String? modelId;

  /// Language hints, most likely first; empty means let the model decide.
  final List<String> languages;

  /// Context passed to models that accept it.
  final String? prompt;

  /// Terms the recording is likely to contain — names, jargon, acronyms.
  final List<String> keywords;

  /// Whether to ask for speaker labels: true, false, or null for "whatever the
  /// model does best".
  ///
  /// Three states rather than two. Null lets a model that labels speakers well
  /// do so without the user having to turn it on per source, while an explicit
  /// false stays off even on a model that offers it.
  final bool? diarize;

  /// The overlap between windows, in seconds, for a plain transcription.
  final int plainOverlapSeconds;

  /// The overlap between windows, in seconds, when speakers were requested.
  final int diarizedOverlapSeconds;

  /// Whether to carry speaker samples forward between windows where the
  /// service accepts them.
  final bool enrollmentEnabled;

  /// Names the user has given speakers before, offered as suggestions.
  ///
  /// Synced, because the people in your recordings are the same people on
  /// either device, and retyping them is the sort of small friction that makes
  /// a feature go unused.
  final List<String> knownSpeakerNames;

  /// Payload fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a defaults record.
  /// Inputs: All fields, all optional.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscribeDefaults({
    this.providerId,
    this.modelId,
    this.languages = const [],
    this.prompt,
    this.keywords = const [],
    this.diarize,
    this.plainOverlapSeconds = defaultPlainOverlapSeconds,
    this.diarizedOverlapSeconds = defaultDiarizedOverlapSeconds,
    this.enrollmentEnabled = true,
    this.knownSpeakerNames = const [],
    this.extraJson = const {},
  });

  /// Purpose: Read the defaults from a settings record payload.
  /// Inputs: [payload].
  /// Returns: A [TranscribeDefaults].
  /// Side effects: None.
  /// Notes: Every field falls back rather than throwing.
  factory TranscribeDefaults.fromPayload(Map<String, dynamic> payload) {
    return TranscribeDefaults(
      providerId: _string(payload['providerId']),
      modelId: _string(payload['modelId']),
      languages: _stringList(payload['languages']),
      prompt: _string(payload['prompt']),
      keywords: _stringList(payload['keywords']),
      diarize: payload['diarize'] is bool ? payload['diarize'] as bool : null,
      plainOverlapSeconds:
          _positiveInt(payload['plainOverlapSeconds']) ??
          defaultPlainOverlapSeconds,
      diarizedOverlapSeconds:
          _positiveInt(payload['diarizedOverlapSeconds']) ??
          defaultDiarizedOverlapSeconds,
      enrollmentEnabled: payload['enrollmentEnabled'] != false,
      knownSpeakerNames: _stringList(payload['knownSpeakerNames']),
      extraJson: {
        for (final e in payload.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Write the defaults as a settings record payload.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Absent optional fields are omitted rather than written as null.
  Map<String, dynamic> toPayload() => {
    ...extraJson,
    if (providerId != null) 'providerId': providerId,
    if (modelId != null) 'modelId': modelId,
    if (languages.isNotEmpty) 'languages': languages,
    if (prompt != null) 'prompt': prompt,
    if (keywords.isNotEmpty) 'keywords': keywords,
    if (diarize != null) 'diarize': diarize,
    'plainOverlapSeconds': plainOverlapSeconds,
    'diarizedOverlapSeconds': diarizedOverlapSeconds,
    'enrollmentEnabled': enrollmentEnabled,
    if (knownSpeakerNames.isNotEmpty) 'knownSpeakerNames': knownSpeakerNames,
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change, plus a `clear` flag per nullable one.
  /// Returns: A new [TranscribeDefaults].
  /// Side effects: None.
  /// Notes: The `clear` flags exist because null already means "keep".
  TranscribeDefaults copyWith({
    String? providerId,
    bool clearProviderId = false,
    String? modelId,
    bool clearModelId = false,
    List<String>? languages,
    String? prompt,
    bool clearPrompt = false,
    List<String>? keywords,
    bool? diarize,
    bool clearDiarize = false,
    int? plainOverlapSeconds,
    int? diarizedOverlapSeconds,
    bool? enrollmentEnabled,
    List<String>? knownSpeakerNames,
  }) => TranscribeDefaults(
    providerId: clearProviderId ? null : (providerId ?? this.providerId),
    modelId: clearModelId ? null : (modelId ?? this.modelId),
    languages: languages ?? this.languages,
    prompt: clearPrompt ? null : (prompt ?? this.prompt),
    keywords: keywords ?? this.keywords,
    diarize: clearDiarize ? null : (diarize ?? this.diarize),
    plainOverlapSeconds: plainOverlapSeconds ?? this.plainOverlapSeconds,
    diarizedOverlapSeconds:
        diarizedOverlapSeconds ?? this.diarizedOverlapSeconds,
    enrollmentEnabled: enrollmentEnabled ?? this.enrollmentEnabled,
    knownSpeakerNames: knownSpeakerNames ?? this.knownSpeakerNames,
    extraJson: extraJson,
  );

  /// Purpose: Remember a speaker name the user typed.
  /// Inputs: [name].
  /// Returns: A copy whose suggestion list holds it, most recent first.
  /// Side effects: None.
  /// Notes: Most recent first, case-insensitively deduplicated, and capped —
  /// a suggestion list is only useful while it is short enough to scan.
  TranscribeDefaults rememberSpeakerName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return this;
    final lower = trimmed.toLowerCase();
    return copyWith(
      knownSpeakerNames: [
        trimmed,
        for (final existing in knownSpeakerNames)
          if (existing.toLowerCase() != lower) existing,
      ].take(_maxRememberedSpeakerNames).toList(),
    );
  }

  /// Purpose: Forget a speaker name the user no longer wants offered.
  /// Inputs: [name].
  /// Returns: A copy without it.
  /// Side effects: None.
  /// Notes: Case-insensitive, to match how [rememberSpeakerName] deduplicates:
  /// a list that offered both "Alice" and "alice" would be a bug either way.
  TranscribeDefaults forgetSpeakerName(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return this;
    return copyWith(
      knownSpeakerNames: [
        for (final existing in knownSpeakerNames)
          if (existing.toLowerCase() != lower) existing,
      ],
    );
  }
}

/// How many speaker names to keep as suggestions.
const _maxRememberedSpeakerNames = 40;

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
/// Returns: The entries, trimmed.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}
