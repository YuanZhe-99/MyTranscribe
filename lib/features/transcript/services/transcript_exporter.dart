/// Purpose: Put a rendered transcript somewhere the user can get at it.
/// Inputs: A transcript, a format, and the job it came from.
/// Returns: The file name written, or null when the user backed out.
/// Side effects: Writes a file, and opens a save dialog or a share sheet.
/// Notes: Desktops have a save-as dialog and mobiles do not, so the two take
/// different routes to the same result. The file is written into the job's
/// exports folder either way, which means a share that is cancelled still
/// leaves something to find. See `doc/en-us/features/exports.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../jobs/services/job_store.dart';
import '../models/transcript.dart';
import 'export_formatters.dart';

/// Writes transcripts out.
class TranscriptExporter {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the stores' shape.
  TranscriptExporter._();

  /// Purpose: Work out what to call an exported file.
  /// Inputs: The transcription's own [title], if it has one, and the
  /// [sourceName] of the recording.
  /// Returns: A file-name stem.
  /// Side effects: None.
  /// Notes: The user's name wins here, and only here. The two files a job
  /// writes beside its recording keep the recording's name, because a folder of
  /// those is read by file name; a file the user is deliberately saving
  /// somewhere should carry the name they chose.
  ///
  /// The characters Windows forbids in a file name become underscores. A title
  /// is free text and "Week 2: intro" is a perfectly reasonable thing to type,
  /// but it would make the save dialog fail with nothing useful to say.
  static String exportFileStem(String? title, String sourceName) {
    final trimmed = title?.trim() ?? '';
    if (trimmed.isEmpty) return p.basenameWithoutExtension(sourceName);
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
  }

  /// Purpose: Render a transcript and hand it to the user.
  /// Inputs: The [transcript], the [format], the [sourceName] and [modelName]
  /// for the Markdown header, the transcription's own [title] where it has one,
  /// and how to [nameOf] each speaker.
  /// Returns: The file name, or null when the user cancelled.
  /// Side effects: Writes into the job's exports folder, then opens a save
  /// dialog on desktop or a share sheet on mobile.
  /// Notes: The speaker naming comes from the caller so the file says exactly
  /// what the screen says — including a name the user typed a moment ago and
  /// has not saved anywhere else yet. The header keeps saying which recording
  /// this came from even when the file is named after the transcription.
  static Future<String?> export({
    required Transcript transcript,
    required ExportFormat format,
    required String sourceName,
    required String modelName,
    required String? Function(String?) nameOf,
    String? title,
  }) async {
    final stem = exportFileStem(title, sourceName);
    final fileName = '$stem.transcript.${format.extension}';
    final content = render(
      transcript: transcript,
      format: format,
      sourceName: sourceName,
      modelName: modelName,
      nameOf: nameOf,
    );

    final dir = await JobStore.exportsDir(transcript.jobId);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(content);

    if (_isDesktop) {
      final target = await FilePicker.platform.saveFile(
        fileName: fileName,
        bytes: utf8.encode(content),
      );
      // A cancelled dialog still leaves the copy in the exports folder, so the
      // work is not lost; it just is not where the user was about to put it.
      if (target == null) return null;
      return p.basename(target);
    }

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: fileName),
    );
    return fileName;
  }

  /// Purpose: Render a transcript without writing anything.
  /// Inputs: The [transcript], the [format], the [sourceName], the [modelName]
  /// and how to [nameOf] each speaker.
  /// Returns: The text.
  /// Side effects: None.
  /// Notes: Separated from the writing so a test can check the content of every
  /// format without touching a file or a picker.
  static String render({
    required Transcript transcript,
    required ExportFormat format,
    required String sourceName,
    required String modelName,
    required String? Function(String?) nameOf,
  }) => switch (format) {
    ExportFormat.txt => renderTxt(transcript, nameOf),
    ExportFormat.markdown => renderMarkdown(
      transcript,
      nameOf,
      subtitleLines: [
        '- Audio: `$sourceName`',
        if (modelName.isNotEmpty) '- Model: `$modelName`',
      ],
    ),
    ExportFormat.srt => renderSrt(transcript, nameOf),
    ExportFormat.vtt => renderVtt(transcript, nameOf),
    ExportFormat.csv => renderCsv(transcript, nameOf),
    ExportFormat.json => const JsonEncoder.withIndent(
      '  ',
    ).convert(transcript.toJson()),
  };

  /// Whether this platform has a save-as dialog.
  static bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}
