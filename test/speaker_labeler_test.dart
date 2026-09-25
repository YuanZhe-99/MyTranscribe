import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/services/speaker_labeler.dart';
import 'package:my_transcribe/features/providers/services/provider_dialect.dart';

void main() {
  RawSegment seg(double start, double end) =>
      RawSegment(startSeconds: start, endSeconds: end, text: 'x');

  test('each segment takes the speaker it overlaps most', () {
    final labelled = labelSegments(
      [seg(0, 4), seg(4, 10)],
      [
        (start: 0, end: 5, speaker: 0),
        (start: 5, end: 10, speaker: 1),
      ],
    );
    expect(labelled.map((s) => s.speaker), ['S1', 'S2']);
  });

  test('overlap is summed per speaker across turns', () {
    final labelled = labelSegments(
      [seg(0, 10)],
      [
        (start: 0, end: 3, speaker: 0),
        (start: 3, end: 7, speaker: 1),
        (start: 7, end: 10, speaker: 0),
      ],
    );
    expect(labelled.single.speaker, 'S1');
  });

  test('a segment no turn touches keeps no speaker', () {
    final labelled = labelSegments(
      [seg(20, 25)],
      [(start: 0, end: 5, speaker: 0)],
    );
    expect(labelled.single.speaker, isNull);
    expect(labelled.single.text, 'x');
  });
}
