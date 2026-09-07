/// Purpose: Join the windows of a split recording back into one transcript.
/// Inputs: The per-window results, and the plan that produced them.
/// Returns: One ordered list of segments.
/// Side effects: None — pure, so both rules are testable without a network.
/// Notes: Consecutive windows share a stretch of audio, so the same words come
/// back twice. A cut point removes most of it when the model returned times, a
/// text rule does the whole job when it did not, and a third rule catches what
/// the cut point cannot: a model that answers in paragraphs returns segments
/// longer than the overlap, so both sides of the cut carry the shared speech.
/// See `doc/en-us/algorithms/overlap-merge.md`.
library;

/// One piece of transcript, with where it came from.
class MergedSegment {
  /// Where it starts in the whole recording, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  final double endSeconds;

  /// What was said.
  final String text;

  /// Whether the times are real or inferred from the window's position.
  ///
  /// A model that returns no times still produces a readable transcript; the
  /// viewer shows approximate times and disables the subtitle exports rather
  /// than inventing precision.
  final bool approximate;

  /// The window this came from.
  final int chunkIndex;

  /// The speaker label the model used, within that window.
  ///
  /// Window-local: the same person is labelled differently in different
  /// windows, which is what the speaker unifier exists to resolve.
  final String? localSpeaker;

  /// Purpose: Create a merged segment.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const MergedSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
    required this.chunkIndex,
    this.approximate = false,
    this.localSpeaker,
  });

  /// The midpoint, used to decide which window owns a segment.
  double get midpointSeconds => (startSeconds + endSeconds) / 2;

  /// Purpose: Return a copy with different text.
  /// Inputs: [text]; [startSeconds] when the surviving words began later than
  /// the segment did.
  /// Returns: A new [MergedSegment].
  /// Side effects: None.
  /// Notes: A trim at a seam removes the words the previous window already
  /// carried, so what is left starts where that window stopped. Moving the
  /// start with the text is what keeps a subtitle from showing the remainder
  /// over the seconds it no longer covers.
  MergedSegment withText(String text, {double? startSeconds}) => MergedSegment(
    startSeconds: startSeconds ?? this.startSeconds,
    endSeconds: endSeconds,
    text: text,
    chunkIndex: chunkIndex,
    approximate: approximate,
    localSpeaker: localSpeaker,
  );
}

/// At least this many tokens must match before an overlap is removed.
///
/// Two would fire on any repeated "you know" or "and then", and the merge would
/// eat real speech. Three is the figure the original scripts used.
const minOverlapTokens = 3;

/// At most this many tokens are compared at a boundary.
///
/// Beyond this the match is no longer about an overlap.
const maxOverlapTokens = 40;

/// At least this many characters must match for a script without spaces.
///
/// A few characters of Chinese carry far less information than three English
/// words, so the threshold has to be higher than the token minimum to mean the
/// same thing — but not much higher: four characters is already a phrase such
/// as 第二个例 or 次の項目, and requiring more would leave a real overlap in
/// place. What keeps this safe is *where* it is compared: the tail of one
/// window against the head of the next, at a seam where duplication is the
/// expected case rather than a coincidence.
const minOverlapCjkCharacters = 4;

/// How many tokens a second of speech is assumed to produce.
///
/// Fast English is about three words a second and Chinese about five characters
/// a second, so four is the middle of the range this app actually meets. It is
/// only used to size a search window, never to place anything in time.
const seamTokensPerSecond = 4;

/// How much larger than the estimate the search window is made.
///
/// A window that is too small misses the overlap and leaves the duplication in
/// the transcript; one that is too large costs a little arithmetic. The error
/// is deliberately made in the cheap direction.
const seamSearchFactor = 2;

/// The largest search window, in tokens.
///
/// The comparison is quadratic in this number, and beyond a few hundred tokens
/// a match is no longer plausibly an overlap.
const maxSeamTokens = 400;

/// How many shared tokens must be found before a seam is trimmed.
///
/// [minOverlapTokens] is safe because it compares the very end of one passage
/// with the very start of the next, where duplication is the expected case. The
/// seam rule matches from the start of the later passage but anywhere in the
/// earlier one, which is less positional evidence, so it has to find more words
/// before it is believed.
const minSharedRunTokens = 6;

/// The same threshold for a script without spaces.
///
/// Eight characters is a clause rather than a phrase, which is what six English
/// words are.
const minSharedRunCjkCharacters = 8;

/// The shortest run that may join a chain of shared speech.
///
/// Two tokens on its own means nothing; two tokens in a chain that already has
/// several links, each following the last in both passages, is one more piece
/// of the same evidence.
const minChainRunTokens = 2;

/// How many tokens may be heard differently between two runs of shared speech.
///
/// Two windows transcribing the same seconds disagree in scattered small ways:
/// a word misheard, a "uh" one side dropped, a number written two ways. Three
/// is enough to step over such a difference and too few to step over a
/// sentence.
const maxSeamGapTokens = 3;

/// Purpose: Work out how far to look for the words two windows share.
/// Inputs: [overlapSeconds] — how much speech the two segments have in common.
/// Returns: A number of tokens.
/// Side effects: None.
/// Notes: Derived from the seam rather than fixed, because the overlap is a
/// setting: twenty seconds for a diarized recording carries five times the
/// words five seconds does. Never smaller than [maxOverlapTokens], so a seam
/// with no measurable time overlap still gets the old search.
int seamSearchTokens(double overlapSeconds) {
  if (overlapSeconds <= 0) return maxOverlapTokens;
  final estimate = (overlapSeconds * seamTokensPerSecond * seamSearchFactor)
      .ceil();
  return estimate.clamp(maxOverlapTokens, maxSeamTokens);
}

/// Purpose: Join windows that carry real times.
/// Inputs: The per-window [segments], keyed by window index, the window start
/// times, and the [overlapSeconds].
/// Returns: One ordered list.
/// Side effects: None.
/// Notes: The cut point sits in the middle of the shared stretch: the earlier
/// window keeps what ends before it, the later one keeps what starts after.
/// The boundary pair is then checked for words both windows carried.
///
/// A segment can be longer than the overlap — a model that answers in
/// paragraphs returns three of them for a ten-minute window — and then the
/// midpoint rule keeps a segment from each side that between them cover the
/// shared stretch twice. That is what [removeSharedRun] is for, and it is why
/// the seam pair is treated differently from an ordinary consecutive pair.
List<MergedSegment> mergeTimedSegments(
  List<List<MergedSegment>> segments,
  List<double> windowStarts,
  double overlapSeconds,
) {
  final merged = <MergedSegment>[];
  for (var index = 0; index < segments.length; index++) {
    final isLast = index == segments.length - 1;
    final cut = isLast
        ? double.infinity
        : windowStarts[index + 1] + overlapSeconds / 2;
    final from = index == 0
        ? double.negativeInfinity
        : windowStarts[index] + overlapSeconds / 2;

    for (final segment in segments[index]) {
      final midpoint = segment.midpointSeconds;
      if (midpoint < from || midpoint >= cut) continue;
      merged.add(segment);
    }
  }

  // Two windows can transcribe the same speech either side of the cut. Trim at
  // each seam rather than across the whole transcript, so a genuinely repeated
  // sentence elsewhere is left alone.
  for (var index = 1; index < merged.length; index++) {
    final previous = merged[index - 1];
    final current = merged[index];
    final seam = previous.chunkIndex != current.chunkIndex;
    final shared = previous.endSeconds - current.startSeconds;

    final trimmed = seam
        ? removeSharedRun(
            previous.text,
            current.text,
            maxTokens: seamSearchTokens(shared),
          )
        : removeRepeatedPrefix(previous.text, current.text);
    if (trimmed == current.text) continue;

    merged[index] = current.withText(
      trimmed,
      // What survived began where the previous window stopped — but only when
      // the two really did overlap in time, and never past the segment's own
      // end, which would invert it.
      startSeconds:
          seam && shared > 0 && previous.endSeconds < current.endSeconds
          ? previous.endSeconds
          : null,
    );
  }
  return [
    for (final segment in merged)
      if (segment.text.trim().isNotEmpty) segment,
  ];
}

/// Purpose: Join windows that returned text and nothing else.
/// Inputs: The per-window [texts], the window start times, and the stride.
/// Returns: One segment per window, with the duplication removed.
/// Side effects: None.
/// Notes: The rule the original scripts used, kept because it is the only thing
/// that works without times. Each window's text keeps the position it had, so
/// the viewer can still say roughly when something was said.
List<MergedSegment> mergeTextOnly(
  List<String> texts,
  List<double> windowStarts,
  double strideSeconds,
) {
  final merged = <MergedSegment>[];
  var accumulated = '';
  for (var index = 0; index < texts.length; index++) {
    final trimmed = removeRepeatedPrefix(accumulated, texts[index]);
    if (trimmed.trim().isEmpty) continue;
    merged.add(
      MergedSegment(
        startSeconds: windowStarts[index],
        endSeconds: windowStarts[index] + strideSeconds,
        text: trimmed.trim(),
        chunkIndex: index,
        approximate: true,
      ),
    );
    accumulated = '$accumulated $trimmed'.trim();
  }
  return merged;
}

/// Purpose: Drop the start of one passage where it repeats the end of another.
/// Inputs: [previous] what has been kept, [current] what came next, and
/// [maxTokens] — how many tokens either side to compare.
/// Returns: [current] with its repeated opening removed.
/// Side effects: None.
/// Notes: Compares longest first and stops at the first match, so the largest
/// genuine overlap is removed rather than a coincidental short one. Tokens are
/// normalized before comparing — case folded, punctuation stripped — because
/// two windows rarely punctuate a boundary identically.
///
/// A run of Han characters, kana or Hangul is split into individual characters,
/// because those scripts do not use spaces: without it the whole overlap of a
/// Chinese recording would be duplicated, which is exactly what happened to the
/// scripts this replaces.
String removeRepeatedPrefix(
  String previous,
  String current, {
  int maxTokens = maxOverlapTokens,
}) {
  if (previous.isEmpty || current.isEmpty) return current;

  final previousTokens = _tokenize(previous);
  final currentTokens = _tokenize(current);
  if (previousTokens.isEmpty || currentTokens.isEmpty) return current;

  final maximum = [
    maxTokens,
    previousTokens.length,
    currentTokens.length,
  ].reduce((a, b) => a < b ? a : b);

  for (var count = maximum; count >= minOverlapTokens; count--) {
    final tail = previousTokens.sublist(previousTokens.length - count);
    final head = currentTokens.sublist(0, count);
    if (!_tokensMatch(tail, head)) continue;
    // A CJK match needs more characters to mean as much as three words do.
    if (_isCjkOnly(head) && count < minOverlapCjkCharacters) continue;
    return _joinFrom(current, currentTokens, count);
  }
  return current;
}

/// Purpose: Drop everything one passage carries of speech another already
/// covered, even when the repetition does not start at the boundary.
/// Inputs: [previous] what has been kept, [current] what came next, and
/// [maxTokens] — how many tokens either side to compare.
/// Returns: [current] with the shared speech and everything before it removed.
/// Side effects: None.
/// Notes: The seam rule for models that answer in paragraphs. Where
/// [removeRepeatedPrefix] needs the repetition to run from the very end of one
/// passage to the very start of the next, a paragraph-sized segment carries the
/// shared stretch in its *middle*: the later window opens with seconds the
/// earlier one had already finished with, and closes with speech the earlier
/// one never heard. So the longest run of words the two have in common is found
/// wherever it sits, and [current] is cut through the end of it.
///
/// [previous] is trusted and never altered. Cutting the later passage rather
/// than the earlier one keeps the transcript in the order it was spoken and
/// leaves the earlier window's punctuation, which is the one that had the full
/// sentence.
///
/// Two windows transcribing the same seconds disagree in scattered small ways —
/// a word misheard, a hesitation one side dropped, a symbol written two ways —
/// so the shared speech comes back as a chain of matching runs with a stranger
/// or two between them. The chain is followed link by link, each link starting
/// where the last one ended in **both** passages, and [current] is cut at the
/// end of the last link. Requiring the chain to move forwards on both sides is
/// what stops it latching onto a phrase the lecture happens to repeat
/// throughout, which for a mathematics lecture is most of its vocabulary.
///
/// Falls back to leaving [current] alone. A seam where the two windows heard
/// genuinely different words leaves a little duplication that a reader can see
/// and delete, which is much better than a silently missing sentence.
String removeSharedRun(
  String previous,
  String current, {
  int maxTokens = maxOverlapTokens,
}) {
  // The anchored rule first: when it fires it is the safest of the three,
  // because the match runs from one passage's end to the other's start.
  final anchored = removeRepeatedPrefix(
    previous,
    current,
    maxTokens: maxTokens,
  );
  if (anchored != current) return anchored;

  if (previous.isEmpty || current.isEmpty) return current;
  final previousTokens = _tokenize(previous);
  final currentTokens = _tokenize(current);
  if (previousTokens.isEmpty || currentTokens.isEmpty) return current;

  final tail = previousTokens.length > maxTokens
      ? previousTokens.sublist(previousTokens.length - maxTokens)
      : previousTokens;
  final head = currentTokens.length > maxTokens
      ? currentTokens.sublist(0, maxTokens)
      : currentTokens;

  final skip = _sharedRunChain(tail, head);
  if (skip == 0) return current;
  return _joinFrom(current, currentTokens, skip);
}

/// Purpose: Follow the chain of runs two passages share at a seam.
/// Inputs: [tail] the end of the earlier passage, [head] the start of the later
/// one.
/// Returns: How many tokens of [head] the two have in common, counted to the
/// end of the last link, or 0 when the evidence is too thin.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
///
/// Greedy and ordered. Each link is the longest run that starts within
/// [maxSeamGapTokens] of where the last one ended in [head] and at or after
/// where it ended in [tail]; the search stops at the first gap it cannot step
/// over. The chain has to start at the head of [head], which is the positional
/// evidence that this is an overlap at all, and the total has to reach
/// [minSharedRunTokens] before anything is cut.
int _sharedRunChain(List<_Token> tail, List<_Token> head) {
  if (tail.isEmpty || head.isEmpty) return 0;

  var headAt = 0;
  var tailAt = 0;
  var covered = 0;
  var end = 0;
  final matched = <_Token>[];

  while (headAt < head.length) {
    var bestLength = 0;
    var bestHead = 0;
    var bestTail = 0;

    final limit = headAt + maxSeamGapTokens;
    for (var h = headAt; h <= limit && h < head.length; h++) {
      for (var t = tailAt; t < tail.length; t++) {
        var length = 0;
        while (h + length < head.length &&
            t + length < tail.length &&
            head[h + length].normalized == tail[t + length].normalized) {
          length++;
        }
        if (length > bestLength) {
          bestLength = length;
          bestHead = h;
          bestTail = t;
        }
      }
    }

    if (bestLength < minChainRunTokens) break;
    matched.addAll(head.sublist(bestHead, bestHead + bestLength));
    covered += bestLength;
    headAt = bestHead + bestLength;
    tailAt = bestTail + bestLength;
    end = headAt;
  }

  final enough = _isCjkOnly(matched)
      ? covered >= minSharedRunCjkCharacters
      : covered >= minSharedRunTokens;
  return enough ? end : 0;
}

/// One token, with where it sat in the original text.
class _Token {
  const _Token(this.normalized, this.end, this.isCjk);

  /// The comparable form: case folded, punctuation stripped.
  final String normalized;

  /// The index just past this token in the source string.
  final int end;

  /// Whether it is a single character from a script that has no spaces.
  final bool isCjk;
}

/// Purpose: Split a passage into comparable tokens.
/// Notes: Internal helper used within this file only; the public entry point is
/// [removeRepeatedPrefix].
/// Inputs: [text].
/// Returns: The tokens, in order.
/// Side effects: None.
/// Notes: Words for scripts that use spaces, single characters for those that
/// do not. Anything that normalizes to nothing — a lone comma — is dropped, so
/// punctuation cannot make two identical passages look different.
List<_Token> _tokenize(String text) {
  final tokens = <_Token>[];
  final buffer = StringBuffer();
  var wordStartHandled = true;

  void flush(int end) {
    if (buffer.isEmpty) return;
    final normalized = _normalize(buffer.toString());
    if (normalized.isNotEmpty) tokens.add(_Token(normalized, end, false));
    buffer.clear();
    wordStartHandled = true;
  }

  for (var i = 0; i < text.length; i++) {
    final rune = text.codeUnitAt(i);
    if (_isCjkRune(rune)) {
      flush(i);
      tokens.add(_Token(String.fromCharCode(rune), i + 1, true));
      continue;
    }
    if (_isSeparator(rune)) {
      flush(i);
      continue;
    }
    buffer.write(text[i]);
    wordStartHandled = false;
  }
  if (!wordStartHandled || buffer.isNotEmpty) flush(text.length);
  return tokens;
}

/// Purpose: Compare two token runs.
/// Inputs: [a], [b].
/// Returns: `true` when every normalized token matches.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _tokensMatch(List<_Token> a, List<_Token> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].normalized != b[i].normalized) return false;
  }
  return true;
}

/// Purpose: Report whether a run is entirely space-less script.
/// Inputs: [tokens].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _isCjkOnly(List<_Token> tokens) => tokens.every((token) => token.isCjk);

/// Purpose: Return the source text from after a number of tokens.
/// Inputs: [source], its [tokens], and how many to [skip].
/// Returns: The remainder, trimmed of leading separators.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Cutting by the recorded
/// offset rather than rebuilding from tokens keeps the original punctuation and
/// spacing of everything that survives.
String _joinFrom(String source, List<_Token> tokens, int skip) {
  if (skip >= tokens.length) return '';
  return source.substring(tokens[skip - 1].end).trimLeft();
}

/// Purpose: Reduce a token to its comparable form.
/// Inputs: [token].
/// Returns: Lower case, with non-word characters removed.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _normalize(String token) =>
    token.toLowerCase().replaceAll(RegExp(r'[^\wÀ-ɏ]'), '');

/// Purpose: Report whether a code unit separates words.
/// Inputs: [rune].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _isSeparator(int rune) =>
    rune == 0x20 || rune == 0x09 || rune == 0x0a || rune == 0x0d;

/// Purpose: Report whether a code unit belongs to a script without spaces.
/// Inputs: [rune].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. CJK ideographs, the two
/// Japanese kana blocks, and Hangul syllables. Deliberately not Thai or Lao,
/// which also lack spaces but whose units are not single code points — getting
/// those right needs a real segmenter, and a wrong split there would be worse
/// than the current behaviour of leaving the overlap alone.
bool _isCjkRune(int rune) =>
    (rune >= 0x4e00 && rune <= 0x9fff) || // CJK unified ideographs
    (rune >= 0x3400 && rune <= 0x4dbf) || // extension A
    (rune >= 0x3040 && rune <= 0x309f) || // hiragana
    (rune >= 0x30a0 && rune <= 0x30ff) || // katakana
    (rune >= 0xac00 && rune <= 0xd7af); // Hangul syllables
