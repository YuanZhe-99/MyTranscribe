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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/byte_format.dart';
import '../models/transcription_job.dart';
import '../services/job_providers.dart';
import '../services/job_runner.dart';
import '../../transcript/views/transcript_viewer_page.dart';
import 'job_text.dart';

class JobDetailPage extends ConsumerWidget {
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

  /// Purpose: Build the page.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the record and the runner.
  /// Notes: The live state wins while this job is the one running, because the
  /// record on disk is only as fresh as the last stage change.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(jobProvider(jobId));
    final runner = ref.watch(jobRunnerProvider);

    return ValueListenableBuilder<JobQueueState>(
      valueListenable: runner.state,
      builder: (context, queue, _) {
        final live = queue.active?.id == jobId ? queue.active : null;
        final job = live ?? stored.value;
        if (job == null) {
          // Either it is still being read, or it was deleted from another
          // pane; a spinner covers both without claiming which.
          const waiting = Center(child: CircularProgressIndicator());
          return embedded ? waiting : Scaffold(appBar: AppBar(), body: waiting);
        }

        final body = _Body(
          job: job,
          queued: queue.queued.contains(jobId),
          onDeleted: onDeleted,
          embedded: embedded,
        );
        if (embedded) return body;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              job.sourceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [_DeleteButton(job: job, onDeleted: onDeleted)],
          ),
          body: body,
        );
      },
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
                    job.sourceName,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
        if (job.outputs.isNotEmpty) ...[
          const SizedBox(height: 24),
          _SectionTitle(l10n.jobSectionOutputs),
          for (final path in job.outputs)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(path.split(RegExp(r'[\\/]')).last),
              subtitle: Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                tooltip: l10n.commonCopy,
                icon: const Icon(Icons.copy_outlined),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: path));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.jobPathCopied)));
                },
              ),
            ),
        ],
        const SizedBox(height: 24),
        _SectionTitle(l10n.jobSectionRecording),
        _Field(l10n.jobFieldSize, formatBytes(job.sourceBytes)),
        if (job.media case final media?)
          _Field(l10n.jobFieldLength, media.formattedDuration),
        _Field(l10n.jobFieldModel, job.modelName),
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final runner = ref.read(jobRunnerProvider);
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
      buttons.add(
        FilledButton.icon(
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => TranscriptViewerPage(jobId: job.id),
            ),
          ),
          icon: const Icon(Icons.notes),
          label: Text(l10n.jobOpenTranscript),
        ),
      );
    } else {
      final resuming = job.chunks.isNotEmpty;
      buttons.add(
        FilledButton.icon(
          onPressed: () {
            runner.enqueue(job.id);
            ref.refresh(jobsListProvider);
          },
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
            onPressed: () async {
              await runner.retryWithout(job.id, diarize: false);
              ref.refresh(jobsListProvider);
            },
            icon: const Icon(Icons.person_off_outlined),
            label: Text(l10n.jobRetryWithoutSpeakers),
          ),
        );
      }
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
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
        ref.refresh(jobsListProvider);
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
