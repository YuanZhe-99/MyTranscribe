# This is a vendored copy

**Upstream:** [`ffmpeg_kit_flutter_new_audio`](https://pub.dev/packages/ffmpeg_kit_flutter_new_audio)
**Version:** 2.5.2
**Licence:** LGPL-3.0, unchanged — see [`LICENSE`](LICENSE)
**Vendored:** 2026-09-05

## Why

The published package declares Windows and Linux support, and its prebuilt
native libraries for those platforms are **x86_64 only**. MyTranscribe is
developed on Windows on **ARM64**, where the Windows half of this plugin cannot
build: the CMake step composes a download URL for an architecture that has no
published archive, and fails at configure time.

Flutter has no app-level way to say "use this plugin, but not on that platform".
The tool includes every transitive plugin that declares a platform, and
`windows/flutter/generated_plugins.cmake` is regenerated on every build, so
editing it does not stick. A `path:` dependency on a copy whose pubspec declares
only the platforms we want is the one mechanism that is deterministic on both an
x64 and an ARM64 host, and it needs no `dependency_overrides`.

Windows and Linux do not lose the feature: they drive external `ffmpeg` and
`ffprobe` executables instead. See `doc/en-us/platform-notes.md`.

Verified: with this copy in the tree, `flutter build windows --debug` succeeds on
an ARM64 host and `windows/flutter/generated_plugins.cmake` lists no plugins,
while `flutter build apk --debug` succeeds and the libraries load on a real
device (`integration_test/media_toolkit_test.dart`).

## What was changed

Exactly three things, all removals:

1. `pubspec.yaml` — the `windows:` and `linux:` entries removed from
   `flutter.plugin.platforms`, and the description amended to point here.
2. `windows/` — deleted.
3. `linux/` — deleted.

`example/` was also deleted, because it is 2.2 MB of a demo application that no
build here compiles.

Nothing in `lib/`, `android/`, `ios/`, `macos/` or `scripts/` was touched. The
Dart API, the Kotlin and Java sources, the podspecs and the licence are byte
identical to the published package.

## Updating it

**Re-vendor; do not edit the version number here.** The whole value of this copy
is that its difference from upstream is three removals anybody can verify.

```bash
dart pub cache add ffmpeg_kit_flutter_new_audio --version <new>
# then, from the repository root, with <cache> the pub cache directory:
rm -rf packages/ffmpeg_kit_flutter_new_audio
mkdir -p packages/ffmpeg_kit_flutter_new_audio
cp -r <cache>/ffmpeg_kit_flutter_new_audio-<new>/{lib,android,ios,macos,scripts} \
      packages/ffmpeg_kit_flutter_new_audio/
cp <cache>/ffmpeg_kit_flutter_new_audio-<new>/{LICENSE,README.md,CHANGELOG.md,pubspec.yaml,analysis_options.yaml} \
   packages/ffmpeg_kit_flutter_new_audio/
```

Then re-apply the pubspec removal, restore this file, and check three things:

- `flutter build windows --debug` still succeeds on an ARM64 host,
- `flutter build apk --debug` still succeeds,
- the upstream changelog does not add a platform we now need.

## The other constraint to remember

The Android and Apple builds **download their native archives at build time**
from the upstream project's releases. An offline machine cannot build those
targets from a clean state. That is a property of the package, not of this copy.
