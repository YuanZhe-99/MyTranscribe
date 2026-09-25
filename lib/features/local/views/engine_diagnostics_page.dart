/// Purpose: What each local model can run on here, how well each route is
/// known, and what its check on this device found — and a report of it the
/// user can copy.
/// Inputs: The engine registry's routes, the library, the engine runtime.
/// Returns: A page under Settings.
/// Side effects: Runs a route's check when asked; copies text to the
/// clipboard when asked.
/// Notes: This is where "encoder on the GPU, decoder on the CPU" belongs,
/// never on a job page. The report names the device, the routes, their grades,
/// check outcomes and speeds — no file names, no paths, no transcript text —
/// and the app sends it nowhere (decision D20 of the local-models plan). See
/// `doc/en-us/features/local-models.md`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/services/settings_repository.dart';
import '../engines/whisper_cpp_engine.dart';
import '../models/engine_capability.dart';
import '../services/engine_registry.dart';
import '../services/local_models_controller.dart';
import '../services/tested_here.dart';
import 'local_text.dart';

/// The whisper.cpp runtime, once probed.
final whisperRuntimeProvider = FutureProvider<WhisperRuntimeInfo>(
  (ref) => ref.watch(whisperCppEngineProvider).runtime(),
);

class EngineDiagnosticsPage extends ConsumerWidget {
  /// Purpose: Create the page.
  /// Inputs: None.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const EngineDiagnosticsPage({super.key});

  /// Purpose: Build the page.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the runtime, the routes and the library.
  /// Notes: None.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final runtime = ref.watch(whisperRuntimeProvider).value;
    final routes = ref.watch(localRoutesProvider).value ?? const [];
    final library = ref.watch(settingsLibraryProvider).value;
    final busy = ref
        .watch(localModelsControllerProvider)
        .values
        .any((a) => a.busy);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsDiagnostics),
        actions: [
          IconButton(
            tooltip: l10n.diagnosticsCopyReport,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.diagnosticsDevice, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(
            [
              currentDeviceClass(),
              Platform.operatingSystemVersion,
              '${Platform.numberOfProcessors} CPU',
            ].join('\n'),
            style: muted,
          ),
          const SizedBox(height: 16),
          Text(l10n.diagnosticsEngine, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (runtime == null)
            const LinearProgressIndicator()
          else if (!runtime.loaded)
            Text('whisper.cpp — ${l10n.diagnosticsEngineMissing}')
          else ...[
            Text('whisper.cpp ${runtime.version}'),
            SelectableText(
              [
                runtime.systemInfo.trim(),
                for (final device in runtime.devices)
                  '${device.name}: ${device.description}',
              ].join('\n'),
              style: muted,
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.diagnosticsRoutes, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (routes.isEmpty) Text(l10n.localModelRoutesNone, style: muted),
          for (final route in routes)
            Card(
              child: ListTile(
                title: Text(
                  '${library?.localModel(route.modelId)?.displayName ?? route.modelId}'
                  ' · ${routeLabel(l10n, route)}',
                ),
                subtitle: Text(
                  [
                    route.testedHere
                        ? l10n.localRouteTested
                        : l10n.localRouteUntested,
                    '${evidenceLabel(l10n, route.evidence)} '
                        '(${route.evidence.letter})',
                    if (!route.available)
                      l10n.localRouteUnavailable(route.unavailableReason ?? '—')
                    else
                      checkLabel(l10n, route.smokeTest),
                    ?speedLabel(l10n, route.smokeTest),
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: route.available
                    ? TextButton(
                        onPressed: busy || library == null
                            ? null
                            : () {
                                final model = library.localModel(route.modelId);
                                if (model == null) return;
                                ref
                                    .read(
                                      localModelsControllerProvider.notifier,
                                    )
                                    .check(model, route);
                              },
                        child: Text(l10n.localCheckNow),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  /// Purpose: Copy the diagnostics report to the clipboard.
  /// Inputs: `context`, `ref`.
  /// Returns: None.
  /// Side effects: Writes the clipboard; shows a message.
  /// Notes: Internal helper used within this file only.
  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final report = diagnosticsReport(
      deviceClass: currentDeviceClass(),
      osVersion: Platform.operatingSystemVersion,
      processors: Platform.numberOfProcessors,
      runtime: ref.read(whisperRuntimeProvider).value,
      routes: ref.read(localRoutesProvider).value ?? const [],
    );
    await Clipboard.setData(ClipboardData(text: report));
    messenger.showSnackBar(SnackBar(content: Text(l10n.diagnosticsCopied)));
  }
}

/// Purpose: Build the text of a diagnostics report.
/// Inputs: The device's class, OS version and processor count; the engine
/// runtime; the routes.
/// Returns: Plain text, one fact per line.
/// Side effects: None.
/// Notes: Pure, so the promise about what it leaves out is tested: model ids
/// and route keys name the package, never a file or a folder, and a failed
/// check contributes its outcome and not its reason, which can quote a path.
String diagnosticsReport({
  required String deviceClass,
  required String osVersion,
  required int processors,
  required WhisperRuntimeInfo? runtime,
  required List<EngineRoute> routes,
}) {
  final lines = <String>[
    'MyTranscribe!!!!! local engine report',
    'device: $deviceClass',
    'os: $osVersion',
    'processors: $processors',
    if (runtime == null)
      'whisper.cpp: not probed'
    else if (!runtime.loaded)
      'whisper.cpp: not built for this device'
    else ...[
      'whisper.cpp: ${runtime.version}',
      'system: ${runtime.systemInfo.trim()}',
      for (final device in runtime.devices)
        'compute device: ${device.name} (${device.description})',
    ],
    for (final route in routes)
      [
        'route: ${route.modelId} ${route.adapterId} ${route.backend}',
        'grade ${route.evidence.letter}',
        route.testedHere ? 'tested here' : 'not tested here',
        route.available ? 'available' : 'unavailable',
        'check ${route.smokeTest.outcome.name}',
        if (route.smokeTest.realTimeFactor case final rtf?)
          'rtf ${rtf.toStringAsFixed(3)}',
      ].join(', '),
  ];
  return lines.join('\n');
}
