/// Purpose: Read FFmpeg's machine-readable progress stream.
/// Inputs: The lines FFmpeg writes to stdout under `-progress pipe:1`.
/// Returns: How far it has got, and whether it has finished.
/// Side effects: None — a pure parser, so the whole format is testable without
/// running anything.
/// Notes: FFmpeg's human-readable status line on stderr is not parsed. It is
/// formatted for people, changes between builds, and is overwritten in place
/// with carriage returns. The `-progress` stream exists precisely to be read by
/// a program: one `key=value` per line, ending in `progress=continue` or
/// `progress=end`.
library;

/// One progress report from FFmpeg.
class FfmpegProgress {
  /// How much of the input has been processed.
  final Duration processed;

  /// Whether FFmpeg reported this as its final block.
  final bool finished;

  /// The output size in bytes, when reported.
  ///
  /// Worth having: it is how the caller can notice a window that is going to
  /// come out over the upload limit before waiting for it to finish.
  final int? totalSizeBytes;

  /// The encoding speed as a multiple of real time, when reported.
  final double? speed;

  /// Purpose: Create a progress report.
  /// Inputs: [processed], [finished], optional [totalSizeBytes] and [speed].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FfmpegProgress({
    required this.processed,
    required this.finished,
    this.totalSizeBytes,
    this.speed,
  });

  /// Purpose: Work out the fraction complete against a known total.
  /// Inputs: [totalSeconds] — the input duration, or null when unknown.
  /// Returns: `double` from 0 to 1, or null when it cannot be known.
  /// Side effects: None.
  /// Notes: Clamped, because FFmpeg's reported time can run a little past the
  /// duration the container declared, and a progress bar at 1.02 looks broken.
  double? fractionOf(double? totalSeconds) {
    if (totalSeconds == null || totalSeconds <= 0) return null;
    final value = processed.inMilliseconds / (totalSeconds * 1000);
    return value.clamp(0.0, 1.0);
  }
}

/// Accumulates `key=value` lines into progress reports.
///
/// FFmpeg writes a block of keys and ends it with `progress=continue` or
/// `progress=end`. Stdout arrives in arbitrary chunks, so this holds the
/// partial block between calls and emits one report per completed block.
class FfmpegProgressParser {
  /// Keys seen since the last completed block.
  final _pending = <String, String>{};

  /// Purpose: Feed one line of FFmpeg's progress output.
  /// Inputs: [line] — one line, with or without trailing whitespace.
  /// Returns: A [FfmpegProgress] when the line completed a block, else null.
  /// Side effects: Accumulates state until a block ends.
  /// Notes: A line without an `=` is ignored rather than treated as an error:
  /// the stream is not a contract this app controls, and a blank line or an
  /// unexpected one should not stop a conversion that is working.
  FfmpegProgress? add(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    final split = trimmed.indexOf('=');
    if (split <= 0) return null;

    final key = trimmed.substring(0, split).trim();
    final value = trimmed.substring(split + 1).trim();

    if (key != 'progress') {
      _pending[key] = value;
      return null;
    }

    final report = FfmpegProgress(
      processed: _readProcessedTime(),
      finished: value == 'end',
      totalSizeBytes: _readInt('total_size'),
      speed: _readSpeed(),
    );
    _pending.clear();
    return report;
  }

  /// Purpose: Feed a chunk of stdout that may hold several lines.
  /// Inputs: [chunk] — decoded text of any length.
  /// Returns: Every report the chunk completed, in order.
  /// Side effects: Accumulates state.
  /// Notes: Splits on either line ending; the tool's output is text either way.
  List<FfmpegProgress> addChunk(String chunk) => [
    for (final line in chunk.split(RegExp(r'\r?\n'))) ?add(line),
  ];

  /// Purpose: Read how much input has been processed.
  /// Inputs: None; reads the pending block.
  /// Returns: A [Duration], zero when neither time key is present.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. `out_time_us` is
  /// preferred because it is a plain integer; `out_time` is a `hh:mm:ss.mmm`
  /// string kept as a fallback for builds that omit the microsecond key. Both
  /// can read `N/A` before the first frame, which parses as zero.
  Duration _readProcessedTime() {
    final micros = _readInt('out_time_us') ?? _readInt('out_time_ms');
    if (micros != null) return Duration(microseconds: micros);

    final text = _pending['out_time'];
    if (text == null) return Duration.zero;
    final match = RegExp(
      r'^(\d+):(\d{2}):(\d{2})(?:\.(\d{1,6}))?$',
    ).firstMatch(text);
    if (match == null) return Duration.zero;
    final fraction = match.group(4) ?? '';
    return Duration(
      hours: int.parse(match.group(1)!),
      minutes: int.parse(match.group(2)!),
      seconds: int.parse(match.group(3)!),
      milliseconds: fraction.isEmpty
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3)),
    );
  }

  /// Purpose: Read an integer key from the pending block.
  /// Inputs: [key].
  /// Returns: The value, or null when absent or not a number.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. FFmpeg writes `N/A`
  /// for a value it does not have yet, which parses to null.
  int? _readInt(String key) {
    final value = _pending[key];
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Purpose: Read the `speed` key, which is written as `1.23x`.
  /// Inputs: None; reads the pending block.
  /// Returns: The multiplier, or null when absent or not yet known.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  double? _readSpeed() {
    final value = _pending['speed'];
    if (value == null) return null;
    return double.tryParse(value.replaceAll('x', '').trim());
  }
}

/// Purpose: Read a duration out of FFmpeg's own banner on stderr.
/// Inputs: [stderrText] — anything FFmpeg printed.
/// Returns: The duration in seconds, or null when the banner has none.
/// Side effects: None.
/// Notes: The fallback for a machine with `ffmpeg` but no `ffprobe`. It is the
/// same regular expression the original Python scripts used, and it is a
/// fallback rather than the main path because the banner is formatted for
/// people: `ffprobe -print_format json` is a contract, this is not.
double? parseDurationFromBanner(String stderrText) {
  final match = RegExp(
    r'Duration:\s*(\d+):(\d{2}):(\d{2}(?:\.\d+)?)',
  ).firstMatch(stderrText);
  if (match == null) return null;
  return int.parse(match.group(1)!) * 3600 +
      int.parse(match.group(2)!) * 60 +
      double.parse(match.group(3)!);
}
