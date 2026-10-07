import 'package:myapps_ai_online/myapps_ai_online.dart' as shared;

import 'provider_dialect.dart';

/// Purpose: Parse online transcription. Inputs: body, format, windowSeconds.
/// Returns: Result. Side effects: None. Notes: Shared parser preserves timestamps.
TranscriptionResult parseTranscriptionBody(
  String body,
  String format,
  double windowSeconds,
) {
  try {
    final result = shared.parseTranscriptionBody(body, windowSeconds);
    return TranscriptionResult(
      text: result.text,
      segments: [
        for (final segment in result.segments)
          RawSegment(
            startSeconds: segment.startSeconds,
            endSeconds: segment.endSeconds,
            text: segment.text,
            speaker: segment.speaker,
          ),
      ],
      hasRealTimestamps: result.hasRealTimestamps,
      hasSpeakers: result.hasSpeakers,
    );
  } on shared.OnlineTranscriptionException catch (error) {
    throw TranscriptionException(
      TranscriptionFailure.values.byName(error.kind.name),
      error.message ?? 'The source returned an unreadable reply.',
    );
  }
}
