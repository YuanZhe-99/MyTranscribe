/// Purpose: Drive the FFmpeg libraries linked into the app.
/// Inputs: None beyond the paths each call is given.
/// Returns: A `MediaToolkit` implementation for Android, iOS and macOS.
/// Side effects: Runs FFmpeg in this process; reads and writes files.
/// Notes: In-process rather than as a child process, which is the only workable
/// route on a sandboxed platform. The commands are the same ones the external
/// backend runs, so a recording normalized on a phone is byte-comparable with
/// one normalized on a desktop — see `doc/en-us/features/media-tools.md`.
///
/// This file is the only one in the app that imports the FFmpeg plugin. It is
/// reached only where `platform_capabilities.dart` reports an embedded backend,
/// so nothing here runs on a platform the plugin was trimmed out of.
library;

import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/media_information.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_audio/statistics.dart';
import 'package:ffmpeg_kit_flutter_new_audio/stream_information.dart';

import '../models/media_info.dart';
import 'media_toolkit.dart';

/// The arguments every invocation starts with.
///
/// The same set the external backend uses, minus `-nostdin`: there is no stdin
/// to protect here, because nothing is spawned.
const _commonArgs = ['-hide_banner', '-loglevel', 'error', '-y'];

class EmbeddedFfmpegMediaToolkit implements MediaToolkit {
  /// Purpose: Create a toolkit over the linked-in libraries.
  /// Inputs: None.
  /// Returns: A new toolkit.
  /// Side effects: None until a method is called.
  /// Notes: None.
  const EmbeddedFfmpegMediaToolkit();

  /// Purpose: Report that media work is available.
  /// Inputs: None.
  /// Returns: An available [MediaToolkitStatus].
  /// Side effects: Runs a trivial FFprobe call to confirm the libraries loaded.
  /// Notes: There are no paths to report and nothing for the user to set up, so
  /// the detail is a phrase rather than a location. The probe is worth its cost
  /// once: a build whose native archive failed to download fails here with a
  /// clear message instead of at the user's first real recording.
  @override
  Future<MediaToolkitStatus> status() async {
    try {
      await FFprobeKit.execute('-version');
      return const MediaToolkitStatus(available: true, detail: 'Built in');
    } catch (error) {
      return MediaToolkitStatus(
        available: false,
        detail: 'The audio libraries did not load: $error',
      );
    }
  }

  /// Purpose: Read a recording's duration and stream details.
  /// Inputs: [path].
  /// Returns: A [MediaInfo].
  /// Side effects: Runs FFprobe in this process.
  /// Notes: A file with no audio stream is [MediaFailureKind.badInput] rather
  /// than a zero-length recording, matching the external backend so callers
  /// have one behaviour to reason about.
  @override
  Future<MediaInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final MediaInformation? information = session.getMediaInformation();
    if (information == null) {
      throw MediaException(
        MediaFailureKind.badInput,
        'The file could not be read as audio.',
        toolOutput: await session.getOutput(),
      );
    }

    final streams = information.getStreams();
    final audio = streams.where((s) => s.getType() == 'audio');
    if (audio.isEmpty) {
      throw const MediaException(
        MediaFailureKind.badInput,
        'That file has no audio to transcribe.',
      );
    }
    final track = audio.first;

    return MediaInfo(
      durationSeconds: double.tryParse(information.getDuration() ?? '') ?? 0,
      bitrateBps: int.tryParse(information.getBitrate() ?? ''),
      audioCodec: track.getCodec(),
      sampleRate: int.tryParse(track.getSampleRate() ?? ''),
      channels: _channelsOf(track),
      hasVideo: streams.any(_isRealVideo),
    );
  }

  /// Purpose: Convert a whole recording to mono 16 kHz 64 kbps MP3.
  /// Inputs: [source], [destination], optional [onProgress] and [cancel].
  /// Returns: A future completing when the file is written.
  /// Side effects: Runs FFmpeg; writes the output.
  /// Notes: Identical settings to the external backend, so the byte budget the
  /// chunk planner relies on holds on every platform.
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
        destination,
      ],
      cancel: cancel,
      onStatistics: onProgress == null
          ? null
          : (statistics) {
              final processed = Duration(milliseconds: statistics.getTime());
              final fraction = total == null || total <= 0
                  ? null
                  : (processed.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);
              onProgress(fraction, processed);
            },
    );
  }

  /// Purpose: Copy one time range out of a normalized recording.
  /// Inputs: [source], [startSeconds], [lengthSeconds], [destination],
  /// optional [cancel].
  /// Returns: A future completing when the window is written.
  /// Side effects: Runs FFmpeg; writes the output.
  /// Notes: `-ss` before `-i` so FFmpeg seeks rather than decoding everything
  /// up to the start. With `-c:a copy` the cut lands on a frame boundary, so
  /// the window can be a few milliseconds off the requested length.
  @override
  Future<void> extractWindow(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    await _run([
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
    ], cancel: cancel);
  }

  /// Purpose: Cut a short 16 kHz mono WAV sample.
  /// Inputs: [source], [startSeconds], [lengthSeconds], [destination],
  /// optional [cancel].
  /// Returns: A future completing when the sample is written.
  /// Side effects: Runs FFmpeg; writes the output.
  /// Notes: Re-encoded rather than copied, so the sample begins exactly where
  /// it was asked to.
  @override
  Future<void> cutSample(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    await _run([
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
    ], cancel: cancel);
  }

  /// Purpose: Run one FFmpeg invocation to completion.
  /// Inputs: The [arguments], and optional [cancel] and [onStatistics].
  /// Returns: A future completing on success.
  /// Side effects: Runs FFmpeg in this process.
  /// Notes: Internal helper used within this file only.
  ///
  /// The plugin's asynchronous entry point is used with a completion callback
  /// rather than its blocking one, because the blocking call would hold the
  /// platform thread for the length of a transcode. The completer bridges that
  /// callback back into a future, and cancellation cancels **this session** by
  /// its id rather than every session — a job's transcode must not cancel
  /// another job's.
  Future<void> _run(
    List<String> arguments, {
    MediaCancelToken? cancel,
    void Function(Statistics)? onStatistics,
  }) async {
    cancel?.throwIfCancelled();

    final completer = Completer<void>();
    StreamSubscription<void>? cancelSubscription;

    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final returnCode = await session.getReturnCode();
        if (completer.isCompleted) return;
        if (ReturnCode.isCancel(returnCode)) {
          completer.completeError(
            const MediaException(
              MediaFailureKind.cancelled,
              'The operation was cancelled.',
            ),
          );
        } else if (ReturnCode.isSuccess(returnCode)) {
          completer.complete();
        } else {
          completer.completeError(
            MediaException(
              MediaFailureKind.toolError,
              'ffmpeg failed with return code '
              '${returnCode?.getValue() ?? 'unknown'}.',
              toolOutput: await session.getOutput(),
            ),
          );
        }
      },
      null,
      onStatistics,
    );

    if (cancel != null) {
      final sessionId = session.getSessionId();
      cancelSubscription = cancel.onCancel.listen(
        (_) => FFmpegKit.cancel(sessionId),
      );
      if (cancel.isCancelled) await FFmpegKit.cancel(sessionId);
    }

    try {
      await completer.future;
    } finally {
      await cancelSubscription?.cancel();
    }
  }
}

/// Purpose: Report whether a stream is real video rather than a cover image.
/// Inputs: [stream].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: An MP3 with embedded album art carries a video stream by codec type.
/// Treating that as video would tell the planner the file can never be uploaded
/// unchanged, which would send every tagged podcast episode through a needless
/// transcode. FFprobe marks the difference with `disposition.attached_pic`.
bool _isRealVideo(StreamInformation stream) {
  if (stream.getType() != 'video') return false;
  final disposition = stream.getAllProperties()?['disposition'];
  if (disposition is Map) return disposition['attached_pic'] != 1;
  return true;
}

/// Purpose: Read a stream's channel count.
/// Inputs: [stream].
/// Returns: The count, or null when the stream does not state one.
/// Side effects: None.
/// Notes: FFprobe reports `channels` as a number in the raw properties; the
/// plugin's typed accessor exposes only the channel *layout* string, so this
/// reads the property directly and falls back to the layout name for the two
/// cases that matter.
int? _channelsOf(StreamInformation stream) {
  final raw = stream.getAllProperties()?['channels'];
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return switch (stream.getChannelLayout()) {
    'mono' => 1,
    'stereo' => 2,
    _ => null,
  };
}
