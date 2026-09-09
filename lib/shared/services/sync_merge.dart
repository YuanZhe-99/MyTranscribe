import 'dart:convert';

import 'package:myapps_data/myapps_data.dart';

import '../../features/jobs/models/transcripts_document.dart';
import '../../features/providers/models/transcribe_settings.dart';

// ─── Generic record merge ───────────────────────────────────────────
//
// `mergeRecords<T>`, `RecordConflict<T>`, and `RecordMergeResult<T>` live in
// the shared package. They are re-exported here so the conflict dialog and the
// tests import one file for everything merge-related.
export 'package:myapps_data/myapps_data.dart'
    show RecordConflict, RecordMergeResult, mergeRecords;

// ─── Settings-specific merge ────────────────────────────────────────

/// Result of merging the settings document with possible per-record conflicts.
class SettingsMergeResult {
  /// Records that merged without needing a decision.
  final List<SettingsRecord> merged;

  /// Records both devices changed differently since the last sync.
  final List<RecordConflict<SettingsRecord>> conflicts;

  /// Top-level document fields written by a build neither side understands.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a settings merge result instance.
  /// Inputs: `merged`, `conflicts`, `extraJson`.
  /// Returns: A new `SettingsMergeResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const SettingsMergeResult({
    required this.merged,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Report whether any record needs a manual decision.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build the final merged document from conflict resolutions.
  /// Inputs: `resolutions` — each conflicting record id mapped to the chosen
  /// record.
  /// Returns: `TranscribeSettings`.
  /// Side effects: None.
  /// Notes: A conflict without a resolution keeps the local record, the same
  /// fallback the sibling apps use. The chosen record still absorbs the other
  /// side's unknown fields, so losing a conflict never deletes a field a newer
  /// build wrote.
  TranscribeSettings buildResolved(Map<String, SettingsRecord> resolutions) {
    final all = <SettingsRecord>[...merged];
    for (final c in conflicts) {
      final chosen = resolutions[c.id] ?? c.localRecord;
      final other = identical(chosen, c.localRecord)
          ? c.remoteRecord
          : c.localRecord;
      all.add(chosen.withPreservedUnknownJson(other));
    }
    return TranscribeSettings(records: all, extraJson: extraJson);
  }
}

/// Purpose: Name a settings record for the conflict dialog.
/// Inputs: `record`.
/// Returns: `String` — the source or model name, else the record id.
/// Side effects: None.
/// Notes: Nonlocalized on purpose: the name the user typed is what tells two
/// sources apart, and a record this build cannot interpret still has an id.
String settingsRecordDisplayName(SettingsRecord record) {
  final payload = record.payload;
  final name = payload['name'] ?? payload['displayName'];
  if (name is String && name.trim().isNotEmpty) return name.trim();
  return record.id;
}

/// Purpose: Merge local, remote, and base settings JSON into one
/// conflict-aware result.
/// Inputs: `localJson`, `remoteJson`, `baseJson`, `autoResolve`.
/// Returns: `SettingsMergeResult`.
/// Side effects: None.
/// Notes: Preserves unknown JSON fields on both the records and the top-level
/// document while delegating per-record decisions to `mergeRecords`. Records
/// are keyed by `SettingsRecord.id` and compared by `modifiedAt`, which is why
/// every edit goes through `SettingsRecord.touch`. Deletions are read from the
/// base snapshot rather than from tombstones: a record present in the base and
/// absent locally is a deletion this device made, and it propagates.
SettingsMergeResult mergeSettingsData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final localData = TranscribeSettings.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remoteData = TranscribeSettings.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final baseData = baseJson != null
      ? TranscribeSettings.fromJson(
          jsonDecode(baseJson) as Map<String, dynamic>,
        )
      : null;
  final localMap = {for (final r in localData.records) r.id: r};
  final remoteMap = {for (final r in remoteData.records) r.id: r};

  final result = mergeRecords<SettingsRecord>(
    local: localData.records,
    remote: remoteData.records,
    base: baseData?.records,
    getId: (r) => r.id,
    getModifiedAt: (r) => r.modifiedAt,
    getDisplayName: settingsRecordDisplayName,
    autoResolve: autoResolve,
    // What the record *says*, not when it was said. The engine uses this to
    // suppress a conflict when both sides ended up with the same content, and
    // including `modifiedAt` would defeat that: two devices that both renamed
    // a source to the same thing, a minute apart, would be asked to choose
    // between two identical configurations. Unknown fields are left out for
    // the same reason — the merge preserves both sides' anyway.
    serialize: (r) =>
        jsonEncode({'id': r.id, 'kind': r.kind.name, 'payload': r.payload}),
  );

  final merged = [
    for (final record in result.merged)
      record.withPreservedUnknownJson(
        identical(localMap[record.id], record)
            ? remoteMap[record.id]
            : localMap[record.id],
      ),
  ];

  return SettingsMergeResult(
    merged: merged,
    conflicts: result.conflicts,
    extraJson: {...remoteData.extraJson, ...localData.extraJson},
  );
}

// ─── Transcripts-specific merge ─────────────────────────────────────

/// Result of merging the transcripts projection with possible conflicts.
class TranscriptsMergeResult {
  /// Transcriptions that merged without needing a decision.
  final List<TranscriptSyncRecord> merged;

  /// Transcriptions both devices changed differently since the last sync.
  final List<RecordConflict<TranscriptSyncRecord>> conflicts;

  /// Top-level document fields written by a build neither side understands.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a transcripts merge result.
  /// Inputs: `merged`, `conflicts`, `extraJson`.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const TranscriptsMergeResult({
    required this.merged,
    this.conflicts = const [],
    this.extraJson = const {},
  });

  /// Purpose: Report whether any transcription needs a manual decision.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get hasConflicts => conflicts.isNotEmpty;

  /// Purpose: Build the final document from conflict resolutions.
  /// Inputs: `resolutions` — each conflicting id mapped to the chosen record.
  /// Returns: `TranscriptsDocument`.
  /// Side effects: None.
  /// Notes: A conflict without a resolution keeps the local record, the same
  /// fallback the settings merge uses.
  TranscriptsDocument buildResolved(
    Map<String, TranscriptSyncRecord> resolutions,
  ) {
    final all = <TranscriptSyncRecord>[...merged];
    for (final conflict in conflicts) {
      final chosen = resolutions[conflict.id] ?? conflict.localRecord;
      final other = identical(chosen, conflict.localRecord)
          ? conflict.remoteRecord
          : conflict.localRecord;
      all.add(chosen.withPreservedUnknownJson(other));
    }
    return TranscriptsDocument(records: all, extraJson: extraJson);
  }
}

/// Purpose: Merge local, remote and base transcripts JSON into one
/// conflict-aware result.
/// Inputs: `localJson`, `remoteJson`, `baseJson`, `autoResolve`.
/// Returns: `TranscriptsMergeResult`.
/// Side effects: None.
/// Notes: The same shape as [mergeSettingsData], and deletions work the same
/// way: a transcription present in the base and absent locally is one this
/// device deleted, and it propagates. What is serialized for the
/// same-content check deliberately excludes **both** timestamps — the record's
/// own and the one inside `job`. Two devices that converged on the same
/// transcript must not be asked to choose between two identical copies just
/// because one of them wrote its record a minute later.
TranscriptsMergeResult mergeTranscriptsData(
  String localJson,
  String remoteJson,
  String? baseJson, {
  bool autoResolve = false,
}) {
  final localData = TranscriptsDocument.fromJson(
    jsonDecode(localJson) as Map<String, dynamic>,
  );
  final remoteData = TranscriptsDocument.fromJson(
    jsonDecode(remoteJson) as Map<String, dynamic>,
  );
  final baseData = baseJson != null
      ? TranscriptsDocument.fromJson(
          jsonDecode(baseJson) as Map<String, dynamic>,
        )
      : null;
  final localMap = {for (final r in localData.records) r.id: r};
  final remoteMap = {for (final r in remoteData.records) r.id: r};

  final result = mergeRecords<TranscriptSyncRecord>(
    local: localData.records,
    remote: remoteData.records,
    base: baseData?.records,
    getId: (r) => r.id,
    getModifiedAt: (r) => r.modifiedAt,
    getDisplayName: (r) => r.displayName,
    autoResolve: autoResolve,
    serialize: (r) => jsonEncode({
      'id': r.id,
      'job': {
        for (final entry in r.job.entries)
          if (entry.key != 'modifiedAt') entry.key: entry.value,
      },
      'transcript': r.transcript,
    }),
  );

  final merged = [
    for (final record in result.merged)
      record.withPreservedUnknownJson(
        identical(localMap[record.id], record)
            ? remoteMap[record.id]
            : localMap[record.id],
      ),
  ];

  return TranscriptsMergeResult(
    merged: merged,
    conflicts: result.conflicts,
    extraJson: {...remoteData.extraJson, ...localData.extraJson},
  );
}

// ─── One conflict, whichever module it came from ────────────────────

/// One side of a conflict, ready to be shown.
class SyncConflictSide {
  /// When this side was last changed.
  final DateTime modifiedAt;

  /// A few lines describing what this side holds.
  final List<String> lines;

  /// The record itself, handed back when the user picks this side.
  final Object record;

  /// Purpose: Create one side of a conflict.
  /// Inputs: [modifiedAt], [lines], [record].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SyncConflictSide({
    required this.modifiedAt,
    required this.lines,
    required this.record,
  });
}

/// One conflict the user has to decide, from any module.
class SyncConflictView {
  /// Which module the conflicting record belongs to.
  final String moduleId;

  /// The record id, used to key the resolution back to the module.
  final String id;

  /// What to call the thing in conflict.
  final String displayName;

  /// This device's version.
  final SyncConflictSide local;

  /// The server's version.
  final SyncConflictSide remote;

  /// Purpose: Create a conflict view.
  /// Inputs: [moduleId], [id], [displayName], [local], [remote].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: The dialog renders this rather than a `SettingsRecord`, so a second
  /// kind of record needed no second dialog. The chosen `record` is opaque; the
  /// caller sorts the choices back into per-module maps by [moduleId].
  const SyncConflictView({
    required this.moduleId,
    required this.id,
    required this.displayName,
    required this.local,
    required this.remote,
  });
}

/// Purpose: Describe a settings conflict for the dialog.
/// Inputs: The [conflict] and its [moduleId].
/// Returns: A [SyncConflictView].
/// Side effects: None.
/// Notes: The payload is an opaque map on purpose (see
/// `transcribe_settings.dart`), so this prints it rather than interpreting it —
/// which also means a record written by a newer build still shows the user
/// something they can choose between. Long values are cut so one differing
/// field stays visible; the API key is never in this map, so nothing secret can
/// be printed.
SyncConflictView settingsConflictView(
  String moduleId,
  RecordConflict<SettingsRecord> conflict,
) => SyncConflictView(
  moduleId: moduleId,
  id: conflict.id,
  displayName: conflict.displayName,
  local: _settingsSide(conflict.localRecord),
  remote: _settingsSide(conflict.remoteRecord),
);

/// Purpose: Describe a transcription conflict for the dialog.
/// Inputs: The [conflict] and its [moduleId].
/// Returns: A [SyncConflictView].
/// Side effects: None.
/// Notes: What tells two versions of one transcription apart is the speakers
/// and the line count, which is what the record's own summary gives.
SyncConflictView transcriptsConflictView(
  String moduleId,
  RecordConflict<TranscriptSyncRecord> conflict,
) => SyncConflictView(
  moduleId: moduleId,
  id: conflict.id,
  displayName: conflict.displayName,
  local: SyncConflictSide(
    modifiedAt: conflict.localRecord.modifiedAt,
    lines: conflict.localRecord.summaryLines,
    record: conflict.localRecord,
  ),
  remote: SyncConflictSide(
    modifiedAt: conflict.remoteRecord.modifiedAt,
    lines: conflict.remoteRecord.summaryLines,
    record: conflict.remoteRecord,
  ),
);

/// Purpose: Summarize one settings record's payload.
/// Inputs: The [record].
/// Returns: A few `field: value` lines.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
SyncConflictSide _settingsSide(SettingsRecord record) {
  final entries = record.payload.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return SyncConflictSide(
    modifiedAt: record.modifiedAt,
    lines: entries.isEmpty
        ? const ['—']
        : [
            for (final entry in entries.take(8))
              '${entry.key}: ${_shortValue(entry.value)}',
            if (entries.length > 8) '…',
          ],
    record: record,
  );
}

/// Purpose: Render one value on one line.
/// Inputs: The [value].
/// Returns: A short string.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _shortValue(Object? value) {
  final text = '$value'.replaceAll('\n', ' ');
  return text.length <= 48 ? text : '${text.substring(0, 47)}…';
}
