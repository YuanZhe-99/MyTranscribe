/// Purpose: Pin the persisted names and the shape of the settings module.
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
import 'package:my_transcribe/features/providers/models/transcribe_settings.dart';

void main() {
  group('the registry', () {
    test('holds exactly the settings module', () {
      expect(transcribeModuleRegistry.modules, hasLength(1));
      final module = transcribeModuleRegistry.modules.single;
      expect(module.fileName, 'transcribe_settings.json');
      expect(module.moduleId, 'settings');
    });

    test('does not carry the API keys or the job folder', () {
      // The whole security argument rests on this: sync, backup and ZIP only
      // touch the file names in the registry, so keys and recordings are
      // excluded structurally rather than by a filter someone has to remember.
      final names = transcribeModuleRegistry.byFileName.keys;
      expect(names, isNot(contains(secretsFileName)));
      expect(names, isNot(contains(jobsDirName)));
      expect(names, isNot(contains('webdav_config.json')));
      expect(names, isNot(contains('storage_config.json')));
    });

    test('names the remote directory and the archive prefix', () {
      expect(transcribeDefaultRemotePath, '/MyTranscribe');
      expect(transcribeArchiveNamePrefix, 'mytranscribe_export_');
    });
  });

  group('validateSettingsJson', () {
    test('accepts an empty document', () {
      expect(() => validateSettingsJson('{}'), returnsNormally);
      expect(
        () => validateSettingsJson('{"records": []}'),
        returnsNormally,
      );
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
      // And writes the kind back as this build understood it, which is the
      // honest thing: it did not interpret the record.
      expect(record.toJson()['kind'], 'unknown');
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
      final touched = original.touch(
        const {'a': 1},
        now: DateTime.utc(2026, 6, 1),
      );
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
}
