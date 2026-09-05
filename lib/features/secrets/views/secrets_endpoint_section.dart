/// Purpose: Tell the user, on the WebDAV page, whether their API keys will
/// travel to the server they have typed in, and let them trust a host that
/// otherwise would not qualify.
/// Inputs: The server address as it is being typed, and this device's trusted
/// hosts.
/// Returns: A banner, a key count, and the trusted-host editor.
/// Side effects: Reads and writes the device's trusted-host list.
/// Notes: The verdict updates as the address is typed, before anything is
/// saved or synced, because the moment to learn that a key will not travel is
/// while choosing the address — not after a sync that quietly left it behind.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../services/secure_endpoint_policy.dart';

/// Purpose: Put a policy reason into words for the user.
/// Inputs: [l10n] and the [reason].
/// Returns: One sentence.
/// Side effects: None.
/// Notes: Every reason gets its own sentence rather than a generic "not
/// allowed": the user can only act on the refusal if they know which rule it
/// was, and half of them are fixed by typing `https` instead of `http`.
String endpointReasonText(AppLocalizations l10n, EndpointReason reason) =>
    switch (reason) {
      EndpointReason.https => l10n.secretsReasonHttps,
      EndpointReason.loopback => l10n.secretsReasonLoopback,
      EndpointReason.privateIpv4 => l10n.secretsReasonPrivateIpv4,
      EndpointReason.linkLocal => l10n.secretsReasonLinkLocal,
      EndpointReason.cgnat => l10n.secretsReasonCgnat,
      EndpointReason.privateIpv6 => l10n.secretsReasonPrivateIpv6,
      EndpointReason.tailnet => l10n.secretsReasonTailnet,
      EndpointReason.zerotier => l10n.secretsReasonZerotier,
      EndpointReason.mdns => l10n.secretsReasonMdns,
      EndpointReason.singleLabelHost => l10n.secretsReasonSingleLabel,
      EndpointReason.trustedHost => l10n.secretsReasonTrusted,
      EndpointReason.deniedPublicHttp => l10n.secretsReasonPublicHttp,
      EndpointReason.deniedScheme => l10n.secretsReasonScheme,
      EndpointReason.deniedUnparseable => l10n.secretsReasonUnparseable,
    };

class SecretsEndpointSection extends StatefulWidget {
  /// The server address as it currently stands in the field.
  final String serverUrl;

  /// How many sources have a key on this device.
  final int keyCount;

  /// Purpose: Create the section.
  /// Inputs: [serverUrl], [keyCount].
  /// Returns: A new instance.
  /// Side effects: None.
  /// Notes: None.
  const SecretsEndpointSection({
    super.key,
    required this.serverUrl,
    required this.keyCount,
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<SecretsEndpointSection> createState() => _SecretsEndpointSectionState();
}

class _SecretsEndpointSectionState extends State<SecretsEndpointSection> {
  List<String> _trusted = const [];

  /// Purpose: Read this device's trusted hosts.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Purpose: Load the trusted hosts.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the device preferences.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final hosts = await TranscribeStorage.getSecretsTrustedHosts();
    if (mounted) setState(() => _trusted = hosts);
  }

  /// Purpose: Save the trusted hosts.
  /// Inputs: [hosts].
  /// Returns: None.
  /// Side effects: Writes the device preferences.
  /// Notes: Internal helper used within this file only. Device-local on
  /// purpose: trust is about the network path this device takes to the server,
  /// and one device's decision must not start key uploads on another.
  Future<void> _save(List<String> hosts) async {
    setState(() => _trusted = hosts);
    await TranscribeStorage.setSecretsTrustedHosts(hosts);
  }

  /// Purpose: Build the section.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: None.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final verdict = evaluateSecretsEndpoint(
      widget.serverUrl,
      trustedHosts: _trusted,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.secretsSectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          color: verdict.allowed
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  verdict.allowed ? Icons.lock_outline : Icons.lock_open,
                  size: 20,
                  color: verdict.allowed
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        verdict.allowed
                            ? l10n.secretsBannerAllowed
                            : l10n.secretsBannerDenied,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: verdict.allowed
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endpointReasonText(l10n, verdict.reason),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: verdict.allowed
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.secretsKeyCount(widget.keyCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: verdict.allowed
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(l10n.secretsTrustedHosts),
          subtitle: Text('${_trusted.length}'),
          children: [
            Text(
              l10n.secretsTrustedHostsHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final host in _trusted)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(host),
                trailing: IconButton(
                  tooltip: l10n.commonRemove,
                  icon: const Icon(Icons.close),
                  onPressed: () => _save([
                    for (final h in _trusted)
                      if (h != host) h,
                  ]),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _add(l10n),
                icon: const Icon(Icons.add),
                label: Text(l10n.secretsTrustedHostAdd),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Purpose: Ask for a host to trust.
  /// Inputs: [l10n].
  /// Returns: None.
  /// Side effects: Opens a dialog and saves.
  /// Notes: Internal helper used within this file only. The entry is validated
  /// as a host, not as a URL: somebody who pastes `http://nas/dav` here has
  /// misunderstood what the list is, and accepting it would trust nothing.
  Future<void> _add(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.secretsTrustedHostAdd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.secretsTrustedHostHint),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.commonAdd),
          ),
        ],
      ),
    );
    controller.dispose();

    final entry = host?.trim().toLowerCase() ?? '';
    if (entry.isEmpty) return;
    if (!_isHost(entry)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.secretsTrustedHostInvalid)));
      return;
    }
    if (_trusted.contains(entry)) return;
    await _save([..._trusted, entry]);
  }

  /// Purpose: Check that an entry is a host or a wildcard, not a URL.
  /// Inputs: [entry].
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool _isHost(String entry) =>
      RegExp(
        r'^(\*\.)?[a-z0-9]([a-z0-9-]*[a-z0-9])?'
        r'(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$',
      ).hasMatch(entry) &&
      !entry.contains('/') &&
      !entry.contains(':');
}
