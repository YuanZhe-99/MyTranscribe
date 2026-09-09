/// Purpose: Test the three-way merge of the transcripts projection.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The cases that matter are the ones a user would notice: a speaker
/// renamed on one device arriving on the other, a deleted transcription staying
/// deleted instead of resurrecting, and two real edits raising a conflict
/// rather than one quietly winning. `autoResolve` stays false everywhere in
/// production (invariant I4), so the conflict path is the important one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/jobs/models/transcripts_document.dart';
import 'package:my_transcribe/shared/services/sync_merge.dart';

/// Purpose: Build a projection document as JSON for a merge case.
/// Inputs: A list of `(id, modifiedAt, speakerName)` triples.
/// Returns: The encoded document.
/// Side effects: None.
/// Notes: Internal helper used within this file only. The speaker's name stands
/// in for "something the user changed in the viewer", which is the edit these
/// cases are about.
String doc(
  List<(String, DateTime, String)> records, {
  DateTime? jobModifiedAt,
}) => encodeTranscripts(
  TranscriptsDocument(
    records: [
      for (final (id, modified, speaker) in records)
        TranscriptSyncRecord(
          id: id,
          createdAt: DateTime.utc(2026, 9, 1),
          modifiedAt: modified,
          job: {
            'id': id,
            'title': 'Week 3',
            'stage': 'done',
            'modifiedAt': (jobModifiedAt ?? modified).toIso8601String(),
          },
          transcript: {
            'jobId': id,
            'speakers': [
              {'id': 'spk_1', 'name': speaker},
            ],
            'segments': [
              {'id': 'seg_0', 'text': 'hello'},
            ],
          },
        ),
    ],
  ),
);

void main() {
  final base = DateTime.utc(2026, 9, 5);
  final later = DateTime.utc(2026, 9, 9);

  group('merging transcriptions', () {
    test('a rename made on the other device arrives', () {
      final result = mergeTranscriptsData(
        doc([('job-1', base, 'Speaker 1')]),
        doc([('job-1', later, '张老师')]),
        doc([('job-1', base, 'Speaker 1')]),
      );

      expect(result.hasConflicts, isFalse);
      final speakers = result.merged.single.transcript['speakers'] as List;
      expect((speakers.single as Map)['name'], '张老师');
    });

    test('a transcription only the other device has is added', () {
      final result = mergeTranscriptsData(
        doc([('job-1', base, 'A')]),
        doc([('job-1', base, 'A'), ('job-2', base, 'B')]),
        doc([('job-1', base, 'A')]),
      );

      expect(result.hasConflicts, isFalse);
      expect(result.merged.map((r) => r.id), ['job-1', 'job-2']);
    });

    test('a deletion propagates instead of resurrecting', () {
      // The user deleted it here; the server still has it. The base proves this
      // was a deletion rather than a copy that never had it.
      final result = mergeTranscriptsData(
        doc([('job-1', base, 'A')]),
        doc([('job-1', base, 'A'), ('job-2', base, 'B')]),
        doc([('job-1', base, 'A'), ('job-2', base, 'B')]),
      );

      expect(result.hasConflicts, isFalse);
      expect(result.merged.map((r) => r.id), ['job-1']);
    });

    test('an edit beats a deletion, because the words are worth more', () {
      final result = mergeTranscriptsData(
        doc([('job-1', base, 'A')]),
        doc([('job-1', base, 'A'), ('job-2', later, '张老师')]),
        doc([('job-1', base, 'A'), ('job-2', base, 'B')]),
      );

      expect(result.merged.map((r) => r.id), containsAll(['job-1', 'job-2']));
    });

    test('two different edits raise a conflict naming the transcription', () {
      final result = mergeTranscriptsData(
        doc([('job-1', later, '张老师')]),
        doc([('job-1', later, '李同学')]),
        doc([('job-1', base, 'Speaker 1')]),
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.single.displayName, 'Week 3');
    });

    test('the same content is not a conflict, whatever the record says', () {
      // Both devices renamed the speaker to the same thing, a minute apart. If
      // the timestamps were part of the comparison, the user would be asked to
      // choose between two identical transcripts.
      final result = mergeTranscriptsData(
        doc([('job-1', later, '张老师')], jobModifiedAt: base),
        doc([
          ('job-1', DateTime.utc(2026, 9, 9, 0, 1), '张老师'),
        ], jobModifiedAt: later),
        doc([('job-1', base, 'Speaker 1')]),
      );

      expect(result.hasConflicts, isFalse);
    });

    test('a resolution is applied and the loser is not lost entirely', () {
      final result = mergeTranscriptsData(
        doc([('job-1', later, '张老师')]),
        doc([('job-1', later, '李同学')]),
        doc([('job-1', base, 'Speaker 1')]),
      );
      final chosen = result.conflicts.single.remoteRecord;
      final resolved = result.buildResolved({'job-1': chosen});

      final speakers = resolved.records.single.transcript['speakers'] as List;
      expect((speakers.single as Map)['name'], '李同学');
    });

    test('fields written by a newer build survive the merge', () {
      final local = TranscriptsDocument(
        records: [
          TranscriptSyncRecord(
            id: 'job-1',
            createdAt: base,
            modifiedAt: later,
            job: const {'stage': 'done', 'somethingNewer': 7},
            transcript: const {'jobId': 'job-1'},
            extraJson: const {'recordLevelNewer': 'x'},
          ),
        ],
        extraJson: const {'documentLevelNewer': true},
      );
      final result = mergeTranscriptsData(
        encodeTranscripts(local),
        doc([('job-1', base, 'A')]),
        doc([('job-1', base, 'A')]),
      );

      expect(result.merged.single.job['somethingNewer'], 7);
      expect(result.merged.single.extraJson['recordLevelNewer'], 'x');
      expect(result.extraJson['documentLevelNewer'], true);
    });
  });

  group('describing a conflict', () {
    test('says who is in it and how long it is', () {
      final result = mergeTranscriptsData(
        doc([('job-1', later, '张老师')]),
        doc([('job-1', later, '李同学')]),
        doc([('job-1', base, 'Speaker 1')]),
      );
      final view = transcriptsConflictView(
        transcriptsModuleId,
        result.conflicts.single,
      );

      expect(view.moduleId, transcriptsModuleId);
      expect(view.displayName, 'Week 3');
      expect(view.local.lines, contains('张老师'));
      expect(view.remote.lines, contains('李同学'));
      expect(view.local.lines, contains('1 lines'));
    });
  });
}
