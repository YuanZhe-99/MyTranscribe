/// Purpose: Test that the transcribe tab splits into two panes only where the
/// window can carry them, and that a job's row says what it is doing.
/// Inputs: None; the job list is supplied through a provider override.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Driven in Simplified Chinese for the reason given in
/// `test/shell_nav_ui_test.dart`: the test font makes Latin labels about 2.5x
/// too wide, so an English run reports overflow at widths that are comfortable
/// in production. Do not "fix" this back to English.
///
/// The records come from an override rather than from disk because a widget
/// test runs in a fake-async zone where real file reads never complete —
/// `test/job_runner_test.dart` is where the store meets real files. The
/// geometries are the ones named in `doc/en-us/adaptive-layout.md`, and each
/// expectation is taken from `useJobsTwoPane` rather than from a number written
/// here: a page must never carry a breakpoint of its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/chunk_plan.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/jobs/services/job_providers.dart';
import 'package:my_transcribe/features/jobs/services/job_runner.dart';
import 'package:my_transcribe/features/jobs/views/job_detail_page.dart';
import 'package:my_transcribe/features/jobs/views/jobs_page.dart';
import 'package:my_transcribe/features/media/services/media_toolkit.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/utils/adaptive_layout.dart';

/// The viewports the series checks every page at.
const _geometries = <String, Size>{
  'phone portrait': Size(412, 915),
  'phone landscape': Size(915, 412),
  'Fold 8 portrait': Size(704, 933),
  'Fold 8 landscape': Size(933, 704),
  'tablet': Size(1280, 800),
  'desktop window': Size(1000, 720),
};

/// Purpose: Build one job record for the list to show.
/// Inputs: The [id], the [name] in the row, the [stage], how many windows are
/// [done] out of the [total], and an optional [error].
/// Returns: A [TranscriptionJob].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
TranscriptionJob buildJob(
  String id,
  String name,
  JobStage stage, {
  int done = 0,
  int total = 0,
  JobError? error,
  String? title,
}) {
  final now = DateTime.now().toUtc();
  return TranscriptionJob(
    id: id,
    createdAt: now,
    modifiedAt: now,
    sourcePath: '/recordings/$name',
    sourceName: name,
    title: title,
    sourceBytes: 1024,
    providerId: 'provider:openai',
    modelId: 'model:openai:gpt-transcribe',
    modelName: 'gpt-transcribe',
    stage: stage,
    error: error,
    // A running job is working on the window after the last finished one.
    currentChunk: stage.isRunning ? done : null,
    chunks: [
      for (var i = 0; i < done; i++)
        ChunkResult(
          index: i,
          startSeconds: i * 600,
          lengthSeconds: 600,
          chunkBytes: 1024,
          text: 'window $i',
        ),
    ],
    plan: total == 0
        ? null
        : ChunkPlan(
            single: total == 1,
            uploadsOriginal: false,
            strideSeconds: 600,
            overlapSeconds: 5,
            predictedChunkBytes: 1024,
            fingerprint: 'test',
            windows: [
              for (var i = 0; i < total; i++)
                ChunkWindow(
                  index: i,
                  startSeconds: i * 600,
                  endSeconds: i * 600 + 605,
                ),
            ],
          ),
  );
}

void main() {
  /// Purpose: Pump the transcribe tab at a pinned viewport.
  /// Inputs: `tester`, the viewport `size`, and the [jobs] to show.
  /// Returns: None.
  /// Side effects: Sets and restores the test view size; pumps a tree.
  /// Notes: Internal helper used within this file only. Pumped a fixed number
  /// of times rather than settled: a running job shows a progress indicator,
  /// which animates forever and would make `pumpAndSettle` wait for its
  /// timeout.
  Future<void> pumpJobs(
    WidgetTester tester,
    Size size,
    List<TranscriptionJob> jobs,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobsListProvider.overrideWithValue(AsyncValue.data(jobs)),
          jobRunnerProvider.overrideWithValue(
            JobRunner(
              toolkit: () async => const UnavailableMediaToolkit('test'),
              repository: SettingsRepository(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const JobsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the transcribe tab', () {
    testWidgets('says so when there is nothing to show', (tester) async {
      await pumpJobs(tester, const Size(412, 915), const []);
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      expect(find.text(l10n.jobsEmptyTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists the recordings it has transcribed', (tester) async {
      await pumpJobs(tester, const Size(412, 915), [
        buildJob('a', '第一次讲座.mp3', JobStage.done),
        buildJob('b', '第二次讲座.mp3', JobStage.done),
      ]);

      expect(find.text('第一次讲座.mp3'), findsOneWidget);
      expect(find.text('第二次讲座.mp3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the name the user gave a transcription', (tester) async {
      await pumpJobs(tester, const Size(412, 915), [
        buildJob('a', '录音 20260903.mp3', JobStage.done, title: '第二周 讲座'),
        buildJob('b', '第二次讲座.mp3', JobStage.done),
      ]);

      expect(find.text('第二周 讲座'), findsOneWidget);
      expect(find.text('录音 20260903.mp3'), findsNothing);
      // A job nobody has named still shows the recording's file name.
      expect(find.text('第二次讲座.mp3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final entry in _geometries.entries) {
      testWidgets('splits into panes at ${entry.key} only when it fits', (
        tester,
      ) async {
        await pumpJobs(tester, entry.value, [
          buildJob('a', '讲座.mp3', JobStage.done),
        ]);

        final expected = useJobsTwoPane(entry.value.width, entry.value.height);
        expect(
          find.byType(VerticalDivider),
          expected ? findsOneWidget : findsNothing,
          reason: '${entry.key} should ${expected ? '' : 'not '}split',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a wide window prompts for a selection', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpJobs(tester, const Size(1280, 800), [
        buildJob('a', '讲座.mp3', JobStage.done),
      ]);

      expect(find.text(l10n.jobsSelectPrompt), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a running job shows how far it has got', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpJobs(tester, const Size(412, 915), [
        buildJob('a', '长录音.mp3', JobStage.uploading, done: 1, total: 3),
      ]);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(l10n.jobStageUploading(2, 3)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a finished job shows no progress bar', (tester) async {
      await pumpJobs(tester, const Size(412, 915), [
        buildJob('a', '讲座.mp3', JobStage.done, done: 3, total: 3),
      ]);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed job shows the reason in the row', (tester) async {
      // The reason belongs in the list, not behind a tap: a user scanning a
      // column of failures needs to see which ones share a cause.
      await pumpJobs(tester, const Size(412, 915), [
        buildJob(
          'b',
          '坏.mp3',
          JobStage.failed,
          error: const JobError(
            kind: JobFailureKind.noApiKey,
            message: '尚未设置密钥。',
          ),
        ),
      ]);

      expect(find.text('尚未设置密钥。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  /// Purpose: Pump the detail pane over one stored record and one runner.
  /// Inputs: `tester`, the [stored] record and the [run]ner to watch.
  /// Returns: None.
  /// Side effects: Sets and restores the test view size; pumps a tree.
  /// Notes: Internal helper used within this file only. Embedded, so the pane
  /// is the whole tree and no route has to be pushed. The record is supplied
  /// through the provider for the reason the list is: a widget test never
  /// completes a real file read.
  Future<void> pumpDetail(
    WidgetTester tester,
    TranscriptionJob stored,
    JobRunner run,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobProvider(stored.id).overrideWithValue(AsyncValue.data(stored)),
          jobRunnerProvider.overrideWithValue(run),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: JobDetailPage(jobId: stored.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the detail pane', () {
    /// Purpose: Build a runner over nothing, to drive its state by hand.
    /// Inputs: None.
    /// Returns: A [JobRunner].
    /// Side effects: None.
    /// Notes: Internal helper used within this file only. Nothing is ever
    /// enqueued on it, so the toolkit and the repository are never reached.
    JobRunner idleRunner() => JobRunner(
      toolkit: () async => const UnavailableMediaToolkit('test'),
      repository: SettingsRepository(),
    );

    testWidgets('says a job has finished the moment the runner drops it', (
      tester,
    ) async {
      // The defect this fixes: the runner publishes an empty queue when it
      // finishes, the page falls back to the record it read when the job was
      // queued, and the pane went on saying "waiting" with a Start button until
      // the app was restarted. Pressing that button rebuilt the transcript.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final run = idleRunner();
      final queued = buildJob('a', '讲座.mp3', JobStage.queued, total: 3);

      await pumpDetail(tester, queued, run);
      expect(find.text(l10n.jobStageQueued), findsOneWidget);

      run.state.value = JobQueueState(
        finished: buildJob('a', '讲座.mp3', JobStage.done, done: 3, total: 3),
      );
      await tester.pump();

      expect(find.text(l10n.jobStageDone), findsOneWidget);
      expect(find.text(l10n.jobOpenTranscript), findsOneWidget);
      expect(find.text(l10n.jobStart), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers to run a finished job again, never to start it', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));

      await pumpDetail(
        tester,
        buildJob('a', '讲座.mp3', JobStage.done, done: 3, total: 3),
        idleRunner(),
      );

      expect(find.text(l10n.jobRunAgain), findsOneWidget);
      expect(find.text(l10n.jobStart), findsNothing);
      expect(find.text(l10n.jobResume), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says what running again costs, and takes no for an answer', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final run = idleRunner();

      await pumpDetail(
        tester,
        buildJob('a', '讲座.mp3', JobStage.done, done: 3, total: 3),
        run,
      );
      await tester.tap(find.text(l10n.jobRunAgain));
      await tester.pump();

      expect(find.text(l10n.jobRunAgainConfirm), findsOneWidget);

      await tester.tap(find.text(l10n.cancel));
      await tester.pump();

      expect(run.state.value.queued, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps showing a job while its record is being re-read', (
      tester,
    ) async {
      // Riverpod 1.x reports a re-reading FutureProvider as loading with no
      // previous value, so a page that trusted it would blink to a spinner
      // every time any job record changed.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final stored = buildJob('a', '讲座.mp3', JobStage.done, done: 3, total: 3);
      final run = idleRunner();

      final container = ProviderContainer(
        overrides: [
          jobProvider('a').overrideWithValue(AsyncValue.data(stored)),
          jobRunnerProvider.overrideWithValue(run),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(
              body: JobDetailPage(jobId: 'a', embedded: true),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(l10n.jobStageDone), findsOneWidget);

      container.updateOverrides([
        jobProvider('a').overrideWithValue(const AsyncValue.loading()),
        jobRunnerProvider.overrideWithValue(run),
      ]);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(l10n.jobStageDone), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
