/// Purpose: Test that the locator searches where it says it does, in order.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and removes temporary directories and files.
/// Notes: The search path is injected rather than read from the environment, so
/// these tests find the files they created and never whatever FFmpeg happens to
/// be installed on the machine running them. On Windows a candidate is accepted
/// on existence alone, so a plain empty file stands in for an executable; on
/// other platforms the locator runs it, so those cases are skipped rather than
/// written to depend on a real binary.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/media/services/ffmpeg_locator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_locator_');
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {
      // Windows can hold a handle briefly; a leftover temp directory is not
      // worth failing a test over.
    }
  });

  /// Purpose: Create a stand-in executable in a directory.
  /// Inputs: [directory], [name] without an extension.
  /// Returns: Its path.
  /// Side effects: Creates the directory and the file.
  /// Notes: Internal helper used within this file only.
  String makeTool(Directory directory, String name) {
    directory.createSync(recursive: true);
    final file = File(
      p.join(directory.path, Platform.isWindows ? '$name.exe' : name),
    );
    file.writeAsStringSync('not really an executable');
    return file.path;
  }

  test('an override wins over everything else', () async {
    final chosen = Directory(p.join(root.path, 'chosen'));
    final onPath = Directory(p.join(root.path, 'onpath'));
    final overridePath = makeTool(chosen, 'ffmpeg');
    makeTool(onPath, 'ffmpeg');

    final locator = FfmpegLocator(
      ffmpegOverride: overridePath,
      searchPath: [onPath.path],
    );
    final tool = await locator.locate('ffmpeg');

    expect(tool, isNotNull);
    expect(tool!.path, overridePath);
    expect(tool.source, FfmpegSource.userSelected);
  }, skip: !Platform.isWindows);

  test('a downloaded copy is preferred to one on PATH', () async {
    final downloads = Directory(p.join(root.path, 'support', 'ffmpeg'));
    final onPath = Directory(p.join(root.path, 'onpath'));
    final downloaded = makeTool(downloads, 'ffmpeg');
    makeTool(onPath, 'ffmpeg');

    final locator = FfmpegLocator(
      downloadDirectory: downloads,
      searchPath: [onPath.path],
    );
    final tool = await locator.locate('ffmpeg');

    expect(tool!.path, downloaded);
    expect(tool.source, FfmpegSource.downloaded);
  }, skip: !Platform.isWindows);

  test('a bin subdirectory is searched too', () async {
    // A downloaded FFmpeg archive unpacks with its executables under bin/.
    final downloads = Directory(p.join(root.path, 'support', 'ffmpeg'));
    final inBin = makeTool(Directory(p.join(downloads.path, 'bin')), 'ffmpeg');
    downloads.createSync(recursive: true);

    final locator = FfmpegLocator(
      downloadDirectory: downloads,
      searchPath: const [],
    );
    final tool = await locator.locate('ffmpeg');

    expect(tool!.path, inBin);
    expect(tool.source, FfmpegSource.downloaded);
  }, skip: !Platform.isWindows);

  test('PATH is searched in order', () async {
    final first = Directory(p.join(root.path, 'first'));
    final second = Directory(p.join(root.path, 'second'));
    final expected = makeTool(first, 'ffprobe');
    makeTool(second, 'ffprobe');

    final locator = FfmpegLocator(searchPath: [first.path, second.path]);
    final tool = await locator.locate('ffprobe');

    expect(tool!.path, expected);
    expect(tool.source, FfmpegSource.systemPath);
  }, skip: !Platform.isWindows);

  test('nothing is found when nothing is there', () async {
    final empty = Directory(p.join(root.path, 'empty'))..createSync();
    final locator = FfmpegLocator(searchPath: [empty.path]);
    expect(await locator.locate('ffmpeg'), isNull);
  });

  test(
    'an override pointing at nothing falls through to the search',
    () async {
      final onPath = Directory(p.join(root.path, 'onpath'));
      final found = makeTool(onPath, 'ffmpeg');

      final locator = FfmpegLocator(
        ffmpegOverride: p.join(root.path, 'does-not-exist', 'ffmpeg.exe'),
        searchPath: [onPath.path],
      );
      final tool = await locator.locate('ffmpeg');

      // Falling through rather than failing means a stale setting from a machine
      // that no longer has that file does not break the app.
      expect(tool!.path, found);
      expect(tool.source, FfmpegSource.systemPath);
    },
    skip: !Platform.isWindows,
  );

  test('the two tools are resolved independently', () async {
    // One on PATH and the other only in the download directory is exactly what
    // a half-finished setup looks like.
    final downloads = Directory(p.join(root.path, 'support', 'ffmpeg'));
    final onPath = Directory(p.join(root.path, 'onpath'));
    final downloadedFfmpeg = makeTool(downloads, 'ffmpeg');
    final pathFfprobe = makeTool(onPath, 'ffprobe');

    final locator = FfmpegLocator(
      downloadDirectory: downloads,
      searchPath: [onPath.path],
    );

    expect((await locator.locate('ffmpeg'))!.path, downloadedFfmpeg);
    expect((await locator.locate('ffprobe'))!.path, pathFfprobe);
  }, skip: !Platform.isWindows);

  test('an empty PATH does not throw', () async {
    final locator = FfmpegLocator(searchPath: const []);
    expect(await locator.locate('ffmpeg'), isNull);
  });
}
