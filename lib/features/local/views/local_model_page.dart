/// Purpose: One local model on this device: what it is, whether it is here,
/// and every route it could run on, each with its check.
/// Inputs: The model's id.
/// Returns: A page, shown in the library's pane or pushed on a phone.
/// Side effects: Downloads, removes, verifies and checks, when asked.
/// Notes: Every route says in plain words whether it was tested on this kind
/// of device and whether it passed its check here (decision D20 of the
/// local-models plan). A download names its size and its host before it
/// starts. See `doc/en-us/features/local-models.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/byte_format.dart';
import '../../providers/models/model_config.dart';
import '../../providers/services/settings_repository.dart';
import '../models/engine_capability.dart';
import '../models/local_model_config.dart';
import '../services/local_models_controller.dart';
import 'local_text.dart';

class LocalModelPage extends ConsumerWidget {
  /// The model shown.
  final String modelId;

  /// Purpose: Create the page.
  /// Inputs: [modelId].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const LocalModelPage({super.key, required this.modelId});

  /// Purpose: Build the page.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the library, the installed packages, the routes
  /// and the controller.
  /// Notes: None.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final model = ref.watch(settingsLibraryProvider).value?.localModel(modelId);
    if (model == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final controller = ref.read(localModelsControllerProvider.notifier);
    final activity = ref.watch(localModelsControllerProvider)[model.id];
    final installed = ref.watch(installedArtifactsProvider).value ?? const {};
    final routes = [
      for (final route
          in ref.watch(localRoutesProvider).value ?? const <EngineRoute>[])
        if (route.modelId == model.id) route,
    ];
    final downloads = controller.downloadableFor(model);
    final isInstalled = model.artifactIds.any(installed.containsKey);
    final canRun = downloads.isNotEmpty || isInstalled;
    final size = downloads.fold<int>(0, (s, m) => s + m.downloadBytesFor());

    return Scaffold(
      appBar: AppBar(title: Text(model.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            localModelStateLabel(
              l10n,
              model,
              installed: isInstalled,
              canRun: canRun,
              activity: activity,
            ),
            style: theme.textTheme.titleMedium,
          ),
          if (activity?.progress case final progress?) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.fraction),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (activity?.progress != null)
                OutlinedButton(
                  onPressed: () => controller.cancel(model),
                  child: Text(l10n.localModelCancel),
                )
              else if (!isInstalled && downloads.isNotEmpty)
                FilledButton.icon(
                  onPressed: activity?.busy ?? false
                      ? null
                      : () => _confirmDownload(context, ref, model, size),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l10n.localModelDownload),
                ),
              if (isInstalled && !(activity?.busy ?? false)) ...[
                OutlinedButton(
                  onPressed: () => _verify(context, ref, model),
                  child: Text(l10n.localModelVerify),
                ),
                OutlinedButton(
                  onPressed: () => _confirmRemove(context, ref, model),
                  child: Text(l10n.localModelRemove),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _Field(l10n.localModelSize, size > 0 ? formatBytes(size) : '—'),
          _Field(
            l10n.localModelLanguages,
            model.languages.isEmpty
                ? l10n.localModelLanguagesAny
                : model.languages.join(', '),
          ),
          _Field(
            l10n.localModelTimestamps,
            model.segmentTimestamps == Capability.supported ? '✓' : '—',
          ),
          if (downloads.firstOrNull case final manifest?)
            _Field(
              l10n.localModelLicence,
              [
                manifest.licenseId,
                if (manifest.attribution.isNotEmpty) manifest.attribution,
              ].join(' · '),
            ),
          const SizedBox(height: 24),
          Text(l10n.localModelRoutes, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (routes.isEmpty)
            Text(
              l10n.localModelRoutesNone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final route in routes)
            _RouteCard(
              route: route,
              busy: activity?.busy ?? false,
              onCheck: () => controller.check(model, route),
            ),
        ],
      ),
    );
  }

  /// Purpose: Ask before downloading, naming the size and the host.
  /// Inputs: `context`, `ref`, the [model], the download [size].
  /// Returns: None.
  /// Side effects: Starts the download when confirmed.
  /// Notes: Internal helper used within this file only. The app contacts a
  /// model host only on this confirmation.
  Future<void> _confirmDownload(
    BuildContext context,
    WidgetRef ref,
    LocalModelConfig model,
    int size,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(localModelsControllerProvider.notifier);
    final hosts = {
      for (final manifest in controller.downloadableFor(model))
        for (final file in manifest.filesFor()) Uri.parse(file.sourceUrl).host,
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.localModelDownloadTitle(model.displayName)),
        content: Text(
          l10n.localModelDownloadBody(formatBytes(size), hosts.join(', ')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.localModelDownload),
          ),
        ],
      ),
    );
    if (ok ?? false) await controller.download(model);
  }

  /// Purpose: Ask before removing the model's files.
  /// Inputs: `context`, `ref`, the [model].
  /// Returns: None.
  /// Side effects: Removes the packages when confirmed.
  /// Notes: Internal helper used within this file only.
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    LocalModelConfig model,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.localModelRemoveBody(model.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.localModelRemove),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(localModelsControllerProvider.notifier).remove(model);
    }
  }

  /// Purpose: Hash the installed files and say whether they are intact.
  /// Inputs: `context`, `ref`, the [model].
  /// Returns: None.
  /// Side effects: Reads the files; shows a message.
  /// Notes: Internal helper used within this file only.
  Future<void> _verify(
    BuildContext context,
    WidgetRef ref,
    LocalModelConfig model,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(localModelsControllerProvider.notifier)
        .verify(model);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? l10n.localModelVerifyOk : l10n.localModelVerifyBad),
      ),
    );
  }
}

/// One route: what it is, how well it is known, and its check here.
class _RouteCard extends StatelessWidget {
  /// The route.
  final EngineRoute route;

  /// Whether something is running, which disables the check button.
  final bool busy;

  /// Runs the check.
  final VoidCallback onCheck;

  /// Purpose: Create the card.
  /// Inputs: All fields.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _RouteCard({
    required this.route,
    required this.busy,
    required this.onCheck,
  });

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final speed = speedLabel(l10n, route.smokeTest);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(routeLabel(l10n, route), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              route.testedHere
                  ? l10n.localRouteTested
                  : l10n.localRouteUntested,
              style: muted,
            ),
            Text(evidenceLabel(l10n, route.evidence), style: muted),
            const SizedBox(height: 4),
            if (!route.available)
              Text(
                l10n.localRouteUnavailable(route.unavailableReason ?? '—'),
                style: TextStyle(color: theme.colorScheme.error),
              )
            else
              Text([checkLabel(l10n, route.smokeTest), ?speed].join(' · ')),
            if (route.available)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: busy ? null : onCheck,
                  child: Text(l10n.localCheckNow),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label and its value.
class _Field extends StatelessWidget {
  /// The label.
  final String label;

  /// The value.
  final String value;

  /// Purpose: Create a field row.
  /// Inputs: [label], [value].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _Field(this.label, this.value);

  /// Purpose: Build the row.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
