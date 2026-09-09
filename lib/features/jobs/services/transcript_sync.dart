/// Purpose: Turn the job folders into one syncable file, and turn a synced file
/// back into job folders.
/// Inputs: The `jobs/` directory, through the storage hub.
/// Returns: The projection, and what applying one changed.
/// Side effects: Reads and writes `transcribe_transcripts.json` and the job
/// folders.
/// Notes: The sync, backup and ZIP engines only ever touch the file names in
/// the module registry, and a job folder can never be one — it holds hours of
/// audio. This is the adapter: the small half of each folder is projected into
/// a module file before the engine runs, and whatever the engine produced is
/// applied back afterwards. `jobs/` stays the app's source of truth; the module
/// file is a transport artefact.
///
/// Three rules keep that from losing data, and each exists because of a way it
/// otherwise would:
///
/// * **Freeze.** A job that is not finished but was in the previous projection
///   — a re-run in progress — is carried forward from that file unchanged.
///   Otherwise its disappearance would read as a deletion, and the other device
///   would delete the whole folder, audio included, while its owner watched it
///   re-run.
/// * **Deletions only from the three-way merge.** Apply removes a job only when
///   the base snapshot proves it was deleted: it was in the projection written
///   before the engine ran and is not in what came back. A force download, a
///   backup restore and a ZIP import are additive, because none of them has a
///   base to prove anything with.
/// * **Never project a gap.** A `job.json` that exists but cannot be read is an
///   error, not an absence. Writing the projection without it would tell the
///   other device that the user had deleted it.
///
/// See `doc/en-us/sync.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart' show atomicWriteString;
import 'package:path/path.dart' as p;

import '../../../app/data_modules.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../../../shared/utils/file_retry.dart';
import '../../transcript/services/transcript_store.dart';
import '../models/transcription_job.dart';
import '../models/transcripts_document.dart';
import 'job_store.dart';

/// What applying a synced document did to the job folders.
class TranscriptApplyOutcome {
  /// Transcription ids written or created.
  final List<String> written;

  /// Transcription ids whose folders were removed.
  final List<String> deletedIds;

  /// Transcription ids left alone, with the reason attached.
  final List<String> skipped;

  /// Things worth telling the user without failing the sync.
  final List<String> warnings;

  /// Purpose: Create an apply outcome.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptApplyOutcome({
    this.written = const [],
    this.deletedIds = const [],
    this.skipped = const [],
    this.warnings = const [],
  });

  /// Whether anything on disk actually moved.
  bool get changedAnything => written.isNotEmpty || deletedIds.isNotEmpty;
}

/// Projects `jobs/` into the transcripts module, and applies it back.
class TranscriptSyncService {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the stores' shape.
  TranscriptSyncService._();

  /// Whether anything has changed since the projection was last written.
  ///
  /// A rebuild reads every job folder, and the daily backup check runs whether
  /// or not anything happened. This makes the common case — nothing changed —
  /// cost one file-exists check.
  static bool _dirty = true;

  /// Purpose: Say that a transcription changed and the projection is stale.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Sets a flag.
  /// Notes: Called wherever a job record or a transcript is written by the
  /// user or the runner — never by the apply step, which would make the sync
  /// chase its own tail.
  static void markDirty() => _dirty = true;

  /// Purpose: Build the projection from the job folders.
  /// Inputs: The [jobsDir] to read, and the [previous] projection if any.
  /// Returns: The document.
  /// Side effects: Reads every job folder.
  /// Notes: Only finished transcriptions with a readable transcript are
  /// projected fresh; the freeze rule carries the rest forward. A file that
  /// exists but cannot be read throws, because the alternative is telling the
  /// other device that the user deleted it.
  static Future<TranscriptsDocument> buildProjection({
    required Directory jobsDir,
    required TranscriptsDocument? previous,
  }) async {
    if (!await jobsDir.exists()) {
      return TranscriptsDocument(extraJson: previous?.extraJson ?? const {});
    }

    final records = <TranscriptSyncRecord>[];
    await for (final entry in jobsDir.list()) {
      if (entry is! Directory) continue;
      final id = p.basename(entry.path);
      if (!TranscriptSyncRecord.isSafeId(id)) continue;

      final job = await JobStore.loadRaw(id);
      if (job == null) {
        // No record at all: a folder being created, or one being deleted.
        // Carrying a previous entry forward would resurrect it; omitting a job
        // that was never projected changes nothing.
        if (previous?.byId(id) case final frozen?) records.add(frozen);
        continue;
      }

      final stage = JobStage.parse(job['stage']);
      final transcript = stage == JobStage.done
          ? await TranscriptStore.loadRaw(id)
          : null;

      if (stage == JobStage.done && transcript != null) {
        final jobModified = _time(job['modifiedAt']);
        final edited = _time(transcript['editedAt']);
        records.add(
          TranscriptSyncRecord(
            id: id,
            createdAt: _time(job['createdAt']),
            modifiedAt: edited.isAfter(jobModified) ? edited : jobModified,
            job: job,
            transcript: transcript,
            extraJson: previous?.byId(id)?.extraJson ?? const {},
          ),
        );
        continue;
      }

      // The freeze rule.
      if (previous?.byId(id) case final frozen?) records.add(frozen);
    }

    return TranscriptsDocument(
      records: records,
      extraJson: previous?.extraJson ?? const {},
    );
  }

  /// Purpose: Write the projection where the engine will find it.
  /// Inputs: None.
  /// Returns: The file's content before and after this call.
  /// Side effects: Reads the job folders; may write the module file.
  /// Notes: `before` is what the engine will treat as this device's side, and
  /// it is also what the apply step compares against to find deletions. The
  /// write is skipped when nothing changed, so the engine's raw-equality fast
  /// path still sees an untouched file. The app directory is resolved once:
  /// a storage-path change between two lookups would project one folder and
  /// write into another.
  static Future<({String? before, String after})> writeProjection() async {
    final appDir = await TranscribeStorage.getAppDir();
    final file = File(p.join(appDir.path, transcriptsDataFileName));
    final jobsDir = Directory(p.join(appDir.path, jobsDirName));

    final exists = await file.exists();
    final before = exists
        ? await retryingFileOperation(file.readAsString)
        : null;

    if (!_dirty && before != null) return (before: before, after: before);

    final previous = before == null ? null : _parse(before);
    final projection = await buildProjection(
      jobsDir: jobsDir,
      previous: previous,
    );
    final after = encodeTranscripts(projection);

    if (after != before) {
      await retryingFileOperation(() => atomicWriteString(file, after));
    }
    _dirty = false;
    return (before: before, after: after);
  }

  /// Purpose: Read the module file as the engine left it.
  /// Inputs: None.
  /// Returns: The content, or null when the file is not there.
  /// Side effects: Reads the file.
  /// Notes: Called after the engine has run, to see whether it changed
  /// anything worth applying.
  static Future<String?> readProjectionFile() async {
    final appDir = await TranscribeStorage.getAppDir();
    final file = File(p.join(appDir.path, transcriptsDataFileName));
    if (!await file.exists()) return null;
    return retryingFileOperation(file.readAsString);
  }

  /// Purpose: Write a synced document back into the job folders.
  /// Inputs: The projection [before] the engine ran, the document [after] it,
  /// and whether deletions may be honoured.
  /// Returns: What changed.
  /// Side effects: Writes and deletes job folders; bumps the store's notifier.
  /// Notes: Every write is quiet and raw. A job the runner is holding is never
  /// touched. A job absent locally is created only when it was **not** in the
  /// pre-sync projection — one deleted while the sync was in flight must not
  /// come back. When [allowDeletions] is false, nothing is removed at all: a
  /// force download, a restore and an import have no base snapshot, so an
  /// absence there means "this copy does not have it", not "somebody deleted
  /// it".
  static Future<TranscriptApplyOutcome> apply({
    required String? before,
    required String after,
    required bool allowDeletions,
  }) async {
    final incoming = _parse(after);
    final preIds = before == null ? <String>{} : _parse(before).ids;

    final written = <String>[];
    final skipped = <String>[];
    final warnings = <String>[];

    for (final record in incoming.records) {
      if (!TranscriptSyncRecord.isSafeId(record.id)) {
        warnings.add('Skipped a transcription with an unusable id.');
        continue;
      }

      final local = await JobStore.load(record.id);
      if (local != null &&
          (local.stage.isRunning || local.stage == JobStage.queued)) {
        // The runner owns this folder right now and is about to write it.
        skipped.add(record.id);
        continue;
      }

      if (local == null) {
        if (preIds.contains(record.id)) {
          // It was here when the sync started and is not now: deleted locally
          // while the sync was in flight. Do not bring it back.
          skipped.add(record.id);
          continue;
        }
      } else if (!record.modifiedAt.isAfter(await _localModified(local.id))) {
        continue;
      }

      try {
        await JobStore.saveRawQuiet(record.id, record.job);
        await TranscriptStore.saveRawQuiet(record.id, record.transcript);
        written.add(record.id);
      } catch (error) {
        warnings.add('Could not write ${record.displayName}: $error');
      }
    }

    final deleted = <String>[];
    if (allowDeletions) {
      for (final id in preIds.difference(incoming.ids)) {
        if (!TranscriptSyncRecord.isSafeId(id)) continue;
        final local = await JobStore.load(id);
        if (local != null &&
            (local.stage.isRunning || local.stage == JobStage.queued)) {
          skipped.add(id);
          continue;
        }
        try {
          await JobStore.delete(id);
          deleted.add(id);
        } catch (error) {
          warnings.add('Could not remove a transcription: $error');
        }
      }
    }

    final outcome = TranscriptApplyOutcome(
      written: written,
      deletedIds: deleted,
      skipped: skipped,
      warnings: warnings,
    );
    if (outcome.changedAnything) {
      // The projection on disk is now behind the folders again.
      markDirty();
      JobStore.notifyChangedOutsideRunner();
    }
    return outcome;
  }

  /// Purpose: Parse a projection, treating an unreadable one as empty.
  /// Inputs: The [json].
  /// Returns: The document.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A file this build
  /// cannot parse at all is treated as holding nothing, which is safe: apply
  /// writes nothing, and the deletion set is computed from the same value.
  static TranscriptsDocument _parse(String json) {
    try {
      return TranscriptsDocument.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
    } catch (_) {
      return const TranscriptsDocument();
    }
  }

  /// Purpose: Say when a local transcription was last touched.
  /// Inputs: The [jobId].
  /// Returns: The later of its record time and its transcript's edit time.
  /// Side effects: Reads both files.
  /// Notes: Internal helper used within this file only. Computed exactly the
  /// way the projection computes it. The record does not move when a speaker is
  /// renamed, so comparing it alone would let an older remote copy overwrite a
  /// correction the user had just made.
  static Future<DateTime> _localModified(String jobId) async {
    final job = await JobStore.loadRaw(jobId);
    final transcript = await TranscriptStore.loadRaw(jobId);
    final recorded = _time(job?['modifiedAt']);
    final edited = _time(transcript?['editedAt']);
    return edited.isAfter(recorded) ? edited : recorded;
  }
}

/// Purpose: Read a timestamp that may be missing or malformed.
/// Inputs: [value].
/// Returns: The UTC time, or the epoch.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
DateTime _time(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
