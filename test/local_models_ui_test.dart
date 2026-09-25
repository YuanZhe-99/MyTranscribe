/// Purpose: Test the local model page at each geometry: what it says about a
/// model's routes, and what it asks before downloading.
/// Inputs: None; the library, the installed packages and the routes come from
/// provider overrides.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Driven in Simplified Chinese for the reason given in
/// `test/shell_nav_ui_test.dart`. The wording checked is the promise of
/// decision D20: every route says whether it was tested on this kind of
/// device and what its check here found.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/engine_registry.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/local_model_templates.dart';
import 'package:my_transcribe/features/local/services/local_models_controller.dart';
import 'package:my_transcribe/features/local/views/local_model_page.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';

import 'golden/fake_local_asr_engine.dart';

/// The viewports the series checks every page at.
const geometries = <String, Size>{
  'phone portrait': Size(412, 915),
  'phone landscape': Size(915, 412),
  'Fold 8 portrait': Size(704, 933),
  'Fold 8 landscape': Size(933, 704),
  'tablet': Size(1280, 800),
  'desktop window': Size(1000, 720),
};

const _modelId = 'local:whisper-large-v3-turbo';
const _artifactId = 'whisper-large-v3-turbo-ggml';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final templates = buildLocalModelTemplates();
  final cpu = fakeRoute(
    adapterId: whisperCppAdapterId,
    modelId: _modelId,
    artifactId: _artifactId,
    testedHere: true,
    smokeTest: const SmokeTestSummary(
      SmokeTestOutcome.passed,
      realTimeFactor: 0.1,
    ),
  );
  final gpu = fakeRoute(
    adapterId: whisperCppAdapterId,
    modelId: _modelId,
    artifactId: _artifactId,
    device: ComputeDevice.gpu,
    backend: 'metal',
    evidence: EvidenceLevel.experimental,
    smokeTest: const SmokeTestSummary(SmokeTestOutcome.crashed),
  );

  /// Purpose: Open the page on the turbo model.
  /// Inputs: `tester`, the viewport `size`, and whether it is [installed].
  /// Returns: None.
  /// Side effects: Sets and restores the view size; pumps a tree.
  /// Notes: Internal helper used within this file only.
  Future<void> pumpPage(
    WidgetTester tester,
    Size size, {
    required bool installed,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final registry = EngineRegistry(
      engines: [
        FakeLocalAsrEngine(adapterId: whisperCppAdapterId, routes: const []),
      ],
      artifacts: ArtifactManager(
        modelsDir: () async => Directory.systemTemp,
      ),
      state: LocalEngineStateStore(
        file: () async => File('${Directory.systemTemp.path}/unused.json'),
      ),
    );
    final manifest = templateArtifact(_artifactId)!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          engineRegistryProvider.overrideWithValue(registry),
          settingsLibraryProvider.overrideWithValue(
            AsyncValue.data(
              SettingsLibrary(
                localModels: [for (final t in templates) t.model],
              ),
            ),
          ),
          installedArtifactsProvider.overrideWithValue(
            AsyncValue.data(
              installed
                  ? {
                      _artifactId: manifest.asInstalled(
                        const [],
                        DateTime.utc(2026, 9, 24),
                      ),
                    }
                  : const <String, ArtifactManifest>{},
            ),
          ),
          localRoutesProvider.overrideWithValue(
            AsyncValue.data(installed ? [cpu, gpu] : const []),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LocalModelPage(modelId: _modelId),
        ),
      ),
    );
    await tester.pump();
  }

  for (final entry in geometries.entries) {
    testWidgets('lays out a downloaded model at ${entry.key}', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpPage(tester, entry.value, installed: true);

      expect(find.text(l10n.localStateReady), findsOneWidget);
      // The routes may be below the fold of a short window.
      await tester.scrollUntilVisible(
        find.text(l10n.localRouteUntested),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.localRouteUntested), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('says what each route is and what its check found', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await pumpPage(tester, const Size(412, 915), installed: true);

    expect(find.text(l10n.localRouteCpu), findsOneWidget);
    expect(find.text(l10n.localRouteGpu('metal')), findsOneWidget);
    expect(find.text(l10n.localEvidenceExperimental), findsOneWidget);
    expect(
      find.text('${l10n.localCheckPassed} · ${l10n.localCheckSpeed('10')}'),
      findsOneWidget,
    );
    expect(find.text(l10n.localCheckCrashed), findsOneWidget);
    expect(find.text(l10n.localModelRemove), findsOneWidget);
  });

  testWidgets('names the size and the host before downloading', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await pumpPage(tester, const Size(412, 915), installed: false);

    expect(find.text(l10n.localStateNotDownloaded), findsOneWidget);
    expect(find.text(l10n.localModelRoutesNone), findsOneWidget);
    await tester.tap(find.text(l10n.localModelDownload));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('huggingface.co'),
      findsOneWidget,
      reason: 'the one host this model comes from',
    );
    // Cancelling contacts nothing.
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
