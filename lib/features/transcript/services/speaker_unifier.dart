/// Purpose: Work out that the "Speaker 1" of one window and the "Speaker 2" of
/// the next are the same person.
/// Inputs: The labelled segments of each window, and how much the windows
/// overlap.
/// Returns: A mapping from each window's labels to global speakers, and the
/// evidence for it.
/// Side effects: None.
/// Notes: This is the problem splitting a recording creates. A source labels
/// speakers within one request and has no idea what it called them in the last
/// one, so a two-hour interview cut into five windows comes back with up to ten
/// unrelated labels. The overlap between consecutive windows is the only
/// evidence available without sending audio again: the same seconds are
/// transcribed twice, so whoever is talking in them is the same person under
/// both labels. See `doc/en-us/algorithms/speaker-unification.md`.
library;

/// One labelled line from one window, in absolute recording time.
class LabelledSegment {
  /// Which window it came from.
  final int windowIndex;

  /// The label the source gave it, meaningful only within that window.
  final String label;

  /// Where it starts in the whole recording, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  final double endSeconds;

  /// What was said.
  final String text;

  /// Purpose: Create a labelled segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LabelledSegment({
    required this.windowIndex,
    required this.label,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });

  /// The key this segment's label is recorded under.
  String get key => '$windowIndex:$label';
}

/// Why one label was or was not joined to a speaker from the window before.
class UnificationDecision {
  /// The window whose label was being placed.
  final int windowIndex;

  /// The label being placed.
  final String label;

  /// The speaker it was given.
  final String speakerId;

  /// How strong the evidence was, in weighted seconds of overlap.
  ///
  /// Zero means there was none: a new speaker, either the first window's, or
  /// somebody who did not talk during the shared seconds.
  final double weight;

  /// The next-best candidate's weight, when there was one.
  ///
  /// A decision whose runner-up was nearly as strong is the one to show the
  /// user when they ask why two voices were merged.
  final double runnerUpWeight;

  /// Whether this was matched to an existing speaker rather than a new one.
  final bool matched;

  /// Purpose: Record a decision.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const UnificationDecision({
    required this.windowIndex,
    required this.label,
    required this.speakerId,
    required this.matched,
    this.weight = 0,
    this.runnerUpWeight = 0,
  });

  /// Whether the runner-up was close enough that this is worth a second look.
  ///
  /// Shown in the viewer as an uncertain boundary; the user can merge or split
  /// from there. The threshold is deliberately generous, because a wrong merge
  /// is annoying and a flagged correct one costs nothing.
  bool get uncertain =>
      matched && runnerUpWeight > 0 && runnerUpWeight >= weight * 0.6;
}

/// What the matching concluded.
class SpeakerUnification {
  /// Every window label, as `"<window>:<label>"`, and the speaker it became.
  final Map<String, String> map;

  /// The speakers, in the order they first spoke.
  final List<String> speakerIds;

  /// One entry per label placed, in order.
  final List<UnificationDecision> decisions;

  /// Purpose: Record the outcome.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SpeakerUnification({
    required this.map,
    required this.speakerIds,
    required this.decisions,
  });
}

/// How much shared talking time counts as evidence at all, in seconds.
///
/// Below this the two labels barely coincide, and matching on it would join
/// people who happened to interject at the same moment.
const minEvidenceSeconds = 1.5;

/// What share of a label's total overlap the winning pair must carry.
///
/// **More** than this share, not merely this much: a label that splits its
/// overlap evenly between two candidates has told us nothing, and guessing
/// between them is how two people become one.
const minEvidenceShare = 0.5;

/// Purpose: Give every window's labels a speaker that means the same thing
/// across the whole recording.
/// Inputs: The [segments] of every window in order, already in absolute time,
/// and the [knownIds] a source echoed back from an enrollment.
/// Returns: The mapping and the evidence.
/// Side effects: None.
/// Notes: Windows are matched to the one before them and the mappings chain, so
/// a speaker who is quiet through window three still keeps their identity in
/// window four as long as somebody carried the chain. A label the source
/// returned as a known speaker id is taken at its word: that is the source
/// telling us it recognised the voice from the sample we sent, which is better
/// evidence than any amount of overlap arithmetic.
SpeakerUnification unifySpeakers(
  List<List<LabelledSegment>> segments, {
  Set<String> knownIds = const {},
}) {
  final map = <String, String>{};
  final speakers = <String>[];
  final decisions = <UnificationDecision>[];

  for (var window = 0; window < segments.length; window++) {
    final labels = _labelsOf(segments[window]);
    final previous = window == 0
        ? const <String>[]
        : _labelsOf(segments[window - 1]);

    // Weights between this window's labels and the previous window's, over the
    // seconds they share.
    final weights = <String, Map<String, double>>{};
    for (final label in labels) {
      weights[label] = {};
      for (final before in previous) {
        weights[label]![before] = _weight(
          segments[window - 1].where((s) => s.label == before),
          segments[window].where((s) => s.label == label),
        );
      }
    }

    final pairs = <(String label, String before, double weight)>[];
    for (final label in labels) {
      for (final entry in weights[label]!.entries) {
        if (entry.value > 0) pairs.add((label, entry.key, entry.value));
      }
    }
    // Strongest evidence first, each label and each previous label used once.
    // A full assignment algorithm would give the same answer for the handful of
    // labels a window ever has, and would be far harder to check by eye.
    pairs.sort((a, b) => b.$3.compareTo(a.$3));

    final matched = <String, (String before, double weight, double runnerUp)>{};
    final usedBefore = <String>{};
    for (final pair in pairs) {
      if (matched.containsKey(pair.$1) || usedBefore.contains(pair.$2)) {
        continue;
      }

      final rowTotal = weights[pair.$1]!.values.fold(0.0, (a, b) => a + b);
      final columnTotal = labels.fold(
        0.0,
        (sum, other) => sum + (weights[other]![pair.$2] ?? 0),
      );
      final runnerUp = _runnerUp(weights[pair.$1]!, pair.$2);

      if (pair.$3 < minEvidenceSeconds) continue;
      if (pair.$3 <= rowTotal * minEvidenceShare) continue;
      if (pair.$3 <= columnTotal * minEvidenceShare) continue;

      matched[pair.$1] = (pair.$2, pair.$3, runnerUp);
      usedBefore.add(pair.$2);
    }

    for (final label in labels) {
      // A source that echoed one of our own speaker ids has recognised the
      // voice from the sample we sent it.
      if (knownIds.contains(label) && speakers.contains(label)) {
        map['$window:$label'] = label;
        decisions.add(
          UnificationDecision(
            windowIndex: window,
            label: label,
            speakerId: label,
            matched: true,
          ),
        );
        continue;
      }

      if (matched[label] case final hit?) {
        final speakerId = map['${window - 1}:${hit.$1}'];
        if (speakerId != null) {
          map['$window:$label'] = speakerId;
          decisions.add(
            UnificationDecision(
              windowIndex: window,
              label: label,
              speakerId: speakerId,
              matched: true,
              weight: hit.$2,
              runnerUpWeight: hit.$3,
            ),
          );
          continue;
        }
      }

      final speakerId = 'spk_${speakers.length + 1}';
      speakers.add(speakerId);
      map['$window:$label'] = speakerId;
      decisions.add(
        UnificationDecision(
          windowIndex: window,
          label: label,
          speakerId: speakerId,
          matched: false,
        ),
      );
    }
  }

  return SpeakerUnification(
    map: map,
    speakerIds: speakers,
    decisions: decisions,
  );
}

/// Purpose: List a window's labels in the order they first speak.
/// Inputs: The window's [segments].
/// Returns: The labels.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Order of appearance, so
/// "Speaker 1" is the first voice heard rather than whichever label the source
/// happened to allocate first.
List<String> _labelsOf(List<LabelledSegment> segments) {
  final seen = <String>[];
  for (final segment in [
    ...segments,
  ]..sort((a, b) => a.startSeconds.compareTo(b.startSeconds))) {
    if (!seen.contains(segment.label)) seen.add(segment.label);
  }
  return seen;
}

/// Purpose: Measure how much two labels look like the same person.
/// Inputs: The segments carrying each label, [before] and [after].
/// Returns: Weighted seconds.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Shared seconds are the
/// base, multiplied up when the two also said the same words. Time alone is
/// nearly enough, but the two windows cut the same speech at different points,
/// so the boundaries never line up exactly; agreeing on the words is what tells
/// a real match from two people talking in the same ten seconds.
double _weight(
  Iterable<LabelledSegment> before,
  Iterable<LabelledSegment> after,
) {
  var total = 0.0;
  for (final a in before) {
    for (final b in after) {
      final start = a.startSeconds > b.startSeconds
          ? a.startSeconds
          : b.startSeconds;
      final end = a.endSeconds < b.endSeconds ? a.endSeconds : b.endSeconds;
      final shared = end - start;
      if (shared <= 0) continue;
      total += shared * (1 + _jaccard(a.text, b.text));
    }
  }
  return total;
}

/// Purpose: Measure how much two pieces of text have in common.
/// Inputs: [a] and [b].
/// Returns: 0 to 1.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Han, kana and hangul are
/// compared character by character, because Chinese and Japanese are written
/// without spaces and splitting on them would make every Chinese pair score
/// zero — the same reason the overlap merger has its own tokeniser.
double _jaccard(String a, String b) {
  final left = _tokens(a);
  final right = _tokens(b);
  if (left.isEmpty || right.isEmpty) return 0;
  final shared = left.intersection(right).length;
  final union = left.union(right).length;
  return union == 0 ? 0 : shared / union;
}

/// Purpose: Break text into comparable pieces.
/// Inputs: [text].
/// Returns: The set of pieces.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Set<String> _tokens(String text) {
  final tokens = <String>{};
  final buffer = StringBuffer();

  void flush() {
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString().toLowerCase());
      buffer.clear();
    }
  }

  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    if (_isIdeographic(rune)) {
      flush();
      tokens.add(character);
    } else if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(character)) {
      buffer.write(character);
    } else {
      flush();
    }
  }
  flush();
  return tokens;
}

/// Purpose: Report whether a character is written without word spacing.
/// Inputs: The [rune].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Han, hiragana, katakana
/// and hangul syllables, which is the set the merger uses for the same reason.
bool _isIdeographic(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x3040 && rune <= 0x30FF) ||
    (rune >= 0xAC00 && rune <= 0xD7AF);

/// Purpose: Find the second-strongest candidate for one label.
/// Inputs: The label's [weights] and the [winner] it was matched to.
/// Returns: The runner-up's weight, or zero.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
double _runnerUp(Map<String, double> weights, String winner) {
  var best = 0.0;
  for (final entry in weights.entries) {
    if (entry.key == winner) continue;
    if (entry.value > best) best = entry.value;
  }
  return best;
}
