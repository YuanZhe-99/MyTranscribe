/// Purpose: One recording being turned into text, as a record on disk.
/// Inputs: Parsed `jobs/<id>/job.json`.
/// Returns: The `TranscriptionJob` value type and the things it is made of.
/// Side effects: None.
/// Notes: A record rather than a running task, which is what lets a job survive
/// the app being closed and pick up where it stopped. Everything needed to
/// resume is here: the plan, what each finished window returned, and the
/// fingerprint that says whether those results still apply. See
/// `doc/en-us/features/transcription-jobs.md`.
library;

import '../../media/models/media_info.dart';
import 'chunk_plan.dart';

/// Where a job has got to.
enum JobStage {
  /// Waiting for the runner.
  queued,

  /// Reading the recording's duration and streams.
  probing,

  /// Working out how to divide it.
  planning,

  /// Converting the whole recording once.
  normalizing,

  /// Cutting one window out of the converted audio.
  cutting,

  /// Sending a window.
  uploading,

  /// Joining the windows back together.
  merging,

  /// Working out who spoke.
  namingSpeakers,

  /// Writing the transcript and the requested outputs.
  rendering,

  /// Finished.
  done,

  /// Stopped by a failure.
  failed,

  /// Stopped by the user.
  cancelled;

  /// Purpose: Parse a persisted stage.
  /// Inputs: [value].
  /// Returns: The stage; anything unrecognised reads as [queued].
  /// Side effects: None.
  /// Notes: Queued is the safe fallback: a job whose stage cannot be read is
  /// re-runnable, and its finished windows are still reused.
  static JobStage parse(Object? value) {
    for (final stage in JobStage.values) {
      if (stage.name == value) return stage;
    }
    return queued;
  }

  /// Whether the job is doing something right now.
  bool get isRunning => switch (this) {
    JobStage.queued ||
    JobStage.done ||
    JobStage.failed ||
    JobStage.cancelled => false,
    _ => true,
  };

  /// Whether the job has stopped for good unless the user acts.
  bool get isFinished => switch (this) {
    JobStage.done || JobStage.failed || JobStage.cancelled => true,
    _ => false,
  };
}

/// Why a job stopped.
enum JobFailureKind {
  /// FFmpeg is needed and not available.
  mediaToolkitMissing,

  /// The recording could not be read.
  badInput,

  /// The recording is no longer where it was.
  sourceMissing,

  /// Converting or cutting failed.
  mediaFailed,

  /// The source refused the request.
  requestRejected,

  /// The source could not be reached.
  network,

  /// No key is set for this source.
  noApiKey,

  /// The source or model is no longer in the library.
  configurationMissing,

  /// Something else.
  unknown;

  /// Purpose: Parse a persisted failure kind.
  /// Inputs: [value].
  /// Returns: The kind, or [unknown].
  /// Side effects: None.
  /// Notes: None.
  static JobFailureKind parse(Object? value) {
    for (final kind in JobFailureKind.values) {
      if (kind.name == value) return kind;
    }
    return unknown;
  }
}

/// What went wrong, kept so the job list can explain itself after a restart.
class JobError {
  /// What kind of failure it was.
  final JobFailureKind kind;

  /// What to tell the user — the source's own words where there were any.
  final String message;

  /// The feature the source refused, when it named one.
  ///
  /// Lets the job offer to run again without it.
  final String? rejectedFeature;

  /// Purpose: Create a job error.
  /// Inputs: [kind], [message], optional [rejectedFeature].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const JobError({
    required this.kind,
    required this.message,
    this.rejectedFeature,
  });

  /// Purpose: Parse a job error.
  /// Inputs: [json].
  /// Returns: A [JobError].
  /// Side effects: None.
  /// Notes: None.
  factory JobError.fromJson(Map<String, dynamic> json) => JobError(
    kind: JobFailureKind.parse(json['kind']),
    message: json['message'] as String? ?? '',
    rejectedFeature: json['rejectedFeature'] as String?,
  );

  /// Purpose: Serialize a job error.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'message': message,
    if (rejectedFeature != null) 'rejectedFeature': rejectedFeature,
  };
}

/// What the user chose for one job.
class JobOptions {
  /// Language hints, most likely first.
  final List<String> languages;

  /// Context for models that accept it.
  final String? prompt;

  /// Terms the recording is likely to contain.
  final List<String> keywords;

  /// Whether speaker labels were asked for.
  final bool diarize;

  /// A window length chosen by hand, in seconds, or null for automatic.
  final double? windowSeconds;

  /// The overlap between windows, in seconds.
  final double overlapSeconds;

  /// Whether to carry speaker samples forward between windows.
  final bool enrollment;

  /// Whether to keep the split audio after the job finishes.
  final bool keepChunks;

  /// Purpose: Create the options for a job.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const JobOptions({
    this.languages = const [],
    this.prompt,
    this.keywords = const [],
    this.diarize = false,
    this.windowSeconds,
    this.overlapSeconds = 5,
    this.enrollment = true,
    this.keepChunks = false,
  });

  /// Purpose: Parse the options.
  /// Inputs: [json].
  /// Returns: A [JobOptions].
  /// Side effects: None.
  /// Notes: None.
  factory JobOptions.fromJson(Map<String, dynamic> json) => JobOptions(
    languages: _strings(json['languages']),
    prompt: json['prompt'] as String?,
    keywords: _strings(json['keywords']),
    diarize: json['diarize'] == true,
    windowSeconds: (json['windowSeconds'] as num?)?.toDouble(),
    overlapSeconds: (json['overlapSeconds'] as num?)?.toDouble() ?? 5,
    enrollment: json['enrollment'] != false,
    keepChunks: json['keepChunks'] == true,
  );

  /// Purpose: Serialize the options.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    if (languages.isNotEmpty) 'languages': languages,
    if (prompt != null) 'prompt': prompt,
    if (keywords.isNotEmpty) 'keywords': keywords,
    'diarize': diarize,
    if (windowSeconds != null) 'windowSeconds': windowSeconds,
    'overlapSeconds': overlapSeconds,
    'enrollment': enrollment,
    'keepChunks': keepChunks,
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change.
  /// Returns: A new [JobOptions].
  /// Side effects: None.
  /// Notes: None.
  JobOptions copyWith({
    bool? diarize,
    List<String>? keywords,
    String? prompt,
  }) => JobOptions(
    languages: languages,
    prompt: prompt ?? this.prompt,
    keywords: keywords ?? this.keywords,
    diarize: diarize ?? this.diarize,
    windowSeconds: windowSeconds,
    overlapSeconds: overlapSeconds,
    enrollment: enrollment,
    keepChunks: keepChunks,
  );
}

/// What one window came back as.
class ChunkResult {
  /// Which window.
  final int index;

  /// Where it started in the recording, in seconds.
  final double startSeconds;

  /// How long it ran, in seconds.
  final double lengthSeconds;

  /// The size of the file that was sent, in bytes.
  ///
  /// A resume compares this against the window file on disk. A file that does
  /// not match was cut under a different plan and cannot be trusted.
  final int chunkBytes;

  /// The whole window's text.
  final String text;

  /// Its segments, in window-local time.
  final List<ChunkSegment> segments;

  /// Whether those segments carry real times.
  final bool hasRealTimestamps;

  /// The speaker ids whose samples this request carried.
  final List<String> knownSpeakerIds;

  /// Purpose: Create a chunk result.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ChunkResult({
    required this.index,
    required this.startSeconds,
    required this.lengthSeconds,
    required this.chunkBytes,
    required this.text,
    this.segments = const [],
    this.hasRealTimestamps = false,
    this.knownSpeakerIds = const [],
  });

  /// Purpose: Parse a chunk result.
  /// Inputs: [json].
  /// Returns: A [ChunkResult].
  /// Side effects: None.
  /// Notes: None.
  factory ChunkResult.fromJson(Map<String, dynamic> json) => ChunkResult(
    index: (json['index'] as num?)?.toInt() ?? 0,
    startSeconds: (json['start'] as num?)?.toDouble() ?? 0,
    lengthSeconds: (json['length'] as num?)?.toDouble() ?? 0,
    chunkBytes: (json['bytes'] as num?)?.toInt() ?? 0,
    text: json['text'] as String? ?? '',
    segments: [
      for (final item in (json['segments'] as List?) ?? const [])
        if (item is Map<String, dynamic>) ChunkSegment.fromJson(item),
    ],
    hasRealTimestamps: json['timed'] == true,
    knownSpeakerIds: _strings(json['knownSpeakerIds']),
  );

  /// Purpose: Serialize a chunk result.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'index': index,
    'start': startSeconds,
    'length': lengthSeconds,
    'bytes': chunkBytes,
    'text': text,
    if (segments.isNotEmpty)
      'segments': [for (final segment in segments) segment.toJson()],
    'timed': hasRealTimestamps,
    if (knownSpeakerIds.isNotEmpty) 'knownSpeakerIds': knownSpeakerIds,
  };
}

/// One segment of a window, in window-local time.
class ChunkSegment {
  /// Where it starts inside the window, in seconds.
  final double startSeconds;

  /// Where it ends inside the window, in seconds.
  final double endSeconds;

  /// What was said.
  final String text;

  /// The speaker label the source used inside this window.
  final String? speaker;

  /// Purpose: Create a chunk segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ChunkSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    this.speaker,
  });

  /// Purpose: Parse a chunk segment.
  /// Inputs: [json].
  /// Returns: A [ChunkSegment].
  /// Side effects: None.
  /// Notes: None.
  factory ChunkSegment.fromJson(Map<String, dynamic> json) => ChunkSegment(
    startSeconds: (json['start'] as num?)?.toDouble() ?? 0,
    endSeconds: (json['end'] as num?)?.toDouble() ?? 0,
    text: json['text'] as String? ?? '',
    speaker: json['speaker'] as String?,
  );

  /// Purpose: Serialize a chunk segment.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'start': startSeconds,
    'end': endSeconds,
    'text': text,
    if (speaker != null) 'speaker': speaker,
  };
}

/// One recording being turned into text.
class TranscriptionJob {
  /// Its identifier, and the name of its folder.
  final String id;

  /// When it was created, in UTC.
  final DateTime createdAt;

  /// When it last changed, in UTC.
  final DateTime modifiedAt;

  /// When it finished, in UTC, or null.
  final DateTime? finishedAt;

  /// Where the recording is.
  final String sourcePath;

  /// What to call it.
  final String sourceName;

  /// How large it is, in bytes.
  final int sourceBytes;

  /// The source it is being sent to.
  final String providerId;

  /// The model being used.
  final String modelId;

  /// That model's wire name, kept so a finished job can still say what produced
  /// it after the model has been renamed or removed.
  final String modelName;

  /// What the user chose.
  final JobOptions options;

  /// What probing found.
  final MediaInfo? media;

  /// How the recording is divided.
  final ChunkPlan? plan;

  /// Where the job has got to.
  final JobStage stage;

  /// Which window is being worked on.
  final int? currentChunk;

  /// Why it stopped, when it did.
  final JobError? error;

  /// What each finished window returned.
  final List<ChunkResult> chunks;

  /// The files that were written.
  final List<String> outputs;

  /// Fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a job.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptionJob({
    required this.id,
    required this.createdAt,
    required this.modifiedAt,
    required this.sourcePath,
    required this.sourceName,
    required this.sourceBytes,
    required this.providerId,
    required this.modelId,
    required this.modelName,
    this.options = const JobOptions(),
    this.finishedAt,
    this.media,
    this.plan,
    this.stage = JobStage.queued,
    this.currentChunk,
    this.error,
    this.chunks = const [],
    this.outputs = const [],
    this.extraJson = const {},
  });

  /// How many windows have finished.
  int get completedChunks => chunks.length;

  /// How many there are in total, or null before there is a plan.
  int? get totalChunks => plan?.windowCount;

  /// How far along the job is, from 0 to 1, or null when it cannot be known.
  double? get progress {
    final total = totalChunks;
    if (total == null || total == 0) return null;
    return (completedChunks / total).clamp(0.0, 1.0);
  }

  /// Purpose: Parse a job.
  /// Inputs: [json].
  /// Returns: A [TranscriptionJob].
  /// Side effects: None.
  /// Notes: A job left in a running stage by a crash reads back as that stage;
  /// the runner turns it into a queued one at startup, which is what makes an
  /// interrupted job resume rather than sit there looking busy.
  factory TranscriptionJob.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse('${json['createdAt']}')?.toUtc();
    return TranscriptionJob(
      id: json['id'] as String? ?? '',
      createdAt: created ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      modifiedAt:
          DateTime.tryParse('${json['modifiedAt']}')?.toUtc() ??
          created ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      finishedAt: DateTime.tryParse('${json['finishedAt']}')?.toUtc(),
      sourcePath: json['sourcePath'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      sourceBytes: (json['sourceBytes'] as num?)?.toInt() ?? 0,
      providerId: json['providerId'] as String? ?? '',
      modelId: json['modelId'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
      options: JobOptions.fromJson(
        (json['options'] as Map<String, dynamic>?) ?? const {},
      ),
      media: json['media'] is Map<String, dynamic>
          ? _mediaFromJson(json['media'] as Map<String, dynamic>)
          : null,
      plan: json['plan'] is Map<String, dynamic>
          ? ChunkPlan.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      stage: JobStage.parse(json['stage']),
      currentChunk: (json['currentChunk'] as num?)?.toInt(),
      error: json['error'] is Map<String, dynamic>
          ? JobError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      chunks: [
        for (final item in (json['chunks'] as List?) ?? const [])
          if (item is Map<String, dynamic>) ChunkResult.fromJson(item),
      ],
      outputs: _strings(json['outputs']),
      extraJson: {
        for (final e in json.entries)
          if (!_knownKeys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Purpose: Serialize a job.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'modifiedAt': modifiedAt.toUtc().toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toUtc().toIso8601String(),
    'sourcePath': sourcePath,
    'sourceName': sourceName,
    'sourceBytes': sourceBytes,
    'providerId': providerId,
    'modelId': modelId,
    'modelName': modelName,
    'options': options.toJson(),
    if (media != null) 'media': _mediaToJson(media!),
    if (plan != null) 'plan': plan!.toJson(),
    'stage': stage.name,
    if (currentChunk != null) 'currentChunk': currentChunk,
    if (error != null) 'error': error!.toJson(),
    if (chunks.isNotEmpty)
      'chunks': [for (final chunk in chunks) chunk.toJson()],
    if (outputs.isNotEmpty) 'outputs': outputs,
  };

  /// Purpose: Return a copy with some fields replaced.
  /// Inputs: The fields to change, plus a `clear` flag per nullable one.
  /// Returns: A new [TranscriptionJob].
  /// Side effects: None.
  /// Notes: [modifiedAt] moves on every copy unless it is given, so a saved job
  /// always records when it last changed.
  TranscriptionJob copyWith({
    DateTime? modifiedAt,
    DateTime? finishedAt,
    MediaInfo? media,
    ChunkPlan? plan,
    JobStage? stage,
    int? currentChunk,
    bool clearCurrentChunk = false,
    JobError? error,
    bool clearError = false,
    List<ChunkResult>? chunks,
    List<String>? outputs,
    JobOptions? options,
  }) => TranscriptionJob(
    id: id,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? DateTime.now().toUtc(),
    finishedAt: finishedAt ?? this.finishedAt,
    sourcePath: sourcePath,
    sourceName: sourceName,
    sourceBytes: sourceBytes,
    providerId: providerId,
    modelId: modelId,
    modelName: modelName,
    options: options ?? this.options,
    media: media ?? this.media,
    plan: plan ?? this.plan,
    stage: stage ?? this.stage,
    currentChunk: clearCurrentChunk
        ? null
        : (currentChunk ?? this.currentChunk),
    error: clearError ? null : (error ?? this.error),
    chunks: chunks ?? this.chunks,
    outputs: outputs ?? this.outputs,
    extraJson: extraJson,
  );
}

/// Keys this build writes at the top level of a job.
const _knownKeys = {
  'id',
  'createdAt',
  'modifiedAt',
  'finishedAt',
  'sourcePath',
  'sourceName',
  'sourceBytes',
  'providerId',
  'modelId',
  'modelName',
  'options',
  'media',
  'plan',
  'stage',
  'currentChunk',
  'error',
  'chunks',
  'outputs',
};

/// Purpose: Parse the probe result.
/// Inputs: [json].
/// Returns: A [MediaInfo].
/// Side effects: None.
/// Notes: Internal helper used within this file only. `MediaInfo` has no JSON
/// of its own because nothing else persists it.
MediaInfo _mediaFromJson(Map<String, dynamic> json) => MediaInfo(
  durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0,
  bitrateBps: (json['bitrate'] as num?)?.toInt(),
  audioCodec: json['codec'] as String?,
  sampleRate: (json['sampleRate'] as num?)?.toInt(),
  channels: (json['channels'] as num?)?.toInt(),
  hasVideo: json['hasVideo'] == true,
);

/// Purpose: Serialize the probe result.
/// Inputs: [media].
/// Returns: A JSON-compatible map.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _mediaToJson(MediaInfo media) => {
  'duration': media.durationSeconds,
  if (media.bitrateBps != null) 'bitrate': media.bitrateBps,
  if (media.audioCodec != null) 'codec': media.audioCodec,
  if (media.sampleRate != null) 'sampleRate': media.sampleRate,
  if (media.channels != null) 'channels': media.channels,
  'hasVideo': media.hasVideo,
};

/// Purpose: Read a list of non-empty strings.
/// Inputs: [value].
/// Returns: The entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<String> _strings(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  ];
}
