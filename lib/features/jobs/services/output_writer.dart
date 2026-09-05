/// Purpose: Write the Markdown and plain-text transcripts a finished job
/// produces.
/// Inputs: The merged segments and what produced them.
/// Returns: The rendered text.
/// Side effects: None here; the caller writes the files.
/// Notes: The format is the one the original Python scripts produced, on
/// purpose: somebody with a folder of transcripts from those scripts and a
/// folder from this app should not be able to tell which is which. The richer
/// formats live in the transcript viewer's exports.
library;

import '../models/transcription_job.dart';
import 'transcript_merger.dart';

/// Purpose: Render a duration the way the scripts did.
/// Inputs: [seconds].
/// Returns: `mm:ss`, or `hh:mm:ss` past an hour.
/// Side effects: None.
/// Notes: The hour part is dropped below an hour rather than shown as a zero,
/// which is what the scripts did and what reads better in a heading.
String formatTimestamp(double seconds) {
  final total = seconds < 0 ? 0 : seconds.floor();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

/// Purpose: Render the Markdown transcript.
/// Inputs: The [job] and its merged [segments].
/// Returns: The document.
/// Side effects: None.
/// Notes: The header bullets and the `## Segment n (about mm:ss)` headings are
/// the scripts' own. When the recording has speakers the body becomes speaker
/// paragraphs instead, because segment headings for a conversation would put a
/// heading between every two sentences.
String renderMarkdown(TranscriptionJob job, List<MergedSegment> segments) {
  final hasSpeakers = segments.any((s) => s.localSpeaker != null);
  final lines = <String>[
    '# Transcript',
    '',
    '- Audio: `${job.sourceName}`',
    '- Model: `${job.modelName}`',
    '- Language hint: `${job.options.languages.isEmpty ? 'auto-detect' : job.options.languages.join(', ')}`',
    if (job.plan case final plan? when !plan.single)
      '- Chunk overlap: `${plan.overlapSeconds.toStringAsFixed(0)}` seconds',
    if (job.plan case final plan? when !plan.single)
      '- Overlap text is automatically deduplicated when possible.',
    '',
  ];

  if (hasSpeakers) {
    for (final paragraph in groupBySpeaker(segments)) {
      final speaker = paragraph.speaker ?? 'Speaker';
      lines
        ..add(
          '**$speaker** [${formatTimestamp(paragraph.startSeconds)}]: '
          '${paragraph.text}',
        )
        ..add('');
    }
    return '${lines.join('\n').trimRight()}\n';
  }

  for (var index = 0; index < segments.length; index++) {
    lines
      ..add(
        '## Segment ${index + 1} '
        '(about ${formatTimestamp(segments[index].startSeconds)})',
      )
      ..add('')
      ..add(segments[index].text)
      ..add('');
  }
  return '${lines.join('\n').trimRight()}\n';
}

/// Purpose: Render the plain-text transcript.
/// Inputs: The merged [segments].
/// Returns: The text.
/// Side effects: None.
/// Notes: Paragraphs separated by a blank line, exactly as the scripts wrote
/// them. With speakers, each paragraph is prefixed with the name.
String renderPlainText(List<MergedSegment> segments) {
  final hasSpeakers = segments.any((s) => s.localSpeaker != null);
  if (!hasSpeakers) {
    return '${segments.map((s) => s.text).join('\n\n').trimRight()}\n';
  }
  return '${groupBySpeaker(segments).map((p) => '${p.speaker ?? 'Speaker'}: ${p.text}').join('\n\n').trimRight()}\n';
}

/// A run of consecutive segments from one speaker.
class SpeakerParagraph {
  /// Who was speaking, when it is known.
  final String? speaker;

  /// Where the run starts, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  final double endSeconds;

  /// What they said, joined.
  final String text;

  /// Purpose: Create a paragraph.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SpeakerParagraph({
    required this.speaker,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
}

/// Purpose: Join consecutive segments from one speaker into paragraphs.
/// Inputs: [segments].
/// Returns: The paragraphs, in order.
/// Side effects: None.
/// Notes: A diarized transcript read segment by segment is a wall of one-line
/// rows; grouping is what makes it read like a conversation. The viewer offers
/// the ungrouped view for correcting, which is the other thing it is for.
List<SpeakerParagraph> groupBySpeaker(List<MergedSegment> segments) {
  final paragraphs = <SpeakerParagraph>[];
  for (final segment in segments) {
    final last = paragraphs.isEmpty ? null : paragraphs.last;
    if (last != null && last.speaker == segment.localSpeaker) {
      paragraphs[paragraphs.length - 1] = SpeakerParagraph(
        speaker: last.speaker,
        startSeconds: last.startSeconds,
        endSeconds: segment.endSeconds,
        text: '${last.text} ${segment.text}'.trim(),
      );
    } else {
      paragraphs.add(
        SpeakerParagraph(
          speaker: segment.localSpeaker,
          startSeconds: segment.startSeconds,
          endSeconds: segment.endSeconds,
          text: segment.text,
        ),
      );
    }
  }
  return paragraphs;
}
