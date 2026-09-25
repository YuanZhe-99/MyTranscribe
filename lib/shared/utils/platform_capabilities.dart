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
  TargetPlatform.windows ||
  TargetPlatform.linux => MediaBackend.externalBinaries,
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

/// Purpose: Name this platform the way model manifests do.
/// Inputs: None.
/// Returns: `android`, `ios`, `macos`, `windows`, `linux` or `fuchsia`.
/// Side effects: None.
/// Notes: A manifest file may say it is for some platforms only — the Core ML
/// encoder that only Apple platforms can load — and the artifact manager asks
/// here rather than branching itself.
String get platformId => switch (defaultTargetPlatform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.macOS => 'macos',
  TargetPlatform.windows => 'windows',
  TargetPlatform.linux => 'linux',
  TargetPlatform.fuchsia => 'fuchsia',
};

/// Purpose: Report whether downloaded models live in the system's caches
/// directory rather than beside the app's data.
/// Inputs: None.
/// Returns: `bool` — true on iOS and macOS.
/// Side effects: None.
/// Notes: A model is a re-downloadable cache, and on Apple platforms the
/// caches directory is what iCloud backup and Time Machine leave out — a 3 GB
/// model in a phone backup is a support ticket. The cost is that the system may
/// purge it when space runs short, which the library shows as "not downloaded".
/// Elsewhere models sit under the app directory, so a custom storage path
/// carries them along.
bool get modelsLiveInCachesDirectory =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Which local engine adapters this platform can have at all.
///
/// Whether the build actually contains one is the engine registry's question;
/// this only says which would be looked for.
enum LocalEngineBackend {
  /// whisper.cpp through FFI.
  whisperCpp,

  /// sherpa-onnx through its Dart API.
  sherpaOnnx,

  /// The Swift plugin: FluidAudio on the Neural Engine, and the system
  /// recogniser.
  apple,

  /// Android's own speech recogniser.
  androidSpeech,

  /// ONNX Runtime with Qualcomm's QNN execution provider.
  qnn,
}

/// Purpose: List the local engine adapters this platform may have.
/// Inputs: None.
/// Returns: A set of [LocalEngineBackend].
/// Side effects: None.
/// Notes: The QNN adapter is Windows and Android only because it is Snapdragon
/// only; which Windows builds carry it is decided at build time, not here.
Set<LocalEngineBackend> get localEngineBackends =>
    switch (defaultTargetPlatform) {
      TargetPlatform.android => const {
        LocalEngineBackend.whisperCpp,
        LocalEngineBackend.sherpaOnnx,
        LocalEngineBackend.androidSpeech,
        LocalEngineBackend.qnn,
      },
      TargetPlatform.iOS || TargetPlatform.macOS => const {
        LocalEngineBackend.whisperCpp,
        LocalEngineBackend.sherpaOnnx,
        LocalEngineBackend.apple,
      },
      TargetPlatform.windows => const {
        LocalEngineBackend.whisperCpp,
        LocalEngineBackend.sherpaOnnx,
        LocalEngineBackend.qnn,
      },
      TargetPlatform.linux => const {
        LocalEngineBackend.whisperCpp,
        LocalEngineBackend.sherpaOnnx,
      },
      TargetPlatform.fuchsia => const {},
    };

/// Purpose: Report whether the operating system has a speech recogniser the
/// app could offer as a fallback.
/// Inputs: None.
/// Returns: `bool` — true on Android, iOS and macOS.
/// Side effects: None.
/// Notes: Windows has no file-transcription API, so the setting is absent
/// there rather than disabled.
bool get hasSystemSpeechRecognizer =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// Purpose: Name this device's class the way the local-model support matrix
/// does.
/// Inputs: The CPU's [architecture] (`arm64`, `x64`, …) and, on Windows, the
/// [processor] identifier the OS reports.
/// Returns: A class such as `windows-arm64-qualcomm`, `windows-x64`,
/// `macos-arm64`, `ios`, `android` or `linux-x64`.
/// Side effects: None.
/// Notes: "Tested here" is recorded per class, never per device. Only what the
/// OS says for certain goes into it: a Qualcomm Windows ARM64 machine is the
/// class this project's own machine belongs to; an Android phone's SoC needs a
/// platform channel to read, so every Android device is one class for now.
String localDeviceClass({
  required String architecture,
  String processor = '',
}) => switch (defaultTargetPlatform) {
  TargetPlatform.windows =>
    architecture == 'arm64' && processor.contains('Qualcomm')
        ? 'windows-arm64-qualcomm'
        : 'windows-$architecture',
  TargetPlatform.macOS => 'macos-$architecture',
  TargetPlatform.iOS => 'ios',
  TargetPlatform.android => 'android',
  TargetPlatform.linux => 'linux-$architecture',
  TargetPlatform.fuchsia => 'fuchsia',
};

/// Purpose: Choose how many CPU threads a local model uses.
/// Inputs: The number of [processors] the OS reports.
/// Returns: A thread count of at least one.
/// Side effects: None.
/// Notes: Phones get at most four: their big cores are few, and a thread on
/// an efficiency core holds the others back at every synchronisation. A
/// desktop leaves two cores free (one when it has four or fewer) and uses at
/// most eight: ggml's own thread pool waits by spinning, so a thread that
/// shares a core with the OS or the Dart VM stalls all the others. Measured on
/// the 8-core Snapdragon 8cx Gen 3 development machine, large-v3-turbo on the
/// check clip: 6 threads RTF 1.89, 7 threads 1.91, 8 threads 3.04, 4 threads 2.43.
int localEngineThreads(int processors) => isMobilePlatform
    ? processors.clamp(1, 4)
    : (processors - (processors > 4 ? 2 : 1)).clamp(1, 8);

/// Purpose: Report whether this platform's whisper.cpp build has Metal.
/// Inputs: None.
/// Returns: `bool` — true on iOS and macOS.
/// Side effects: None.
/// Notes: Metal is part of the OS there, so the GPU route cannot be missing a
/// driver; elsewhere GPU backends arrive with L3.
bool get hasMetalBackend =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
