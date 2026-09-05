/// Purpose: What the app needs to know about a recording before it can plan
/// how to transcribe it.
/// Inputs: Produced by a `MediaToolkit.probe` implementation.
/// Returns: The `MediaInfo` value type.
/// Side effects: None.
/// Notes: Everything here is optional except the duration, because the two
/// backends learn different amounts about a file and the planner is written to
/// work from whatever it gets. A field the probe could not determine is null,
/// never a zero standing in for "unknown" — the planner treats those
/// differently.
library;

/// What a probe learned about one recording.
class MediaInfo {
  /// How long the recording runs, in seconds.
  final double durationSeconds;

  /// The overall bit rate in bits per second, when the container states one.
  ///
  /// Only used for an estimate the user sees. The chunk planner deliberately
  /// does not read it: it sizes windows from the bit rate the app itself will
  /// re-encode to, which is fixed and therefore exactly predictable.
  final int? bitrateBps;

  /// The audio codec name the container reports, such as `mp3` or `aac`.
  final String? audioCodec;

  /// The audio sample rate in hertz.
  final int? sampleRate;

  /// How many audio channels the recording has.
  final int? channels;

  /// Whether the file also carries a video stream.
  ///
  /// A video file is a perfectly good source — the audio is extracted — but it
  /// can never be uploaded unchanged, however small it is.
  final bool hasVideo;

  /// Purpose: Create a media info instance.
  /// Inputs: [durationSeconds] and the optional stream details.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const MediaInfo({
    required this.durationSeconds,
    this.bitrateBps,
    this.audioCodec,
    this.sampleRate,
    this.channels,
    this.hasVideo = false,
  });

  /// Purpose: Report whether the recording is long enough to be worth
  /// transcribing.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: A probe that returns zero usually means the file is not audio at
  /// all, or is truncated. Either way there is nothing to send.
  bool get hasAudio => durationSeconds > 0;

  /// Purpose: Render the duration as `h:mm:ss` or `m:ss`.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: For display beside a file name. The hour part is dropped for a
  /// recording under an hour rather than shown as a zero.
  String get formattedDuration {
    final total = durationSeconds.round();
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
    }
    return '$minutes:$ss';
  }

  /// Purpose: Describe the streams in one short line.
  /// Inputs: None.
  /// Returns: `String`, empty when nothing was determined.
  /// Side effects: None.
  /// Notes: Built from whatever the probe supplied, so a backend that reports
  /// less produces a shorter line rather than one full of "unknown".
  String get summary => [
    ?audioCodec,
    if (sampleRate != null) '${(sampleRate! / 1000).toStringAsFixed(1)} kHz',
    if (channels == 1) 'mono' else if (channels != null) '$channels ch',
    if (hasVideo) 'video',
  ].join(' · ');
}
