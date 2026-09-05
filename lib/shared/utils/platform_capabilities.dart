import 'package:flutter/foundation.dart';

/// What the current platform can do, in one place.
///
/// This is the only file in `lib/` that branches on the platform. Everything
/// here reads [defaultTargetPlatform] rather than `dart:io`'s `Platform`, so a
/// widget test can drive any branch through
/// `debugDefaultTargetPlatformOverride`, and so the rules stay testable on the
/// one host the project actually has. See `doc/en-us/platform-notes.md`.

/// How this platform reaches FFmpeg.
enum MediaBackend {
  /// The FFmpeg libraries are linked into the app and run in-process.
  embedded,

  /// `ffmpeg` and `ffprobe` are separate executables the app finds or
  /// downloads, and drives as child processes.
  externalBinaries,

  /// Neither is available; the app can still upload a small file unchanged,
  /// but cannot probe, transcode or split one.
  none,
}

/// Purpose: Report whether the app is running on a phone or tablet.
/// Inputs: None.
/// Returns: `bool` — true on Android and iOS.
/// Side effects: None.
/// Notes: Reads [defaultTargetPlatform], so a test override changes it.
bool get isMobilePlatform =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Purpose: Report whether the app is running on a desktop.
/// Inputs: None.
/// Returns: `bool` — true on Windows, macOS and Linux.
/// Side effects: None.
/// Notes: The complement of [isMobilePlatform]; both are spelled out because
/// call sites read better naming the platform family they care about.
bool get isDesktopPlatform => !isMobilePlatform;

/// Purpose: Say how this platform reaches FFmpeg.
/// Inputs: None.
/// Returns: A [MediaBackend].
/// Side effects: None.
/// Notes: Android, iOS and macOS link the FFmpeg libraries into the app, which
/// is the only workable route on a sandboxed platform where spawning a child
/// process is not an option. Windows and Linux drive external executables
/// instead, because the plugin publishes x86_64 binaries only and this
/// project's own development machine is Windows on ARM64 — see
/// `doc/en-us/platform-notes.md`. Whether the executables are actually present
/// is a runtime question `MediaToolkit.status()` answers; this only says which
/// backend would be asked.
MediaBackend get mediaBackend => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.macOS => MediaBackend.embedded,
  TargetPlatform.windows || TargetPlatform.linux =>
    MediaBackend.externalBinaries,
  TargetPlatform.fuchsia => MediaBackend.none,
};

/// Purpose: Report whether the app looks for FFmpeg executables on this
/// platform.
/// Inputs: None.
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Gates the Settings rows that show a tool path and let the user point
/// at their own build. On an embedded-backend platform there is no path to
/// show, so those rows would be noise.
bool get usesExternalFfmpeg => mediaBackend == MediaBackend.externalBinaries;

/// Purpose: Report whether the app offers to download FFmpeg for the user.
/// Inputs: None.
/// Returns: `bool` — true on Windows only.
/// Side effects: None.
/// Notes: Windows has no package manager every machine already has, so the app
/// fetches a published build itself. Linux is deliberately excluded: every
/// distribution ships FFmpeg, and downloading a foreign binary there is worse
/// than one `apt install` line in the error message.
bool get canDownloadFfmpeg => defaultTargetPlatform == TargetPlatform.windows;

/// Purpose: Decide whether Settings shows the storage location row.
/// Inputs: None.
/// Returns: `bool` — false on mobile.
/// Side effects: None.
/// Notes: On a phone the path is a sandbox location the user can neither read
/// nor act on, so the row is noise; on a desktop it is a real folder they may
/// want to find. The custom storage path itself keeps working on every
/// platform — only the display is hidden.
bool get showsStorageLocation => !isMobilePlatform;

/// Purpose: Report whether a finished transcript is handed to the system share
/// sheet rather than written with a save dialog.
/// Inputs: None.
/// Returns: `bool` — true on Android and iOS.
/// Side effects: None.
/// Notes: A phone has no folder the user browses, so "save as" means nothing
/// there; a desktop has one and a share sheet is the unusual path. The exporter
/// offers the other route as a secondary action on both, so neither platform
/// loses a capability — this only decides which one is the button.
bool get sharesFilesBySheet => isMobilePlatform;

/// Purpose: Report whether the app must copy a picked file into its own
/// storage before working on it.
/// Inputs: None.
/// Returns: `bool` — true on Android and iOS.
/// Side effects: None.
/// Notes: A picked file arrives as a cache copy of a content URI, and the
/// system may purge it between launches — which would break resuming a job
/// days later. On desktop the picked path is a real file that stays where it
/// is, so copying a multi-gigabyte recording would waste the space for nothing.
bool get copiesPickedFilesIntoStorage => isMobilePlatform;
