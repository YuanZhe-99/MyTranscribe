/// Purpose: Drive `ffmpeg` and `ffprobe` as child processes.
/// Inputs: A locator that resolves the two executables.
/// Returns: A `MediaToolkit` implementation for Windows and Linux.
/// Side effects: Starts processes, reads and writes files.
/// Notes: Used where the FFmpeg libraries cannot be linked in — see
/// `doc/en-us/platform-notes.md` for why that is Windows here. Processes are
/// started attached with pipes, which Dart creates without a console window on
/// Windows, so nothing flashes while a job runs.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/media_info.dart';
import 'ffmpeg_locator.dart';
import 'ffmpeg_progress_parser.dart';
import 'media_toolkit.dart';

/// How many lines of a tool's stderr to keep for an error message.
///
/// FFmpeg prints its banner and then the actual complaint, so the tail is the
/// useful part. Twenty lines is enough to carry a codec error with its context
/// and short enough to put in a dialog.
const _stderrTailLines = 20;

/// The arguments every invocation starts with.
///
/// `-nostdin` matters: without it FFmpeg tries to read the console, and a
/// process started from a GUI app with a piped stdin can hang waiting for input
/// that will never come.
const _commonArgs = ['-nostdin', '-hide_banner', '-loglevel', 'error', '-y'];

class ExternalFfmpegMediaToolkit implements MediaToolkit {
  /// Finds the executables.
  final FfmpegLocator locator;

  /// Purpose: Create a toolkit over external executables.
  /// Inputs: [locator].
  /// Returns: A new toolkit.
  /// Side effects: None until a method is called.
  /// Notes: Tools are resolved on each call rather than cached, so setting a
  /// path in Settings or finishing a download takes effect immediately.
  const ExternalFfmpegMediaToolkit({required this.locator});

  /// Purpose: Resolve one executable or fail with a useful message.
  /// Inputs: [name] — `ffmpeg` or `ffprobe`.
  /// Returns: The tool.
  /// Side effects: Searches the file system.
  /// Notes: Internal helper used within this file only.
  Future<FfmpegTool> _require(String name) async {
    final tool = await locator.locate(name);
    if (tool == null) {
      throw MediaException(
        MediaFailureKind.toolMissing,
        '$name was not found. Set its location in Settings, or let the app '
        'download a copy.',
      );
    }
    return tool;
  }

  /// Purpose: Report whether both executables are present.
  /// Inputs: None.
  /// Returns: A [MediaToolkitStatus] naming the paths and the version.
  /// Side effects: Searches the file system and runs `ffmpeg -version`.
  /// Notes: `ffprobe` missing is reported as unavailable even though probing
  /// could fall back to reading `ffmpeg`'s banner, because a machine with one
  /// and not the other is almost always a half-finished install the user wants
  /// to know about.
  @override
  Future<MediaToolkitStatus> status() async {
    final ffmpeg = await locator.locate('ffmpeg');
    final ffprobe = await locator.locate('ffprobe');
    if (ffmpeg == null || ffprobe == null) {
      final missing = [
        if (ffmpeg == null) 'ffmpeg',
        if (ffprobe == null) 'ffprobe',
      ].join(' and ');
      return MediaToolkitStatus(
        available: false,
        detail: '$missing not found',
        ffmpegPath: ffmpeg?.path,
        ffprobePath: ffprobe?.path,
      );
    }

    var version = ffmpeg.source.name;
    try {
      final result = await Process.run(ffmpeg.path, const ['-version']);
      final firstLine = const LineSplitter()
          .convert('${result.stdout}')
          .firstOrNull;
      if (firstLine != null && firstLine.isNotEmpty) version = firstLine;
    } catch (_) {
      // The version line is a nicety; the paths below are the real answer.
    }

    return MediaToolkitStatus(
      available: true,
      detail: version,
      ffmpegPath: ffmpeg.path,
      ffprobePath: ffprobe.path,
    );
  }

  /// Purpose: Read a recording's duration and stream details.
  /// Inputs: [path].
  /// Returns: A [MediaInfo].
  /// Side effects: Runs `ffprobe`.
  /// Notes: Asks for JSON, which is a stable contract, rather than parsing the
  /// human-readable banner. A file with no audio stream at all is a
  /// [MediaFailureKind.badInput] rather than a zero-length recording, because
  /// the caller needs to tell those apart.
  @override
  Future<MediaInfo> probe(String path) async {
    if (!File(path).existsSync()) {
      throw MediaException(
        MediaFailureKind.badInput,
        'The recording could not be found: $path',
      );
    }
    final ffprobe = await _require('ffprobe');

    final result = await Process.run(ffprobe.path, [
      '-v',
      'error',
      '-print_format',
      'json',
      '-show_format',
      '-show_streams',
      path,
    ]);
    if (result.exitCode != 0) {
      throw MediaException(
        MediaFailureKind.badInput,
        'The file could not be read as audio.',
        toolOutput: _tail('${result.stderr}'),
      );
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    } on FormatException catch (error) {
      throw MediaException(
        MediaFailureKind.toolError,
        'ffprobe returned something unreadable.',
        toolOutput: '$error',
      );
    }

    final streams = (json['streams'] as List?) ?? const [];
    final audio = streams.cast<Map<String, dynamic>>().where(
      (s) => s['codec_type'] == 'audio',
    );
    if (audio.isEmpty) {
      throw const MediaException(
        MediaFailureKind.badInput,
        'That file has no audio to transcribe.',
      );
    }
    final track = audio.first;
    final format = (json['format'] as Map<String, dynamic>?) ?? const {};

    return MediaInfo(
      durationSeconds:
          _toDouble(format['duration']) ?? _toDouble(track['duration']) ?? 0,
      bitrateBps: _toInt(format['bit_rate']),
      audioCodec: track['codec_name'] as String?,
      sampleRate: _toInt(track['sample_rate']),
      channels: _toInt(track['channels']),
      hasVideo: streams.cast<Map<String, dynamic>>().any(
        // A cover image is a video stream by codec type; it is not video.
        (s) => s['codec_type'] == 'video' && s['disposition'] is Map
            ? (s['disposition'] as Map)['attached_pic'] != 1
            : s['codec_type'] == 'video',
      ),
    );
  }

  /// Purpose: Convert a whole recording to mono 16 kHz 64 kbps MP3.
  /// Inputs: [source], [destination], optional [onProgress] and [cancel].
  /// Returns: A future completing when the file is written.
  /// Side effects: Runs `ffmpeg`; writes and, on failure, deletes the output.
  /// Notes: `-vn` drops any video, including a cover image, which would
  /// otherwise be carried into the MP3 and inflate every window cut from it.
  @override
  Future<void> normalize(
    String source,
    String destination, {
    MediaProgress? onProgress,
    MediaCancelToken? cancel,
  }) async {
    double? total;
    if (onProgress != null) {
      try {
        total = (await probe(source)).durationSeconds;
      } catch (_) {
        // Progress becomes indeterminate rather than the conversion failing.
      }
    }

    await _run(
      await _require('ffmpeg'),
      [
        ..._commonArgs,
        '-i',
        source,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'libmp3lame',
        '-b:a',
        '64k',
        '-progress',
        'pipe:1',
        destination,
      ],
      destination: destination,
      cancel: cancel,
      onProgress: onProgress == null
          ? null
          : (report) => onProgress(report.fractionOf(total), report.processed),
    );
  }

  /// Purpose: Copy one time range out of a normalized recording.
  /// Inputs: [source], [startSeconds], [lengthSeconds], [destination],
  /// optional [cancel].
  /// Returns: A future completing when the window is written.
  /// Side effects: Runs `ffmpeg`; writes and, on failure, deletes the output.
  /// Notes: `-ss` goes **before** `-i` so FFmpeg seeks rather than decoding
  /// and discarding everything up to the start — on a two-hour recording that
  /// is the difference between instant and a minute. With `-c:a copy` the cut
  /// lands on a frame boundary, so the window can be a few milliseconds off the
  /// requested length; the merge is written not to care.
  @override
  Future<void> extractWindow(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    await _run(
      await _require('ffmpeg'),
      [
        ..._commonArgs,
        '-ss',
        startSeconds.toStringAsFixed(3),
        '-i',
        source,
        '-t',
        lengthSeconds.toStringAsFixed(3),
        '-vn',
        '-c:a',
        'copy',
        destination,
      ],
      destination: destination,
      cancel: cancel,
    );
  }

  /// Purpose: Cut a short 16 kHz mono WAV sample.
  /// Inputs: [source], [startSeconds], [lengthSeconds], [destination],
  /// optional [cancel].
  /// Returns: A future completing when the sample is written.
  /// Side effects: Runs `ffmpeg`; writes and, on failure, deletes the output.
  /// Notes: Re-encoded rather than copied, so the sample begins exactly where
  /// it was asked to. A reference clip that starts half a word early is worth
  /// less than the milliseconds saved.
  @override
  Future<void> cutSample(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    await _run(
      await _require('ffmpeg'),
      [
        ..._commonArgs,
        '-ss',
        startSeconds.toStringAsFixed(3),
        '-i',
        source,
        '-t',
        lengthSeconds.toStringAsFixed(3),
        '-vn',
        '-ac',
        '1',
        '-ar',
        '16000',
        '-c:a',
        'pcm_s16le',
        destination,
      ],
      destination: destination,
      cancel: cancel,
    );
  }

  /// Purpose: Run one FFmpeg invocation to completion.
  /// Inputs: The [tool], its [arguments], the [destination] to clean up on
  /// failure, and optional [cancel] and [onProgress].
  /// Returns: A future completing on success.
  /// Side effects: Starts a process; deletes a partial output on any failure.
  /// Notes: Internal helper used within this file only.
  ///
  /// Started with [ProcessStartMode.normal] and piped, which is what keeps
  /// Windows from opening a console window. Stdout carries the progress stream
  /// and stderr is buffered so a failure can quote it. Cancelling kills the
  /// process, which makes it exit non-zero — hence the explicit cancellation
  /// check before the exit code is judged, so a cancel is not reported as a
  /// tool error.
  Future<void> _run(
    FfmpegTool tool,
    List<String> arguments, {
    required String destination,
    MediaCancelToken? cancel,
    void Function(FfmpegProgress)? onProgress,
  }) async {
    cancel?.throwIfCancelled();

    final Process process;
    try {
      process = await Process.start(tool.path, arguments);
    } catch (error) {
      throw MediaException(
        MediaFailureKind.toolFailed,
        'ffmpeg could not be started.',
        toolOutput: '$error',
      );
    }

    final parser = FfmpegProgressParser();
    final stderrLines = <String>[];
    StreamSubscription<void>? cancelSubscription;

    final stdoutDone = process.stdout.transform(utf8.decoder).listen((chunk) {
      if (onProgress == null) return;
      for (final report in parser.addChunk(chunk)) {
        onProgress(report);
      }
    }).asFuture<void>();

    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderrLines.add(line);
          if (stderrLines.length > _stderrTailLines) stderrLines.removeAt(0);
        })
        .asFuture<void>();

    if (cancel != null) {
      cancelSubscription = cancel.onCancel.listen((_) => process.kill());
      if (cancel.isCancelled) process.kill();
    }

    final exitCode = await process.exitCode;
    await cancelSubscription?.cancel();
    await stdoutDone;
    await stderrDone;

    if (cancel?.isCancelled ?? false) {
      await _deleteQuietly(destination);
      throw const MediaException(
        MediaFailureKind.cancelled,
        'The operation was cancelled.',
      );
    }
    if (exitCode != 0) {
      await _deleteQuietly(destination);
      throw MediaException(
        MediaFailureKind.toolError,
        'ffmpeg failed with exit code $exitCode.',
        toolOutput: stderrLines.join('\n'),
      );
    }
  }

  /// Purpose: Remove a partial output, ignoring failures.
  /// Inputs: [path].
  /// Returns: A future completing either way.
  /// Side effects: Deletes a file when it exists.
  /// Notes: Internal helper used within this file only. A half-written window
  /// left behind would be reused by a resume, whose only check is the file's
  /// size, so cleaning up here is what keeps that check honest.
  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Purpose: Keep the last lines of a tool's output.
  /// Inputs: [text].
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _tail(String text) {
    final lines = const LineSplitter().convert(text);
    if (lines.length <= _stderrTailLines) return text.trim();
    return lines.sublist(lines.length - _stderrTailLines).join('\n');
  }
}

/// Purpose: Read a JSON value that may be a number or a numeric string.
/// Inputs: [value].
/// Returns: The number, or null.
/// Side effects: None.
/// Notes: `ffprobe` writes numbers as strings in its JSON output, and writes
/// `N/A` when it does not know, which parses to null.
double? _toDouble(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};

/// Purpose: Read a JSON value that may be an integer or a numeric string.
/// Inputs: [value].
/// Returns: The integer, or null.
/// Side effects: None.
/// Notes: See [_toDouble].
int? _toInt(Object? value) => switch (value) {
  final int n => n,
  final num n => n.round(),
  final String s => int.tryParse(s),
  _ => null,
};
