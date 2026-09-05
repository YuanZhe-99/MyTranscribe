/// Purpose: Test the library end to end against a real directory — seeding,
/// saving, resetting and deleting, through the files the app actually writes.
/// Inputs: None; a temporary directory stands in for the app's storage.
/// Returns: None.
/// Side effects: Creates and removes temporary directories and files.
/// Notes: `test/settings_repository_test.dart` covers the pure rules. This one
/// covers the part those cannot: that a seed reaches disk in a form the next
/// launch reads back identically, and that a key never lands in the settings
/// file. A fake path provider redirects the storage hub, so nothing here
/// touches the developer's real app data.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/providers/models/provider_templates.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/secrets/services/secrets_store.dart';
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
  final repository = SettingsRepository();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_storage_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    // The hub caches whether it has read its config; a fresh temp directory
    // per test needs that cache cleared, which resetting the path does.
    await TranscribeStorage.setStoragePath(null);
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {
      // Windows can hold a handle briefly.
    }
  });

  /// Purpose: Read the settings file as raw text.
  /// Inputs: None.
  /// Returns: Its contents, or an empty string when it does not exist.
  /// Side effects: Reads the file.
  /// Notes: Internal helper used within this file only.
  Future<String> rawSettings() async {
    final file = await TranscribeStorage.getSettingsFile();
    return file.existsSync() ? file.readAsString() : '';
  }

  test('a first launch seeds the library and writes it', () async {
    final library = await repository.load();

    expect(library.providers, hasLength(2));
    expect(library.models, isNotEmpty);
    expect(await rawSettings(), isNotEmpty);
  });

  test('a second launch reads back exactly what the first wrote', () async {
    await repository.load();
    final afterFirst = await rawSettings();

    final library = await repository.load();
    final afterSecond = await rawSettings();

    // Byte-identical: the second launch must not re-seed, and must not move a
    // single modifiedAt. If it did, every launch would look like a change to
    // sync and re-upload the whole file.
    expect(afterSecond, afterFirst);
    expect(library.providers, hasLength(2));
  });

  test('an edit survives a reload and is marked as the user\'s', () async {
    await repository.load();
    final before = (await repository.load()).provider(openaiProviderId)!;

    await repository.saveProvider(before.copyWith(name: 'My OpenAI'));
    final after = (await repository.load()).provider(openaiProviderId)!;

    expect(after.name, 'My OpenAI');
    expect(after.overriddenFields, contains('name'));
  });

  test('resetting puts the built-in values back', () async {
    await repository.load();
    final before = (await repository.load()).provider(openaiProviderId)!;
    await repository.saveProvider(
      before.copyWith(name: 'Renamed', baseUrl: 'http://example.invalid'),
    );

    await repository.resetToTemplate(openaiProviderId);
    final after = (await repository.load()).provider(openaiProviderId)!;

    expect(after.name, 'OpenAI');
    expect(after.baseUrl, 'https://api.openai.com/v1');
    expect(after.overriddenFields, isEmpty);
  });

  test('deleting a source takes its models with it', () async {
    await repository.load();
    expect((await repository.load()).modelsOf(openrouterProviderId), isNotEmpty);

    await repository.deleteProvider(openrouterProviderId);
    final after = await repository.load();

    expect(after.provider(openrouterProviderId), isNull);
    expect(
      after.modelsOf(openrouterProviderId),
      isEmpty,
      reason: 'a model whose source is gone can never be used',
    );
    // The other source is untouched, and nothing re-seeded the deleted one.
    expect(after.provider(openaiProviderId), isNotNull);
  });

  test('deleting every source lets the built-in ones be seeded again',
      () async {
    await repository.load();
    await repository.deleteProvider(openaiProviderId);
    await repository.deleteProvider(openrouterProviderId);

    final after = await repository.load();
    expect(after.providers, hasLength(2));
  });

  group('API keys', () {
    test('are stored in their own file, not in the settings', () async {
      await repository.load();
      await SecretsStore.setKey(openaiProviderId, 'sk-secret-value');

      // The load-bearing assertion of the whole design: the settings file is
      // what syncs, what is backed up and what goes into a ZIP export, and the
      // key must not be anywhere in it.
      expect(await rawSettings(), isNot(contains('sk-secret-value')));

      final keysFile = File(p.join(root.path, 'MyTranscribe', secretsFileName));
      expect(keysFile.existsSync(), isTrue);
      expect(await keysFile.readAsString(), contains('sk-secret-value'));
    });

    test('are read back, and cleared to a tombstone', () async {
      await SecretsStore.setKey(openaiProviderId, 'sk-abc');
      expect(await SecretsStore.keyFor(openaiProviderId), 'sk-abc');

      await SecretsStore.setKey(openaiProviderId, null);
      expect(await SecretsStore.keyFor(openaiProviderId), isNull);

      final stored = await SecretsStore.load();
      expect(
        stored.keys.containsKey(openaiProviderId),
        isTrue,
        reason: 'the tombstone must survive, or the next sync undoes this',
      );
    });

    test('an absent file reads as no keys rather than failing', () async {
      expect((await SecretsStore.load()).keys, isEmpty);
      expect(await SecretsStore.keyFor(openaiProviderId), isNull);
    });

    test('a damaged file costs a key, not the app', () async {
      final keysFile = File(p.join(root.path, 'MyTranscribe', secretsFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync('{ this is not json');
      expect(keysFile.existsSync(), isTrue);
      expect((await SecretsStore.load()).keys, isEmpty);
    });
  });

  group('the written file', () {
    test('is pretty-printed the way the sync engine writes it', () async {
      await repository.load();
      final raw = await rawSettings();
      // Sync compares raw strings before merging. A different indentation here
      // would make every unchanged file look changed and re-upload forever, so
      // the file on disk has to match what `encodeSettings` produces exactly.
      expect(raw, contains('\n  "records"'));
      expect(raw, encodeSettings(await TranscribeStorage.loadSettings()));
    });

    test('parses as valid settings to the sync engine', () async {
      await repository.load();
      final raw = await rawSettings();
      expect(() => validateSettingsJson(raw), returnsNormally);
    });

    test('holds no key, ever', () async {
      await repository.load();
      final decoded = jsonDecode(await rawSettings()) as Map<String, dynamic>;
      expect(jsonEncode(decoded).toLowerCase(), isNot(contains('apikey')));
    });
  });
}
