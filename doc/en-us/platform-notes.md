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

- Deployment target **17.0** since 0.3.3 (14.0 before, for the FFmpeg libraries): FluidAudio, the
  Neural Engine route of L4, declares iOS 17, and a Swift package cannot be linked below its floor
  (decision D12, approved by the user on 2026-09-24). It drops the iPhone 8, 8 Plus and X, which
  stop at iOS 16.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are both true, which makes the
  app's folder visible in Files. Without them a finished transcript would be reachable only through
  a share sheet.
- App Transport Security allows local networking and arbitrary loads, mirroring Android's cleartext
  flag and for the same reason. This is a decision to revisit before any App Store submission:
  local networking alone would be easier to justify, but it would break a WebDAV server reached over
  a Tailscale address.
- No microphone or speech-recognition usage strings, because the app does neither.

## macOS

Deployment target **14.0** (Sonoma) since 0.3.3, for the same reason as iOS; 10.15 before. Sonoma
runs on Macs from 2018 on (the iMac from 2019, and the 2017 iMac Pro), so earlier Macs stop at
0.3.2.

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

The app build compiles nothing native (decision D21 of `PLAN.md`). `packages/local_asr_whisper`
keeps a manifest, `native/binaries.json`, that pins one archive per target by URL and SHA-256. Its
build hook downloads the archive for the target being built, checks the hash, unpacks the listed
libraries into its shared cache under `.dart_tool/`, and hands them to the Flutter tool as code
assets. A hash that does not match fails the build rather than bundle a different binary. Every
archive is built from whisper.cpp v1.9.4 (commit `927cfce3`), and each carries whisper.cpp's own
Parakeet runtime beside Whisper's (`parakeet`; inside the framework binary on Apple), which the
Parakeet engine binds with its own generated bindings (`parakeet_bindings.g.dart`, decision D22).
Our own archives are the `whisper-bin-v1.9.4-3` release, the first with the GPU backends.

| Target | Archive | CPU code | Other backends |
|---|---|---|---|
| Windows x64 | ours: `whisper-win-x64.zip` in the `whisper-bin-v1.9.4-3` release (MSVC) | every x86 variant, the best loaded at run time | Vulkan |
| Windows ARM64 | ours: `whisper-win-arm64.zip` in the same release | one library at ARMv8.2 with dot-product and FP16, no OpenMP | OpenCL (Adreno) |
| Android arm64-v8a, x86_64 | ours: `whisper-android-<abi>.zip` in the same release | every Android variant, the best loaded at run time | arm64: OpenCL (Adreno) and Vulkan; x86_64: none |
| macOS, iOS and its simulator | upstream's `whisper-b5130-xcframework.zip`: the framework binary of the matching slice, and of a universal binary the one architecture being built | linked in | Metal, and the Core ML encoder when it is beside the model |
| Linux x64 | upstream's `whisper-bin-ubuntu-x64.tar.gz`, the libraries under their sonames | every x86 variant | — (only the host `flutter test` runs on in CI) |

Three of them are ours because upstream's do not qualify: its Windows ARM64 zips need
`libomp140.aarch64.dll` from Visual Studio's `debug_nonredist` folder, which may not be shipped, and
target ARMv8.7, which older Snapdragon laptops cannot run; it publishes nothing for Android; and its
Windows x64 zip has no GPU backend, while one built here would not be ABI-matched to its other
libraries. `.github/workflows/native-prebuild.yml` builds all three from the same upstream commit,
once per version (`ci-cd.md`). 32-bit Android has no entry — a large Whisper model does not fit a
32-bit address space — and the engine reports itself as not built there.

The GPU backends (L3) are libraries of their own that ggml loads beside the CPU one, and each loads
only where the device's own runtime is there: `ggml-vulkan` needs the driver's `vulkan-1.dll` or
`libvulkan.so`, `ggml-opencl` the driver's `OpenCL.dll` or the phone's `libOpenCL.so`. Neither
runtime is bundled. A backend that does not load leaves no route, and the app runs on the CPU. On
Android 12 and later an app may open a vendor library only when it declares it, so the manifest
declares `libOpenCL.so` with `uses-native-library`, not required. The engine offers one route per
GPU device ggml reports and passes its position to `gpu_device`; the grades are in
`local-asr-support-matrix.md`. Nothing on the development machine can run them: its 8cx Gen 3 has
no native OpenCL or Vulkan driver, and Microsoft's OpenCLOn12 layer lacks the FP16 support ggml
requires, so the device is dropped.

The Dart side binds the libraries directly; there is no C shim. `third_party/whisper.cpp/include/`
holds the pinned version's headers and licence, and `dart run tool/ffigen.dart` generates
`lib/src/whisper_bindings.g.dart`, bound to the `whisper` code asset, and
`lib/src/ggml_bindings.g.dart`, looked up in the ggml libraries beside it — or inside whisper's own
binary on Apple, where ggml is linked in. The parameter structs travel by value, so at load the
engine reads whisper.cpp's default parameters back through the generated structs and compares them
with the values its source documents; a mismatch means the library and the bindings disagree, and
the engine refuses the library rather than call into it. Cancel and progress are callbacks created
in the engine isolate, which is allowed because whisper.cpp calls both on the thread that called
`whisper_full`. ggml's two enums are bound as 32-bit integers, the size every compiler these targets
use gives them. The memory guard's figure for available memory comes from the OS through FFI. The engine
uses at most four threads on a phone; on a desktop it leaves two cores free (one on a machine with
four or fewer), at most eight, because ggml's thread pool spins while it waits — on the 8-core
development machine eight threads ran 60 % slower than six (`localEngineThreads`).

Where the CPU code is chosen at run time, ggml loads its variants as separate libraries from the
folder the whisper library was loaded from, which the Dart side asks the OS for: on Android that
folder is not the executable's, and in a `flutter test` run neither is anything else. That is why
the Android app is built with **legacy packaging** (`useLegacyPackaging` in
`android/app/build.gradle.kts`): the native libraries are extracted to the app's library folder
instead of being read from inside the APK, where a folder cannot be listed. Android's backup rules
(`res/xml/backup_rules.xml` and `res/xml/data_extraction_rules.xml`) keep `models/` out of Auto
Backup and device transfer.

The Windows libraries link the Visual C++ runtime (`MSVCP140.dll`, `VCRUNTIME140.dll`, and on x64
also `VCRUNTIME140_1.dll` and the OpenMP runtime `VCOMP140.DLL`). The app already depends on that
runtime — its own executable and its plugins link `MSVCP140.dll` and `VCRUNTIME140.dll`, and the
installer copies none of it — so whisper.cpp adds only `VCOMP140.DLL` on x64, which the same Visual
C++ Redistributable installs.

Moving to a newer upstream version touches all of it at once: run `native-prebuild.yml` for the new
tag, point `native/binaries.json` at the new archives with their hashes, copy the new headers into
`third_party/`, regenerate the bindings, update the layout check if the defaults moved, and bump
`_bindingsVersion` in `whisper_cpp_engine.dart` so every device checks its routes again.

### sherpa-onnx

Qwen3-ASR runs on sherpa-onnx (decision D22), through `packages/local_asr_sherpa`, built exactly
like `local_asr_whisper`: `native/binaries.json` pins sherpa-onnx v1.13.8's own release assets by URL
and SHA-256, the hook downloads and bundles them, `third_party/sherpa-onnx/c-api.h` is vendored with
the licence (Apache-2.0), and `dart run tool/ffigen.dart` generates `lib/src/sherpa_bindings.g.dart`.
The pub package `sherpa_onnx` is not used: 1.13.8 ships no Windows ARM64 DLLs, so this machine could
not have run it.

| Target | Archive | Libraries |
|---|---|---|
| Windows x64, ARM64 | `sherpa-onnx-v1.13.8-win-{x64,arm64}-shared-MD-Release-no-tts-lib.tar.bz2` | `sherpa-onnx-c-api.dll`, `onnxruntime.dll`, `onnxruntime_providers_shared.dll` |
| Android arm64-v8a, x86_64 | `sherpa-onnx-1.13.8.aar`, its `jni/<abi>/` folder | `libsherpa-onnx-c-api.so`, `libonnxruntime.so` |
| macOS | `sherpa-onnx-v1.13.8-osx-universal2-shared-no-tts-lib.tar.bz2`, one slice per architecture | `libsherpa-onnx-c-api.dylib`, `libonnxruntime.dylib` |
| Linux x64 | `sherpa-onnx-v1.13.8-linux-x64-shared-no-tts-lib.tar.bz2` | `libsherpa-onnx-c-api.so`, `libonnxruntime.so` |
| iOS | none yet — sherpa-onnx publishes no dynamic library for it; the engine reports itself as not built | |

The C API takes its config by pointer, with no function that reads defaults back, so the guard
against a layout mismatch is the version: the library must report exactly `1.13.8`, or it is not
used. `onnxruntime.dll` also links `MSVCP140_1.dll`, part of the same Visual C++ Redistributable.
The Android archive is the largest download of any target (48 MiB), fetched once by the hook.

### The Neural Engine bridge

On iOS and macOS, Parakeet also runs on the Neural Engine through FluidAudio 0.17.4 (L4).
FluidAudio compiles C, C++ and Swift, so under decision D21 it is wrapped once, not in the app
build: `packages/local_asr_apple/bridge` is a small Swift package whose five `@_cdecl` functions
(`lasr_apple.h`) load a staged Core ML folder with FluidAudio's own downloader switched off
(`ModelHub.offlineMode`), transcribe samples to JSON with token times, free and release.
`.github/workflows/apple-prebuild.yml` builds it with `xcodebuild` on a macOS runner for macOS,
iOS and the iOS Simulator and publishes the three binaries as a release; the package's hook
downloads that archive by hash and hands over the slice being built, and `tool/ffigen.dart`
generates the bindings from the header. Every function blocks its caller — the engine's worker
isolate — on a detached task.

The model is FluidInference's Core ML conversion of Parakeet v3, pinned by Hugging Face revision
and hashed file by file: four compiled models (`Preprocessor`, `Encoder` at int8, `Decoder`,
`JointDecisionv3`) and `parakeet_vocab.json`, 483 MB. Its files are marked for iOS and macOS only,
and the engine is registered only there, so no other platform offers the package. Core ML reports
no per-operation placement, so the route records `mixed` (configured for the CPU and the Neural
Engine).
