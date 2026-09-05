/// Purpose: Hand the rest of the app the right media backend for this
/// platform, already configured from the user's settings.
/// Inputs: The platform, and the tool paths in `storage_config.json`.
/// Returns: Riverpod providers for the toolkit and its status.
/// Side effects: Reads preferences and, through the toolkit, the file system.
/// Notes: This is the only place that decides which backend is used. Everything
/// above it takes a `MediaToolkit` and does not know or care whether FFmpeg is
/// a child process or a linked-in library.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/services/transcribe_storage.dart';
import '../../../shared/utils/platform_capabilities.dart';
import 'embedded_ffmpeg_media_toolkit.dart';
import 'external_ffmpeg_media_toolkit.dart';
import 'ffmpeg_locator.dart';
import 'media_toolkit.dart';

/// The directory a downloaded FFmpeg is kept in.
///
/// The application support directory, not the app data directory: these are
/// executables for *this* machine and this architecture, so they must not
/// follow a custom storage path onto a network share, and they have no business
/// in a folder the user might sync or back up.
Future<Directory> ffmpegDownloadDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'ffmpeg'));
}

/// Purpose: Build the locator with the user's paths and the app's directories.
/// Inputs: None.
/// Returns: A configured [FfmpegLocator].
/// Side effects: Reads `storage_config.json` and resolves the support
/// directory.
/// Notes: Rebuilt on each use rather than cached, so setting a path in Settings
/// or finishing a download takes effect without a restart.
Future<FfmpegLocator> buildFfmpegLocator() async {
  return FfmpegLocator(
    ffmpegOverride: await TranscribeStorage.getFfmpegPath(),
    ffprobeOverride: await TranscribeStorage.getFfprobePath(),
    downloadDirectory: await ffmpegDownloadDirectory(),
    // Homebrew's directories, for a macOS machine that has FFmpeg installed
    // and would otherwise not find it: a GUI app on macOS does not inherit the
    // shell's PATH, so /opt/homebrew/bin is invisible unless it is named.
    extraDirectories: Platform.isMacOS
        ? [Directory('/opt/homebrew/bin'), Directory('/usr/local/bin')]
        : const [],
  );
}

/// The media backend for this platform.
///
/// A future rather than a plain value because building the locator reads the
/// user's settings, and a platform without a backend gets an
/// [UnavailableMediaToolkit] rather than null — so callers have one error path
/// instead of two.
final mediaToolkitProvider = FutureProvider<MediaToolkit>((ref) async {
  switch (mediaBackend) {
    case MediaBackend.externalBinaries:
      return ExternalFfmpegMediaToolkit(locator: await buildFfmpegLocator());
    case MediaBackend.embedded:
      return const EmbeddedFfmpegMediaToolkit();
    case MediaBackend.none:
      return const UnavailableMediaToolkit('This platform has no audio tools.');
  }
});

/// Whether media work is possible right now, and with what.
///
/// Watched by the Settings row. Invalidate this provider after changing a tool
/// path or finishing a download, so the row refreshes.
final mediaToolkitStatusProvider = FutureProvider<MediaToolkitStatus>((
  ref,
) async {
  final toolkit = await ref.watch(mediaToolkitProvider.future);
  return toolkit.status();
});
