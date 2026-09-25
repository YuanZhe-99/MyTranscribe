/// Purpose: Hand the pages one runner and one list of jobs.
/// Inputs: The media toolkit and the settings repository.
/// Returns: Riverpod providers.
/// Side effects: Creating the runner starts nothing; enqueuing does.
/// Notes: There is exactly one runner for the whole app. Two would race for the
/// same job folders and would each think they were the only one writing, so the
/// provider is deliberately not scoped or auto-disposed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../local/services/engine_registry.dart';
import '../../local/services/local_transcription_backend.dart';
import '../../local/services/route_smoke_test.dart';
import '../../local/services/smoke_clip.dart';
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
    // Local jobs route through the engine registry; every route passes the
    // check clip on this device before its first job.
    localBackend: LocalTranscriptionBackend(
      registry: ref.read(engineRegistryProvider),
      smokeTester: RouteSmokeTester(
        state: ref.read(localEngineStateStoreProvider),
      ),
      smokeClip: loadSmokeClip,
      speakerLabeler: ref.read(speakerLabelerProvider),
    ),
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
///
/// The runner is not the only writer. Sync, a backup restore and a ZIP import
/// all write job folders without going through it, which is why this adds the
/// store's own notifier: a transcription that arrived from another device has
/// to appear without the app being restarted too.
final jobRevisionProvider = Provider<int>((ref) {
  final runner = ref.watch(jobRunnerProvider);
  final outside = JobStore.changedOutsideRunner;
  void forward() => ref.state = runner.revision.value + outside.value;
  runner.revision.addListener(forward);
  outside.addListener(forward);
  ref.onDispose(() {
    runner.revision.removeListener(forward);
    outside.removeListener(forward);
  });
  return runner.revision.value + outside.value;
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
    FutureProvider.family<
      ({int bytes, bool hasConvertedAudio, bool hasSource}),
      String
    >((ref, jobId) async {
      ref.watch(jobRevisionProvider);
      return JobStore.storageInfo(jobId);
    });

/// How much converted audio every finished transcription is holding, in bytes.
///
/// Read by the settings page so the offer to remove it can say what it buys
/// back. Watches the revision, so the figure drops to zero the moment the
/// cleanup runs rather than after the page is reopened.
final convertedAudioTotalProvider = FutureProvider<int>((ref) async {
  ref.watch(jobRevisionProvider);
  return JobStore.convertedAudioBytes();
});
