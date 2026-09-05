/// Purpose: Test seeding, template refresh and the typed view of the library.
/// Inputs: None.
/// Returns: None.
/// Side effects: None — every case uses the repository's pure entry points, so
/// nothing touches disk.
/// Notes: The load-bearing case is the first one: two devices that seed
/// independently must produce identical records, because that is what makes
/// the first sync a merge rather than a duplication. Everything else protects
/// a user's edits from a later template refresh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:my_transcribe/features/providers/models/provider_config.dart';
import 'package:my_transcribe/features/providers/models/provider_templates.dart';
import 'package:my_transcribe/features/providers/models/transcribe_settings.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';

void main() {
  final repository = SettingsRepository();
  final seededAt = DateTime.utc(2026, 1, 1);

  TranscribeSettings seeded() =>
      repository.seedInto(const TranscribeSettings(), now: seededAt);

  group('seeding', () {
    test('two devices seed byte-identical documents', () {
      // The whole reason template ids are derived rather than generated: if
      // these differed, the first sync would leave the user with two of
      // everything and no way to tell which was which.
      final first = repository.seedInto(
        const TranscribeSettings(),
        now: DateTime.utc(2026, 1, 1),
      );
      final second = SettingsRepository().seedInto(
        const TranscribeSettings(),
        now: DateTime.utc(2026, 6, 30),
      );

      expect(
        first.records.map((r) => r.id).toList(),
        second.records.map((r) => r.id).toList(),
      );
      for (final record in first.records) {
        expect(
          record.payload,
          second.byId(record.id)!.payload,
          reason: '${record.id} differs between devices',
        );
      }
    });

    test('seeds both built-in sources, their models and the defaults', () {
      final library = repository.read(seeded());
      expect(
        library.providers.map((p) => p.id),
        containsAll(<String>[openaiProviderId, openrouterProviderId]),
      );
      expect(library.modelsOf(openaiProviderId), isNotEmpty);
      expect(library.modelsOf(openrouterProviderId), isNotEmpty);
      expect(library.defaults.plainOverlapSeconds, 5);
      expect(library.defaults.diarizedOverlapSeconds, 20);
    });

    test('never overwrites a record that is already there', () {
      // Seeding runs whenever no source exists. A user who deleted every source
      // but kept a model must not have that model reset under them.
      final edited = seeded();
      final modelId = templateModelId(openaiProviderId, 'gpt-transcribe');
      final record = edited.byId(modelId)!;
      final custom = edited.upsert(
        record.touch({
          ...record.payload,
          'displayName': 'My name for it',
        }, now: DateTime.utc(2026, 2, 1)),
      );

      final reseeded = repository.seedInto(custom, now: seededAt);
      expect(reseeded.byId(modelId)!.payload['displayName'], 'My name for it');
    });

    test('every model belongs to a source that exists', () {
      final library = repository.read(seeded());
      final ids = library.providers.map((p) => p.id).toSet();
      for (final model in library.models) {
        expect(ids, contains(model.providerId), reason: model.id);
      }
    });

    test('every source names a default model that exists', () {
      final library = repository.read(seeded());
      for (final provider in library.providers) {
        expect(
          library.model(provider.defaultModelId),
          isNotNull,
          reason: '${provider.id} points at a model that was not seeded',
        );
      }
    });

    test('the seeded document is valid to the sync engine', () {
      // The engine validates a payload before writing it during a restore or an
      // import, so a document this app produced must pass its own validator.
      expect(
        () => validateSettingsJson(encodeSettings(seeded())),
        returnsNormally,
      );
    });
  });

  group('template capabilities', () {
    late SettingsLibrary library;

    setUp(() => library = repository.read(seeded()));

    test('gpt-transcribe takes a language list, not a single code', () {
      final model = library.model(
        templateModelId(openaiProviderId, 'gpt-transcribe'),
      )!;
      expect(model.languageParamStyle, LanguageParamStyle.languages);
      expect(model.supportsKeywords, isTrue);
      expect(model.supportsPrompt, isTrue);
      // It returns text and nothing else, which is what makes the transcript
      // viewer show approximate times rather than real ones.
      expect(model.segmentTimestamps, Capability.unsupported);
      expect(model.diarization, Capability.unsupported);
    });

    test('whisper is the OpenAI model that returns times', () {
      final model = library.model(
        templateModelId(openaiProviderId, 'whisper-1'),
      )!;
      expect(model.segmentTimestamps, Capability.supported);
      expect(model.responseFormats, contains('verbose_json'));
    });

    test('the diarizing model carries what a speaker request needs', () {
      final model = library.model(
        templateModelId(openaiProviderId, 'gpt-4o-transcribe-diarize'),
      )!;
      expect(model.diarization, Capability.supported);
      expect(model.responseFormats.first, 'diarized_json');
      expect(model.requiresChunkingStrategy, isTrue);
      expect(model.maxKnownSpeakers, 4);
      // It takes no prompt, so the job page must not offer one for it.
      expect(model.supportsPrompt, isFalse);
    });

    test('the gateway caps request length for every model behind it', () {
      // A provider-level limit, distinct from a model's: the gateway gives up
      // on a long upstream request whatever the model would have accepted.
      final provider = library.provider(openrouterProviderId)!;
      expect(provider.maxRequestSeconds, 600);
    });

    test('the gateway never offers a prompt, because it drops one', () {
      // Accepting a prompt and ignoring it is worse than refusing it: the user
      // would see their context accepted and never learn it was discarded.
      for (final model in library.modelsOf(openrouterProviderId)) {
        expect(model.supportsPrompt, isFalse, reason: model.id);
      }
    });
  });

  group('template refresh', () {
    test('does nothing when every record is current', () {
      // Returning null rather than an equal document matters: rewriting one
      // would move modifiedAt on every record and make the next sync believe
      // this device changed everything.
      expect(repository.applyTemplateUpdates(seeded()), isNull);
    });

    test('refreshes a record left behind by an older build', () {
      final stale = _withTemplateVersion(
        seeded(),
        templateModelId(openaiProviderId, 'whisper-1'),
        0,
        {'displayName': 'Old name'},
      );

      final refreshed = repository.applyTemplateUpdates(stale);
      expect(refreshed, isNotNull);
      final model = repository
          .read(refreshed!)
          .model(templateModelId(openaiProviderId, 'whisper-1'))!;
      expect(model.displayName, 'Whisper');
      expect(model.templateVersion, templateVersion);
    });

    test('leaves a field the user changed alone', () {
      // The point of the whole mechanism. An improved default reaches somebody
      // who never touched it; a deliberate correction survives.
      final stale = _withTemplateVersion(
        seeded(),
        templateModelId(openaiProviderId, 'whisper-1'),
        0,
        {
          'displayName': 'My name for it',
          'maxDurationSeconds': 3000,
          'overriddenFields': ['displayName', 'maxDurationSeconds'],
        },
      );

      final refreshed = repository.applyTemplateUpdates(stale)!;
      final model = repository
          .read(refreshed)
          .model(templateModelId(openaiProviderId, 'whisper-1'))!;
      expect(model.displayName, 'My name for it');
      expect(model.maxDurationSeconds, 3000);
      // And a field they did not touch still came from the template.
      expect(model.segmentTimestamps, Capability.supported);
    });

    test('does not touch a source the user added themselves', () {
      final custom = seeded().upsert(
        SettingsRecord(
          id: 'provider:mine',
          kind: SettingsRecordKind.provider,
          createdAt: seededAt,
          modifiedAt: seededAt,
          payload: const ProviderConfig(
            id: 'provider:mine',
            name: 'My server',
            dialect: ProviderDialect.openaiCompatible,
            baseUrl: 'http://127.0.0.1:8080/v1',
            authScheme: AuthScheme.none,
          ).toPayload(),
        ),
      );

      expect(repository.applyTemplateUpdates(custom), isNull);
      final mine = repository.read(custom).provider('provider:mine')!;
      expect(mine.authScheme, AuthScheme.none);
    });
  });

  group('reading', () {
    test('an unknown record kind is skipped, not fatal', () {
      // A record from a newer build must not stop this one reading the library,
      // and it stays in the document so it still syncs.
      final withFuture = seeded().upsert(
        SettingsRecord(
          id: 'somethingNew:1',
          kind: SettingsRecordKind.unknown,
          createdAt: seededAt,
          modifiedAt: seededAt,
          payload: const {'whatever': true},
        ),
      );
      final library = repository.read(withFuture);
      expect(library.providers, isNotEmpty);
      expect(withFuture.byId('somethingNew:1'), isNotNull);
    });

    test('an empty document reads as an empty library', () {
      final library = repository.read(const TranscribeSettings());
      expect(library.isEmpty, isTrue);
      expect(library.models, isEmpty);
      expect(library.defaults.plainOverlapSeconds, 5);
    });
  });

  group('ids for records the user adds', () {
    test('are random, so two people adding a server do not collide', () {
      final a = repository.newProviderId();
      final b = repository.newProviderId();
      expect(a, startsWith('provider:'));
      expect(a, isNot(b));
      expect(repository.newModelId(), startsWith('model:'));
    });
  });

  group('endpoints', () {
    test('tolerate a base URL typed with or without a trailing slash', () {
      const withSlash = ProviderConfig(
        id: 'provider:x',
        name: 'x',
        dialect: ProviderDialect.openaiCompatible,
        baseUrl: 'http://localhost:8080/v1/',
      );
      const without = ProviderConfig(
        id: 'provider:x',
        name: 'x',
        dialect: ProviderDialect.openaiCompatible,
        baseUrl: 'http://localhost:8080/v1',
      );
      expect(
        withSlash.endpoint('audio/transcriptions'),
        'http://localhost:8080/v1/audio/transcriptions',
      );
      expect(
        without.endpoint('/audio/transcriptions'),
        'http://localhost:8080/v1/audio/transcriptions',
      );
    });
  });
}

/// Purpose: Rewrite one record as an older build would have left it.
/// Inputs: [settings], [recordId], [version], [overrides] to merge in.
/// Returns: A new document.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
TranscribeSettings _withTemplateVersion(
  TranscribeSettings settings,
  String recordId,
  int version,
  Map<String, dynamic> overrides,
) {
  final record = settings.byId(recordId)!;
  return settings.upsert(
    record.touch({
      ...record.payload,
      ...overrides,
      'templateVersion': version,
    }, now: DateTime.utc(2025, 1, 1)),
  );
}
