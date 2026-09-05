/// Purpose: The API keys file, and the rule for merging two copies of it.
/// Inputs: Parsed `transcribe_secrets.json` content.
/// Returns: `ProviderSecret` and `SecretsFile` value types.
/// Side effects: None.
/// Notes: **This file is never a data module.** The sync, backup and ZIP
/// engines only touch the file names in the registry in
/// `lib/app/data_modules.dart`, and this one is not there, which is what keeps
/// keys out of every backup bundle and every export — structurally, not by a
/// filter somebody has to remember. When it does travel, it is exchanged by
/// `SecretsSyncService`, and only to an endpoint that qualifies. See
/// `doc/en-us/features/secure-secrets-sync.md`.
library;

/// The format version written into the file.
///
/// Present so a future change to the shape can be recognised rather than
/// guessed at. Nothing reads it yet beyond passing it through.
const secretsFileVersion = 1;

/// One source's key, and when it was last set.
class ProviderSecret {
  /// The key itself, or null when it was deleted.
  ///
  /// **Null is a tombstone, not an absence.** Without one, deleting a key on
  /// this device and syncing would simply let the other device's copy come
  /// back, which is the opposite of what deleting a credential should do.
  final String? apiKey;

  /// When it was last set or cleared, in UTC.
  ///
  /// The whole merge rests on this: two devices hold independent values for one
  /// source, and the later edit wins. A local-time value read on a device in
  /// another zone would resolve the wrong way.
  final DateTime updatedAt;

  /// Purpose: Create a stored key.
  /// Inputs: [apiKey] (null for a tombstone), [updatedAt].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const ProviderSecret({required this.apiKey, required this.updatedAt});

  /// Purpose: Report whether a usable key is present.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: A tombstone and a blank string both read as absent.
  bool get hasKey => apiKey != null && apiKey!.isNotEmpty;

  /// Purpose: Parse one entry.
  /// Inputs: [json].
  /// Returns: A [ProviderSecret].
  /// Side effects: None.
  /// Notes: An unreadable timestamp falls back to the epoch, so a damaged entry
  /// loses to any real one rather than winning every merge.
  factory ProviderSecret.fromJson(Map<String, dynamic> json) {
    final key = json['apiKey'];
    return ProviderSecret(
      apiKey: key is String && key.isNotEmpty ? key : null,
      updatedAt:
          DateTime.tryParse('${json['updatedAt']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// Purpose: Serialize one entry.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: A tombstone is written as an explicit null, because the entry has
  /// to exist for the deletion to propagate.
  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

/// Every key this device holds.
class SecretsFile {
  /// Keys by source record id, so a key follows its source.
  final Map<String, ProviderSecret> keys;

  /// Top-level fields written by a build this one does not know about.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a secrets file.
  /// Inputs: [keys], [extraJson].
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SecretsFile({this.keys = const {}, this.extraJson = const {}});

  /// Purpose: Parse the file.
  /// Inputs: [json].
  /// Returns: A [SecretsFile].
  /// Side effects: None.
  /// Notes: A `keys` value of the wrong type reads as empty rather than
  /// throwing. Failing to parse must not lock the user out of the app; it makes
  /// them re-enter a key, which is recoverable.
  factory SecretsFile.fromJson(Map<String, dynamic> json) {
    final raw = json['keys'];
    return SecretsFile(
      keys: raw is! Map
          ? const {}
          : {
              for (final entry in raw.entries)
                if (entry.key is String && entry.value is Map<String, dynamic>)
                  entry.key as String: ProviderSecret.fromJson(
                    entry.value as Map<String, dynamic>,
                  ),
            },
      extraJson: {
        for (final e in json.entries)
          if (e.key != 'keys' && e.key != 'version') e.key: e.value,
      },
    );
  }

  /// Purpose: Serialize the file.
  /// Inputs: None.
  /// Returns: A JSON-compatible map.
  /// Side effects: None.
  /// Notes: Keys are written in sorted order so two devices holding the same
  /// content produce the same bytes, which is what lets the exchange skip an
  /// upload that would change nothing.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'version': secretsFileVersion,
    'keys': {
      for (final id in keys.keys.toList()..sort()) id: keys[id]!.toJson(),
    },
  };

  /// Purpose: Read one source's key.
  /// Inputs: [providerId].
  /// Returns: The key, or null when absent or deleted.
  /// Side effects: None.
  /// Notes: None.
  String? keyFor(String providerId) {
    final secret = keys[providerId];
    return secret != null && secret.hasKey ? secret.apiKey : null;
  }

  /// Purpose: Set or clear one source's key.
  /// Inputs: [providerId], [apiKey] (null or empty clears it), optional [now].
  /// Returns: A new [SecretsFile].
  /// Side effects: None.
  /// Notes: Clearing writes a tombstone rather than removing the entry, so the
  /// deletion survives the next exchange instead of being undone by the other
  /// device's copy.
  SecretsFile withKey(String providerId, String? apiKey, {DateTime? now}) {
    final trimmed = apiKey?.trim();
    return SecretsFile(
      keys: {
        ...keys,
        providerId: ProviderSecret(
          apiKey: trimmed == null || trimmed.isEmpty ? null : trimmed,
          updatedAt: (now ?? DateTime.now()).toUtc(),
        ),
      },
      extraJson: extraJson,
    );
  }

  /// Purpose: List the sources that currently have a key.
  /// Inputs: None.
  /// Returns: Their record ids.
  /// Side effects: None.
  /// Notes: For the settings row that says how many are configured, without
  /// exposing any key.
  Set<String> get configuredProviders => {
    for (final entry in keys.entries)
      if (entry.value.hasKey) entry.key,
  };
}

/// Purpose: Merge two copies of the keys file, per source, by recency.
/// Inputs: [local], [remote].
/// Returns: The merged file.
/// Side effects: None.
/// Notes: Last writer wins, per key, with tombstones taking part — so clearing
/// a key on one device clears it everywhere rather than being resurrected.
///
/// There is no three-way merge and no base snapshot here, and that is a
/// deliberate difference from how the settings document is merged. A key is one
/// independent value per source, not a structure two people can edit different
/// parts of; there is nothing to reconcile beyond "which is newer". It is also
/// what makes the exchange safe to run outside the sync lock: a concurrent
/// write becomes a rejected conditional upload and a re-merge, not a lost
/// update.
///
/// A tie goes to the remote copy. Ties are almost always the same value written
/// twice, and picking one side consistently means every device converges rather
/// than each preferring itself forever.
SecretsFile mergeSecrets(SecretsFile local, SecretsFile remote) {
  final merged = <String, ProviderSecret>{};
  for (final id in {...local.keys.keys, ...remote.keys.keys}) {
    final mine = local.keys[id];
    final theirs = remote.keys[id];
    if (mine == null) {
      merged[id] = theirs!;
    } else if (theirs == null) {
      merged[id] = mine;
    } else {
      merged[id] = mine.updatedAt.isAfter(theirs.updatedAt) ? mine : theirs;
    }
  }
  return SecretsFile(
    keys: merged,
    extraJson: {...remote.extraJson, ...local.extraJson},
  );
}
