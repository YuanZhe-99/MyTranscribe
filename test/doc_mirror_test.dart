/// Purpose: Test that the Chinese documentation mirrors the English file for
/// file, and that both stay linked to the code they describe.
/// Inputs: None; the `doc/` tree is read from disk.
/// Returns: None.
/// Side effects: Reads files.
/// Notes: `AGENTS.md` requires an exact mirror — same files, same headings —
/// and a rule nothing checks is a rule that drifts. This catches the two ways
/// it goes wrong in practice: a page added on one side only, and a link to a
/// page that was renamed or never written.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Purpose: List every Markdown page under one documentation directory.
/// Inputs: The [language] directory name.
/// Returns: Paths relative to that directory, sorted, with forward slashes.
/// Side effects: Reads the directory.
/// Notes: Internal helper used within this file only. Slashes are normalised
/// because this repository is developed on Windows and the test must compare
/// the same strings there and on a Mac.
List<String> pagesOf(String language) {
  final root = Directory(p.join('doc', language));
  if (!root.existsSync()) return const [];
  return [
    for (final entry in root.listSync(recursive: true))
      if (entry is File && entry.path.endsWith('.md'))
        p.relative(entry.path, from: root.path).replaceAll(r'\', '/'),
  ]..sort();
}

/// Purpose: Read every heading of a page.
/// Inputs: The [language] and the page's relative [path].
/// Returns: The heading lines, in order.
/// Side effects: Reads the file.
/// Notes: Internal helper used within this file only. Only the depth is
/// compared, not the text — the text is translated, the structure is not.
List<int> headingDepthsOf(String language, String path) => [
  for (final line in File(p.join('doc', language, path)).readAsLinesSync())
    if (RegExp(r'^#{1,6} ').hasMatch(line)) line.indexOf(' '),
];

void main() {
  group('the documentation mirror', () {
    test('has the same pages in English and Chinese', () {
      final english = pagesOf('en-us');
      final chinese = pagesOf('zh-cn');

      expect(english, isNotEmpty, reason: 'the English tree is authoritative');
      expect(
        chinese,
        english,
        reason: 'every page must exist in both languages, at the same path',
      );
    });

    test('gives each page the same heading structure', () {
      // The words are translated; the shape is not. A page that lost a section
      // in translation is the failure this catches.
      for (final page in pagesOf('en-us')) {
        expect(
          headingDepthsOf('zh-cn', page),
          headingDepthsOf('en-us', page),
          reason: '$page has a different heading structure in Chinese',
        );
      }
    });
  });

  group('the links between pages', () {
    test('all point at a page that exists', () {
      for (final language in ['en-us', 'zh-cn']) {
        for (final page in pagesOf(language)) {
          final file = File(p.join('doc', language, page));
          final links = RegExp(
            r'\]\(([^)#]+\.md)(#[^)]*)?\)',
          ).allMatches(file.readAsStringSync());

          for (final link in links) {
            final target = p.normalize(
              p.join(p.dirname(file.path), link.group(1)!),
            );
            expect(
              File(target).existsSync(),
              isTrue,
              reason: '$language/$page links to ${link.group(1)}, which is not '
                  'there',
            );
          }
        }
      }
    });
  });

  group('the function index', () {
    test('lists every source file, and nothing that is gone', () {
      // The index claims to cover the whole tree. When it stops being true it
      // stops being useful, and nobody notices until they go looking for a
      // file that was never added.
      final sources = [
        for (final entry in Directory('lib').listSync(recursive: true))
          if (entry is File &&
              entry.path.endsWith('.dart') &&
              !entry.path.replaceAll(r'\', '/').contains('lib/l10n/'))
            entry.path.replaceAll(r'\', '/'),
      ]..sort();

      final index = File(
        p.join('doc', 'en-us', 'functions', 'INDEX.md'),
      ).readAsStringSync();
      final listed = RegExp(
        r'`(lib/[^`]+\.dart)`',
      ).allMatches(index).map((m) => m.group(1)!).toSet();

      expect(
        sources.where((s) => !listed.contains(s)),
        isEmpty,
        reason: 'these source files are missing from the index',
      );
      expect(
        listed.where((l) => !sources.contains(l)),
        isEmpty,
        reason: 'these index rows name a file that no longer exists',
      );
    });
  });
}
