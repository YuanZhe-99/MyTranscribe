/// Purpose: Keep each job's record, audio and outputs on disk.
/// Inputs: The app data directory, through the storage hub.
/// Returns: Jobs, and the paths belonging to them.
/// Side effects: Reads, writes and deletes files under `jobs/`.
/// Notes: Job folders are deliberately **not** a data module: sync, backup and
/// ZIP only touch the file names in the registry, so hours of private audio
/// never end up in a backup bundle. They live under the app directory so a
/// storage-path change still carries them along. See
/// `doc/en-us/data-formats.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart' show atomicWriteString;
import 'package:path/path.dart' as p;

import '../../../shared/services/transcribe_storage.dart';
import '../models/transcription_job.dart';

/// The record inside a job's folder.
const jobFileName = 'job.json';

/// The converted copy every window is cut from, and the viewer plays.
const normalizedAudioFileName = 'audio.mp3';

/// Where the split audio goes.
const chunksDirName = 'chunks';

/// Where speaker samples go.
const speakersDirName = 'speakers';

/// Where rendered transcripts go.
const exportsDirName = 'exports';

/// Reads and writes jobs.
class JobStore {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the storage hub's shape.
  JobStore._();

  /// Purpose: Locate a job's record.
  /// Inputs: [jobId].
  /// Returns: `Future<File>`.
  /// Side effects: May create the job folder.
  /// Notes: None.
  static Future<File> recordFile(String jobId) async {
    final dir = await TranscribeStorage.jobDir(jobId, create: true);
    return File(p.join(dir.path, jobFileName));
  }

  /// Purpose: Locate the converted audio for a job.
  /// Inputs: [jobId].
  /// Returns: `Future<File>`.
  /// Side effects: May create the job folder.
  /// Notes: This doubles as the transcript viewer's listening copy, which is
  /// why it outlives the windows cut from it.
  static Future<File> normalizedAudio(String jobId) async {
    final dir = await TranscribeStorage.jobDir(jobId, create: true);
    return File(p.join(dir.path, normalizedAudioFileName));
  }

  /// Purpose: Locate one window's audio.
  /// Inputs: [jobId], [index].
  /// Returns: `Future<File>`.
  /// Side effects: May create the chunks folder.
  /// Notes: Numbered with leading zeros so a folder listing is in order, which
  /// matters when somebody is looking at kept chunks to work out what went
  /// wrong.
  static Future<File> chunkFile(String jobId, int index) async {
    final dir = await _subdir(jobId, chunksDirName);
    return File(
      p.join(dir.path, 'chunk_${index.toString().padLeft(4, '0')}.mp3'),
    );
  }

  /// Purpose: Locate one window's raw reply.
  /// Inputs: [jobId], [index].
  /// Returns: `Future<File>`.
  /// Side effects: May create the chunks folder.
  /// Notes: Kept after the job finishes. It is what lets the speaker matching
  /// be re-run without uploading anything again, and what makes a bug report
  /// about a strange transcript answerable.
  static Future<File> chunkResponseFile(String jobId, int index) async {
    final dir = await _subdir(jobId, chunksDirName);
    return File(
      p.join(
        dir.path,
        'chunk_${index.toString().padLeft(4, '0')}.response.json',
      ),
    );
  }

  /// Purpose: Locate one speaker's voice sample.
  /// Inputs: [jobId], [speakerId].
  /// Returns: `Future<File>`.
  /// Side effects: May create the speakers folder.
  /// Notes: None.
  static Future<File> speakerSample(String jobId, String speakerId) async {
    final dir = await _subdir(jobId, speakersDirName);
    return File(p.join(dir.path, '$speakerId.wav'));
  }

  /// Purpose: Locate the folder rendered transcripts go into.
  /// Inputs: [jobId].
  /// Returns: `Future<Directory>`.
  /// Side effects: Creates the folder.
  /// Notes: None.
  static Future<Directory> exportsDir(String jobId) =>
      _subdir(jobId, exportsDirName);

  /// Purpose: Write a job's record.
  /// Inputs: [job].
  /// Returns: A future completing after the write.
  /// Side effects: Atomically writes `job.json`.
  /// Notes: Called after **every** finished window, which is what a resume
  /// reads. Atomic, so a crash mid-write leaves the previous record rather than
  /// half of a new one.
  ///
  /// The write is retried, because an atomic replace is a rename and on Windows
  /// a rename fails outright while anything else holds the file open — the jobs
  /// list reading it, a virus scanner, the search indexer. That collision lasts
  /// milliseconds, and losing an hour-long job to it would be absurd.
  static Future<void> save(TranscriptionJob job) async {
    final file = await recordFile(job.id);
    final content = const JsonEncoder.withIndent('  ').convert(job.toJson());
    await _retrying(() => atomicWriteString(file, content));
  }

  /// Purpose: Read one job.
  /// Inputs: [jobId].
  /// Returns: The job, or null when there is none or it cannot be read.
  /// Side effects: Reads the record.
  /// Notes: An unreadable record reads as absent rather than throwing: one
  /// damaged job must not stop the list from showing the others.
  static Future<TranscriptionJob?> load(String jobId) async {
    try {
      final file = await recordFile(jobId);
      if (!await file.exists()) return null;
      // Retried for the same reason the write is: a running job replaces this
      // file constantly, and a read that lands in that instant must not make
      // the job look as though it is not there.
      final raw = await _retrying(file.readAsString);
      if (raw.trim().isEmpty) return null;
      return TranscriptionJob.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Read every job, newest first.
  /// Inputs: None.
  /// Returns: The jobs.
  /// Side effects: Lists the jobs folder and reads each record.
  /// Notes: A folder without a readable record is skipped rather than shown as
  /// a broken row — it is usually a job that was deleted while being written.
  static Future<List<TranscriptionJob>> loadAll() async {
    final dir = await TranscribeStorage.jobsDir();
    if (!await dir.exists()) return const [];

    final jobs = <TranscriptionJob>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final job = await load(p.basename(entry.path));
      if (job != null && job.id.isNotEmpty) jobs.add(job);
    }
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  /// Purpose: Delete a job and everything belonging to it.
  /// Inputs: [jobId].
  /// Returns: A future completing after the deletion.
  /// Side effects: Removes the whole job folder.
  /// Notes: This removes the recording's converted copy and the transcript
  /// along with the record, which is what the user is told when they confirm.
  static Future<void> delete(String jobId) async {
    final dir = await TranscribeStorage.jobDir(jobId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Purpose: Remove the split audio, keeping everything else.
  /// Inputs: [jobId].
  /// Returns: A future completing after the deletion.
  /// Side effects: Deletes the chunk audio files.
  /// Notes: Run when a job finishes unless the user asked to keep them. The
  /// raw replies beside them are **not** deleted: they are small, and they are
  /// what lets the speaker matching be re-run without uploading again.
  static Future<void> deleteChunkAudio(String jobId) async {
    final dir = await _subdir(jobId, chunksDirName);
    if (!await dir.exists()) return;
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.mp3')) {
        try {
          await entry.delete();
        } catch (_) {
          // A file another process is holding is not worth failing a finished
          // job over; it will be removed with the job.
        }
      }
    }
  }

  /// Purpose: Work out how much disk a job is using.
  /// Inputs: [jobId].
  /// Returns: Bytes.
  /// Side effects: Walks the job folder.
  /// Notes: For the detail page, so the user can see what deleting one buys
  /// back. Audio dominates, so the figure is meaningful rather than noise.
  static Future<int> sizeOnDisk(String jobId) async {
    final dir = await TranscribeStorage.jobDir(jobId);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entry in dir.list(recursive: true)) {
      if (entry is File) {
        try {
          total += await entry.length();
        } catch (_) {}
      }
    }
    return total;
  }

  /// Purpose: Retry a file operation that a momentary lock defeated.
  /// Inputs: [action], and how many [attempts] to make.
  /// Returns: What [action] returns.
  /// Side effects: Whatever [action] does, possibly more than once.
  /// Notes: Internal helper used within this file only. The delay grows so the
  /// last attempt is roughly a quarter of a second after the first, which is
  /// far longer than a scanner or a concurrent reader holds a small file, and
  /// short enough that nobody notices. The final failure is thrown, not
  /// swallowed: a record that truly cannot be written is worth reporting.
  static Future<T> _retrying<T>(
    Future<T> Function() action, {
    int attempts = 6,
  }) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } on FileSystemException {
        if (attempt >= attempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 8 * attempt));
      }
    }
  }

  /// Purpose: Resolve one of a job's subfolders.
  /// Inputs: [jobId], [name].
  /// Returns: `Future<Directory>`.
  /// Side effects: Creates it when absent.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _subdir(String jobId, String name) async {
    final parent = await TranscribeStorage.jobDir(jobId, create: true);
    final dir = Directory(p.join(parent.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
