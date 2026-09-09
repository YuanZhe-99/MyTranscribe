/// Purpose: Test that the transcript viewer reads correctly at each geometry,
/// and that the things a wrong transcript would let a user do are not offered.
/// Inputs: None; the transcript and the view settings come from provider
/// overrides.
/// Returns: None.
/// Side effects: Pumps widget trees; the store tests write temporary files.
/// Notes: Driven in Simplified Chinese for the reason given in
/// `test/shell_nav_ui_test.dart`.
///
/// The page takes its data from providers rather than reading files itself,
/// which is what makes this possible: a widget test runs in a fake-async zone
/// where `dart:io` futures never complete, so a page that awaited one could
/// never be pumped. There is no audio file, so no audio device is opened —
/// the player creates one only when something is loaded.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/providers/models/transcribe_defaults.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/transcript/models/transcript.dart';
import 'package:my_transcribe/features/jobs/services/job_providers.dart';
import 'package:my_transcribe/features/transcript/services/transcript_providers.dart';
import 'package:my_transcribe/features/transcript/services/transcript_store.dart';
import 'package:my_transcribe/features/transcript/views/transcript_viewer_page.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:my_transcribe/shared/utils/adaptive_layout.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

/// The viewports the series checks every page at.
const _geometries = <String, Size>{
  'phone portrait': Size(412, 915),
  'phone landscape': Size(915, 412),
  'Fold 8 portrait': Size(704, 933),
  'Fold 8 landscape': Size(933, 704),
  'tablet': Size(1280, 800),
  'desktop window': Size(1000, 720),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const jobId = 'job-1';
  late Directory root;

  final job = TranscriptionJob(
    id: jobId,
    createdAt: DateTime.utc(2026, 9, 5),
    modifiedAt: DateTime.utc(2026, 9, 5),
    sourcePath: '/recordings/讲座.mp3',
    sourceName: '讲座.mp3',
    sourceBytes: 1024,
    providerId: 'provider:openai',
    modelId: 'model:openai:gpt-transcribe',
    modelName: 'gpt-transcribe',
    stage: JobStage.done,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_viewer_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await TranscribeStorage.setStoragePath(null);
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Build the transcript this test will open.
  /// Inputs: The [segments] as (start, end, speakerId, text), the [speakers],
  /// and whether the times are only [approximate].
  /// Returns: A [Transcript].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Transcript buildTranscript(
    List<(double, double, String?, String)> segments, {
    List<Speaker> speakers = const [],
    bool approximate = false,
  }) => Transcript(
    jobId: jobId,
    speakers: speakers,
    segments: [
      for (var i = 0; i < segments.length; i++)
        TranscriptSegment(
          id: 'seg_$i',
          chunkIndex: 0,
          startSeconds: segments[i].$1,
          endSeconds: segments[i].$2,
          speakerId: segments[i].$3,
          text: segments[i].$4,
          approximate: approximate,
        ),
    ],
  );

  /// Purpose: Open the viewer on a transcript at a pinned viewport.
  /// Inputs: `tester`, the viewport `size`, and the transcript's [segments],
  /// [speakers] and whether its times are only [approximate].
  /// Returns: None.
  /// Side effects: Sets and restores the test view size; pumps a tree.
  /// Notes: Internal helper used within this file only.
  Future<void> pumpViewer(
    WidgetTester tester,
    Size size,
    List<(double, double, String?, String)> segments, {
    List<Speaker> speakers = const [],
    bool approximate = false,
    List<String> knownNames = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptProvider(jobId).overrideWithValue(
            AsyncValue.data(
              buildTranscript(
                segments,
                speakers: speakers,
                approximate: approximate,
              ),
            ),
          ),
          jobProvider(jobId).overrideWithValue(AsyncValue.data(job)),
          viewerPreferencesProvider.overrideWithValue(
            const AsyncValue.data(ViewerPreferences()),
          ),
          // Left un-overridden this would read disk and stay loading for ever
          // in the fake-async zone; the page tolerates that, but a test about
          // the suggestions needs them to be there.
          settingsLibraryProvider.overrideWithValue(
            AsyncValue.data(
              SettingsLibrary(
                defaults: TranscribeDefaults(knownSpeakerNames: knownNames),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TranscriptViewerPage(jobId: jobId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('the transcript viewer', () {
    testWidgets('shows what was said', (tester) async {
      await pumpViewer(tester, const Size(412, 915), [
        (0, 5, null, '今天我们讲第一个题目。'),
        (5, 10, null, '接下来看第二个。'),
      ]);

      expect(find.text('今天我们讲第一个题目。'), findsOneWidget);
      expect(find.text('接下来看第二个。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says so when the transcription produced nothing', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(tester, const Size(412, 915), const []);

      expect(find.text(l10n.viewerEmpty), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final entry in _geometries.entries) {
      testWidgets('puts its panels beside the text at ${entry.key} only when '
          'they fit', (tester) async {
        await pumpViewer(tester, entry.value, [(0, 5, null, '一句话。')]);

        final expected = useViewerSidebar(
          entry.value.width,
          entry.value.height,
          entry.value.width,
        );
        expect(
          find.byType(VerticalDivider),
          expected ? findsOneWidget : findsNothing,
          reason: '${entry.key} should ${expected ? '' : 'not '}split',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a narrow window keeps the panels behind buttons', (
      tester,
    ) async {
      // Not hidden: the same controls, reached differently.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(
        tester,
        const Size(412, 915),
        [(0, 5, 'spk_1', '你好。')],
        speakers: const [Speaker(id: 'spk_1', name: '老师')],
      );

      expect(find.byTooltip(l10n.viewerOptions), findsOneWidget);
      expect(find.byTooltip(l10n.viewerSpeakers), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('names the speaker on the paragraph they said', (tester) async {
      await pumpViewer(
        tester,
        const Size(412, 915),
        [(0, 5, 'spk_1', '第一句。'), (5, 10, 'spk_2', '第二句。')],
        speakers: const [
          Speaker(id: 'spk_1', name: '老师'),
          Speaker(id: 'spk_2', name: '学生', colorIndex: 1),
        ],
      );

      expect(find.text('老师'), findsWidgets);
      expect(find.text('学生'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('warns when the times are only estimates', (tester) async {
      // The model returned none, so nobody should quote these as exact.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(tester, const Size(412, 915), [
        (0, 600, null, '一整段。'),
      ], approximate: true);

      expect(find.text(l10n.viewerApproximate), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says there is nothing to play when the audio is gone', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(tester, const Size(412, 915), [(0, 5, null, '一句话。')]);

      expect(find.text(l10n.viewerAudioMissing), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('finds a phrase and marks how many times it occurs', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(tester, const Size(412, 915), [
        (0, 5, null, '重叠的部分要去掉。'),
        (5, 10, null, '这里也有重叠。'),
      ]);

      await tester.tap(find.byTooltip(l10n.viewerSearchHint));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '重叠');
      await tester.pump();

      expect(find.text(l10n.viewerSearchCount(1, 2)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers no subtitles when the times are estimates', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(tester, const Size(412, 915), [
        (0, 600, null, '一整段。'),
      ], approximate: true);

      await tester.tap(find.byTooltip(l10n.viewerExport));
      await tester.pumpAndSettle();

      expect(find.text('SRT'), findsOneWidget);
      expect(
        find.text(l10n.viewerExportNeedsTimes),
        findsNWidgets(2),
        reason: 'both subtitle formats say why they are unavailable',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('counts the lines nobody is credited with', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(
        tester,
        const Size(412, 915),
        [
          (0, 5, 'spk_1', '大家好。'),
          (5, 10, null, '听不清是谁。'),
          (10, 15, null, '也听不清。'),
        ],
        speakers: const [Speaker(id: 'spk_1', colorIndex: 0)],
      );

      await tester.tap(find.byTooltip(l10n.viewerSpeakers));
      await tester.pumpAndSettle();

      expect(find.text(l10n.viewerSpeakerUnknown), findsWidgets);
      expect(find.text(l10n.viewerSpeakerLines(2)), findsOneWidget);
    });

    testWidgets('marking a speaker unknown takes them off the list', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(
        tester,
        const Size(412, 915),
        [
          (0, 5, 'spk_1', '大家好。'),
          (5, 10, 'spk_2', '老师好。'),
        ],
        speakers: const [
          Speaker(id: 'spk_1', name: '张老师', colorIndex: 0),
          Speaker(id: 'spk_2', colorIndex: 1),
        ],
      );

      await tester.tap(find.byTooltip(l10n.viewerSpeakers));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.viewerSpeakerUnassign).last);
      await tester.pumpAndSettle();

      // The write never completes in this zone, but the screen is updated
      // before it is started, which is the behaviour being checked.
      expect(find.text('张老师'), findsWidgets);
      expect(find.text(l10n.viewerSpeakerUnknown), findsWidgets);
      expect(find.text(l10n.viewerSpeakerLines(1)), findsWidgets);
    });

    testWidgets('offers a name used before, and applies it in one tap', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(
        tester,
        const Size(412, 915),
        [(0, 5, 'spk_1', '大家好。')],
        speakers: const [Speaker(id: 'spk_1', colorIndex: 0)],
        knownNames: const ['张老师', '李同学'],
      );

      await tester.tap(find.byTooltip(l10n.viewerSpeakers));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.viewerSpeakerRename).last);
      await tester.pumpAndSettle();

      expect(find.text(l10n.viewerSpeakerSuggestions), findsOneWidget);
      expect(find.text('李同学'), findsOneWidget);

      await tester.tap(find.text('张老师'));
      await tester.pumpAndSettle();

      expect(find.text('张老师'), findsWidgets);
    });

    testWidgets('two renames in one sheet session both stick', (tester) async {
      // The sheet is built once, outside the page's build. Before the panel was
      // rebuilt from the current transcript, the second rename was made against
      // the copy captured when the sheet opened and undid the first.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpViewer(
        tester,
        const Size(412, 915),
        [
          (0, 5, 'spk_1', '大家好。'),
          (5, 10, 'spk_2', '老师好。'),
        ],
        speakers: const [
          Speaker(id: 'spk_1', colorIndex: 0),
          Speaker(id: 'spk_2', colorIndex: 1),
        ],
      );

      await tester.tap(find.byTooltip(l10n.viewerSpeakers));
      await tester.pumpAndSettle();

      for (final (index, name) in [(0, '老师'), (1, '学生')]) {
        await tester.tap(find.byIcon(Icons.more_vert).at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.viewerSpeakerRename).last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, name);
        await tester.tap(find.text(l10n.save).last);
        await tester.pumpAndSettle();
      }

      expect(find.text('老师'), findsWidgets);
      expect(find.text('学生'), findsWidgets);
    });
  });

  group('the transcript on disk', () {
    test('a rename is on disk and is re-read on the next open', () async {
      // The regression behind "I renamed Speaker 1, went back, came in again
      // and it was Speaker 1 once more": the provider was never refreshed, so
      // the second open was served the first read for the rest of the session.
      final container = ProviderContainer(
        overrides: [
          jobProvider(jobId).overrideWithValue(AsyncValue.data(job)),
          viewerPreferencesProvider.overrideWithValue(
            const AsyncValue.data(ViewerPreferences()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await TranscriptStore.save(
        Transcript(
          jobId: jobId,
          speakers: const [Speaker(id: 'spk_1', colorIndex: 0)],
          segments: const [
            TranscriptSegment(
              id: 'seg_0',
              chunkIndex: 0,
              startSeconds: 0,
              endSeconds: 5,
              speakerId: 'spk_1',
              text: '大家好。',
            ),
          ],
        ),
      );

      final first = await container.read(transcriptProvider(jobId).future);
      expect(first!.speakers.single.name, isNull);

      await TranscriptStore.save(
        first.copyWith(
          speakers: [first.speakers.single.copyWith(name: '张老师')],
        ),
      );
      container.read(transcriptRevisionProvider.notifier).state++;

      final again = await container.read(transcriptProvider(jobId).future);
      expect(again!.speakers.single.name, '张老师');
    });

    test('round-trips through JSON, keeping fields it does not know', () async {
      // A file written by a newer build must survive being read and rewritten
      // by this one.
      final file = await TranscriptStore.fileFor(jobId);
      await file.writeAsString(
        jsonEncode({
          'jobId': jobId,
          'segments': [
            {
              'id': 'seg_0',
              'chunkIndex': 0,
              'start': 0,
              'end': 5,
              'text': 'hello',
              'confidence': 0.91,
            },
          ],
          'somethingNewer': {'a': 1},
        }),
      );

      final read = await TranscriptStore.load(jobId);
      await TranscriptStore.save(read!);
      final again =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;

      expect(again['somethingNewer'], {'a': 1});
      expect(
        (again['segments'] as List).first,
        containsPair('confidence', 0.91),
      );
    });

    test('an unreadable transcript reads as absent, not as an error', () async {
      final file = await TranscriptStore.fileFor(jobId);
      await file.writeAsString('{ not json');
      expect(await TranscriptStore.load(jobId), isNull);
    });
  });
}
