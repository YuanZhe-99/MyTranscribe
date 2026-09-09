/// Purpose: MyTranscribe's WebDAV sync API, a thin facade over the shared
/// `WebDavSyncEngine` from the `myapps_data` package.
/// Inputs: `WebDAVConfig` values from the config page and auto-sync service.
/// Returns: App-typed `SyncResult`/`PendingSync` values.
/// Side effects: Delegates all local and remote I/O to the shared engine.
/// Notes: The shape mirrors MyAnime's facade so the WebDAV config page and
/// conflict dialog can be ported with the type names unchanged. Behavior
/// changes belong in the package, not here.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:myapps_data/myapps_data.dart' show SyncProgress;

import '../../app/data_modules.dart';
import '../../features/jobs/models/transcripts_document.dart';
import '../../features/jobs/services/audio_sync_service.dart';
import '../../features/jobs/services/transcript_sync.dart';
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

  /// What became of the converted audio, which travels only when asked for.
  final AudioSyncOutcome? audio;

  /// Purpose: Create a sync result instance.
  /// Inputs: `success`, `error`, `pending`, `warnings`, `secrets`, `audio`.
  /// Returns: A new `SyncResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SyncResult({
    required this.success,
    this.error,
    this.pending,
    this.warnings = const [],
    this.secrets,
    this.audio,
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
    audio: audio,
  );

  /// Purpose: Attach the audio outcome to a finished sync.
  /// Inputs: [outcome].
  /// Returns: A new [SyncResult].
  /// Side effects: None.
  /// Notes: Its warnings join the sync's own, so a file that would not upload
  /// is reported where the user is already looking. A failure to move audio is
  /// never a failure of the sync: the transcript is what matters, and it is
  /// already on the server.
  SyncResult withAudio(AudioSyncOutcome outcome) => SyncResult(
    success: success,
    error: error,
    pending: pending,
    warnings: [...warnings, ...outcome.warnings],
    secrets: secrets,
    audio: outcome,
  );

  /// Purpose: Add the warnings the transcript apply step produced.
  /// Inputs: [extra].
  /// Returns: A new [SyncResult], or this one when there is nothing to add.
  /// Side effects: None.
  /// Notes: None.
  SyncResult withWarnings(List<String> extra) => extra.isEmpty
      ? this
      : SyncResult(
          success: success,
          error: error,
          pending: pending,
          warnings: [...warnings, ...extra],
          secrets: secrets,
          audio: audio,
        );
}

/// Holds pending merge results that contain per-record conflicts.
class PendingSync {
  /// The app-typed merge result the conflict dialog reads.
  final SettingsMergeResult? settingsMerge;

  /// The transcripts merge result, when a transcription conflicted.
  final TranscriptsMergeResult? transcriptsMerge;

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
  const PendingSync({
    this.settingsMerge,
    this.transcriptsMerge,
    this.enginePending,
  });

  /// Purpose: List every settings conflict.
  /// Inputs: None.
  /// Returns: `List<RecordConflict<SettingsRecord>>`.
  /// Side effects: None.
  /// Notes: Kept for callers that only care about settings records.
  List<RecordConflict<SettingsRecord>> get allConflicts => [
    ...?settingsMerge?.conflicts,
  ];

  /// Purpose: Describe every conflict the user has to decide, in order.
  /// Inputs: None.
  /// Returns: One view per conflict, settings first.
  /// Side effects: None.
  /// Notes: The dialog renders these rather than a record type, which is what
  /// let a second module arrive without a second dialog. Settings first because
  /// a source or a model is what a transcription depends on.
  List<SyncConflictView> get conflictViews => [
    for (final conflict in settingsMerge?.conflicts ?? const [])
      settingsConflictView(settingsModuleId, conflict),
    for (final conflict in transcriptsMerge?.conflicts ?? const [])
      transcriptsConflictView(transcriptsModuleId, conflict),
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
    // Read on every call rather than captured, so a test that installs a fake
    // server after this engine was built still gets it — and so production,
    // where nothing installs one, keeps the real client.
    clientFactory: (config) =>
        (clientFactory ?? shared.WebDavClient.new)(config),
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
  ///
  /// The transcripts module is a projection of `jobs/`, so the folders are
  /// projected into it before the engine runs and whatever the engine produced
  /// is applied back afterwards. Deletions are honoured here and only here: the
  /// pre-sync projection is the base that proves an absence was a deletion
  /// rather than a copy that never had it. A projection that cannot be built —
  /// a record locked or damaged — fails the sync before anything is sent,
  /// because a gap in it would read as the user deleting a transcription.
  static Future<SyncResult> sync(
    shared.WebDAVConfig config, {
    bool autoResolve = false,
  }) async {
    final ({String? before, String after}) projection;
    try {
      projection = await TranscriptSyncService.writeProjection();
    } catch (error) {
      return SyncResult(
        success: false,
        error: 'Could not read the transcriptions: $error',
      );
    }

    var result = _toSyncResult(
      await _engine.sync(config, autoResolve: autoResolve),
    );

    // Not while conflicts are outstanding: the engine leaves the file untouched
    // for a pending module, and finalizing is what will write it.
    final transcriptsPending =
        result.pending?.enginePending?.forModuleId(transcriptsModuleId) != null;
    final applied = await _applyTranscripts(
      before: projection.before,
      allowDeletions: result.success && !transcriptsPending,
      skip: transcriptsPending,
    );
    result = result.withWarnings(applied.warnings);

    result = result.withSecrets(await _exchangeSecrets(config));
    return result.withAudio(
      await _exchangeAudio(
        config,
        deletedIds: applied.deletedIds.toSet(),
        mode: AudioSyncMode.sync,
      ),
    );
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
    Map<String, SettingsRecord> resolutions, {
    Map<String, TranscriptSyncRecord> transcriptResolutions = const {},
  }) async {
    final enginePending = pending.enginePending;
    if (enginePending == null) return false;

    // What the engine is about to replace, and therefore the base that says
    // which transcriptions the merge dropped.
    final before = await TranscriptSyncService.readProjectionFile();

    final ok = await _engine.finalizePendingSync(config, enginePending, {
      settingsModuleId: resolutions,
      transcriptsModuleId: transcriptResolutions,
    });
    if (!ok) return false;

    final applied = await _applyTranscripts(
      before: before,
      allowDeletions: true,
      skip: false,
    );
    await _exchangeAudio(
      config,
      deletedIds: applied.deletedIds.toSet(),
      mode: AudioSyncMode.sync,
    );
    return true;
  }

  /// Purpose: Overwrite remote data with local data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Overwrites remote files, saves base snapshots, publishes
  /// progress.
  /// Notes: Remote changes since the last sync are lost. Runs under the remote
  /// `.lock` and the in-flight guard, like a normal sync.
  static Future<SyncResult> forceUpload(shared.WebDAVConfig config) async {
    try {
      await TranscriptSyncService.writeProjection();
    } catch (error) {
      return SyncResult(
        success: false,
        error: 'Could not read the transcriptions: $error',
      );
    }
    final result = _toSyncResult(
      await _engine.forceUpload(config),
    ).withSecrets(await _exchangeSecrets(config));
    return result.withAudio(
      await _exchangeAudio(config, mode: AudioSyncMode.uploadOnly),
    );
  }

  /// Purpose: Overwrite local data with remote data, without merging.
  /// Inputs: `config`.
  /// Returns: `Future<SyncResult>`.
  /// Side effects: Replaces local data files and base snapshots.
  /// Notes: Local changes since the last sync are lost — for the settings. The
  /// transcriptions are the exception: what comes down is written into `jobs/`,
  /// but nothing is **deleted**, because a force download has no base snapshot
  /// to tell "the server never had this" apart from "somebody deleted this".
  /// A transcription only this device has simply uploads again next time.
  static Future<SyncResult> forceDownload(shared.WebDAVConfig config) async {
    try {
      await TranscriptSyncService.writeProjection();
    } catch (error) {
      return SyncResult(
        success: false,
        error: 'Could not read the transcriptions: $error',
      );
    }
    var result = _toSyncResult(await _engine.forceDownload(config));
    final applied = await _applyTranscripts(
      before: null,
      allowDeletions: false,
      skip: false,
    );
    result = result
        .withWarnings(applied.warnings)
        .withSecrets(await _exchangeSecrets(config));
    return result.withAudio(
      await _exchangeAudio(config, mode: AudioSyncMode.downloadOnly),
    );
  }

  /// Purpose: Write whatever the engine produced back into the job folders.
  /// Inputs: The projection [before] the engine ran, whether deletions are
  /// allowed, and whether to [skip] the step entirely.
  /// Returns: What changed.
  /// Side effects: Writes and deletes job folders.
  /// Notes: Internal helper used within this file only. The file is re-read
  /// after the engine rather than trusted from before it, because that is the
  /// only way to see what the merge decided. Nothing is applied when it comes
  /// back unchanged, which is the common case.
  static Future<TranscriptApplyOutcome> _applyTranscripts({
    required String? before,
    required bool allowDeletions,
    required bool skip,
  }) async {
    if (skip) return const TranscriptApplyOutcome();
    try {
      final after = await TranscriptSyncService.readProjectionFile();
      if (after == null || after == before) {
        return const TranscriptApplyOutcome();
      }
      return await TranscriptSyncService.apply(
        before: before,
        after: after,
        allowDeletions: allowDeletions,
      );
    } catch (error) {
      return TranscriptApplyOutcome(
        warnings: ['Could not update the transcriptions: $error'],
      );
    }
  }

  /// Purpose: Exchange the converted audio after a sync, when asked to.
  /// Inputs: The [config], the ids the merge [deletedIds], and the [mode].
  /// Returns: What became of the audio.
  /// Side effects: Network I/O; may write `jobs/<id>/audio.mp3`.
  /// Notes: Internal helper used within this file only. It reads the projection
  /// as it now stands, so it moves audio for exactly the transcriptions both
  /// devices agree exist. Off by default, and then it sends no request at all.
  static Future<AudioSyncOutcome> _exchangeAudio(
    shared.WebDAVConfig config, {
    Set<String> deletedIds = const {},
    required AudioSyncMode mode,
  }) async {
    try {
      final json = await TranscriptSyncService.readProjectionFile();
      if (json == null) {
        return const AudioSyncOutcome(status: AudioSyncStatus.off);
      }
      return await AudioSyncService.exchange(
        config,
        document: TranscriptsDocument.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        ),
        deletedIds: deletedIds,
        mode: mode,
        clientFactory: clientFactory,
      );
    } catch (error) {
      return AudioSyncOutcome(
        status: AudioSyncStatus.failed,
        warnings: ['Could not sync the audio: $error'],
      );
    }
  }

  /// Builds the WebDAV client the side channels use, so tests can supply one.
  ///
  /// The engine has its own; these two exchanges run outside it.
  @visibleForTesting
  static shared.WebDavClient Function(shared.WebDAVConfig)? clientFactory;

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
    clientFactory: clientFactory,
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
              transcriptsMerge:
                  pending.forModuleId(transcriptsModuleId)?.state
                      as TranscriptsMergeResult?,
              enginePending: pending,
            ),
    );
  }
}
