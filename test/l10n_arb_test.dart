/// Purpose: Test that the three ARB catalogs stay in step.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads the ARB files.
/// Notes: `AGENTS.md` says every user-facing string goes through the ARB files
/// and that `app_en.arb` is the template. `flutter gen-l10n` only warns about a
/// missing translation, and a warning in a build log is not a promise — this
/// fails the build instead. Placeholders are compared too, because a
/// translation that renames one compiles and then throws at runtime.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const template = 'lib/l10n/app_en.arb';
  const translations = ['lib/l10n/app_zh.arb', 'lib/l10n/app_zh_TW.arb'];

  Map<String, dynamic> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  Set<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  /// The `{placeholder}` names a message actually uses.
  ///
  /// Read from the message text rather than from the `@key` metadata: the
  /// metadata only has to exist in the template, and duplicating it into every
  /// catalog would be a second thing to keep in step. What matters is that a
  /// translation interpolates the same names.
  /// A placeholder reference is a brace holding one word, closed by `}` or
  /// followed by `,` — the latter being how a plural or select opens, as in
  /// `{count, plural, ...}`. Requiring that punctuation is what keeps the
  /// *branch text* of a plural out of the results: `=0{No models}` would
  /// otherwise read as a placeholder named `No`.
  Set<String> placeholdersOf(Map<String, dynamic> arb, String key) {
    final message = arb[key];
    if (message is! String) return const {};
    return RegExp(
      r'\{(\w+)\s*[,}]',
    ).allMatches(message).map((m) => m.group(1)!).toSet();
  }

  test("every catalog carries exactly the template's keys", () {
    final expected = keysOf(read(template));
    expect(expected, isNotEmpty);
    for (final path in translations) {
      final actual = keysOf(read(path));
      expect(
        actual.difference(expected),
        isEmpty,
        reason: '$path has keys the template does not',
      );
      expect(
        expected.difference(actual),
        isEmpty,
        reason: '$path is missing keys',
      );
    }
  });

  test('every catalog interpolates the same placeholders', () {
    final english = read(template);
    for (final path in translations) {
      final other = read(path);
      for (final key in keysOf(english)) {
        expect(
          placeholdersOf(other, key),
          placeholdersOf(english, key),
          reason: '$path disagrees about $key',
        );
      }
    }
  });

  test('every catalog names its own locale', () {
    expect(read(template)['@@locale'], 'en');
    expect(read('lib/l10n/app_zh.arb')['@@locale'], 'zh');
    expect(read('lib/l10n/app_zh_TW.arb')['@@locale'], 'zh_TW');
  });

  test('the Traditional catalog is not a copy of the Simplified one', () {
    // A file that was added and never translated would pass every check above.
    // These are words Taiwan and the mainland write differently.
    final simplified = read('lib/l10n/app_zh.arb');
    final traditional = read('lib/l10n/app_zh_TW.arb');
    for (final key in ['navTranscribe', 'navLibrary', 'settingsData']) {
      expect(
        traditional[key],
        isNot(simplified[key]),
        reason: '$key is identical in both Chinese catalogs',
      );
    }
  });

  test('no message is left in English in a Chinese catalog', () {
    // Catches a key added to all three files with the English text pasted in.
    // Proper nouns and language names are the deliberate exceptions.
    const allowed = {'appTitle', 'settingsWebDAVNextcloud', 'settingsVersion'};
    final english = read(template);
    for (final path in translations) {
      final other = read(path);
      for (final key in keysOf(english)) {
        if (allowed.contains(key)) continue;
        final source = english[key];
        if (source is! String) continue;
        // Only compare messages that contain letters to translate.
        if (!RegExp(r'[A-Za-z]{4}').hasMatch(source)) continue;
        expect(
          other[key],
          isNot(source),
          reason: '$path still has the English text for $key',
        );
      }
    }
  });
}
