/// Purpose: Prove the app boots — router, theme, localizations and shell all
/// build together without throwing.
/// Inputs: None.
/// Returns: None.
/// Side effects: Pumps a widget tree.
/// Notes: Driven in Simplified Chinese, like every layout-sensitive test in
/// this repo: `flutter_test`'s default font renders each glyph as a full em
/// square, which inflates Latin text to roughly 2.5x its real width and reports
/// overflow at widths that are comfortable in production. CJK glyphs really are
/// square, so a Chinese locale measures the production layout. Do not "fix"
/// this back to English.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/app.dart';

void main() {
  testWidgets('the app boots to the transcribe tab', (tester) async {
    // A phone in portrait: below every split threshold, so this exercises the
    // bottom navigation bar rather than the rail.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MyTranscribeApp(initialLocation: '/jobs')),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
