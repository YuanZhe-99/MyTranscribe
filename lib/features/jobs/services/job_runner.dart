/// Purpose: Run transcription jobs, one at a time, and survive being
/// interrupted.
/// Inputs: Jobs from the store, the media toolkit, the library and the
/// transcription client.
/// Returns: Progress, through a listenable queue state.
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

  /// Purpose: Create a queue state.
  /// Inputs: [active], [queued].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const JobQueueState({this.active, this.queued = const []});
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

  final _queue = <String>[];

  /// The most recent state of the running job.
  ///
  /// [_advance] works on its own local copy as it moves through the stages, so
  /// when it throws, the copy [_run] started with is several stages out of
  /// date. Writing *that* back would erase the plan and every finished window,
  /// and the next run would pay for them all again — which is the one thing
  /// resuming exists to prevent. Every save records the truth here.
  TranscriptionJob? _latest;

  bool _busy = false;
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
    await JobStore.save(job);
    return job;
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
    unawaited(_pump());
  }

  /// Purpose: Re-queue jobs that were interrupted.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Rewrites the stage of any job left mid-run, and queues it.
  /// Notes: Called at startup. A job whose record says "uploading" was closed
  /// mid-flight; leaving it in that stage would show a progress bar that never
  /// moves, so it becomes queued and resumes from its finished windows.
  Future<void> restore() async {
    for (final job in await JobStore.loadAll()) {
      if (!job.stage.isRunning) continue;
      await JobStore.save(
        job.copyWith(stage: JobStage.queued, clearCurrentChunk: true),
      );
      enqueue(job.id);
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
    await JobStore.save(
      job.copyWith(
        options: job.options.copyWith(diarize: diarize),
        stage: JobStage.queued,
        clearError: true,
        clearCurrentChunk: true,
      ),
    );
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
    while (state.value.active?.id == jobId) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await JobStore.delete(jobId);
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
        final job = await JobStore.load(id);
        if (job == null) continue;
        await _run(job);
      }
    } finally {
      _busy = false;
      state.value = JobQueueState(queued: List.of(_queue));
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
      _mediaCancel = null;
      _activeClient = null;
      _cancelRequested = null;
      _latest = null;
      _publish();
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

    // ── Render ──
    job = await _save(job.copyWith(stage: JobStage.rendering));
    // The transcript is written before the two text files, because it is the
    // one the viewer reads and the one the user's later corrections live in;
    // the text files are a rendering of it.
    await TranscriptStore.save(
      TranscriptStore.fromMerged(
        job.id,
        segments,
        timestamped:
            job.chunks.isNotEmpty &&
            job.chunks.every((chunk) => chunk.hasRealTimestamps),
      ),
    );
    final outputs = await _writeOutputs(job, segments);

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

  /// Purpose: Write the Markdown and text transcripts.
  /// Inputs: [job], [segments].
  /// Returns: The paths written.
  /// Side effects: Writes files.
  /// Notes: Internal helper used within this file only. Beside the recording
  /// when that folder can be written, which is where the scripts put them and
  /// where somebody looking for the transcript will look first; otherwise in
  /// the job's own exports folder.
  Future<List<String>> _writeOutputs(
    TranscriptionJob job,
    List<MergedSegment> segments,
  ) async {
    final stem = p.basenameWithoutExtension(job.sourceName);
    final markdown = renderMarkdown(job, segments);
    final text = renderPlainText(segments);

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

  /// Purpose: Save a job and publish it.
  /// Inputs: [job].
  /// Returns: The saved job.
  /// Side effects: Writes the record and updates [state].
  /// Notes: Internal helper used within this file only. Every stage change goes
  /// through here, which is what makes the record on disk always match what the
  /// UI is showing.
  Future<TranscriptionJob> _save(TranscriptionJob job) async {
    _latest = job;
    await JobStore.save(job);
    state.value = JobQueueState(active: job, queued: List.of(_queue));
    return job;
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
    );
  }

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

/// Thrown inside a run when the user cancelled.
class _JobCancelled implements Exception {
  const _JobCancelled();
}

/// Thrown inside a run when the job cannot continue.
class _JobFailed implements Exception {
  const _JobFailed(this.error);

  final JobError error;
}
