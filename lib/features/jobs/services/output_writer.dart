/// Purpose: Write the Markdown and plain-text transcripts a finished job
/// produces.
/// Inputs: The finished job and the transcript built from it.
/// Returns: The rendered text.
/// Side effects: None here; the caller writes the files.
/// Notes: The format is the one the original Python scripts produced, on
/// purpose: somebody with a folder of transcripts from those scripts and a
/// folder from this app should not be able to tell which is which.
///
/// The rendering itself is the viewer's, from `export_formatters.dart`, so the
/// file written beside a recording and the file exported from the viewer say
/// the same thing in the same shape. Only two things differ, and both are
/// deliberate: the header bullets are this app's own, and an unnamed speaker is
/// called `Speaker n` in English because the runner has no interface language
/// to ask.
///
/// These files are a rendering of the transcript **as the job finished it**.
/// Corrections made later in the viewer are exported from the viewer; nothing
/// rewrites what is next to the recording behind the user's back.
library;

import '../../transcript/models/transcript.dart';
import '../../transcript/services/export_formatters.dart';
import '../models/transcription_job.dart';

/// Purpose: Render a duration the way the scripts did.
/// Inputs: [seconds].
/// Returns: `mm:ss`, or `hh:mm:ss` past an hour.
/// Side effects: None.
/// Notes: The hour part is dropped below an hour rather than shown as a zero,
/// which is what the scripts did and what reads better in a heading. Past an
/// hour the hour is padded, which is where this differs from the viewer's
/// [readableTimestamp] — and why it is passed to the renderer explicitly.
String formatTimestamp(double seconds) {
  final total = seconds < 0 ? 0 : seconds.floor();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return hours > 0 ? '${hours.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

/// Purpose: Render the Markdown transcript written beside a recording.
/// Inputs: The [job] and the [transcript] it produced.
/// Returns: The document.
/// Side effects: None.
/// Notes: The header bullets are the scripts' own. When the recording has
/// speakers the body becomes speaker paragraphs instead of `## Segment n`
/// headings, because a heading between every two sentences of a conversation
/// is unreadable.
///
/// The names come from the transcript, so they are the ones the cross-window
/// matching settled on — one person, one name, from end to end. Rendering the
/// window-local labels instead would print every window's `S1` as though they
/// were one person, which is what an earlier build did.
String renderJobMarkdown(TranscriptionJob job, Transcript transcript) {
  final languages = job.options.languages;
  return renderMarkdown(
    transcript,
    (id) => transcript.nameFor(
      id,
      fallback: defaultSpeakerName,
      unknown: defaultUnknownSpeakerName,
    ),
    subtitleLines: [
      '- Audio: `${job.sourceName}`',
      '- Model: `${job.modelName}`',
      '- Language hint: '
          '`${languages.isEmpty ? 'auto-detect' : languages.join(', ')}`',
      if (job.plan case final plan? when !plan.single) ...[
        '- Chunk overlap: `${plan.overlapSeconds.toStringAsFixed(0)}` seconds',
        '- Overlap text is automatically deduplicated when possible.',
      ],
    ],
    timestamp: formatTimestamp,
  );
}

/// Purpose: Render the plain-text transcript written beside a recording.
/// Inputs: The [transcript].
/// Returns: The text.
/// Side effects: None.
/// Notes: Paragraphs separated by a blank line, exactly as the scripts wrote
/// them. With speakers, each paragraph is prefixed with the name.
String renderJobPlainText(Transcript transcript) => renderTxt(
  transcript,
  (id) => transcript.nameFor(
    id,
    fallback: defaultSpeakerName,
    unknown: defaultUnknownSpeakerName,
  ),
);
