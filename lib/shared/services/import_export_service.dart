/// Purpose: MyTranscribe's ZIP export/import API, a facade over the shared
/// `ZipTransfer` engine.
/// Inputs: Destination directories and ZIP file paths from the settings pages.
/// Returns: Written file paths, or import success flags.
/// Side effects: Reads and writes the app data directory.
/// Notes: Archive naming is `mytranscribe_export_<yyyyMMdd_HHmmss>.zip`.
library;

import 'package:myapps_data/myapps_data.dart' as shared;

import '../../app/data_modules.dart';

class ImportExportService {
  /// Shared ZIP engine configured strictly.
  ///
  /// MyTranscribe has no installed base to stay lenient for, so it takes the
  /// stricter knobs: unknown entries are rejected, payloads must be UTF-8 and
  /// must parse as settings data before anything is written, and writes are
  /// atomic. Path traversal is refused outright by the engine regardless.
  static final shared.ZipTransfer _zip = shared.ZipTransfer(
    storage: const TranscribeStorageAdapter(),
    modules: transcribeModuleRegistry,
    archiveNamePrefix: transcribeArchiveNamePrefix,
    rejectUnknownEntries: true,
    strictUtf8: true,
    validateBeforeWrite: true,
    atomicWrites: true,
  );

  /// Purpose: Export the sources, models and defaults as a ZIP file.
  /// Inputs: `destDir`.
  /// Returns: `Future<String?>` — the exported file path, or null on failure.
  /// Side effects: Writes `mytranscribe_export_<stamp>.zip` in `destDir`.
  /// Notes: Bundles the registry's data files. Recordings, transcripts, API
  /// keys, `webdav_config.json`, `.sync_base/` and `backups/` are never
  /// included — the registry is the allowlist, so exclusion is structural.
  static Future<String?> exportZIP(String destDir) => _zip.exportZip(destDir);

  /// Purpose: Import sources, models and defaults from a ZIP file.
  /// Inputs: `filePath`.
  /// Returns: `Future<bool>` — true on success.
  /// Side effects: Overwrites allowlisted data files.
  /// Notes: Only the registry's data files are extracted, every entry must
  /// resolve inside the app dir, and an archive containing anything else is
  /// rejected without writing.
  static Future<bool> importZIP(String filePath) => _zip.importZip(filePath);
}
