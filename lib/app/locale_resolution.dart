import 'package:flutter/widgets.dart';

/// How a device's language list is matched to the app's three UI languages.
///
/// Flutter's own `basicLocaleListResolution` is kept — this only corrects what
/// it is given. Chinese is the reason: a phone set to Traditional Chinese can
/// say `zh-Hant-TW`, `zh-Hant-HK`, `zh-Hant`, or just `zh-HK`, and Flutter's
/// algorithm matches on language and country, so every one of those except
/// `zh-Hant-TW` would land on Simplified Chinese. Deciding by **script** is
/// what a reader means by "Traditional", so that decision is made here first.

/// The country code the app's Traditional Chinese locale is filed under.
const traditionalChineseCountry = 'TW';

/// Countries and regions that write Chinese in Traditional characters.
const traditionalChineseRegions = {'TW', 'HK', 'MO'};

/// Purpose: Normalize any Chinese locale to one of the app's two.
/// Inputs: `locale`.
/// Returns: `Locale` — `zh_TW` for Traditional, `zh` for Simplified, and the
/// input unchanged for every other language.
/// Side effects: None.
/// Notes: The script subtag wins when there is one, because it says what the
/// user actually asked for; the region is the fallback for the devices that
/// send none. `zh-Hans-HK` is therefore Simplified even though Hong Kong is a
/// Traditional region, which is the honest reading of that request.
Locale normalizeChinese(Locale locale) {
  if (locale.languageCode != 'zh') return locale;
  final script = locale.scriptCode;
  if (script == 'Hant') return const Locale('zh', traditionalChineseCountry);
  if (script == 'Hans') return const Locale('zh');
  return traditionalChineseRegions.contains(locale.countryCode)
      ? const Locale('zh', traditionalChineseCountry)
      : const Locale('zh');
}

/// Purpose: Choose the UI language for a device's preferred locale list.
/// Inputs: `preferred` — the device's list, best first; `supported` — what the
/// app ships.
/// Returns: `Locale` — the language to display.
/// Side effects: None.
/// Notes: Wired as `MaterialApp.localeListResolutionCallback`, so it runs only
/// when the learner has not picked a language themselves; an explicit choice is
/// passed as `locale` and Flutter uses that instead. An empty or null list, and
/// a list with no Chinese and no match, both fall through to Flutter's own
/// answer, which is the first supported locale — English, the template.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  final normalized = [
    for (final locale in preferred ?? const <Locale>[]) normalizeChinese(locale),
  ];
  return basicLocaleListResolution(normalized, supported);
}
