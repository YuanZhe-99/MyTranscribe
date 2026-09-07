/// Purpose: Hand the pages one runner and one list of jobs.
/// Inputs: The media toolkit and the settings repository.
/// Returns: Riverpod providers.
/// Side effects: Creating the runner starts nothing; enqueuing does.
/// Notes: There is exactly one runner for the whole app. Two would race for the
/// same job folders and would each think they were the only one writing, so the
/// provider is deliberately not scoped or auto-disposed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../media/services/media_toolkit_provider.dart';
import '../../providers/services/settings_repository.dart';
import '../models/transcription_job.dart';
import 'job_runner.dart';
import 'job_store.dart';

/// The one job runner.
final jobRunnerProvider = Provider<JobRunner>((ref) {
  return JobRunner(
    // Resolved per run rather than held, so a user who sets up FFmpeg while the
    // app is open does not have to restart it before the next job can split.
    toolkit: () => ref.read(mediaToolkitProvider.future),
    repository: ref.read(settingsRepositoryProvider),
  );
});

/// How many times a job record has changed since the app started.
///
/// The bridge between the runner, which knows when it has written something,
/// and the providers below, which read what it wrote. Watching this is what
/// makes a job that finishes reach every page on its own: before it existed,
/// the only way a record was re-read was a page happening to refresh the list
/// after a button was pressed, so a job that finished while its own page was
/// open went on showing the stage it started at until the app was restarted.
final jobRevisionProvider = Provider<int>((ref) {
  final runner = ref.watch(jobRunnerProvider);
  void forward() => ref.state = runner.revision.value;
  runner.revision.addListener(forward);
  ref.onDispose(() => runner.revision.removeListener(forward));
  return runner.revision.value;
});

/// Every job on disk, newest first.
///
/// Re-read whenever [jobRevisionProvider] moves, which is every time a job is
/// created, finishes, is renamed or is deleted.
final jobsListProvider = FutureProvider<List<TranscriptionJob>>((ref) async {
  ref.watch(jobRevisionProvider);
  return JobStore.loadAll();
});

/// One job, re-read from disk.
///
/// The detail page watches this for a job that is not running; a running one
/// comes from the runner's own notifier, which is fresher.
final jobProvider = FutureProvider.family<TranscriptionJob?, String>((
  ref,
  jobId,
) async {
  ref.watch(jobRevisionProvider);
  return JobStore.load(jobId);
});

/// How much room one job takes, and whether its converted audio is still there.
///
/// Read for the detail page. Watches the revision so removing the converted
/// copy updates the figure without the page asking again.
final jobStorageProvider =
    FutureProvider.family<({int bytes, bool hasConvertedAudio}), String>((
      ref,
      jobId,
    ) async {
      ref.watch(jobRevisionProvider);
      return JobStore.storageInfo(jobId);
    });
