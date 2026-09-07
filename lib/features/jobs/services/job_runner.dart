/// Purpose: Run transcription jobs, one at a time, and survive being
/// interrupted.
/// Inputs: Jobs from the store, the media toolkit, the library and the
/// transcription client.
/// Returns: Progress, through a listenable queue state, and a revision counter
/// that says when a record on disk has changed.
/// Side effects: Runs FFmpeg, makes network requests, writes files, holds the
/// screen awake.
/// Notes: The stage machine and its resume rule are the heart of this app.
/// Everything it does is recorded after each window, so closing the app mid-run
/// costs at most the window that was in flight. See
/// `doc/en-us/features/transcription-jobs.md`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:myapps_data/myapps_data.dart' show SyncWakeLock;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../media/services/media_toolkit.dart';
import '../../providers/services/dialects.dart';
import '../../providers/services/provider_dialect.dart';
import '../../providers/services/settings_repository.dart';
import '../../providers/services/transcription_client.dart';
import '../../secrets/services/secrets_store.dart';
import '../../transcript/models/transcript.dart';
import '../../transcript/services/speaker_unifier.dart';
import '../../transcript/services/transcript_store.dart';
import '../models/chunk_plan.dart';
import '../models/transcription_job.dart';
import 'chunk_planner.dart';
import 'job_store.dart';
import 'output_writer.dart';
import 'transcript_merger.dart';

/// What the runner is doing, for the pages watching it.
class JobQueueState {
  /// The job being worked on, or null when nothing is running.
  final TranscriptionJob? active;

  /// The ids waiting their turn, in order.
  final List<String> queued;

  /// The last job to stop for good, whatever became of it.
  ///
  /// A page watching a job it is showing loses [active] the instant that job
  /// finishes, and what it falls back to is a record read from disk before the
  /// run began. Keeping the finished job here is what lets the page say
  /// "finished" at once instead of showing the stage it started at until
  /// something else happens to re-read the file.
  final TranscriptionJob? finished;

  /// Purpose: Create a queue state.
  /// Inputs: [active], [queued], [finished].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const JobQueueState({this.active, this.queued = const [], this.finished});
}

/// Runs jobs.
class JobRunner {
  /// Purpose: Create the runner.
  /// Inputs: The [toolkit] resolver, the [repository], the [client] factory and
  /// an id generator, all injectable for tests.
  /// Returns: A new runner.
  /// Side effects: None until [enqueue] or [restore] is called.
  /// Notes: Everything it touches is injected, so the whole state machine can
  /// be exercised with a fake toolkit and a fake server — no FFmpeg, no
  /// network, no key.
  JobRunner({
    required Future<MediaToolkit> Function() toolkit,
    required SettingsRepository repository,
    TranscriptionClient Function()? clientFactory,
    Future<String?> Function(String providerId)? keyLookup,
    Uuid? uuid,
  }) : _toolkit = toolkit,
       _repository = repository,
       _clientFactory = clientFactory ?? TranscriptionClient.new,
       _keyLookup = keyLookup ?? SecretsStore.keyFor,
       _uuid = uuid ?? const Uuid();

  final Future<MediaToolkit> Function() _toolkit;
  final SettingsRepository _repository;
  final TranscriptionClient Function() _clientFactory;
  final Future<String?> Function(String) _keyLookup;
  final Uuid _uuid;

  /// What the runner is doing, for the UI to watch.
  final ValueNotifier<JobQueueState> state = ValueNotifier(
    const JobQueueState(),
  );

  /// Bumped whenever a job record on disk has changed.
  ///
  /// [state] says what is happening *now*; this says that what is *written* is
  /// no longer what a page last read. The providers that read job records watch
  /// it, so a job that finishes, is created, renamed or deleted reaches every
  /// page without anybody having to remember to refresh a list.
  final ValueNotifier<int> revision = ValueNotifier(0);

  final _queue = <String>[];

  /// Names given to jobs while the runner might still write over them.
  ///
  /// Re-applied on every write, so a rename during a run survives the next
  /// window's save. Entries are harmless once the job has stopped: they say the
  /// same thing the record already does.
  final _titles = <String, String?>{};

  /// The most recent state of the running job.
  ///
  /// [_advance] works on its own local copy as it moves through the stages, so
  /// when it throws, the copy [_run] started with is several stages out of
  /// date. Writing *that* back would erase the plan and every finished window,
  /// and the next run would pay for them all again — which is the one thing
  /// resuming exists to prevent. Every save records the truth here.
  TranscriptionJob? _latest;

  bool _busy = false;

  /// The job the runner has taken off the queue, from the moment it takes it.
  ///
  /// [state] cannot answer this: a job leaves the queue synchronously and only
  /// reaches `active` after its record has been read, so for a moment it is in
  /// neither place. Anything that must not touch a job the runner is about to
  /// start asks here.
  String? _running;

  MediaCancelToken? _mediaCancel;
  TranscriptionClient? _activeClient;
  String? _cancelRequested;

  /// Purpose: Create a job for a recording.
  /// Inputs: The [sourcePath], the [providerId] and [modelId], and the
  /// [options].
  /// Returns: The new job, already saved.
  /// Side effects: Writes the job record.
  /// Notes: The model's wire name is copied onto the job, so a finished
  /// transcript can still say what produced it after the model has been renamed
  /// or removed from the library.
  Future<TranscriptionJob> create({
    required String sourcePath,
    required String providerId,
    required String modelId,
    required String modelName,
    JobOptions options = const JobOptions(),
  }) async {
    final file = File(sourcePath);
    final now = DateTime.now().toUtc();
    final job = TranscriptionJob(
      id: _uuid.v4(),
      createdAt: now,
      modifiedAt: now,
      sourcePath: sourcePath,
      sourceName: p.basename(sourcePath),
      sourceBytes: file.existsSync() ? file.lengthSync() : 0,
      providerId: providerId,
      modelId: modelId,
      modelName: modelName,
      options: options,
    );
    final created = await _write(job);
    _bump();
    return created;
  }

  /// Purpose: Put a job in the queue.
  /// Inputs: [jobId].
  /// Returns: None.
  /// Side effects: Starts the runner when it is idle.
  /// Notes: One job runs at a time. Overlapping them would make the resume
  /// ordering harder to reason about and would multiply the requests a source
  /// sees at once, which is how rate limits are hit.
  void enqueue(String jobId) {
    if (_queue.contains(jobId)) return;
    _queue.add(jobId);
    _publish();
    // A job resumed from a failure still says "did not finish" on disk until
    // the runner reaches it, which with other jobs ahead of it can be minutes.
    // Marking it waiting immediately is what the user just asked for.
    unawaited(_markQueued(jobId));
    unawaited(_pump());
  }

  /// Purpose: Record that a job is waiting its turn.
  /// Inputs: [jobId].
  /// Returns: None.
  /// Side effects: Rewrites the job's stage when it had stopped.
  /// Notes: Internal helper used within this file only. The finished windows
  /// and the plan are left alone; only the stage and the old error go.
  Future<void> _markQueued(String jobId) async {
    final job = await JobStore.load(jobId);
    if (job == null || !job.stage.isFinished) return;
    await _write(
      job.copyWith(
        stage: JobStage.queued,
        clearError: true,
        clearCurrentChunk: true,
      ),
    );
    _bump();
  }

  /// Purpose: Re-queue jobs that were interrupted, and clear up after the ones
  /// that finished.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Rewrites the stage of any job left mid-run, queues it, and
  /// deletes split audio a finished job could not delete for itself.
  /// Notes: Called at startup. A job whose record says "uploading" was closed
  /// mid-flight; leaving it in that stage would show a progress bar that never
  /// moves, so it becomes queued and resumes from its finished windows.
  Future<void> restore() async {
    final jobs = await JobStore.loadAll();
    for (final job in jobs) {
      if (!job.stage.isRunning) continue;
      await _write(
        job.copyWith(stage: JobStage.queued, clearCurrentChunk: true),
      );
      enqueue(job.id);
    }
    await _sweepChunkAudio(jobs);
    _bump();
  }

  /// Purpose: Delete split audio a finished job left behind.
  /// Inputs: The [jobs] on disk.
  /// Returns: None.
  /// Side effects: Deletes chunk audio files.
  /// Notes: Internal helper used within this file only. A job deletes its own
  /// windows when it finishes, but a file another process is holding at that
  /// instant survives, and nothing used to come back for it — so a window as
  /// large as a tenth of the recording sat in the job folder for good. Whatever
  /// was holding it has certainly let go by the next start.
  ///
  /// Only jobs that finished, were not asked to keep their windows, and were
  /// actually split. Anything else either has no windows or has them on
  /// purpose.
  Future<void> _sweepChunkAudio(List<TranscriptionJob> jobs) async {
    for (final job in jobs) {
      if (job.stage != JobStage.done) continue;
      if (job.options.keepChunks) continue;
      if (job.plan?.uploadsOriginal != false) continue;
      await JobStore.deleteChunkAudio(job.id);
    }
  }

  /// Purpose: Stop a job.
  /// Inputs: [jobId].
  /// Returns: None.
  /// Side effects: Cancels the running conversion and the in-flight upload, or
  /// removes the job from the queue.
  /// Notes: A cancelled job keeps the windows it finished, so resuming it does
  /// not pay for them again.
  void cancel(String jobId) {
    _queue.remove(jobId);
    if (state.value.active?.id == jobId) {
      _cancelRequested = jobId;
      _mediaCancel?.cancel();
      _activeClient?.cancel();
    }
    _publish();
  }

  /// Purpose: Run a job again with one feature turned off.
  /// Inputs: [jobId], and which feature to drop.
  /// Returns: None.
  /// Side effects: Rewrites the job's options and queues it.
  /// Notes: Offered when a source refuses something the user asked for. The
  /// finished windows are kept in the record, but dropping the feature changes
  /// the plan's fingerprint, so they will be discarded on the way through —
  /// which is right, because they were produced under the settings that failed.
  Future<void> retryWithout(String jobId, {required bool diarize}) async {
    final job = await JobStore.load(jobId);
    if (job == null) return;
    await _write(
      job.copyWith(
        options: job.options.copyWith(diarize: diarize),
        stage: JobStage.queued,
        clearError: true,
        clearCurrentChunk: true,
      ),
    );
    _bump();
    enqueue(jobId);
  }

  /// Purpose: Delete a job and everything belonging to it.
  /// Inputs: [jobId].
  /// Returns: None.
  /// Side effects: Stops the job if it is running, then removes its folder.
  /// Notes: Cancelled first. Deleting the folder out from under a running
  /// conversion would leave FFmpeg writing into nothing and the runner failing
  /// on a file that vanished, which is a confusing way to report a deletion the
  /// user asked for.
  Future<void> remove(String jobId) async {
    cancel(jobId);
    // `_running` rather than the published state, because a job that has just
    // been taken off the queue is in neither place for a moment, and deleting
    // its folder in that moment is exactly the race this loop exists to avoid.
    while (_running == jobId) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await JobStore.delete(jobId);
    _titles.remove(jobId);
    _bump();
  }

  /// Purpose: Give a transcription a name of its own.
  /// Inputs: [jobId] and the [title]; blank or null puts the recording's file
  /// name back.
  /// Returns: None.
  /// Side effects: Rewrites the job record.
  /// Notes: Works while the job is running. The runner carries its own copy of
  /// a job through the stages and writes that copy after every window, so a
  /// rename written straight to disk would be overwritten within seconds. The
  /// name is remembered here and re-applied to every write until the run ends,
  /// which is what makes renaming something the user can do at any time rather
  /// than only when nothing is happening.
  Future<void> rename(String jobId, String? title) async {
    final trimmed = title?.trim();
    final next = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _titles[jobId] = next;

    final job = await JobStore.load(jobId);
    if (job == null) return;
    final renamed = await _write(
      job.copyWith(title: next, clearTitle: next == null),
    );

    // The page showing a job that has just finished reads it from here, so this
    // copy has to learn the new name too.
    if (state.value.finished?.id == jobId) {
      state.value = JobQueueState(
        active: state.value.active,
        queued: List.of(_queue),
        finished: renamed,
      );
    }
    _bump();
  }

  /// Purpose: Remove a job's converted audio, keeping everything else.
  /// Inputs: [jobId].
  /// Returns: Whether anything was removed.
  /// Side effects: Deletes the converted copy and any window audio.
  /// Notes: Refused while the job is running or waiting — the converted copy is
  /// what the windows are cut from, and taking it away mid-run would make the
  /// job fail on a file that vanished. The transcript, the record and the raw
  /// replies stay, so the only thing lost is playback.
  Future<bool> discardAudio(String jobId) async {
    if (_running == jobId || _queue.contains(jobId)) return false;
    await JobStore.deleteConvertedAudio(jobId);
    _bump();
    return true;
  }

  /// Purpose: Work through the queue.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Runs jobs.
  /// Notes: Internal helper used within this file only. The busy flag is the
  /// only thing keeping two runs apart, so every exit path clears it.
  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_queue.isNotEmpty) {
        final id = _queue.removeAt(0);
        _running = id;
        try {
          final job = await JobStore.load(id);
          if (job == null) continue;
          await _run(job);
        } finally {
          _running = null;
        }
      }
    } finally {
      _busy = false;
      state.value = JobQueueState(
        queued: List.of(_queue),
        finished: state.value.finished,
      );
    }
  }

  /// Purpose: Run one job from wherever it left off.
  /// Inputs: [initial].
  /// Returns: None.
  /// Side effects: Everything a job does.
  /// Notes: Internal helper used within this file only. The screen is kept
  /// awake for the duration and released in every exit path, including a
  /// failure and a cancellation.
  Future<void> _run(TranscriptionJob initial) async {
    _cancelRequested = null;
    _latest = initial;
    await SyncWakeLock.acquire();
    try {
      await _advance(initial);
    } on _JobCancelled {
      await _save(
        _latest!.copyWith(stage: JobStage.cancelled, clearCurrentChunk: true),
      );
    } on _JobFailed catch (failure) {
      await _save(
        _latest!.copyWith(
          stage: JobStage.failed,
          error: failure.error,
          clearCurrentChunk: true,
        ),
      );
    } catch (error) {
      await _save(
        _latest!.copyWith(
          stage: JobStage.failed,
          error: JobError(kind: JobFailureKind.unknown, message: '$error'),
          clearCurrentChunk: true,
        ),
      );
    } finally {
      await SyncWakeLock.release();
      // Whatever it became — done, failed or cancelled — this is the record
      // that was just written, and it is what a page showing this job needs
      // before it can re-read the file for itself.
      final last = _latest;
      _mediaCancel = null;
      _activeClient = null;
      _cancelRequested = null;
      _latest = null;
      state.value = JobQueueState(
        queued: List.of(_queue),
        finished: last ?? state.value.finished,
      );
      _bump();
    }
  }

  /// Purpose: Take a job through every stage.
  /// Inputs: [initial].
  /// Returns: The finished job.
  /// Side effects: Everything a job does.
  /// Notes: Internal helper used within this file only.
  Future<TranscriptionJob> _advance(TranscriptionJob initial) async {
    var job = initial;
    final library = await _repository.load();
    final provider = library.provider(job.providerId);
    final model = library.model(job.modelId);
    if (provider == null || model == null) {
      throw _JobFailed(
        const JobError(
          kind: JobFailureKind.configurationMissing,
          message:
              'The source or model this job used is no longer in the library.',
        ),
      );
    }

    final source = File(job.sourcePath);
    if (!source.existsSync()) {
      throw _JobFailed(
        JobError(
          kind: JobFailureKind.sourceMissing,
          message: 'The recording is no longer at ${job.sourcePath}.',
        ),
      );
    }

    final apiKey = await _keyLookup(job.providerId);
    if (provider.needsApiKey && (apiKey == null || apiKey.isEmpty)) {
      throw _JobFailed(
        JobError(
          kind: JobFailureKind.noApiKey,
          message: 'No API key is set for ${provider.name}.',
        ),
      );
    }

    final toolkit = await _toolkit();
    final toolkitReady = (await toolkit.status()).available;

    // ── Probe ──
    job = await _save(job.copyWith(stage: JobStage.probing, clearError: true));
    _checkCancelled(job);
    var media = job.media;
    if (media == null && toolkitReady) {
      try {
        media = await toolkit.probe(job.sourcePath);
      } on MediaException catch (error) {
        if (error.kind == MediaFailureKind.badInput) {
          throw _JobFailed(
            JobError(kind: JobFailureKind.badInput, message: error.message),
          );
        }
        // Anything else leaves the planner to work from the file size alone.
      }
    }

    // ── Plan ──
    job = await _save(job.copyWith(stage: JobStage.planning, media: media));
    _checkCancelled(job);
    final handler = dialectHandler(provider.dialect);
    final probe = TranscriptionRequest(
      file: source,
      mimeType: mimeTypeForPath(job.sourcePath),
      languages: job.options.languages,
      prompt: job.options.prompt,
      keywords: job.options.keywords,
      diarize: job.options.diarize,
    );
    final planRequest = PlanRequest(
      sourceBytes: job.sourceBytes,
      sourceExtension: p.extension(job.sourcePath).replaceFirst('.', ''),
      media: media,
      model: model,
      provider: provider,
      diarize: job.options.diarize,
      jsonMode: handler.needsJsonBody(probe, model),
      overlapSeconds: job.options.overlapSeconds,
      userWindowSeconds: job.options.windowSeconds,
      toolkitAvailable: toolkitReady,
      settingsFingerprintParts: [
        job.options.languages.join(','),
        job.options.prompt ?? '',
        job.options.keywords.join(','),
      ],
    );
    final planned = ChunkPlanner.plan(planRequest);
    if (!planned.isSuccess) {
      throw _JobFailed(_planFailure(planned.failure!));
    }
    var plan = planned.plan!;

    // A plan made under different settings invalidates every cached window: a
    // result produced with another model, or another window length, is not the
    // result the user is now asking for.
    var chunks = job.plan?.fingerprint == plan.fingerprint
        ? List<ChunkResult>.of(job.chunks)
        : <ChunkResult>[];
    job = await _save(job.copyWith(plan: plan, chunks: chunks));

    // ── Convert ──
    File audioSource = source;
    if (!plan.uploadsOriginal) {
      final normalized = await JobStore.normalizedAudio(job.id);
      if (!normalized.existsSync()) {
        job = await _save(job.copyWith(stage: JobStage.normalizing));
        _checkCancelled(job);
        final cancel = MediaCancelToken();
        _mediaCancel = cancel;
        try {
          await toolkit.normalize(
            job.sourcePath,
            normalized.path,
            cancel: cancel,
          );
        } on MediaException catch (error) {
          if (error.kind == MediaFailureKind.cancelled) {
            throw const _JobCancelled();
          }
          throw _JobFailed(
            JobError(kind: JobFailureKind.mediaFailed, message: error.message),
          );
        } finally {
          await cancel.dispose();
          _mediaCancel = null;
        }
      }
      audioSource = normalized;
    }

    // ── Windows ──
    // Carrying voice samples forward is only possible when the model accepts
    // them, the recording is actually split, and there is a converted copy to
    // cut samples out of.
    final enrolling =
        job.options.enrollment &&
        job.options.diarize &&
        (model.maxKnownSpeakers ?? 0) > 0 &&
        !plan.uploadsOriginal &&
        toolkitReady;

    final client = _clientFactory();
    _activeClient = client;
    try {
      for (final window in plan.windows) {
        _checkCancelled(job);
        if (chunks.any((c) => c.index == window.index)) continue;

        final chunkFile = plan.uploadsOriginal
            ? audioSource
            : await JobStore.chunkFile(job.id, window.index);

        if (!plan.uploadsOriginal) {
          job = await _save(
            job.copyWith(stage: JobStage.cutting, currentChunk: window.index),
          );
          if (!chunkFile.existsSync()) {
            final cancel = MediaCancelToken();
            _mediaCancel = cancel;
            try {
              await toolkit.extractWindow(
                audioSource.path,
                window.startSeconds,
                window.lengthSeconds,
                chunkFile.path,
                cancel: cancel,
              );
            } on MediaException catch (error) {
              if (error.kind == MediaFailureKind.cancelled) {
                throw const _JobCancelled();
              }
              throw _JobFailed(
                JobError(
                  kind: JobFailureKind.mediaFailed,
                  message: error.message,
                ),
              );
            } finally {
              await cancel.dispose();
              _mediaCancel = null;
            }
          }
        }

        job = await _save(
          job.copyWith(stage: JobStage.uploading, currentChunk: window.index),
        );
        _checkCancelled(job);

        // Voices the earlier windows established, so this one can recognise
        // them rather than being matched to them afterwards.
        final known = enrolling
            ? await _enrol(job, audioSource, toolkit, model.maxKnownSpeakers)
            : const <KnownSpeaker>[];

        final TranscriptionResult result;
        try {
          result = await client.transcribe(
            request: TranscriptionRequest(
              file: chunkFile,
              mimeType: mimeTypeForPath(chunkFile.path),
              languages: job.options.languages,
              prompt: job.options.prompt,
              keywords: job.options.keywords,
              diarize: job.options.diarize,
              knownSpeakers: known,
            ),
            provider: provider,
            model: model,
            apiKey: apiKey,
            windowSeconds: window.lengthSeconds,
          );
        } on TranscriptionException catch (error) {
          if (_cancelRequested == job.id) throw const _JobCancelled();
          throw _JobFailed(_requestFailure(error));
        }

        // Keep the raw reply. It is small, and it is what lets the speaker
        // matching be re-run later without uploading anything again.
        await File(
          (await JobStore.chunkResponseFile(job.id, window.index)).path,
        ).writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'text': result.text,
            'segments': [
              for (final segment in result.segments)
                {
                  'start': segment.startSeconds,
                  'end': segment.endSeconds,
                  'text': segment.text,
                  if (segment.speaker != null) 'speaker': segment.speaker,
                },
            ],
          }),
        );

        chunks = [
          ...chunks,
          ChunkResult(
            index: window.index,
            startSeconds: window.startSeconds,
            lengthSeconds: window.lengthSeconds,
            chunkBytes: chunkFile.existsSync() ? chunkFile.lengthSync() : 0,
            text: result.text,
            segments: [
              for (final segment in result.segments)
                ChunkSegment(
                  startSeconds: segment.startSeconds,
                  endSeconds: segment.endSeconds,
                  text: segment.text,
                  speaker: segment.speaker,
                ),
            ],
            hasRealTimestamps: result.hasRealTimestamps,
            // What this window was told about; the matching takes an echoed id
            // as a voice match, and a resume needs to know it was sent.
            knownSpeakerIds: [for (final speaker in known) speaker.id],
          ),
        ]..sort((a, b) => a.index.compareTo(b.index));
        job = await _save(job.copyWith(chunks: chunks));
      }
    } finally {
      _activeClient = null;
    }

    // ── Merge ──
    job = await _save(
      job.copyWith(stage: JobStage.merging, clearCurrentChunk: true),
    );
    final segments = _merge(job, plan);

    // ── Speakers ──
    // Each window labelled its speakers with no idea what the last one called
    // them, so the labels are joined up before anything is written.
    var speakerMap = const <String, String>{};
    if (job.chunks.any(
      (chunk) => chunk.segments.any((segment) => segment.speaker != null),
    )) {
      job = await _save(job.copyWith(stage: JobStage.namingSpeakers));
      speakerMap = _unifySpeakers(job);
    }

    // ── Render ──
    job = await _save(job.copyWith(stage: JobStage.rendering));
    // The transcript is built and written before the two text files, because it
    // is the one the viewer reads and the one the user's later corrections live
    // in; the text files are a rendering of it. Rendering them from the same
    // value is also what gives them the unified speaker names rather than each
    // window's own labels.
    final transcript = TranscriptStore.fromMerged(
      job.id,
      segments,
      timestamped:
          job.chunks.isNotEmpty &&
          job.chunks.every((chunk) => chunk.hasRealTimestamps),
      speakerMap: speakerMap,
    );
    await TranscriptStore.save(transcript);
    final outputs = await _writeOutputs(job, transcript);

    if (!job.options.keepChunks && !plan.uploadsOriginal) {
      await JobStore.deleteChunkAudio(job.id);
    }

    return _save(
      job.copyWith(
        stage: JobStage.done,
        finishedAt: DateTime.now().toUtc(),
        outputs: outputs,
        clearCurrentChunk: true,
        clearError: true,
      ),
    );
  }

  /// Purpose: Join the finished windows into one transcript.
  /// Inputs: [job], [plan].
  /// Returns: The merged segments.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Which rule applies is
  /// decided by what the source actually returned, not by what was asked for:
  /// a model that was expected to give times and did not still produces a
  /// readable transcript.
  List<MergedSegment> _merge(TranscriptionJob job, ChunkPlan plan) {
    final ordered = List<ChunkResult>.of(job.chunks)
      ..sort((a, b) => a.index.compareTo(b.index));
    if (ordered.isEmpty) return const [];

    final starts = [for (final chunk in ordered) chunk.startSeconds];
    final timed = ordered.every((chunk) => chunk.hasRealTimestamps);

    if (!timed) {
      return mergeTextOnly(
        [for (final chunk in ordered) chunk.text],
        starts,
        plan.strideSeconds,
      );
    }

    return mergeTimedSegments(
      [
        for (final chunk in ordered)
          [
            for (final segment in chunk.segments)
              MergedSegment(
                // Window-local times become absolute here, once, so nothing
                // downstream has to remember which window a segment came from
                // in order to place it.
                startSeconds: chunk.startSeconds + segment.startSeconds,
                endSeconds: chunk.startSeconds + segment.endSeconds,
                text: segment.text,
                chunkIndex: chunk.index,
                localSpeaker: segment.speaker,
              ),
          ],
      ],
      starts,
      plan.overlapSeconds,
    );
  }

  /// Purpose: Cut a short clip of each speaker heard so far, to send with the
  /// next window.
  /// Inputs: The [job], the converted [audio], the [toolkit], and how many
  /// samples the model will [limit] itself to.
  /// Returns: The speakers to name, longest-talking first.
  /// Side effects: Writes a WAV per speaker into the job's speakers folder.
  /// Notes: Internal helper used within this file only. This is what turns the
  /// matching from guesswork into recognition: the source is told "this voice
  /// is spk_1" and echoes the id back, so a speaker who is silent through a
  /// whole overlap still keeps their identity. The clip comes from their
  /// longest line, which is the most likely to be clean speech rather than a
  /// two-word interjection. A sample already cut is reused, so a resume does
  /// not re-cut them all.
  Future<List<KnownSpeaker>> _enrol(
    TranscriptionJob job,
    File audio,
    MediaToolkit toolkit,
    int? limit,
  ) async {
    if (job.chunks.isEmpty) return const [];

    final map = _unifySpeakers(job);
    if (map.isEmpty) return const [];

    // The longest clean line for each speaker, and how long they talk overall.
    final best = <String, ({double start, double length})>{};
    final talking = <String, double>{};
    for (final chunk in job.chunks) {
      for (final segment in chunk.segments) {
        final label = segment.speaker;
        if (label == null) continue;
        final speakerId = map['${chunk.index}:$label'];
        if (speakerId == null) continue;

        final start = chunk.startSeconds + segment.startSeconds;
        final length = segment.endSeconds - segment.startSeconds;
        if (length <= 0) continue;

        talking[speakerId] = (talking[speakerId] ?? 0) + length;
        if (length > (best[speakerId]?.length ?? 0)) {
          best[speakerId] = (start: start, length: length);
        }
      }
    }

    final ranked = talking.keys.toList()
      ..sort((a, b) => talking[b]!.compareTo(talking[a]!));

    final speakers = <KnownSpeaker>[];
    for (final speakerId in ranked.take(limit ?? ranked.length)) {
      final line = best[speakerId];
      if (line == null || line.length < _minSampleSeconds) continue;

      final file = await JobStore.speakerSample(job.id, speakerId);
      if (!file.existsSync()) {
        try {
          await toolkit.cutSample(
            audio.path,
            // A little way in, so the clip does not open on the moment the
            // previous speaker stopped.
            line.start + 0.5,
            line.length.clamp(_minSampleSeconds, _maxSampleSeconds),
            file.path,
          );
        } on MediaException {
          // A sample that will not cut is not worth failing a job over; the
          // overlap matching still has to work without one.
          continue;
        }
      }
      if (file.existsSync()) {
        speakers.add(KnownSpeaker(id: speakerId, sample: file));
      }
    }
    return speakers;
  }

  /// Purpose: Join each window's speaker labels into speakers that mean the
  /// same thing across the whole recording.
  /// Inputs: [job].
  /// Returns: A map from `"<window>:<label>"` to a speaker id.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Run on the raw window
  /// results rather than on the merged segments, because the overlap is the
  /// evidence and the merge is what removes it. Any known-speaker ids a source
  /// echoed back are passed through, since a voice the source recognised from a
  /// sample beats any amount of overlap arithmetic.
  Map<String, String> _unifySpeakers(TranscriptionJob job) {
    final ordered = List<ChunkResult>.of(job.chunks)
      ..sort((a, b) => a.index.compareTo(b.index));

    final windows = [
      for (final chunk in ordered)
        [
          for (final segment in chunk.segments)
            if (segment.speaker case final label?)
              LabelledSegment(
                windowIndex: chunk.index,
                label: label,
                startSeconds: chunk.startSeconds + segment.startSeconds,
                endSeconds: chunk.startSeconds + segment.endSeconds,
                text: segment.text,
              ),
        ],
    ];

    return unifySpeakers(
      windows,
      knownIds: {for (final chunk in ordered) ...chunk.knownSpeakerIds},
    ).map;
  }

  /// Purpose: Write the Markdown and text transcripts.
  /// Inputs: [job], the [transcript] it produced.
  /// Returns: The paths written.
  /// Side effects: Writes files.
  /// Notes: Internal helper used within this file only. Beside the recording
  /// when that folder can be written, which is where the scripts put them and
  /// where somebody looking for the transcript will look first; otherwise in
  /// the job's own exports folder.
  ///
  /// Named after the **recording**, not after the job's own title: these files
  /// live beside the recording and a folder full of them is read by file name.
  Future<List<String>> _writeOutputs(
    TranscriptionJob job,
    Transcript transcript,
  ) async {
    final stem = p.basenameWithoutExtension(job.sourceName);
    final markdown = renderJobMarkdown(job, transcript);
    final text = renderJobPlainText(transcript);

    Directory target;
    try {
      final beside = File(job.sourcePath).parent;
      final probe = File(p.join(beside.path, '.mytranscribe_write_test'));
      await probe.writeAsString('');
      await probe.delete();
      target = beside;
    } catch (_) {
      target = await JobStore.exportsDir(job.id);
    }

    final markdownPath = p.join(target.path, '$stem.transcript.md');
    final textPath = p.join(target.path, '$stem.transcript.txt');
    await File(markdownPath).writeAsString(markdown);
    await File(textPath).writeAsString(text);
    return [markdownPath, textPath];
  }

  /// Purpose: Write a job, applying anything renamed since it was read.
  /// Inputs: [job].
  /// Returns: What was actually written.
  /// Side effects: Writes the record.
  /// Notes: Internal helper used within this file only. Every write goes
  /// through here so a rename made while a job is running cannot be undone by
  /// the runner's own older copy — which it would be, on the very next window.
  Future<TranscriptionJob> _write(TranscriptionJob job) async {
    var next = job;
    if (_titles.containsKey(job.id)) {
      final title = _titles[job.id];
      next = job.copyWith(title: title, clearTitle: title == null);
    }
    await JobStore.save(next);
    return next;
  }

  /// Purpose: Save a job and publish it.
  /// Inputs: [job].
  /// Returns: The saved job.
  /// Side effects: Writes the record and updates [state].
  /// Notes: Internal helper used within this file only. Every stage change goes
  /// through here, which is what makes the record on disk always match what the
  /// UI is showing.
  Future<TranscriptionJob> _save(TranscriptionJob job) async {
    final written = await _write(job);
    _latest = written;
    state.value = JobQueueState(
      active: written,
      queued: List.of(_queue),
      finished: state.value.finished,
    );
    return written;
  }

  /// Purpose: Publish the queue without changing a job.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Updates [state].
  /// Notes: Internal helper used within this file only.
  void _publish() {
    state.value = JobQueueState(
      active: state.value.active,
      queued: List.of(_queue),
      finished: state.value.finished,
    );
  }

  /// Purpose: Say that a job record on disk has changed.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Notifies everything watching [revision].
  /// Notes: Internal helper used within this file only. Called from every path
  /// that writes or deletes a record, so the providers that read them can
  /// re-read without any page having to remember to ask.
  void _bump() => revision.value++;

  /// Purpose: Stop the job when the user has asked to.
  /// Inputs: [job].
  /// Returns: None; throws when cancelled.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Checked between stages
  /// so a cancel takes effect at the next boundary even when nothing long is
  /// running at that moment.
  void _checkCancelled(TranscriptionJob job) {
    if (_cancelRequested == job.id) throw const _JobCancelled();
  }

  /// Purpose: Turn a planning failure into a job error.
  /// Inputs: [failure].
  /// Returns: A [JobError].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  JobError _planFailure(PlanFailure failure) => switch (failure) {
    PlanFailure.mediaToolkitMissing => const JobError(
      kind: JobFailureKind.mediaToolkitMissing,
      message:
          'This recording has to be split, which needs FFmpeg. Set it up in '
          'Settings.',
    ),
    PlanFailure.durationUnknown => const JobError(
      kind: JobFailureKind.badInput,
      message: 'The length of this recording could not be read.',
    ),
    PlanFailure.noAudio => const JobError(
      kind: JobFailureKind.badInput,
      message: 'That file has no audio to transcribe.',
    ),
  };

  /// Purpose: Turn a request failure into a job error.
  /// Inputs: [error].
  /// Returns: A [JobError].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The source's own words
  /// are carried through, and the feature it refused is recorded so the detail
  /// page can offer to run again without it.
  JobError _requestFailure(TranscriptionException error) => JobError(
    kind: switch (error.failure) {
      TranscriptionFailure.unauthorized => JobFailureKind.noApiKey,
      TranscriptionFailure.network => JobFailureKind.network,
      TranscriptionFailure.cancelled => JobFailureKind.unknown,
      _ => JobFailureKind.requestRejected,
    },
    message: error.message,
    rejectedFeature: error.rejectedFeature?.name,
  );
}

/// The shortest voice sample worth sending, in seconds.
///
/// Below this the sources that accept reference clips reject them, and a clip
/// that short would not identify anybody anyway.
const _minSampleSeconds = 2.0;

/// The longest voice sample worth sending, in seconds.
///
/// The published limit is ten; more audio does not improve the match and every
/// window's request carries all of them.
const _maxSampleSeconds = 8.0;

/// Thrown inside a run when the user cancelled.
class _JobCancelled implements Exception {
  const _JobCancelled();
}

/// Thrown inside a run when the job cannot continue.
class _JobFailed implements Exception {
  const _JobFailed(this.error);

  final JobError error;
}
