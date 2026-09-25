/// Purpose: Fetch one file of a model package, resuming where a previous
/// attempt stopped, and prove it is the file the manifest names.
/// Inputs: A manifest file entry and a partial-download path.
/// Returns: The verified file, still at its partial path.
/// Side effects: Makes HTTP requests; writes and may delete the partial file.
/// Notes: Model files run to gigabytes and phones change networks, so a
/// download that restarts from zero on every interruption would never finish.
/// A range request continues it; the SHA-256 over the whole file at the end is
/// what makes a resumed file trustworthy. Downloads come only from the URL in
/// the manifest (decision D17 of the local-models plan). See
/// `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/artifact_manifest.dart';

/// Why a package could not be downloaded or installed.
enum ArtifactFailure {
  /// The server could not be reached, or the connection dropped.
  network,

  /// The server answered with an error.
  httpError,

  /// The file arrived, but its size or SHA-256 is not the manifest's.
  hashMismatch,

  /// There is not enough free space for the download, the unpacking and the
  /// install together.
  diskFull,

  /// An archive would not unpack.
  unpackFailed,

  /// The package is in use by a running job.
  leased,

  /// The manifest is not one this build can install.
  badManifest,

  /// The user cancelled.
  cancelled,
}

/// A download or install that did not finish.
class ArtifactException implements Exception {
  /// What went wrong.
  final ArtifactFailure failure;

  /// A sentence for a log or the library row.
  final String message;

  /// Purpose: Create an artifact exception.
  /// Inputs: [failure], [message].
  /// Returns: A new exception.
  /// Side effects: None.
  /// Notes: None.
  const ArtifactException(this.failure, this.message);

  /// Purpose: Render the failure for a log.
  /// Inputs: None.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: None.
  @override
  String toString() => 'ArtifactException(${failure.name}): $message';
}

/// A cancellation signal for a download.
class DownloadCancelToken {
  bool _cancelled = false;
  final _listeners = <void Function()>[];

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelled;

  /// Purpose: Request cancellation.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Notifies listeners once.
  /// Notes: Idempotent.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  /// Purpose: Run [listener] when cancellation is requested.
  /// Inputs: [listener].
  /// Returns: None.
  /// Side effects: Registers the listener.
  /// Notes: Internal to this feature; the downloader uses it to close a
  /// response stream mid-read.
  void onCancel(void Function() listener) => _listeners.add(listener);
}

/// Purpose: Report download progress.
/// Inputs: Bytes on disk so far for this file, and the file's total.
/// Returns: None.
/// Side effects: Caller-defined.
/// Notes: Bytes a resume found already on disk count from the first report,
/// so a progress bar resumes where it stopped rather than at zero.
typedef DownloadProgress = void Function(int received, int total);

/// Downloads single files with range resumption and hash verification.
class ArtifactDownloader {
  /// The HTTP client factory, injectable for tests.
  final http.Client Function() clientFactory;

  /// Purpose: Create a downloader.
  /// Inputs: Optional [clientFactory].
  /// Returns: A new downloader.
  /// Side effects: None.
  /// Notes: None.
  ArtifactDownloader({http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;

  /// Purpose: Download [file] to [partial], resuming, and verify it.
  /// Inputs: The manifest entry, the partial-download path, optional
  /// [onProgress] and [cancel].
  /// Returns: [partial], complete and verified.
  /// Side effects: Writes [partial]; deletes it when its hash is wrong.
  /// Notes: A partial file already the full size is verified without asking
  /// the network. A server that ignores the range and sends the whole file
  /// again (200 rather than 206) restarts the file rather than appending a
  /// second copy to it. A wrong hash deletes the file, because resuming a
  /// corrupt prefix would corrupt every later attempt too.
  Future<File> download(
    ArtifactFile file,
    File partial, {
    DownloadProgress? onProgress,
    DownloadCancelToken? cancel,
  }) async {
    await partial.parent.create(recursive: true);
    var have = await partial.exists() ? await partial.length() : 0;
    if (have > file.bytes) {
      await partial.delete();
      have = 0;
    }

    if (have < file.bytes) {
      await _fetch(file, partial, have, onProgress, cancel);
    } else {
      onProgress?.call(have, file.bytes);
    }

    final length = await partial.length();
    final digest = await hashFile(partial);
    if (length != file.bytes || digest != file.sha256) {
      await _deleteQuietly(partial);
      throw ArtifactException(
        ArtifactFailure.hashMismatch,
        '${file.path}: expected ${file.bytes} bytes with SHA-256 '
        '${file.sha256}, got $length bytes with $digest.',
      );
    }
    return partial;
  }

  /// Purpose: Fetch the missing tail of a file.
  /// Inputs: The entry, the [partial] file, the bytes it already [have], and
  /// the callbacks.
  /// Returns: None.
  /// Side effects: Makes one HTTP request; appends to or rewrites [partial].
  /// Notes: Internal helper used within this file only.
  Future<void> _fetch(
    ArtifactFile file,
    File partial,
    int have,
    DownloadProgress? onProgress,
    DownloadCancelToken? cancel,
  ) async {
    if (cancel?.isCancelled ?? false) throw _cancelled();
    final client = clientFactory();
    IOSink? sink;
    StreamSubscription<List<int>>? subscription;
    try {
      final request = http.Request('GET', Uri.parse(file.sourceUrl));
      if (have > 0) request.headers['Range'] = 'bytes=$have-';

      final http.StreamedResponse response;
      try {
        response = await client.send(request);
      } on SocketException catch (error) {
        throw ArtifactException(ArtifactFailure.network, error.message);
      } on http.ClientException catch (error) {
        throw ArtifactException(ArtifactFailure.network, error.message);
      }

      final int start;
      if (response.statusCode == 206 && have > 0) {
        start = have;
      } else if (response.statusCode == 200) {
        start = 0;
      } else if (response.statusCode == 416 && have > 0) {
        // The server says there is nothing past what we have; let the hash
        // decide whether what we have is the file.
        await response.stream.drain<void>();
        return;
      } else {
        await response.stream.drain<void>();
        throw ArtifactException(
          ArtifactFailure.httpError,
          '${file.path}: the server answered ${response.statusCode}.',
        );
      }

      sink = partial.openWrite(
        mode: start == 0 ? FileMode.writeOnly : FileMode.append,
      );
      var received = start;
      onProgress?.call(received, file.bytes);

      final done = Completer<void>();
      subscription = response.stream.listen(
        (chunk) {
          sink!.add(chunk);
          received += chunk.length;
          onProgress?.call(received, file.bytes);
        },
        onError: (Object error) {
          if (!done.isCompleted) {
            done.completeError(
              ArtifactException(ArtifactFailure.network, '$error'),
            );
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      cancel?.onCancel(() {
        if (!done.isCompleted) done.completeError(_cancelled());
      });
      await done.future;
      // A write that failed for want of space surfaces here, on the flush,
      // rather than on the add that caused it.
      final written = sink;
      sink = null;
      await written.flush();
      await written.close();
    } on FileSystemException catch (error) {
      throw diskFullOr(error);
    } finally {
      await subscription?.cancel();
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      client.close();
    }
  }
}

/// Purpose: Compute a file's SHA-256 without reading it into memory.
/// Inputs: [file].
/// Returns: The lower-case hex digest.
/// Side effects: Reads the file.
/// Notes: A model is gigabytes; reading it whole would take that much memory
/// on a phone that has just been asked to load it.
Future<String> hashFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Purpose: Turn a file-system error into a disk-full failure where it is one.
/// Inputs: [error].
/// Returns: An [ArtifactException] — [ArtifactFailure.diskFull] for the
/// out-of-space error codes, otherwise a generic install failure.
/// Side effects: None.
/// Notes: POSIX reports ENOSPC (28); Windows reports ERROR_HANDLE_DISK_FULL
/// (39) or ERROR_DISK_FULL (112). The pre-download space check cannot always
/// know the free space, so this is the check of last resort.
ArtifactException diskFullOr(FileSystemException error) {
  final code = error.osError?.errorCode;
  if (code == 28 || code == 39 || code == 112) {
    return ArtifactException(
      ArtifactFailure.diskFull,
      'There is not enough free space: ${error.message}',
    );
  }
  return ArtifactException(
    ArtifactFailure.unpackFailed,
    '${error.message} (${error.path})',
  );
}

/// Purpose: Build the cancellation failure.
/// Inputs: None.
/// Returns: An [ArtifactException].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArtifactException _cancelled() =>
    const ArtifactException(ArtifactFailure.cancelled, 'Cancelled.');

/// Purpose: Delete a file, ignoring failure.
/// Inputs: [file].
/// Returns: None.
/// Side effects: May delete the file.
/// Notes: Internal helper used within this file only.
Future<void> _deleteQuietly(File file) async {
  try {
    await file.delete();
  } catch (_) {}
}
