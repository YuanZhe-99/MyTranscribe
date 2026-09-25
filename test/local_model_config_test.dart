/// Purpose: Test the synced local-model record: parsing, unknown fields, the
/// built-in templates, seeding and refreshing, and what an older build does to
/// it.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The round trip through a 0.2.x-shaped reader is the case that
/// matters most: a record kind an older build cannot read must come back to
/// this one intact, or a user with two devices on different versions loses
/// their list of local models.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/local_model_config.dart';
import 'package:my_transcribe/features/local/services/local_model_templates.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:my_transcribe/features/providers/models/transcribe_settings.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';

/// Purpose: Parse a record kind the way 0.2.1 did.
/// Inputs: [value].
/// Returns: The kind name 0.2.1 would have written back.
/// Side effects: None.
/// Notes: A copy of the 0.2.1 rule — three known kinds, everything else
/// `unknown` — so the test states what the older build does rather than
/// assuming it.
String kindAsWrittenBy021(Object? value) =>
    const ['provider', 'model', 'defaults'].contains(value)
    ? value! as String
    : 'unknown';

void main() {
  group('a local model record', () {
    test('round-trips, keeping fields a newer build wrote', () {
      final payload = {
        'templateId': 'local:x',
        'displayName': 'X',
        'family': 'whisper',
        'languages': ['EN', 'ja'],
        'maxDurationSeconds': 600,
        'diarization': 'unsupported',
        'wordTimestamps': 'supported',
        'segmentTimestamps': 'supported',
        'supportsPrompt': true,
        'supportsKeywords': false,
        'artifacts': {
          'whisper_cpp': ['a'],
          'qnn': ['b'],
        },
        'templateVersion': 1,
        'futureField': {'kept': true},
      };
      final model = LocalModelConfig.fromPayload('local:x', payload);
      expect(model.family, LocalModelFamily.whisper);
      expect(model.languages, ['en', 'ja']);
      expect(model.artifactIds, {'a', 'b'});
      expect(model.extraJson, {
        'futureField': {'kept': true},
      });

      final written = model.toPayload();
      expect(written['futureField'], {'kept': true});
      expect(
        (written['artifacts'] as Map).keys.toList(),
        ['qnn', 'whisper_cpp'],
        reason: 'sorted, so an unchanged record writes the same bytes',
      );
    });

    test('reads garbage as defaults rather than throwing', () {
      final model = LocalModelConfig.fromPayload('local:y', {
        'family': 42,
        'languages': 'en',
        'artifacts': ['nope'],
        'maxDurationSeconds': -1,
      });
      expect(model.family, LocalModelFamily.unknown);
      expect(model.languages, isEmpty);
      expect(model.artifacts, isEmpty);
      expect(model.maxDurationSeconds, isNull);
      expect(model.displayName, 'local:y');
    });

    test('accepts a language by its primary subtag', () {
      const model = LocalModelConfig(
        id: 'local:p',
        displayName: 'P',
        languages: ['en', 'de'],
      );
      expect(model.acceptsLanguages(const []), isTrue);
      expect(model.acceptsLanguages(const ['en-GB']), isTrue);
      expect(model.acceptsLanguages(const ['en', 'zh-Hant']), isFalse);
      const any = LocalModelConfig(id: 'local:w', displayName: 'W');
      expect(any.acceptsLanguages(const ['zh']), isTrue);
    });

    test('marks edited fields as overridden', () {
      const model = LocalModelConfig(id: 'local:x', displayName: 'X');
      final edited = model.copyWith(displayName: 'Mine');
      expect(edited.overriddenFields, {'displayName'});
      final refreshed = model.copyWith(
        displayName: 'Template',
        markOverridden: false,
      );
      expect(refreshed.overriddenFields, isEmpty);
    });

    test('shares its provider id with the job record', () {
      expect(localJobProviderId, localProviderId);
    });
  });

  group('the built-in templates', () {
    final templates = buildLocalModelTemplates();

    test('have local ids and packages the records point at', () {
      final ids = <String>{};
      for (final template in templates) {
        expect(template.model.id, startsWith(localModelIdPrefix));
        expect(template.model.templateVersion, localTemplateVersion);
        expect(ids.add(template.model.id), isTrue, reason: 'unique ids');
        final artifacts = {for (final a in template.artifacts) a.artifactId};
        expect(template.model.artifactIds, artifacts);
        for (final artifact in template.artifacts) {
          expect(artifact.modelId, template.model.id);
          expect(templateArtifact(artifact.artifactId), isNotNull);
        }
      }
    });

    test('pin every file by URL, size and SHA-256', () {
      for (final template in templates) {
        for (final artifact in template.artifacts) {
          expect(artifact.revision, isNotEmpty);
          expect(artifact.licenseId, isNotEmpty);
          for (final file in artifact.files) {
            expect(file.bytes, greaterThan(0));
            expect(file.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
            final url = Uri.parse(file.sourceUrl);
            expect(url.scheme, 'https');
            expect(
              url.path.contains('/resolve/main/'),
              isFalse,
              reason: '${file.path} must be pinned to a revision, not main',
            );
          }
        }
      }
    });

    test('keep Chinese, Japanese and Korean away from Parakeet', () {
      final parakeet = templates
          .firstWhere((t) => t.model.family == LocalModelFamily.parakeet)
          .model;
      for (final language in ['zh', 'ja', 'ko', 'yue']) {
        expect(parakeet.acceptsLanguages([language]), isFalse);
      }
      expect(parakeet.acceptsLanguages(['en']), isTrue);
    });

    test('claim no speaker labels, and no timestamps for Qwen', () {
      for (final template in templates) {
        expect(template.model.diarization, Capability.unsupported);
      }
      final qwen = templates
          .firstWhere((t) => t.model.family == LocalModelFamily.qwen)
          .model;
      expect(qwen.segmentTimestamps, Capability.unsupported);
    });

    test('ship the Core ML encoder to Apple platforms only', () {
      final turbo = templateArtifact('whisper-large-v3-turbo-ggml')!;
      expect(turbo.filesFor('windows'), hasLength(1));
      expect(turbo.filesFor('macos'), hasLength(2));
      expect(
        turbo.filesFor('ios').last.unpack,
        ArchiveKind.zip,
        reason: 'the encoder is a zipped folder',
      );
    });
  });

  group('the library', () {
    final repository = SettingsRepository();
    final stamp = DateTime.utc(2026, 9, 24);

    test('seeds the built-in local models with derived ids', () {
      final seeded = repository.seedLocalModelsInto(
        const TranscribeSettings(),
        now: stamp,
      );
      final library = repository.read(seeded);
      expect(
        library.localModels.map((m) => m.id),
        buildLocalModelTemplates().map((t) => t.model.id),
      );
      expect(
        seeded.ofKind(SettingsRecordKind.localModel),
        hasLength(buildLocalModelTemplates().length),
      );
      // Two devices seeding independently produce the same records.
      final again = repository.seedLocalModelsInto(
        const TranscribeSettings(),
        now: stamp,
      );
      expect(jsonEncode(again.toJson()), jsonEncode(seeded.toJson()));
    });

    test('refreshes an old template record but not what the user changed', () {
      final seeded = repository.seedLocalModelsInto(
        const TranscribeSettings(),
        now: stamp,
      );
      final record = seeded.byId('local:whisper-large-v3-turbo')!;
      final old = LocalModelConfig.fromPayload(record.id, record.payload)
          .copyWith(displayName: 'My turbo', maxDurationSeconds: 60)
          .copyWith(templateVersion: 0, markOverridden: false);
      final stale = seeded.upsert(
        record.touch({
          ...old.toPayload(),
          'overriddenFields': ['displayName'],
        }, now: stamp),
      );
      final refreshed = repository.applyTemplateUpdates(stale, now: stamp);
      expect(refreshed, isNotNull);
      final model = repository.read(refreshed!).localModel(record.id)!;
      expect(model.displayName, 'My turbo', reason: 'overridden');
      expect(model.maxDurationSeconds, localWindowCeilingSeconds);
      expect(model.templateVersion, localTemplateVersion);
      expect(
        repository.applyTemplateUpdates(refreshed, now: stamp),
        isNull,
        reason: 'nothing left to refresh writes nothing',
      );
    });
  });

  group('an older build', () {
    test('carries a local model record through and this build takes it '
        'back', () {
      final repository = SettingsRepository();
      final seeded = repository.seedLocalModelsInto(
        const TranscribeSettings(),
        now: DateTime.utc(2026, 9, 24),
      );
      final original = seeded.toJson();

      // What 0.2.1 reads and writes back: every field kept, the kind turned
      // into `unknown`.
      final through021 = {
        ...original,
        'records': [
          for (final record in original['records'] as List)
            {
              ...record as Map<String, dynamic>,
              'kind': kindAsWrittenBy021(record['kind']),
            },
        ],
      };
      expect(
        (through021['records'] as List).every((r) => r['kind'] == 'unknown'),
        isTrue,
        reason: '0.2.1 does not know the localModel kind',
      );

      final back = TranscribeSettings.fromJson(
        jsonDecode(jsonEncode(through021)) as Map<String, dynamic>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(original));
      expect(
        repository.read(back).localModels,
        hasLength(buildLocalModelTemplates().length),
      );
    });

    test('never sees a local model as a source or a model', () {
      final repository = SettingsRepository();
      final seeded = repository.seedLocalModelsInto(const TranscribeSettings());
      final library = repository.read(seeded);
      expect(library.providers, isEmpty);
      expect(library.models, isEmpty);
    });
  });
}
