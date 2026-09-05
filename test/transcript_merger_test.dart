/// Purpose: Test how the windows of a split recording are joined back up.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Two rules, tested separately: the exact cut-point rule for models
/// that return times, and the token rule the original Python scripts used for
/// models that return only text. The Chinese cases are the ones the scripts got
/// wrong — they split on spaces, so a language that does not use them had its
/// whole overlap duplicated.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/services/transcript_merger.dart';

void main() {
  group('removeRepeatedPrefix', () {
    test('removes a repeated opening', () {
      expect(
        removeRepeatedPrefix(
          'and then we looked at the second example',
          'the second example is the interesting one',
        ),
        'is the interesting one',
      );
    });

    test('needs three matching words, not two', () {
      // Three is removed.
      expect(
        removeRepeatedPrefix('we said and then we', 'and then we moved on'),
        'moved on',
      );
      // Two is not. It would fire on any repeated "you know" or "and then",
      // and the merge would start eating real speech.
      expect(
        removeRepeatedPrefix('we said and then', 'and then we moved on'),
        'and then we moved on',
      );
      expect(
        removeRepeatedPrefix('it was so', 'so it was different'),
        'so it was different',
      );
    });

    test('ignores case and punctuation at the seam', () {
      // Two windows rarely punctuate a boundary identically.
      expect(
        removeRepeatedPrefix(
          'that is the whole idea.',
          'The whole idea, really, is simple',
        ),
        'really, is simple',
      );
    });

    test('removes the longest overlap, not the first one it finds', () {
      expect(
        removeRepeatedPrefix(
          'one two three four five',
          'two three four five six seven',
        ),
        'six seven',
      );
    });

    test('leaves text alone when nothing matches', () {
      expect(
        removeRepeatedPrefix('completely different words', 'nothing in common'),
        'nothing in common',
      );
    });

    test('handles an empty side', () {
      expect(removeRepeatedPrefix('', 'anything'), 'anything');
      expect(removeRepeatedPrefix('anything', ''), '');
    });

    test('does not remove a whole passage that repeats itself', () {
      // The overlap is the *start* of the new text. A sentence that happens to
      // repeat later in the passage is left alone.
      const previous = 'the rule is simple';
      const current = 'we apply it and the rule is simple again';
      expect(removeRepeatedPrefix(previous, current), current);
    });
  });

  group('removeRepeatedPrefix in Chinese', () {
    test('removes an overlap in text with no spaces', () {
      // The case the original scripts could not handle at all.
      expect(
        removeRepeatedPrefix(
          '我们今天要讲的是第二个例子',
          '第二个例子其实很有意思',
        ),
        '其实很有意思',
      );
    });

    test('needs more characters than it needs English words', () {
      // Three characters of Chinese carry far less than three English words,
      // so a short coincidental match must not trigger a removal.
      expect(
        removeRepeatedPrefix('这个问题很重要', '重要的是下一步'),
        '重要的是下一步',
      );
    });

    test('handles Japanese kana', () {
      expect(
        removeRepeatedPrefix(
          'それでは次の項目にうつります',
          '次の項目にうつりますが',
        ),
        'が',
      );
    });

    test('handles a mixture of scripts', () {
      expect(
        removeRepeatedPrefix(
          'we call this 转写 overlap handling here',
          'overlap handling here is the point',
        ),
        'is the point',
      );
    });

    test('two matching words are still not enough, in any script', () {
      // The three-token minimum is not relaxed just because one of the tokens
      // happens to be Chinese.
      expect(
        removeRepeatedPrefix(
          'we call this overlap handling',
          'overlap handling is the point',
        ),
        'overlap handling is the point',
      );
    });
  });

  group('mergeTextOnly', () {
    test('joins windows and removes what the overlap duplicated', () {
      final merged = mergeTextOnly(
        [
          'the first part of the lecture and then the second',
          'and then the second part follows',
        ],
        [0, 600],
        600,
      );
      expect(merged, hasLength(2));
      expect(merged.first.text, 'the first part of the lecture and then the second');
      expect(merged.last.text, 'part follows');
    });

    test('marks every segment as approximate', () {
      // These models return no times at all, and the viewer must not pretend
      // otherwise: it shows "about 10:00" and disables the subtitle exports.
      final merged = mergeTextOnly(['one two three'], [0], 600);
      expect(merged.single.approximate, isTrue);
      expect(merged.single.startSeconds, 0);
    });

    test('keeps each window at the position it had', () {
      final merged = mergeTextOnly(
        ['alpha bravo charlie', 'delta echo foxtrot'],
        [0, 300],
        300,
      );
      expect(merged.last.startSeconds, 300);
    });

    test('drops a window that was entirely duplicate', () {
      final merged = mergeTextOnly(
        ['one two three four five', 'one two three four five'],
        [0, 100],
        100,
      );
      expect(merged, hasLength(1));
    });
  });

  group('mergeTimedSegments', () {
    /// Purpose: Build a segment for a test case.
    /// Inputs: [start], [end], [text], [chunk].
    /// Returns: A [MergedSegment].
    /// Side effects: None.
    /// Notes: Internal helper used within this file only.
    MergedSegment seg(double start, double end, String text, int chunk) =>
        MergedSegment(
          startSeconds: start,
          endSeconds: end,
          text: text,
          chunkIndex: chunk,
        );

    test('cuts in the middle of the shared stretch', () {
      // Windows: 0–110 and 100–210, overlapping by 10 from 100. The cut is at
      // 105, so a segment centred at 102 belongs to the first window and one
      // centred at 108 belongs to the second.
      final merged = mergeTimedSegments(
        [
          [seg(0, 50, 'first', 0), seg(100, 104, 'before the cut', 0)],
          [seg(100, 104, 'before the cut', 1), seg(106, 110, 'after the cut', 1)],
        ],
        [0, 100],
        10,
      );
      expect(
        merged.map((s) => s.text),
        ['first', 'before the cut', 'after the cut'],
      );
    });

    test('keeps everything from a single window', () {
      final merged = mergeTimedSegments(
        [
          [seg(0, 10, 'one', 0), seg(10, 20, 'two', 0)],
        ],
        [0],
        0,
      );
      expect(merged, hasLength(2));
    });

    test('trims a phrase both windows transcribed at the seam', () {
      final merged = mergeTimedSegments(
        [
          [seg(90, 105, 'the end of the first window', 0)],
          [seg(111, 122, 'the end of the first window continues here', 1)],
        ],
        [0, 100],
        20,
      );
      expect(merged.map((s) => s.text), ['the end of the first window', 'continues here']);
    });

    test('drops a segment left empty by the trim', () {
      final merged = mergeTimedSegments(
        [
          [seg(90, 105, 'exactly the same words here', 0)],
          [seg(111, 122, 'exactly the same words here', 1)],
        ],
        [0, 100],
        20,
      );
      expect(merged, hasLength(1));
    });

    test('carries the window-local speaker label through', () {
      // The unifier needs to know which window a label came from, because the
      // same person is labelled differently in each.
      final merged = mergeTimedSegments(
        [
          [
            MergedSegment(
              startSeconds: 0,
              endSeconds: 10,
              text: 'hello',
              chunkIndex: 0,
              localSpeaker: 'A',
            ),
          ],
        ],
        [0],
        0,
      );
      expect(merged.single.localSpeaker, 'A');
      expect(merged.single.chunkIndex, 0);
    });

    test('a three-window recording keeps its order and loses nothing real', () {
      final merged = mergeTimedSegments(
        [
          [seg(0, 90, 'one', 0), seg(95, 99, 'two', 0)],
          [seg(100, 190, 'three', 1), seg(195, 199, 'four', 1)],
          [seg(200, 290, 'five', 2)],
        ],
        [0, 100, 200],
        10,
      );
      expect(merged.map((s) => s.text), ['one', 'two', 'three', 'four', 'five']);
    });
  });
}
