/// Purpose: Single source of truth describing MyTranscribe's syncable data
/// files to the shared `myapps_data` engines.
/// Inputs: `TranscribeStorage` for storage paths/settings, `mergeSettingsData`
/// for the app's record merge, and `TranscribeSettings` for parsing.
/// Returns: A `StorageAdapter` implementation and the app's `ModuleRegistry`.
/// Side effects: None at import time; callbacks perform parsing and storage
/// I/O.
/// Notes: File names and module IDs are persisted compatibility contracts
/// (myapps_data invariants I1/I2) and must never change once a build ships.
///
/// **What is deliberately not here.** `transcribe_secrets.json` — the API keys
/// — is not a module. The registry is fixed when the sync engine is built, so a
/// module cannot be registered conditionally, and keys must only travel to a
/// server the user reaches securely. `SecretsSyncService` exchanges that file
/// itself. Job folders under `jobs/` are not modules either: recordings and
/// transcripts are large and private, and only configuration was ever meant to
/// be backed up. Both are excluded *structurally* — the sync, backup and ZIP
/// engines only ever touch the file names in this registry — rather than by a
/// filter somebody could forget to update.
///
/// **What the transcripts module is.** `transcribe_transcripts.json` carries
/// the small half of every finished job folder: the record and the transcript,
/// and nothing else. It is a projection, rebuilt from `jobs/` before a sync and
/// applied back into it afterwards by `TranscriptSyncService`, so the folders
/// stay the app's source of truth and the audio stays where it is. The
/// converted listening copy travels only through an opt-in side channel, under
/// `audio/` beside these files, never as a module.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';

import '../features/jobs/models/transcripts_document.dart';
import '../features/providers/models/transcribe_settings.dart';
import '../shared/services/sync_merge.dart';
import '../shared/services/transcribe_storage.dart';

/// Pretty-printer matching `TranscribeStorage`'s local save format.
///
/// Sync writes must use the same indentation the storage hub uses, otherwise an
/// otherwise-unchanged file misses the raw-equality fast path on the next sync
/// and re-uploads forever (I6).
const _prettyJson = JsonEncoder.withIndent('  ');

/// Local and remote name of MyTranscribe's settings file (I1/I2).
const settingsDataFileName = 'transcribe_settings.json';

/// Backup bundle module key for that file (I2).
const settingsModuleId = 'settings';

/// Local name of the API-key file.
///
/// Never in [transcribeModuleRegistry]; see the library note above.
const secretsFileName = 'transcribe_secrets.json';

/// Local and remote name of the transcripts projection (I1/I2).
const transcriptsDataFileName = 'transcribe_transcripts.json';

/// Backup bundle module key for that file (I2).
const transcriptsModuleId = 'transcripts';

/// Remote subdirectory holding one converted audio file per transcription.
///
/// Not a module: audio travels through an app-level side channel that only
/// runs when the device has opted in, the same shape the API keys use.
const audioRemoteDirName = 'audio';

/// Marker inside a job folder saying its converted audio was removed on purpose.
///
/// Without it, the next sync would helpfully download again exactly what the
/// user had just deleted to free space.
const audioDiscardedMarkerName = 'audio.discarded';

/// Directory under the app dir holding one folder per transcription job.
const jobsDirName = 'jobs';

/// Directory holding one folder per installed local model package.
///
/// Never in [transcribeModuleRegistry]: a model is gigabytes, re-downloadable,
/// and belongs to one device (decision D3 of the local-models plan). Keeping it
/// out of the registry keeps it out of sync, backups and ZIP exports
/// structurally, the way the job folders are kept out.
const modelsDirName = 'models';

/// Directory inside [modelsDirName] holding partial downloads and the staging
/// folders an install is assembled in before it is renamed into place.
const modelDownloadsDirName = '.downloads';

/// The device-local state of the local engines: smoke-test results, the
/// in-flight marker, the chosen device per model and the fallback policy.
///
/// Not a data module. Every value in it describes this device, and syncing a
/// GPU choice or a check result would make it a promise on another one.
const localEngineStateFileName = 'local_engine_state.json';

/// Default remote WebDAV directory for MyTranscribe.
const transcribeDefaultRemotePath = '/MyTranscribe';

/// Archive name prefix for ZIP exports.
const transcribeArchiveNamePrefix = 'mytranscribe_export_';

/// Purpose: Bridge the shared engines to MyTranscribe's storage hub.
/// Inputs: Optional [appDir] resolver overriding the hub lookup.
/// Returns: Storage root and `storage_config.json` access.
/// Side effects: Delegates to `TranscribeStorage`, which performs file I/O.
/// Notes: [appDir] exists so `BackupService` can expose a
/// `@visibleForTesting appDirProvider` seam; it is read on every call, so tests
/// that swap the provider between cases still work.
class TranscribeStorageAdapter implements StorageAdapter {
  /// Purpose: Create an adapter over `TranscribeStorage`.
  /// Inputs: Optional [appDir] resolver.
  /// Returns: A new adapter.
  /// Side effects: None.
  /// Notes: Pass [appDir] only to preserve a test seam.
  const TranscribeStorageAdapter({Future<Directory> Function()? appDir})
    : _appDir = appDir;

  final Future<Directory> Function()? _appDir;

  /// Purpose: Resolve the active app data directory.
  /// Inputs: None.
  /// Returns: The custom storage path when configured, else the platform dir.
  /// Side effects: May create the directory via the hub.
  /// Notes: Honors the injected resolver first so `appDirProvider` still wins.
  @override
  Future<Directory> getAppDir() => (_appDir ?? TranscribeStorage.getAppDir)();

  /// Purpose: Read `storage_config.json`.
  /// Inputs: None.
  /// Returns: The parsed settings map.
  /// Side effects: Reads local storage.
  /// Notes: Delegates so app-owned keys stay owned by the hub.
  @override
  Future<Map<String, dynamic>> readConfig() => TranscribeStorage.readConfig();

  /// Purpose: Persist `storage_config.json`.
  /// Inputs: [config] complete settings map.
  /// Returns: A future completing after the write.
  /// Side effects: Writes local storage.
  /// Notes: The engines read-modify-write, so unknown keys survive.
  @override
  Future<void> writeConfig(Map<String, dynamic> config) =>
      TranscribeStorage.writeConfig(config);
}

/// Purpose: Encode a settings document the way the storage hub writes it.
/// Inputs: [settings].
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: Shared by the storage hub, the merge and the conflict-resolution
/// paths, so all three produce byte-identical output for identical data.
String encodeSettings(TranscribeSettings settings) =>
    _prettyJson.convert(settings.toJson());

/// Purpose: Validate a `transcribe_settings.json` payload before it is
/// written.
/// Inputs: [json] raw module content.
/// Returns: None; throws when the payload is not parseable settings data.
/// Side effects: None.
/// Notes: A bare `TranscribeSettings.fromJson(jsonDecode(...))`, so the backup
/// and import engines surface the parser's own exception when a payload is bad.
void validateSettingsJson(String json) {
  TranscribeSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Purpose: Merge local/remote/base settings JSON for the shared sync engine.
/// Inputs: [localJson], [remoteJson], optional [baseJson], [autoResolve].
/// Returns: A complete outcome, or a pending one carrying the conflicts.
/// Side effects: None.
/// Notes: Wraps `mergeSettingsData`. The typed `SettingsMergeResult` is carried
/// through as opaque `state` so `WebDAVService` can hand a real `PendingSync`
/// to the conflict dialog.
ModuleMergeOutcome mergeSettingsModule({
  required String localJson,
  required String remoteJson,
  required String? baseJson,
  required bool autoResolve,
}) {
  final result = mergeSettingsData(
    localJson,
    remoteJson,
    baseJson,
    autoResolve: autoResolve,
  );
  if (!result.hasConflicts) {
    return ModuleMergeOutcome(
      mergedJson: encodeSettings(
        TranscribeSettings(records: result.merged, extraJson: result.extraJson),
      ),
      state: result,
    );
  }
  return ModuleMergeOutcome(
    state: result,
    conflicts: [
      for (final conflict in result.conflicts)
        ModuleConflict(
          id: conflict.id,
          localRecord: conflict.localRecord,
          remoteRecord: conflict.remoteRecord,
          displayName: conflict.displayName,
        ),
    ],
    buildResolvedJson: (resolutions) => encodeSettings(
      result.buildResolved({
        for (final entry in resolutions.entries)
          if (entry.value is SettingsRecord)
            entry.key: entry.value as SettingsRecord,
      }),
    ),
  );
}

/// Purpose: Describe `transcribe_settings.json` to the shared engines.
/// Inputs: None.
/// Returns: The app's single [DataModule].
/// Side effects: None.
/// Notes: No `postMergeTransform` (no migration yet), no `preUploadTransform`
/// (unknown-field preservation is baked into the models via
/// `withPreservedUnknownJson`), and no `referencedImages` — settings carry no
/// images.
DataModule buildSettingsModule() => DataModule(
  fileName: settingsDataFileName,
  moduleId: settingsModuleId,
  validate: validateSettingsJson,
  merge:
      ({
        required String localJson,
        required String remoteJson,
        required String? baseJson,
        required bool autoResolve,
      }) => mergeSettingsModule(
        localJson: localJson,
        remoteJson: remoteJson,
        baseJson: baseJson,
        autoResolve: autoResolve,
      ),
);

/// Purpose: Encode a transcripts document the way the projection writes it.
/// Inputs: [document].
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: The same indentation everything else uses, so an unchanged document
/// hits the engine's raw-equality fast path instead of re-uploading (I6).
String encodeTranscripts(TranscriptsDocument document) =>
    _prettyJson.convert(document.toJson());

/// Purpose: Validate a `transcribe_transcripts.json` payload before it is
/// written.
/// Inputs: [json] raw module content.
/// Returns: None; throws when the payload will not parse at all.
/// Side effects: None.
/// Notes: Deliberately shallow. A single unusable record is dropped by the
/// parser rather than rejected here, because refusing the whole file would
/// block every other transcription over one damaged entry.
void validateTranscriptsJson(String json) {
  TranscriptsDocument.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

/// Purpose: Merge local/remote/base transcripts JSON for the shared engine.
/// Inputs: [localJson], [remoteJson], optional [baseJson], [autoResolve].
/// Returns: A complete outcome, or a pending one carrying the conflicts.
/// Side effects: None.
/// Notes: The same shape as [mergeSettingsModule]; the typed result rides along
/// as opaque `state` so `WebDAVService` can hand real conflicts to the dialog.
ModuleMergeOutcome mergeTranscriptsModule({
  required String localJson,
  required String remoteJson,
  required String? baseJson,
  required bool autoResolve,
}) {
  final result = mergeTranscriptsData(
    localJson,
    remoteJson,
    baseJson,
    autoResolve: autoResolve,
  );
  if (!result.hasConflicts) {
    return ModuleMergeOutcome(
      mergedJson: encodeTranscripts(
        TranscriptsDocument(
          records: result.merged,
          extraJson: result.extraJson,
        ),
      ),
      state: result,
    );
  }
  return ModuleMergeOutcome(
    state: result,
    conflicts: [
      for (final conflict in result.conflicts)
        ModuleConflict(
          id: conflict.id,
          localRecord: conflict.localRecord,
          remoteRecord: conflict.remoteRecord,
          displayName: conflict.displayName,
        ),
    ],
    buildResolvedJson: (resolutions) => encodeTranscripts(
      result.buildResolved({
        for (final entry in resolutions.entries)
          if (entry.value is TranscriptSyncRecord)
            entry.key: entry.value as TranscriptSyncRecord,
      }),
    ),
  );
}

/// Purpose: Describe `transcribe_transcripts.json` to the shared engines.
/// Inputs: None.
/// Returns: The transcripts [DataModule].
/// Side effects: None.
/// Notes: The file is a projection of `jobs/`, rebuilt before the engine runs
/// and applied back into the job folders afterwards — see
/// `TranscriptSyncService`. The engine knows none of that; to it this is one
/// more flat file with a merge function.
DataModule buildTranscriptsModule() => DataModule(
  fileName: transcriptsDataFileName,
  moduleId: transcriptsModuleId,
  validate: validateTranscriptsJson,
  merge:
      ({
        required String localJson,
        required String remoteJson,
        required String? baseJson,
        required bool autoResolve,
      }) => mergeTranscriptsModule(
        localJson: localJson,
        remoteJson: remoteJson,
        baseJson: baseJson,
        autoResolve: autoResolve,
      ),
);

/// Purpose: Provide MyTranscribe's ordered module registry.
/// Inputs: None.
/// Returns: A registry holding the settings and transcripts modules.
/// Side effects: None.
/// Notes: Built once; the shared engines treat registry order as significant,
/// so a further module must be appended, never inserted before these.
final ModuleRegistry transcribeModuleRegistry = ModuleRegistry([
  buildSettingsModule(),
  buildTranscriptsModule(),
]);
