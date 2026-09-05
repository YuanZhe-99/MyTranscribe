/// Purpose: Exchange the API keys file with the WebDAV server, but only when
/// the address is one a key may safely travel to.
/// Inputs: The WebDAV configuration and this device's trusted hosts.
/// Returns: What happened, for the sync dialog to report.
/// Side effects: Network I/O, and writes the local keys file.
/// Notes: Deliberately outside the shared sync engine. The engine's lock guards
/// three-way merges against a base snapshot; this file is a flat per-source
/// map merged by recency and written with a conditional PUT, so it needs no
/// lock and cannot lose an update. Putting it inside would have meant changing
/// behaviour shared by five apps to serve one. See `doc/en-us/sync.md`.
library;

import 'dart:convert';

import 'package:myapps_data/myapps_data.dart' as shared;

import '../../../app/data_modules.dart';
import '../models/provider_secrets.dart';
import 'secrets_store.dart';
import 'secure_endpoint_policy.dart';

/// What became of the keys during a sync.
enum SecretsSyncStatus {
  /// Keys were exchanged.
  synced,

  /// The address is not one a key may be sent to, so none was.
  skippedInsecure,

  /// Neither side has any keys, so there was nothing to exchange.
  nothingToDo,

  /// The exchange was attempted and failed.
  failed,
}

/// The outcome of one exchange.
class SecretsSyncOutcome {
  /// What happened.
  final SecretsSyncStatus status;

  /// Why, when the address was refused.
  final EndpointReason? reason;

  /// Whether the local file gained anything.
  final bool downloaded;

  /// Whether the remote file was written.
  final bool uploaded;

  /// How many sources have a key locally afterwards.
  final int keyCount;

  /// What went wrong, when something did.
  final String? error;

  /// Purpose: Record an outcome.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SecretsSyncOutcome({
    required this.status,
    this.reason,
    this.downloaded = false,
    this.uploaded = false,
    this.keyCount = 0,
    this.error,
  });
}

/// Exchanges the keys file.
class SecretsSyncService {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the other services' shape.
  SecretsSyncService._();

  /// Purpose: Exchange keys with the server, if the address allows it.
  /// Inputs: The [config], the [trustedHosts] this device accepts, and an
  /// optional [clientFactory] for tests.
  /// Returns: A [SecretsSyncOutcome].
  /// Side effects: One GET and possibly one PUT; may rewrite the local keys
  /// file.
  /// Notes: Called after the settings sync has returned, so a refused address
  /// still syncs everything else. Neither direction happens when the address is
  /// refused: downloading a key over plain HTTP exposes it just as surely as
  /// uploading one.
  static Future<SecretsSyncOutcome> exchange(
    shared.WebDAVConfig config, {
    List<String> trustedHosts = const [],
    shared.WebDavClient Function(shared.WebDAVConfig)? clientFactory,
  }) async {
    final verdict = evaluateSecretsEndpoint(
      config.serverUrl,
      trustedHosts: trustedHosts,
    );
    if (!verdict.allowed) {
      return SecretsSyncOutcome(
        status: SecretsSyncStatus.skippedInsecure,
        reason: verdict.reason,
      );
    }

    final client = (clientFactory ?? shared.WebDavClient.new)(config);
    try {
      final remote = await client.download(secretsFileName);
      if (remote.status == shared.RemoteFileStatus.error) {
        return SecretsSyncOutcome(
          status: SecretsSyncStatus.failed,
          error: remote.error,
        );
      }

      final local = await SecretsStore.load();
      final theirs = _parse(remote);
      if (local.keys.isEmpty && theirs.keys.isEmpty) {
        return const SecretsSyncOutcome(status: SecretsSyncStatus.nothingToDo);
      }

      final merged = mergeSecrets(local, theirs);
      final changedLocally = !_same(local, merged);
      if (changedLocally) await SecretsStore.saveQuiet(merged);

      final body = const JsonEncoder.withIndent('  ').convert(merged.toJson());
      final changedRemotely = !_same(theirs, merged);
      if (!changedRemotely) {
        return SecretsSyncOutcome(
          status: SecretsSyncStatus.synced,
          downloaded: changedLocally,
          keyCount: merged.keys.length,
        );
      }

      // Conditional, so two devices writing at once cannot silently lose one
      // side's key: a 412 means somebody else wrote first, and the answer is to
      // merge with what they wrote rather than overwrite it.
      var result = await client.upload(
        secretsFileName,
        body,
        ifMatchEtag: shared.WebDavClient.strongEtag(remote.etag),
        ifNoneMatchAll: remote.status == shared.RemoteFileStatus.notFound,
      );

      if (result.is412) {
        final again = await client.download(secretsFileName);
        final rebased = mergeSecrets(merged, _parse(again));
        await SecretsStore.saveQuiet(rebased);
        result = await client.upload(
          secretsFileName,
          const JsonEncoder.withIndent('  ').convert(rebased.toJson()),
          ifMatchEtag: shared.WebDavClient.strongEtag(again.etag),
        );
        if (result.error != null) {
          return SecretsSyncOutcome(
            status: SecretsSyncStatus.failed,
            error: result.error,
            downloaded: true,
            keyCount: rebased.keys.length,
          );
        }
        return SecretsSyncOutcome(
          status: SecretsSyncStatus.synced,
          downloaded: true,
          uploaded: true,
          keyCount: rebased.keys.length,
        );
      }

      if (result.error != null) {
        return SecretsSyncOutcome(
          status: SecretsSyncStatus.failed,
          error: result.error,
          downloaded: changedLocally,
          keyCount: merged.keys.length,
        );
      }

      return SecretsSyncOutcome(
        status: SecretsSyncStatus.synced,
        downloaded: changedLocally,
        uploaded: true,
        keyCount: merged.keys.length,
      );
    } catch (error) {
      return SecretsSyncOutcome(
        status: SecretsSyncStatus.failed,
        error: '$error',
      );
    }
  }

  /// Purpose: Read the remote keys file.
  /// Inputs: The [remote] response.
  /// Returns: A [SecretsFile]; an empty one when there is nothing readable.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A remote file that will
  /// not parse is treated as absent rather than as an error: the local keys are
  /// still worth uploading, and refusing to sync because a stray file is
  /// malformed would leave the user stuck with no way to fix it from the app.
  static SecretsFile _parse(shared.RemoteFile remote) {
    if (remote.status != shared.RemoteFileStatus.found) {
      return const SecretsFile();
    }
    try {
      final decoded = jsonDecode(remote.content ?? '{}');
      if (decoded is! Map<String, dynamic>) return const SecretsFile();
      return SecretsFile.fromJson(decoded);
    } catch (_) {
      return const SecretsFile();
    }
  }

  /// Purpose: Compare two keys files by what they say.
  /// Inputs: [a] and [b].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Compared by content so
  /// an exchange that changed nothing does not write a file or make a request,
  /// which is the normal case on every sync after the first.
  static bool _same(SecretsFile a, SecretsFile b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());
}
