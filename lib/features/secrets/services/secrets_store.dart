import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapps_data/myapps_data.dart';

import '../../../app/data_modules.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../models/provider_secrets.dart';

/// Application namespace and byte-compatible facade over the shared secret store.
class SecretsStore {
  /// Purpose: Prevent construction. Inputs: None. Returns: None.
  /// Side effects: None. Notes: Static application facade.
  SecretsStore._();

  static final sharedStore = SecretStore(
    storage: const TranscribeStorageAdapter(),
    fileName: secretsFileName,
    namespaces: const {'provider'},
    onSaved: () => AutoSyncService.instance.notifySaved(),
  );

  /// Purpose: Read keys. Inputs: None. Returns: Secrets.
  /// Side effects: Reads disk. Notes: Read failures appear empty to consumers.
  static Future<SecretsFile> load() async =>
      SecretsFile.fromJson((await sharedStore.load()).toJson());

  /// Purpose: Serialize a mutation. Inputs: action. Returns: Result.
  /// Side effects: Queues action. Notes: Never hold across network calls.
  static Future<T> withLock<T>(Future<T> Function() action) =>
      sharedStore.withLock(action);

  /// Purpose: Read before mutation. Inputs: None. Returns: Secrets.
  /// Side effects: Sets aside corrupt content. Notes: I/O failures propagate.
  static Future<SecretsFile> loadForWrite() async =>
      SecretsFile.fromJson((await sharedStore.loadForWrite()).toJson());

  /// Purpose: Save and notify sync. Inputs: secrets. Returns: Completion.
  /// Side effects: Writes disk and schedules sync. Notes: Preserve unknown fields.
  static Future<void> save(SecretsFile secrets) =>
      sharedStore.save(SecretsDocument.fromJson(secrets.toJson()));

  /// Purpose: Save without notification. Inputs: secrets. Returns: Completion.
  /// Side effects: Writes disk. Notes: Used after remote exchange.
  static Future<void> saveQuiet(SecretsFile secrets) =>
      sharedStore.saveQuiet(SecretsDocument.fromJson(secrets.toJson()));

  /// Purpose: Read one key. Inputs: providerId. Returns: Key.
  /// Side effects: Reads disk. Notes: Restricted to provider namespace.
  static Future<String?> keyFor(String providerId) =>
      sharedStore.keyFor(providerId);

  /// Purpose: Set or clear a key. Inputs: providerId, apiKey. Returns: Completion.
  /// Side effects: Writes and schedules sync. Notes: Clearing writes a tombstone.
  static Future<void> setKey(String providerId, String? apiKey) =>
      sharedStore.setKey(providerId, apiKey);

  /// Purpose: Forget all local keys. Inputs: None. Returns: Completion.
  /// Side effects: Removes file. Notes: No remote tombstones.
  static Future<void> deleteAll() => sharedStore.deleteAll();
}

/// Purpose: Encode compatible secret bytes. Inputs: secrets. Returns: JSON.
/// Side effects: None. Notes: Same pretty-printing as existing releases.
String encodeSecrets(SecretsFile secrets) =>
    const JsonEncoder.withIndent('  ').convert(secrets.toJson());

/// Provider IDs with usable keys; widgets never receive key contents.
final configuredProvidersProvider = FutureProvider<Set<String>>(
  (ref) => SecretsStore.sharedStore.configuredIds(),
);
