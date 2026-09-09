/// Purpose: Test turning the job folders into the syncable projection, and
/// turning a synced projection back into job folders.
/// Inputs: None; a temporary app directory holds the folders.
/// Returns: None.
/// Side effects: Creates and deletes files under a temporary directory.
/// Notes: The load-bearing cases are the three rules that keep this from losing
/// somebody's recordings: a job being re-run must not read as a deletion, a job
/// deleted while a sync is in flight must not come back, and a record that
/// cannot be read must stop the projection rather than silently leave a gap in
/// it. Each of those, done wrong, deletes a folder on another device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/jobs/models/transcripts_document.dart';
import 'package:my_transcribe/features/jobs/services/job_store.dart';
import 'package:my_transcribe/features/jobs/services/transcript_sync.dart';
import 'package:my_transcribe/features/transcript/services/transcript_store.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A path provider that answers with one temporary directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_sync_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await TranscribeStorage.setStoragePath(null);
    TranscriptSyncService.markDirty();
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Write one job folder by hand.
  /// Inputs: The [id], the [stage], whether it has a [transcript], and when it
  /// was [modified].
  /// Returns: None.
  /// Side effects: Writes `job.json` and maybe `transcript.json`.
  /// Notes: Internal helper used within this file only. Raw maps rather than
  /// models, because raw maps are what the projection carries.
  Future<void> writeJob(
    String id, {
    String stage = 'done',
    bool transcript = true,
    DateTime? modified,
    String speaker = 'Speaker 1',
  }) async {
    final when = (modified ?? DateTime.utc(2026, 9, 5)).toIso8601String();
    await JobStore.saveRawQuiet(id, {
      'id': id,
      'createdAt': '2026-09-01T00:00:00.000Z',
      'modifiedAt': when,
      'stage': stage,
      'sourcePath': '/recordings/$id.mp3',
      'sourceName': '$id.mp3',
      'title': 'Lecture $id',
    });
    if (transcript) {
      await TranscriptStore.saveRawQuiet(id, {
        'jobId': id,
        'editedAt': when,
        'speakers': [
          {'id': 'spk_1', 'name': speaker},
        ],
        'segments': [
          {'id': 'seg_0', 'text': 'hello'},
        ],
      });
    }
  }

  /// Purpose: Read the projection from disk.
  /// Inputs: None.
  /// Returns: The document.
  /// Side effects: Reads the module file.
  /// Notes: Internal helper used within this file only.
  Future<TranscriptsDocument> projection() async {
    final json = await TranscriptSyncService.readProjectionFile();
    return TranscriptsDocument.fromJson(
      jsonDecode(json!) as Map<String, dynamic>,
    );
  }

  group('building the projection', () {
    test('carries finished transcriptions and nothing else', () async {
      await writeJob('job-done');
      await writeJob('job-running', stage: 'transcribing');
      await writeJob('job-notext', transcript: false);

      await TranscriptSyncService.writeProjection();
      expect((await projection()).ids, {'job-done'});
    });

    test('sorts by id, so two devices encode the same data alike', () async {
      await writeJob('b');
      await writeJob('a');

      final result = await TranscriptSyncService.writeProjection();
      expect(result.after.indexOf('"a"'), lessThan(result.after.indexOf('"b"')));
    });

    test('carries the whole record and transcript, untouched', () async {
      await writeJob('job-1', speaker: '张老师');
      await TranscriptSyncService.writeProjection();

      final record = (await projection()).byId('job-1')!;
      expect(record.job['title'], 'Lecture job-1');
      expect(record.job['sourcePath'], '/recordings/job-1.mp3');
      final speakers = record.transcript['speakers'] as List;
      expect((speakers.single as Map)['name'], '张老师');
    });

    test('a job being re-run is frozen, not dropped', () async {
      // The rule that stops a re-run from reading as a deletion. Without it the
      // other device would delete the whole folder, audio included, while its
      // owner watched the recording transcribe again.
      await writeJob('job-1');
      await TranscriptSyncService.writeProjection();

      await writeJob('job-1', stage: 'transcribing', transcript: false);
      TranscriptSyncService.markDirty();
      await TranscriptSyncService.writeProjection();

      expect((await projection()).ids, {'job-1'});
    });

    test('a job that was never finished is simply absent', () async {
      await writeJob('job-1', stage: 'queued', transcript: false);
      await TranscriptSyncService.writeProjection();
      expect((await projection()).ids, isEmpty);
    });

    test('an unreadable record stops the projection, leaving the old one',
        () async {
      await writeJob('job-1');
      await TranscriptSyncService.writeProjection();
      final good = await TranscriptSyncService.readProjectionFile();

      final record = await JobStore.recordFile('job-2');
      await record.writeAsString('{ not json');
      TranscriptSyncService.markDirty();

      await expectLater(TranscriptSyncService.writeProjection(), throwsA(anything));
      expect(await TranscriptSyncService.readProjectionFile(), good);
    });

    test('skips a folder whose name could reach outside the job folder',
        () async {
      await writeJob('job-1');
      await Directory(
        p.join(root.path, jobsDirName, 'not safe'),
      ).create(recursive: true);
      await TranscriptSyncService.writeProjection();
      expect((await projection()).ids, {'job-1'});
    });
  });

  group('applying a synced projection', () {
    /// Purpose: Encode a document for the apply step to read.
    /// Inputs: The [ids] and when each was [modified].
    /// Returns: The JSON.
    /// Side effects: None.
    /// Notes: Internal helper used within this file only.
    String incoming(Map<String, DateTime> ids, {String speaker = 'Remote'}) =>
        encodeTranscripts(
          TranscriptsDocument(
            records: [
              for (final entry in ids.entries)
                TranscriptSyncRecord(
                  id: entry.key,
                  createdAt: DateTime.utc(2026, 9, 1),
                  modifiedAt: entry.value,
                  job: {
                    'id': entry.key,
                    'createdAt': '2026-09-01T00:00:00.000Z',
                    'stage': 'done',
                    'modifiedAt': entry.value.toIso8601String(),
                    'title': 'From the server',
                  },
                  transcript: {
                    'jobId': entry.key,
                    'editedAt': entry.value.toIso8601String(),
                    'speakers': [
                      {'id': 'spk_1', 'name': speaker},
                    ],
                    'segments': const [],
                  },
                ),
            ],
          ),
        );

    test('creates a transcription this device has never seen', () async {
      final outcome = await TranscriptSyncService.apply(
        before: null,
        after: incoming({'job-new': DateTime.utc(2026, 9, 9)}),
        allowDeletions: false,
      );

      expect(outcome.written, ['job-new']);
      expect((await JobStore.load('job-new'))!.title, 'From the server');
      expect(await TranscriptStore.load('job-new'), isNotNull);
    });

    test('does not resurrect one deleted while the sync was in flight',
        () async {
      // It was in the projection when the sync started and is gone now, so the
      // user deleted it in between. Writing it back would undo that.
      final before = encodeTranscripts(
        TranscriptsDocument(
          records: [
            TranscriptSyncRecord(
              id: 'job-1',
              createdAt: DateTime.utc(2026, 9, 1),
              modifiedAt: DateTime.utc(2026, 9, 5),
              job: const {'stage': 'done'},
              transcript: const {},
            ),
          ],
        ),
      );

      final outcome = await TranscriptSyncService.apply(
        before: before,
        after: incoming({'job-1': DateTime.utc(2026, 9, 9)}),
        allowDeletions: false,
      );

      expect(outcome.written, isEmpty);
      expect(await JobStore.load('job-1'), isNull);
    });

    test('overwrites only when the arriving copy is newer', () async {
      await writeJob('job-1', modified: DateTime.utc(2026, 9, 9), speaker: '本机');

      await TranscriptSyncService.apply(
        before: null,
        after: incoming({'job-1': DateTime.utc(2026, 9, 5)}),
        allowDeletions: false,
      );
      expect((await JobStore.load('job-1'))!.title, 'Lecture job-1');

      await TranscriptSyncService.apply(
        before: null,
        after: incoming({'job-1': DateTime.utc(2026, 9, 20)}),
        allowDeletions: false,
      );
      expect((await JobStore.load('job-1'))!.title, 'From the server');
    });

    test('never writes over a job the runner is holding', () async {
      await writeJob('job-1', stage: 'transcribing', transcript: false);

      final outcome = await TranscriptSyncService.apply(
        before: null,
        after: incoming({'job-1': DateTime.utc(2026, 9, 20)}),
        allowDeletions: false,
      );

      expect(outcome.written, isEmpty);
      expect(outcome.skipped, ['job-1']);
      expect((await JobStore.load('job-1'))!.title, 'Lecture job-1');
    });

    test('deletes what the merge dropped, but only when allowed', () async {
      await writeJob('job-1');
      await writeJob('job-2');
      final before = (await TranscriptSyncService.writeProjection()).after;

      await TranscriptSyncService.apply(
        before: before,
        after: incoming({'job-1': DateTime.utc(2026, 9, 5)}),
        allowDeletions: false,
      );
      expect(await JobStore.load('job-2'), isNotNull);

      final outcome = await TranscriptSyncService.apply(
        before: before,
        after: incoming({'job-1': DateTime.utc(2026, 9, 5)}),
        allowDeletions: true,
      );
      expect(outcome.deletedIds, ['job-2']);
      expect(await JobStore.load('job-2'), isNull);
    });

    test('tells the pages that a job folder changed behind the runner',
        () async {
      final before = JobStore.changedOutsideRunner.value;
      await TranscriptSyncService.apply(
        before: null,
        after: incoming({'job-new': DateTime.utc(2026, 9, 9)}),
        allowDeletions: false,
      );
      expect(JobStore.changedOutsideRunner.value, greaterThan(before));
    });

    test('skips a record whose id could name a path outside the folder',
        () async {
      final outcome = await TranscriptSyncService.apply(
        before: null,
        after: incoming({'../escape': DateTime.utc(2026, 9, 9)}),
        allowDeletions: false,
      );

      expect(outcome.written, isEmpty);
      expect(outcome.warnings, isNotEmpty);
    });

    test('what it writes projects back byte for byte', () async {
      // If it did not, the two devices would take turns rewriting each other's
      // document and re-uploading it for ever.
      final after = incoming({'job-1': DateTime.utc(2026, 9, 9)});
      await TranscriptSyncService.apply(
        before: null,
        after: after,
        allowDeletions: false,
      );
      TranscriptSyncService.markDirty();
      final again = (await TranscriptSyncService.writeProjection()).after;

      expect(again, after);
    });
  });
}
