/// Purpose: Test that the shell shows a rail or a bottom bar at the right
/// geometries, and that its two renderings stay in step.
/// Inputs: None.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Driven in Simplified Chinese. `flutter_test`'s default font renders
/// every glyph as a full em square, which inflates Latin labels to roughly 2.5x
/// their real width and reports overflow at widths that are comfortable in
/// production; CJK glyphs really are square, so a Chinese locale measures the
/// production layout. Do not "fix" this back to English.
///
/// The shell is built over stub pages rather than the real ones, so a failure
/// here is a failure of the shell and not of whatever a tab happens to show.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/widgets/shell_scaffold.dart';

/// Purpose: Pump the shell at a pinned viewport.
/// Inputs: `tester`, `size` in logical pixels, optional `location`.
/// Returns: None.
/// Side effects: Sets and restores the test view size; pumps a tree.
/// Notes: Internal helper used within this file only.
Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  String location = '/jobs',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          for (final route in ShellScaffold.routes)
            GoRoute(
              path: route,
              builder: (context, state) =>
                  Scaffold(body: Center(child: Text('page $route'))),
            ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    MaterialApp.router(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a phone in portrait gets a bottom bar', (tester) async {
    await pumpShell(tester, const Size(412, 915)); // Pixel 8, portrait
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone in landscape gets a rail even though it cannot split', (
    tester,
  ) async {
    // The case Rule B exists for: 915 x 412 spends 19% of its height on a
    // bottom bar while 915 logical pixels of width sit unused.
    await pumpShell(tester, const Size(915, 412));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Galaxy Z Fold 8 gets a rail in both orientations', (
    tester,
  ) async {
    await pumpShell(tester, const Size(704, 933)); // portrait
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpShell(tester, const Size(933, 704)); // landscape
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the default desktop window gets a rail', (tester) async {
    await pumpShell(tester, const Size(1280, 720));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both renderings carry the same destinations', (tester) async {
    // One list feeds the bar and the rail, so they cannot drift apart. This
    // asserts the labels really do arrive in both.
    await pumpShell(tester, const Size(412, 915));
    final barLabels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();

    await pumpShell(tester, const Size(1280, 720));
    final railLabels = tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .destinations
        .map((d) => (d.label as Text).data)
        .toList();

    expect(barLabels, hasLength(ShellScaffold.routes.length));
    expect(railLabels, barLabels);
  });

  testWidgets('tapping a destination navigates to that tab', (tester) async {
    await pumpShell(tester, const Size(412, 915));
    expect(find.text('page /jobs'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('page /settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail is centred, not pinned to the top', (tester) async {
    // A rail with no leading button or FAB would otherwise leave its whole
    // lower half empty on a tall window.
    await pumpShell(tester, const Size(1280, 720));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.groupAlignment, 0);
    expect(rail.labelType, NavigationRailLabelType.all);
  });
}
