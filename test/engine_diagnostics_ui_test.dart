/// Purpose: Test the diagnostics page at each geometry, and hold the copied
/// report to its promise: no file names, no paths, no transcript text.
/// Inputs: None; the runtime, the routes and the library come from provider
/// overrides.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Driven in Simplified Chinese for the reason given in
/// `test/shell_nav_ui_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_asr_whisper/local_asr_whisper.dart';
import 'package:my_transcribe/features/local/engines/whisper_cpp_engine.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/local_model_templates.dart';
import 'package:my_transcribe/features/local/services/local_models_controller.dart';
import 'package:my_transcribe/features/local/views/engine_diagnostics_page.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';

import 'golden/fake_local_asr_engine.dart';
import 'local_models_ui_test.dart' show geometries;

const _runtime = WhisperRuntimeInfo(
  loaded: true,
  version: '1.9.4',
  systemInfo: 'CPU : NEON = 1 | ARM_FMA = 1 | DOTPROD = 1',
  devices: [WhisperDevice('CPU', 'Snapdragon Compute Platform', 0)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final routes = [
    fakeRoute(
      adapterId: whisperCppAdapterId,
      modelId: 'local:whisper-large-v3-turbo',
      artifactId: 'whisper-large-v3-turbo-ggml',
      testedHere: true,
      smokeTest: const SmokeTestSummary(
        SmokeTestOutcome.failed,
        realTimeFactor: 0.2,
        reason: r'MODEL_MISSING: C:\Users\someone\models\ggml.bin',
      ),
    ),
  ];

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          whisperRuntimeProvider.overrideWithValue(
            const AsyncValue.data(_runtime),
          ),
          localRoutesProvider.overrideWithValue(AsyncValue.data(routes)),
          settingsLibraryProvider.overrideWithValue(
            AsyncValue.data(
              SettingsLibrary(
                localModels: [
                  for (final t in buildLocalModelTemplates()) t.model,
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: EngineDiagnosticsPage(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final entry in geometries.entries) {
    testWidgets('lays out at ${entry.key}', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpPage(tester, entry.value);

      expect(find.text('whisper.cpp 1.9.4'), findsOneWidget);
      expect(find.textContaining(l10n.localRouteTested), findsOneWidget);
      expect(find.byTooltip(l10n.diagnosticsCopyReport), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('the report names routes and results, never a path', () {
    final report = diagnosticsReport(
      deviceClass: 'windows-arm64-qualcomm',
      osVersion: 'Windows 11',
      processors: 8,
      runtime: _runtime,
      routes: routes,
    );
    expect(report, contains('device: windows-arm64-qualcomm'));
    expect(report, contains('whisper.cpp: 1.9.4'));
    expect(
      report,
      contains(
        'route: local:whisper-large-v3-turbo whisper_cpp cpu, grade A, '
        'tested here, available, check failed, rtf 0.200',
      ),
    );
    expect(report, isNot(contains(r'C:\')), reason: 'no path from a reason');
    expect(report, isNot(contains('ggml.bin')), reason: 'no file name');
  });
}
