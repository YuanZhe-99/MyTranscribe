/// Purpose: Test folding one speaker into another by hand.
/// Inputs: None; small transcripts are built in the test.
/// Returns: None.
/// Side effects: None.
/// Notes: The cross-window matching refuses a doubtful join rather than
/// guessing, so one person coming back as two is its expected way of being
/// wrong. Merging is the repair, and it has to be complete: a line left
/// pointing at a speaker that no longer exists would render with no name.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/transcript/models/transcript.dart';

/// Purpose: Build a two-speaker transcript.
/// Inputs: None.
/// Returns: A [Transcript].
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Transcript build() => const Transcript(
  jobId: 'job',
  speakers: [
    Speaker(id: 'spk_1', name: 'Alice'),
    Speaker(id: 'spk_2', colorIndex: 1),
    Speaker(id: 'spk_3', colorIndex: 2),
  ],
  speakerMap: {'0:A': 'spk_1', '1:X': 'spk_2', '1:Y': 'spk_3'},
  segments: [
    TranscriptSegment(
      id: 'seg_0',
      chunkIndex: 0,
      startSeconds: 0,
      endSeconds: 5,
      speakerId: 'spk_1',
      text: 'one',
    ),
    TranscriptSegment(
      id: 'seg_1',
      chunkIndex: 1,
      startSeconds: 5,
      endSeconds: 10,
      speakerId: 'spk_2',
      text: 'two',
    ),
    TranscriptSegment(
      id: 'seg_2',
      chunkIndex: 1,
      startSeconds: 10,
      endSeconds: 15,
      speakerId: 'spk_3',
      text: 'three',
    ),
  ],
);

void main() {
  group('marking a speaker unknown', () {
    test('takes their lines away without touching the text', () {
      final unknown = build().unassignSpeaker('spk_2');

      expect(unknown.speakers.map((s) => s.id), ['spk_1', 'spk_3']);
      expect(unknown.segments.map((s) => s.speakerId), [
        'spk_1',
        null,
        'spk_3',
      ]);
      expect(unknown.segments.map((s) => s.text), ['one', 'two', 'three']);
    });

    test('drops the window labels that led to them', () {
      // A label left pointing at a speaker who no longer exists would put a
      // re-run's lines back on a record nothing else knows about.
      expect(build().unassignSpeaker('spk_2').speakerMap, {
        '0:A': 'spk_1',
        '1:Y': 'spk_3',
      });
    });

    test('counts the lines nobody is credited with', () {
      expect(build().unassignedCount, 0);
      expect(build().unassignSpeaker('spk_2').unassignedCount, 1);
    });

    test('renumbers whoever is left', () {
      final unknown = build().unassignSpeaker('spk_2');
      expect(unknown.displayNameOf('spk_3', (n) => 'Speaker $n'), 'Speaker 2');
    });

    test('an id that is not there changes nothing', () {
      expect(build().unassignSpeaker('spk_9').speakers, hasLength(3));
      expect(build().unassignSpeaker('spk_9').unassignedCount, 0);
    });

    test('reads as unknown only when the transcript has speakers', () {
      final unknown = build().unassignSpeaker('spk_2');
      String fallback(int n) => 'Speaker $n';

      expect(unknown.nameFor(null, fallback: fallback, unknown: '未知'), '未知');
      expect(
        unknown.nameFor('spk_2', fallback: fallback, unknown: '未知'),
        '未知',
        reason: 'a line still pointing at a removed record reads the same way',
      );
      expect(
        const Transcript(
          jobId: 'job',
        ).nameFor(null, fallback: fallback, unknown: '未知'),
        isNull,
        reason: 'nothing was diarized, so there is nothing to be unsure about',
      );
    });
  });

  group('merging a speaker away', () {
    test('moves every line of theirs to the survivor', () {
      final merged = build().mergeSpeakers('spk_2', 'spk_1');

      expect(merged.speakers.map((s) => s.id), ['spk_1', 'spk_3']);
      expect(
        merged.segments.where((s) => s.speakerId == 'spk_2'),
        isEmpty,
        reason: 'a line pointing at a speaker that is gone renders unnamed',
      );
      expect(merged.segments[1].speakerId, 'spk_1');
    });

    test('leaves the words alone', () {
      final merged = build().mergeSpeakers('spk_2', 'spk_1');
      expect(merged.segments.map((s) => s.text), ['one', 'two', 'three']);
    });

    test('rewrites the window labels that led to them', () {
      // Otherwise re-running the matching would resurrect the merged speaker.
      final merged = build().mergeSpeakers('spk_2', 'spk_1');
      expect(merged.speakerMap['1:X'], 'spk_1');
      expect(merged.speakerMap.values, isNot(contains('spk_2')));
    });

    test('remembers what was merged, so it can be explained', () {
      final merged = build().mergeSpeakers('spk_2', 'spk_1');
      expect(merged.speaker('spk_1')!.mergedIds, contains('spk_2'));
    });

    test('carries an earlier merge along a second one', () {
      final twice = build()
          .mergeSpeakers('spk_2', 'spk_1')
          .mergeSpeakers('spk_1', 'spk_3');

      expect(twice.speakers.map((s) => s.id), ['spk_3']);
      expect(
        twice.speaker('spk_3')!.mergedIds,
        containsAll(<String>['spk_1', 'spk_2']),
      );
      expect(twice.segments.every((s) => s.speakerId == 'spk_3'), isTrue);
    });

    test('keeps the survivor name, not the merged one', () {
      final merged = build().mergeSpeakers('spk_1', 'spk_2');
      expect(merged.speaker('spk_2')!.name, isNull);
      expect(merged.speaker('spk_1'), isNull);
    });

    test('does nothing when asked to merge a speaker into itself', () {
      final merged = build().mergeSpeakers('spk_1', 'spk_1');
      expect(merged.speakers, hasLength(3));
    });

    test('does nothing when either speaker is not there', () {
      final merged = build().mergeSpeakers('spk_9', 'spk_1');
      expect(merged.speakers, hasLength(3));
    });
  });

  group('naming a speaker', () {
    /// Purpose: Name an unnamed speaker the way the viewer does.
    /// Inputs: The [number].
    /// Returns: The fallback label.
    /// Side effects: None.
    /// Notes: Internal helper used within this file only; stands in for the
    /// localized `viewerSpeakerFallback`.
    String fallback(int number) => 'Speaker $number';

    test('uses the name when there is one', () {
      expect(build().displayNameOf('spk_1', fallback), 'Alice');
    });

    test('numbers an unnamed speaker by position, not by their id', () {
      // A matching that placed four labels and then lost one to a trimmed
      // overlap leaves an id nothing points at. Reading the number out of the
      // id would show 1, 2, 3, 5 and look as though somebody went missing.
      const gapped = Transcript(
        jobId: 'job',
        speakers: [
          Speaker(id: 'spk_1'),
          Speaker(id: 'spk_2', colorIndex: 1),
          Speaker(id: 'spk_5', colorIndex: 2),
        ],
      );

      expect(gapped.displayNameOf('spk_5', fallback), 'Speaker 3');
    });

    test('renumbers after a merge', () {
      final merged = build().mergeSpeakers('spk_2', 'spk_1');
      expect(merged.displayNameOf('spk_3', fallback), 'Speaker 2');
    });

    test('says nothing for an id that is not there', () {
      expect(build().displayNameOf('spk_9', fallback), isNull);
      expect(build().displayNameOf(null, fallback), isNull);
    });
  });
}
