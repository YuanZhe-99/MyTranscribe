# Building and verifying

There is **no continuous integration**. The repository has two remotes and neither runs a hosted
job, so `flutter analyze` and `flutter test` run locally and are the gate.

| Remote | Where | For |
|---|---|---|
| `origin` | a private Gitea instance | development; every push goes here first |
| `github` | `github.com/YuanZhe-99/MyTranscribe` | the public mirror |

Both carry the same `main` and the same tags. Push `origin` first: a commit that has not been through
the local gate has no business being public.

## Fresh clone

```bash
git clone git@github.com:YuanZhe-99/MyTranscribe.git     # or the Gitea remote
cd MyTranscribe
git submodule update --init          # myapps_data is a path dependency inside a submodule
flutter pub get
flutter gen-l10n
```

Skipping the submodule step makes `flutter pub get` fail: `myapps_data` is resolved from
`packages/myapps_data`, which is empty until the submodule is checked out.

The submodule URL is **relative** — `../MyApps-DATA.git` — so it resolves against whichever remote
you cloned from. A GitHub clone reaches `github.com/YuanZhe-99/MyApps-DATA`, a Gitea clone reaches
the Gitea copy, and neither has to know the other exists. Both must carry the tag this repository
pins; today that is `v1.0.2` at the same commit on both.

## Verify

```bash
flutter analyze                      # must report zero issues
flutter test
```

Both must pass before any commit. When a change is narrow, run the narrowest meaningful subset:

```bash
flutter test test/adaptive_layout_test.dart test/shell_nav_ui_test.dart   # layout work
flutter test test/settings_merge_test.dart test/data_modules_test.dart    # sync or data work
flutter test test/l10n_arb_test.dart                                      # after touching an ARB
```

`flutter gen-l10n` must be re-run and its output committed whenever an ARB file changes; the
generated files are tracked.

## On-device tests

`test/` runs on the host and covers almost everything. One question it cannot answer is whether the
FFmpeg libraries linked into the Android, iOS and macOS builds actually load and run — the native
archives are fetched at build time, and a wrong architecture fails at the first real call rather
than at build. That is what `integration_test/` is for:

```bash
flutter devices
flutter test integration_test/media_toolkit_test.dart -d <device id>
```

Run it after touching anything in `lib/features/media/` or after re-vendoring the FFmpeg package.
See `integration_test/README.md`.

The desktop equivalent lives in `test/media_toolkit_live_test.dart`, which skips itself when no
FFmpeg is installed and keeps its large download behind a flag:

```bash
flutter test test/media_toolkit_live_test.dart
flutter test test/media_toolkit_live_test.dart --dart-define=live_download=true
```

## Run

```bash
flutter run -d windows
flutter run -d macos
flutter run -d <android device id>
```

`flutter devices` lists what is attached. In a debug build, `DevicePreview` is enabled, which is the
quickest way to see a page at the foldable geometries in [`adaptive-layout.md`](adaptive-layout.md)
without a foldable.

On Windows and Linux the app needs `ffmpeg` and `ffprobe` for anything beyond uploading a small file
unchanged; Settings offers to download them on Windows, or accepts a path to a build you already
have. Android, iOS and macOS have the libraries built in.

## Build

```bash
flutter build apk --release          # Android, sideload
flutter build appbundle --release    # Android, store
flutter build windows --release
flutter build macos --release
flutter build ipa                    # iOS, needs a Mac and a signing identity
```

Release signing on Android reads `android/key.properties`, which is not committed. Without it a
release build is signed with the debug key, which is fine for a local build and not for
distribution.

Packaging, when a release calls for it:

```bash
dart run msix:create                 # Windows, MSIX
iscc installer.iss                   # Windows, Inno Setup installer
```

## Icons

```bash
dart run tool/generate_ios_icons.dart   # writes the iOS default, dark and tinted sources
dart run flutter_launcher_icons          # Android mipmaps, iOS appiconset, Windows and macOS icons
```

The source is `assets/icon/app_icon.png`. Generated icon files are never hand-edited; change the
source and rerun both commands.

## Before a release

`AGENTS.md` holds the full checklist. In short: the version appears in `pubspec.yaml` twice (the
version itself and the MSIX version) and in `installer.iss` three times, and all of them move
together. The settings page's version display is not one of them — it reads the package info at
runtime and must never be hand-edited.
