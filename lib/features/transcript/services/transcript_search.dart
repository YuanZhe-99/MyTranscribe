/// Purpose: Find a phrase in a transcript and mark where it occurs.
/// Inputs: A transcript and what to look for.
/// Returns: Match positions.
/// Side effects: None.
/// Notes: Pure and case-insensitive, with no word boundaries: a transcript is
/// as likely to be Chinese as English, and Chinese has no spaces to anchor a
/// word boundary to. Matching plain substrings treats both alike.
library;

import '../models/transcript.dart';

/// Where one occurrence is.
class SearchHit {
  /// Which segment it is in, by position in the list.
  final int segmentIndex;

  /// Where the match starts in that segment's text.
  final int start;

  /// Where it ends.
  final int end;

  /// Purpose: Create a hit.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SearchHit({
    required this.segmentIndex,
    required this.start,
    required this.end,
  });
}

/// Purpose: Find every occurrence of a phrase.
/// Inputs: The [transcript] and the [query].
/// Returns: The hits, in reading order.
/// Side effects: None.
/// Notes: An empty or whitespace-only query finds nothing rather than
/// everything, so clearing the box clears the highlights.
List<SearchHit> findInTranscript(Transcript transcript, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  final hits = <SearchHit>[];
  for (var index = 0; index < transcript.segments.length; index++) {
    final haystack = transcript.segments[index].text.toLowerCase();
    var from = 0;
    while (true) {
      final at = haystack.indexOf(needle, from);
      if (at < 0) break;
      hits.add(
        SearchHit(segmentIndex: index, start: at, end: at + needle.length),
      );
      from = at + needle.length;
    }
  }
  return hits;
}

/// Purpose: Split a line into the parts that match and the parts that do not.
/// Inputs: The [text] and the [query].
/// Returns: Pieces in order, each flagged as matching or not.
/// Side effects: None.
/// Notes: Returned as pieces rather than as offsets so the widget that draws
/// them cannot get the arithmetic wrong; the offsets are this function's
/// problem, once.
List<(String text, bool matches)> highlightParts(String text, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return [(text, false)];

  final haystack = text.toLowerCase();
  final parts = <(String, bool)>[];
  var from = 0;
  while (true) {
    final at = haystack.indexOf(needle, from);
    if (at < 0) break;
    if (at > from) parts.add((text.substring(from, at), false));
    parts.add((text.substring(at, at + needle.length), true));
    from = at + needle.length;
  }
  if (from < text.length) parts.add((text.substring(from), false));
  return parts.isEmpty ? [(text, false)] : parts;
}
