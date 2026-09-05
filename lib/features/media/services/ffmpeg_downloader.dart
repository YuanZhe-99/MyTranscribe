/// Purpose: Fetch a published FFmpeg build for this machine, so a user on
/// Windows does not have to find one themselves.
/// Inputs: The host architecture, and the app's support directory.
/// Returns: Progress while it runs, and the resolved tool paths at the end.
/// Side effects: Downloads a file, extracts two executables, writes a manifest.
/// Notes: Windows only. Every Linux distribution ships FFmpeg, so downloading a
/// foreign binary there would be worse than one install line in an error
/// message; Android, iOS and macOS have the libraries built in. See
/// `doc/en-us/features/media-tools.md`.
library;

import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'media_toolkit.dart';

/// Where the builds come from.
///
/// BtbN's builds are the ones FFmpeg's own download page points Windows users
/// at, they are published per architecture including ARM64, and the `latest`
/// tag is stable — which is what lets this URL be a constant rather than a
/// release lookup.
const _releaseBase =
    'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest';

/// The build variant to fetch.
///
/// The LGPL build rather than the GPL one. Everything this app asks FFmpeg for
/// is audio — decoding, and encoding MP3 through LAME, which is LGPL — so the
/// GPL build's extra video encoders would be weight with no purpose. The
/// executable runs as a separate process either way, so neither choice affects
/// this app's own licence; picking the smaller, more permissive build is simply
/// the tidier answer.
const _variant = 'lgpl';

/// How far a download has got.
class FfmpegDownloadProgress {
  /// What the helper is doing now.
  final FfmpegDownloadStage stage;

  /// Bytes received so far, while downloading.
  final int receivedBytes;

  /// The total to expect, when the server declared one.
  final int? totalBytes;

  /// Purpose: Create a progress report.
  /// Inputs: [stage], [receivedBytes], optional [totalBytes].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FfmpegDownloadProgress({
    required this.stage,
    this.receivedBytes = 0,
    this.totalBytes,
  });

  /// Purpose: The fraction downloaded, for a progress bar.
  /// Inputs: None.
  /// Returns: `double` from 0 to 1, or null when the size is unknown.
  /// Side effects: None.
  /// Notes: Only meaningful during [FfmpegDownloadStage.downloading]; the other
  /// stages are short and indeterminate.
  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (receivedBytes / total).clamp(0.0, 1.0);
  }
}

/// What the download helper is doing.
enum FfmpegDownloadStage { downloading, extracting, verifying, done }

/// What the helper found out about this machine before downloading.
class FfmpegDownloadPlan {
  /// The file to fetch.
  final String assetName;

  /// The full URL.
  final String url;

  /// Purpose: Create a download plan.
  /// Inputs: [assetName], [url].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FfmpegDownloadPlan({required this.assetName, required this.url});
}

/// Downloads and unpacks an FFmpeg build.
class FfmpegDownloader {
  /// Where to put the executables.
  final Directory destination;

  /// The HTTP client, injectable for tests.
  final http.Client Function() clientFactory;

  /// The architecture to fetch for, defaulting to this machine's.
  final Abi abi;

  /// Purpose: Create a downloader.
  /// Inputs: [destination], optional [clientFactory] and [abi].
  /// Returns: A new downloader.
  /// Side effects: None until [download] is called.
  /// Notes: [abi] is injectable so the asset-name rule can be tested for an
  /// architecture the test machine is not.
  FfmpegDownloader({
    required this.destination,
    http.Client Function()? clientFactory,
    Abi? abi,
  }) : clientFactory = clientFactory ?? http.Client.new,
       abi = abi ?? Abi.current();

  /// Purpose: Work out what would be downloaded, without downloading it.
  /// Inputs: None.
  /// Returns: The plan.
  /// Side effects: None.
  /// Notes: Lets the UI name the file and its source before asking the user to
  /// go ahead — downloading a binary from the internet is not something to do
  /// without saying what and from where.
  FfmpegDownloadPlan plan() {
    final asset = 'ffmpeg-master-latest-${_architectureSlug()}-$_variant.zip';
    return FfmpegDownloadPlan(assetName: asset, url: '$_releaseBase/$asset');
  }

  /// Purpose: Name the architecture as the published builds do.
  /// Inputs: None; reads [abi].
  /// Returns: `win64` or `winarm64`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. An unsupported
  /// architecture throws rather than guessing: downloading the wrong binary
  /// produces a confusing failure much later.
  String _architectureSlug() => switch (abi) {
    Abi.windowsX64 => 'win64',
    Abi.windowsArm64 => 'winarm64',
    _ => throw MediaException(
      MediaFailureKind.toolMissing,
      'There is no published FFmpeg build for this machine '
      '(${abi.toString()}). Install FFmpeg and set its location in Settings.',
    ),
  };

  /// Purpose: Download, extract and verify an FFmpeg build.
  /// Inputs: Optional [onProgress] and [cancel].
  /// Returns: The path to the extracted `ffmpeg`.
  /// Side effects: Network I/O; writes into [destination].
  /// Notes: Only `ffmpeg` and `ffprobe` are extracted — the archive also holds
  /// `ffplay`, headers and documentation, none of which this app has any use
  /// for. The archive itself is deleted afterwards.
  Future<String> download({
    void Function(FfmpegDownloadProgress)? onProgress,
    MediaCancelToken? cancel,
  }) async {
    final target = plan();
    cancel?.throwIfCancelled();

    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    final archivePath = p.join(destination.path, 'download.zip');
    final archiveFile = File(archivePath);

    final client = clientFactory();
    try {
      final request = http.Request('GET', Uri.parse(target.url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw MediaException(
          MediaFailureKind.toolFailed,
          'The download failed with status ${response.statusCode}.',
        );
      }

      final sink = archiveFile.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (cancel?.isCancelled ?? false) break;
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(
            FfmpegDownloadProgress(
              stage: FfmpegDownloadStage.downloading,
              receivedBytes: received,
              totalBytes: response.contentLength,
            ),
          );
        }
      } finally {
        await sink.close();
      }

      if (cancel?.isCancelled ?? false) {
        await _deleteQuietly(archiveFile);
        throw const MediaException(
          MediaFailureKind.cancelled,
          'The download was cancelled.',
        );
      }

      onProgress?.call(
        const FfmpegDownloadProgress(stage: FfmpegDownloadStage.extracting),
      );
      final extracted = await _extract(archiveFile);
      await _deleteQuietly(archiveFile);

      if (extracted.isEmpty) {
        throw const MediaException(
          MediaFailureKind.toolFailed,
          'The download did not contain ffmpeg.',
        );
      }

      onProgress?.call(
        const FfmpegDownloadProgress(stage: FfmpegDownloadStage.verifying),
      );
      final ffmpegPath = extracted['ffmpeg'];
      if (ffmpegPath == null) {
        throw const MediaException(
          MediaFailureKind.toolFailed,
          'The download did not contain ffmpeg.',
        );
      }
      final version = await _verify(ffmpegPath);

      await File(p.join(destination.path, 'manifest.json')).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'asset': target.assetName,
          'url': target.url,
          'downloadedAt': DateTime.now().toUtc().toIso8601String(),
          'version': version,
          'files': extracted,
        }),
      );

      onProgress?.call(
        const FfmpegDownloadProgress(stage: FfmpegDownloadStage.done),
      );
      return ffmpegPath;
    } on MediaException {
      rethrow;
    } catch (error) {
      throw MediaException(
        MediaFailureKind.toolFailed,
        'The download could not be completed.',
        toolOutput: '$error',
      );
    } finally {
      client.close();
    }
  }

  /// Purpose: Pull the two executables out of the archive.
  /// Inputs: [archiveFile].
  /// Returns: Tool name to written path, for the ones that were found.
  /// Side effects: Writes files into [destination].
  /// Notes: Internal helper used within this file only. The archive is decoded
  /// from the file rather than from memory: these builds are around a hundred
  /// megabytes, and holding one in memory on a phone-sized heap is avoidable.
  /// Entry names are matched by their base name only, so nothing in the archive
  /// can decide where a file lands.
  Future<Map<String, String>> _extract(File archiveFile) async {
    final wanted = {'ffmpeg.exe', 'ffprobe.exe'};
    final written = <String, String>{};

    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      for (final entry in archive.files) {
        if (!entry.isFile) continue;
        final base = p.basename(entry.name.replaceAll('\\', '/'));
        if (!wanted.contains(base)) continue;

        final outputPath = p.join(destination.path, base);
        final output = OutputFileStream(outputPath);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
        written[p.basenameWithoutExtension(base)] = outputPath;
      }
    } finally {
      await input.close();
    }
    return written;
  }

  /// Purpose: Check that what was extracted actually runs.
  /// Inputs: [ffmpegPath].
  /// Returns: The first line of its version banner.
  /// Side effects: Runs the executable.
  /// Notes: Internal helper used within this file only. Worth the one process:
  /// an archive for the wrong architecture extracts perfectly and then fails at
  /// the first real use, which is a much more confusing place to find out.
  Future<String> _verify(String ffmpegPath) async {
    final ProcessResult result;
    try {
      result = await Process.run(ffmpegPath, const ['-version']);
    } catch (error) {
      throw MediaException(
        MediaFailureKind.toolFailed,
        'The downloaded ffmpeg would not run on this machine.',
        toolOutput: '$error',
      );
    }
    if (result.exitCode != 0) {
      throw MediaException(
        MediaFailureKind.toolFailed,
        'The downloaded ffmpeg exited with code ${result.exitCode}.',
        toolOutput: '${result.stderr}',
      );
    }
    return const LineSplitter().convert('${result.stdout}').firstOrNull ?? '';
  }

  /// Purpose: Delete a file, ignoring failures.
  /// Inputs: [file].
  /// Returns: A future completing either way.
  /// Side effects: Deletes the file when it exists.
  /// Notes: Internal helper used within this file only.
  Future<void> _deleteQuietly(File file) async {
    try {
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }
}
