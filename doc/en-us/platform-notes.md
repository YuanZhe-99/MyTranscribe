# Platform notes

Four platforms are generated and configured: Android, Windows, iOS and macOS. Linux and Web are not
targeted.

| Surface | Value |
|---|---|
| Android namespace and application id | `com.yuanzhe.my_transcribe` |
| iOS and macOS bundle id | `com.yuanzhe.myTranscribe` |
| MSIX identity | `com.yuanzhe.mytranscribe` |
| Display name everywhere | `MyTranscribe!!!!!` |
| Publisher | `yuanzhe` |

## FFmpeg: two backends, one interface

Splitting a recording needs FFmpeg, and how the app gets it differs by platform. Both backends
implement the same `MediaToolkit` interface, and
`lib/shared/utils/platform_capabilities.dart` decides which one is asked.

| Platform | Backend | How |
|---|---|---|
| Android, iOS, macOS | `embedded` | The FFmpeg libraries are linked into the app and run in-process. The only workable route on a sandboxed platform, where spawning a child process is not an option. |
| Windows | `externalBinaries` | `ffmpeg.exe` and `ffprobe.exe` are separate executables the app finds, or offers to download. |

**Why Windows is different.** The maintained FFmpeg plugin publishes prebuilt Windows libraries for
x86_64 only, and this project's development machine is Windows on **ARM64**. A plugin that declares
Windows support would be pulled into the Windows build and fail at configure time looking for an
ARM64 archive that does not exist. Flutter has no app-level "exclude this plugin on that platform",
and `generated_plugins.cmake` is regenerated on every build, so editing it does not stick. The
plugin is therefore **vendored** into `packages/ffmpeg_kit_flutter_new_audio/` as a trimmed copy
with its Windows and Linux platform entries removed, and consumed as a path dependency.
`VENDORED.md` beside it records the upstream version and exactly what was removed; bumping it means
re-vendoring, not editing a version number. The app's `analysis_options.yaml` excludes the copy,
because its style is upstream's and not ours to correct.

Two consequences worth knowing before adding any plugin with native code. First, every plugin must
apply the Kotlin Gradle Plugin itself while `android.builtInKotlin=false`; the build prints a
warning naming the ones that do, and today those are the vendored FFmpeg copy, `file_picker`,
`package_info_plus` and `wakelock_plus`. Second, the Android and Apple builds **download their
native archives at build time**, so an offline machine cannot build those targets from clean.

Binary discovery order on Windows, in full: a path the user set in Settings, then the app's own
support directory (where the download helper puts them), then the directory the executable is in and
its `bin/` subdirectory, then the working directory, then every entry of `PATH`. On Windows a
candidate is probed by checking that the file exists rather than by running it, because running an
executable to test it flashes a console window.

The download helper fetches a published build for the host architecture into the app support
directory, extracts only the two executables, and records what it downloaded. It exists because
Windows has no package manager every machine already has. Linux is deliberately excluded from the
helper: every distribution ships FFmpeg, and downloading a foreign binary there is worse than one
install line in the error message.

Child processes are started attached with pipes, which Dart creates without a console window on
Windows. Progress is read from FFmpeg's own machine-readable progress stream on stdout; the last
lines of stderr are kept so a failure can say what went wrong.

## Android

Gradle state, inherited from the sibling apps and load-bearing:

- AGP 9.1.1, Kotlin Gradle Plugin 2.2.20 declared in `settings.gradle.kts`
- `android.builtInKotlin=false` — the app does not apply KGP itself, but several plugins still do
  and resolve the version from there. **Any plugin added to this app must apply KGP itself**;
  `file_picker` is pinned to an exact version for precisely this reason, and the pin carries the
  explanation in `pubspec.yaml`.
- `android.newDsl=false`
- Java 17 with core library desugaring; the Kotlin `jvmTarget` is set to 17 explicitly, because
  without it Kotlin defaults to the running JDK's target and the build fails with an inconsistent
  JVM target error.
- `minSdk = flutter.minSdkVersion` (24), which is also what the bundled FFmpeg libraries require.

Release signing reads `android/key.properties` when it exists and falls back to the debug config
when it does not, so a fresh clone builds without any secret. `key.properties` and `*.jks` are
gitignored and never committed.

**Permissions: `INTERNET`, and nothing else.** Recordings arrive through the system file picker,
which grants access to the one file the user chose, so no storage permission is needed. The app does
not record audio and asks for no microphone permission.

`android:usesCleartextTraffic="true"` — a WebDAV server on a home network, and a transcription
server the user runs themselves, are commonly plain HTTP. API keys are still withheld from a
plain-HTTP endpoint unless it is a private address; see
[`features/secure-secrets-sync.md`](features/secure-secrets-sync.md).

`android:configChanges` carries `screenLayout|screenSize|smallestScreenSize|density`, so folding or
unfolding resizes the window without recreating the activity. See
[`adaptive-layout.md`](adaptive-layout.md).

## iOS

- Deployment target **14.0**, raised from Flutter's default because the FFmpeg libraries require it.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are both true, which makes the
  app's folder visible in Files. Without them a finished transcript would be reachable only through
  a share sheet.
- App Transport Security allows local networking and arbitrary loads, mirroring Android's cleartext
  flag and for the same reason. This is a decision to revisit before any App Store submission:
  local networking alone would be easier to justify, but it would break a WebDAV server reached over
  a Tailscale address.
- No microphone or speech-recognition usage strings, because the app does neither.

## macOS

Sandboxed, with three entitlements in both the debug and the release profile:

- `app-sandbox`
- `network.client` — reaching the transcription service and the user's WebDAV server
- `files.user-selected.read-write` — the user picks a recording and chooses where a transcript is
  saved; the sandbox grants access to exactly those files

Running FFmpeg in-process rather than as a child process avoids the sandbox questions a spawned
executable would raise.

## Windows

The runner is renamed to `MyTranscribe!!!!!` in its resources and window title. Packaging metadata
for MSIX lives in `pubspec.yaml` and for the installer in `installer.iss`; both carry a copy of the
version, and `AGENTS.md` lists every place a version number appears.

Building on ARM64 works today with no extra tools. A plugin that ships prebuilt x86_64 Windows
binaries will not, which is the constraint the FFmpeg arrangement above exists to satisfy — check it
before adding any plugin with native Windows code.

The audio player is the second place that constraint decided a dependency. `audioplayers` was chosen
over `just_audio` and `media_kit` because its Windows backend is Media Foundation compiled from
source, so it builds on ARM64; the other two ship an x86_64-only libmpv and would fail the same way
the FFmpeg plugin does. This was verified with a real `flutter build windows` on the ARM64 machine
rather than taken from documentation.

## Local models

Where downloaded models live differs by platform, and `platform_capabilities.dart` decides it
(`modelsLiveInCachesDirectory`):

| Platform | Where `models/` is | Why |
|---|---|---|
| iOS, macOS | the app's caches directory | iCloud backup and Time Machine leave it out; a model is a re-downloadable cache, and gigabytes of it in a phone backup is a support ticket. The system may purge it when space runs short, and the library then shows the model as not downloaded. No native code is needed to mark a folder as excluded. |
| Android, Windows | `models/` under the app directory | A custom storage path carries the models along. On Android the backup rules below exclude `models/` from Auto Backup and from device transfer. |

A desktop user may move models anywhere with `modelsPath`; nothing is copied when it changes.

Which engine adapters a platform may have at all is also decided there (`localEngineBackends`):
whisper.cpp and sherpa-onnx everywhere; the Swift plugin on iOS and macOS; Android's recogniser on
Android; ONNX Runtime with Qualcomm's QNN provider on Windows and Android. Whether a build actually
contains one is the engine registry's answer. `hasSystemSpeechRecognizer` is false on Windows,
which has no file-transcription API, so the fallback setting is absent there rather than disabled.

### whisper.cpp

whisper.cpp is a git submodule at `packages/whisper.cpp`, pinned to a release tag (v1.9.4), with the
public upstream URL — an absolute URL is right here, unlike `myapps_data`, because upstream lives
in neither of this project's remotes. `packages/local_asr_whisper` wraps it: a build hook
(`hook/build.dart`) runs CMake on the submodule for whatever target the Flutter tool is building,
and a small C shim (`src/lasr_whisper.c`) gives the Dart side a stable ABI of plain types, so no
Dart code mirrors a whisper.cpp struct. No pub package was usable: the two that exist ship
x86_64-only Windows binaries or no desktop at all.

| Target | Compiler | CPU code | Other backends |
|---|---|---|---|
| Windows ARM64 | clang from Visual Studio's LLVM component (or a standalone LLVM), in Visual Studio's developer environment | one library at ARMv8.2 with dot-product and FP16, which every Windows 11 ARM processor has — the pinned ggml has no Windows ARM64 variant list to choose from at run time | — (OpenCL in L3) |
| Windows x64 | the same clang | every x86 variant built, the best loaded at run time | — (Vulkan in L3) |
| Android arm64, x86_64 | the NDK's clang and CMake toolchain file | every Android variant built, the best loaded at run time | — (OpenCL in L3) |
| macOS, iOS | Xcode's clang | the default for the architecture | Metal, with the Core ML encoder used when it is beside the model |
| Linux x64 | the host compiler | the default | — (the host `flutter test` runs on in CI) |

`cl.exe` is not used on Windows: it lacks the FP16 intrinsics ggml's ARM code needs, and the OpenCL
backend of L3 does not support it at all. On x64 the incompatible-pointer-types diagnostic stays a
warning: ggml's SSE4.2 variant passes block pointers to `_mm_prefetch`, which a recent clang
otherwise stops on. 32-bit Android is not built — a large Whisper model does
not fit a 32-bit address space — and the engine reports itself as not built there.

Where the CPU code is chosen at run time, ggml loads its backends as separate libraries, and the
shim loads them from the folder it was itself loaded from: on Android that folder is not the
executable's, and in a `flutter test` run neither is anything else. That is why the Android app is
built with **legacy packaging** (`useLegacyPackaging` in `android/app/build.gradle.kts`): the
native libraries are extracted to the app's library folder instead of being read from inside the
APK, where a folder cannot be listed. Android's backup rules (`res/xml/backup_rules.xml` and
`res/xml/data_extraction_rules.xml`) keep `models/` out of Auto Backup and device transfer.

Tools: CMake and Ninja from PATH, then Visual Studio's own copies on Windows, then the Android SDK's
for Android; without Ninja on macOS or Linux the hook falls back to Makefiles. The CMake build
directory lives in the hook's shared output under `.dart_tool/`, so a second build is incremental.
