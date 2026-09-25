# Architecture

## Shape

MyTranscribe is a Flutter app with three tabs and no backend of its own. Everything it does is
either local file work, a model running on the device, or a request to a server the user configured.

```
lib/
  main.dart                 startup services, last tab, runApp
  app/                      app shell: MaterialApp.router, theme, routes, data modules
  features/<feature>/       models/ services/ views/ widgets/
  shared/                   providers/ services/ utils/ views/ widgets/
  l10n/                     ARB catalogs and their generated Dart
packages/myapps_data/       the shared sync, backup and ZIP engines (git submodule)
```

`features/` is flat by domain, not by layer: there is no data/domain/presentation split. A feature
owns its models, its services and its pages, and anything two features need moves to `shared/`.

The features are `jobs` (transcribing), `providers` (sources and models), `local` (models that run
on the device: their records, packages, engines and routes), `transcript` (reading the result),
`media` (FFmpeg), `secrets` (API keys) and `settings`.

A local model reaches the job runner through `LocalTranscriptionBackend`, which speaks the one engine
protocol, `LocalAsrEngine`, that every on-device adapter implements. The runner's stage machine,
resume and merge are shared by uploaded and local jobs; see
[`features/local-models.md`](features/local-models.md).

## Core architectural rules

- **State management is `flutter_riverpod` 1.x** — `StateNotifierProvider` for anything the UI
  edits, plain `Provider` for a dependency, `FutureProvider` for a one-shot read. Provider and Bloc
  are not used and should not be introduced.
- **Routing is `go_router` with a single `ShellRoute`.** The three tabs live inside it. Starting a
  job and reading a transcript are full-window routes *outside* the shell: both are things you do to
  one recording and leave when finished, and a transcript wants the whole window. Keeping them
  outside also means they have no navigation rail to subtract, which the layout rules rely on.
  `buildAppRouter` takes the initial location, and the root widget holds the router in a
  `late final` field so a theme or locale change does not rebuild it and reset navigation history.
- **There is no dependency injection container.** Riverpod providers plus static service singletons
  are the whole of it.
- **Material 3 through `flex_color_scheme`**, seeded with `FlexScheme.tealM3`. The scheme is what
  tells the series' apps apart at a glance.
- **Models are hand-written.** No code generation. Every model has `fromJson` and `toJson` and
  carries an `extraJson` map, so a field written by a newer build survives being read and rewritten
  by an older one.
- **Persistence is pretty-printed JSON files** under the app directory. No database, no
  `shared_preferences`. The indentation is load-bearing: sync compares raw strings before merging,
  so an engine that wrote a different format from the storage hub would make every unchanged file
  look changed and re-upload forever.
- **HTTP is `package:http`.** The shared package uses it too, so one stack serves both the WebDAV
  transport and the transcription requests.
- **One file branches on the platform**: `lib/shared/utils/platform_capabilities.dart`, and it reads
  `defaultTargetPlatform` rather than `dart:io`'s `Platform`, so a widget test can drive any branch
  on the one host the project actually has.
- **One file holds layout numbers**: `lib/shared/utils/adaptive_layout.dart`, which imports nothing
  from Flutter and is therefore testable as pure functions. A numeric width comparison inside a
  widget file is a bug.

## The five kinds of data

This distinction runs through the whole app and is worth stating once:

| Kind | Example | Synced | In backups and ZIP |
|---|---|---|---|
| Configuration | sources, models, defaults | yes, as a data module | yes |
| Transcripts | the record and text of a finished transcription | yes, as a data module projected from `jobs/` | yes |
| Secrets | API keys | only to a secure endpoint, by a separate exchange | no |
| Recordings and audio | the original file, the chunk audio, the converted copy | no — the converted copy only, only by an opt-in side channel | no |
| Downloaded models | the packages a local model loads, and this device's engine state | no — the local model *records* sync as configuration | no |

The exclusions are **structural**, not filtered: the sync, backup and ZIP engines only ever touch
the file names in the registry in `lib/app/data_modules.dart`, and neither the secrets file, the job
folders nor the models folder are in it. Adding any of them to the registry would silently start
uploading it.

A transcription's *text* still travels, because the small half of each job folder — the record and
the transcript, never the audio — is projected into a module file of its own before a sync and
applied back into `jobs/` afterwards. The converted listening copy travels only on a device that
asked for it, through an app-level side channel like the one the keys use. See
[`data-formats.md`](data-formats.md) and [`sync.md`](sync.md).

## The shared package

`myapps_data` is a Flutter package embedded as a git submodule at `packages/myapps_data` and
consumed as a path dependency. It provides the WebDAV transport and sync engine, the upload lock,
the generic three-way record merge, atomic file writes, storage migration, the backup engine and the
ZIP transfer engine.

The app meets it at two seams:

- `lib/app/data_modules.dart` — a `StorageAdapter` implementation and the `ModuleRegistry`. This
  file is the single source of truth for data-file names, module ids, the remote path and the
  archive prefix; nothing else may hardcode them.
- `lib/shared/services/webdav_service.dart`, `backup_service.dart`, `import_export_service.dart`
  and `auto_sync_service.dart` — four thin facades whose public shape matches the sibling apps', so
  a page can be ported between apps unchanged. Behaviour changes belong in the package, not in a
  facade.

Consumers must not import `package:myapps_data/src/...` directly; the barrel is the API.

## Storage

`lib/shared/services/transcribe_storage.dart` is the storage hub: the one place that knows where
data lives. Every file access resolves through `getAppDir()`, which honours a custom storage path,
and every settings write goes through `saveSettings()`, which notifies auto-sync. Device-local
preferences are typed accessors over `storage_config.json`, and a default is stored as an **absent
key** so a later build that changes a default changes it for everyone who never touched the setting.

## Startup

`main()` does four things before the first frame, in this order: start the daily backup check (fire
and forget), start the auto-sync lifecycle observer, read the last tab so the app opens where the
user left it, and `runApp`. Nothing here reaches the network — both services are no-ops until the
user configures sync in Settings.

`DevicePreview` is compiled in and enabled only in debug builds, where it is the quickest way to try
the foldable geometries in [`adaptive-layout.md`](adaptive-layout.md).

## Localization

Stock Flutter `gen-l10n` with ARB files in `lib/l10n/`. `app_en.arb` is the template; `app_zh.arb`
and `app_zh_TW.arb` mirror it key for key, and `test/l10n_arb_test.dart` fails when one of them does
not. Generated files are committed. The two Chinese catalogs are both hand-maintained: Taiwan usage
differs by vocabulary and not only by characters.

`lib/app/locale_resolution.dart` decides Traditional versus Simplified by script subtag, because
Flutter's own language-and-country matching sends `zh-Hant-HK` to Simplified.

## Testing

Pure rules are tested as pure functions; rendered pages are tested at the logical-pixel geometry of
named devices. Widget tests run in Simplified Chinese: `flutter_test`'s default font renders every
glyph as a full em square, which inflates Latin labels to roughly two and a half times their real
width and reports overflow at widths that are comfortable in production. CJK glyphs really are
square, so a Chinese locale measures the production layout.
