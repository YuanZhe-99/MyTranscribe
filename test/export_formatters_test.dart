/// Purpose: Test that each export format says what the transcript says, in the
/// shape the program that reads it expects.
/// Inputs: None; small transcripts are built in the test.
/// Returns: None.
/// Side effects: None.
/// Notes: Subtitle files are read by machines that fail silently on a malformed
/// one, so the timestamp shapes are checked exactly rather than loosely.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/transcript/models/transcript.dart';
import 'package:my_transcribe/features/transcript/services/export_formatters.dart';

/// Purpose: Build a transcript for a test.
/// Inputs: The [segments] as (start, end, speakerId, text), and the [speakers].
/// Returns: A [Transcript].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Transcript build(
  List<(double, double, String?, String)> segments, {
  List<Speaker> speakers = const [],
  bool approximate = false,
}) => Transcript(
  jobId: 'job',
  speakers: speakers,
  segments: [
    for (var i = 0; i < segments.length; i++)
      TranscriptSegment(
        id: 'seg_$i',
        chunkIndex: 0,
        startSeconds: segments[i].$1,
        endSeconds: segments[i].$2,
        speakerId: segments[i].$3,
        text: segments[i].$4,
        approximate: approximate,
      ),
  ],
);

/// Purpose: Name a speaker the way the viewer would.
/// Inputs: [id].
/// Returns: The name, or null when nobody is identified.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String? name(String? id) => switch (id) {
  'spk_1' => 'Alice',
  'spk_2' => 'Bob',
  _ => null,
};

void main() {
  group('timestamps', () {
    test('carry hours even at zero, which players require', () {
      expect(subtitleTimestamp(0), '00:00:00,000');
      expect(subtitleTimestamp(65.25), '00:01:05,250');
      expect(subtitleTimestamp(3725.5), '01:02:05,500');
    });

    test('use a full stop for WebVTT and a comma for SubRip', () {
      expect(subtitleTimestamp(1.5), '00:00:01,500');
      expect(subtitleTimestamp(1.5, millisecondSeparator: '.'), '00:00:01.500');
    });

    test('never go negative', () {
      expect(subtitleTimestamp(-5), '00:00:00,000');
      expect(readableTimestamp(-5), '00:00');
    });

    test('drop the hour for a reader below an hour', () {
      expect(readableTimestamp(65), '01:05');
      expect(readableTimestamp(3725), '1:02:05');
    });

    test('round milliseconds without spilling into the next second', () {
      // .9999 must not become :01,1000.
      expect(subtitleTimestamp(0.9999), '00:00:00,999');
    });
  });

  group('plain text', () {
    test('separates paragraphs with a blank line, as the scripts did', () {
      final text = renderTxt(
        build([(0, 5, null, 'first line'), (5, 10, null, 'second line')]),
        name,
      );
      expect(text, 'first line\n\nsecond line\n');
    });

    test('prefixes each paragraph with the speaker when there is one', () {
      final text = renderTxt(
        build(
          [(0, 5, 'spk_1', 'hello'), (5, 10, 'spk_2', 'hi there')],
          speakers: const [
            Speaker(id: 'spk_1'),
            Speaker(id: 'spk_2'),
          ],
        ),
        name,
      );
      expect(text, 'Alice: hello\n\nBob: hi there\n');
    });

    test('joins consecutive lines from one speaker into one paragraph', () {
      // Otherwise a conversation reads as a wall of one-line rows.
      final text = renderTxt(
        build(
          [
            (0, 5, 'spk_1', 'one'),
            (5, 10, 'spk_1', 'two'),
            (10, 15, 'spk_2', 'three'),
          ],
          speakers: const [
            Speaker(id: 'spk_1'),
            Speaker(id: 'spk_2'),
          ],
        ),
        name,
      );
      expect(text, 'Alice: one two\n\nBob: three\n');
    });
  });

  group('Markdown', () {
    test('uses the segment headings the original scripts wrote', () {
      final text = renderMarkdown(
        build([(0, 5, null, 'first'), (65, 70, null, 'second')]),
        name,
        subtitleLines: const ['- Audio: `x.mp3`'],
      );
      expect(text, startsWith('# Transcript\n'));
      expect(text, contains('- Audio: `x.mp3`'));
      expect(text, contains('## Segment 1 (about 00:00)'));
      expect(text, contains('## Segment 2 (about 01:05)'));
    });

    test('becomes speaker paragraphs when the recording has speakers', () {
      // Segment headings between every two sentences of a conversation would
      // be unreadable.
      final text = renderMarkdown(
        build(
          [(0, 5, 'spk_1', 'hello')],
          speakers: const [Speaker(id: 'spk_1')],
        ),
        name,
      );
      expect(text, contains('**Alice** [00:00]: hello'));
      expect(text, isNot(contains('## Segment')));
    });
  });

  group('SubRip', () {
    test('numbers cues from one and separates them with a blank line', () {
      final text = renderSrt(
        build([(0, 2, null, 'one'), (2, 4, null, 'two')]),
        name,
      );
      expect(
        text,
        '1\n00:00:00,000 --> 00:00:02,000\none\n\n'
        '2\n00:00:02,000 --> 00:00:04,000\ntwo\n\n',
      );
    });

    test('puts the speaker on its own line, having no field for one', () {
      final text = renderSrt(
        build(
          [(0, 2, 'spk_1', 'hello')],
          speakers: const [Speaker(id: 'spk_1')],
        ),
        name,
      );
      expect(text, contains('00:00:02,000\nAlice:\nhello'));
    });
  });

  group('WebVTT', () {
    test('starts with the required header', () {
      final text = renderVtt(build([(0, 2, null, 'one')]), name);
      expect(text, startsWith('WEBVTT\n\n'));
    });

    test('uses a voice tag for the speaker, which players can style', () {
      final text = renderVtt(
        build([(0, 2, 'spk_2', 'hi')], speakers: const [Speaker(id: 'spk_2')]),
        name,
      );
      expect(text, contains('<v Bob>hi'));
    });
  });

  group('the table', () {
    test('leads with a byte-order mark so Excel reads Chinese correctly', () {
      final text = renderCsv(build([(0, 1, null, '你好')]), name);
      expect(text.codeUnitAt(0), 0xFEFF);
      expect(text, contains('你好'));
    });

    test('quotes a field containing a comma, and doubles a quote', () {
      final text = renderCsv(
        build([(0, 1, null, 'one, two'), (1, 2, null, 'she said "no"')]),
        name,
      );
      expect(text, contains('"one, two"'));
      expect(text, contains('"she said ""no"""'));
    });

    test('names its columns', () {
      final text = renderCsv(build([(0, 1, null, 'x')]), name);
      expect(text, contains('index,start,end,speaker,text'));
    });
  });

  group('which formats are offered', () {
    test('subtitles are the ones that need real timestamps', () {
      // A subtitle file a minute out is worse than none, because it looks like
      // it works.
      expect(ExportFormat.srt.needsRealTimestamps, isTrue);
      expect(ExportFormat.vtt.needsRealTimestamps, isTrue);
      expect(ExportFormat.txt.needsRealTimestamps, isFalse);
      expect(ExportFormat.markdown.needsRealTimestamps, isFalse);
      expect(ExportFormat.json.needsRealTimestamps, isFalse);
      expect(ExportFormat.csv.needsRealTimestamps, isFalse);
    });

    test('a transcript of estimates says its times are not real', () {
      final estimated = build([
        (0, 60, null, 'a whole window'),
      ], approximate: true);
      expect(estimated.hasTimestamps, isFalse);
    });

    test('every format has its own extension', () {
      final extensions = ExportFormat.values.map((f) => f.extension).toSet();
      expect(extensions, hasLength(ExportFormat.values.length));
    });
  });
}
