import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/shared/services/webdav_privacy.dart';
import 'package:my_transcribe/shared/services/webdav_service.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _Paths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Paths(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every WebDAV network entry refuses before device acknowledgement',
    () async {
      final root = await Directory.systemTemp.createTemp('transcribe_privacy');
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(root);
      addTearDown(() async {
        PathProviderPlatform.instance = previous;
        await root.delete(recursive: true);
      });
      var network = 0;
      final originalFactory = WebDAVService.clientFactory;
      WebDAVService.clientFactory = (config) {
        network++;
        throw StateError('network must remain untouched');
      };
      addTearDown(() => WebDAVService.clientFactory = originalFactory);
      final config = shared.WebDAVConfig(
        serverUrl: 'https://example.com',
        username: 'user',
        password: 'pass',
        remotePath: '/transcribe',
      );
      await WebDAVService.saveConfig(config);
      expect(await WebDavPrivacy.allowed(), isFalse);
      expect(await WebDAVService.testConnection(config), isFalse);
      expect((await WebDAVService.sync(config)).success, isFalse);
      expect((await WebDAVService.forceUpload(config)).success, isFalse);
      expect((await WebDAVService.forceDownload(config)).success, isFalse);
      expect(network, 0);
      expect((await WebDAVService.loadConfig())?.serverUrl, config.serverUrl);
      await WebDavPrivacy.store.acknowledge(WebDavPrivacy.noticeVersion);
      expect(await WebDavPrivacy.allowed(), isTrue);
    },
  );
}
