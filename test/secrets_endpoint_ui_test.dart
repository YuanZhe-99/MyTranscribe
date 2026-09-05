/// Purpose: Test that the WebDAV page tells the user, before they sync,
/// whether their API keys will travel to the address they typed.
/// Inputs: None; the section is pumped on its own.
/// Returns: None.
/// Side effects: Pumps widget trees and writes temporary files.
/// Notes: Driven in Simplified Chinese for the reason given in
/// `test/shell_nav_ui_test.dart`. The verdict itself is tested exhaustively in
/// `test/secure_endpoint_policy_test.dart`; what this file checks is that the
/// answer reaches the screen, with the reason, while the address is still being
/// typed.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/secrets/services/secure_endpoint_policy.dart';
import 'package:my_transcribe/features/secrets/views/secrets_endpoint_section.dart';
import 'package:my_transcribe/l10n/app_localizations.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A path provider that answers with one temporary directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_banner_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await TranscribeStorage.setStoragePath(null);
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Pump the section for one address.
  /// Inputs: `tester`, the [url] and how many [keys] this device holds.
  /// Returns: None.
  /// Side effects: Pumps a tree.
  /// Notes: Internal helper used within this file only. The trusted-host list
  /// is read from disk, which a widget test cannot await, so these cases all
  /// use an empty list — the trusted path is covered in the policy tests and
  /// the exchange tests.
  Future<void> pumpSection(
    WidgetTester tester,
    String url, {
    int keys = 2,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecretsEndpointSection(serverUrl: url, keyCount: keys),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the banner', () {
    testWidgets('says keys will sync over HTTPS, and why', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'https://cloud.example.com/dav');

      expect(find.text(l10n.secretsBannerAllowed), findsOneWidget);
      expect(
        find.text(endpointReasonText(l10n, EndpointReason.https)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('says keys stay here over plain HTTP, and why', (tester) async {
      // And it says the rest still syncs, so the user does not conclude that
      // the whole thing is broken.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'http://dav.example.com/dav');

      expect(find.text(l10n.secretsBannerDenied), findsOneWidget);
      expect(
        find.text(endpointReasonText(l10n, EndpointReason.deniedPublicHttp)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts a Tailscale address over plain HTTP', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'http://nas.tail694d4.ts.net/dav');

      expect(find.text(l10n.secretsBannerAllowed), findsOneWidget);
      expect(
        find.text(endpointReasonText(l10n, EndpointReason.tailnet)),
        findsOneWidget,
      );
    });

    testWidgets('accepts a LAN address over plain HTTP', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'http://192.168.1.20:5005/dav');

      expect(find.text(l10n.secretsBannerAllowed), findsOneWidget);
      expect(
        find.text(endpointReasonText(l10n, EndpointReason.privateIpv4)),
        findsOneWidget,
      );
    });

    testWidgets('shows a verdict for an empty field too', (tester) async {
      // Not a blank space where a warning should be.
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, '');

      expect(find.text(l10n.secretsBannerDenied), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says how many keys this device holds', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'https://cloud.example.com/dav', keys: 3);

      expect(find.text(l10n.secretsKeyCount(3)), findsOneWidget);
    });

    testWidgets('offers the trusted-host list', (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      await pumpSection(tester, 'http://dav.example.com/dav');

      expect(find.text(l10n.secretsTrustedHosts), findsOneWidget);
      await tester.tap(find.text(l10n.secretsTrustedHosts));
      await tester.pumpAndSettle();
      expect(find.text(l10n.secretsTrustedHostAdd), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
