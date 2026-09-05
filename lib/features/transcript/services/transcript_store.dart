/// Purpose: Keep each job's transcript on disk, and build one from a finished
/// job.
/// Inputs: The job folder, through the job store.
/// Returns: Transcripts.
/// Side effects: Reads and writes `transcript.json`.
/// Notes: Beside the job record rather than in a data module, for the same
/// reason the audio is: a transcript is the private content of a recording and
/// has no business in a backup bundle that syncs to a server. See
/// `doc/en-us/architecture.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart' show atomicWriteString;
import 'package:path/path.dart' as p;

import '../../../shared/services/transcribe_storage.dart';
import '../../jobs/services/transcript_merger.dart';
import '../models/transcript.dart';

/// The transcript inside a job's folder.
const transcriptFileName = 'transcript.json';

/// Reads and writes transcripts.
class TranscriptStore {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the job store's shape.
  TranscriptStore._();

  /// Purpose: Locate a job's transcript file.
  /// Inputs: [jobId].
  /// Returns: `Future<File>`.
  /// Side effects: May create the job folder.
  /// Notes: None.
  static Future<File> fileFor(String jobId) async {
    final dir = await TranscribeStorage.jobDir(jobId, create: true);
    return File(p.join(dir.path, transcriptFileName));
  }

  /// Purpose: Read a job's transcript.
  /// Inputs: [jobId].
  /// Returns: The transcript, or null when there is none.
  /// Side effects: Reads the file.
  /// Notes: An unreadable file reads as absent. A job whose transcript will not
  /// parse can still be opened, re-run and deleted, which is more use than an
  /// error that blocks all three.
  static Future<Transcript?> load(String jobId) async {
    try {
      final file = await fileFor(jobId);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return Transcript.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Write a job's transcript.
  /// Inputs: [transcript].
  /// Returns: A future completing after the write.
  /// Side effects: Atomically writes `transcript.json`.
  /// Notes: Atomic, because this file is what the user's corrections live in
  /// and a half-written one would lose them all.
  static Future<void> save(Transcript transcript) async {
    final file = await fileFor(transcript.jobId);
    await atomicWriteString(
      file,
      const JsonEncoder.withIndent('  ').convert(transcript.toJson()),
    );
  }

  /// Purpose: Build a transcript from a job's merged segments.
  /// Inputs: The [jobId] and the merged [segments].
  /// Returns: A [Transcript].
  /// Side effects: None.
  /// Notes: Speakers are created in the order they first speak, so "Speaker 1"
  /// is the first voice heard rather than whichever label the source happened
  /// to allocate first. A segment with no timestamp of its own is marked
  /// approximate here, once, so nothing downstream has to work it out again.
  static Transcript fromMerged(
    String jobId,
    List<MergedSegment> segments, {
    required bool timestamped,
    Map<String, String> speakerMap = const {},
  }) {
    final speakers = <String, Speaker>{};
    final map = Map<String, String>.of(speakerMap);
    final lines = <TranscriptSegment>[];

    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      String? speakerId;

      if (segment.localSpeaker case final label?) {
        final key = '${segment.chunkIndex}:$label';
        // The cross-window matching has usually already decided this. A label
        // it did not place — a window whose overlap was inconclusive — becomes
        // a new speaker here rather than being dropped.
        speakerId = map[key];
        if (speakerId == null) {
          speakerId = 'spk_${map.length + 1}';
          map[key] = speakerId;
        }
        speakers.putIfAbsent(
          speakerId,
          () => Speaker(id: speakerId!, colorIndex: speakers.length),
        );
      }

      lines.add(
        TranscriptSegment(
          id: 'seg_$index',
          chunkIndex: segment.chunkIndex,
          startSeconds: segment.startSeconds,
          endSeconds: segment.endSeconds,
          text: segment.text,
          approximate: !timestamped,
          speakerId: speakerId,
        ),
      );
    }

    return Transcript(
      jobId: jobId,
      speakers: speakers.values.toList(),
      speakerMap: map,
      segments: lines,
    );
  }
}
