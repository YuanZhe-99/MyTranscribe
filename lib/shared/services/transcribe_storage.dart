import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/data_modules.dart';
import '../../features/providers/models/transcribe_settings.dart';
import 'auto_sync_service.dart';

/// The app's storage hub: the one place that knows where data lives on disk.
///
/// Every file read or write in the app goes through [getAppDir] so a custom
/// storage path keeps working, and every settings write goes through
/// [saveSettings] so auto-sync learns about it.
class TranscribeStorage {
  static const _configFileName = 'storage_config.json';

  /// Custom storage directory path override.
  static String? _customPath;

  /// Whether config has been loaded from disk.
  static bool _configLoaded = false;

  /// Purpose: Resolve the platform default data directory.
  /// Inputs: None.
  /// Returns: `Future<Directory>` — `<documents>/MyTranscribe`, created if
  /// absent.
  /// Side effects: May create the directory.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getDefaultAppDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final appDir = Directory(p.join(dir.path, 'MyTranscribe'));
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    return appDir;
  }

  /// Purpose: Locate `storage_config.json`.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the default directory.
  /// Notes: Internal helper used within this file only. The config file always
  /// lives in the default location because it holds the custom path.
  static Future<File> _getConfigFile() async {
    final dir = await _getDefaultAppDir();
    return File(p.join(dir.path, _configFileName));
  }

  /// Purpose: Load the storage path from the config file, once.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `storage_config.json`; caches the custom path.
  /// Notes: Internal helper used within this file only. A malformed config is
  /// treated as absent.
  static Future<void> _loadConfig() async {
    if (_configLoaded) return;
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _customPath = json['storagePath'] as String?;
      }
    } catch (_) {}
    _configLoaded = true;
  }

  /// Purpose: Resolve the active app data directory.
  /// Inputs: None.
  /// Returns: `Future<Directory>` — the custom path when set, else the default.
  /// Side effects: May create the directory.
  /// Notes: Every file access in the app resolves through here.
  static Future<Directory> getAppDir() async {
    await _loadConfig();
    final custom = _customPath;
    if (custom != null && custom.isNotEmpty) {
      final dir = Directory(custom);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    return _getDefaultAppDir();
  }

  /// Purpose: Locate a file inside the app directory.
  /// Inputs: `name`.
  /// Returns: `Future<File>`.
  /// Side effects: None beyond [getAppDir].
  /// Notes: Internal helper used within this file only.
  static Future<File> _getFile(String name) async {
    final appDir = await getAppDir();
    return File(p.join(appDir.path, name));
  }

  /// Purpose: Resolve the directory holding one job's audio, chunks and
  /// transcript.
  /// Inputs: `jobId`; `create` — whether to create the directory.
  /// Returns: `Future<Directory>`.
  /// Side effects: May create the directory.
  /// Notes: Job folders live under the app directory so a storage-path change
  /// carries them along, but they are **not** in the module registry, which is
  /// what keeps recordings and transcripts out of sync, backups and ZIP
  /// exports. See `doc/en-us/data-formats.md`.
  static Future<Directory> jobDir(String jobId, {bool create = false}) async {
    final appDir = await getAppDir();
    final dir = Directory(p.join(appDir.path, jobsDirName, jobId));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Purpose: Resolve the directory holding every job folder.
  /// Inputs: `create` — whether to create the directory.
  /// Returns: `Future<Directory>`.
  /// Side effects: May create the directory.
  /// Notes: None.
  static Future<Directory> jobsDir({bool create = false}) async {
    final appDir = await getAppDir();
    final dir = Directory(p.join(appDir.path, jobsDirName));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Purpose: Return the active storage directory path for UI display.
  /// Inputs: None.
  /// Returns: `Future<String>`.
  /// Side effects: None.
  /// Notes: Respects the configured custom storage path when one is set.
  static Future<String> getStoragePath() async {
    final appDir = await getAppDir();
    return appDir.path;
  }

  /// Purpose: Change the storage directory and migrate the data to it.
  /// Inputs: `newPath`; pass `null` to reset to the default location.
  /// Returns: `Future<bool>` — false only when the path could not be recorded.
  /// Side effects: Rewrites `storage_config.json` and moves the old folder's
  /// contents to the new location.
  /// Notes: Migrates everything in the folder — the settings file, `jobs/`,
  /// `.sync_base/`, `backups/` and `webdav_config.json` — not an enumerated
  /// list, so a file added later moves automatically. `storage_config.json`
  /// stays put because it is what records the path. Existing destination files
  /// win and their source copies are left in place. `jobs/` can hold gigabytes
  /// of audio, so this can take a while; the caller shows progress.
  static Future<bool> setStoragePath(String? newPath) async {
    try {
      final oldDir = await getAppDir();

      _customPath = newPath;
      final config = await readConfig();
      if (newPath != null) {
        config['storagePath'] = newPath;
      } else {
        config.remove('storagePath');
      }
      await writeConfig(config);

      final newDir = await getAppDir();
      if (oldDir.path == newDir.path) return true;

      // Per-entry failures are reported rather than thrown; the path change
      // itself has already been persisted, so the move is best-effort and any
      // unmoved file remains readable at the old location.
      await migrateStorageContents(from: oldDir, to: newDir);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Settings document ──

  /// Purpose: Return the synced settings file for direct low-level access.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: None.
  /// Notes: For flows that need the path rather than the parsed document.
  static Future<File> getSettingsFile() => _getFile(settingsDataFileName);

  /// Purpose: Load the sources, models and defaults.
  /// Inputs: None.
  /// Returns: `Future<TranscribeSettings>` — empty when the file is absent or
  /// blank.
  /// Side effects: Reads the settings file.
  /// Notes: A corrupt file throws rather than being treated as empty, so a
  /// later save cannot silently overwrite settings that were merely unreadable.
  static Future<TranscribeSettings> loadSettings() async {
    final file = await getSettingsFile();
    if (!await file.exists()) return const TranscribeSettings();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const TranscribeSettings();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return TranscribeSettings.fromJson(json);
  }

  /// Purpose: Write the sources, models and defaults.
  /// Inputs: `settings`.
  /// Returns: None.
  /// Side effects: Atomically writes the settings file, then notifies
  /// auto-sync.
  /// Notes: Pretty-printed with two-space indentation — the shared sync engine
  /// writes the same format, which is what lets an unchanged file hit the
  /// raw-equality fast path instead of re-uploading.
  static Future<void> saveSettings(TranscribeSettings settings) async {
    final file = await getSettingsFile();
    await atomicWriteString(file, encodeSettings(settings));
    AutoSyncService.instance.notifySaved();
  }

  // ── Device-local preferences (`storage_config.json`) ──

  /// Purpose: Read the whole device-local settings map.
  /// Inputs: None.
  /// Returns: `Future<Map<String, dynamic>>` — empty when absent or malformed.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: The shared engines read and write their own keys here through
  /// `TranscribeStorageAdapter`, so this must never drop unknown keys.
  static Future<Map<String, dynamic>> readConfig() async {
    try {
      final file = await _getConfigFile();
      if (!await file.exists()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Purpose: Write the whole device-local settings map.
  /// Inputs: `config`.
  /// Returns: None.
  /// Side effects: Atomically writes `storage_config.json`.
  /// Notes: Callers read-modify-write, so keys owned by the shared engines
  /// survive an app-owned change and the other way round.
  static Future<void> writeConfig(Map<String, dynamic> config) async {
    final file = await _getConfigFile();
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  /// Purpose: Read a device-local boolean preference.
  /// Inputs: `key`.
  /// Returns: `Future<bool?>` — null when unset or stored as another type.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Internal helper used within this file only. A wrong type reads as
  /// unset, so a hand-edited config cannot crash the app.
  static Future<bool?> _getBool(String key) async {
    final value = (await readConfig())[key];
    return value is bool ? value : null;
  }

  /// Purpose: Write or clear a device-local boolean preference.
  /// Inputs: `key`, `value` — null removes the key.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: Internal helper used within this file only. Defaults are stored as
  /// an absent key, so a later build that changes a default changes it for
  /// everyone who never touched the setting.
  static Future<void> _setBool(String key, bool? value) async {
    final config = await readConfig();
    if (value == null) {
      config.remove(key);
    } else {
      config[key] = value;
    }
    await writeConfig(config);
  }

  /// Purpose: Read a device-local string preference.
  /// Inputs: `key`.
  /// Returns: `Future<String?>`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Internal helper used within this file only. An empty string reads
  /// as unset, so clearing a text field and removing the key mean the same.
  static Future<String?> _getString(String key) async {
    final value = (await readConfig())[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Purpose: Write or clear a device-local string preference.
  /// Inputs: `key`, `value` — null or empty removes the key.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: Internal helper used within this file only.
  static Future<void> _setString(String key, String? value) async {
    final config = await readConfig();
    if (value == null || value.isEmpty) {
      config.remove(key);
    } else {
      config[key] = value;
    }
    await writeConfig(config);
  }

  /// Purpose: Read a device-local integer preference.
  /// Inputs: `key`.
  /// Returns: `Future<int?>`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Internal helper used within this file only.
  static Future<int?> _getInt(String key) async {
    final value = (await readConfig())[key];
    return value is int ? value : null;
  }

  /// Purpose: Write or clear a device-local integer preference.
  /// Inputs: `key`, `value` — null removes the key.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: Internal helper used within this file only.
  static Future<void> _setInt(String key, int? value) async {
    final config = await readConfig();
    if (value == null) {
      config.remove(key);
    } else {
      config[key] = value;
    }
    await writeConfig(config);
  }

  /// Purpose: Read the persisted theme mode.
  /// Inputs: None.
  /// Returns: `Future<String?>` — `light`, `dark`, or null for the system.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<String?> getThemeMode() => _getString('themeMode');

  /// Purpose: Persist the theme mode.
  /// Inputs: `mode` — `light`, `dark`, or null for the system.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: The system default is stored as an absent key.
  static Future<void> setThemeMode(String? mode) =>
      _setString('themeMode', mode);

  /// Purpose: Read the persisted interface language.
  /// Inputs: None.
  /// Returns: `Future<String?>` — `language` or `language_COUNTRY`, or null to
  /// follow the system.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<String?> getLocaleTag() => _getString('locale');

  /// Purpose: Persist the interface language.
  /// Inputs: `tag` — `language` or `language_COUNTRY`, or null for the system.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: The country part carries `zh_TW`: Traditional and Simplified
  /// Chinese differ only by country here, so a tag that dropped it would
  /// silently move a reader to the other one.
  static Future<void> setLocaleTag(String? tag) => _setString('locale', tag);

  /// Purpose: Read the tab the app was last on.
  /// Inputs: None.
  /// Returns: `Future<String>` — a route name without its leading slash.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Defaults to the transcribe tab, which is what the app is for.
  static Future<String> getLastTab() async =>
      await _getString('lastTab') ?? 'jobs';

  /// Purpose: Remember the tab the app is on.
  /// Inputs: `tab` — a route name without its leading slash.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: Called on every tab change and deliberately not awaited; losing
  /// the write costs nothing more than starting on the transcribe tab.
  static Future<void> setLastTab(String tab) => _setString('lastTab', tab);

  /// Purpose: Read the user's own path to the `ffmpeg` executable.
  /// Inputs: None.
  /// Returns: `Future<String?>` — null when the app should search for one.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Device-local on purpose: a path that exists on a desktop names
  /// nothing on a phone, so this must never travel through sync.
  static Future<String?> getFfmpegPath() => _getString('ffmpegPath');

  /// Purpose: Set the user's own path to the `ffmpeg` executable.
  /// Inputs: `path` — null restores automatic discovery.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setFfmpegPath(String? path) =>
      _setString('ffmpegPath', path);

  /// Purpose: Read the user's own path to the `ffprobe` executable.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Separate from the `ffmpeg` path because a user may have one on
  /// PATH and the other beside it under another name.
  static Future<String?> getFfprobePath() => _getString('ffprobePath');

  /// Purpose: Set the user's own path to the `ffprobe` executable.
  /// Inputs: `path` — null restores automatic discovery.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setFfprobePath(String? path) =>
      _setString('ffprobePath', path);

  /// Purpose: Read the hosts the user marked safe for API keys over plain
  /// HTTP.
  /// Inputs: None.
  /// Returns: `Future<List<String>>` — host names or `*.suffix` patterns.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: **Device-local, deliberately.** A host name can resolve to a
  /// machine on this network here and to something else entirely on another
  /// device, so the trust decision belongs to the device that will make the
  /// connection. Keeping it out of sync also means one device's edit cannot
  /// start key uploads from every other device.
  static Future<List<String>> getSecretsTrustedHosts() async {
    final value = (await readConfig())['secretsTrustedHosts'];
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  /// Purpose: Replace the trusted-host list.
  /// Inputs: `hosts`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: An empty list removes the key, so the default reads as "trust
  /// nothing extra".
  static Future<void> setSecretsTrustedHosts(List<String> hosts) async {
    final config = await readConfig();
    if (hosts.isEmpty) {
      config.remove('secretsTrustedHosts');
    } else {
      config['secretsTrustedHosts'] = hosts;
    }
    await writeConfig(config);
  }

  /// Purpose: Read the transcript viewer's text size.
  /// Inputs: None.
  /// Returns: `Future<int?>` — points, or null for the default.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: None.
  static Future<int?> getViewerFontSize() => _getInt('viewerFontSize');

  /// Purpose: Set the transcript viewer's text size.
  /// Inputs: `size` — null restores the default.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setViewerFontSize(int? size) =>
      _setInt('viewerFontSize', size);

  /// Purpose: Read whether the viewer prints a timestamp on each paragraph.
  /// Inputs: None.
  /// Returns: `Future<bool>` — true unless the user turned it off.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: On by default, so **off** is what gets stored.
  static Future<bool> getViewerShowTimestamps() async =>
      await _getBool('viewerShowTimestamps') ?? true;

  /// Purpose: Turn the viewer's timestamps on or off.
  /// Inputs: `show`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setViewerShowTimestamps(bool show) =>
      _setBool('viewerShowTimestamps', show ? null : false);

  /// Purpose: Read whether the viewer joins consecutive segments of one
  /// speaker into a paragraph.
  /// Inputs: None.
  /// Returns: `Future<bool>` — true unless the user turned it off.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: On by default: a diarized transcript read segment by segment is a
  /// wall of one-line rows, and the Segments view already offers that.
  static Future<bool> getViewerGroupSpeakers() async =>
      await _getBool('viewerGroupSpeakers') ?? true;

  /// Purpose: Turn speaker grouping on or off.
  /// Inputs: `group`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setViewerGroupSpeakers(bool group) =>
      _setBool('viewerGroupSpeakers', group ? null : false);

  /// Purpose: Read whether finished chunk files are kept for inspection.
  /// Inputs: None.
  /// Returns: `Future<bool>` — false unless the user turned it on.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Off by default: the chunks of a long recording are as large as the
  /// recording itself.
  static Future<bool> getKeepChunkFiles() async =>
      await _getBool('keepChunkFiles') ?? false;

  /// Purpose: Turn chunk retention on or off.
  /// Inputs: `keep`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setKeepChunkFiles(bool keep) =>
      _setBool('keepChunkFiles', keep ? true : null);

  /// Purpose: Read which view the transcript opens in.
  /// Inputs: None.
  /// Returns: `Future<String>` — `transcript` or `segments`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Reading is what most people open a transcript to do, so the
  /// flowing view is the default; the per-line view is for correcting.
  static Future<String> getViewerMode() async =>
      await _getString('viewerMode') ?? 'transcript';

  /// Purpose: Remember which view the transcript was left in.
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setViewerMode(String mode) =>
      _setString('viewerMode', mode == 'transcript' ? null : mode);

  /// Purpose: Read whether the transcript scrolls itself as the audio plays.
  /// Inputs: None.
  /// Returns: `Future<bool>` — true unless the user turned it off.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: On by default: somebody playing the audio beside the transcript is
  /// following along, and scrolling by hand at the same time is a nuisance.
  static Future<bool> getViewerAutoScroll() async =>
      await _getBool('viewerAutoScroll') ?? true;

  /// Purpose: Turn following-the-audio on or off.
  /// Inputs: `follow`.
  /// Returns: None.
  /// Side effects: Rewrites `storage_config.json`.
  /// Notes: None.
  static Future<void> setViewerAutoScroll(bool follow) =>
      _setBool('viewerAutoScroll', follow ? null : false);
}
