/// Purpose: FluidAudio's results become segments the way whisper.cpp's
/// Parakeet results do (L4 of the local-models plan).
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Pure function; no native library is loaded.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/engines/fluid_audio_engine.dart';

void main() {
  test('timed tokens are cut into sentences', () {
    final segments = segmentsFrom((
      text: 'Hello world. How are you?',
      tokens: [
        (piece: '▁Hello', start: 0.0, end: 0.4),
        (piece: '▁world', start: 0.4, end: 0.8),
        (piece: '.', start: 0.8, end: 0.9),
        (piece: '▁How', start: 1.2, end: 1.4),
        (piece: '▁are', start: 1.4, end: 1.5),
        (piece: '▁you', start: 1.5, end: 1.7),
        (piece: '?', start: 1.7, end: 1.8),
      ],
    ), 2);
    expect(segments.map((s) => s.text), ['Hello world.', 'How are you?']);
    expect(segments.last.startSeconds, 1.2);
  });

  test('text without times spans the window, and silence gives nothing', () {
    final one = segmentsFrom((text: ' Hello. ', tokens: const []), 30);
    expect(one.single.text, 'Hello.');
    expect(one.single.endSeconds, 30);
    expect(segmentsFrom((text: '  ', tokens: const []), 30), isEmpty);
  });
}
