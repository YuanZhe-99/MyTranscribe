# Building and verifying

## Remotes

| Remote | Where | For |
|---|---|---|
| `origin` | a private Gitea instance | development; every push goes here first |
| `github` | `github.com/YuanZhe-99/MyTranscribe` | the public mirror, and the only one that runs CI |

Both carry the same `main` and the same tags. Push `origin` first: a commit that has not been through
the local gate has no business being public.

## Continuous integration

`.github/workflows/build.yml` runs on GitHub on every push to `main`, every pull request, and on
demand from the Actions tab. Gitea has no runner, so a push there is checked by nothing.

| Job | Runner | Produces |
|---|---|---|
| `android` | `ubuntu-latest` | analyze, the full test suite, an APK and an AAB |
| `windows-x64` | `windows-latest` | an Inno Setup installer |
| `windows-arm64` | `windows-11-arm` | an Inno Setup installer |
| `ios` | `macos-latest` | an unsigned sideload IPA |
| `macos` | `macos-latest` | a DMG |
| `release` | `ubuntu-latest` | on a `v*` tag only: a GitHub Release with all of the above |

**The verification gate is still local.** CI is a second opinion on four platforms this machine does
not have; it is not a reason to stop running `flutter analyze` and `flutter test` before committing.
A red build there after a green run here is nearly always a platform-specific problem worth reading.

Three things about the jobs are worth knowing:

- **Android release signing is optional.** The job writes `android/key.properties` only when the
  repository has the keystore secrets (`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD`). Without them the Gradle config falls back to the debug key exactly as a local
  build does, so the APK installs but is not something to publish to a store.
- **The Ubuntu runner has FFmpeg**, so `test/media_toolkit_live_test.dart` stops skipping itself and
  exercises the external-executable media backend against a real binary. That is the one part of the
  media layer a host without FFmpeg cannot check. Its large download stays behind
  `--dart-define=live_download`.
- **The ARM64 job uses stable**, unlike the sibling apps, which build it from Flutter master. When
  their workflows were written stable had no ARM64 Windows engine; 3.44.2 ships
  `windows-arm64-release`, and this project is developed on Windows on ARM64 against exactly that
  version. Pinning stable also means every run produces the same `flutter_windows.dll`, so
  Defender's cloud reputation accumulates against one hash instead of a fresh unknown one per build.

MSIX is not built in CI: packaging one needs a signing certificate, and this repository carries
none. `dart run msix:create` locally is still the way to produce it.

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
