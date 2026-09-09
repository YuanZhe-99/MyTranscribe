/// Purpose: MyTranscribe's local backup API, a facade over the shared
/// `BackupEngine` from the `myapps_data` package.
/// Inputs: Backup files and module selections from the backup page.
/// Returns: `BackupInfo` listings and `RestoreResult` outcomes.
/// Side effects: Delegates bundle, blob, and restore I/O to the shared engine.
/// Notes: The `@visibleForTesting appDirProvider` seam is wired into the
/// storage adapter and read on every call, so tests can redirect backup I/O to
/// a temporary directory.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;

import '../../app/data_modules.dart';
import '../../features/jobs/services/transcript_sync.dart';
import 'transcribe_storage.dart';

// The bundle format and its result types are the package's. Shapes:
// RestoreResult{ok, wroteAnything, missingImages} and
// BackupInfo{file, date, sizeBytes, corrupt}.
export 'package:myapps_data/myapps_data.dart' show BackupInfo, RestoreResult;

/// Manages local backups with manual/auto creation and retention policies.
///
/// Backup format v2: each `backup_*.json` bundle stores data-module JSON
/// strings. MyTranscribe has no images, so the `_imageRefs` map every bundle
/// carries stays empty here, and the blob store under `backups/blobs/` is
/// never populated.
class BackupService {
  /// Purpose: Allow tests to redirect backup I/O to a temporary directory.
  /// Inputs: None.
  /// Returns: The overridden app directory future, or null in production.
  /// Side effects: None.
  /// Notes: Only set from tests; production always uses [TranscribeStorage].
  @visibleForTesting
  static Future<Directory> Function()? appDirProvider;

  /// Purpose: Resolve the app data directory honoring the test override.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Passed to the adapter
  /// as a tear-off so swapping [appDirProvider] between tests still takes
  /// effect on the already-built engine.
  static Future<Directory> _getAppDir() {
    final provider = appDirProvider;
    if (provider != null) return provider();
    return TranscribeStorage.getAppDir();
  }

  /// Data module identifiers used for per-module restore.
  ///
  /// Derived from the app registry — the file name and module id are written
  /// down once, in `lib/app/data_modules.dart`.
  static final Map<String, String> modules = {
    for (final module in transcribeModuleRegistry.modules)
      module.fileName: module.moduleId,
  };

  /// Lazily-built engine backing every static entry point.
  static final shared.BackupEngine _engine = shared.BackupEngine(
    storage: TranscribeStorageAdapter(appDir: _getAppDir),
    modules: transcribeModuleRegistry,
    defaultRemotePath: transcribeDefaultRemotePath,
  );

  /// Whether a backup is taken automatically once per day.
  static bool get autoBackupEnabled => _engine.autoBackupEnabled;

  static set autoBackupEnabled(bool value) => _engine.autoBackupEnabled = value;

  /// Days to keep backups; 0 keeps them forever.
  static int get retentionDays => _engine.retentionDays;

  static set retentionDays(int value) => _engine.retentionDays = value;

  /// Purpose: Load backup settings from `storage_config.json`.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Populates [autoBackupEnabled] and [retentionDays].
  /// Notes: Keys are the series-wide `autoBackupEnabled` and
  /// `backupRetentionDays`.
  static Future<void> loadSettings() => _engine.loadSettings();

  /// Purpose: Persist backup settings to `storage_config.json`.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Writes the storage config, preserving unrelated keys.
  /// Notes: None.
  static Future<void> saveSettings() => _engine.saveSettings();

  /// Purpose: Create a v2 backup bundle.
  /// Inputs: None.
  /// Returns: `Future<File?>` — the bundle, or null on failure.
  /// Side effects: Writes the bundle, then runs retention cleanup.
  /// Notes: None.
  ///
  /// The transcripts projection is rebuilt first, so a bundle taken straight
  /// after a correction carries it.
  static Future<File?> createBackup() async {
    await TranscriptSyncService.writeProjection();
    return _engine.createBackup();
  }

  /// Purpose: Take the once-per-day automatic backup when it is due.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: May create a backup.
  /// Notes: No-op when [autoBackupEnabled] is false; re-entrancy guarded, and
  /// "already backed up today" is decided by scanning bundle file names.
  static Future<void> runAutoBackupIfNeeded() async {
    // Cheap when nothing has changed: the projection keeps a dirty flag, so the
    // daily check costs one file-exists test on a quiet day.
    await TranscriptSyncService.writeProjection();
    await _engine.runAutoBackupIfNeeded();
  }

  /// Purpose: List backups, newest first.
  /// Inputs: None.
  /// Returns: `Future<List<BackupInfo>>`.
  /// Side effects: Reads the backups directory and probes small bundles.
  /// Notes: Unparseable bundles are flagged `corrupt`, never hidden.
  static Future<List<shared.BackupInfo>> listBackups() => _engine.listBackups();

  /// Purpose: List the module ids a bundle contains.
  /// Inputs: `file` bundle.
  /// Returns: `Future<List<String>>`; empty when unparseable.
  /// Side effects: Reads the bundle.
  /// Notes: Drives the per-module restore checkboxes.
  static Future<List<String>> getBackupModules(File file) =>
      _engine.getBackupModules(file);

  /// Purpose: Restore from a backup file, optionally only specific modules.
  /// Inputs: `file`, `moduleKeys`.
  /// Returns: `Future<RestoreResult>` describing success and whether any file
  /// was written.
  /// Side effects: Overwrites app data files atomically.
  /// Notes: Every selected payload is validated before anything is written,
  /// and WebDAV auto-sync is disabled before the first write, re-enabled only
  /// when the restore failed without writing (I5).
  ///
  /// The transcriptions a bundle carries are written into the job folders
  /// afterwards, **additively**. A bundle says what it held when it was taken,
  /// not what the user has deleted since, so nothing local is removed because
  /// it is missing from one.
  static Future<shared.RestoreResult> restoreBackup(
    File file, {
    Set<String>? moduleKeys,
  }) async {
    final before = await TranscriptSyncService.readProjectionFile();
    final result = await _engine.restoreBackup(file, moduleKeys: moduleKeys);
    final wanted =
        moduleKeys == null || moduleKeys.contains(transcriptsModuleId);
    if (result.ok && result.wroteAnything && wanted) {
      final after = await TranscriptSyncService.readProjectionFile();
      if (after != null && after != before) {
        await TranscriptSyncService.apply(
          before: before,
          after: after,
          allowDeletions: false,
        );
      }
    }
    return result;
  }

  /// Purpose: Delete one backup bundle.
  /// Inputs: `file`.
  /// Returns: `Future<void>`.
  /// Side effects: Removes the bundle.
  /// Notes: None.
  static Future<void> deleteBackup(File file) => _engine.deleteBackup(file);
}
