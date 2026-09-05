/// Purpose: Join the windows of a split recording back into one transcript.
/// Inputs: The per-window results, and the plan that produced them.
/// Returns: One ordered list of segments.
/// Side effects: None — pure, so both rules are testable without a network.
/// Notes: Consecutive windows share a stretch of audio, so the same words come
/// back twice. Two rules remove the duplication: an exact one when the model
/// returned times, and a text one when it did not. See
/// `doc/en-us/algorithms/overlap-merge.md`.
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
  /// Inputs: [text].
  /// Returns: A new [MergedSegment].
  /// Side effects: None.
  /// Notes: None.
  MergedSegment withText(String text) => MergedSegment(
    startSeconds: startSeconds,
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

/// Purpose: Join windows that carry real times.
/// Inputs: The per-window [segments], keyed by window index, the window start
/// times, and the [overlapSeconds].
/// Returns: One ordered list.
/// Side effects: None.
/// Notes: The cut point sits in the middle of the shared stretch: the earlier
/// window keeps what ends before it, the later one keeps what starts after.
/// The boundary pair is then checked for repeated words, in case both windows
/// transcribed the same phrase slightly differently.
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

  // Two windows can transcribe the same phrase either side of the cut. Trim the
  // repetition at each seam rather than across the whole transcript, so a
  // genuinely repeated sentence elsewhere is left alone.
  for (var index = 1; index < merged.length; index++) {
    final trimmed = removeRepeatedPrefix(
      merged[index - 1].text,
      merged[index].text,
    );
    if (trimmed != merged[index].text) {
      merged[index] = merged[index].withText(trimmed);
    }
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
/// Inputs: [previous] what has been kept, [current] what came next.
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
String removeRepeatedPrefix(String previous, String current) {
  if (previous.isEmpty || current.isEmpty) return current;

  final previousTokens = _tokenize(previous);
  final currentTokens = _tokenize(current);
  if (previousTokens.isEmpty || currentTokens.isEmpty) return current;

  final maximum = [
    maxOverlapTokens,
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
