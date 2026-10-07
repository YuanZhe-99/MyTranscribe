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
import 'package:my_transcribe/features/providers/services/online_sources_controller.dart';
import 'package:my_transcribe/features/providers/services/online_privacy.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart' as online;
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

  test(
    'shared online edit preserves records and consent follows the host',
    () async {
      await repository.load();
      final controller = TranscribeOnlineSources(repository, 'Audio and hints');
      addTearDown(controller.dispose);
      await controller.reload();
      final original = controller.providers.first;
      expect(controller.templates.templates, isNotEmpty);
      controller.privacyNotice(original);
      await controller.acknowledge(
        original.id,
        online.OnlinePrivacyAcknowledgement(
          noticeVersion: 1,
          recipientHost: original.recipientHost!,
          acknowledgedAt: DateTime.now().toUtc(),
        ),
      );
      final before = (await repository.load()).provider(original.id)!;
      expect(await OnlinePrivacy.allowed(before), isTrue);
      await controller.save(
        original.copyWith(name: 'Edited source'),
        newKey: 'test-local-key',
      );
      final edited = (await repository.load()).provider(original.id)!;
      expect(edited.templateId, before.templateId);
      expect(edited.maxFileBytes, before.maxFileBytes);
      expect(edited.defaultModelId, before.defaultModelId);
      expect(await rawSettings(), isNot(contains('test-local-key')));
      await controller.save(
        original.copyWith(baseUrl: 'https://other.example.com/v1'),
      );
      expect(
        await OnlinePrivacy.allowed(
          (await repository.load()).provider(original.id)!,
        ),
        isFalse,
      );
      await controller.remove(original.id);
      expect(await SecretsStore.keyFor(original.id), isNull);
    },
  );

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
    expect(
      (await repository.load()).modelsOf(openrouterProviderId),
      isNotEmpty,
    );

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

  test(
    'deleting every source lets the built-in ones be seeded again',
    () async {
      await repository.load();
      await repository.deleteProvider(openaiProviderId);
      await repository.deleteProvider(openrouterProviderId);

      final after = await repository.load();
      expect(after.providers, hasLength(2));
    },
  );

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

    test('a damaged file is set aside when a key is saved, not lost', () async {
      final keysFile = File(p.join(root.path, 'MyTranscribe', secretsFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync('{ this is not json');

      await SecretsStore.setKey(openaiProviderId, 'sk-new');

      expect(await SecretsStore.keyFor(openaiProviderId), 'sk-new');
      final aside = keysFile.parent
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).contains('.unreadable-'))
          .toList();
      expect(aside.single.readAsStringSync(), '{ this is not json');
    });

    test('an I/O error saving a key is thrown and changes nothing', () async {
      final keysFile = File(p.join(root.path, 'MyTranscribe', secretsFileName))
        ..createSync(recursive: true);
      keysFile.deleteSync();
      Directory(keysFile.path).createSync();

      await expectLater(
        SecretsStore.setKey(openaiProviderId, 'sk-new'),
        throwsA(isA<FileSystemException>()),
      );
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

  group('storage_config.json', () {
    /// Purpose: Locate the config file the hub writes.
    /// Inputs: None.
    /// Returns: The file, which may not exist yet.
    /// Side effects: None.
    /// Notes: Internal helper used within this file only. The config always
    /// lives in the default location, beside the app directory's parent.
    File configFile() =>
        File(p.join(root.path, 'MyTranscribe', 'storage_config.json'));

    /// Purpose: List the files set aside beside the config.
    /// Inputs: None.
    /// Returns: Their paths.
    /// Side effects: Lists a directory.
    /// Notes: Internal helper used within this file only.
    List<File> setAside() => configFile().parent
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).contains('.unreadable-'))
        .toList();

    test('setters running at once do not erase one another', () async {
      await Future.wait([
        TranscribeStorage.setThemeMode('dark'),
        TranscribeStorage.setLocaleTag('zh_TW'),
        TranscribeStorage.setLastTab('library'),
        TranscribeStorage.setViewerFontSize(20),
        TranscribeStorage.setSyncIncludesAudio(true),
      ]);

      final config = await TranscribeStorage.readConfig();
      expect(config['themeMode'], 'dark');
      expect(config['locale'], 'zh_TW');
      expect(config['lastTab'], 'library');
      expect(config['viewerFontSize'], 20);
      expect(config['syncIncludesAudio'], true);
    });

    test('keeps keys it does not own', () async {
      await TranscribeStorage.writeConfigLocked({'fromEngine': 'kept'});
      await TranscribeStorage.setThemeMode('light');
      expect((await TranscribeStorage.readConfig())['fromEngine'], 'kept');
    });

    test('an unparseable file is set aside, not overwritten', () async {
      await TranscribeStorage.getAppDir();
      configFile().writeAsStringSync('{ "themeMode": "dark", oops');

      // Reading stays lenient and touches nothing.
      expect(await TranscribeStorage.readConfig(), isEmpty);
      expect(setAside(), isEmpty);

      await TranscribeStorage.setLocaleTag('zh');

      expect((await TranscribeStorage.readConfig())['locale'], 'zh');
      final aside = setAside();
      expect(aside, hasLength(1));
      expect(aside.single.readAsStringSync(), '{ "themeMode": "dark", oops');
    });

    test('a file that is not a JSON object is set aside too', () async {
      await TranscribeStorage.getAppDir();
      configFile().writeAsStringSync('[1, 2, 3]');

      await TranscribeStorage.setThemeMode('dark');

      expect((await TranscribeStorage.readConfig())['themeMode'], 'dark');
      expect(setAside().single.readAsStringSync(), '[1, 2, 3]');
    });

    test('a blank or absent file is simply started', () async {
      await TranscribeStorage.getAppDir();
      configFile().writeAsStringSync('  \n');

      await TranscribeStorage.setThemeMode('dark');

      expect((await TranscribeStorage.readConfig())['themeMode'], 'dark');
      expect(setAside(), isEmpty);
    });

    test('an I/O error is thrown, and nothing is set aside', () async {
      // A folder where the file should be: not readable as a file, not
      // replaceable by one. That is an I/O problem, not bad content.
      await TranscribeStorage.getAppDir();
      if (configFile().existsSync()) configFile().deleteSync();
      Directory(configFile().path).createSync();

      await expectLater(
        TranscribeStorage.setThemeMode('dark'),
        throwsA(isA<FileSystemException>()),
      );
      expect(setAside(), isEmpty);
    });

    test('a failed write does not block the next one', () async {
      await TranscribeStorage.getAppDir();
      if (configFile().existsSync()) configFile().deleteSync();
      final blocker = Directory(configFile().path)..createSync();
      await expectLater(
        TranscribeStorage.setThemeMode('dark'),
        throwsA(isA<FileSystemException>()),
      );
      blocker.deleteSync();

      await TranscribeStorage.setThemeMode('light');
      expect((await TranscribeStorage.readConfig())['themeMode'], 'light');
    });
  });
}
