/// Purpose: Edit one model — its identifier, its limits, and what it can do.
/// Inputs: The model's record id.
/// Returns: A page; hosted in the library's editor pane on a wide window.
/// Side effects: Writes the settings file.
/// Notes: The capability fields here are read by the chunk planner and the
/// request builder, so editing one changes how the app behaves rather than only
/// what it displays. That is the point: a service raises a limit or gains a
/// feature, and the user should not have to wait for a new build.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../models/model_config.dart';
import '../services/settings_repository.dart';

class ModelEditorPage extends ConsumerStatefulWidget {
  /// Which model to edit.
  final String modelId;

  /// Purpose: Create the model editor.
  /// Inputs: [modelId].
  /// Returns: A new widget.
  /// Side effects: None.
  /// Notes: None.
  const ModelEditorPage({super.key, required this.modelId});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<ModelEditorPage> createState() => _ModelEditorPageState();
}

class _ModelEditorPageState extends ConsumerState<ModelEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _modelName = TextEditingController();
  final _displayName = TextEditingController();
  final _maxFileMegabytes = TextEditingController();
  final _maxDurationSeconds = TextEditingController();

  /// The model as loaded, before any edit.
  ModelConfig? _original;

  /// The capabilities currently selected.
  Capability _diarization = Capability.unknown;
  Capability _segmentTimestamps = Capability.unknown;
  Capability _wordTimestamps = Capability.unknown;
  bool _supportsPrompt = false;
  bool _supportsKeywords = false;

  /// Whether the fields have been filled from the record yet.
  bool _loaded = false;

  /// Purpose: Release the text controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controllers.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _modelName.dispose();
    _displayName.dispose();
    _maxFileMegabytes.dispose();
    _maxDurationSeconds.dispose();
    super.dispose();
  }

  /// Purpose: Fill the fields from the record, once.
  /// Inputs: [model].
  /// Returns: None.
  /// Side effects: Sets the controllers and the capability state.
  /// Notes: Internal helper used within this file only. Guarded so a rebuild
  /// never overwrites what the user is halfway through typing.
  void _fill(ModelConfig model) {
    if (_loaded) return;
    _loaded = true;
    _original = model;
    _modelName.text = model.modelName;
    _displayName.text = model.displayName;
    _maxFileMegabytes.text = model.maxFileBytes == null
        ? ''
        : (model.maxFileBytes! / (1024 * 1024)).round().toString();
    _maxDurationSeconds.text = model.maxDurationSeconds?.toString() ?? '';
    _diarization = model.diarization;
    _segmentTimestamps = model.segmentTimestamps;
    _wordTimestamps = model.wordTimestamps;
    _supportsPrompt = model.supportsPrompt;
    _supportsKeywords = model.supportsKeywords;
  }

  /// Purpose: Save the edited model.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and refreshes the library.
  /// Notes: Internal helper used within this file only. An empty limit field
  /// means "no limit" rather than zero, which is why both are cleared
  /// explicitly rather than written as a falsy value.
  Future<void> _save() async {
    final original = _original;
    if (original == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final megabytes = int.tryParse(_maxFileMegabytes.text.trim());
    final seconds = int.tryParse(_maxDurationSeconds.text.trim());

    final updated = original.copyWith(
      modelName: _modelName.text.trim(),
      displayName: _displayName.text.trim(),
      maxFileBytes: megabytes == null ? null : megabytes * 1024 * 1024,
      clearMaxFileBytes: megabytes == null,
      maxDurationSeconds: seconds,
      clearMaxDurationSeconds: seconds == null,
      diarization: _diarization,
      segmentTimestamps: _segmentTimestamps,
      wordTimestamps: _wordTimestamps,
      supportsPrompt: _supportsPrompt,
      supportsKeywords: _supportsKeywords,
    );

    await ref.read(settingsRepositoryProvider).saveModel(updated);
    ref.refresh(settingsLibraryProvider);
    if (!mounted) return;
    _original = updated;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.settingsWebDAVConfigSaved)),
    );
  }

  /// Purpose: Put this model back to its built-in values.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes the settings file and reloads the fields.
  /// Notes: Internal helper used within this file only.
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

    await ref.read(settingsRepositoryProvider).resetToTemplate(widget.modelId);
    ref.refresh(settingsLibraryProvider);
    if (mounted) setState(() => _loaded = false);
  }

  /// Purpose: Build one three-way capability row.
  /// Inputs: [label], the [value], and [onChanged].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Three states rather
  /// than a switch, because "not verified" is a real answer the app acts on
  /// differently from "no": it offers the feature with a warning.
  Widget _capabilityRow(
    String label,
    Capability value,
    ValueChanged<Capability> onChanged,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          SegmentedButton<Capability>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: Capability.supported,
                label: Text(l10n.capabilitySupported),
              ),
              ButtonSegment(
                value: Capability.unsupported,
                label: Text(l10n.capabilityUnsupported),
              ),
              ButtonSegment(
                value: Capability.unknown,
                label: Text(l10n.capabilityUnknown),
              ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build the model editor.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the library.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final library = ref.watch(settingsLibraryProvider);
    final model = library.value?.model(widget.modelId);

    if (model == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.libraryTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _fill(model);

    return Scaffold(
      appBar: AppBar(
        title: Text(model.displayName),
        actions: [
          if (model.templateId != null)
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
                  controller: _modelName,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.libraryModelName,
                    border: const OutlineInputBorder(),
                    helperText: 'gpt-transcribe',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.libraryModelName
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayName,
                  decoration: InputDecoration(
                    labelText: l10n.libraryDisplayName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(l10n.libraryLimits, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _maxFileMegabytes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.libraryMaxFileSize,
                    border: const OutlineInputBorder(),
                    helperText: l10n.libraryUnlimited,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxDurationSeconds,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.libraryMaxDuration,
                    border: const OutlineInputBorder(),
                    helperText: l10n.libraryUnlimited,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.libraryCapabilities,
                  style: theme.textTheme.titleSmall,
                ),
                _capabilityRow(
                  l10n.libraryDiarization,
                  _diarization,
                  (value) => setState(() => _diarization = value),
                ),
                _capabilityRow(
                  l10n.librarySegmentTimestamps,
                  _segmentTimestamps,
                  (value) => setState(() => _segmentTimestamps = value),
                ),
                _capabilityRow(
                  l10n.libraryWordTimestamps,
                  _wordTimestamps,
                  (value) => setState(() => _wordTimestamps = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.libraryPrompt),
                  value: _supportsPrompt,
                  onChanged: (value) => setState(() => _supportsPrompt = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.libraryKeywords),
                  value: _supportsKeywords,
                  onChanged: (value) =>
                      setState(() => _supportsKeywords = value),
                ),
                if (model.overriddenFields.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${l10n.libraryOverridden}: '
                      '${(model.overriddenFields.toList()..sort()).join(', ')}',
                      style: theme.textTheme.bodySmall,
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
