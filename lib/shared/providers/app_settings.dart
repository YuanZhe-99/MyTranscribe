import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../services/transcribe_storage.dart';

/// How the transcript viewer lays a transcript out.
enum TranscriptViewMode {
  /// Paragraphs of continuous prose, one per speaker turn.
  transcript,

  /// One row per segment, with its own time range.
  segments,
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  /// Purpose: Create an app settings notifier instance.
  /// Inputs: None.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: Starts loading the persisted settings.
  /// Notes: None.
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }

  /// Purpose: Create a notifier that starts from fixed settings.
  /// Inputs: `settings`.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: None; nothing is read from disk.
  /// Notes: For tests that override `appSettingsProvider`. Setters still
  /// persist through `TranscribeStorage`.
  AppSettingsNotifier.fixed(super.settings);

  /// Purpose: Load the persisted preferences from disk.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `storage_config.json` and replaces the state.
  /// Notes: Internal helper used within this file only. **A storage failure
  /// leaves every default in place rather than propagating.** This runs from
  /// the constructor, so nothing is awaiting it and an exception would surface
  /// as an unhandled asynchronous error while the app carried on with the
  /// defaults anyway — the same outcome, reported as a crash.
  Future<void> _loadPersisted() async {
    try {
      await _readPersisted();
    } catch (_) {
      // Defaults, already in `state` from the constructor.
    }
  }

  /// Purpose: Read every persisted preference and apply it.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the config file and replaces the state.
  /// Notes: Internal helper used within this file only.
  Future<void> _readPersisted() async {
    final modeStr = await TranscribeStorage.getThemeMode();
    final localeTag = await TranscribeStorage.getLocaleTag();
    final fontSize = await TranscribeStorage.getViewerFontSize();
    final showTimestamps = await TranscribeStorage.getViewerShowTimestamps();
    final groupSpeakers = await TranscribeStorage.getViewerGroupSpeakers();
    final keepChunks = await TranscribeStorage.getKeepChunkFiles();
    final autoSaveFiles = await TranscribeStorage.getAutoSaveTranscriptFiles();
    final uiStyle = (await TranscribeStorage.getUiStyle()) == 'material3'
        ? AppUiStyle.material3
        : AppUiStyle.expressive;
    final expressiveWideBottomNav = await TranscribeStorage.getWideBottomNav();
    final navRailOnRight = await TranscribeStorage.getNavRailRight();
    final alwaysSideNav = await TranscribeStorage.getAlwaysSideNav();

    final themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    Locale? locale;
    if (localeTag != null) {
      final parts = localeTag.split('_');
      locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }

    state = AppSettings(
      themeMode: themeMode,
      locale: locale,
      // An out-of-range value in a hand-edited config reads as the default.
      viewerFontSize:
          fontSize != null &&
              fontSize >= AppSettings.minFontSize &&
              fontSize <= AppSettings.maxFontSize
          ? fontSize
          : AppSettings.defaultFontSize,
      viewerShowTimestamps: showTimestamps,
      viewerGroupSpeakers: groupSpeakers,
      keepChunkFiles: keepChunks,
      autoSaveTranscriptFiles: autoSaveFiles,
      uiStyle: uiStyle,
      expressiveWideBottomNav: expressiveWideBottomNav,
      navRailOnRight: navRailOnRight,
      alwaysSideNav: alwaysSideNav,
    );
  }

  /// Purpose: Update theme mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: Persists the selected theme mode.
  /// Notes: `system` is stored as an absent key, not a value.
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    TranscribeStorage.setThemeMode(str);
  }

  /// Purpose: Update locale with the provided value.
  /// Inputs: `locale` — null follows the system.
  /// Returns: None.
  /// Side effects: Persists the selected locale.
  /// Notes: Stored as `language` or `language_COUNTRY`, which is what carries
  /// `zh_TW`: Traditional and Simplified Chinese differ only by country here,
  /// so a tag that dropped it would silently move a reader to the other one.
  void setLocale(Locale? locale) {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    if (locale == null) {
      TranscribeStorage.setLocaleTag(null);
    } else {
      final tag = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      TranscribeStorage.setLocaleTag(tag);
    }
  }

  /// Purpose: Switch the interface style.
  /// Inputs: `style`.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: Expressive is the default and is stored as an absent key. Expressive
  /// gets the theme-level Expressive approximation and the floating island
  /// bottom bar; Material 3 the stock theme and the classic full-width bar. The
  /// wide-window rail is the same in both.
  void setUiStyle(AppUiStyle style) {
    state = state.copyWith(uiStyle: style);
    TranscribeStorage.setUiStyle(
      style == AppUiStyle.material3 ? 'material3' : null,
    );
  }

  /// Purpose: Choose whether the Expressive style keeps its bottom bar on
  /// wide windows instead of the side rail (0.4.1).
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; the shell rebuilds.
  /// Notes: Off (side rail) by default. Ignored by the Material 3 style.
  void setExpressiveWideBottomNav(bool enabled) {
    state = state.copyWith(expressiveWideBottomNav: enabled);
    TranscribeStorage.setWideBottomNav(enabled);
  }

  /// Purpose: Choose which side of the window the navigation rail sits on
  /// (0.4.1).
  /// Inputs: `right`.
  /// Returns: None.
  /// Side effects: Persists the preference; the shell rebuilds.
  /// Notes: Left by default; applies to both styles whenever the rail shows.
  void setNavRailOnRight(bool right) {
    state = state.copyWith(navRailOnRight: right);
    TranscribeStorage.setNavRailRight(right);
  }

  /// Purpose: Choose whether the side rail is used even on narrow windows
  /// (0.4.1).
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; the shell rebuilds.
  /// Notes: Off by default and not recommended on phones, where the rail takes
  /// width from the content. When on it overrides the Expressive
  /// bottom-on-wide-screens choice.
  void setAlwaysSideNav(bool enabled) {
    state = state.copyWith(alwaysSideNav: enabled);
    TranscribeStorage.setAlwaysSideNav(enabled);
  }

  /// Purpose: Change the transcript viewer's text size.
  /// Inputs: `size` in points.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: Clamped rather than rejected, so a value written by another build
  /// still lands somewhere usable. The default is stored as an absent key.
  void setViewerFontSize(int size) {
    final clamped = size.clamp(
      AppSettings.minFontSize,
      AppSettings.maxFontSize,
    );
    state = state.copyWith(viewerFontSize: clamped);
    TranscribeStorage.setViewerFontSize(
      clamped == AppSettings.defaultFontSize ? null : clamped,
    );
  }

  /// Purpose: Turn the viewer's timestamps on or off.
  /// Inputs: `show`.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: On by default, so off is what gets stored.
  void setViewerShowTimestamps(bool show) {
    state = state.copyWith(viewerShowTimestamps: show);
    TranscribeStorage.setViewerShowTimestamps(show);
  }

  /// Purpose: Turn speaker grouping on or off in the viewer.
  /// Inputs: `group`.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: On by default, so off is what gets stored.
  void setViewerGroupSpeakers(bool group) {
    state = state.copyWith(viewerGroupSpeakers: group);
    TranscribeStorage.setViewerGroupSpeakers(group);
  }

  /// Purpose: Choose whether a finished job keeps its chunk files.
  /// Inputs: `keep`.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: Off by default. Kept chunks are as large as the recording, so this
  /// is a debugging aid rather than something to leave on.
  void setKeepChunkFiles(bool keep) {
    state = state.copyWith(keepChunkFiles: keep);
    TranscribeStorage.setKeepChunkFiles(keep);
  }

  /// Purpose: Choose whether a finished job writes transcript files beside the
  /// recording.
  /// Inputs: `on`.
  /// Returns: None.
  /// Side effects: Persists the choice.
  /// Notes: Off by default. The files land in whatever folder the recording
  /// came from, which is not always somewhere the user wants them.
  void setAutoSaveTranscriptFiles(bool on) {
    state = state.copyWith(autoSaveTranscriptFiles: on);
    TranscribeStorage.setAutoSaveTranscriptFiles(on);
  }
}

class AppSettings {
  /// Smallest transcript text size the viewer offers, in points.
  static const minFontSize = 12;

  /// Largest transcript text size the viewer offers, in points.
  static const maxFontSize = 24;

  /// The transcript text size a fresh install reads at, in points.
  static const defaultFontSize = 16;

  /// Which theme the app follows.
  final ThemeMode themeMode;

  /// The chosen interface language; null follows the system.
  final Locale? locale;

  /// The transcript viewer's text size, in points.
  final int viewerFontSize;

  /// Whether the viewer prints a timestamp on each paragraph.
  final bool viewerShowTimestamps;

  /// Whether the viewer joins consecutive segments of one speaker.
  final bool viewerGroupSpeakers;

  /// Whether a finished job keeps its chunk audio for inspection.
  final bool keepChunkFiles;

  /// Whether a finished job writes a Markdown and a text file beside the
  /// recording it was made from.
  final bool autoSaveTranscriptFiles;

  /// The interface style (0.4.0): Expressive (default, with the compact floating
  /// bottom bar) or stock Material 3 (classic bottom bar).
  final AppUiStyle uiStyle;

  /// Whether the Expressive style keeps its bottom bar on wide windows instead
  /// of the side rail (0.4.1). Off by default.
  final bool expressiveWideBottomNav;

  /// Whether the navigation rail sits on the right of the window (0.4.1). Off
  /// (left) by default; applies to both styles.
  final bool navRailOnRight;

  /// Whether the side rail is used even on narrow windows such as phones
  /// (0.4.1). Off by default; not recommended there.
  final bool alwaysSideNav;

  /// Purpose: Create an app settings instance.
  /// Inputs: All fields.
  /// Returns: A new `AppSettings` instance.
  /// Side effects: None.
  /// Notes: Device-local preferences only; nothing here is synced. They live in
  /// one object so a page reads them synchronously from the provider rather
  /// than starting its own async read and racing its own first frame.
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.viewerFontSize = defaultFontSize,
    this.viewerShowTimestamps = true,
    this.viewerGroupSpeakers = true,
    this.keepChunkFiles = false,
    this.autoSaveTranscriptFiles = false,
    this.uiStyle = AppUiStyle.expressive,
    this.expressiveWideBottomNav = false,
    this.navRailOnRight = false,
    this.alwaysSideNav = false,
  });

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: The fields to replace, plus a `clear` flag per nullable one.
  /// Returns: `AppSettings`.
  /// Side effects: None.
  /// Notes: The `clear` flags exist because `null` already means "keep".
  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    int? viewerFontSize,
    bool? viewerShowTimestamps,
    bool? viewerGroupSpeakers,
    bool? keepChunkFiles,
    bool? autoSaveTranscriptFiles,
    AppUiStyle? uiStyle,
    bool? expressiveWideBottomNav,
    bool? navRailOnRight,
    bool? alwaysSideNav,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      viewerFontSize: viewerFontSize ?? this.viewerFontSize,
      viewerShowTimestamps: viewerShowTimestamps ?? this.viewerShowTimestamps,
      viewerGroupSpeakers: viewerGroupSpeakers ?? this.viewerGroupSpeakers,
      keepChunkFiles: keepChunkFiles ?? this.keepChunkFiles,
      autoSaveTranscriptFiles:
          autoSaveTranscriptFiles ?? this.autoSaveTranscriptFiles,
      uiStyle: uiStyle ?? this.uiStyle,
      expressiveWideBottomNav:
          expressiveWideBottomNav ?? this.expressiveWideBottomNav,
      navRailOnRight: navRailOnRight ?? this.navRailOnRight,
      alwaysSideNav: alwaysSideNav ?? this.alwaysSideNav,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
      (ref) => AppSettingsNotifier(),
    );
