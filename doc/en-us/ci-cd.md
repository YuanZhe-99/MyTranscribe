# Building and verifying

There is **no continuous integration**. This repository has one remote — a private Gitea instance —
and no hosted runner, so `flutter analyze` and `flutter test` run locally and are the gate. If a
public mirror is ever added, this page is where the workflow would be described.

## Fresh clone

```bash
git clone <local_gitea_address>/MyTranscribe.git
cd MyTranscribe
git submodule update --init          # myapps_data is a path dependency inside a submodule
flutter pub get
flutter gen-l10n
```

Skipping the submodule step makes `flutter pub get` fail: `myapps_data` is resolved from
`packages/myapps_data`, which is empty until the submodule is checked out.

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
