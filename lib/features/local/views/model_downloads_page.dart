import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_ai_local_ui/myapps_ai_local_ui.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart' as shared;

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/byte_format.dart';
import '../../providers/services/settings_repository.dart';
import '../services/engine_registry.dart';
import '../services/local_models_controller.dart';
import 'local_model_page.dart';

/// Shared downloadable artifact list with application record and check navigation.
class ModelDownloadsPage extends ConsumerStatefulWidget {
  /// Purpose: Create downloads page. Inputs: None. Returns: Page.
  /// Side effects: None. Notes: Records remain in the source-management page.
  const ModelDownloadsPage({super.key});

  /// Purpose: Create state. Inputs: None. Returns: State.
  /// Side effects: None. Notes: Owns status subscriptions.
  @override
  ConsumerState<ModelDownloadsPage> createState() => _ModelDownloadsPageState();
}

class _ModelDownloadsPageState extends ConsumerState<ModelDownloadsPage> {
  final Map<String, StreamSubscription<shared.ArtifactStatus>> _subscriptions =
      {};

  /// Purpose: Release observations. Inputs: None. Returns: None.
  /// Side effects: Cancels subscriptions. Notes: Does not cancel requested downloads.
  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  /// Purpose: Render shared model tiles. Inputs: context. Returns: Page.
  /// Side effects: Observes installed state. Notes: Actions remain explicit.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final library = ref.watch(settingsLibraryProvider).value;
    final manager = ref.read(artifactManagerProvider).sharedManager;
    final controller = ref.read(localModelsControllerProvider.notifier);
    final labels = MyAppsLocalModelLabels(
      modelName: (entry) =>
          library?.localModel(entry.modelId)?.displayName ?? entry.modelId,
      state: (state) => switch (state) {
        shared.ModelInstallState.installed => l.localStateReady,
        shared.ModelInstallState.downloading => l.localStateDownloading('…'),
        shared.ModelInstallState.verifying => l.localStateChecking,
        shared.ModelInstallState.failed ||
        shared.ModelInstallState.corrupt => l.localModelVerifyBad,
        shared.ModelInstallState.unknown => l.localStateNoEngine,
        shared.ModelInstallState.notInstalled => l.localStateNotDownloaded,
      },
      action: (action) => switch (action) {
        shared.ModelAction.download => l.localModelDownload,
        shared.ModelAction.cancel ||
        shared.ModelAction.pauseResume => l.localModelCancel,
        shared.ModelAction.verify => l.localModelVerify,
        shared.ModelAction.remove => l.localModelRemove,
      },
      failure: (_) => l.localModelVerifyBad,
      progress: (fraction, _) => fraction == null
          ? l.localStateChecking
          : '${(fraction * 100).round()}%',
      systemManaged: l.localStateNoEngine,
      removeTitle: l.localModelRemoveBody,
      removeBody: l.localDownloadRemoveNotice,
      removeConfirm: l.localModelRemove,
      storage: (used, _) => used ?? '',
      empty: l.libraryEmptyBody,
      actionFailed: l.localModelVerifyBad,
      cancel: l.cancel,
    );
    final tiles = <Widget>[];
    for (final model in library?.localModels ?? []) {
      for (final manifest in controller.downloadableFor(model)) {
        _subscriptions.putIfAbsent(
          manifest.artifactId,
          () => manager.watch(manifest.artifactId).listen((_) {
            if (mounted) setState(() {});
          }),
        );
        final entry = shared.ModelCatalogEntry.forArtifact(
          manifest: shared.ArtifactManifest.fromJson(manifest.toJson()),
          status: manager.statusOf(manifest.artifactId),
          platform: manager.platform,
          capability: 'asr',
          leased: manager.isLeased(manifest.artifactId),
        );
        tiles.add(
          MyAppsLocalModelTile(
            entry: entry,
            labels: labels,
            formatBytes: formatBytes,
            onAction: (action) async {
              if (action == shared.ModelAction.cancel) {
                controller.cancel(model);
                return;
              }
              if (action == shared.ModelAction.verify) {
                await controller.verify(model);
                await manager.refresh(manifest.artifactId);
                return;
              }
              final removing = action == shared.ModelAction.remove;
              final confirmed =
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        removing
                            ? l.localModelRemove
                            : l.localModelDownloadTitle(model.displayName),
                      ),
                      content: Text(
                        removing
                            ? l.localDownloadRemoveNotice
                            : l.localModelDownloadBody(
                                formatBytes(manifest.downloadBytesFor()),
                                manifest.files
                                    .map(
                                      (file) =>
                                          Uri.tryParse(file.sourceUrl)?.host ??
                                          '',
                                    )
                                    .toSet()
                                    .join(', '),
                              ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            removing
                                ? l.localModelRemove
                                : l.localModelDownload,
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirmed) return;
              if (removing) {
                await controller.remove(model);
              } else {
                await controller.download(model);
              }
              await manager.refresh(manifest.artifactId);
            },
          ),
        );
        tiles.add(
          ListTile(
            title: Text(l.localModelRoutes),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalModelPage(modelId: model.id),
                ),
              );
              await manager.refresh(manifest.artifactId);
            },
          ),
        );
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsLocalModels)),
      body: ListView(
        children: tiles.isEmpty
            ? [ListTile(title: Text(l.libraryEmptyBody))]
            : tiles,
      ),
    );
  }
}
