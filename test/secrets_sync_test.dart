/// Purpose: Test that API keys travel to a WebDAV server only over an address
/// they may safely travel to, and that two devices cannot lose one another's.
/// Inputs: None; a fake WebDAV store and a temporary directory stand in.
/// Returns: None.
/// Side effects: Writes temporary files.
/// Notes: The rule the user asked for is the reason this exists: settings sync
/// anywhere, keys only over HTTPS or an address that cannot leave their own
/// network. The test that matters most is the negative one — that a refused
/// address makes **no request at all**, in either direction.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/secrets/models/provider_secrets.dart';
import 'package:my_transcribe/features/secrets/services/secrets_store.dart';
import 'package:my_transcribe/features/secrets/services/secrets_sync_service.dart';
import 'package:my_transcribe/features/secrets/services/secure_endpoint_policy.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'golden/fake_webdav_store.dart';

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

/// A store that can misbehave at chosen moments, wrapped around the fake.
class _HookedStore extends http.BaseClient {
  _HookedStore(this.inner);

  final FakeWebDavStore inner;

  /// Runs once, just before the first PUT reaches the store.
  Future<void> Function()? beforePut;

  /// Set to make every GET after the first fail at the transport (the client
  /// retries a dropped connection, so failing one attempt would prove nothing).
  bool failLaterGets = false;

  int _gets = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') {
      _gets++;
      if (failLaterGets && _gets >= 2) {
        throw http.ClientException('connection dropped');
      }
    }
    if (request.method == 'PUT' && beforePut != null) {
      final hook = beforePut!;
      beforePut = null;
      await hook();
    }
    return inner.send(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late FakeWebDavStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_secrets_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await TranscribeStorage.setStoragePath(null);
    store = FakeWebDavStore();
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Build a configuration pointing at one address.
  /// Inputs: The [url].
  /// Returns: A [shared.WebDAVConfig].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  shared.WebDAVConfig config(String url) => shared.WebDAVConfig(
    serverUrl: url,
    username: 'user',
    password: 'pass',
    remotePath: transcribeDefaultRemotePath,
  );

  /// Purpose: Run the exchange against the fake store.
  /// Inputs: The [url] and the [trusted] hosts.
  /// Returns: The outcome.
  /// Side effects: Network calls into the fake, and local file writes.
  /// Notes: Internal helper used within this file only.
  Future<SecretsSyncOutcome> exchange(
    String url, {
    List<String> trusted = const [],
  }) => SecretsSyncService.exchange(
    config(url),
    trustedHosts: trusted,
    clientFactory: (c) => shared.WebDavClient(c, httpClient: store),
  );

  /// Purpose: Put a key on the remote side.
  /// Inputs: The [providerId], the [key] and when it was [at] set.
  /// Returns: None.
  /// Side effects: Replaces the fake store's contents.
  /// Notes: Internal helper used within this file only.
  void remoteHas(String providerId, String? key, DateTime at) {
    store.content = jsonEncode(
      SecretsFile(
        keys: {providerId: ProviderSecret(apiKey: key, updatedAt: at)},
      ).toJson(),
    );
  }

  group('an address a key must not travel to', () {
    test('is refused, and nothing is sent or fetched', () async {
      // Not even the download: reading a key over plain HTTP exposes it just
      // as surely as writing one.
      await SecretsStore.setKey('provider:openai', 'sk-secret');

      final outcome = await exchange('http://dav.example.com/remote.php');

      expect(outcome.status, SecretsSyncStatus.skippedInsecure);
      expect(outcome.reason, EndpointReason.deniedPublicHttp);
      expect(store.requests, isEmpty, reason: 'no request may be made at all');
    });

    test('leaves the local key exactly as it was', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      await exchange('http://dav.example.com/remote.php');
      expect(await SecretsStore.keyFor('provider:openai'), 'sk-secret');
    });

    test('says which rule refused it, so the page can explain', () async {
      expect(
        (await exchange('ftp://dav.example.com')).reason,
        EndpointReason.deniedScheme,
      );
      expect((await exchange('   ')).reason, EndpointReason.deniedUnparseable);
    });
  });

  group('an address a key may travel to', () {
    test('uploads a key the server does not have', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(outcome.uploaded, isTrue);
      expect(store.writes, hasLength(1));
      expect(store.writes.single, contains('sk-secret'));
    });

    test('creates the file only when it is absent', () async {
      // Otherwise two devices starting at once would overwrite each other's
      // first key rather than merging them.
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      await exchange('https://cloud.example.com/dav');
      expect(store.ifNoneMatch.single, '*');
    });

    test('takes a key this device does not have', () async {
      remoteHas('provider:openrouter', 'sk-remote', DateTime.utc(2026, 9, 5));

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(outcome.downloaded, isTrue);
      expect(await SecretsStore.keyFor('provider:openrouter'), 'sk-remote');
    });

    test('keeps the newer of two keys for the same source', () async {
      await SecretsStore.setKey('provider:openai', 'sk-old');
      // Written a day later on the other device.
      remoteHas(
        'provider:openai',
        'sk-new',
        DateTime.now().toUtc().add(const Duration(days: 1)),
      );

      await exchange('https://cloud.example.com/dav');

      expect(await SecretsStore.keyFor('provider:openai'), 'sk-new');
    });

    test('a deletion travels too, rather than coming back', () async {
      // A key cleared on one device must not be resurrected by the other; the
      // tombstone is what carries the deletion.
      await SecretsStore.setKey('provider:openai', 'sk-old');
      remoteHas(
        'provider:openai',
        null,
        DateTime.now().toUtc().add(const Duration(days: 1)),
      );

      await exchange('https://cloud.example.com/dav');

      expect(await SecretsStore.keyFor('provider:openai'), isNull);
    });

    test('sends nothing when both sides already agree', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      await exchange('https://cloud.example.com/dav');
      final writesAfterFirst = store.writes.length;

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(outcome.uploaded, isFalse);
      expect(store.writes, hasLength(writesAfterFirst));
    });

    test('does nothing at all when nobody has a key', () async {
      final outcome = await exchange('https://cloud.example.com/dav');
      expect(outcome.status, SecretsSyncStatus.nothingToDo);
      expect(store.writes, isEmpty);
    });

    test('a LAN address over plain HTTP is allowed', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      final outcome = await exchange('http://192.168.1.20:5005/dav');
      expect(outcome.status, SecretsSyncStatus.synced);
    });

    test('a Tailscale address over plain HTTP is allowed', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      final outcome = await exchange('http://nas.tailnet-example.ts.net/dav');
      expect(outcome.status, SecretsSyncStatus.synced);
    });

    test('a trusted host over plain HTTP is allowed', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      final outcome = await exchange(
        'http://dav.example.com/dav',
        trusted: ['dav.example.com'],
      );
      expect(outcome.status, SecretsSyncStatus.synced);
    });
  });

  group('two devices writing at once', () {
    test('the loser re-reads and merges rather than overwriting', () async {
      // The other device wrote between this one's read and its write. Its key
      // must survive.
      await SecretsStore.setKey('provider:openai', 'sk-mine');
      store.refuseNextPut = true;
      store.content = jsonEncode(
        SecretsFile(
          keys: {
            'provider:openrouter': ProviderSecret(
              apiKey: 'sk-theirs',
              updatedAt: DateTime.now().toUtc(),
            ),
          },
        ).toJson(),
      );

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(await SecretsStore.keyFor('provider:openai'), 'sk-mine');
      expect(await SecretsStore.keyFor('provider:openrouter'), 'sk-theirs');
      expect(store.content, contains('sk-mine'));
      expect(store.content, contains('sk-theirs'));
    });

    test('sends the entity tag it read, so the server can refuse', () async {
      await SecretsStore.setKey('provider:openai', 'sk-mine');
      remoteHas('provider:openrouter', 'sk-theirs', DateTime.utc(2026, 1, 1));

      await exchange('https://cloud.example.com/dav');

      expect(store.ifMatch.single, '"v1"');
    });
  });

  group('when the server is unreachable', () {
    test('the failure is reported, not thrown', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      store.offline = true;

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.failed);
      expect(outcome.error, isNotNull);
    });

    test('and the local key is untouched', () async {
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      store.offline = true;
      await exchange('https://cloud.example.com/dav');
      expect(await SecretsStore.keyFor('provider:openai'), 'sk-secret');
    });

    test('a remote file that will not parse is treated as absent', () async {
      // Refusing to sync because a stray file is malformed would leave the user
      // with no way to fix it from the app.
      await SecretsStore.setKey('provider:openai', 'sk-secret');
      store.content = 'not json at all';

      final outcome = await exchange('https://cloud.example.com/dav');

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(store.content, contains('sk-secret'));
    });
  });

  group('the local file while an exchange is running', () {
    /// Purpose: Run the exchange through a hooked store.
    /// Inputs: The [hooked] store.
    /// Returns: The outcome.
    /// Side effects: As [exchange].
    /// Notes: Internal helper used within this file only.
    Future<SecretsSyncOutcome> hookedExchange(_HookedStore hooked) =>
        SecretsSyncService.exchange(
          config('https://cloud.example.com/dav'),
          clientFactory: (c) => shared.WebDavClient(c, httpClient: hooked),
        );

    test('a key typed during the upload is not lost by the rebase', () async {
      await SecretsStore.setKey('provider:openai', 'sk-mine');
      store.refuseNextPut = true;
      remoteHas('provider:openrouter', 'sk-theirs', DateTime.utc(2026, 1, 1));
      final hooked = _HookedStore(store)
        ..beforePut = () => SecretsStore.setKey('provider:local', 'sk-typed');

      final outcome = await hookedExchange(hooked);

      expect(outcome.status, SecretsSyncStatus.synced);
      expect(await SecretsStore.keyFor('provider:local'), 'sk-typed');
      expect(await SecretsStore.keyFor('provider:openai'), 'sk-mine');
      expect(await SecretsStore.keyFor('provider:openrouter'), 'sk-theirs');
      expect(store.content, contains('sk-typed'));
    });

    test('a failed re-download after a refusal fails, and overwrites nothing '
        'remote', () async {
      await SecretsStore.setKey('provider:openai', 'sk-mine');
      store.refuseNextPut = true;
      remoteHas('provider:openrouter', 'sk-theirs', DateTime.utc(2026, 1, 1));
      final before = store.content;
      final hooked = _HookedStore(store)..failLaterGets = true;

      final outcome = await hookedExchange(hooked);

      expect(outcome.status, SecretsSyncStatus.failed);
      expect(store.writes, isEmpty, reason: 'nothing was uploaded');
      expect(store.content, before);
      expect(await SecretsStore.keyFor('provider:openai'), 'sk-mine');
    });

    test('two keys set at once are both kept', () async {
      await Future.wait([
        SecretsStore.setKey('provider:a', 'sk-a'),
        SecretsStore.setKey('provider:b', 'sk-b'),
        SecretsStore.setKey('provider:c', 'sk-c'),
      ]);
      final keys = await SecretsStore.load();
      expect(keys.keyFor('provider:a'), 'sk-a');
      expect(keys.keyFor('provider:b'), 'sk-b');
      expect(keys.keyFor('provider:c'), 'sk-c');
    });

    test(
      'an unparseable file is set aside, then the exchange carries on',
      () async {
        final file = File(
          '${(await TranscribeStorage.getAppDir()).path}/$secretsFileName',
        );
        file.writeAsStringSync('{ this is not json');
        remoteHas('provider:openrouter', 'sk-theirs', DateTime.utc(2026, 1, 1));

        final outcome = await exchange('https://cloud.example.com/dav');

        expect(outcome.status, SecretsSyncStatus.synced);
        expect(await SecretsStore.keyFor('provider:openrouter'), 'sk-theirs');
        final aside = file.parent
            .listSync()
            .whereType<File>()
            .where((f) => f.path.contains('$secretsFileName.unreadable-'))
            .toList();
        expect(aside, hasLength(1));
        expect(aside.single.readAsStringSync(), '{ this is not json');
      },
    );
  });
}
