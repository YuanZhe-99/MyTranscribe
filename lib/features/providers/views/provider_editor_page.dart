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
import '../models/provider_config.dart';
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
          if (provider.templateId != null)
            IconButton(
              tooltip: l10n.libraryResetToTemplate,
              icon: const Icon(Icons.restart_alt),
              onPressed: _reset,
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
