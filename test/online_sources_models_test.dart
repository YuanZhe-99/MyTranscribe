/// Purpose: Test multi-model editing through the shared online sources UI.
/// Inputs: None; a temporary directory stands in for app storage.
/// Returns: None.
/// Side effects: Creates and removes temporary directories.
/// Notes: ASR capability fields on existing records must never change.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_transcribe/features/providers/models/model_config.dart';
import 'package:my_transcribe/features/providers/services/online_sources_controller.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/providers/views/online_sources_page.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart' as online;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  final repository = SettingsRepository();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('transcribe_models_');
    PathProviderPlatform.instance = _Paths(root.path);
    await TranscribeStorage.setStoragePath(null);
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  Future<TranscribeOnlineSources> controller({
    http.Client Function()? client,
    Set<String> jobs = const {},
  }) async {
    await repository.load();
    final c = TranscribeOnlineSources(
      repository,
      'Audio',
      clientFactory: client,
      jobModelIds: () async => jobs,
    );
    addTearDown(c.dispose);
    await c.reload();
    return c;
  }

  test('saving two models creates unknown-capability records', () async {
    final c = await controller();
    final before = await repository.load();
    final provider = c.providers.first;
    final existing = before.modelsOf(provider.id);
    final saved = provider.copyWith(
      models: [
        ...provider.models,
        const online.OnlineModel(modelName: 'new-a'),
        const online.OnlineModel(modelName: 'new-b', alias: 'Bee'),
      ],
    );
    await c.save(saved);
    final after = await repository.load();
    final models = after.modelsOf(provider.id);
    expect(models, hasLength(existing.length + 2));
    for (final old in existing) {
      final now = models.firstWhere((m) => m.id == old.id);
      expect(now.diarization, old.diarization);
      expect(now.segmentTimestamps, old.segmentTimestamps);
      expect(now.overriddenFields, old.overriddenFields);
      expect(now.displayName, old.displayName);
    }
    final a = models.firstWhere((m) => m.modelName == 'new-a');
    final b = models.firstWhere((m) => m.modelName == 'new-b');
    for (final m in [a, b]) {
      expect(m.diarization, Capability.unknown);
      expect(m.segmentTimestamps, Capability.unknown);
      expect(m.overriddenFields, isEmpty);
    }
    expect(a.displayName, 'new-a');
    expect(b.displayName, 'Bee');
    expect(
      after.provider(provider.id)!.defaultModelId,
      before.provider(provider.id)!.defaultModelId,
    );
  });

  test('an alias change updates only the display name', () async {
    final c = await controller();
    final provider = c.providers.first;
    final old = (await repository.load()).modelsOf(provider.id).first;
    await c.save(
      provider.copyWith(
        models: [
          for (final m in provider.models)
            m.modelName == old.modelName ? m.copyWith(alias: 'Renamed') : m,
        ],
      ),
    );
    final now = (await repository.load()).model(old.id)!;
    expect(now.displayName, 'Renamed');
    expect(now.modelName, old.modelName);
    expect(now.id, old.id);
    expect(now.diarization, old.diarization);
    expect(now.maxFileBytes, old.maxFileBytes);
    expect(now.responseFormats, old.responseFormats);
  });

  test('removed models are deleted unless default or used by a job', () async {
    final c = await controller();
    final provider = c.providers.first;
    await c.save(
      provider.copyWith(
        models: [
          ...provider.models,
          const online.OnlineModel(modelName: 'tmp-1'),
          const online.OnlineModel(modelName: 'tmp-2'),
        ],
      ),
    );
    final library = await repository.load();
    final tmp2 = library
        .modelsOf(provider.id)
        .firstWhere((m) => m.modelName == 'tmp-2');
    final used = await controller(jobs: {tmp2.id});
    final p = used.providers.firstWhere((x) => x.id == provider.id);
    // Drop everything except the first (default) model.
    await used.save(p.copyWith(models: [p.models.first]));
    final names = (await repository.load())
        .modelsOf(provider.id)
        .map((m) => m.modelName)
        .toSet();
    expect(names, contains('tmp-2'));
    expect(names, isNot(contains('tmp-1')));
    final defaultId = library.provider(provider.id)!.defaultModelId;
    expect((await repository.load()).model(defaultId), isNotNull);
  });

  test('fetchModels marks only transcription ids as chat', () async {
    final c = await controller(
      client: () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 'whisper-1'},
              {'id': 'gpt-4o'},
              {'id': 'GPT-4o-Transcribe'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final entries = await c.fetchModels(c.providers.first, 'k');
    final byId = {for (final e in entries) e.id: e.chat};
    expect(byId['whisper-1'], isTrue);
    expect(byId['GPT-4o-Transcribe'], isTrue);
    expect(byId['gpt-4o'], isFalse);
    expect(c.catalogModels(c.providers.first), isEmpty);
  });

  for (final size in const [Size(360, 690), Size(1400, 900)]) {
    testWidgets('online sources page fits $size', (tester) async {
      final library = (await tester.runAsync(() async {
        await TranscribeStorage.setStoragePath(null);
        return repository.load();
      }))!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(repository),
              settingsLibraryProvider.overrideWithValue(
                AsyncValue.data(library),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const OnlineSourcesPage(),
            ),
          ),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
