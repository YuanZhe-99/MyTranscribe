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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_transcribe/app/theme.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/providers/app_settings.dart';
import 'package:my_transcribe/shared/widgets/shell_scaffold.dart';

/// Purpose: Pump the shell at a pinned viewport.
/// Inputs: `tester`, `size` in logical pixels, optional `location` and
/// `uiStyle`.
/// Returns: None.
/// Side effects: Sets and restores the test view size; pumps a tree.
/// Notes: Internal helper used within this file only.
Future<void> pumpShell(
  WidgetTester tester,
  Size size, {
  String location = '/jobs',
  AppUiStyle uiStyle = AppUiStyle.expressive,
  bool wideBottom = false,
  bool railRight = false,
  bool alwaysSide = false,
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
    ProviderScope(
      overrides: [
        appSettingsProvider.overrideWithValue(
          AppSettingsNotifier.fixed(
            AppSettings(
              uiStyle: uiStyle,
              expressiveWideBottomNav: wideBottom,
              navRailOnRight: railRight,
              alwaysSideNav: alwaysSide,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  bottomBarStyleTests();
  wideNavigationTests();
  testWidgets('a phone in portrait gets a bottom bar', (tester) async {
    await pumpShell(tester, const Size(412, 915)); // Pixel 8, portrait
    expect(find.byKey(_island), findsOneWidget);
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
    // asserts the labels really do arrive in both. The classic bar is used
    // here because the Expressive bar shows only the selected label.
    await pumpShell(
      tester,
      const Size(412, 915),
      uiStyle: AppUiStyle.material3,
    );
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

/// The floating island's key, so a test can tell it from the classic bar.
const _island = ValueKey('floatingNavBarIsland');

/// Purpose: Test the bottom bar style that follows the interface style.
/// Inputs: None.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Expressive floats the bar; Material 3 keeps the classic full-width
/// one; a rail looks the same in both.
void bottomBarStyleTests() {
  group('bottom bar style', () {
    testWidgets('Expressive (the default) floats the bar', (tester) async {
      await pumpShell(tester, const Size(412, 915));
      expect(find.byKey(_island), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // Only the selected destination shows its label; the others are icons
      // with tooltips.
      expect(find.text('转写'), findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);
    });

    testWidgets('Material 3 keeps the classic full-width bar', (tester) async {
      await pumpShell(
        tester,
        const Size(412, 915),
        uiStyle: AppUiStyle.material3,
      );
      expect(find.byKey(_island), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('the rail ignores the style', (tester) async {
      for (final style in AppUiStyle.values) {
        await pumpShell(tester, const Size(1280, 720), uiStyle: style);
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byKey(_island), findsNothing);
      }
    });

    testWidgets('the floating bar still navigates', (tester) async {
      await pumpShell(tester, const Size(412, 915));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('page /settings'), findsOneWidget);
    });
  });
}

/// Purpose: Test the wide-window navigation settings (0.4.1).
/// Inputs: None.
/// Returns: None.
/// Side effects: Pumps widget trees.
/// Notes: Expressive may keep its bottom bar on wide windows; the rail can sit
/// on either side in both styles.
void wideNavigationTests() {
  group('wide-window navigation (0.4.1)', () {
    testWidgets('Expressive can keep its bottom bar on a wide window', (
      tester,
    ) async {
      await pumpShell(tester, const Size(933, 704), wideBottom: true);
      expect(find.byKey(_island), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('Material 3 ignores the wide bottom-bar setting', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const Size(933, 704),
        uiStyle: AppUiStyle.material3,
        wideBottom: true,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('the rail sits on the left by default', (tester) async {
      await pumpShell(tester, const Size(933, 704));
      expect(tester.getTopLeft(find.byType(NavigationRail)).dx, 0);
    });

    for (final style in AppUiStyle.values) {
      testWidgets('a phone can use the rail when asked (${style.name})', (
        tester,
      ) async {
        await pumpShell(
          tester,
          const Size(412, 915),
          uiStyle: style,
          alwaysSide: true,
        );
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byKey(_island), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
      });
    }

    testWidgets('always-side overrides the wide bottom bar', (tester) async {
      await pumpShell(
        tester,
        const Size(933, 704),
        wideBottom: true,
        alwaysSide: true,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    for (final style in AppUiStyle.values) {
      testWidgets('the rail can sit on the right (${style.name})', (
        tester,
      ) async {
        await pumpShell(
          tester,
          const Size(933, 704),
          uiStyle: style,
          railRight: true,
        );
        expect(tester.getRect(find.byType(NavigationRail)).right, 933);
        expect(find.text('page /jobs'), findsOneWidget);
      });
    }
  });
}
