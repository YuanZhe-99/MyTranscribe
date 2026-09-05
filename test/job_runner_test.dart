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
