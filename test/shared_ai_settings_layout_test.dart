import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/engine_registry.dart';
import 'package:my_transcribe/features/local/views/model_downloads_page.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/providers/views/online_sources_page.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const geometries = [
    Size(360, 800),
    Size(412, 915),
    Size(915, 412),
    Size(704, 933),
    Size(933, 704),
    Size(1280, 800),
    Size(1000, 720),
  ];
  for (final size in geometries) {
    testWidgets('shared source and downloads pages fit $size', (tester) async {
      final root = Directory.systemTemp.createTempSync('transcribe_ai_layout');
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root.path);
      final repository = SettingsRepository();
      final library = (await tester.runAsync(() async {
        await TranscribeStorage.setStoragePath(null);
        return repository.load();
      }))!;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() async {
        tester.view.reset();
        PathProviderPlatform.instance = previous;
        await root.delete(recursive: true);
      });
      for (final page in [
        const OnlineSourcesPage(),
        const ModelDownloadsPage(),
      ]) {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                settingsRepositoryProvider.overrideWithValue(repository),
                settingsLibraryProvider.overrideWithValue(
                  AsyncValue.data(library),
                ),
                artifactManagerProvider.overrideWithValue(
                  ArtifactManager(
                    modelsDir: () async => Directory('${root.path}/models'),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                home: page,
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
      }
    });
  }
}
