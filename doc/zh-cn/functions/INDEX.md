# MyTranscribe `lib/` 函数索引

WebDAVConfigPage.build 使用 myapps_data 连接和操作控件，端点安全及音频同步
策略留在应用适配器。

外观设置行使用 MyAppsSettingsSegmentRow，数据操作和备份偏好委托给 myapps_data。
回调和领域设置由应用负责。

设置显示委托 myapps_ui，见 [shared-ui.md](../shared-ui.md)。

资料条目现在描述公共导出和应用适配，实现归属见 [shared-ui.md](../shared-ui.md)。

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
念文档完整描述时，它才会获得自己的页面。共享 AI 迁移涉及的文件现已有逐文件声明页面；
未改动领域仍链接到对应概念页面。

## 根目录

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/main.dart` | [architecture.md](../architecture.md) |

## app/

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/app/app.dart` | [architecture.md](../architecture.md) |
| `lib/app/router.dart` | [router.md](app/router.md) |
| `lib/app/theme.dart` | [shared-ui.md](../shared-ui.md) |
| `lib/app/flavor.dart` | [architecture.md](../architecture.md) |
| `lib/app/locale_resolution.dart` | [architecture.md](../architecture.md) |
| `lib/app/data_modules.dart` | [data-formats.md](../data-formats.md), [sync.md](../sync.md) |

## features/

| 源文件 | 由哪一页描述 |
|---|---|
| `lib/features/profile/models/profile_data.dart` | [features/profile.md](../features/profile.md)、[data-formats.md](../data-formats.md) |
| `lib/features/profile/services/profile_merge.dart` | [features/profile.md](../features/profile.md)、[sync.md](../sync.md) |
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

| 源文件 | 由哪一页描述 |
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
