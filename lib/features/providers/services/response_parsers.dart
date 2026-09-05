/// Purpose: Read the reply formats these endpoints return into one shape.
/// Inputs: A response body and the format it was asked for.
/// Returns: Segments, with whatever times and speaker labels were present.
/// Side effects: None — pure, so every format is testable without a network.
/// Notes: Four shapes reduce to one: plain text, a bare `{"text": …}`, a
/// verbose object with segments, and a diarized one with speakers. Everything
/// above this sees only `TranscriptionResult`.
library;

import 'dart:convert';

import 'provider_dialect.dart';

/// Purpose: Read a reply into a result.
/// Inputs: [body], the [format] that was asked for, and the [windowSeconds] of
/// audio it covered.
/// Returns: A [TranscriptionResult].
/// Side effects: None.
/// Notes: An endpoint sometimes ignores the format that was asked for, so the
/// body is inspected rather than trusted: a JSON object is parsed as one
/// whatever `format` says, and anything else is taken as plain text. That is
/// more forgiving than switching on `format` alone, and it costs nothing.
TranscriptionResult parseTranscriptionBody(
  String body,
  String format,
  double windowSeconds,
) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    throw const TranscriptionException(
      TranscriptionFailure.badResponse,
      'The source returned an empty reply.',
    );
  }

  // `text`, `srt` and `vtt` come back as plain text, and so does anything an
  // endpoint returned without the JSON it promised.
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
    return TranscriptionResult(
      text: trimmed,
      segments: [
        RawSegment(startSeconds: 0, endSeconds: windowSeconds, text: trimmed),
      ],
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException catch (error) {
    throw TranscriptionException(
      TranscriptionFailure.badResponse,
      'The reply could not be read: ${error.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const TranscriptionException(
      TranscriptionFailure.badResponse,
      'The reply was not a transcription object.',
    );
  }

  final segments = _readSegments(decoded);
  final text = _readText(decoded, segments);

  if (segments.isEmpty) {
    if (text.isEmpty) {
      throw const TranscriptionException(
        TranscriptionFailure.badResponse,
        'The reply carried no transcript.',
      );
    }
    return TranscriptionResult(
      text: text,
      segments: [
        RawSegment(startSeconds: 0, endSeconds: windowSeconds, text: text),
      ],
    );
  }

  return TranscriptionResult(
    text: text,
    segments: segments,
    hasRealTimestamps: true,
    hasSpeakers: segments.any((s) => s.speaker != null),
  );
}

/// Purpose: Pull the segments out of a decoded reply.
/// Inputs: [json].
/// Returns: The segments, empty when the reply has none.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Both the verbose and the
/// diarized shapes put them under `segments`; only the diarized one adds a
/// speaker, which may be a number or a string depending on the service.
List<RawSegment> _readSegments(Map<String, dynamic> json) {
  final raw = json['segments'];
  if (raw is! List) return const [];

  final segments = <RawSegment>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final text = item['text'];
    if (text is! String) continue;
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;

    segments.add(
      RawSegment(
        startSeconds: _toDouble(item['start']) ?? 0,
        endSeconds: _toDouble(item['end']) ?? _toDouble(item['start']) ?? 0,
        text: trimmed,
        speaker: _readSpeaker(item['speaker']),
      ),
    );
  }
  return segments;
}

/// Purpose: Read the whole-window text.
/// Inputs: [json], and the [segments] already parsed.
/// Returns: The text.
/// Side effects: None.
/// Notes: Internal helper used within this file only. The top-level `text` is
/// preferred where it exists, because it is what the service considers the
/// transcript; joining the segments is the fallback for a reply that has
/// segments and no summary.
String _readText(Map<String, dynamic> json, List<RawSegment> segments) {
  final text = json['text'];
  if (text is String && text.trim().isNotEmpty) return text.trim();
  return segments.map((s) => s.text).join(' ').trim();
}

/// Purpose: Normalize a speaker label.
/// Inputs: [value].
/// Returns: A label, or null when the reply named no speaker.
/// Side effects: None.
/// Notes: Internal helper used within this file only. One service labels
/// speakers with strings and another with integers; both become a string here,
/// with a number prefixed so `0` cannot be mistaken for an absent value further
/// down.
String? _readSpeaker(Object? value) => switch (value) {
  final String s when s.trim().isNotEmpty => s.trim(),
  final int n => 'S$n',
  final num n => 'S${n.round()}',
  _ => null,
};

/// Purpose: Read a number that may be sent as a string.
/// Inputs: [value].
/// Returns: The number, or null.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
double? _toDouble(Object? value) => switch (value) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s),
  _ => null,
};
