import 'package:myapps_data/myapps_data.dart' as shared;

import 'secrets_store.dart';

enum SecretsSyncStatus { synced, skippedInsecure, nothingToDo, failed }

class SecretsSyncOutcome {
  final SecretsSyncStatus status;
  final shared.EndpointReason? reason;
  final bool downloaded;
  final bool uploaded;
  final int keyCount;
  final String? error;

  /// Purpose: Describe an exchange. Inputs: outcome fields. Returns: Outcome.
  /// Side effects: None. Notes: Key count excludes tombstones.
  const SecretsSyncOutcome({
    required this.status,
    this.reason,
    this.downloaded = false,
    this.uploaded = false,
    this.keyCount = 0,
    this.error,
  });
}

/// Application namespace over shared conditional secret exchange.
class SecretsSyncService {
  /// Purpose: Prevent construction. Inputs: None. Returns: None.
  /// Side effects: None. Notes: Static facade.
  SecretsSyncService._();

  /// Purpose: Exchange keys. Inputs: config, trustedHosts, clientFactory, mode.
  /// Returns: Outcome. Side effects: HTTP and local writes.
  /// Notes: Refused endpoints make no request; force modes are one-way.
  static Future<SecretsSyncOutcome> exchange(
    shared.WebDAVConfig config, {
    List<String> trustedHosts = const [],
    shared.WebDavClient Function(shared.WebDAVConfig)? clientFactory,
    shared.SecretExchangeMode mode = shared.SecretExchangeMode.sync,
  }) async {
    final result = await shared.SecretExchange(
      store: SecretsStore.sharedStore,
      clientFactory: clientFactory,
    ).exchange(config, trustedHosts: trustedHosts, mode: mode);
    return SecretsSyncOutcome(
      status: SecretsSyncStatus.values.byName(result.status.name),
      reason: result.reason,
      downloaded: result.downloaded,
      uploaded: result.uploaded,
      keyCount: result.keyCount,
      error: result.error,
    );
  }
}
