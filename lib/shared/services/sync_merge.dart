import 'dart:convert';

import 'package:myapps_data/myapps_data.dart';

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
      ? TranscribeSettings.fromJson(jsonDecode(baseJson) as Map<String, dynamic>)
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
