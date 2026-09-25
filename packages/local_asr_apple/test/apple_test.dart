/// Purpose: The Neural Engine bridge loads where the build has it, and only
/// there.
/// Inputs: None.
/// Returns: None.
/// Side effects: On macOS the hook downloads the prebuilt bridge.
/// Notes: Run with `dart test` in this package. Elsewhere the hook gives no
/// asset, and the version is null rather than a crash.
library;

import 'dart:io';

import 'package:local_asr_apple/local_asr_apple.dart';
import 'package:test/test.dart';

void main() {
  test('the bridge answers on macOS and is absent elsewhere', () {
    final version = AppleAsrLibrary.version();
    if (Platform.isMacOS) {
      expect(version, contains('fluidaudio 0.17.4'));
    } else {
      expect(version, isNull);
    }
  });
}
