/// Purpose: The library tab — the services the app can use, and the models each
/// one offers.
/// Inputs: `settingsLibraryProvider` for the records, and
/// `configuredProvidersProvider` for which sources have a key.
/// Returns: A shell page; on a wide window it hosts its own editor pane.
/// Side effects: None directly; the editors it opens write settings and keys.
/// Notes: The list is grouped by source with its models indented under it,
/// which is why its pane is wider than the jobs list's — it carries two levels
/// of text. See `doc/en-us/features/provider-library.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../local/services/local_models_controller.dart';
import '../../local/views/local_model_page.dart';
import '../../local/views/local_text.dart';
import '../../secrets/services/secrets_store.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import '../widgets/add_source_sheet.dart';
import '../services/settings_repository.dart';
import 'model_editor_page.dart';
import 'provider_editor_page.dart';

/// What the editor pane is showing.
sealed class LibrarySelection {
  /// Purpose: Allow subclasses only.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: None.
  const LibrarySelection();
}

/// A source is selected.
class ProviderSelection extends LibrarySelection {
  /// Its record id.
  final String providerId;

  /// Purpose: Select a source.
  /// Inputs: [providerId].
  /// Returns: A new selection.
  /// Side effects: None.
  /// Notes: The id rather than the record, so the pane always renders the
  /// current version after an edit rather than a stale copy.
  const ProviderSelection(this.providerId);
}

/// A model is selected.
class ModelSelection extends LibrarySelection {
  /// Its record id.
  final String modelId;

  /// Purpose: Select a model.
  /// Inputs: [modelId].
  /// Returns: A new selection.
  /// Side effects: None.
  /// Notes: See [ProviderSelection].
  const ModelSelection(this.modelId);
}

/// A local model is open.
class LocalModelSelection extends LibrarySelection {
  /// The local model's id.
  final String modelId;

  /// Purpose: Create the selection.
  /// Inputs: [modelId].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LocalModelSelection(this.modelId);
}

class LibraryPage extends ConsumerStatefulWidget {
  /// Purpose: Create a library page instance.
  /// Inputs: None.
  /// Returns: A new `LibraryPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const LibraryPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  /// What the editor pane is showing, or null for the empty state.
  LibrarySelection? _selection;

  /// Whether this build is rendering two panes.
  bool _twoPane = false;

  /// Purpose: Open a source or model, in the pane or as a pushed route.
  /// Inputs: [selection].
  /// Returns: None.
  /// Side effects: Sets state or pushes a route.
  /// Notes: Internal helper used within this file only. The same widget serves
  /// both, so the two cannot drift.
  void _open(LibrarySelection selection) {
    if (_twoPane) {
      setState(() => _selection = selection);
      return;
    }
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => _editor(selection)));
  }

  /// Purpose: Build the editor for a selection.
  /// Inputs: [selection].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _editor(LibrarySelection selection) => switch (selection) {
    ProviderSelection(:final providerId) => ProviderEditorPage(
      providerId: providerId,
    ),
    ModelSelection(:final modelId) => ModelEditorPage(modelId: modelId),
    LocalModelSelection(:final modelId) => LocalModelPage(modelId: modelId),
  };

  /// Purpose: Build the library tab.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the library and which sources have a key.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    _twoPane = useLibraryTwoPane(screen.width, screen.height);

    final list = _buildList(l10n);
    if (!_twoPane) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        body: list,
        floatingActionButton: _addButton(l10n),
      );
    }

    final contentWidth = shellContentWidth(screen.width);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.libraryTitle)),
      body: Row(
        children: [
          SizedBox(width: libraryListPaneWidth(contentWidth), child: list),
          const VerticalDivider(width: 1),
          Expanded(child: _buildEditorPane(l10n)),
        ],
      ),
      floatingActionButton: _addButton(l10n),
    );
  }

  /// Purpose: Build the button that adds a source.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _addButton(AppLocalizations l10n) => FloatingActionButton.extended(
    onPressed: _addSource,
    icon: const Icon(Icons.add),
    label: Text(l10n.libraryAddSource),
  );

  /// Purpose: Add a source from one of the starter presets.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and opens the new source's editor.
  /// Notes: Internal helper used within this file only. The new record is saved
  /// immediately and then opened, rather than being built in a dialog and saved
  /// at the end: an address and a key are enough to get going, and the editor
  /// is where the rest belongs anyway.
  Future<void> _addSource() async {
    final preset = await showAddSourceSheet(context);
    if (preset == null || !mounted) return;

    final repository = ref.read(settingsRepositoryProvider);
    final id = repository.newProviderId();
    final provider = ProviderConfig(
      id: id,
      name: preset.template.name.isEmpty ? preset.label : preset.template.name,
      dialect: preset.template.dialect,
      baseUrl: preset.template.baseUrl,
      authScheme: preset.template.authScheme,
      maxFileBytes: preset.template.maxFileBytes,
      requestTimeoutSeconds: preset.template.requestTimeoutSeconds,
    );
    await repository.saveProvider(provider);

    if (preset.model case final model?) {
      final modelId = repository.newModelId();
      await repository.saveModel(
        ModelConfig(
          id: modelId,
          providerId: id,
          modelName: model.modelName,
          displayName: model.displayName,
          maxFileBytes: model.maxFileBytes,
          segmentTimestamps: model.segmentTimestamps,
          responseFormats: model.responseFormats,
        ),
      );
      await repository.saveProvider(
        provider.copyWith(defaultModelId: modelId, markOverridden: false),
      );
    }

    ref.refresh(settingsLibraryProvider);
    if (mounted) _open(ProviderSelection(id));
  }

  /// Purpose: Build the grouped list of sources and their models.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildList(AppLocalizations l10n) {
    final library = ref.watch(settingsLibraryProvider);
    final configured = ref.watch(configuredProvidersProvider).value ?? const {};

    return library.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: l10n.libraryEmptyTitle,
        body: '$error',
      ),
      data: (data) {
        if (data.isEmpty && data.localModels.isEmpty) {
          return EmptyState(
            icon: Icons.library_books_outlined,
            title: l10n.libraryEmptyTitle,
            body: l10n.libraryEmptyBody,
          );
        }
        return ListView(
          padding: EdgeInsets.only(
            bottom: shellListBottomInset(MediaQuery.sizeOf(context).width) + 72,
          ),
          children: [
            if (data.localModels.isNotEmpty) ..._thisDeviceSection(l10n, data),
            for (final provider in data.providers)
              ..._sourceSection(
                l10n,
                provider,
                data.modelsOf(provider.id),
                hasKey: configured.contains(provider.id),
              ),
          ],
        );
      },
    );
  }

  /// Purpose: Build the section of models that run on this device.
  /// Inputs: [l10n], the library [data].
  /// Returns: The rows.
  /// Side effects: Watches the installed packages and the download state.
  /// Notes: Internal helper used within this file only. Above the sources,
  /// because a model already on the device is the one that needs no key and no
  /// network. Each row says its state here — downloaded or not, downloading,
  /// checking — which is a fact about this device, not about the library.
  List<Widget> _thisDeviceSection(AppLocalizations l10n, SettingsLibrary data) {
    final installed = ref.watch(installedArtifactsProvider).value ?? const {};
    final activity = ref.watch(localModelsControllerProvider);
    final controller = ref.read(localModelsControllerProvider.notifier);
    return [
      ListTile(
        leading: const Icon(Icons.memory_outlined),
        title: Text(l10n.libraryThisDevice),
        subtitle: Text(l10n.libraryThisDeviceSubtitle),
      ),
      for (final model in data.localModels)
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: ListTile(
            dense: true,
            leading: Icon(
              model.artifactIds.any(installed.containsKey)
                  ? Icons.download_done_outlined
                  : Icons.cloud_download_outlined,
              size: 20,
            ),
            title: Text(model.displayName),
            subtitle: Text(
              localModelStateLabel(
                l10n,
                model,
                installed: model.artifactIds.any(installed.containsKey),
                canRun:
                    controller.downloadableFor(model).isNotEmpty ||
                    model.artifactIds.any(installed.containsKey),
                activity: activity[model.id],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            selected:
                _twoPane &&
                _selection is LocalModelSelection &&
                (_selection! as LocalModelSelection).modelId == model.id,
            onTap: () => _open(LocalModelSelection(model.id)),
          ),
        ),
      const Divider(height: 1),
    ];
  }

  /// Purpose: Build one source header and its models.
  /// Inputs: [l10n], [provider], [models], whether it [hasKey].
  /// Returns: The rows.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A source that needs a
  /// key and has none is marked, because that is the single most common reason
  /// a transcription fails and the one thing the list can warn about before it
  /// happens.
  List<Widget> _sourceSection(
    AppLocalizations l10n,
    ProviderConfig provider,
    List<ModelConfig> models, {
    required bool hasKey,
  }) {
    final theme = Theme.of(context);
    final needsKey = provider.needsApiKey && !hasKey;
    return [
      ListTile(
        leading: Icon(
          needsKey ? Icons.key_off_outlined : Icons.cloud_outlined,
          color: needsKey ? theme.colorScheme.error : null,
        ),
        title: Text(provider.name),
        subtitle: Text(
          needsKey
              ? '${l10n.libraryApiKeyMissing} · ${l10n.libraryModelsCount(models.length)}'
              : l10n.libraryModelsCount(models.length),
          style: needsKey ? TextStyle(color: theme.colorScheme.error) : null,
        ),
        trailing: const Icon(Icons.chevron_right),
        selected:
            _twoPane &&
            _selection is ProviderSelection &&
            (_selection! as ProviderSelection).providerId == provider.id,
        onTap: () => _open(ProviderSelection(provider.id)),
      ),
      for (final model in models)
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.graphic_eq_outlined, size: 20),
            title: Text(model.displayName),
            subtitle: Text(model.modelName),
            trailing: _modelBadges(model),
            selected:
                _twoPane &&
                _selection is ModelSelection &&
                (_selection! as ModelSelection).modelId == model.id,
            onTap: () => _open(ModelSelection(model.id)),
          ),
        ),
      const Divider(height: 1),
    ];
  }

  /// Purpose: Show at a glance what a model can do.
  /// Inputs: [model].
  /// Returns: A small row of icons, or nothing when it has no notable feature.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Only *supported* shows
  /// an icon. An unknown capability deliberately shows nothing here — a badge
  /// for "we are not sure" in a list would be noise, and the editor says so
  /// properly.
  Widget? _modelBadges(ModelConfig model) {
    final theme = Theme.of(context);
    final icons = <IconData>[
      if (model.diarization == Capability.supported) Icons.groups_outlined,
      if (model.segmentTimestamps == Capability.supported)
        Icons.schedule_outlined,
    ];
    if (icons.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final icon in icons)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(icon, size: 18, color: theme.colorScheme.outline),
          ),
      ],
    );
  }

  /// Purpose: Build the editor pane beside the list.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The editor is hosted in
  /// a nested `Navigator` holding one route, which reports `canPop == false` so
  /// it grows no back arrow.
  Widget _buildEditorPane(AppLocalizations l10n) {
    final selection = _selection;
    if (selection == null) {
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.librarySelectItem,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return Navigator(
      key: ValueKey(switch (selection) {
        ProviderSelection(:final providerId) => providerId,
        ModelSelection(:final modelId) => modelId,
        LocalModelSelection(:final modelId) => modelId,
      }),
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => _editor(selection)),
    );
  }
}
