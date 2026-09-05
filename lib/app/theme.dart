import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

class AppTheme {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `AppTheme._` instance.
  /// Side effects: None.
  /// Notes: Implementations should preserve this contract.
  AppTheme._();

  /// The seed scheme. Each app in the series has its own; MyTranscribe uses
  /// teal, so it is told apart from MyNihongo pink and MyDevice blue at a glance.
  static const FlexScheme _scheme = FlexScheme.tealM3;

  /// Purpose: Return the light Material theme used by the app.
  /// Inputs: None.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData get light => FlexThemeData.light(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 7,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      navigationBarLabelBehavior:
          NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    useMaterial3: true,
  );

  /// Purpose: Return the dark Material theme used by the app.
  /// Inputs: None.
  /// Returns: `ThemeData`.
  /// Side effects: None.
  /// Notes: None.
  static ThemeData get dark => FlexThemeData.dark(
    scheme: _scheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 13,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 20,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: true,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      navigationBarLabelBehavior:
          NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    useMaterial3: true,
  );
}
