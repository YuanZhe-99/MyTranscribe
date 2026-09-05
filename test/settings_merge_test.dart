/// Purpose: Test the three-way merge of the settings document.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The cases that matter are the ones a user would notice: an edit made
/// on one device arriving on the other, a deletion propagating instead of
/// resurrecting, and two real edits raising a conflict rather than one quietly
/// winning. `autoResolve` stays false everywhere in production (invariant I4),
/// so the conflict path is the important one.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/providers/models/transcribe_settings.dart';
import 'package:my_transcribe/shared/services/sync_merge.dart';

/// Purpose: Build a settings document as JSON for a merge case.
/// Inputs: A list of `(id, modifiedAt, payload)` triples.
/// Returns: The encoded document.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String doc(List<(String, DateTime, Map<String, dynamic>)> records) =>
    encodeSettings(
      TranscribeSettings(
        records: [
          for (final (id, modified, payload) in records)
            SettingsRecord(
              id: id,
              kind: SettingsRecordKind.provider,
              createdAt: DateTime.utc(2026, 1, 1),
              modifiedAt: modified,
              payload: payload,
            ),
        ],
      ),
    );

void main() {
  final base = DateTime.utc(2026, 1, 1);
  final later = DateTime.utc(2026, 2, 1);
  final latest = DateTime.utc(2026, 3, 1);

  test('an edit on one device arrives on the other', () {
    final result = mergeSettingsData(
      doc([('provider:a', later, {'name': 'Local edit'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
    );
    expect(result.hasConflicts, isFalse);
    expect(result.merged.single.payload['name'], 'Local edit');
  });

  test('a remote edit wins when this device did not touch the record', () {
    final result = mergeSettingsData(
      doc([('provider:a', base, {'name': 'Original'})]),
      doc([('provider:a', later, {'name': 'Remote edit'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
    );
    expect(result.hasConflicts, isFalse);
    expect(result.merged.single.payload['name'], 'Remote edit');
  });

  test('a record added on one device is kept', () {
    final result = mergeSettingsData(
      doc([('provider:a', base, {}), ('provider:new', later, {})]),
      doc([('provider:a', base, {})]),
      doc([('provider:a', base, {})]),
    );
    expect(result.hasConflicts, isFalse);
    expect(result.merged.map((r) => r.id), containsAll(<String>[
      'provider:a',
      'provider:new',
    ]));
  });

  test('a deletion propagates instead of resurrecting', () {
    // Deleted here, untouched there: it must not come back on the next sync.
    final result = mergeSettingsData(
      doc([]),
      doc([('provider:a', base, {})]),
      doc([('provider:a', base, {})]),
    );
    expect(result.hasConflicts, isFalse);
    expect(result.merged, isEmpty);
  });

  test('a deletion loses to a real edit on the other device', () {
    final result = mergeSettingsData(
      doc([]),
      doc([('provider:a', later, {'name': 'Still wanted'})]),
      doc([('provider:a', base, {})]),
    );
    expect(result.merged.single.payload['name'], 'Still wanted');
  });

  test('two different edits raise a conflict rather than one winning', () {
    final result = mergeSettingsData(
      doc([('provider:a', later, {'name': 'Mine'})]),
      doc([('provider:a', latest, {'name': 'Theirs'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
    );
    expect(result.hasConflicts, isTrue);
    expect(result.conflicts.single.id, 'provider:a');
    // Named by what the user typed, so the dialog is readable.
    expect(result.conflicts.single.displayName, 'Mine');
  });

  test('the same edit on both devices is not a conflict', () {
    final result = mergeSettingsData(
      doc([('provider:a', later, {'name': 'Same'})]),
      doc([('provider:a', latest, {'name': 'Same'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
    );
    expect(result.hasConflicts, isFalse);
  });

  test('a resolution is applied, and an unanswered conflict keeps local', () {
    final result = mergeSettingsData(
      doc([('provider:a', later, {'name': 'Mine'})]),
      doc([('provider:a', latest, {'name': 'Theirs'})]),
      doc([('provider:a', base, {'name': 'Original'})]),
    );
    final conflict = result.conflicts.single;

    final chosenRemote = result.buildResolved({
      conflict.id: conflict.remoteRecord,
    });
    expect(chosenRemote.records.single.payload['name'], 'Theirs');

    final unanswered = result.buildResolved(const {});
    expect(unanswered.records.single.payload['name'], 'Mine');
  });

  test('unknown fields survive a merge', () {
    // An older build must never delete a field a newer one wrote.
    final localJson = jsonDecode(
      doc([('provider:a', later, {'name': 'Mine'})]),
    ) as Map<String, dynamic>;
    final remoteJson = jsonDecode(
      doc([('provider:a', base, {'name': 'Mine'})]),
    ) as Map<String, dynamic>;
    (remoteJson['records'] as List).single['futureField'] = 'keep me';

    final result = mergeSettingsData(
      jsonEncode(localJson),
      jsonEncode(remoteJson),
      jsonEncode(remoteJson),
    );
    expect(result.merged.single.extraJson['futureField'], 'keep me');
  });

  test('a record with no name falls back to its id in the dialog', () {
    final result = mergeSettingsData(
      doc([('provider:a', later, {'baseUrl': 'x'})]),
      doc([('provider:a', latest, {'baseUrl': 'y'})]),
      doc([('provider:a', base, {})]),
    );
    expect(result.conflicts.single.displayName, 'provider:a');
  });
}
