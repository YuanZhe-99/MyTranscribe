/// Purpose: Show one transcription — what it is doing, how it was divided, what
/// it produced, and what to do about it.
/// Inputs: A job id; the record from disk, or the runner's live state while it
/// runs.
/// Returns: A page, embeddable in the jobs tab's second pane.
/// Side effects: Starts, stops and deletes jobs; writes to the clipboard.
/// Notes: The same widget serves the pushed route and the wide-window pane, so
/// the two cannot drift. See `doc/en-us/features/transcription-jobs.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/byte_format.dart';
import '../../local/models/engine_capability.dart';
import '../../local/views/local_text.dart';
import '../models/transcription_job.dart';
import '../services/job_providers.dart';
import '../services/job_runner.dart';
import '../../transcript/views/transcript_viewer_page.dart';
import 'job_text.dart';

class JobDetailPage extends ConsumerStatefulWidget {
  /// Which job to show.
  final String jobId;

  /// Whether this is the jobs tab's second pane rather than its own route.
  final bool embedded;

  /// Called after the job is deleted, so an embedding pane can clear itself.
  final VoidCallback? onDeleted;

  /// Purpose: Create a detail page.
  /// Inputs: [jobId], [embedded], [onDeleted].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const JobDetailPage({
    super.key,
    required this.jobId,
    this.embedded = false,
    this.onDeleted,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends ConsumerState<JobDetailPage> {
  /// The last record this page managed to show.
  ///
  /// A `FutureProvider` that is re-reading reports `AsyncLoading` and, in
  /// Riverpod 1.x, carries no previous value. Without this the page would blink
  /// back to a spinner every time a job record changed.
  TranscriptionJob? _lastSeen;

  /// Purpose: Choose which copy of the job to believe.
  /// Inputs: The runner's [queue] and the [stored] record, when there is one.
  /// Returns: The most recently written copy, or null when there is none yet.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Three copies can exist
  /// at once and none of them is reliably the newest: the runner's own copy of
  /// a job it is working on, the copy it wrote as that job stopped, and the
  /// record read from disk. Comparing `modifiedAt` picks the truth without any
  /// of them having to know about the others — which matters most at the moment
  /// a job finishes, when the runner drops it and the disk copy has not been
  /// re-read yet.
  TranscriptionJob? _freshest(JobQueueState queue, TranscriptionJob? stored) {
    TranscriptionJob? best;
    for (final candidate in <TranscriptionJob?>[
      queue.active?.id == widget.jobId ? queue.active : null,
      queue.finished?.id == widget.jobId ? queue.finished : null,
      stored,
      _lastSeen,
    ]) {
      if (candidate == null) continue;
      if (best == null || candidate.modifiedAt.isAfter(best.modifiedAt)) {
        best = candidate;
      }
    }
    return best;
  }

  /// Purpose: Build the page.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the record and the runner, and remembers what it
  /// showed.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(jobProvider(widget.jobId));
    final runner = ref.watch(jobRunnerProvider);

    return ValueListenableBuilder<JobQueueState>(
      valueListenable: runner.state,
      builder: (context, queue, _) {
        final job = _freshest(queue, stored.value);
        if (job == null) {
          // Either it is still being read, or it was deleted from another
          // pane; a spinner covers both without claiming which.
          const waiting = Center(child: CircularProgressIndicator());
          return widget.embedded
              ? waiting
              : Scaffold(appBar: AppBar(), body: waiting);
        }
        // A cache, not state: nothing needs rebuilding because of it.
        _lastSeen = job;

        final body = _Body(
          job: job,
          queued: queue.queued.contains(widget.jobId),
          onDeleted: widget.onDeleted,
          embedded: widget.embedded,
        );
        if (widget.embedded) return body;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              job.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              _RenameButton(job: job),
              _DeleteButton(job: job, onDeleted: widget.onDeleted),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

/// Purpose: Ask what to call one transcription.
/// Inputs: `context`, the [runner] and the [job].
/// Returns: None.
/// Side effects: Opens a dialog and, on a save, renames the job.
/// Notes: Public so the jobs list can offer the same dialog from a long press —
/// renaming is something you want where you notice the name, and that is the
/// row as often as the detail page. An empty name clears it, which is how a
/// wrong one is undone; the hint shows the recording's file name so it is clear
/// what clearing it goes back to.
Future<void> showJobRenameDialog(
  BuildContext context,
  JobRunner runner,
  TranscriptionJob job,
) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: job.title ?? '');
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.jobRenameTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: job.sourceName,
          helperText: l10n.jobRenameHint,
          helperMaxLines: 2,
        ),
        onSubmitted: (value) => Navigator.of(ctx).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  controller.dispose();
  if (title != null) await runner.rename(job.id, title);
}

/// The button that renames a transcription.
class _RenameButton extends ConsumerWidget {
  /// The job.
  final TranscriptionJob job;

  /// Purpose: Create the rename button.
  /// Inputs: [job].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _RenameButton({required this.job});

  /// Purpose: Build the button.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; the callback renames.
  /// Notes: None.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.jobRename,
      icon: const Icon(Icons.edit_outlined),
      onPressed: () =>
          showJobRenameDialog(context, ref.read(jobRunnerProvider), job),
    );
  }
}

/// The scrolling contents, shared by both presentations.
class _Body extends ConsumerWidget {
  /// The job being shown.
  final TranscriptionJob job;

  /// Whether it is waiting behind another job.
  final bool queued;

  /// Whether this is a pane rather than a route.
  final bool embedded;

  /// Called after deletion.
  final VoidCallback? onDeleted;

  /// Purpose: Create the body.
  /// Inputs: [job], [queued], [embedded], [onDeleted].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _Body({
    required this.job,
    required this.queued,
    required this.embedded,
    required this.onDeleted,
  });

  /// Purpose: Build the contents.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; the buttons act.
  /// Notes: Ordered by what a user wants when they open this page: what is
  /// happening, what went wrong if anything, then the files, then the details.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        shellListBottomInset(width) + 16,
      ),
      children: [
        if (embedded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    job.displayName,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _RenameButton(job: job),
                _DeleteButton(job: job, onDeleted: onDeleted),
              ],
            ),
          ),
        _StatusCard(job: job, queued: queued),
        const SizedBox(height: 16),
        _Actions(job: job, queued: queued),
        if (job.error != null) ...[
          const SizedBox(height: 24),
          _SectionTitle(l10n.jobSectionProblem),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                job.error!.message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _SectionTitle(l10n.jobSectionRecording),
        _Field(l10n.jobFieldSize, formatBytes(job.sourceBytes)),
        _StorageRow(job: job),
        if (job.media case final media?)
          _Field(l10n.jobFieldLength, media.formattedDuration),
        _Field(l10n.jobFieldModel, job.modelName),
        if (job.isLocal && job.chunks.isNotEmpty)
          _Field(l10n.jobFieldRanOn, _placementSummary(l10n, job)),
        for (final fallback in job.fallbacks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.jobFallback(
                routeKeyLabel(l10n, fallback.from),
                routeKeyLabel(l10n, fallback.to),
                fallback.reason,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        _Field(
          l10n.jobFieldStarted,
          job.createdAt.toLocal().toString().split('.').first,
        ),
        if (job.finishedAt case final finished?)
          _Field(
            l10n.jobFieldFinished,
            finished.toLocal().toString().split('.').first,
          ),
        if (job.plan case final plan?) ...[
          const SizedBox(height: 24),
          _SectionTitle(l10n.jobSectionPlan),
          Text(planSummary(l10n, plan), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final reason in plan.reasons)
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
      ],
    );
  }
}

/// Purpose: Say where a local job's windows ran.
/// Inputs: [l10n], the [job].
/// Returns: One placement when every window ran in the same place, otherwise
/// the runs of windows that shared one.
/// Side effects: None.
/// Notes: From what the runtime reported for each window, never inferred
/// from the route that was asked for.
String _placementSummary(AppLocalizations l10n, TranscriptionJob job) {
  final chunks = List.of(job.chunks)
    ..sort((a, b) => a.index.compareTo(b.index));
  final runs = <({int first, int last, PlacementKind placement})>[];
  for (final chunk in chunks) {
    final placement = chunk.placement ?? PlacementKind.unknown;
    if (runs.isNotEmpty && runs.last.placement == placement) {
      runs.last = (
        first: runs.last.first,
        last: chunk.index,
        placement: placement,
      );
    } else {
      runs.add((first: chunk.index, last: chunk.index, placement: placement));
    }
  }
  if (runs.length == 1) return placementLabel(l10n, runs.single.placement);
  return [
    for (final run in runs)
      l10n.jobPlacementWindows(
        '${run.first + 1}',
        '${run.last + 1}',
        placementLabel(l10n, run.placement),
      ),
  ].join('\n');
}

/// What the job is doing, with a bar when that means something.
class _StatusCard extends StatelessWidget {
  /// The job.
  final TranscriptionJob job;

  /// Whether it is waiting behind another.
  final bool queued;

  /// Purpose: Create the status card.
  /// Inputs: [job], [queued].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _StatusCard({required this.job, required this.queued});

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = jobProgress(job);
    final total = job.plan?.windowCount ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              queued && job.stage == JobStage.queued
                  ? l10n.jobStageQueued
                  : jobStageLabel(l10n, job),
              style: theme.textTheme.titleMedium,
            ),
            if (total > 1) ...[
              const SizedBox(height: 4),
              Text(
                l10n.jobSegmentsDone(job.chunks.length, total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (job.stage.isRunning) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }
}

/// The buttons that act on a job.
class _Actions extends ConsumerWidget {
  /// The job.
  final TranscriptionJob job;

  /// Whether it is waiting behind another.
  final bool queued;

  /// Purpose: Create the action row.
  /// Inputs: [job], [queued].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _Actions({required this.job, required this.queued});

  /// Purpose: Build the buttons.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; the callbacks queue and cancel.
  /// Notes: A refused feature earns its own button, because "try again" alone
  /// would repeat the request the source has already turned down. Wrapped
  /// rather than laid out in a row, so a narrow pane stacks them instead of
  /// overflowing.
  ///
  /// A finished job offers to run again, and never offers plain "Start": a
  /// Start button on a job that is already done is what an out-of-date page
  /// used to show, and pressing it silently threw away the transcript.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final runner = ref.read(jobRunnerProvider);
    // Null while the probe is still running; treated as "yes" then, so the
    // button does not flicker in and out every time the page opens.
    final storage = ref.watch(jobStorageProvider(job.id)).value;
    final canRerun = storage == null || storage.hasSource;
    final buttons = <Widget>[];

    if (job.stage.isRunning || queued) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => runner.cancel(job.id),
          icon: const Icon(Icons.stop),
          label: Text(l10n.jobStop),
        ),
      );
    } else if (job.stage == JobStage.done) {
      buttons
        ..add(
          FilledButton.icon(
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => TranscriptViewerPage(jobId: job.id),
              ),
            ),
            icon: const Icon(Icons.notes),
            label: Text(l10n.jobOpenTranscript),
          ),
        )
        ..addAll([
          // Running again means transcribing the recording, and there is not
          // always one on this device: a transcription that arrived over sync
          // never had it, and a recording the user has since moved or deleted
          // is the same situation. The button would only produce a failure.
          if (canRerun)
            OutlinedButton.icon(
              onPressed: () => _confirmRunAgain(context, l10n, runner),
              icon: const Icon(Icons.replay),
              label: Text(l10n.jobRunAgain),
            ),
        ]);
    } else {
      final resuming = job.chunks.isNotEmpty;
      buttons.add(
        FilledButton.icon(
          onPressed: () => runner.enqueue(job.id),
          icon: Icon(resuming ? Icons.play_arrow : Icons.play_arrow_outlined),
          label: Text(
            resuming
                ? l10n.jobResume
                : (job.stage == JobStage.failed
                      ? l10n.jobRetry
                      : l10n.jobStart),
          ),
        ),
      );

      if (job.error?.rejectedFeature == 'diarization' && job.options.diarize) {
        buttons.add(
          OutlinedButton.icon(
            onPressed: () => runner.retryWithout(job.id, diarize: false),
            icon: const Icon(Icons.person_off_outlined),
            label: Text(l10n.jobRetryWithoutSpeakers),
          ),
        );
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  /// Purpose: Ask before transcribing a finished recording again.
  /// Inputs: `context`, [l10n] and the [runner].
  /// Returns: None.
  /// Side effects: Opens a dialog and, on a yes, queues the job.
  /// Notes: Internal helper used within this file only. Running again rebuilds
  /// the transcript from the windows, which overwrites every correction made in
  /// the viewer — speaker names, edited lines, reassignments. That is a real
  /// loss and nothing later reveals it, so it is said out loud first.
  Future<void> _confirmRunAgain(
    BuildContext context,
    AppLocalizations l10n,
    JobRunner runner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jobRunAgain),
        content: Text(l10n.jobRunAgainConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.jobRunAgain),
          ),
        ],
      ),
    );
    if (confirmed == true) runner.enqueue(job.id);
  }
}

/// What the job is holding on this device, and the offer to give some back.
class _StorageRow extends ConsumerWidget {
  /// The job.
  final TranscriptionJob job;

  /// Purpose: Create the storage row.
  /// Inputs: [job].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _StorageRow({required this.job});

  /// Purpose: Build the row.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Reads the job folder's size.
  /// Notes: Nothing at all while the size is being measured, rather than a
  /// spinner: it arrives in a few milliseconds and a flicker in the middle of a
  /// list of fields is worse than a line that appears.
  ///
  /// The converted copy is a third of the size of the recording and the app
  /// gave no way to see it, let alone remove it short of deleting the whole
  /// transcription. It stays by default — it is what the viewer plays — but a
  /// transcript that has been read does not need it any more.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final info = ref.watch(jobStorageProvider(job.id)).value;
    if (info == null || info.bytes == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            l10n.jobDiskUsage(formatBytes(info.bytes)),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (info.hasConvertedAudio && !job.stage.isRunning)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () => _confirm(context, l10n, ref),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text(l10n.jobRemoveAudio),
            ),
          ),
      ],
    );
  }

  /// Purpose: Ask before removing the converted copy.
  /// Inputs: `context`, [l10n] and `ref`.
  /// Returns: None.
  /// Side effects: Opens a dialog and, on a yes, deletes the audio.
  /// Notes: Internal helper used within this file only. The confirmation says
  /// what stays, because the thing being removed sounds like the transcript's
  /// own audio and is not.
  Future<void> _confirm(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.jobRemoveAudio),
        content: Text(l10n.jobRemoveAudioConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref.read(jobRunnerProvider).discardAudio(job.id);
    if (!context.mounted || !removed) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.jobAudioRemoved)));
  }
}

/// The button that deletes a job.
class _DeleteButton extends ConsumerWidget {
  /// The job.
  final TranscriptionJob job;

  /// Called after deletion.
  final VoidCallback? onDeleted;

  /// Purpose: Create the delete button.
  /// Inputs: [job], [onDeleted].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _DeleteButton({required this.job, required this.onDeleted});

  /// Purpose: Build the button.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; the callback deletes.
  /// Notes: Confirmed first, and the confirmation says exactly what goes and
  /// what stays — the original recording is not this app's to delete.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.delete,
      icon: const Icon(Icons.delete_outline),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.delete),
            content: Text(l10n.jobDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;

        await ref.read(jobRunnerProvider).remove(job.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.jobDeleted)));
        if (onDeleted != null) {
          onDeleted!();
        } else {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// A section heading.
class _SectionTitle extends StatelessWidget {
  /// The heading text.
  final String text;

  /// Purpose: Create a heading.
  /// Inputs: [text].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _SectionTitle(this.text);

  /// Purpose: Build the heading.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

/// One labelled value.
class _Field extends StatelessWidget {
  /// What it is.
  final String label;

  /// What it says.
  final String value;

  /// Purpose: Create a field row.
  /// Inputs: [label], [value].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _Field(this.label, this.value);

  /// Purpose: Build the row.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
