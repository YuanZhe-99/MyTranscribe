/// Purpose: Set up one transcription — the recording, the model, the hints, and
/// a preview of how it will be divided.
/// Inputs: The library, the saved defaults, and a file the user picks.
/// Returns: The new job's id, popped to the caller.
/// Side effects: Reads the recording's duration, creates a job and queues it.
/// Notes: The plan preview is the point of this page. The scripts made the user
/// guess a chunk size and told them afterwards whether it worked; here the
/// choice is made, explained and overridable before anything is uploaded. See
/// `doc/en-us/features/chunking-and-resume.md`.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/byte_format.dart';
import '../../media/models/media_info.dart';
import '../../media/services/media_toolkit.dart';
import '../../media/services/media_toolkit_provider.dart';
import '../../providers/models/model_config.dart';
import '../../providers/models/provider_config.dart';
import '../../providers/services/settings_repository.dart';
import '../../secrets/services/secrets_store.dart';
import '../models/chunk_plan.dart';
import '../models/transcription_job.dart';
import '../services/chunk_planner.dart';
import '../services/job_providers.dart';
import 'job_text.dart';

class NewJobPage extends ConsumerStatefulWidget {
  /// Purpose: Create the new-job page.
  /// Inputs: None.
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const NewJobPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<NewJobPage> createState() => _NewJobPageState();
}

class _NewJobPageState extends ConsumerState<NewJobPage> {
  /// The chosen recording, once there is one.
  File? _file;

  /// What the probe learned about it, when a toolkit could read it.
  MediaInfo? _media;

  /// The chosen source and model.
  String? _providerId;
  String? _modelId;

  /// Whether speaker labels were asked for.
  bool _diarize = false;

  /// Whether to keep the split audio afterwards.
  bool _keepChunks = false;

  /// Whether the defaults have been applied yet.
  bool _seeded = false;

  final _languages = TextEditingController();
  final _prompt = TextEditingController();
  final _keywords = TextEditingController();

  /// Purpose: Release the text controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controllers.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _languages.dispose();
    _prompt.dispose();
    _keywords.dispose();
    super.dispose();
  }

  /// Purpose: Pick a recording and read what can be read about it.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Opens the system picker and probes the file.
  /// Notes: Internal helper used within this file only. A probe that fails is
  /// not an error here: without a duration the planner falls back to the file
  /// size, which is what the original scripts did for every file.
  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles();
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    setState(() {
      _file = File(path);
      _media = null;
    });

    try {
      final toolkit = await ref.read(mediaToolkitProvider.future);
      if ((await toolkit.status()).available) {
        final info = await toolkit.probe(path);
        if (mounted) setState(() => _media = info);
      }
    } on MediaException {
      // Left unknown on purpose; the plan preview says what it can.
    }
  }

  /// Purpose: Work out how the chosen recording would be sent.
  /// Inputs: The [library] and whether a toolkit is [toolkitReady].
  /// Returns: The plan, or null when there is nothing to plan yet.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. This is the same
  /// planner the runner uses, given the same inputs, so the preview is the
  /// decision rather than a description of it.
  PlanResult? _preview(SettingsLibrary library, bool toolkitReady) {
    final file = _file;
    final provider = library.provider(_providerId);
    final model = library.model(_modelId);
    if (file == null || provider == null || model == null) return null;

    return ChunkPlanner.plan(
      PlanRequest(
        sourceBytes: file.existsSync() ? file.lengthSync() : 0,
        sourceExtension: p.extension(file.path).replaceFirst('.', ''),
        media: _media,
        model: model,
        provider: provider,
        diarize: _diarize,
        jsonMode: false,
        overlapSeconds: _diarize
            ? library.defaults.diarizedOverlapSeconds.toDouble()
            : library.defaults.plainOverlapSeconds.toDouble(),
        toolkitAvailable: toolkitReady,
      ),
    );
  }

  /// Purpose: Create the job and start it.
  /// Inputs: The [library].
  /// Returns: None.
  /// Side effects: Writes a job record, queues it, and pops with its id.
  /// Notes: Internal helper used within this file only.
  Future<void> _start(SettingsLibrary library) async {
    final file = _file;
    final model = library.model(_modelId);
    if (file == null || model == null) return;

    final runner = ref.read(jobRunnerProvider);
    final job = await runner.create(
      sourcePath: file.path,
      providerId: model.providerId,
      modelId: model.id,
      modelName: model.modelName,
      options: JobOptions(
        languages: _split(_languages.text),
        prompt: _prompt.text.trim().isEmpty ? null : _prompt.text.trim(),
        keywords: _split(_keywords.text),
        diarize: _diarize,
        overlapSeconds: _diarize
            ? library.defaults.diarizedOverlapSeconds.toDouble()
            : library.defaults.plainOverlapSeconds.toDouble(),
        enrollment: library.defaults.enrollmentEnabled,
        keepChunks: _keepChunks,
      ),
    );
    runner.enqueue(job.id);
    if (mounted) Navigator.of(context).pop(job.id);
  }

  /// Purpose: Split a comma-separated field into a list.
  /// Inputs: [text].
  /// Returns: The trimmed, non-empty parts.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Both commas are
  /// accepted, because a Chinese keyboard produces the full-width one and
  /// silently ignoring it would look like the field did not work.
  List<String> _split(String text) => [
    for (final part in text.split(RegExp('[,，]')))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the library, the keys and the toolkit.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final library = ref.watch(settingsLibraryProvider).value;
    final configured = ref.watch(configuredProvidersProvider).value;
    final toolkitReady = ref.watch(mediaToolkitStatusProvider).value?.available;

    if (library == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.newJobTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_seeded) {
      _seeded = true;
      _providerId =
          library.defaults.providerId ?? library.providers.firstOrNull?.id;
      _modelId =
          library.defaults.modelId ??
          library.modelsOf(_providerId ?? '').firstOrNull?.id;
      _languages.text = library.defaults.languages.join(', ');
      _prompt.text = library.defaults.prompt ?? '';
      _keywords.text = library.defaults.keywords.join(', ');
    }

    final model = library.model(_modelId);
    final provider = library.provider(_providerId);
    final plan = _preview(library, toolkitReady ?? false);
    final missingKey =
        provider != null &&
        provider.needsApiKey &&
        configured != null &&
        !configured.contains(provider.id);

    final width = MediaQuery.sizeOf(context).width;
    final contentWidth = shellContentWidth(width);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newJobTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: pageMaxContentWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _recordingCard(l10n),
              const SizedBox(height: 16),
              _sourceAndModel(l10n, library),
              if (missingKey)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.newJobNoKey,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                l10n.newJobOptions,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _optionFields(l10n, model, contentWidth),
              const SizedBox(height: 16),
              _switches(l10n, model),
              const SizedBox(height: 24),
              _planCard(l10n, plan),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _file != null && model != null && plan?.isSuccess == true
            ? () => _start(library)
            : null,
        icon: const Icon(Icons.play_arrow),
        label: Text(l10n.newJobStart),
      ),
    );
  }

  /// Purpose: Build the recording chooser.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _recordingCard(AppLocalizations l10n) {
    final file = _file;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.audio_file_outlined),
        title: Text(file == null ? l10n.newJobNoFile : p.basename(file.path)),
        subtitle: file == null
            ? null
            : Text(
                [
                  formatBytes(file.existsSync() ? file.lengthSync() : 0),
                  if (_media case final media?) media.formattedDuration,
                ].join(' · '),
              ),
        trailing: TextButton(
          onPressed: _pick,
          child: Text(file == null ? l10n.newJobChoose : l10n.newJobChange),
        ),
      ),
    );
  }

  /// Purpose: Build the source and model pickers.
  /// Inputs: [l10n], the [library].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Choosing a source
  /// resets the model, because a model belongs to exactly one source and a
  /// stale pairing would be rejected by the server rather than by this page.
  Widget _sourceAndModel(AppLocalizations l10n, SettingsLibrary library) {
    if (library.providers.isEmpty) {
      return Text(l10n.newJobNoModels);
    }
    final models = library.modelsOf(_providerId ?? '');
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _providerId,
          decoration: InputDecoration(labelText: l10n.jobFieldSource),
          items: [
            for (final ProviderConfig provider in library.providers)
              DropdownMenuItem(value: provider.id, child: Text(provider.name)),
          ],
          onChanged: (value) => setState(() {
            _providerId = value;
            _modelId = library.modelsOf(value ?? '').firstOrNull?.id;
            _diarize = false;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: models.any((m) => m.id == _modelId) ? _modelId : null,
          decoration: InputDecoration(labelText: l10n.jobFieldModel),
          items: [
            for (final ModelConfig model in models)
              DropdownMenuItem(value: model.id, child: Text(model.displayName)),
          ],
          onChanged: (value) => setState(() {
            _modelId = value;
            _diarize = false;
          }),
        ),
      ],
    );
  }

  /// Purpose: Build the language, context and keyword fields.
  /// Inputs: [l10n], the [model], and the [contentWidth].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Two of the fields sit
  /// side by side when the window can pack them, which is the only layout
  /// decision on this page and it comes from `adaptive_layout.dart`.
  Widget _optionFields(
    AppLocalizations l10n,
    ModelConfig? model,
    double contentWidth,
  ) {
    final languages = TextField(
      controller: _languages,
      decoration: InputDecoration(
        labelText: l10n.newJobLanguages,
        helperText: l10n.newJobLanguagesHint,
        helperMaxLines: 3,
      ),
    );
    final keywords = TextField(
      controller: _keywords,
      enabled: model?.supportsKeywords ?? true,
      decoration: InputDecoration(
        labelText: l10n.newJobKeywords,
        helperText: l10n.newJobKeywordsHint,
        helperMaxLines: 3,
      ),
    );

    return Column(
      children: [
        if (useNewJobOptionRow(contentWidth))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: languages),
              const SizedBox(width: 16),
              Expanded(child: keywords),
            ],
          )
        else ...[
          languages,
          const SizedBox(height: 16),
          keywords,
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _prompt,
          maxLines: 3,
          enabled: model?.supportsPrompt ?? true,
          decoration: InputDecoration(
            labelText: l10n.newJobPrompt,
            helperText: l10n.newJobPromptHint,
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }

  /// Purpose: Build the speaker and keep-audio switches.
  /// Inputs: [l10n], the [model].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A model that is known
  /// not to label speakers gets a disabled switch with the reason, rather than
  /// a hidden one: hiding it would leave the user wondering where the feature
  /// went after they changed models.
  Widget _switches(AppLocalizations l10n, ModelConfig? model) {
    final capability = model?.diarization ?? Capability.unknown;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _diarize && capability != Capability.unsupported,
          onChanged: capability == Capability.unsupported
              ? null
              : (value) => setState(() => _diarize = value),
          title: Text(l10n.newJobDiarize),
          subtitle: switch (capability) {
            Capability.unsupported => Text(l10n.newJobDiarizeUnsupported),
            Capability.unknown => Text(l10n.newJobDiarizeUnknown),
            Capability.supported => null,
          },
          isThreeLine: capability == Capability.unknown,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _keepChunks,
          onChanged: (value) => setState(() => _keepChunks = value),
          title: Text(l10n.newJobKeepChunks),
          subtitle: Text(l10n.newJobKeepChunksHint),
        ),
      ],
    );
  }

  /// Purpose: Build the plan preview.
  /// Inputs: [l10n], the [plan].
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A plan that cannot be
  /// made says why in the same place a successful one says how, so the user
  /// never has to start a job to find out it could not run.
  Widget _planCard(AppLocalizations l10n, PlanResult? plan) {
    final theme = Theme.of(context);
    if (plan == null) {
      return Text(
        l10n.newJobPlanPending,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (!plan.isSuccess) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(switch (plan.failure!) {
            PlanFailure.mediaToolkitMissing =>
              l10n.settingsMediaToolsSubtitleMissing,
            PlanFailure.durationUnknown => l10n.planSplitByDuration,
            PlanFailure.noAudio => l10n.planSplitByFormat,
          }, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.newJobPlanTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(planSummary(l10n, plan.plan!)),
            const SizedBox(height: 8),
            for (final reason in plan.plan!.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${planReasonText(l10n, reason)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
