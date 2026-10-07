import 'package:flutter/material.dart';
import 'package:myapps_data/myapps_data.dart';

import '../../app/data_modules.dart';
import '../../l10n/app_localizations.dart';

/// Device-local versioned acknowledgement of this application's sync inventory.
class WebDavPrivacy {
  static const noticeVersion = 1;
  static final store = WebDavPrivacyAcknowledgementStore.storageConfig(
    const TranscribeStorageAdapter(),
  );

  /// Purpose: Gate network access. Inputs: None. Returns: Consent.
  /// Side effects: Reads device preferences. Notes: Fails closed on read errors.
  static Future<bool> allowed() async =>
      !needsAcknowledgement(await store.load(), noticeVersion);

  /// Purpose: Explain sync readiness. Inputs: configured. Returns: Status.
  /// Side effects: Reads consent. Notes: Never removes saved configuration.
  static Future<WebDavPrivacyStatus> status(bool configured) async =>
      webDavPrivacyStatus(
        syncConfigured: configured,
        stored: await store.load(),
        currentVersion: noticeVersion,
      );

  /// Purpose: Ask before sync or connection tests. Inputs: context, config.
  /// Returns: True on acknowledgement. Side effects: Dialog and local write.
  /// Notes: Refusal writes nothing; audio and keys have separate conditions.
  static Future<bool> ensure(BuildContext context, WebDAVConfig config) async {
    if (await allowed()) return true;
    if (!context.mounted) return false;
    final l = AppLocalizations.of(context)!;
    final verdict = evaluateEndpointSecurity(
      Uri.tryParse(config.serverUrl) ?? Uri(),
    );
    final accepted = await showMyAppsWebDavPrivacyNotice(
      context,
      labels: MyAppsWebDavPrivacyNoticeLabels(
        title: l.webdavPrivacyTitle,
        intro: l.webdavPrivacyIntro,
        modulesHeading: l.webdavPrivacyData,
        optionalContentHeading: l.webdavPrivacyOptional,
        destinationHeading: l.webdavPrivacyDestination,
        encryptionHeading: l.webdavPrivacyEncryption,
        transportHeading: l.webdavPrivacyTransport,
        transportDescription: (_) => config.serverUrl.startsWith('https:')
            ? l.webdavPrivacyHttps
            : l.webdavPrivacyHttp,
        insecureHttpWarning: l.webdavPrivacyHttp,
        noThirdPartiesStatement: l.webdavPrivacyNoThirdParties,
        confirmLabel: l.webdavPrivacyConfirm,
        declineLabel: l.cancel,
      ),
      modules: [MyAppsWebDavPrivacyItem(title: l.webdavPrivacyInventory)],
      optionalContent: [
        MyAppsWebDavPrivacyItem(title: l.webdavPrivacyAudio),
        MyAppsWebDavPrivacyItem(title: l.webdavPrivacySecrets),
      ],
      destinationHost: Uri.tryParse(config.serverUrl)?.host ?? config.serverUrl,
      encryptionStatement: l.webdavPrivacyPlaintext,
      verdict: verdict,
    );
    if (!accepted) return false;
    await store.acknowledge(noticeVersion);
    return true;
  }
}
