import 'package:device_preview/device_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../shared/providers/app_settings.dart';
import 'locale_resolution.dart';
import 'router.dart';
import 'theme.dart';

/// Enable mouse wheel and trackpad scrolling on desktop.
class _DesktopScrollBehavior extends MaterialScrollBehavior {
  /// Purpose: Report which pointer kinds may drag a scrollable.
  /// Inputs: None.
  /// Returns: `Set<PointerDeviceKind>`.
  /// Side effects: None.
  /// Notes: The desktop targets are first-class here — a long recording is
  /// usually transcribed at a desk — so the mouse and trackpad must drag a
  /// scrollable, which Material does not enable by default.
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MyTranscribeApp extends ConsumerStatefulWidget {
  /// Which tab to open on, read from the device preferences before `runApp`.
  final String initialLocation;

  /// Purpose: Create the root app widget.
  /// Inputs: `initialLocation`.
  /// Returns: A new `MyTranscribeApp` instance.
  /// Side effects: None.
  /// Notes: None.
  const MyTranscribeApp({super.key, this.initialLocation = '/jobs'});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<MyTranscribeApp> createState() => _MyTranscribeAppState();
}

class _MyTranscribeAppState extends ConsumerState<MyTranscribeApp> {
  /// The router, built once.
  ///
  /// A `GoRouter` owns navigation history, so rebuilding one on a theme or
  /// locale change would send the app back to its initial tab.
  late final GoRouter _router = buildAppRouter(
    initialLocation: widget.initialLocation,
  );

  /// Purpose: Build the `MaterialApp.router` with theme, locale, and routes.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'MyTranscribe!!!!!',
      debugShowCheckedModeBanner: false,

      // Enable desktop scroll
      scrollBehavior: _DesktopScrollBehavior(),

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,

      // Localization
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: resolveAppLocale,

      // DevicePreview
      builder: DevicePreview.appBuilder,

      // Routing
      routerConfig: _router,
    );
  }
}
