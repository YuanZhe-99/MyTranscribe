/// Purpose: Test that a speaker keeps one identity across every window of a
/// split recording, and that a doubtful match is refused rather than guessed.
/// Inputs: None; small window layouts are built in the test.
/// Returns: None.
/// Side effects: None.
/// Notes: The failure that matters is a wrong merge: two people shown as one is
/// a transcript that lies about who said what, and no amount of later reading
/// reveals it. A missed merge shows as an extra speaker the user can join in
/// one tap. The thresholds are set accordingly, and these tests hold them
/// there.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/transcript/services/speaker_unifier.dart';

/// Purpose: Build one window's labelled segments.
/// Inputs: The [windowIndex] and the lines as (start, end, label, text).
/// Returns: The segments.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<LabelledSegment> window(
  int windowIndex,
  List<(double, double, String, String)> lines,
) => [
  for (final line in lines)
    LabelledSegment(
      windowIndex: windowIndex,
      label: line.$3,
      startSeconds: line.$1,
      endSeconds: line.$2,
      text: line.$4,
    ),
];

void main() {
  group('one window', () {
    test('numbers its speakers in the order they first talk', () {
      // Not in the order the source allocated its labels: the first voice heard
      // should be Speaker 1.
      final result = unifySpeakers([
        window(0, [(10, 20, 'B', 'I speak first'), (0, 5, 'A', 'no, I do')]),
      ]);

      expect(result.map['0:A'], 'spk_1');
      expect(result.map['0:B'], 'spk_2');
      expect(result.speakerIds, ['spk_1', 'spk_2']);
    });

    test('gives an unlabelled recording no speakers at all', () {
      final result = unifySpeakers([]);
      expect(result.speakerIds, isEmpty);
      expect(result.map, isEmpty);
    });
  });

  group('two windows', () {
    test('joins the same voice across the overlap', () {
      // Window 0 covers 0-100, window 1 covers 80-180; both transcribe 80-100.
      final result = unifySpeakers([
        window(0, [
          (0, 40, 'A', 'the first part of the lecture'),
          (80, 100, 'B', 'and now a question from the floor'),
        ]),
        window(1, [
          (80, 100, 'X', 'and now a question from the floor'),
          (120, 160, 'Y', 'back to the lecture again'),
        ]),
      ]);

      expect(
        result.map['1:X'],
        result.map['0:B'],
        reason: 'the same seconds, so the same person',
      );
      expect(result.map['1:Y'], isNot(result.map['0:B']));
    });

    test('survives the source swapping its labels round', () {
      // The source has no memory between requests, so window 1 calling the same
      // person "B" instead of "A" is normal, not an error.
      final result = unifySpeakers([
        window(0, [
          (0, 50, 'A', 'hello everyone'),
          (80, 100, 'B', 'this is the second voice speaking now'),
        ]),
        window(1, [
          (80, 100, 'B', 'this is the second voice speaking now'),
          (110, 140, 'A', 'a third stretch'),
        ]),
      ]);

      expect(result.map['1:B'], result.map['0:B']);
    });

    test('makes a new speaker for somebody who first talks later', () {
      final result = unifySpeakers([
        window(0, [
          (0, 50, 'A', 'the lecture begins'),
          (80, 100, 'A', 'still the lecturer talking'),
        ]),
        window(1, [
          (80, 100, 'A', 'still the lecturer talking'),
          (120, 140, 'B', 'a question from someone new'),
        ]),
      ]);

      expect(result.map['1:A'], result.map['0:A']);
      expect(result.map['1:B'], isNot(result.map['0:A']));
      expect(result.speakerIds, hasLength(2));
    });

    test('refuses a match built on a moment of shared time', () {
      // Half a second of overlap is two people talking at once, not evidence.
      final result = unifySpeakers([
        window(0, [(0, 50, 'A', 'the lecture'), (99.5, 100, 'B', 'mm')]),
        window(1, [
          (99.5, 100, 'X', 'mm'),
          (120, 160, 'Y', 'something else entirely'),
        ]),
      ]);

      expect(
        result.map['1:X'],
        isNot(result.map['0:B']),
        reason: 'below the evidence floor, so a new speaker',
      );
    });

    test('refuses a match when the overlap is split evenly', () {
      // A label that overlaps two candidates equally has told us nothing, and
      // guessing between them is how two people become one.
      final result = unifySpeakers([
        window(0, [
          (80, 90, 'A', 'first speaker in the overlap'),
          (90, 100, 'B', 'second speaker in the overlap'),
        ]),
        window(1, [(80, 100, 'X', 'both of them at once somehow')]),
      ]);

      expect(result.map['1:X'], isNot('spk_1'));
      expect(result.map['1:X'], isNot('spk_2'));
    });

    test('does not give one previous speaker to two new labels', () {
      final result = unifySpeakers([
        window(0, [
          (80, 100, 'A', 'a long stretch of talking in the shared seconds'),
        ]),
        window(1, [
          (80, 92, 'X', 'a long stretch of talking in the shared seconds'),
          (92, 100, 'Y', 'a long stretch of talking in the shared seconds'),
        ]),
      ]);

      expect(
        {result.map['1:X'], result.map['1:Y']},
        hasLength(2),
        reason: 'one person cannot be two speakers in the next window',
      );
    });
  });

  group('three windows', () {
    test('carries an identity all the way through', () {
      // The chain is the point: window 2 never sees window 0.
      final result = unifySpeakers([
        window(0, [
          (0, 40, 'A', 'part one of the talk'),
          (80, 100, 'A', 'the shared seconds of the first pair'),
        ]),
        window(1, [
          (80, 100, 'M', 'the shared seconds of the first pair'),
          (160, 180, 'M', 'the shared seconds of the second pair'),
        ]),
        window(2, [
          (160, 180, 'Q', 'the shared seconds of the second pair'),
          (200, 240, 'Q', 'part three of the talk'),
        ]),
      ]);

      expect(result.map['1:M'], result.map['0:A']);
      expect(result.map['2:Q'], result.map['0:A']);
      expect(result.speakerIds, hasLength(1));
    });

    test('a two-speaker interview stays two speakers', () {
      final result = unifySpeakers([
        window(0, [
          (0, 30, 'A', 'so tell me about your work'),
          (80, 95, 'B', 'well it started about ten years ago'),
          (95, 100, 'A', 'and what happened then'),
        ]),
        window(1, [
          (80, 95, 'S1', 'well it started about ten years ago'),
          (95, 100, 'S2', 'and what happened then'),
          (160, 175, 'S1', 'we moved the whole thing to another city'),
          (175, 180, 'S2', 'that sounds difficult'),
        ]),
        window(2, [
          (160, 175, 'P', 'we moved the whole thing to another city'),
          (175, 180, 'Q', 'that sounds difficult'),
          (200, 230, 'P', 'it was, but it worked out'),
        ]),
      ]);

      expect(
        result.speakerIds,
        hasLength(2),
        reason: 'two people talked, however many windows it took',
      );
      expect(result.map['2:P'], result.map['0:B']);
      expect(result.map['2:Q'], result.map['0:A']);
    });
  });

  group('Chinese audio', () {
    test('matches on the characters, having no spaces to split on', () {
      // The same failure the overlap merger had: splitting on spaces makes
      // every Chinese pair score zero.
      final result = unifySpeakers([
        window(0, [(0, 40, 'A', '我们先讲第一个题目'), (80, 100, 'B', '这里是第二位说话人在讲话')]),
        window(1, [(80, 100, 'X', '这里是第二位说话人在讲话'), (120, 160, 'Y', '完全不同的内容')]),
      ]);

      expect(result.map['1:X'], result.map['0:B']);
      expect(result.map['1:Y'], isNot(result.map['0:B']));
    });
  });

  group('what a source recognised itself', () {
    test('is taken at its word', () {
      // The source was sent a sample clip named spk_1 and echoed it back. That
      // is a voice match, which beats any amount of overlap arithmetic.
      final result = unifySpeakers(
        [
          window(0, [(0, 40, 'A', 'the first window')]),
          window(1, [
            (200, 240, 'spk_1', 'far past any overlap with window zero'),
          ]),
        ],
        knownIds: const {'spk_1'},
      );

      expect(result.map['0:A'], 'spk_1');
      expect(result.map['1:spk_1'], 'spk_1');
      expect(result.speakerIds, hasLength(1));
    });
  });

  group('the evidence it kept', () {
    test('records why each label was placed', () {
      final result = unifySpeakers([
        window(0, [(80, 100, 'A', 'shared talking in the overlap')]),
        window(1, [(80, 100, 'X', 'shared talking in the overlap')]),
      ]);

      final decision = result.decisions.firstWhere(
        (d) => d.windowIndex == 1 && d.label == 'X',
      );
      expect(decision.matched, isTrue);
      expect(decision.weight, greaterThan(minEvidenceSeconds));
      expect(decision.uncertain, isFalse);
    });

    test('flags a match whose runner-up was nearly as strong', () {
      // Worth a second look, and cheap to flag: a wrong merge is invisible
      // once it is made.
      final result = unifySpeakers([
        window(0, [
          (80, 92, 'A', 'the same words in both of these lines here'),
          (88, 100, 'B', 'the same words in both of these lines here'),
        ]),
        window(1, [
          (80, 100, 'X', 'the same words in both of these lines here'),
        ]),
      ]);

      final decision = result.decisions.firstWhere((d) => d.label == 'X');
      if (decision.matched) {
        expect(decision.uncertain, isTrue);
      } else {
        expect(decision.speakerId, isNot('spk_1'));
      }
    });

    test('a first window is all new speakers, with no weight claimed', () {
      final result = unifySpeakers([
        window(0, [(0, 10, 'A', 'hello'), (10, 20, 'B', 'hi')]),
      ]);
      expect(result.decisions.every((d) => !d.matched), isTrue);
      expect(result.decisions.every((d) => d.weight == 0), isTrue);
    });
  });
}
