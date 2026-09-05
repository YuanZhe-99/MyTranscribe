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

/// Every job on disk, newest first.
///
/// Refreshed — `ref.refresh` in this Riverpod version — whenever a job is
/// created, finishes or is deleted.
final jobsListProvider = FutureProvider<List<TranscriptionJob>>((ref) async {
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
  return JobStore.load(jobId);
});
