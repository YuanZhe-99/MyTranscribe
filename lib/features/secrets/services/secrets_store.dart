/// Purpose: Read and write the API keys file.
/// Inputs: The app data directory, through the storage hub.
/// Returns: The keys, and a Riverpod provider over them.
/// Side effects: Reads and writes `transcribe_secrets.json`.
/// Notes: The file lives under the app directory so a storage-path change
/// carries it along, but it is **not** in the module registry — which is what
/// keeps it out of sync, backups and ZIP exports structurally. The pattern is
/// MyAnime!!!!!'s `metadata_cache.dart`: same folder, deliberately absent from
/// the registry, with a comment saying so where somebody might add it.
///
/// Keys are stored in plain text, as the WebDAV password beside them is, and
/// the privacy policy says so.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_data/myapps_data.dart'
    show AtomicWriteQueue, atomicWriteString;
import 'package:path/path.dart' as p;

import '../../../app/data_modules.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../../../shared/utils/file_retry.dart';
import '../models/provider_secrets.dart';

/// Reads and writes the keys.
class SecretsStore {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the storage hub's shape, so both are used the same way.
  SecretsStore._();

  /// Purpose: Locate the keys file.
  /// Inputs: None.
  /// Returns: `Future<File>`.
  /// Side effects: May create the app directory.
  /// Notes: Internal helper used within this file only.
  static Future<File> _file() async {
    final dir = await TranscribeStorage.getAppDir();
    return File(p.join(dir.path, secretsFileName));
  }

  /// Purpose: Read every stored key.
  /// Inputs: None.
  /// Returns: The keys; empty when the file is absent, blank or unreadable.
  /// Side effects: Reads the file.
  /// Notes: An unreadable file reads as empty rather than throwing, unlike the
  /// settings document. The trade is different: an empty settings file that
  /// then gets saved would destroy the user's library, while an empty keys file
  /// costs them re-entering a key, and refusing to start the app over it would
  /// be worse.
  static Future<SecretsFile> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const SecretsFile();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const SecretsFile();
      return SecretsFile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SecretsFile();
    }
  }

  /// Serializes every read-modify-write of the keys file in this process, so a
  /// key typed in Settings cannot be lost to a sync exchange that read the file
  /// a moment earlier (or the other way round).
  static final AtomicWriteQueue _lock = AtomicWriteQueue();

  /// Purpose: Run a read-modify-write of the keys file without interleaving.
  /// Inputs: [action], which should read with [loadForWrite] and write with
  /// [save] or [saveQuiet].
  /// Returns: What [action] returns, or its error.
  /// Side effects: Whatever [action] does.
  /// Notes: [save] and [saveQuiet] stay unlocked primitives, so an action
  /// holding the lock can call them. **Never hold the lock across a network
  /// call**, and never call [withLock] (or [setKey], [deleteAll]) from inside
  /// [action]: the queue is not re-entrant and that would wait on itself
  /// forever.
  static Future<T> withLock<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock.enqueue(() async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// Purpose: Read the keys for a change that will be written back.
  /// Inputs: None.
  /// Returns: The keys; empty when the file is absent or blank, or when its
  /// content could not be parsed.
  /// Side effects: Reads the file; when the content cannot be parsed, renames
  /// it to `transcribe_secrets.json.unreadable-<UTC timestamp>`. Throws a
  /// [FileSystemException] on an I/O error.
  /// Notes: [load] treats "unreadable" and "absent" the same, which is right
  /// for a read but wrong for the read half of a write: the write would then
  /// replace the only copy of whatever keys the damaged file still holds. Here
  /// the damaged bytes are set aside first, so they can be recovered by hand
  /// and the write can go ahead. An I/O error is different — the file may be
  /// fine and merely locked — so it is thrown rather than treated as content.
  /// The UI says so with the `libraryApiKeyUnreadable` message.
  static Future<SecretsFile> loadForWrite() async {
    final file = await _file();
    if (!await file.exists()) return const SecretsFile();
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const SecretsFile();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return SecretsFile.fromJson(decoded);
    } on FileSystemException {
      rethrow;
    } on FormatException {
      // Falls through to set the file aside.
    }
    await setAsideUnreadable(file);
    return const SecretsFile();
  }

  /// Purpose: Write the keys, and let auto-sync know.
  /// Inputs: [secrets].
  /// Returns: A future completing after the write.
  /// Side effects: Atomically writes the file and notifies auto-sync.
  /// Notes: The notification is what makes a key entered here reach another
  /// device: it schedules the debounced sync, whose facade runs the secrets
  /// exchange after the settings module. Use [saveQuiet] for a write that
  /// *came from* a sync, or the two would chase each other.
  static Future<void> save(SecretsFile secrets) async {
    await saveQuiet(secrets);
    AutoSyncService.instance.notifySaved();
  }

  /// Purpose: Write the keys without scheduling a sync.
  /// Inputs: [secrets].
  /// Returns: A future completing after the write.
  /// Side effects: Atomically writes the file.
  /// Notes: For the exchange itself, which has just finished talking to the
  /// server and must not immediately ask to do it again.
  static Future<void> saveQuiet(SecretsFile secrets) async {
    final file = await _file();
    await atomicWriteString(file, encodeSecrets(secrets));
  }

  /// Purpose: Read one source's key.
  /// Inputs: [providerId].
  /// Returns: The key, or null.
  /// Side effects: Reads the file.
  /// Notes: The one call the request builder makes. It reads from disk each
  /// time rather than caching, so a key changed in Settings takes effect on the
  /// next request rather than the next launch — and so a key is not left
  /// sitting in memory longer than a request needs it.
  static Future<String?> keyFor(String providerId) async =>
      (await load()).keyFor(providerId);

  /// Purpose: Set or clear one source's key.
  /// Inputs: [providerId], [apiKey] — null or empty clears it.
  /// Returns: A future completing after the write.
  /// Side effects: Writes the file and notifies auto-sync. Throws when the
  /// file cannot be read for an I/O reason, leaving it untouched.
  /// Notes: Clearing writes a tombstone, so the deletion survives the next
  /// exchange rather than being undone by the other device. Runs under
  /// [withLock], and reads with [loadForWrite]: a damaged file is set aside
  /// rather than overwritten, and a locked one fails instead of being replaced
  /// by a file holding only this key.
  static Future<void> setKey(String providerId, String? apiKey) =>
      withLock(() async {
        final secrets = await loadForWrite();
        await save(secrets.withKey(providerId, apiKey));
      });

  /// Purpose: Delete the file entirely.
  /// Inputs: None.
  /// Returns: A future completing after the deletion.
  /// Side effects: Removes the file.
  /// Notes: For "forget every key on this device". It leaves no tombstones, so
  /// a later sync from another device brings the keys back — which is the
  /// intended behaviour for a device being handed on, and is stated where the
  /// action is offered.
  static Future<void> deleteAll() => withLock(() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  });
}

/// Purpose: Encode the keys file the way it is stored and uploaded.
/// Inputs: [secrets].
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: One encoder for the local write and the upload, so a file that has
/// not changed produces identical bytes and the exchange can skip an upload
/// that would say nothing new.
String encodeSecrets(SecretsFile secrets) =>
    const JsonEncoder.withIndent('  ').convert(secrets.toJson());

/// Which sources currently have a key.
///
/// Watched by the library, so a source shows whether it is ready to use. It
/// exposes ids only — never a key — so a widget cannot accidentally render one.
final configuredProvidersProvider = FutureProvider<Set<String>>((ref) async {
  return (await SecretsStore.load()).configuredProviders;
});
