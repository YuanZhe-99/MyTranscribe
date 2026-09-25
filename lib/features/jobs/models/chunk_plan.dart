/// Purpose: How one recording will be divided, and why.
/// Inputs: Produced by `ChunkPlanner`.
/// Returns: The `ChunkPlan`, its windows, and the reasons behind it.
/// Side effects: None.
/// Notes: The reasons are not decoration. A user who sees "split because this
/// gateway gives up after 600 seconds" can act — raise the limit on the source,
/// or choose another model — where "split into 14 parts" tells them nothing.
library;

/// Why the plan came out the way it did.
enum PlanReasonCode {
  /// The recording fits, and goes up untouched.
  fitsWhole,

  /// Too large to upload in one piece.
  splitBySize,

  /// Longer than one request may carry.
  splitByDuration,

  /// Its format is not one this model accepts, so it must be converted.
  splitByFormat,

  /// Window length limited by the upload size budget.
  windowCappedBySize,

  /// Window length limited by the model's own audio cap.
  windowCappedByModel,

  /// Window length limited by the provider's request cap.
  windowCappedByProvider,

  /// Window length limited by the app's own ceiling on a single request.
  windowCappedByCeiling,

  /// The overlap was widened because speaker labels were requested.
  overlapForSpeakers,

  /// The user set the window length by hand.
  windowChosenByUser,

  /// Window length limited by the local model's or route's own ceiling.
  windowCappedByEngine,

  /// Window length limited by the memory the local route has to work in.
  windowCappedByMemory,
}

/// One reason, with the numbers that produced it.
class PlanReason {
  /// Which reason.
  final PlanReasonCode code;

  /// The number that made it apply, where there is one.
  final num? value;

  /// Purpose: Create a plan reason.
  /// Inputs: [code], optional [value].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: The value is left unlocalized and unformatted here; the page that
  /// shows it decides whether it is seconds, megabytes or minutes.
  const PlanReason(this.code, [this.value]);
}

/// One window of audio to send.
class ChunkWindow {
  /// Its position in the plan, from zero.
  final int index;

  /// Where it starts in the recording, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  ///
  /// Consecutive windows overlap: this runs past the next one's start by the
  /// plan's overlap.
  final double endSeconds;

  /// Purpose: Create a window.
  /// Inputs: [index], [startSeconds], [endSeconds].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ChunkWindow({
    required this.index,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// How long the window runs, in seconds.
  double get lengthSeconds => endSeconds - startSeconds;

  /// Purpose: Parse a window.
  /// Inputs: [json].
  /// Returns: A [ChunkWindow].
  /// Side effects: None.
  /// Notes: None.
  factory ChunkWindow.fromJson(Map<String, dynamic> json) => ChunkWindow(
    index: (json['index'] as num?)?.toInt() ?? 0,
    startSeconds: (json['start'] as num?)?.toDouble() ?? 0,
    endSeconds: (json['end'] as num?)?.toDouble() ?? 0,
  );

  /// Purpose: Serialize a window.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'index': index,
    'start': startSeconds,
    'end': endSeconds,
  };
}

/// How a recording will be sent.
class ChunkPlan {
  /// Whether the recording goes up in one piece or in windows.
  final bool single;

  /// Whether the original file is uploaded as it is, rather than a converted
  /// copy.
  ///
  /// True only on the fast path — small enough, short enough and already in a
  /// format the model accepts — which is what lets the app transcribe a short
  /// clip with no FFmpeg at all.
  final bool uploadsOriginal;

  /// How far apart consecutive windows start, in seconds.
  final double strideSeconds;

  /// How much each window runs past the next one's start, in seconds.
  final double overlapSeconds;

  /// The windows, in order.
  final List<ChunkWindow> windows;

  /// The expected size of one full window, in bytes.
  ///
  /// Predictable because the app converts to a fixed bit rate first. The runner
  /// compares the real size against it and re-plans if a window comes out over
  /// the limit anyway.
  final int predictedChunkBytes;

  /// Why the plan is what it is.
  final List<PlanReason> reasons;

  /// Identifies the settings this plan was made under.
  ///
  /// A resume recomputes it; when it differs, every cached window result is
  /// discarded, because a result produced under different settings is not the
  /// result the user asked for.
  final String fingerprint;

  /// Purpose: Create a plan.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ChunkPlan({
    required this.single,
    required this.uploadsOriginal,
    required this.strideSeconds,
    required this.overlapSeconds,
    required this.windows,
    required this.predictedChunkBytes,
    required this.fingerprint,
    this.reasons = const [],
  });

  /// How many windows there are.
  int get windowCount => windows.length;

  /// Purpose: Parse a plan.
  /// Inputs: [json].
  /// Returns: A [ChunkPlan].
  /// Side effects: None.
  /// Notes: Reasons are not persisted — they are for the page that showed the
  /// plan when it was made, and re-deriving them on a resume would be as easy
  /// as reading them back.
  factory ChunkPlan.fromJson(Map<String, dynamic> json) => ChunkPlan(
    single: json['single'] == true,
    uploadsOriginal: json['uploadsOriginal'] == true,
    strideSeconds: (json['stride'] as num?)?.toDouble() ?? 0,
    overlapSeconds: (json['overlap'] as num?)?.toDouble() ?? 0,
    windows: [
      for (final item in (json['windows'] as List?) ?? const [])
        if (item is Map<String, dynamic>) ChunkWindow.fromJson(item),
    ],
    predictedChunkBytes: (json['predictedChunkBytes'] as num?)?.toInt() ?? 0,
    fingerprint: json['fingerprint'] as String? ?? '',
  );

  /// Purpose: Serialize a plan.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    'single': single,
    'uploadsOriginal': uploadsOriginal,
    'stride': strideSeconds,
    'overlap': overlapSeconds,
    'windows': [for (final window in windows) window.toJson()],
    'predictedChunkBytes': predictedChunkBytes,
    'fingerprint': fingerprint,
  };
}

/// Why a recording cannot be planned at all.
enum PlanFailure {
  /// It needs splitting or converting, and there is no FFmpeg here.
  mediaToolkitMissing,

  /// It needs splitting, and nothing could read its duration.
  durationUnknown,

  /// The recording has no audio.
  noAudio,
}

/// A plan, or the reason there is none.
class PlanResult {
  /// The plan, when one could be made.
  final ChunkPlan? plan;

  /// Why not, when one could not.
  final PlanFailure? failure;

  /// Purpose: Create a successful result.
  /// Inputs: [plan].
  /// Returns: A new result.
  /// Side effects: None.
  /// Notes: None.
  const PlanResult.success(ChunkPlan this.plan) : failure = null;

  /// Purpose: Create a failed result.
  /// Inputs: [failure].
  /// Returns: A new result.
  /// Side effects: None.
  /// Notes: None.
  const PlanResult.failed(PlanFailure this.failure) : plan = null;

  /// Whether a plan was produced.
  bool get isSuccess => plan != null;
}
