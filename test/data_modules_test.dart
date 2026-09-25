/// Purpose: Pin the persisted names and the shape of the data modules.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: File names and module ids are compatibility contracts — once a build
/// ships, changing one orphans every synced device and every backup bundle.
/// These tests exist so that change cannot be made by accident.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/jobs/models/transcripts_document.dart';
import 'package:my_transcribe/features/providers/models/transcribe_settings.dart';

void main() {
  group('the registry', () {
    test('holds the settings and transcripts modules, in that order', () {
      // Order is significant to the shared engines, and both names are
      // persisted contracts. A further module is appended, never inserted.
      final modules = transcribeModuleRegistry.modules;
      expect(modules, hasLength(2));
      expect(modules[0].fileName, 'transcribe_settings.json');
      expect(modules[0].moduleId, 'settings');
      expect(modules[1].fileName, 'transcribe_transcripts.json');
      expect(modules[1].moduleId, 'transcripts');
    });

    test('does not carry the API keys, the job folder or the audio', () {
      // The whole security argument rests on this: sync, backup and ZIP only
      // touch the file names in the registry, so keys and recordings are
      // excluded structurally rather than by a filter someone has to remember.
      final names = transcribeModuleRegistry.byFileName.keys;
      expect(names, isNot(contains(secretsFileName)));
      expect(names, isNot(contains(jobsDirName)));
      expect(names, isNot(contains('webdav_config.json')));
      expect(names, isNot(contains('storage_config.json')));
      // The converted audio travels through an opt-in side channel instead, so
      // a device that never asks for it never sends a byte of one.
      expect(names, isNot(contains(audioRemoteDirName)));
      // Downloaded models are gigabytes and belong to one device; the engine
      // state describes this device's processors (D2, D3).
      expect(names, isNot(contains(modelsDirName)));
      expect(names, isNot(contains(localEngineStateFileName)));
    });

    test('names the remote directory and the archive prefix', () {
      expect(transcribeDefaultRemotePath, '/MyTranscribe');
      expect(transcribeArchiveNamePrefix, 'mytranscribe_export_');
    });
  });

  group('validateSettingsJson', () {
    test('accepts an empty document', () {
      expect(() => validateSettingsJson('{}'), returnsNormally);
      expect(() => validateSettingsJson('{"records": []}'), returnsNormally);
    });

    test('rejects content that is not JSON', () {
      expect(() => validateSettingsJson('not json'), throwsFormatException);
    });
  });

  group('encodeSettings', () {
    test('pretty-prints with two spaces, like the storage hub', () {
      // Sync compares raw strings before merging. If the engine wrote a
      // different indentation from the hub, an unchanged file would miss the
      // fast path and re-upload on every sync, forever.
      final encoded = encodeSettings(
        TranscribeSettings(
          records: [
            SettingsRecord(
              id: 'provider:openai',
              kind: SettingsRecordKind.provider,
              createdAt: DateTime.utc(2026, 1, 1),
              modifiedAt: DateTime.utc(2026, 1, 2),
              payload: const {'name': 'OpenAI'},
            ),
          ],
        ),
      );
      expect(encoded, contains('\n  "records"'));
      expect(encoded, contains('"name": "OpenAI"'));
      // And it round-trips.
      final parsed = TranscribeSettings.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(parsed.records.single.id, 'provider:openai');
      expect(parsed.records.single.kind, SettingsRecordKind.provider);
    });
  });

  group('SettingsRecord', () {
    test('keeps fields a newer build wrote', () {
      final json = {
        'id': 'model:future',
        'kind': 'model',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'modifiedAt': '2026-01-01T00:00:00.000Z',
        'payload': {'modelName': 'x'},
        'somethingNew': 42,
      };
      final record = SettingsRecord.fromJson(json);
      expect(record.extraJson['somethingNew'], 42);
      expect(record.toJson()['somethingNew'], 42);
    });

    test('reads an unknown kind without losing the record', () {
      final record = SettingsRecord.fromJson({
        'id': 'x',
        'kind': 'somethingElse',
        'modifiedAt': '2026-01-01T00:00:00.000Z',
      });
      expect(record.kind, SettingsRecordKind.unknown);
      // And writes the kind back exactly as it found it. 0.2.x wrote
      // `unknown` here, which turned a later build's record kind into one
      // nobody can read once it had passed through an older device.
      expect(record.toJson()['kind'], 'somethingElse');
    });

    test('takes back a local model that an older build wrote as unknown', () {
      // 0.2.x writes a kind it does not know as `unknown`; the `local:` id
      // prefix is what lets this build recognise the record again.
      final record = SettingsRecord.fromJson({
        'id': 'local:whisper-large-v3-turbo',
        'kind': 'unknown',
        'payload': {'displayName': 'Whisper large-v3 turbo'},
      });
      expect(record.kind, SettingsRecordKind.localModel);
      expect(record.toJson()['kind'], 'localModel');

      final other = SettingsRecord.fromJson({'id': 'x', 'kind': 'unknown'});
      expect(other.kind, SettingsRecordKind.unknown);
      expect(other.toJson()['kind'], 'unknown');
    });

    test('falls back to the epoch, never to now', () {
      // "now" would make an untouched record look newer than the remote copy
      // on every read, and win every merge.
      final record = SettingsRecord.fromJson({'id': 'x', 'kind': 'model'});
      expect(record.modifiedAt.millisecondsSinceEpoch, 0);
      expect(record.modifiedAt.isUtc, isTrue);
    });

    test('touch moves modifiedAt and keeps createdAt', () {
      final original = SettingsRecord(
        id: 'x',
        kind: SettingsRecordKind.model,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
      );
      final touched = original.touch(const {
        'a': 1,
      }, now: DateTime.utc(2026, 6, 1));
      expect(touched.createdAt, DateTime.utc(2026, 1, 1));
      expect(touched.modifiedAt, DateTime.utc(2026, 6, 1));
      expect(touched.payload, const {'a': 1});
    });
  });

  group('TranscribeSettings', () {
    final record = SettingsRecord(
      id: 'provider:a',
      kind: SettingsRecordKind.provider,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
    );

    test('upsert replaces in place and appends new records', () {
      final one = const TranscribeSettings().upsert(record);
      expect(one.records, hasLength(1));

      final replaced = one.upsert(record.touch(const {'name': 'A'}));
      expect(replaced.records, hasLength(1));
      expect(replaced.records.single.payload['name'], 'A');

      final two = replaced.upsert(
        SettingsRecord(
          id: 'provider:b',
          kind: SettingsRecordKind.provider,
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
        ),
      );
      expect(two.records.map((r) => r.id), ['provider:a', 'provider:b']);
    });

    test('remove really removes, so the deletion can propagate', () {
      final settings = const TranscribeSettings().upsert(record);
      expect(settings.remove('provider:a').records, isEmpty);
    });

    test('drops a record with no id, which could never be merged', () {
      final parsed = TranscribeSettings.fromJson({
        'records': [
          {'kind': 'provider'},
          {'id': 'provider:a', 'kind': 'provider'},
        ],
      });
      expect(parsed.records.map((r) => r.id), ['provider:a']);
    });

    test('a records field of the wrong type reads as empty', () {
      expect(TranscribeSettings.fromJson({'records': 7}).records, isEmpty);
    });
  });

  group('the transcripts module', () {
    /// Purpose: Build a projection record for a test.
    /// Inputs: The [id] and an optional [title].
    /// Returns: A [TranscriptSyncRecord].
    /// Side effects: None.
    /// Notes: Internal helper used within this file only.
    TranscriptSyncRecord record(String id, {String? title}) =>
        TranscriptSyncRecord(
          id: id,
          createdAt: DateTime.utc(2026, 9, 1),
          modifiedAt: DateTime.utc(2026, 9, 9),
          job: {'id': id, 'title': ?title},
          transcript: {'jobId': id, 'segments': []},
        );

    test('accepts an empty document and rejects what is not JSON', () {
      expect(() => validateTranscriptsJson('{}'), returnsNormally);
      expect(() => validateTranscriptsJson('{"records": []}'), returnsNormally);
      expect(() => validateTranscriptsJson('not json'), throwsFormatException);
    });

    test('encodes sorted by id, so two devices agree byte for byte', () {
      // The merge returns records in set-iteration order. Without the sort, two
      // devices holding identical data would encode it differently, miss the
      // engine's raw-equality fast path and re-upload each other's document
      // forever.
      final encoded = encodeTranscripts(
        TranscriptsDocument(records: [record('b'), record('a')]),
      );
      expect(encoded.indexOf('"a"'), lessThan(encoded.indexOf('"b"')));
      expect(encoded, contains('\n  "records"'));
    });

    test('round-trips, keeping fields it does not understand', () {
      final encoded = encodeTranscripts(
        const TranscriptsDocument(extraJson: {'somethingNewer': 1}),
      );
      final parsed = TranscriptsDocument.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(parsed.extraJson['somethingNewer'], 1);
    });

    test('drops a record it cannot use rather than failing the file', () {
      // One damaged entry from another device must not stop every other
      // transcription from syncing.
      final parsed = TranscriptsDocument.fromJson({
        'records': [
          {'id': '', 'job': {}, 'transcript': {}},
          {'id': 'ok', 'job': {}, 'transcript': {}},
          {'id': 'nomaps'},
        ],
      });
      expect(parsed.ids, {'ok'});
    });

    test('refuses an id that would name a path outside the job folder', () {
      expect(TranscriptSyncRecord.isSafeId('job-1'), isTrue);
      expect(TranscriptSyncRecord.isSafeId('..'), isFalse);
      expect(TranscriptSyncRecord.isSafeId('a/b'), isFalse);
      expect(TranscriptSyncRecord.isSafeId(r'a\b'), isFalse);
      expect(TranscriptSyncRecord.isSafeId(''), isFalse);
    });

    test('names a transcription by its title, then its recording', () {
      expect(record('x', title: 'Week 3').displayName, 'Week 3');
      expect(
        TranscriptSyncRecord(
          id: 'x',
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
          job: const {'sourceName': 'lecture.mp3'},
          transcript: const {},
        ).displayName,
        'lecture.mp3',
      );
      expect(record('x').displayName, 'x');
    });
  });
}
