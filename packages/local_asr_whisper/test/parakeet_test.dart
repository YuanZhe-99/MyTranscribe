/// Purpose: Prove whisper.cpp's Parakeet library loads from the bundled set
/// and transcribes, and that its tokens become sensible sentences.
/// Inputs: The `PARAKEET_TEST_MODEL` environment variable: a Parakeet GGML
/// model path (`ggml-parakeet-tdt-0.6b-v3-q8_0.bin`). Without it the
/// transcription test skips; the grouping tests always run.
/// Returns: None.
/// Side effects: The hook downloads the prebuilt libraries on first run.
/// Notes: Run with `dart test` in this package.
library;

import 'dart:io';

import 'package:local_asr_whisper/local_asr_whisper.dart';
import 'package:test/test.dart';

import 'whisper_test.dart' show readWav;

void main() {
  group('sentences', () {
    test('cuts at sentence ends and keeps the token times', () {
      final lines = sentences(const [
        ParakeetToken('▁Hello', 0.0, 0.4),
        ParakeetToken('▁world', 0.4, 0.8),
        ParakeetToken('.', 0.8, 0.9),
        ParakeetToken('▁How', 1.2, 1.4),
        ParakeetToken('▁are', 1.4, 1.5),
        ParakeetToken('▁you', 1.5, 1.7),
        ParakeetToken('?', 1.7, 1.8),
      ]);
      expect(lines.map((s) => s.text), ['Hello world.', 'How are you?']);
      expect(lines.first.startSeconds, 0.0);
      expect(lines.first.endSeconds, 0.9);
      expect(lines.last.startSeconds, 1.2);
    });

    test('drops control tokens and cuts a long sentence at a word', () {
      final tokens = [
        const ParakeetToken('<unk>', 0, 0),
        for (var i = 0; i < 30; i++)
          ParakeetToken('▁w$i', i.toDouble(), i + 0.5),
      ];
      final lines = sentences(tokens);
      expect(lines, hasLength(2));
      expect(lines.first.text, startsWith('w0 '));
      expect(lines.last.startSeconds, greaterThan(maxSentenceSeconds));
    });
  });

  final model = Platform.environment['PARAKEET_TEST_MODEL'];
  test(
    'transcribes the JFK sample, and can be cancelled',
    () {
      final samples = readWav(File('../../assets/local_asr/jfk.wav'));
      final parakeet = ParakeetModel.load(model!);
      try {
        final lines = parakeet.transcribe(samples, threads: 6);
        final text = lines.map((s) => s.text).join(' ').toLowerCase();
        expect(text, contains('ask not what your country can do for you'));
        expect(lines.last.endSeconds, closeTo(11, 1.5));

        final control = WhisperControl()..cancel();
        try {
          expect(
            () => parakeet.transcribe(samples, control: control),
            throwsA(isA<WhisperCancelled>()),
          );
        } finally {
          control.dispose();
        }
      } finally {
        parakeet.release();
      }
    },
    skip: model == null ? 'set PARAKEET_TEST_MODEL to a model path' : false,
  );
}
