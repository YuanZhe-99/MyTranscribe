/// Purpose: The transcribe tab — every recording this app has transcribed,
/// newest first, and the one that is running now.
/// Inputs: `jobsListProvider` for the records and the runner's own notifier for
/// the job in flight.
/// Returns: A shell page; on a wide window it hosts the detail beside the list.
/// Side effects: None directly; the detail pane starts, stops and deletes jobs.
/// Notes: The running job is watched through the runner rather than re-read
/// from disk on a timer, so the progress line moves as the work does. See
/// `doc/en-us/features/transcription-jobs.md`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/transcription_job.dart';
import '../services/job_providers.dart';
import '../services/job_runner.dart';
import 'job_detail_page.dart';
import 'job_text.dart';
import 'new_job_page.dart';

class JobsPage extends ConsumerStatefulWidget {
  /// Purpose: Create a jobs page instance.
  /// Inputs: None.
  /// Returns: A new `JobsPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const JobsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  /// The job the detail pane is showing, by id.
  String? _selected;

  /// Whether this build is rendering two panes.
  bool _twoPane = false;

  /// The last list this page managed to show.
  ///
  /// The list is re-read whenever a job record changes, and a re-reading
  /// `FutureProvider` reports `AsyncLoading` with no previous value in Riverpod
  /// 1.x. Without this the whole list would blink to a spinner every time a job
  /// finished.
  List<TranscriptionJob>? _records;

  /// Purpose: Open a job, in the pane or as a pushed route.
  /// Inputs: [jobId].
  /// Returns: None.
  /// Side effects: Sets state or pushes a route, and refreshes the list after a
  /// pushed detail page closes.
  /// Notes: Internal helper used within this file only. The same widget serves
  /// both, so the two cannot drift.
  Future<void> _open(String jobId) async {
    if (_twoPane) {
      setState(() => _selected = jobId);
      return;
    }
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => JobDetailPage(jobId: jobId)));
  }

  /// Purpose: Start a new transcription.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Opens the new-job route and refreshes the list afterwards.
  /// Notes: Internal helper used within this file only. Full window rather than
  /// a sheet: choosing a file, a model and the options is a page's worth of
  /// decisions, and on a phone a sheet would cover them with the keyboard.
  Future<void> _newJob() async {
    final id = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<String>(MaterialPageRoute(builder: (_) => const NewJobPage()));
    if (!mounted) return;
    if (id != null) await _open(id);
  }

  /// Purpose: Build the transcribe tab.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Watches the job list and the runner.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screen = MediaQuery.sizeOf(context);
    _twoPane = useJobsTwoPane(screen.width, screen.height);

    final list = _buildList(l10n);
    final fab = FloatingActionButton.extended(
      onPressed: _newJob,
      icon: const Icon(Icons.add),
      label: Text(l10n.jobsNew),
    );

    if (!_twoPane) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.jobsTitle)),
        body: list,
        floatingActionButton: fab,
      );
    }

    final contentWidth = shellContentWidth(screen.width);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobsTitle)),
      body: Row(
        children: [
          SizedBox(width: jobsListPaneWidth(contentWidth), child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selected == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.jobsSelectPrompt,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : JobDetailPage(
                    key: ValueKey(_selected),
                    jobId: _selected!,
                    embedded: true,
                    onDeleted: () => setState(() => _selected = null),
                  ),
          ),
        ],
      ),
      floatingActionButton: fab,
    );
  }

  /// Purpose: Build the list of jobs.
  /// Inputs: [l10n].
  /// Returns: `Widget`.
  /// Side effects: Watches the job list and the runner's queue.
  /// Notes: Internal helper used within this file only. The record on disk is
  /// the source of truth for every job except the running one, whose live state
  /// is substituted in — otherwise the row would sit at the stage it was last
  /// saved at. The list itself is re-read whenever the runner says a record
  /// changed, so a job that finishes updates its own row.
  Widget _buildList(AppLocalizations l10n) {
    final jobs = ref.watch(jobsListProvider);
    final runner = ref.watch(jobRunnerProvider);

    return ValueListenableBuilder<JobQueueState>(
      valueListenable: runner.state,
      builder: (context, queue, _) {
        final records = jobs.value ?? _records;
        if (records == null) {
          return const Center(child: CircularProgressIndicator());
        }
        // A cache, not state: nothing needs rebuilding because of it.
        _records = records;
        if (records.isEmpty) {
          return EmptyState(
            icon: Icons.graphic_eq_outlined,
            title: l10n.jobsEmptyTitle,
            body: l10n.jobsEmptyBody,
          );
        }

        final active = queue.active;
        return ListView.builder(
          padding: EdgeInsets.only(
            bottom: shellListBottomInset(MediaQuery.sizeOf(context).width),
          ),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final job = active?.id == record.id ? active! : record;
            return _JobTile(
              job: job,
              selected: _twoPane && job.id == _selected,
              onTap: () => _open(job.id),
            );
          },
        );
      },
    );
  }
}

/// One row in the list of transcriptions.
class _JobTile extends ConsumerWidget {
  /// The job this row stands for.
  final TranscriptionJob job;

  /// Whether the detail pane is showing it.
  final bool selected;

  /// What to do when it is tapped.
  final VoidCallback onTap;

  /// Purpose: Create a row.
  /// Inputs: [job], [selected], [onTap].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const _JobTile({
    required this.job,
    required this.selected,
    required this.onTap,
  });

  /// Purpose: Build the row.
  /// Inputs: `context`, `ref`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None here; a long press opens the rename dialog.
  /// Notes: A running job shows a progress bar under its name; a finished one
  /// shows nothing extra, so a list of finished work stays quiet. Renaming is
  /// on a long press because the list is where a name is usually noticed.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final running = job.stage.isRunning;
    final progress = jobProgress(job);

    return ListTile(
      selected: selected,
      onTap: onTap,
      onLongPress: () =>
          showJobRenameDialog(context, ref.read(jobRunnerProvider), job),
      leading: running
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(value: progress, strokeWidth: 3),
            )
          : Icon(
              jobStageIcon(job.stage),
              color: job.stage == JobStage.failed ? scheme.error : null,
            ),
      title: Text(
        job.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.stage == JobStage.failed && job.error != null
                ? job.error!.message
                : jobStageLabel(l10n, job),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: job.stage == JobStage.failed ? scheme.error : null,
            ),
          ),
          if (running && progress != null) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
      isThreeLine: running,
    );
  }
}
