# MyTranscribe `lib/` Function Index

The top-level index of the hand-written Function Explanation Layer documentation for `lib/`. Each
row links to a per-source-file page mirroring the `lib/` tree, with `.dart` replaced by `.md`.

Measure these counts rather than adjusting them by hand:

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

Generated localization code under `lib/l10n/` is excluded from the convention and from these counts.

## Status

The per-file pages are written as each area is implemented; the table below lists the files that
exist today and the concept page that currently describes each one. A file gains its own page when
its behaviour stops being fully described by the concept documentation.

## Root

| Source file | Described by |
|---|---|
| `lib/main.dart` | [architecture.md](../architecture.md) |

## app/

| Source file | Described by |
|---|---|
| `lib/app/app.dart` | [architecture.md](../architecture.md) |
| `lib/app/router.dart` | [architecture.md](../architecture.md) |
| `lib/app/theme.dart` | [architecture.md](../architecture.md) |
| `lib/app/flavor.dart` | [architecture.md](../architecture.md) |
| `lib/app/locale_resolution.dart` | [architecture.md](../architecture.md) |
| `lib/app/data_modules.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |

## features/

| Source file | Described by |
|---|---|
| `lib/features/providers/models/transcribe_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/providers/views/library_page.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/jobs/views/jobs_page.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/settings/views/settings_page.dart` | [features/sync-and-backup.md](../features/sync-and-backup.md) |
| `lib/features/settings/views/backup_page.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/features/settings/views/license_page.dart` | — |
| `lib/features/settings/views/privacy_policy_page.dart` | — |

## shared/

| Source file | Described by |
|---|---|
| `lib/shared/services/transcribe_storage.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/services/webdav_service.dart` | [sync.md](../sync.md) |
| `lib/shared/services/sync_merge.dart` | [sync.md](../sync.md) |
| `lib/shared/services/backup_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/import_export_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/auto_sync_service.dart` | [sync.md](../sync.md) |
| `lib/shared/providers/app_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/utils/adaptive_layout.dart` | [adaptive-layout.md](../adaptive-layout.md) |
| `lib/shared/utils/platform_capabilities.dart` | [platform-notes.md](../platform-notes.md) |
| `lib/shared/views/webdav_config_page.dart` | [sync.md](../sync.md) |
| `lib/shared/widgets/shell_scaffold.dart` | [adaptive-layout.md](../adaptive-layout.md) |
| `lib/shared/widgets/settings_conflict_dialog.dart` | [sync.md](../sync.md) |
| `lib/shared/widgets/empty_state.dart` | — |
