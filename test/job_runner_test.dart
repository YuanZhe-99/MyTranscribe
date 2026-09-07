/// Purpose: Test the transcription state machine end to end, without FFmpeg, a
/// network or an API key.
/// Inputs: None; a fake media toolkit and a fake transcription server stand in.
/// Returns: None.
/// Side effects: Writes into a temporary directory.
/// Notes: The cases that matter are the ones a user meets: a short recording
/// that goes up whole, a long one split into windows, an interrupted run that
/// picks up where it stopped, a cancellation, and a failure that says something
/// useful. Splitting is forced here by **duration** rather than by size, using
/// a model with a per-request time cap, so no test has to write a 25 MB file.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/jobs/services/job_runner.dart';
import 'package:my_transcribe/features/jobs/services/job_store.dart';
import 'package:my_transcribe/features/media/models/media_info.dart';
import 'package:my_transcribe/features/media/services/media_toolkit.dart';
import 'package:my_transcribe/features/providers/models/provider_templates.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/providers/services/transcription_client.dart';
import 'package:my_transcribe/features/transcript/services/transcript_store.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'golden/fake_transcription_server.dart';

/// A model with no caps at all, so a small file uploads whole.
const _wholeFileModel = 'gpt-transcribe';

/// A model capped at 1500 seconds a request, so a long recording is split.
const _cappedModel = 'gpt-4o-transcribe';

/// A path provider that answers with one temporary directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// A media toolkit that writes plausible files without running anything.
class _FakeToolkit implements MediaToolkit {
  _FakeToolkit({this.duration = 3600, this.available = true});

  /// What every probe reports.
  final double duration;

  /// Whether the toolkit claims to work.
  final bool available;

  /// How many windows were cut.
  int windowsCut = 0;

  /// Whether the whole recording was converted.
  bool normalized = false;

  /// Set to fail the next conversion, to exercise the error path.
  MediaException? failNormalize;

  @override
  Future<MediaToolkitStatus> status() async =>
      MediaToolkitStatus(available: available, detail: 'fake');

  @override
  Future<MediaInfo> probe(String path) async =>
      MediaInfo(durationSeconds: duration, audioCodec: 'mp3');

  @override
  Future<void> normalize(
    String source,
    String destination, {
    MediaProgress? onProgress,
    MediaCancelToken? cancel,
  }) async {
    if (failNormalize != null) throw failNormalize!;
    cancel?.throwIfCancelled();
    normalized = true;
    File(destination).writeAsBytesSync(Uint8List(4096));
  }

  @override
  Future<void> extractWindow(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    windowsCut++;
    File(destination).writeAsBytesSync(Uint8List(2048));
  }

  @override
  Future<void> cutSample(
    String source,
    double startSeconds,
    double lengthSeconds,
    String destination, {
    MediaCancelToken? cancel,
  }) async {
    File(destination).writeAsBytesSync(Uint8List(512));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late SettingsRepository repository;
  late File source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_runner_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    // The hub caches whether it has read its config; a fresh temp directory
    // per test needs that cache cleared, which resetting the path does.
    await TranscribeStorage.setStoragePath(null);
    repository = SettingsRepository();
    await repository.load();

    source = File(p.join(root.path, 'lecture.mp3'))
      ..writeAsBytesSync(Uint8List(1024 * 1024));
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Build a runner over the fakes.
  /// Inputs: The [toolkit] and the [server].
  /// Returns: A [JobRunner].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  JobRunner runner(_FakeToolkit toolkit, FakeTranscriptionServer server) =>
      JobRunner(
        toolkit: () async => toolkit,
        repository: repository,
        clientFactory: () => TranscriptionClient(
          clientFactory: () => server,
          sleep: (_) async {},
        ),
        keyLookup: (_) async => 'sk-test',
      );

  /// Purpose: Create a job against a built-in OpenAI model.
  /// Inputs: The [run]ner, the [model] wire name, the [path], and the
  /// [options].
  /// Returns: The created job.
  /// Side effects: Writes the job record.
  /// Notes: Internal helper used within this file only.
  Future<TranscriptionJob> createJob(
    JobRunner run, {
    String model = _cappedModel,
    String? path,
    JobOptions options = const JobOptions(),
  }) => run.create(
    sourcePath: path ?? source.path,
    providerId: openaiProviderId,
    modelId: templateModelId(openaiProviderId, model),
    modelName: model,
    options: options,
  );

  /// Purpose: Run a job to completion and return it.
  /// Inputs: The [run]ner and the [jobId].
  /// Returns: The finished job.
  /// Side effects: Runs the job.
  /// Notes: Internal helper used within this file only. Polls the record rather
  /// than the queue, because the record is what a resume would read.
  Future<TranscriptionJob> runToCompletion(JobRunner run, String jobId) async {
    run.enqueue(jobId);

    // A job being resumed still says "failed" on disk for the moment before the
    // runner picks it up, and reading that would be reading the previous run's
    // result. Wait for it to leave that state first.
    for (var i = 0; i < 200; i++) {
      final job = await JobStore.load(jobId);
      if (job != null && !job.stage.isFinished) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    for (var i = 0; i < 600; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final job = await JobStore.load(jobId);
      if (job != null && job.stage.isFinished) return job;
    }
    fail('the job did not finish');
  }

  group('a recording that needs splitting', () {
    test('is converted once, cut into windows, and joined back up', () async {
      final toolkit = _FakeToolkit();
      final server = FakeTranscriptionServer([
        FakeReply.text('the first window'),
        FakeReply.text('the second window'),
        FakeReply.text('the third window'),
      ]);
      final run = runner(toolkit, server);
      final job = await runToCompletion(run, (await createJob(run)).id);

      expect(
        job.stage,
        JobStage.done,
        reason: '${job.error?.kind}: ${job.error?.message}',
      );
      expect(toolkit.normalized, isTrue, reason: 'converted once');
      expect(job.plan!.windowCount, greaterThan(1));
      expect(toolkit.windowsCut, job.plan!.windowCount);
      expect(server.requests, hasLength(job.plan!.windowCount));
      expect(job.chunks, hasLength(job.plan!.windowCount));
      expect(job.outputs, hasLength(2));
    });

    test('writes a Markdown and a text transcript', () async {
      final run = runner(
        _FakeToolkit(),
        FakeTranscriptionServer([FakeReply.text('hello there')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      final markdown = File(
        job.outputs.firstWhere((path) => path.endsWith('.md')),
      );
      expect(markdown.existsSync(), isTrue);
      final content = markdown.readAsStringSync();
      expect(content, startsWith('# Transcript'));
      expect(content, contains('- Audio: `lecture.mp3`'));
      expect(content, contains('- Model: `$_cappedModel`'));
      expect(content, contains('## Segment 1'));
      expect(
        File(
          job.outputs.firstWhere((path) => path.endsWith('.txt')),
        ).existsSync(),
        isTrue,
      );
    });

    test('deletes the window audio but keeps the raw replies', () async {
      // The replies are what let the speaker matching be re-run later without
      // uploading anything again.
      final run = runner(
        _FakeToolkit(),
        FakeTranscriptionServer([FakeReply.text('hello')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      expect((await JobStore.chunkFile(job.id, 0)).existsSync(), isFalse);
      expect(
        (await JobStore.chunkResponseFile(job.id, 0)).existsSync(),
        isTrue,
      );
    });

    test('keeps the window audio when the user asked it to', () async {
      final run = runner(
        _FakeToolkit(),
        FakeTranscriptionServer([FakeReply.text('hello')]),
      );
      final job = await runToCompletion(
        run,
        (await createJob(run, options: const JobOptions(keepChunks: true))).id,
      );
      expect((await JobStore.chunkFile(job.id, 0)).existsSync(), isTrue);
    });
  });

  group('clearing up the split audio', () {
    test('sweeps a window a finished job could not delete', () async {
      // A file another process was holding when the job finished used to sit
      // in the job folder for good — as large as a tenth of the recording.
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      final stray = await JobStore.chunkFile(job.id, 7);
      stray.writeAsBytesSync(Uint8List(2048));
      expect(stray.existsSync(), isTrue);

      await run.restore();
      expect(stray.existsSync(), isFalse);
    });

    test('leaves the windows of a job that asked to keep them', () async {
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await runToCompletion(
        run,
        (await createJob(run, options: const JobOptions(keepChunks: true))).id,
      );

      await run.restore();
      expect((await JobStore.chunkFile(job.id, 0)).existsSync(), isTrue);
    });

    test('retries a window something is holding open', () async {
      // Only Windows refuses the delete outright; elsewhere this passes on the
      // first attempt, which is fine — the point is that the retry does not
      // make matters worse.
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      final held = await JobStore.chunkFile(job.id, 3);
      held.writeAsBytesSync(Uint8List(2048));
      final handle = held.openSync();
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 60),
          handle.closeSync,
        ),
      );

      expect(await JobStore.deleteChunkAudio(job.id), 0);
      expect(held.existsSync(), isFalse);
    });
  });

  group('the converted listening copy', () {
    test('is what the viewer plays when it is there', () async {
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      final audio = await JobStore.playbackAudio(job.id, job.sourcePath);
      expect(audio!.path, (await JobStore.normalizedAudio(job.id)).path);
    });

    test('falls back to the recording for a job sent whole', () async {
      // These never had a converted copy, and the viewer used to say there was
      // nothing to play with the recording sitting right there.
      final run = runner(
        _FakeToolkit(duration: 90),
        FakeTranscriptionServer([FakeReply.text('a short clip')]),
      );
      final job = await runToCompletion(
        run,
        (await createJob(run, model: _wholeFileModel)).id,
      );

      expect((await JobStore.normalizedAudio(job.id)).existsSync(), isFalse);
      final audio = await JobStore.playbackAudio(job.id, job.sourcePath);
      expect(audio!.path, job.sourcePath);
    });

    test('says there is nothing when neither is on the device', () async {
      expect(await JobStore.playbackAudio('nobody', '/gone.mp3'), isNull);
    });

    test('can be given back without losing the transcript', () async {
      // Thirty-nine megabytes for an eighty-minute lecture, with no way to see
      // it and no way to remove it short of deleting the transcription.
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      final before = await JobStore.storageInfo(job.id);
      expect(before.hasConvertedAudio, isTrue);
      expect(before.bytes, greaterThan(0));

      expect(await run.discardAudio(job.id), isTrue);

      final after = await JobStore.storageInfo(job.id);
      expect(after.hasConvertedAudio, isFalse);
      expect(after.bytes, lessThan(before.bytes));
      expect(await TranscriptStore.load(job.id), isNotNull);
      expect(
        (await JobStore.chunkResponseFile(job.id, 0)).existsSync(),
        isTrue,
        reason: 'the raw replies are what let the matching be re-run',
      );
      expect(await JobStore.load(job.id), isNotNull);
    });

    test('is refused while the job is still queued', () async {
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await createJob(run);
      run.enqueue(job.id);

      expect(await run.discardAudio(job.id), isFalse);
      run.cancel(job.id);
    });
  });

  group('speakers across windows', () {
    test('the same voice keeps one name from end to end', () async {
      // Each window labels its speakers with no idea what the last one called
      // them, and here the source swaps the labels round between windows. Two
      // people must still come out as two people.
      // Two windows: 0 to 1425, and 1405 to 2000. The twenty seconds they share
      // carry both voices, which is the only evidence there is.
      final toolkit = _FakeToolkit(duration: 2000);
      final server = FakeTranscriptionServer([
        FakeReply.diarized([
          (0, 600, 'A', 'the interviewer opens the conversation'),
          (1405, 1415, 'A', 'first voice in the shared seconds'),
          (1415, 1425, 'B', 'second voice in the shared seconds'),
        ]),
        // Window-local times, and the source has swapped its labels round.
        FakeReply.diarized([
          (0, 10, 'X', 'first voice in the shared seconds'),
          (10, 20, 'Y', 'second voice in the shared seconds'),
          (100, 500, 'X', 'more from the first voice'),
        ]),
      ]);
      final run = runner(toolkit, server);
      final job = await runToCompletion(
        run,
        (await createJob(
          run,
          options: const JobOptions(diarize: true, overlapSeconds: 20),
        )).id,
      );

      expect(job.stage, JobStage.done);
      final transcript = await TranscriptStore.load(job.id);
      expect(transcript, isNotNull);
      expect(
        transcript!.speakers,
        hasLength(2),
        reason: 'two people talked, however the windows labelled them',
      );
    });

    test('names them the same way in the files beside the recording', () async {
      // The window-local labels are meaningless outside their own window: every
      // window calls somebody "A" or "X", and printing those made five
      // different people look like one. The files carry the unified names.
      final toolkit = _FakeToolkit(duration: 2000);
      final server = FakeTranscriptionServer([
        FakeReply.diarized([
          (0, 600, 'A', 'the interviewer opens the conversation'),
          (1405, 1415, 'A', 'first voice in the shared seconds'),
          (1415, 1425, 'B', 'second voice in the shared seconds'),
        ]),
        FakeReply.diarized([
          (0, 10, 'X', 'first voice in the shared seconds'),
          (10, 20, 'Y', 'second voice in the shared seconds'),
          (100, 500, 'X', 'more from the first voice'),
        ]),
      ]);
      final run = runner(toolkit, server);
      final job = await runToCompletion(
        run,
        (await createJob(
          run,
          options: const JobOptions(diarize: true, overlapSeconds: 20),
        )).id,
      );

      final markdown = File(
        job.outputs.firstWhere((path) => path.endsWith('.md')),
      ).readAsStringSync();
      final text = File(
        job.outputs.firstWhere((path) => path.endsWith('.txt')),
      ).readAsStringSync();

      expect(markdown, contains('**Speaker 1**'));
      expect(markdown, contains('**Speaker 2**'));
      expect(markdown, isNot(contains('**A**')));
      expect(markdown, isNot(contains('**X**')));
      expect(text, contains('Speaker 1:'));
      expect(text, isNot(contains('A:')));
    });

    test('writes a transcript beside the job for the viewer to read', () async {
      final run = runner(
        _FakeToolkit(duration: 90),
        FakeTranscriptionServer([FakeReply.text('a short clip')]),
      );
      final job = await runToCompletion(
        run,
        (await createJob(run, model: _wholeFileModel)).id,
      );

      final transcript = await TranscriptStore.load(job.id);
      expect(transcript!.segments, isNotEmpty);
      expect(
        transcript.hasTimestamps,
        isFalse,
        reason: 'this model returned none, so the times are estimates',
      );
    });
  });

  group('a recording that fits', () {
    test('goes up whole, with no conversion at all', () async {
      // The fast path, and the reason the app is usable before FFmpeg is set
      // up.
      final toolkit = _FakeToolkit(duration: 90);
      final server = FakeTranscriptionServer([FakeReply.text('short clip')]);
      final run = runner(toolkit, server);

      final job = await runToCompletion(
        run,
        (await createJob(run, model: _wholeFileModel)).id,
      );

      expect(job.stage, JobStage.done);
      expect(job.plan!.uploadsOriginal, isTrue);
      expect(toolkit.normalized, isFalse);
      expect(toolkit.windowsCut, 0);
      expect(server.requests, hasLength(1));
    });
  });

  group('resuming', () {
    test('reuses the windows that already finished', () async {
      // The third window fails. The next run must send only what is left — the
      // finished ones are already paid for.
      final toolkit = _FakeToolkit(duration: 5400);
      final failing = FakeTranscriptionServer([
        FakeReply.text('one'),
        FakeReply.text('two'),
        FakeReply.error(400, 'something went wrong'),
      ]);
      final firstRun = runner(toolkit, failing);
      final created = await createJob(firstRun);
      final failed = await runToCompletion(firstRun, created.id);

      expect(failed.stage, JobStage.failed);
      final done = failed.chunks.length;
      expect(done, 2);

      final second = FakeTranscriptionServer([FakeReply.text('three')]);
      final secondRun = runner(toolkit, second);
      final finished = await runToCompletion(secondRun, created.id);

      expect(finished.stage, JobStage.done);
      expect(
        second.requests,
        hasLength(finished.plan!.windowCount - done),
        reason: 'the finished windows must not be sent again',
      );
    });

    test('discards cached windows when the settings changed', () async {
      // A result produced under other settings is not the result the user is
      // now asking for.
      final toolkit = _FakeToolkit(duration: 5400);
      final first = FakeTranscriptionServer([
        FakeReply.text('one'),
        FakeReply.error(500, 'later'),
      ]);
      final run = runner(toolkit, first);
      final created = await createJob(run);
      final failed = await runToCompletion(run, created.id);
      expect(failed.chunks, isNotEmpty);

      // A different window length changes the plan's fingerprint.
      await JobStore.save(
        failed.copyWith(
          options: const JobOptions(windowSeconds: 600),
          stage: JobStage.queued,
        ),
      );

      final second = FakeTranscriptionServer([FakeReply.text('fresh')]);
      final secondRun = runner(toolkit, second);
      final finished = await runToCompletion(secondRun, created.id);

      expect(finished.stage, JobStage.done);
      expect(
        second.requests,
        hasLength(finished.plan!.windowCount),
        reason: 'every window is sent again under the new settings',
      );
    });

    test('re-queues a job the app was closed during', () async {
      final toolkit = _FakeToolkit(duration: 600);
      final created = await createJob(
        runner(toolkit, FakeTranscriptionServer([])),
        model: _wholeFileModel,
      );
      // What a record left behind by a crash looks like.
      await JobStore.save(created.copyWith(stage: JobStage.uploading));

      final run = runner(
        toolkit,
        FakeTranscriptionServer([FakeReply.text('recovered')]),
      );
      await run.restore();

      for (var i = 0; i < 600; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final job = await JobStore.load(created.id);
        if (job != null && job.stage.isFinished) {
          expect(job.stage, JobStage.done);
          return;
        }
      }
      fail('the interrupted job did not resume');
    });
  });

  group('cancelling', () {
    test('stops the job and keeps the windows that finished', () async {
      final toolkit = _FakeToolkit(duration: 7200);
      final server = FakeTranscriptionServer([FakeReply.text('a window')]);
      final run = runner(toolkit, server);
      final created = await createJob(run);

      run.enqueue(created.id);
      // Let it get past the first window, then stop it.
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final job = await JobStore.load(created.id);
        if ((job?.chunks.length ?? 0) >= 1) break;
      }
      run.cancel(created.id);

      for (var i = 0; i < 600; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final job = await JobStore.load(created.id);
        if (job != null && job.stage.isFinished) {
          expect(job.stage, JobStage.cancelled);
          expect(
            job.chunks,
            isNotEmpty,
            reason: 'a cancelled job keeps what it already paid for',
          );
          return;
        }
      }
      fail('the job did not stop');
    });
  });

  group('failures', () {
    test('says when there is no key for the source', () async {
      final run = JobRunner(
        toolkit: () async => _FakeToolkit(),
        repository: repository,
        clientFactory: () => TranscriptionClient(
          clientFactory: () => FakeTranscriptionServer([]),
          sleep: (_) async {},
        ),
        keyLookup: (_) async => null,
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      expect(job.stage, JobStage.failed);
      expect(job.error!.kind, JobFailureKind.noApiKey);
    });

    test('says when the recording is gone', () async {
      final run = runner(_FakeToolkit(), FakeTranscriptionServer([]));
      final created = await createJob(run, path: p.join(root.path, 'gone.mp3'));
      final job = await runToCompletion(run, created.id);

      expect(job.error!.kind, JobFailureKind.sourceMissing);
    });

    test('says when splitting is needed and there is no FFmpeg', () async {
      // Too large to send whole, and nothing available to divide it with.
      final big = File(p.join(root.path, 'big.mp3'))
        ..writeAsBytesSync(Uint8List(26 * 1024 * 1024));
      final run = runner(
        _FakeToolkit(available: false),
        FakeTranscriptionServer([]),
      );
      final job = await runToCompletion(
        run,
        (await createJob(run, model: _wholeFileModel, path: big.path)).id,
      );

      expect(job.error!.kind, JobFailureKind.mediaToolkitMissing);
      expect(job.error!.message, contains('Settings'));
    });

    test("carries the source's own words through", () async {
      final run = runner(
        _FakeToolkit(),
        FakeTranscriptionServer([
          FakeReply.error(400, 'Unsupported audio format: opus'),
        ]),
      );
      final job = await runToCompletion(run, (await createJob(run)).id);

      expect(job.error!.kind, JobFailureKind.requestRejected);
      expect(job.error!.message, 'Unsupported audio format: opus');
    });

    test(
      'records which feature was refused, so it can be offered again',
      () async {
        final run = runner(
          _FakeToolkit(),
          FakeTranscriptionServer([
            FakeReply.error(400, 'diarization is not supported here'),
          ]),
        );
        final job = await runToCompletion(
          run,
          (await createJob(run, options: const JobOptions(diarize: true))).id,
        );

        expect(job.error!.rejectedFeature, 'diarization');
      },
    );

    test('a failed conversion is reported as one', () async {
      final toolkit = _FakeToolkit()
        ..failNormalize = const MediaException(
          MediaFailureKind.toolError,
          'ffmpeg failed with exit code 1.',
        );
      final run = runner(toolkit, FakeTranscriptionServer([]));
      final job = await runToCompletion(run, (await createJob(run)).id);

      expect(job.error!.kind, JobFailureKind.mediaFailed);
    });
  });

  group('the record on disk', () {
    test(
      'is written after every window, which is what a resume reads',
      () async {
        final run = runner(
          _FakeToolkit(duration: 5400),
          FakeTranscriptionServer([FakeReply.text('window')]),
        );
        final job = await runToCompletion(run, (await createJob(run)).id);

        final reloaded = await JobStore.load(job.id);
        expect(reloaded!.chunks, hasLength(job.plan!.windowCount));
        expect(reloaded.stage, JobStage.done);
        expect(reloaded.finishedAt, isNotNull);
      },
    );

    test(
      'says so when a record has changed, and keeps the finished job',
      () async {
        // The two things a page needs to notice a job that finished. The counter
        // is what makes the providers re-read; the finished job is what lets the
        // page say so before that read comes back. Without either, the pane went
        // on showing "waiting" until the app was restarted.
        final run = runner(
          _FakeToolkit(duration: 5400),
          FakeTranscriptionServer([FakeReply.text('window')]),
        );

        var bumps = 0;
        run.revision.addListener(() => bumps++);

        final job = await runToCompletion(run, (await createJob(run)).id);

        expect(
          bumps,
          greaterThanOrEqualTo(2),
          reason: 'created, then finished',
        );
        expect(run.state.value.active, isNull);
        expect(run.state.value.finished?.id, job.id);
        expect(run.state.value.finished?.stage, JobStage.done);
      },
    );

    test('keeps a name the user gave it', () async {
      final run = runner(
        _FakeToolkit(duration: 90),
        FakeTranscriptionServer([FakeReply.text('one')]),
      );
      final job = await createJob(run, model: _wholeFileModel);

      expect(job.displayName, 'lecture.mp3');

      await run.rename(job.id, '讲座一');
      final named = await JobStore.load(job.id);
      expect(named!.title, '讲座一');
      expect(named.displayName, '讲座一');

      // Blank puts the recording's own name back, which is how a wrong name is
      // undone.
      await run.rename(job.id, '   ');
      final cleared = await JobStore.load(job.id);
      expect(cleared!.title, isNull);
      expect(cleared.displayName, 'lecture.mp3');
    });

    test('a name survives a run that is already going', () async {
      // The runner carries its own copy through the stages and writes it after
      // every window, so a rename written straight to disk would be gone within
      // seconds.
      final run = runner(
        _FakeToolkit(duration: 5400),
        FakeTranscriptionServer([FakeReply.text('window')]),
      );
      final job = await createJob(run);
      run.enqueue(job.id);

      // As soon as the first window has landed, so the runner certainly writes
      // again afterwards.
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final current = await JobStore.load(job.id);
        if ((current?.chunks.length ?? 0) >= 1) break;
      }
      await run.rename(job.id, '讲座一');

      for (var i = 0; i < 600; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final current = await JobStore.load(job.id);
        if (current != null && current.stage.isFinished) {
          expect(current.stage, JobStage.done);
          expect(current.title, '讲座一');
          return;
        }
      }
      fail('the job did not finish');
    });

    test('a name survives a round trip through JSON', () async {
      final run = runner(
        _FakeToolkit(duration: 90),
        FakeTranscriptionServer([FakeReply.text('one')]),
      );
      final job = await createJob(run, model: _wholeFileModel);
      await run.rename(job.id, 'Week 2');

      final loaded = await JobStore.load(job.id);
      expect(loaded!.toJson()['title'], 'Week 2');
      expect(TranscriptionJob.fromJson(loaded.toJson()).displayName, 'Week 2');
    });

    test('lists every job, newest first', () async {
      final run = runner(
        _FakeToolkit(duration: 90),
        FakeTranscriptionServer([FakeReply.text('one')]),
      );
      final first = await createJob(run, model: _wholeFileModel);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await createJob(run, model: _wholeFileModel);

      final all = await JobStore.loadAll();
      expect(all.first.id, second.id);
      expect(all.map((j) => j.id), containsAll(<String>[first.id, second.id]));
    });
  });
}
