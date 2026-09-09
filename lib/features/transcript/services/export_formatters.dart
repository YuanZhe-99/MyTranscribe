/// Purpose: Render a transcript in each format somebody might want it in.
/// Inputs: A transcript and the names its speakers go by.
/// Returns: Text.
/// Side effects: None.
/// Notes: All pure, so every format is testable without a file, a viewer or a
/// share sheet. Which formats are offered is decided elsewhere: subtitles from
/// a transcript with no real timestamps would be confidently wrong, and the
/// viewer disables them with the reason rather than producing them. See
/// `doc/en-us/features/exports.md`.
library;

import '../models/transcript.dart';

/// The formats a transcript can be saved as.
enum ExportFormat {
  /// Plain text, speaker-prefixed paragraphs.
  txt,

  /// Markdown, the format the original scripts wrote.
  markdown,

  /// SubRip subtitles.
  srt,

  /// WebVTT subtitles.
  vtt,

  /// The app's own JSON, everything included.
  json,

  /// One row per segment.
  csv;

  /// The file extension, without the dot.
  String get extension => switch (this) {
    ExportFormat.txt => 'txt',
    ExportFormat.markdown => 'md',
    ExportFormat.srt => 'srt',
    ExportFormat.vtt => 'vtt',
    ExportFormat.json => 'json',
    ExportFormat.csv => 'csv',
  };

  /// Whether this format states a time for every line.
  ///
  /// A transcript whose times are the app's own estimates must not be offered
  /// in one of these: a subtitle file that is a minute out is worse than no
  /// subtitle file, because it looks like it works.
  bool get needsRealTimestamps =>
      this == ExportFormat.srt || this == ExportFormat.vtt;
}

/// Purpose: Render a timestamp for a subtitle file.
/// Inputs: [seconds] and the [millisecondSeparator] the format uses.
/// Returns: `hh:mm:ss,mmm` or `hh:mm:ss.mmm`.
/// Side effects: None.
/// Notes: Both formats want the hours field even at zero, unlike the headings
/// in the Markdown transcript — players are stricter than readers.
String subtitleTimestamp(double seconds, {String millisecondSeparator = ','}) {
  final total = seconds < 0 ? 0.0 : seconds;
  final whole = total.floor();
  final millis = ((total - whole) * 1000).round().clamp(0, 999);
  final hh = (whole ~/ 3600).toString().padLeft(2, '0');
  final mm = ((whole % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (whole % 60).toString().padLeft(2, '0');
  return '$hh:$mm:$ss$millisecondSeparator'
      '${millis.toString().padLeft(3, '0')}';
}

/// Purpose: Render a timestamp for a reader.
/// Inputs: [seconds].
/// Returns: `mm:ss`, or `h:mm:ss` past an hour.
/// Side effects: None.
/// Notes: The hour is dropped below an hour, which is how somebody scrubbing a
/// forty-minute lecture thinks about it.
String readableTimestamp(double seconds) {
  final total = seconds < 0 ? 0 : seconds.floor();
  final hours = total ~/ 3600;
  final mm = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (total % 60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// A run of consecutive lines from one speaker.
class SpeakerRun {
  /// Who was speaking, already named.
  final String? speaker;

  /// Where the run starts, in seconds.
  final double startSeconds;

  /// Where it ends, in seconds.
  final double endSeconds;

  /// What they said, joined.
  final String text;

  /// Purpose: Create a run.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SpeakerRun({
    required this.speaker,
    required this.startSeconds,
    required this.endSeconds,
    required this.text,
  });
}

/// Purpose: Join consecutive lines from one speaker into paragraphs.
/// Inputs: The [transcript] and how to [nameOf] each speaker.
/// Returns: The runs, in order.
/// Side effects: None.
/// Notes: A diarized transcript read line by line is a wall of one-line rows.
/// Grouping is what makes it read like a conversation; the viewer keeps the
/// ungrouped view for correcting, which is the other thing it is for.
List<SpeakerRun> groupBySpeaker(
  Transcript transcript,
  String? Function(String? speakerId) nameOf,
) {
  final runs = <SpeakerRun>[];
  for (final segment in transcript.segments) {
    final name = nameOf(segment.speakerId);
    final last = runs.isEmpty ? null : runs.last;
    if (last != null && last.speaker == name) {
      runs[runs.length - 1] = SpeakerRun(
        speaker: name,
        startSeconds: last.startSeconds,
        endSeconds: segment.endSeconds,
        text: '${last.text} ${segment.text}'.trim(),
      );
    } else {
      runs.add(
        SpeakerRun(
          speaker: name,
          startSeconds: segment.startSeconds,
          endSeconds: segment.endSeconds,
          text: segment.text,
        ),
      );
    }
  }
  return runs;
}

/// Purpose: Render a transcript as plain text.
/// Inputs: The [transcript] and how to [nameOf] each speaker.
/// Returns: The text.
/// Side effects: None.
/// Notes: Paragraphs separated by a blank line, as the original scripts wrote
/// them; with speakers, each paragraph carries the name.
String renderTxt(Transcript transcript, String? Function(String?) nameOf) {
  if (!transcript.hasSpeakers) {
    return '${transcript.segments.map((s) => s.text).join('\n\n').trim()}\n';
  }
  final runs = groupBySpeaker(transcript, nameOf);
  return '${runs.map((r) => r.speaker == null ? r.text : '${r.speaker}: ${r.text}').join('\n\n').trim()}\n';
}

/// Purpose: Render a transcript as Markdown.
/// Inputs: The [transcript], a [title], the [subtitleLines] for the header, how
/// to [nameOf] each speaker, and how to render a [timestamp].
/// Returns: The document.
/// Side effects: None.
/// Notes: The plain form matches what the original scripts produced, on
/// purpose: a folder of transcripts from those scripts and a folder from this
/// app should be indistinguishable. That is also why [timestamp] is a
/// parameter: the scripts padded the hour and [readableTimestamp] does not, so
/// the files written beside a recording pass their own formatter and an export
/// takes the reader's one.
String renderMarkdown(
  Transcript transcript,
  String? Function(String?) nameOf, {
  String title = 'Transcript',
  List<String> subtitleLines = const [],
  String Function(double seconds) timestamp = readableTimestamp,
}) {
  final lines = <String>['# $title', '', ...subtitleLines, ''];

  if (transcript.hasSpeakers) {
    for (final run in groupBySpeaker(transcript, nameOf)) {
      lines
        ..add(
          '**${run.speaker ?? defaultUnknownSpeakerName}** '
          '[${timestamp(run.startSeconds)}]: ${run.text}',
        )
        ..add('');
    }
    return '${lines.join('\n').trimRight()}\n';
  }

  for (var index = 0; index < transcript.segments.length; index++) {
    final segment = transcript.segments[index];
    lines
      ..add(
        '## Segment ${index + 1} '
        '(about ${timestamp(segment.startSeconds)})',
      )
      ..add('')
      ..add(segment.text)
      ..add('');
  }
  return '${lines.join('\n').trimRight()}\n';
}

/// Purpose: Name an unnamed speaker where there is no interface language to ask.
/// Inputs: The [number].
/// Returns: `Speaker <number>`.
/// Side effects: None.
/// Notes: For the job runner, which writes the transcript files beside a
/// recording with no `BuildContext` and therefore no localizations. Everything
/// the user exports from the viewer uses the localized fallback instead, and
/// the two only differ for a speaker nobody has named.
String defaultSpeakerName(int number) => 'Speaker $number';

/// What a line nobody is credited with is called, outside the interface.
///
/// English on purpose, and for the same reason as [defaultSpeakerName]: the job
/// runner writes files with no localizations to ask. The viewer passes its own
/// translated word instead. Before this existed, a diarized Markdown export
/// printed a bare `**Speaker**` over every line the matching could not place.
const defaultUnknownSpeakerName = 'Unknown';

/// Purpose: Render a transcript as SubRip subtitles.
/// Inputs: The [transcript] and how to [nameOf] each speaker.
/// Returns: The subtitle file.
/// Side effects: None.
/// Notes: The speaker's name goes on its own line above the text, which is how
/// SubRip carries one at all — it has no speaker field.
String renderSrt(Transcript transcript, String? Function(String?) nameOf) {
  final out = StringBuffer();
  for (var index = 0; index < transcript.segments.length; index++) {
    final segment = transcript.segments[index];
    final name = nameOf(segment.speakerId);
    out
      ..writeln(index + 1)
      ..writeln(
        '${subtitleTimestamp(segment.startSeconds)} --> '
        '${subtitleTimestamp(segment.endSeconds)}',
      );
    if (name != null) out.writeln('$name:');
    out
      ..writeln(segment.text)
      ..writeln();
  }
  return out.toString();
}

/// Purpose: Render a transcript as WebVTT.
/// Inputs: The [transcript] and how to [nameOf] each speaker.
/// Returns: The subtitle file.
/// Side effects: None.
/// Notes: WebVTT does have a speaker tag, so the name goes in one rather than
/// on a line of its own — players can then style each speaker differently.
String renderVtt(Transcript transcript, String? Function(String?) nameOf) {
  final out = StringBuffer()
    ..writeln('WEBVTT')
    ..writeln();
  for (final segment in transcript.segments) {
    final name = nameOf(segment.speakerId);
    out.writeln(
      '${subtitleTimestamp(segment.startSeconds, millisecondSeparator: '.')}'
      ' --> '
      '${subtitleTimestamp(segment.endSeconds, millisecondSeparator: '.')}',
    );
    out
      ..writeln(name == null ? segment.text : '<v $name>${segment.text}')
      ..writeln();
  }
  return out.toString();
}

/// Purpose: Render a transcript as a comma-separated table.
/// Inputs: The [transcript] and how to [nameOf] each speaker.
/// Returns: The table.
/// Side effects: None.
/// Notes: Quoted per RFC 4180, and led by a byte-order mark: without it Excel
/// on Windows opens a Chinese transcript as mojibake, which is where most of
/// these will be opened.
String renderCsv(Transcript transcript, String? Function(String?) nameOf) {
  final out = StringBuffer('﻿')..writeln('index,start,end,speaker,text');
  for (var index = 0; index < transcript.segments.length; index++) {
    final segment = transcript.segments[index];
    out.writeln(
      [
        '${index + 1}',
        segment.startSeconds.toStringAsFixed(3),
        segment.endSeconds.toStringAsFixed(3),
        nameOf(segment.speakerId) ?? '',
        segment.text,
      ].map(_csvField).join(','),
    );
  }
  return out.toString();
}

/// Purpose: Quote one field for a comma-separated file.
/// Inputs: [value].
/// Returns: The field, quoted when it has to be.
/// Side effects: None.
/// Notes: Internal helper used within this file only. A quote inside a quoted
/// field is doubled, which is the whole of RFC 4180's escaping.
String _csvField(String value) {
  if (!value.contains(RegExp('[",\n\r]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
