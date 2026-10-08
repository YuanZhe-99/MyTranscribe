import 'package:flutter/material.dart';
import 'package:myapps_data/myapps_data.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart';
import 'package:myapps_ai_online_ui/myapps_ai_online_ui.dart';

import '../../../app/data_modules.dart';
import '../../../l10n/app_localizations.dart';
import '../models/provider_config.dart';
import '../views/online_sources_page.dart';

/// Versioned per-device permission to send audio to each provider host.
class OnlinePrivacy {
  static const version = 1;

  /// Purpose: Locate host consent. Inputs: provider. Returns: Store.
  /// Side effects: None. Notes: Scheme and host changes require new consent.
  static WebDavPrivacyAcknowledgementStore _store(ProviderConfig provider) {
    final uri = Uri.tryParse(provider.baseUrl);
    return WebDavPrivacyAcknowledgementStore.storageConfig(
      const TranscribeStorageAdapter(),
      key:
          'onlineTranscriptionPrivacy:${provider.id}:${uri != null && uri.hasAuthority && uri.hasScheme ? uri.origin : provider.baseUrl}',
    );
  }

  /// Purpose: Gate audio requests. Inputs: provider. Returns: Consent.
  /// Side effects: Reads local preferences. Notes: No network before consent.
  static Future<bool> allowed(ProviderConfig provider) async =>
      !needsAcknowledgement(await _store(provider).load(), version);

  /// Purpose: Ask before online audio upload. Inputs: context, provider.
  /// Returns: Consent. Side effects: Dialog and local acknowledgement.
  /// Notes: Host changes invalidate prior consent; no synced acknowledgement.
  static Future<bool> ensure(
    BuildContext context,
    ProviderConfig provider,
  ) async {
    final uri = Uri.tryParse(provider.baseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      return false;
    }
    final host = Uri.tryParse(provider.baseUrl)?.host ?? provider.baseUrl;
    final acknowledgement = _store(provider);
    if (!needsAcknowledgement(await acknowledgement.load(), version)) {
      return true;
    }
    if (!context.mounted) return false;
    final l = AppLocalizations.of(context)!;
    final accepted = await showOnlinePrivacyNoticeDialog(
      context,
      notice: OnlinePrivacyNotice(
        version: version,
        recipientHost: host,
        providerName: provider.name,
        sent: [
          OnlineDataItem(
            OnlineDataCategory.audio,
            description: l.onlinePrivacyBody(host),
          ),
        ],
      ),
      labels: transcribeOnlineLabels(l),
    );
    if (accepted) await acknowledgement.acknowledge(version);
    return accepted;
  }
}
