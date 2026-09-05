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
}) {
  final now = DateTime.now().toUtc();
  return TranscriptionJob(
    id: id,
    createdAt: now,
    modifiedAt: now,
    sourcePath: '/recordings/$name',
    sourceName: name,
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
}
