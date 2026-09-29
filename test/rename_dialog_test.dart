/// Purpose: Test that the rename dialog and the dialogs like it can be opened
/// and dismissed without their text controllers being used after disposal.
/// Inputs: None; a runner over a stub repository stands in.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: The controllers used to be disposed the moment `showDialog` returned,
/// while the route's closing animation was still building the text field, which
/// throws "used after being disposed" on a real device. The tests open a
/// dialog, dismiss it, and let the animation run to the end; any such error
/// surfaces as a test exception.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/jobs/services/job_runner.dart';
import 'package:my_transcribe/features/jobs/views/job_detail_page.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';

void main() {
  final job = TranscriptionJob(
    id: 'job-1',
    createdAt: DateTime.utc(2026, 9, 5),
    modifiedAt: DateTime.utc(2026, 9, 5),
    sourcePath: '/recordings/lecture.mp3',
    sourceName: 'lecture.mp3',
    sourceBytes: 1024,
    providerId: 'provider:openai',
    modelId: 'model:openai:gpt-transcribe',
    modelName: 'gpt-transcribe',
    title: 'Week 1',
  );

  Future<void> openDialog(WidgetTester tester) async {
    final runner = JobRunner(
      toolkit: () => throw UnimplementedError(),
      repository: SettingsRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showJobRenameDialog(context, runner, job),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens with the current name and cancels cleanly', (
    tester,
  ) async {
    await openDialog(tester);
    expect(find.text('Week 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Something else');
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.cancel));
    // Through the whole closing animation, frame by frame.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('can be opened and dismissed again', (tester) async {
    await openDialog(tester);
    await tester.tapAt(const Offset(4, 4)); // the barrier
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
