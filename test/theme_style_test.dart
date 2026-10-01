import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/theme.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Purpose: Test the Material 3 / Expressive interface styles (0.4.0).
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes a temporary app directory.
/// Notes: The two styles must share colors and differ only in theme details.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('themes', () {
    final m3 = AppTheme.light(null, AppUiStyle.material3);
    final ex = AppTheme.light(null, AppUiStyle.expressive);

    test('both styles share the seed color scheme', () {
      expect(ex.colorScheme, m3.colorScheme);
      expect(
        AppTheme.dark(null, AppUiStyle.expressive).colorScheme,
        AppTheme.dark(null, AppUiStyle.material3).colorScheme,
      );
    });

    test('Expressive is the default style', () {
      expect(AppTheme.light().cardTheme.shape, ex.cardTheme.shape);
    });

    test('Material 3 stays stock apart from outlined fields', () {
      expect(m3.cardTheme.shape, isNull);
      expect(m3.filledButtonTheme.style, isNull);
      expect(m3.inputDecorationTheme.border, isA<OutlineInputBorder>());
    });

    test('Expressive rounds shapes and emphasizes titles', () {
      expect(
        ex.cardTheme.shape,
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
      expect(ex.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(ex.textTheme.titleLarge!.fontWeight, FontWeight.w600);
      expect(ex.textTheme.bodyLarge, m3.textTheme.bodyLarge);
      final field = ex.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(field.borderRadius, BorderRadius.circular(12));
    });

    test('Expressive buttons morph to a rounded square when pressed', () {
      final shape = ex.filledButtonTheme.style!.shape!;
      expect(shape.resolve({}), isA<StadiumBorder>());
      expect(
        shape.resolve({WidgetState.pressed}),
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
    });
  });

  group('storage', () {
    late Directory temp;
    late File config;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('mytranscribe_ui_style');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      final appDir = Directory(p.join(docs.path, 'MyTranscribe'))..createSync();
      config = File(p.join(appDir.path, 'storage_config.json'));
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
      await TranscribeStorage.setStoragePath(null);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('no key means the default Expressive style', () async {
      expect(await TranscribeStorage.getUiStyle(), isNull);
    });

    test('writes store only Material 3', () async {
      await TranscribeStorage.setUiStyle('material3');
      expect(jsonDecode(config.readAsStringSync()), {'uiStyle': 'material3'});
      await TranscribeStorage.setUiStyle(null);
      expect(jsonDecode(config.readAsStringSync()), isEmpty);
      expect(await TranscribeStorage.getUiStyle(), isNull);
    });
  });
}
