/// Purpose: Find the `ffmpeg` and `ffprobe` executables on a platform that
/// uses external ones.
/// Inputs: A path the user set, the app's own directories, and `PATH`.
/// Returns: A resolved tool, or a reason it could not be found.
/// Side effects: Reads the file system and may run an executable to check it.
/// Notes: The search order and the Windows probing rule are adapted from the
/// `video-auto-compressor` project's `runtime_tools.dart`, which worked this
/// out first. See `doc/en-us/features/media-tools.md`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Where a resolved executable came from.
///
/// Shown in Settings so the user can tell a build they chose from one that was
/// found for them, which is the difference between "why is it using that one"
/// and an answer.
enum FfmpegSource {
  /// A path the user entered in Settings.
  userSelected,

  /// The copy the app downloaded, in its own support directory.
  downloaded,

  /// Beside the application executable, or in a `bin` directory next to it.
  besideApp,

  /// In the working directory or its `bin` directory.
  workingDirectory,

  /// On `PATH`.
  systemPath,
}

/// One executable the app found.
class FfmpegTool {
  /// The tool's base name, `ffmpeg` or `ffprobe`.
  final String name;

  /// The absolute path to the executable.
  final String path;

  /// Where it was found.
  final FfmpegSource source;

  /// Purpose: Create a resolved tool.
  /// Inputs: [name], [path], [source].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const FfmpegTool({
    required this.name,
    required this.path,
    required this.source,
  });
}

/// Finds FFmpeg executables, in a fixed order, with a seam for tests.
class FfmpegLocator {
  /// A path the user set for `ffmpeg`, or null to search.
  final String? ffmpegOverride;

  /// A path the user set for `ffprobe`, or null to search.
  final String? ffprobeOverride;

  /// The app's support directory, where a downloaded copy lives.
  final Directory? downloadDirectory;

  /// Extra directories to search before `PATH`.
  ///
  /// Used for the Homebrew locations on macOS, and by tests, which pass a
  /// temporary directory here instead of touching the real environment.
  final List<Directory> extraDirectories;

  /// The `PATH` entries to search, defaulting to the process environment.
  ///
  /// Injectable so a test can search a directory it controls rather than
  /// whatever happens to be installed on the machine running the test.
  final List<String> searchPath;

  /// Purpose: Create a locator.
  /// Inputs: The user's overrides, the download directory, extra directories,
  /// and the `PATH` entries.
  /// Returns: A new locator.
  /// Side effects: Reads the environment when [searchPath] is not given.
  /// Notes: None.
  FfmpegLocator({
    this.ffmpegOverride,
    this.ffprobeOverride,
    this.downloadDirectory,
    this.extraDirectories = const [],
    List<String>? searchPath,
  }) : searchPath = searchPath ?? _environmentPath();

  /// Purpose: Split the `PATH` environment variable into directories.
  /// Inputs: None.
  /// Returns: The non-empty entries, in order.
  /// Side effects: Reads the environment.
  /// Notes: Internal helper used within this file only.
  static List<String> _environmentPath() {
    final value = Platform.environment['PATH'];
    if (value == null || value.isEmpty) return const [];
    return value
        .split(Platform.isWindows ? ';' : ':')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  /// Purpose: Return the file names an executable might have here.
  /// Inputs: [name] — `ffmpeg` or `ffprobe`.
  /// Returns: The candidate file names, most likely first.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The extension-less
  /// name is kept on Windows too, because a build extracted from an archive by
  /// hand sometimes has one.
  List<String> _fileNames(String name) =>
      Platform.isWindows ? ['$name.exe', name] : [name];

  /// Purpose: Find one executable.
  /// Inputs: [name] — `ffmpeg` or `ffprobe`.
  /// Returns: The resolved tool, or null when none was found.
  /// Side effects: Reads the file system; may run a candidate to check it.
  /// Notes: The order is: the user's own path, the downloaded copy, beside the
  /// app, the working directory, then `PATH`. The user's choice comes first so
  /// setting one is always effective, and it is **not** verified beyond
  /// existing — if they point at something broken, the error from running it
  /// says more than "not found" would.
  Future<FfmpegTool?> locate(String name) async {
    final override = name == 'ffmpeg' ? ffmpegOverride : ffprobeOverride;
    if (override != null && override.trim().isNotEmpty) {
      final resolved = await _probe(name, override.trim());
      if (resolved != null) {
        return FfmpegTool(
          name: name,
          path: resolved,
          source: FfmpegSource.userSelected,
        );
      }
    }

    for (final (directory, source) in _searchDirectories()) {
      for (final fileName in _fileNames(name)) {
        final candidate = p.join(directory.path, fileName);
        final resolved = await _probe(name, candidate);
        if (resolved != null) {
          return FfmpegTool(name: name, path: resolved, source: source);
        }
      }
    }

    for (final entry in searchPath) {
      for (final fileName in _fileNames(name)) {
        final resolved = await _probe(name, p.join(entry, fileName));
        if (resolved != null) {
          return FfmpegTool(
            name: name,
            path: resolved,
            source: FfmpegSource.systemPath,
          );
        }
      }
    }

    return null;
  }

  /// Purpose: List the directories to search, in order, with their labels.
  /// Inputs: None.
  /// Returns: Directory and source pairs.
  /// Side effects: Reads the process path and the working directory.
  /// Notes: Internal helper used within this file only. Each location is tried
  /// directly and with a `bin` subdirectory, because a downloaded FFmpeg
  /// archive unpacks with its executables under `bin`.
  List<(Directory, FfmpegSource)> _searchDirectories() {
    final directories = <(Directory, FfmpegSource)>[];

    void add(Directory directory, FfmpegSource source) {
      directories.add((directory, source));
      directories.add((Directory(p.join(directory.path, 'bin')), source));
    }

    final download = downloadDirectory;
    if (download != null) add(download, FfmpegSource.downloaded);
    add(File(Platform.resolvedExecutable).parent, FfmpegSource.besideApp);
    for (final extra in extraDirectories) {
      add(extra, FfmpegSource.besideApp);
    }
    add(Directory.current, FfmpegSource.workingDirectory);
    return directories;
  }

  /// Purpose: Check whether one candidate path is a usable executable.
  /// Inputs: [name] the tool, [path] the candidate.
  /// Returns: The absolute path when usable, else null.
  /// Side effects: Reads the file system; runs the candidate on non-Windows.
  /// Notes: Internal helper used within this file only.
  ///
  /// **On Windows a candidate is checked by existence alone, never by running
  /// it.** Running a console executable to test it flashes a console window,
  /// and the search tries many candidates — so verifying this way would flash
  /// one per candidate every time the app looks. Elsewhere the candidate is
  /// run with `-version`, which is cheap and catches a file that exists but
  /// cannot execute.
  Future<String?> _probe(String name, String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    if (Platform.isWindows) return file.absolute.path;

    try {
      final result = await Process.run(path, const ['-version']);
      if (result.exitCode != 0) return null;
    } catch (_) {
      return null;
    }
    return file.absolute.path;
  }
}
