/// Purpose: The one interface the rest of the app uses to touch audio, and the
/// value types that go with it.
/// Inputs: Implemented by the external-executable and embedded-library
/// backends.
/// Returns: `MediaToolkit`, `MediaToolkitStatus`, `MediaCancelToken` and the
/// failure type.
/// Side effects: None here; implementations do file and process work.
/// Notes: Nothing above this interface knows whether FFmpeg is a child process
/// or a linked-in library. That is the whole point: the two platforms differ
/// for reasons recorded in `doc/en-us/platform-notes.md`, and the job runner
/// should not have to care.
library;

import 'dart:async';

import '../models/media_info.dart';

/// Why a media operation failed.
enum MediaFailureKind {
  /// No usable FFmpeg was found, or the app has no backend on this platform.
  toolMissing,

  /// The tool was found but would not start.
  toolFailed,

  /// The input file is absent, unreadable, or not media the tool can open.
  badInput,

  /// The tool ran and reported an error.
  toolError,

  /// The caller cancelled the operation.
  cancelled,
}

/// A media operation that did not finish.
class MediaException implements Exception {
  /// What went wrong, in a form the UI can branch on.
  final MediaFailureKind kind;

  /// A sentence naming what failed, for a log or a dialog.
  final String message;

  /// The last lines the tool printed, when it printed any.
  ///
  /// FFmpeg says something specific and useful on stderr — an unsupported
  /// codec, a missing file, a broken pipe. Throwing that away and showing
  /// "conversion failed" would waste the one thing that explains the failure.
  final String? toolOutput;

  /// Purpose: Create a media exception.
  /// Inputs: [kind], [message], optional [toolOutput].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const MediaException(this.kind, this.message, {this.toolOutput});

  /// Purpose: Render the failure for a log.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => toolOutput == null || toolOutput!.isEmpty
      ? 'MediaException(${kind.name}): $message'
      : 'MediaException(${kind.name}): $message\n$toolOutput';
}

/// Whether this device can do media work, and with what.
class MediaToolkitStatus {
  /// Whether probing, converting and splitting are available.
  final bool available;

  /// Where the tools came from, for the settings row: a path, a version
  /// string, or a short phrase such as "built in".
  final String detail;

  /// The resolved `ffmpeg` path, when there is a path to name.
  final String? ffmpegPath;

  /// The resolved `ffprobe` path, when there is a path to name.
  final String? ffprobePath;

  /// Purpose: Create a status value.
  /// Inputs: [available], [detail], optional tool paths.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const MediaToolkitStatus({
    required this.available,
    required this.detail,
    this.ffmpegPath,
    this.ffprobePath,
  });
}

/// A cancellation signal shared between a caller and a running operation.
///
/// One token may be passed to several operations — a job cancels its transcode
/// and its current upload with the same one — and cancelling is idempotent.
class MediaCancelToken {
  bool _cancelled = false;
  final _controller = StreamController<void>.broadcast();

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Fires once when cancellation is requested.
  ///
  /// An implementation listens to this to kill a process or cancel a session
  /// while it is blocked waiting for one to finish.
  Stream<void> get onCancel => _controller.stream;

  /// Purpose: Request cancellation.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Sets the flag and notifies listeners.
  /// Notes: Idempotent. A second call does nothing, so a job that cancels both
  /// its transcode and its upload through one token is safe.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_controller.isClosed) _controller.add(null);
  }

  /// Purpose: Release the token's stream.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Closes the broadcast controller.
  /// Notes: Call when the work the token guards is over, cancelled or not.
  Future<void> dispose() => _controller.close();

  /// Purpose: Throw if cancellation has been requested.
  /// Inputs: None.
  /// Returns: None; throws [MediaException] when cancelled.
  /// Side effects: None.
  /// Notes: Called between steps, so a cancelled operation stops at the next
  /// boundary rather than only when a process happens to exit.
  void throwIfCancelled() {
    if (_cancelled) {
      throw const MediaException(
        MediaFailureKind.cancelled,
        'The operation was cancelled.',
      );
    }
  }
}

/// Purpose: Report how far a long media operation has got.
/// Inputs: [fraction] from 0 to 1 where it can be known, and [processed], how
/// much of the input has been handled.
/// Returns: None.
/// Side effects: Caller-defined; normally updates a progress notifier.
/// Notes: [fraction] is null when the total is unknown, which is what a
/// progress bar wants for an indeterminate state.
typedef MediaProgress = void Function(double? fraction, Duration processed);

/// Everything the app needs FFmpeg for.
abstract class MediaToolkit {
  /// Purpose: Report whether media work is possible here, and with what.
  /// Inputs: None.
  /// Returns: A [MediaToolkitStatus].
  /// Side effects: May look for executables on disk and run one to read its
  /// version.
  /// Notes: Called by Settings and before a job that needs splitting. An
  /// unavailable toolkit is not fatal: a recording small enough to upload
  /// unchanged still transcribes.
  Future<MediaToolkitStatus> status();

  /// Purpose: Read a recording's duration and stream details.
  /// Inputs: [path] to the file.
  /// Returns: A [MediaInfo].
  /// Side effects: Reads the file's headers.
  /// Notes: Throws [MediaException] with [MediaFailureKind.badInput] when the
  /// file is not media, rather than returning a zero duration — the caller
  /// needs to tell "no audio" from "could not tell".
  Future<MediaInfo> probe(String path);

  /// Purpose: Convert a whole recording to the one format every window is cut
  /// from.
  /// Inputs: [source] path, [destination] path, optional [onProgress] and
  /// [cancel].
  /// Returns: A future completing when the file is written.
  /// Side effects: Writes [destination]; deletes a partial file on failure.
  /// Notes: Mono, 16 kHz, 64 kbps MP3 — the settings the original scripts
  /// used. Doing this once rather than per window is what makes a window's
  /// size exactly predictable, and the result doubles as the transcript
  /// viewer's listening copy.
  Future<void> normalize(
    String source,
    String destination, {
    MediaProgress? onProgress,
    MediaCancelToken? cancel,
  });

  /// Purpose: Copy one time range out of a normalized recording.
  /// Inputs: [source] normalized file, [startSeconds], [lengthSeconds],
  /// [destination], optional [cancel].
  /// Returns: A future completing when the window is written.
  /// Side effects: Writes [destination].
  /// Notes: Copies the encoded stream rather than re-encoding it, so this is
  /// fast and lossless. It also means a cut lands on a frame boundary, which is
  /// why the caller must not assume the window is exactly the requested length.
  Future<void> extractWindow(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  });

  /// Purpose: Cut a short sample for identifying a speaker.
  /// Inputs: [source], [startSeconds], [lengthSeconds], [destination],
  /// optional [cancel].
  /// Returns: A future completing when the sample is written.
  /// Side effects: Writes [destination].
  /// Notes: Uncompressed 16 kHz mono WAV, which is what the APIs that accept a
  /// reference clip ask for. Re-encoded rather than copied, because the sample
  /// must start exactly where it was asked to.
  Future<void> cutSample(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  });
}

/// A toolkit for a platform that has no FFmpeg at all.
///
/// Every call fails with [MediaFailureKind.toolMissing]. Having this instead of
/// a null toolkit means the caller has one error path rather than two, and the
/// message says what is wrong instead of throwing a null error.
class UnavailableMediaToolkit implements MediaToolkit {
  /// The sentence shown wherever this toolkit is asked to do something.
  final String reason;

  /// Purpose: Create an unavailable toolkit.
  /// Inputs: [reason] — one sentence naming why.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const UnavailableMediaToolkit(this.reason);

  /// Purpose: Report that nothing is available.
  /// Inputs: None.
  /// Returns: An unavailable [MediaToolkitStatus] carrying [reason].
  /// Side effects: None.
  /// Notes: None.
  @override
  Future<MediaToolkitStatus> status() async =>
      MediaToolkitStatus(available: false, detail: reason);

  /// Purpose: Fail, naming the missing tool.
  /// Inputs: Ignored.
  /// Returns: Never; always throws.
  /// Side effects: None.
  /// Notes: None.
  Never _fail() => throw MediaException(MediaFailureKind.toolMissing, reason);

  @override
  Future<MediaInfo> probe(String path) async => _fail();

  @override
  Future<void> normalize(
    String source,
    String destination, {
    MediaProgress? onProgress,
    MediaCancelToken? cancel,
  }) async => _fail();

  @override
  Future<void> extractWindow(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async => _fail();

  @override
  Future<void> cutSample(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async => _fail();
}
