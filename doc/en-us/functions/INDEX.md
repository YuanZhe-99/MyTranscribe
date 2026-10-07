# MyTranscribe `lib/` Function Index

WebDAVConfigPage.build uses myapps_data connection and operation controls;
endpoint security and audio-sync policies stay in application adapters.

Settings rendering delegates to myapps_ui; see [shared-ui.md](../shared-ui.md).
Appearance rows use MyAppsSettingsSegmentRow; data actions and backup preferences
delegate to myapps_data. Callbacks and domain settings stay application-owned.

Profile rows now document shared exports and app adapters; implementation ownership is in [shared-ui.md](../shared-ui.md).

The top-level index of the hand-written Function Explanation Layer documentation for `lib/`. Each
row links to a per-source-file page mirroring the `lib/` tree, with `.dart` replaced by `.md`.

Measure these counts rather than adjusting them by hand:

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

Generated localization code under `lib/l10n/` is excluded from the convention and from these counts.

At the 0.2.1 release that command reports **881** documented declarations across **86** source
files. With the foundation of the local-models plan (L0) it reports **1076** across **100**, and
These are historical extraction counts; the tables below cover the current source tree.

## Status

The per-file pages are written as each area is implemented; the table below lists the files that
exist today and the concept page that currently describes each one. A file gains its own page when
its behaviour stops being fully described by the concept documentation. Shared AI migration
files now have per-file declaration pages; unchanged areas still link to their concept pages.

## Root

| Source file | Described by |
|---|---|
| `lib/main.dart` | [architecture.md](../architecture.md) |

## app/

| Source file | Described by |
|---|---|
| `lib/app/app.dart` | [architecture.md](../architecture.md) |
| `lib/app/router.dart` | [router.md](app/router.md) |
| `lib/app/theme.dart` | [shared-ui.md](../shared-ui.md) |
| `lib/app/flavor.dart` | [architecture.md](../architecture.md) |
| `lib/app/locale_resolution.dart` | [architecture.md](../architecture.md) |
| `lib/app/data_modules.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |

## features/

| Source file | Described by |
|---|---|
| `lib/features/profile/models/profile_data.dart` | [features/profile.md](../features/profile.md), [data-formats.md](../data-formats.md) |
| `lib/features/profile/services/profile_merge.dart` | [features/profile.md](../features/profile.md), [sync.md](../sync.md) |
| `lib/features/profile/services/profile_store.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/profile/services/avatar_image.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/profile/providers/profile_provider.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/profile/views/avatar_editor.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/profile/views/profile_avatar.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/profile/views/profile_header.dart` | [features/profile.md](../features/profile.md) |
| `lib/features/providers/models/transcribe_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/providers/models/provider_config.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/model_config.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/provider_templates.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/transcribe_defaults.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/providers/services/settings_repository.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/views/provider_editor_page.dart` | [provider_editor_page.md](features/providers/views/provider_editor_page.md) |
| `lib/features/providers/views/model_editor_page.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/widgets/api_key_field.dart` | [api_key_field.md](features/providers/widgets/api_key_field.md) |
| `lib/features/secrets/models/provider_secrets.dart` | [provider_secrets.md](features/secrets/models/provider_secrets.md) |
| `lib/features/secrets/services/secrets_store.dart` | [secrets_store.md](features/secrets/services/secrets_store.md) |
| `lib/features/providers/views/source_management_page.dart` | [source_management_page.md](features/providers/views/source_management_page.md) |
| `lib/features/jobs/views/jobs_page.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/media/models/media_info.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/media_toolkit.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/external_ffmpeg_media_toolkit.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/embedded_ffmpeg_media_toolkit.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/ffmpeg_locator.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/ffmpeg_downloader.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/ffmpeg_progress_parser.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/media/services/media_toolkit_provider.dart` | [platform-notes.md](../platform-notes.md) |
| `lib/features/media/widgets/media_tools_tile.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/settings/views/settings_page.dart` | [settings_page.md](features/settings/views/settings_page.md) |
| `lib/features/settings/views/backup_page.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/features/settings/views/speaker_names_page.dart` | [features/diarization-and-speakers.md](../features/diarization-and-speakers.md) |
| `lib/features/settings/views/license_page.dart` | [license_page.md](features/settings/views/license_page.md) |
| `lib/features/settings/views/privacy_policy_page.dart` | [privacy_policy_page.md](features/settings/views/privacy_policy_page.md) |
| `lib/features/jobs/models/transcription_job.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/jobs/models/transcripts_document.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |
| `lib/features/jobs/models/chunk_plan.dart` | [algorithms/chunk-planner.md](../algorithms/chunk-planner.md) |
| `lib/features/jobs/services/chunk_planner.dart` | [algorithms/chunk-planner.md](../algorithms/chunk-planner.md) |
| `lib/features/jobs/services/transcript_merger.dart` | [algorithms/overlap-merge.md](../algorithms/overlap-merge.md) |
| `lib/features/jobs/services/job_store.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/jobs/services/job_runner.dart` | [job_runner.md](features/jobs/services/job_runner.md) |
| `lib/features/jobs/services/job_providers.dart` | [job_providers.md](features/jobs/services/job_providers.md) |
| `lib/features/jobs/services/transcript_sync.dart` | [sync.md](../sync.md) |
| `lib/features/jobs/services/audio_sync_service.dart` | [sync.md](../sync.md) |
| `lib/features/jobs/services/output_writer.dart` | [features/exports.md](../features/exports.md) |
| `lib/features/jobs/views/new_job_page.dart` | [new_job_page.md](features/jobs/views/new_job_page.md) |
| `lib/features/jobs/views/job_detail_page.dart` | [job_detail_page.md](features/jobs/views/job_detail_page.md) |
| `lib/features/jobs/views/job_text.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/providers/services/provider_dialect.dart` | [provider_dialect.md](features/providers/services/provider_dialect.md) |
| `lib/features/providers/services/dialects.dart` | [dialects.md](features/providers/services/dialects.md) |
| `lib/features/providers/services/response_parsers.dart` | [response_parsers.md](features/providers/services/response_parsers.md) |
| `lib/features/providers/services/transcription_client.dart` | [transcription_client.md](features/providers/services/transcription_client.md) |
| `lib/features/providers/services/model_catalog_fetcher.dart` | [model_catalog_fetcher.md](features/providers/services/model_catalog_fetcher.md) |
| `lib/features/providers/widgets/add_source_sheet.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/secrets/services/secure_endpoint_policy.dart` | [secure_endpoint_policy.md](features/secrets/services/secure_endpoint_policy.md) |
| `lib/features/secrets/services/secrets_sync_service.dart` | [secrets_sync_service.md](features/secrets/services/secrets_sync_service.md) |
| `lib/features/secrets/views/secrets_endpoint_section.dart` | [secrets_endpoint_section.md](features/secrets/views/secrets_endpoint_section.md) |
| `lib/features/transcript/models/transcript.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/transcript/services/transcript_store.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/transcript/services/transcript_providers.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/transcript/services/speaker_unifier.dart` | [algorithms/speaker-unification.md](../algorithms/speaker-unification.md) |
| `lib/features/transcript/services/speaker_palette.dart` | [features/diarization-and-speakers.md](../features/diarization-and-speakers.md) |
| `lib/features/transcript/services/transcript_search.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/transcript/services/export_formatters.dart` | [features/exports.md](../features/exports.md) |
| `lib/features/transcript/services/transcript_exporter.dart` | [features/exports.md](../features/exports.md) |
| `lib/features/transcript/views/transcript_viewer_page.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/transcript/widgets/viewer_options_panel.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/transcript/widgets/speakers_panel.dart` | [features/diarization-and-speakers.md](../features/diarization-and-speakers.md) |
| `lib/features/transcript/widgets/segment_edit_sheet.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/transcript/widgets/audio_player_bar.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/features/local/models/local_model_config.dart` | [features/local-models.md](../features/local-models.md), [data-formats.md](../data-formats.md) |
| `lib/features/local/models/engine_capability.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/models/artifact_manifest.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/local/models/local_engine_state.dart` | [local_engine_state.md](features/local/models/local_engine_state.md) |
| `lib/features/local/services/local_asr_engine.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/engine_registry.dart` | [engine_registry.md](features/local/services/engine_registry.md) |
| `lib/features/local/services/engine_router.dart` | [engine_router.md](features/local/services/engine_router.md) |
| `lib/features/local/services/artifact_downloader.dart` | [artifact_downloader.md](features/local/services/artifact_downloader.md) |
| `lib/features/local/services/artifact_manager.dart` | [artifact_manager.md](features/local/services/artifact_manager.md) |
| `lib/features/local/services/local_engine_state_store.dart` | [local_engine_state_store.md](features/local/services/local_engine_state_store.md) |
| `lib/features/local/services/speaker_labeler.dart` | [speaker_labeler.md](features/local/services/speaker_labeler.md) |
| `lib/features/local/views/speaker_labels_tile.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/local_model_templates.dart` | [local_model_templates.md](features/local/services/local_model_templates.md) |
| `lib/features/local/services/local_transcription_backend.dart` | [local_transcription_backend.md](features/local/services/local_transcription_backend.md) |
| `lib/features/local/services/pcm_window_cutter.dart` | [pcm_window_cutter.md](features/local/services/pcm_window_cutter.md) |
| `lib/features/local/services/route_smoke_test.dart` | [route_smoke_test.md](features/local/services/route_smoke_test.md) |
| `lib/features/local/services/smoke_clip.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/services/tested_here.dart` | [tested_here.md](features/local/services/tested_here.md) |
| `lib/features/local/engines/fluid_audio_engine.dart` | [fluid_audio_engine.md](features/local/engines/fluid_audio_engine.md) |
| `lib/features/local/engines/sherpa_onnx_engine.dart` | [sherpa_onnx_engine.md](features/local/engines/sherpa_onnx_engine.md) |
| `lib/features/local/engines/system_recognizer_engine.dart` | [system_recognizer_engine.md](features/local/engines/system_recognizer_engine.md) |
| `lib/features/local/engines/whisper_cpp_engine.dart` | [whisper_cpp_engine.md](features/local/engines/whisper_cpp_engine.md) |
| `lib/features/local/services/local_models_controller.dart` | [local_models_controller.md](features/local/services/local_models_controller.md) |
| `lib/features/local/views/local_text.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/views/local_model_page.dart` | [local_model_page.md](features/local/views/local_model_page.md) |
| `lib/features/local/views/engine_diagnostics_page.dart` | [features/local-models.md](../features/local-models.md) |

## shared/

| Source file | Described by |
|---|---|
| `lib/shared/services/transcribe_storage.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/services/webdav_service.dart` | [webdav_service.md](shared/services/webdav_service.md) |
| `lib/shared/services/sync_merge.dart` | [sync.md](../sync.md) |
| `lib/shared/services/backup_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/import_export_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/auto_sync_service.dart` | [auto_sync_service.md](shared/services/auto_sync_service.md) |
| `lib/shared/providers/app_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/utils/adaptive_layout.dart` | [shared-ui.md](../shared-ui.md) |
| `lib/shared/utils/file_retry.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/utils/platform_capabilities.dart` | [platform-notes.md](../platform-notes.md) |
| `lib/shared/views/webdav_config_page.dart` | [webdav_config_page.md](shared/views/webdav_config_page.md) |
| `lib/shared/widgets/shell_scaffold.dart` | [shell_scaffold.md](shared/widgets/shell_scaffold.md) |
| `lib/shared/widgets/settings_conflict_dialog.dart` | [sync.md](../sync.md) |
| `lib/shared/widgets/empty_state.dart` | — |
| `lib/shared/services/audio_player_service.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/shared/utils/byte_format.dart` | — |

| `lib/features/local/services/shared_asr_adapter.dart` | [shared_asr_adapter.md](features/local/services/shared_asr_adapter.md) |

| `lib/features/providers/services/shared_online_adapter.dart` | [shared_online_adapter.md](features/providers/services/shared_online_adapter.md) |

| `lib/features/providers/services/online_privacy.dart` | [online_privacy.md](features/providers/services/online_privacy.md) |

| `lib/features/local/views/model_downloads_page.dart` | [model_downloads_page.md](features/local/views/model_downloads_page.md) |

| `lib/shared/services/webdav_privacy.dart` | [webdav_privacy.md](shared/services/webdav_privacy.md) |

| `lib/features/providers/services/online_sources_controller.dart` | [online_sources_controller.md](features/providers/services/online_sources_controller.md) |

| `lib/features/providers/views/online_sources_page.dart` | [online_sources_page.md](features/providers/views/online_sources_page.md) |
