/// Purpose: The transcript a finished job produces — its segments, who spoke
/// them, and the corrections the user has made.
/// Inputs: Built by the job runner from the merged windows; edited in the
/// viewer.
/// Returns: `Speaker`, `TranscriptSegment` and `Transcript`.
/// Side effects: None.
/// Notes: Segments point at speakers by id, never by name. Renaming a speaker
/// or merging two of them then costs one record, not a rewrite of every line —
/// and a rewrite is exactly where an edit would be lost. See
/// `doc/en-us/data-formats.md`.
library;

/// Someone who speaks in a recording.
class Speaker {
  /// A stable id, `spk_1` upwards.
  ///
  /// Used as the known-speaker name when a source accepts reference clips, so
  /// renaming a speaker never changes what is sent.
  final String id;

  /// What to call them, once somebody has said.
  final String? name;

  /// Which colour of the viewer's palette they get.
  final int colorIndex;

  /// The sample clip cut for them, relative to the job folder.
  final String? sampleFile;

  /// Ids merged into this speaker, kept so a merge can be explained.
  final List<String> mergedIds;

  /// Fields a newer build wrote that this one does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a speaker.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const Speaker({
    required this.id,
    this.name,
    this.colorIndex = 0,
    this.sampleFile,
    this.mergedIds = const [],
    this.extraJson = const {},
  });

  /// What to show for this speaker when nobody has named them.
  ///
  /// The fallback carries the number rather than a bare word, so two unnamed
  /// speakers are still told apart in a transcript.
  String displayName(String Function(int number) fallback) =>
      name?.trim().isNotEmpty == true
      ? name!.trim()
      : fallback(int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 0);

  /// Purpose: Parse a speaker.
  /// Inputs: [json].
  /// Returns: A [Speaker].
  /// Side effects: None.
  /// Notes: None.
  factory Speaker.fromJson(Map<String, dynamic> json) => Speaker(
    id: '${json['id']}',
    name: json['name'] as String?,
    colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
    sampleFile: json['sampleFile'] as String?,
    mergedIds: [
      for (final id in (json['mergedIds'] as List? ?? const [])) '$id',
    ],
    extraJson: {
      for (final entry in json.entries)
        if (!_speakerKeys.contains(entry.key)) entry.key: entry.value,
    },
  );

  /// Purpose: Serialize a speaker.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    if (name != null) 'name': name,
    'colorIndex': colorIndex,
    if (sampleFile != null) 'sampleFile': sampleFile,
    if (mergedIds.isNotEmpty) 'mergedIds': mergedIds,
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change; [clearName] to unname them again.
  /// Returns: A new [Speaker].
  /// Side effects: None.
  /// Notes: None.
  Speaker copyWith({
    String? name,
    int? colorIndex,
    String? sampleFile,
    List<String>? mergedIds,
    bool clearName = false,
  }) => Speaker(
    id: id,
    name: clearName ? null : (name ?? this.name),
    colorIndex: colorIndex ?? this.colorIndex,
    sampleFile: sampleFile ?? this.sampleFile,
    mergedIds: mergedIds ?? this.mergedIds,
    extraJson: extraJson,
  );
}

/// Keys this build writes for a speaker.
const _speakerKeys = {'id', 'name', 'colorIndex', 'sampleFile', 'mergedIds'};

/// One line of the transcript.
class TranscriptSegment {
  /// A stable id, so an edit survives a re-merge.
  final String id;

  /// Which window it came from.
  final int chunkIndex;

  /// Where it starts in the whole recording, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  final double endSeconds;

  /// Whether those times are the model's or the app's own estimate.
  ///
  /// A model that returns no timestamps still produces a readable transcript;
  /// the times are then the window's start, and saying so is what stops the
  /// viewer from offering subtitle exports that would be wrong.
  final bool approximate;

  /// Who said it, when that is known.
  final String? speakerId;

  /// What was said.
  final String text;

  /// When the user last changed it.
  final DateTime? editedAt;

  /// Fields a newer build wrote that this one does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptSegment({
    required this.id,
    required this.chunkIndex,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    this.approximate = false,
    this.speakerId,
    this.editedAt,
    this.extraJson = const {},
  });

  /// How long the segment runs, in seconds.
  double get lengthSeconds =>
      endSeconds > startSeconds ? endSeconds - startSeconds : 0;

  /// Purpose: Parse a segment.
  /// Inputs: [json].
  /// Returns: A [TranscriptSegment].
  /// Side effects: None.
  /// Notes: None.
  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      TranscriptSegment(
        id: '${json['id']}',
        chunkIndex: (json['chunkIndex'] as num?)?.toInt() ?? 0,
        startSeconds: (json['start'] as num?)?.toDouble() ?? 0,
        endSeconds: (json['end'] as num?)?.toDouble() ?? 0,
        text: '${json['text'] ?? ''}',
        approximate: json['approximate'] == true,
        speakerId: json['speakerId'] as String?,
        editedAt: DateTime.tryParse('${json['editedAt']}')?.toUtc(),
        extraJson: {
          for (final entry in json.entries)
            if (!_segmentKeys.contains(entry.key)) entry.key: entry.value,
        },
      );

  /// Purpose: Serialize a segment.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'chunkIndex': chunkIndex,
    'start': startSeconds,
    'end': endSeconds,
    'text': text,
    if (approximate) 'approximate': true,
    if (speakerId != null) 'speakerId': speakerId,
    if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change; [clearSpeaker] to unassign it.
  /// Returns: A new [TranscriptSegment].
  /// Side effects: None.
  /// Notes: None.
  TranscriptSegment copyWith({
    String? text,
    String? speakerId,
    DateTime? editedAt,
    bool clearSpeaker = false,
  }) => TranscriptSegment(
    id: id,
    chunkIndex: chunkIndex,
    startSeconds: startSeconds,
    endSeconds: endSeconds,
    text: text ?? this.text,
    approximate: approximate,
    speakerId: clearSpeaker ? null : (speakerId ?? this.speakerId),
    editedAt: editedAt ?? this.editedAt,
    extraJson: extraJson,
  );
}

/// Keys this build writes for a segment.
const _segmentKeys = {
  'id',
  'chunkIndex',
  'start',
  'end',
  'text',
  'approximate',
  'speakerId',
  'editedAt',
};

/// A whole transcript.
class Transcript {
  /// Which job it belongs to.
  final String jobId;

  /// Everyone who speaks, in the order they first do.
  final List<Speaker> speakers;

  /// Which window label became which speaker, as `"<window>:<label>"`.
  ///
  /// Kept so the matching can be re-run, explained, or undone without going
  /// back to the source.
  final Map<String, String> speakerMap;

  /// The lines, in order.
  final List<TranscriptSegment> segments;

  /// When the user last edited anything.
  final DateTime? editedAt;

  /// Fields a newer build wrote that this one does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a transcript.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const Transcript({
    required this.jobId,
    this.speakers = const [],
    this.speakerMap = const {},
    this.segments = const [],
    this.editedAt,
    this.extraJson = const {},
  });

  /// Whether any segment carries a time the model actually gave.
  bool get hasTimestamps => segments.any((s) => !s.approximate);

  /// Whether anybody is identified.
  bool get hasSpeakers => speakers.isNotEmpty;

  /// How long the recording runs according to its last segment.
  double get durationSeconds => segments.isEmpty ? 0 : segments.last.endSeconds;

  /// Purpose: Find one speaker.
  /// Inputs: [id].
  /// Returns: The speaker, or null.
  /// Side effects: None.
  /// Notes: None.
  Speaker? speaker(String? id) {
    if (id == null) return null;
    for (final speaker in speakers) {
      if (speaker.id == id) return speaker;
    }
    return null;
  }

  /// Purpose: Fold one speaker into another.
  /// Inputs: The speaker to merge away [from], and the one to merge [into].
  /// Returns: A new [Transcript].
  /// Side effects: None.
  /// Notes: Every line, and every window label that led to the merged speaker,
  /// is repointed; the merged id is remembered on the survivor so the change
  /// can be explained later. The matching refuses a doubtful join rather than
  /// guessing, so one person coming back as two is its expected failure, and
  /// this is the repair. Nothing is deleted but the speaker record itself: the
  /// text is untouched, because it was always right.
  Transcript mergeSpeakers(String from, String into) {
    if (from == into) return this;
    if (speaker(from) == null || speaker(into) == null) return this;

    return copyWith(
      speakers: [
        for (final existing in speakers)
          if (existing.id == into)
            existing.copyWith(
              mergedIds: [
                ...existing.mergedIds,
                from,
                ...speaker(from)!.mergedIds,
              ],
            )
          else if (existing.id != from)
            existing,
      ],
      speakerMap: {
        for (final entry in speakerMap.entries)
          entry.key: entry.value == from ? into : entry.value,
      },
      segments: [
        for (final segment in segments)
          if (segment.speakerId == from)
            segment.copyWith(speakerId: into)
          else
            segment,
      ],
    );
  }

  /// Purpose: Parse a transcript.
  /// Inputs: [json].
  /// Returns: A [Transcript].
  /// Side effects: None.
  /// Notes: None.
  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
    jobId: '${json['jobId'] ?? ''}',
    speakers: [
      for (final entry in (json['speakers'] as List? ?? const []))
        if (entry is Map<String, dynamic>) Speaker.fromJson(entry),
    ],
    speakerMap: {
      for (final entry
          in (json['speakerMap'] as Map<String, dynamic>? ?? const {}).entries)
        entry.key: '${entry.value}',
    },
    segments: [
      for (final entry in (json['segments'] as List? ?? const []))
        if (entry is Map<String, dynamic>) TranscriptSegment.fromJson(entry),
    ],
    editedAt: DateTime.tryParse('${json['editedAt']}')?.toUtc(),
    extraJson: {
      for (final entry in json.entries)
        if (!_transcriptKeys.contains(entry.key)) entry.key: entry.value,
    },
  );

  /// Purpose: Serialize a transcript.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: `hasTimestamps` and `hasSpeakers` are written even though they are
  /// derived, because a person reading the file to answer "can I get subtitles
  /// out of this?" should not have to scan every segment to find out.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'jobId': jobId,
    'hasTimestamps': hasTimestamps,
    'hasSpeakers': hasSpeakers,
    'speakers': [for (final speaker in speakers) speaker.toJson()],
    if (speakerMap.isNotEmpty) 'speakerMap': speakerMap,
    'segments': [for (final segment in segments) segment.toJson()],
    if (editedAt != null) 'editedAt': editedAt!.toUtc().toIso8601String(),
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change.
  /// Returns: A new [Transcript].
  /// Side effects: None.
  /// Notes: None.
  Transcript copyWith({
    List<Speaker>? speakers,
    Map<String, String>? speakerMap,
    List<TranscriptSegment>? segments,
    DateTime? editedAt,
  }) => Transcript(
    jobId: jobId,
    speakers: speakers ?? this.speakers,
    speakerMap: speakerMap ?? this.speakerMap,
    segments: segments ?? this.segments,
    editedAt: editedAt ?? this.editedAt,
    extraJson: extraJson,
  );
}

/// Keys this build writes at the top level of a transcript.
const _transcriptKeys = {
  'jobId',
  'hasTimestamps',
  'hasSpeakers',
  'speakers',
  'speakerMap',
  'segments',
  'editedAt',
};
