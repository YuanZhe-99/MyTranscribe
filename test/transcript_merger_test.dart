/// Purpose: Test how the windows of a split recording are joined back up.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Three rules, tested separately: the exact cut-point rule for models
/// that return times, the token rule the original Python scripts used for
/// models that return only text, and the seam rule for models that answer in
/// paragraphs longer than the overlap. The Chinese cases are the ones the
/// scripts got wrong — they split on spaces, so a language that does not use
/// them had its whole overlap duplicated. The paragraph cases are the ones the
/// first real recording got wrong.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/services/transcript_merger.dart';

/// Purpose: Build a run of distinguishable words.
/// Inputs: [from] and [to], inclusive.
/// Returns: `w<from> … w<to>`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Numbered words make it
/// obvious in a failure message which part of a passage survived.
String words(int from, int to) =>
    [for (var i = from; i <= to; i++) 'w$i'].join(' ');

/// Purpose: Build a run of distinct Han characters.
/// Inputs: [from] and [count] — an offset into the ideograph block, and how
/// many characters.
/// Returns: The characters, with no spaces between them.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Generated rather than
/// written out so each character is certainly distinct, which is what makes a
/// match meaningful.
String han(int from, int count) =>
    String.fromCharCodes([for (var i = 0; i < count; i++) 0x4e00 + from + i]);

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
      expect(removeRepeatedPrefix('我们今天要讲的是第二个例子', '第二个例子其实很有意思'), '其实很有意思');
    });

    test('needs more characters than it needs English words', () {
      // Three characters of Chinese carry far less than three English words,
      // so a short coincidental match must not trigger a removal.
      expect(removeRepeatedPrefix('这个问题很重要', '重要的是下一步'), '重要的是下一步');
    });

    test('handles Japanese kana', () {
      expect(removeRepeatedPrefix('それでは次の項目にうつります', '次の項目にうつりますが'), 'が');
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

  group('removeSharedRun', () {
    test('sizes the search from how long the overlap is', () {
      expect(seamSearchTokens(19.5), 156);
      expect(seamSearchTokens(0), maxOverlapTokens);
      // Five seconds of speech is about forty tokens, which is where the old
      // fixed window already sat.
      expect(seamSearchTokens(5), maxOverlapTokens);
      expect(seamSearchTokens(1000), maxSeamTokens);
    });

    test('the anchored rule alone misses a long overlap', () {
      // This is the defect the first real recording found. The repetition is
      // fifty words long, so a comparison capped at forty never lines the two
      // sides up: the tail of the first passage and the head of the second are
      // the same fifty words seen through two windows offset by ten.
      final previous = words(1, 80);
      final current = '${words(31, 80)} ${words(81, 95)}';

      expect(removeRepeatedPrefix(previous, current), current);
      expect(
        removeRepeatedPrefix(previous, current, maxTokens: 157),
        words(81, 95),
      );
    });

    test('finds the shared words when one of them was heard differently', () {
      // A single word transcribed differently in the middle of the overlap
      // breaks the anchored rule outright. The longest run either side of it
      // is still thirty-five words, which is evidence enough.
      final previous = words(1, 80);
      final current =
          '${words(31, 44)} elsewhere ${words(46, 80)} '
          '${words(81, 95)}';

      expect(removeSharedRun(previous, current, maxTokens: 157), words(81, 95));
    });

    test('needs a longer run than the anchored rule does', () {
      // "and then we" is three words, which is enough at a boundary and not
      // enough in the middle of a passage, where it is just a common phrase.
      const previous = 'alpha beta gamma and then we delta epsilon';
      const current = 'zeta and then we eta theta';

      expect(removeSharedRun(previous, current, maxTokens: 157), current);
    });

    test('follows the chain across words heard differently', () {
      // Taken from the real recording, seam 1 to 2. The same fifteen seconds
      // came back as "in general space" from one window and ", uh, general
      // space," from the other, which breaks every rule that needs one
      // unbroken run.
      const previous =
          'So here, what we do is, what we do here is we are subtracting the '
          'projection of a vi- Of V3 onto a plane in general space spanned by';
      const current =
          'Of V3 onto a plane, uh, general space, spanned by the two previous, '
          'uh, vectors, basis vectors, U1 and U2.';

      expect(
        removeSharedRun(previous, current, maxTokens: 127),
        'the two previous, uh, vectors, basis vectors, U1 and U2.',
      );
    });

    test('steps over a symbol the two windows wrote differently', () {
      // The real recording's seam 3 to 4: "x squared" against "s square", and
      // "phi 0" against "y0", with matching speech either side of each.
      const previous =
          'and we use the orthogonality 0, which leads to then V0 equals minus '
          'x squared inner product with f, sorry, phi 0 divided by';
      const current =
          'V0 equals minus s square inner product with f, sorry, y0 divided by '
          'y0, y0 inner product. So I will keep this form as is.';

      expect(
        removeSharedRun(previous, current, maxTokens: 134),
        'y0, y0 inner product. So I will keep this form as is.',
      );
    });

    test('will not chain onto a phrase the recording repeats throughout', () {
      // "inner product" is most of a mathematics lecture's vocabulary. A link
      // has to come after the last one in the earlier passage as well as in the
      // later one, so an earlier mention cannot pull the cut forwards.
      const previous = 'the inner product of a and b, then we take the norm';
      const current =
          'so now consider a different question entirely, about the inner '
          'product again';

      expect(removeSharedRun(previous, current, maxTokens: 127), current);
    });

    test('leaves a passage alone when the two share nothing', () {
      expect(
        removeSharedRun('one two three four', 'five six seven eight'),
        'five six seven eight',
      );
    });

    test('handles an empty side', () {
      expect(removeSharedRun('', 'something'), 'something');
      expect(removeSharedRun('something', ''), '');
    });

    test('works in a script with no spaces', () {
      // Thirty shared characters with one heard differently in the middle: the
      // run after it is fourteen characters, above the higher CJK threshold.
      final previous = han(0, 60);
      final current =
          '${han(30, 15)}${han(900, 1)}${han(45, 15)}${han(600, 10)}';

      expect(removeSharedRun(previous, current, maxTokens: 157), han(600, 10));
    });

    test('a short run of characters is not enough, either', () {
      // Five characters, below minSharedRunCjkCharacters.
      final previous = '${han(0, 20)}${han(700, 5)}${han(30, 6)}';
      final current = '${han(800, 4)}${han(700, 5)}${han(850, 6)}';

      expect(removeSharedRun(previous, current, maxTokens: 157), current);
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
      expect(
        merged.first.text,
        'the first part of the lecture and then the second',
      );
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
          [
            seg(100, 104, 'before the cut', 1),
            seg(106, 110, 'after the cut', 1),
          ],
        ],
        [0, 100],
        10,
      );
      expect(merged.map((s) => s.text), [
        'first',
        'before the cut',
        'after the cut',
      ]);
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
      expect(merged.map((s) => s.text), [
        'the end of the first window',
        'continues here',
      ]);
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

    test('trims the shared stretch when the segments are paragraphs', () {
      // The shape the first real recording produced: nine-and-a-half-minute
      // windows, a twenty-second overlap for speakers, and a model that answers
      // in paragraphs — so one segment either side of the cut covers the shared
      // speech in full, and the midpoint rule keeps both.
      final merged = mergeTimedSegments(
        [
          [seg(515.56, 570.0, words(1, 80), 0)],
          [seg(550.48, 574.92, '${words(31, 80)} ${words(81, 95)}', 1)],
        ],
        [0, 550],
        20,
      );

      expect(merged, hasLength(2));
      expect(merged[0].text, words(1, 80));
      expect(merged[1].text, words(81, 95));
    });

    test('moves a trimmed segment to where its words actually begin', () {
      // What is left of the later segment was spoken after the earlier window
      // stopped, so a subtitle built from it must not claim the seconds the
      // trim removed.
      final merged = mergeTimedSegments(
        [
          [seg(515.56, 570.0, words(1, 80), 0)],
          [seg(550.48, 574.92, '${words(31, 80)} ${words(81, 95)}', 1)],
        ],
        [0, 550],
        20,
      );

      expect(merged[1].startSeconds, 570.0);
      expect(merged[1].endSeconds, 574.92);
    });

    test('leaves the times alone when nothing was trimmed', () {
      final merged = mergeTimedSegments(
        [
          [seg(90, 105, 'the first window said this', 0)],
          [seg(101, 122, 'the second window said something else', 1)],
        ],
        [0, 100],
        20,
      );

      expect(merged[1].startSeconds, 101);
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
      expect(merged.map((s) => s.text), [
        'one',
        'two',
        'three',
        'four',
        'five',
      ]);
    });
  });
}
