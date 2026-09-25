/// Purpose: Prove the build hook's library loads on this host and, given a
/// model, transcribes whisper.cpp's own sample.
/// Inputs: The `LASR_TEST_MODEL` environment variable: a GGML model path
/// (`ggml-tiny.bin` is enough). Without it the transcription test skips.
/// Returns: None.
/// Side effects: Builds the native library through the hook on first run.
/// Notes: Run with `dart test` in this package. The app's own tests use a
/// fake engine and never need this library.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:local_asr_whisper/local_asr_whisper.dart';
import 'package:test/test.dart';

/// Purpose: Read a 16 kHz mono 16-bit WAV as floats.
/// Inputs: [file].
/// Returns: The samples.
/// Side effects: Reads the file.
/// Notes: Internal helper used within this file only; walks the chunks.
Float32List readWav(File file) {
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, at, at + 4);
    final size = data.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      final count = size ~/ 2;
      return Float32List.fromList([
        for (var i = 0; i < count; i++)
          data.getInt16(at + 8 + i * 2, Endian.little) / 32768.0,
      ]);
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('no samples');
}

void main() {
  test('loads, with at least the CPU backend', () {
    final backends = WhisperLibrary.load();
    expect(backends, isNotNull);
    expect(backends, greaterThan(0));
    expect(WhisperLibrary.version(), isNotEmpty);
    final devices = WhisperLibrary.devices();
    expect(devices.map((d) => d.type), contains(0), reason: 'a CPU device');
    // ignore: avoid_print
    print(
      '${WhisperLibrary.systemInfo()}\n'
      '${devices.map((d) => '${d.name}: ${d.description}').join('\n')}',
    );
  });

  final model = Platform.environment['LASR_TEST_MODEL'];
  test(
    'transcribes the JFK sample, and can be cancelled',
    () {
      WhisperLibrary.load();
      final samples = readWav(File('../whisper.cpp/samples/jfk.wav'));
      final whisper = WhisperModel.load(model!);
      final control = WhisperControl();
      try {
        final watch = Stopwatch()..start();
        final segments = whisper.transcribe(
          samples,
          language: 'en',
          threads: 4,
          control: control,
        );
        watch.stop();
        final text = segments.map((s) => s.text).join(' ').toLowerCase();
        // ignore: avoid_print
        print('${watch.elapsedMilliseconds} ms: $text');
        expect(text, contains('ask not what your country can do for you'));
        expect(segments.first.startSeconds, 0);
        expect(segments.last.endSeconds, closeTo(11, 1.5));
        expect(control.progress, 100);

        control
          ..reset()
          ..cancel();
        expect(
          () => whisper.transcribe(samples, control: control),
          throwsA(isA<WhisperCancelled>()),
        );
      } finally {
        whisper.release();
        control.dispose();
      }
    },
    skip: model == null ? 'set LASR_TEST_MODEL to a GGML model' : false,
  );
}
