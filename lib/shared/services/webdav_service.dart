/// Purpose: MyTranscribe's WebDAV sync API, a thin facade over the shared
/// `WebDavSyncEngine` from the `myapps_data` package.
/// Inputs: `WebDAVConfig` values from the config page and auto-sync service.
/// Returns: App-typed `SyncResult`/`PendingSync` values.
/// Side effects: Delegates all local and remote I/O to the shared engine.
/// Notes: The shape mirrors MyAnime's facade so the WebDAV config page and
/// conflict dialog can be ported with the type names unchanged. Behavior
/// changes belong in the package, not here.
library;

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:myapps_data/myapps_data.dart' show SyncProgress;

import '../../app/data_modules.dart';
import '../../features/providers/models/transcribe_settings.dart';
import '../../features/secrets/services/secrets_sync_service.dart';
import 'sync_merge.dart';
import 'transcribe_storage.dart';

// The config and transport value types are the package's. They are
// re-exported under their original names so call sites import one file.
export 'package:myapps_data/myapps_data.dart'
    show WebDAVConfig, WebDAVUploadLock, RemoteFile, RemoteFileStatus;

/// Result of a sync operation.
class SyncResult {
  /// Whether the operation completed without a fatal or per-file error.
  final bool success;

  /// Error text shown to the user when [success] is false.
  final String? error;

  /// Unresolved conflicts awaiting the conflict dialog.
  final PendingSync? pending;

  /// Non-fatal warnings collected during sync.
  final List<String> warnings;

  /// What became of the API keys, which travel separately and only to an
  /// address they may safely travel to.
  final SecretsSyncOutcome? secrets;

  /// Purpose: Create a sync result instance.
  /// Inputs: `success`, `error`, `pending`, `warnings`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
    this.secrets,
  });

  /// Purpose: Report whether the result carries unresolved conflicts.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => pending != null;

  /// Purpose: Attach the keys outcome to a finished sync.
  /// Inputs: [outcome].
  /// Returns: A new [SyncResult].
  /// Side effects: None.
  /// Notes: The keys are exchanged after the engine returns, so the result has
  /// to be built twice; nothing else about it changes.
  SyncResult withSecrets(SecretsSyncOutcome outcome) => SyncResult(
    success: success,
    error: error,
    pending: pending,
    warnings: warnings,
    secrets: outcome,
  );
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  /// The app-typed merge result the conflict dialog reads.
  final SettingsMergeResult? settingsMerge;

  /// Engine-side pending state used to finalize under a fresh remote lock.
  ///
  /// Kept private to callers: the UI only ever passes a `PendingSync` straight
  /// back to [WebDAVService.finalizePendingSync].
  final shared.EnginePendingSync? enginePending;

  /// Purpose: Create a pending sync instance.
  /// Inputs: `settingsMerge`, `enginePending`.
  /// Returns: A new `PendingSync` instance.
  /// Side effects: None.
  /// Notes: `enginePending` is null only for values built by test code.
  const PendingSync({this.settingsMerge, this.enginePending});

  /// Purpose: List every record conflict across modules.
  /// Inputs: None.
  /// Returns: `List<RecordConflict<SettingsRecord>>`.
  /// Side effects: None.
  /// Notes: One module today; the list shape leaves room for more.
  List<RecordConflict<SettingsRecord>> get allConflicts => [
    ...?settingsMerge?.conflicts,
  ];
}

/// WebDAV sync facade over the shared engine.
class WebDAVService {
  /// Lazily-built engine shared by every static entry point.
  ///
  /// One long-lived instance preserves the in-flight guard, the sticky
  /// local-data-changed flag, and the progress notifier identity.
  static final shared.WebDavSyncEngine _engine = shared.WebDavSyncEngine(
    storage: const TranscribeStorageAdapter(),
    modules: transcribeModuleRegistry,
    defaultRemotePath: transcribeDefaultRemotePath,
  );

  /// Live sync progress for the config page's progress bar.
  static ValueNotifier<SyncProgress> get progress => _engine.progress;

  /// Purpose: Read and clear the "local data changed" signal.
  /// Inputs: None.
  /// Returns: `bool` — whether sync wrote local data.
  /// Side effects: Resets the flag.
  /// Notes: Open pages call this to decide whether to reload from disk.
  static bool consumeLocalDataChanged() => _engine.consumeLocalDataChanged();

  /// Purpose: Load the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<WebDAVConfig?>` — null when absent or unreadable.
  /// Side effects: Reads `webdav_config.json`.
  /// Notes: A missing `remotePath` defaults to `/MyTranscribe`.
  static Future<shared.WebDAVConfig?> loadConfig() => _engine.loadConfig();

  /// Purpose: Save the WebDAV configuration.
  /// Inputs: `config`.
  /// Returns: `Future<void>`.
  /// Side effects: Atomically writes `webdav_config.json`.
  /// Notes: Credentials are stored as the package stores them.
  static Future<void> saveConfig(shared.WebDAVConfig config) =>
      _engine.saveConfig(config);

  /// Purpose: Delete the saved WebDAV configuration.
  /// Inputs: None.
  /// Returns: `Future<void>`.
  /// Side effects: Removes `webdav_config.json` when present.
  /// Notes: Base snapshots and the client ID are intentionally left in place.
  static Future<void> deleteConfig() => _engine.deleteConfig();

  /// Purpose: Check that the server is reachable with these credentials.
  /// Inputs: `config`, possibly unsaved values from the config page.
  /// Returns: `Future<bool>` — true for HTTP 207 or 404.
  /// Side effects: Issues one PROPFIND.
  /// Notes: 404 counts as reachable because the collection may not exist yet.
  static Future<bool> testConnection(shared.WebDAVConfig config) =>
      _engine.testConnection(config);

  /// Purpose: Run a full two-way sync under the remote upload lock.
  /// Inputs: `config`, `autoResolve` (false everywhere in production, I4).
  /// Returns: `Future<SyncResult>`, carrying `PendingSync` on true conflicts.
  /// Side effects: Local and remote data/lock I/O; updates [progress].
  /// Notes: Conflicts are never silently auto-resolved.
  static Future<SyncResult> sync(
    shared.WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    final result = _toSyncResult(
      await _engine.sync(config, autoResolve: autoResolve),
    );
    return result.withSecrets(await _exchangeSecrets(config));
  }

  /// Purpose: Finalize sync by applying the user's conflict resolutions.
  /// Inputs: `config`, `pending`, `resolutions` (record ID → chosen record).
  /// Returns: `Future<bool>` — false when applying or uploading fails.
  /// Side effects: Reacquires the remote lock, writes local data, uploads.
  /// Notes: The base snapshot is only saved after a successful upload under
  /// the held remote `.lock`.
  static Future<bool> finalizePendingSync(
    shared.WebDAVConfig config,
    PendingSync pending,
    Map<String, SettingsRecord> resolutions,
  ) async {
    final enginePending = pending.enginePending;
    if (enginePending == null) return false;
    return _engine.finalizePendingSync(config, enginePending, {
      settingsModuleId: resolutions,
    });
  }

  /// Purpose: Overwrite remote data with local data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites remote files, saves base snapshots, publishes
  /// progress.
  /// Notes: Remote changes since the last sync are lost. Runs under the remote
  /// `.lock` and the in-flight guard, like a normal sync.
  static Future<SyncResult> forceUpload(shared.WebDAVConfig config) async {
    final result = _toSyncResult(await _engine.forceUpload(config));
    return result.withSecrets(await _exchangeSecrets(config));
  }

  /// Purpose: Overwrite local data with remote data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Replaces local data files and base snapshots.
  /// Notes: Local changes since the last sync are lost.
  static Future<SyncResult> forceDownload(shared.WebDAVConfig config) async {
    final result = _toSyncResult(await _engine.forceDownload(config));
    return result.withSecrets(await _exchangeSecrets(config));
  }

  /// Purpose: Exchange the API keys after a sync, when the address allows it.
  /// Inputs: The `config` just synced with.
  /// Returns: What became of the keys.
  /// Side effects: One GET and possibly one PUT; may rewrite the keys file.
  /// Notes: After the engine returns rather than inside it: the engine lock
  /// guards three-way merges against a base snapshot, and the keys file is a
  /// flat per-source map with a conditional PUT, so it needs neither. Every
  /// entry point calls this, including auto-sync, so a key set on one device
  /// reaches the other without anybody pressing anything.
  static Future<SecretsSyncOutcome> _exchangeSecrets(
    shared.WebDAVConfig config,
  ) async => SecretsSyncService.exchange(
    config,
    trustedHosts: await TranscribeStorage.getSecretsTrustedHosts(),
  );

  /// Purpose: Convert an engine result into the app-typed result.
  /// Inputs: `result` from the shared engine.
  /// Returns: `SyncResult` with the app's `PendingSync` shape rebuilt.
  /// Side effects: None.
  /// Notes: The engine carries the app's `SettingsMergeResult` through as
  /// opaque `state`, so the conflict dialog receives real `SettingsRecord`s.
  static SyncResult _toSyncResult(shared.EngineSyncResult result) {
    final pending = result.pending;
    return SyncResult(
      success: result.success,
      error: result.error,
      warnings: result.warnings,
      pending: pending == null
          ? null
          : PendingSync(
              settingsMerge:
                  pending.forModuleId(settingsModuleId)?.state
                      as SettingsMergeResult?,
              enginePending: pending,
            ),
    );
  }
}
