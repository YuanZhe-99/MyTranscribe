/// Purpose: Edit one source — its address, how to authenticate, and its key.
/// Inputs: The source's record id.
/// Returns: A page; hosted in the library's editor pane on a wide window.
/// Side effects: Writes the settings file and the keys file.
/// Notes: The key is edited here but stored elsewhere: it goes into
/// `transcribe_secrets.json`, which is not part of any data module, so it never
/// reaches a backup or a ZIP export. See
/// `doc/en-us/features/secure-secrets-sync.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../secrets/services/secrets_store.dart';
import '../models/model_config.dart';
import '../models/provider_config.dart';
import '../services/model_catalog_fetcher.dart';
import '../services/settings_repository.dart';
import '../widgets/api_key_field.dart';

class ProviderEditorPage extends ConsumerStatefulWidget {
  /// Which source to edit.
  final String providerId;

  /// Purpose: Create the source editor.
  /// Inputs: [providerId].
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const ProviderEditorPage({super.key, required this.providerId});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<ProviderEditorPage> createState() => _ProviderEditorPageState();
}

class _ProviderEditorPageState extends ConsumerState<ProviderEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _headerName = TextEditingController();

  /// The source as loaded, before any edit.
  ProviderConfig? _original;

  /// The authentication scheme currently selected.
  AuthScheme _authScheme = AuthScheme.bearer;

  /// Whether the fields have been filled from the record yet.
  bool _loaded = false;

  /// Whether a model list is being fetched.
  bool _importing = false;

  /// Purpose: Release the text controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controllers.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _headerName.dispose();
    super.dispose();
  }

  /// Purpose: Fill the fields from the record, once.
  /// Inputs: [provider].
  /// Returns: None.
  /// Side effects: Sets the controllers and the scheme.
  /// Notes: Internal helper used within this file only. Guarded by [_loaded]
  /// so a rebuild — which happens whenever the library provider refreshes —
  /// never overwrites what the user is halfway through typing.
  void _fill(ProviderConfig provider) {
    if (_loaded) return;
    _loaded = true;
    _original = provider;
    _name.text = provider.name;
    _baseUrl.text = provider.baseUrl;
    _headerName.text = provider.authHeaderName ?? '';
    _authScheme = provider.authScheme;
  }

  /// Purpose: Save the edited source.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and refreshes the library.
  /// Notes: Internal helper used within this file only. Every changed field is
  /// marked as overridden by `copyWith`, which is what protects it from a later
  /// template refresh.
  Future<void> _save() async {
    final original = _original;
    if (original == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final updated = original.copyWith(
      name: _name.text.trim(),
      baseUrl: _baseUrl.text.trim(),
      authScheme: _authScheme,
      authHeaderName: _authScheme == AuthScheme.header
          ? _headerName.text.trim()
          : null,
      clearAuthHeaderName: _authScheme != AuthScheme.header,
    );

    await ref.read(settingsRepositoryProvider).saveProvider(updated);
    ref.refresh(settingsLibraryProvider);
    if (!mounted) return;
    _original = updated;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsWebDAVConfigSaved)),
    );
  }

  /// Purpose: Put this source back to its built-in values.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and reloads the fields.
  /// Notes: Internal helper used within this file only. Confirmed first,
  /// because it silently discards every change the user made to this record.
  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryResetToTemplate),
        content: Text(l10n.backupRestoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(settingsRepositoryProvider)
        .resetToTemplate(widget.providerId);
    ref.refresh(settingsLibraryProvider);
    if (mounted) setState(() => _loaded = false);
  }

  /// Purpose: Ask the source what models it offers and add the chosen ones.
  /// Inputs: [provider].
  /// Returns: None.
  /// Side effects: One HTTP request; may write several model records.
  /// Notes: Internal helper used within this file only. Models already in the
  /// library are shown but not offered again, so importing twice does not
  /// duplicate them. Capabilities come from a built-in template or stay
  /// unknown — see `model_catalog_fetcher.dart` for why nothing is guessed.
  Future<void> _importModels(ProviderConfig provider) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(settingsRepositoryProvider);
    final existing = {
      for (final model
          in ref.read(settingsLibraryProvider).value?.modelsOf(provider.id) ??
              const <ModelConfig>[])
        model.modelName,
    };

    setState(() => _importing = true);
    List<CatalogEntry> entries;
    try {
      entries = await ModelCatalogFetcher().fetch(
        provider,
        apiKey: await SecretsStore.keyFor(provider.id),
      );
    } on CatalogException catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted) return;

    final available = [
      for (final entry in entries)
        if (!existing.contains(entry.modelName)) entry,
    ];
    if (available.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.libraryNoNewModels)));
      return;
    }

    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _ModelPickerDialog(entries: available),
    );
    if (chosen == null || chosen.isEmpty) return;

    for (final entry in available) {
      if (!chosen.contains(entry.modelName)) continue;
      await repository.saveModel(
        modelFromCatalog(entry, provider, repository.newModelId()),
      );
    }
    ref.refresh(settingsLibraryProvider);
  }

  /// Purpose: Delete this source and its models.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file, clears the stored key, and leaves
  /// the editor.
  /// Notes: Internal helper used within this file only. The key is cleared too,
  /// because a key for a source that no longer exists can never be used and
  /// leaving it behind would keep syncing a live credential for nothing.
  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.libraryDeleteSource),
        content: Text(l10n.libraryDeleteSourceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await SecretsStore.setKey(widget.providerId, null);
    await ref
        .read(settingsRepositoryProvider)
        .deleteProvider(widget.providerId);
    ref.refresh(settingsLibraryProvider);
    ref.refresh(configuredProvidersProvider);
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// Purpose: Add an empty model to this source.
  /// Inputs: [provider].
  /// Returns: None.
  /// Side effects: Writes a model record.
  /// Notes: Internal helper used within this file only. For a service whose
  /// model list cannot be fetched, which is common for a self-hosted server.
  Future<void> _addModel(ProviderConfig provider) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.saveModel(
      ModelConfig(
        id: repository.newModelId(),
        providerId: provider.id,
        modelName: 'whisper-1',
        maxFileBytes: provider.maxFileBytes,
      ),
    );
    ref.refresh(settingsLibraryProvider);
  }

  /// Purpose: Build the source editor.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the library.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(settingsLibraryProvider);
    final provider = library.value?.provider(widget.providerId);

    if (provider == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _fill(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.name),
        actions: [
          if (_importing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'import' => _importModels(provider),
              'add-model' => _addModel(provider),
              'reset' => _reset(),
              _ => _delete(),
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'import',
                child: Text(l10n.libraryImportModels),
              ),
              PopupMenuItem(
                value: 'add-model',
                child: Text(l10n.libraryAddModel),
              ),
              if (provider.templateId != null)
                PopupMenuItem(
                  value: 'reset',
                  child: Text(l10n.libraryResetToTemplate),
                ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.libraryDeleteSource,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: pageMaxContentWidth),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.libraryName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? l10n.libraryName : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.libraryBaseUrl,
                    border: const OutlineInputBorder(),
                    helperText: 'https://api.example.com/v1',
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return l10n.libraryBaseUrl;
                    final uri = Uri.tryParse(text);
                    if (uri == null ||
                        !uri.hasScheme ||
                        (uri.scheme != 'http' && uri.scheme != 'https')) {
                      return l10n.settingsWebDAVConnectionFailed;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.libraryAuth,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AuthScheme>(
                  segments: [
                    ButtonSegment(
                      value: AuthScheme.bearer,
                      label: Text(l10n.libraryAuthBearer),
                    ),
                    ButtonSegment(
                      value: AuthScheme.none,
                      label: Text(l10n.libraryAuthNone),
                    ),
                    ButtonSegment(
                      value: AuthScheme.header,
                      label: Text(l10n.libraryAuthHeader),
                    ),
                  ],
                  selected: {_authScheme},
                  onSelectionChanged: (s) =>
                      setState(() => _authScheme = s.first),
                ),
                if (_authScheme == AuthScheme.header) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _headerName,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.libraryAuthHeaderName,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_authScheme == AuthScheme.none)
                  ListTile(
                    leading: const Icon(Icons.lock_open_outlined),
                    title: Text(l10n.libraryApiKeyNotNeeded),
                  )
                else
                  ApiKeyField(providerId: provider.id),
                const SizedBox(height: 24),
                if (provider.maxRequestSeconds case final seconds?)
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.libraryMaxRequest),
                    subtitle: Text('$seconds'),
                  ),
                if (provider.overriddenFields.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${l10n.libraryOverridden}: '
                      '${(provider.overriddenFields.toList()..sort()).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Choose which of a source's models to add to the library.
class _ModelPickerDialog extends StatefulWidget {
  /// The models the source listed that are not in the library yet.
  final List<CatalogEntry> entries;

  /// Purpose: Create the picker.
  /// Inputs: [entries].
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ModelPickerDialog({required this.entries});

  @override
  State<_ModelPickerDialog> createState() => _ModelPickerDialogState();
}

class _ModelPickerDialogState extends State<_ModelPickerDialog> {
  /// The model names ticked so far.
  final _chosen = <String>{};

  /// Purpose: Build the picker.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Nothing is ticked to begin with. A source can list dozens of
  /// models and importing all of them by default would bury the two the user
  /// actually wanted.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.libraryImportModels),
      content: SizedBox(
        width: 420,
        height: 400,
        child: ListView.builder(
          itemCount: widget.entries.length,
          itemBuilder: (ctx, index) {
            final entry = widget.entries[index];
            return CheckboxListTile(
              dense: true,
              value: _chosen.contains(entry.modelName),
              title: Text(entry.displayName ?? entry.modelName),
              subtitle: entry.displayName == null
                  ? null
                  : Text(entry.modelName),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _chosen.add(entry.modelName);
                } else {
                  _chosen.remove(entry.modelName);
                }
              }),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(_chosen),
          child: Text(l10n.commonAdd),
        ),
      ],
    );
  }
}
