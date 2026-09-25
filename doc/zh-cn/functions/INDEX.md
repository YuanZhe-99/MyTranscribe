# MyTranscribe `lib/` 函数索引

`lib/` 手写函数说明层文档的顶层索引。每一行链接到与 `lib/` 目录结构对应的单个源文件页面，`.dart` 换成
`.md`。

请测量这些计数，而不要手工调整：

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

`lib/l10n/` 下生成的本地化代码不属于该约定，也不计入这些计数。

在 0.2.1 发布时，该命令报告 **86** 个源文件中共 **881** 处带说明的声明。加上本地模型计划的基础部分（L0）后，它报告
**100** 个源文件中共 **1076** 处，其中每个文件都出现在下面的表格里。

## 状态

单文件页面随各领域实现而撰写；下表列出今天存在的文件，以及当前描述它们的概念页面。当某个文件的行为不再能被概
念文档完整描述时，它才会获得自己的页面。今天还没有出现这种情况：每个文件都被某个概念页面覆盖，而一张只有一行
说明的表格，能说的比源码里已有的 `/// Purpose:` 段落还少。

## 根目录

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/main.dart` | [architecture.md](../architecture.md) |

## app/

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/app/app.dart` | [architecture.md](../architecture.md) |
| `lib/app/router.dart` | [architecture.md](../architecture.md) |
| `lib/app/theme.dart` | [architecture.md](../architecture.md) |
| `lib/app/flavor.dart` | [architecture.md](../architecture.md) |
| `lib/app/locale_resolution.dart` | [architecture.md](../architecture.md) |
| `lib/app/data_modules.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |

## features/

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/features/providers/models/transcribe_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/providers/models/provider_config.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/model_config.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/provider_templates.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/models/transcribe_defaults.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/providers/services/settings_repository.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/views/provider_editor_page.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/views/model_editor_page.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/widgets/api_key_field.dart` | [features/secure-secrets-sync.md](../features/secure-secrets-sync.md) |
| `lib/features/secrets/models/provider_secrets.dart` | [features/secure-secrets-sync.md](../features/secure-secrets-sync.md) |
| `lib/features/secrets/services/secrets_store.dart` | [features/secure-secrets-sync.md](../features/secure-secrets-sync.md) |
| `lib/features/providers/views/library_page.dart` | [features/provider-library.md](../features/provider-library.md) |
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
| `lib/features/settings/views/settings_page.dart` | [features/sync-and-backup.md](../features/sync-and-backup.md) |
| `lib/features/settings/views/backup_page.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/features/settings/views/speaker_names_page.dart` | [features/diarization-and-speakers.md](../features/diarization-and-speakers.md) |
| `lib/features/settings/views/license_page.dart` | — |
| `lib/features/settings/views/privacy_policy_page.dart` | — |
| `lib/features/jobs/models/transcription_job.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/jobs/models/transcripts_document.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |
| `lib/features/jobs/models/chunk_plan.dart` | [algorithms/chunk-planner.md](../algorithms/chunk-planner.md) |
| `lib/features/jobs/services/chunk_planner.dart` | [algorithms/chunk-planner.md](../algorithms/chunk-planner.md) |
| `lib/features/jobs/services/transcript_merger.dart` | [algorithms/overlap-merge.md](../algorithms/overlap-merge.md) |
| `lib/features/jobs/services/job_store.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/jobs/services/job_runner.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/jobs/services/job_providers.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/jobs/services/transcript_sync.dart` | [sync.md](../sync.md) |
| `lib/features/jobs/services/audio_sync_service.dart` | [sync.md](../sync.md) |
| `lib/features/jobs/services/output_writer.dart` | [features/exports.md](../features/exports.md) |
| `lib/features/jobs/views/new_job_page.dart` | [features/chunking-and-resume.md](../features/chunking-and-resume.md) |
| `lib/features/jobs/views/job_detail_page.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/jobs/views/job_text.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/providers/services/provider_dialect.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/services/dialects.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/services/response_parsers.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/services/transcription_client.dart` | [features/transcription-jobs.md](../features/transcription-jobs.md) |
| `lib/features/providers/services/model_catalog_fetcher.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/providers/widgets/add_source_sheet.dart` | [features/provider-library.md](../features/provider-library.md) |
| `lib/features/secrets/services/secure_endpoint_policy.dart` | [algorithms/secure-endpoint.md](../algorithms/secure-endpoint.md) |
| `lib/features/secrets/services/secrets_sync_service.dart` | [features/secure-secrets-sync.md](../features/secure-secrets-sync.md) |
| `lib/features/secrets/views/secrets_endpoint_section.dart` | [features/secure-secrets-sync.md](../features/secure-secrets-sync.md) |
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
| `lib/features/local/models/local_engine_state.dart` | [data-formats.md](../data-formats.md) |
| `lib/features/local/services/local_asr_engine.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/engine_registry.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/engine_router.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/services/artifact_downloader.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/artifact_manager.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/local_engine_state_store.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/local_model_templates.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/local_transcription_backend.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/services/pcm_window_cutter.dart` | [features/media-tools.md](../features/media-tools.md) |
| `lib/features/local/services/route_smoke_test.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/services/smoke_clip.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/services/tested_here.dart` | [algorithms/engine-routing.md](../algorithms/engine-routing.md) |
| `lib/features/local/engines/fluid_audio_engine.dart` | [features/local-models.md](../features/local-models.md), [platform-notes.md](../platform-notes.md) |
| `lib/features/local/engines/sherpa_onnx_engine.dart` | [features/local-models.md](../features/local-models.md), [platform-notes.md](../platform-notes.md) |
| `lib/features/local/engines/system_recognizer_engine.dart` | [features/local-models.md](../features/local-models.md), [platform-notes.md](../platform-notes.md) |
| `lib/features/local/engines/whisper_cpp_engine.dart` | [features/local-models.md](../features/local-models.md), [platform-notes.md](../platform-notes.md) |
| `lib/features/local/services/local_models_controller.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/views/local_text.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/views/local_model_page.dart` | [features/local-models.md](../features/local-models.md) |
| `lib/features/local/views/engine_diagnostics_page.dart` | [features/local-models.md](../features/local-models.md) |

## shared/

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/shared/services/transcribe_storage.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/services/webdav_service.dart` | [sync.md](../sync.md) |
| `lib/shared/services/sync_merge.dart` | [sync.md](../sync.md) |
| `lib/shared/services/backup_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/import_export_service.dart` | [backup-restore.md](../backup-restore.md) |
| `lib/shared/services/auto_sync_service.dart` | [sync.md](../sync.md) |
| `lib/shared/providers/app_settings.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/utils/adaptive_layout.dart` | [adaptive-layout.md](../adaptive-layout.md) |
| `lib/shared/utils/file_retry.dart` | [data-formats.md](../data-formats.md) |
| `lib/shared/utils/platform_capabilities.dart` | [platform-notes.md](../platform-notes.md) |
| `lib/shared/views/webdav_config_page.dart` | [sync.md](../sync.md) |
| `lib/shared/widgets/shell_scaffold.dart` | [adaptive-layout.md](../adaptive-layout.md) |
| `lib/shared/widgets/settings_conflict_dialog.dart` | [sync.md](../sync.md) |
| `lib/shared/widgets/empty_state.dart` | — |
| `lib/shared/services/audio_player_service.dart` | [features/transcript-viewer.md](../features/transcript-viewer.md) |
| `lib/shared/utils/byte_format.dart` | — |
