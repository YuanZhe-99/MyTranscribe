import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/jobs/services/job_providers.dart';
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

  /// Purpose: Pick up jobs the app was closed in the middle of.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Re-queues interrupted jobs, which starts uploading again.
  /// Notes: Flutter lifecycle override. Here rather than in `main()` because
  /// the runner lives in the provider scope, and a job that was interrupted
  /// should carry on the moment the app is back rather than waiting for the
  /// user to find it and press a button.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A corrupt job folder must not surface as an unhandled async error at
      // startup. The jobs are simply not resumed until the next start.
      unawaited(
        ref.read(jobRunnerProvider).restore().catchError((Object _) {}),
      );
    });
  }

  /// Purpose: Build the `MaterialApp.router` with theme, locale, and routes.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    // The platform's wallpaper colors reach the theme on Android only: the
    // desktop plugins report the system accent, which would replace the
    // app's own seed color.
    final allowDynamic =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp.router(
        title: 'MyTranscribe!!!!!',
        debugShowCheckedModeBanner: false,

        // Enable desktop scroll
        scrollBehavior: _DesktopScrollBehavior(),

        // Theme
        theme: AppTheme.light(
          allowDynamic ? lightDynamic : null,
          settings.uiStyle,
        ),
        darkTheme: AppTheme.dark(
          allowDynamic ? darkDynamic : null,
          settings.uiStyle,
        ),
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
      ),
    );
  }
}
