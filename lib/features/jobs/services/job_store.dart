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
  /// Returns: How many window files could not be deleted.
  /// Side effects: Deletes the chunk audio files.
  /// Notes: Run when a job finishes unless the user asked to keep them. The
  /// raw replies beside them are **not** deleted: they are small, and they are
  /// what lets the speaker matching be re-run without uploading again.
  ///
  /// Each delete is retried, for the reason [save] is: on Windows a delete
  /// fails outright while anything else holds the file open, and the last
  /// window is the file most likely to be held — a scanner or the search
  /// indexer reaches a freshly written file within seconds, and this runs
  /// seconds after the last one was written.
  ///
  /// A file that survives even the retries is still not worth failing a
  /// finished job over, so the count is returned rather than thrown, and
  /// [JobRunner.restore] sweeps whatever was left behind at the next start.
  static Future<int> deleteChunkAudio(String jobId) async {
    final dir = await _subdir(jobId, chunksDirName);
    if (!await dir.exists()) return 0;

    var left = 0;
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.mp3')) continue;
      try {
        await _retrying(entry.delete, attempts: 10);
      } catch (_) {
        left++;
      }
    }
    return left;
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

  /// Purpose: Say how much room a job takes and whether its audio is still
  /// there.
  /// Inputs: [jobId].
  /// Returns: The size in bytes, and whether the converted copy exists.
  /// Side effects: Walks the job folder.
  /// Notes: One walk for both answers, because the page asks both at once. The
  /// converted copy is almost all of the size — a third of the original
  /// recording — so the figure and the offer to remove it belong together.
  static Future<({int bytes, bool hasConvertedAudio})> storageInfo(
    String jobId,
  ) async {
    final audio = await normalizedAudio(jobId);
    return (
      bytes: await sizeOnDisk(jobId),
      hasConvertedAudio: await audio.exists(),
    );
  }

  /// Purpose: Remove the converted audio, keeping the transcript.
  /// Inputs: [jobId].
  /// Returns: A future completing after the deletion.
  /// Side effects: Deletes `audio.mp3` and any window audio beside it.
  /// Notes: The converted copy outlives the windows on purpose — it is what the
  /// viewer plays — but it is a third of the size of the recording, and a
  /// transcript that has been read and corrected does not need it any more.
  /// Nothing else goes: the record, the transcript, the raw replies and the
  /// speaker samples all stay, so the transcript is still readable, still
  /// correctable, and the speaker matching can still be re-run.
  static Future<void> deleteConvertedAudio(String jobId) async {
    await deleteChunkAudio(jobId);
    final audio = await normalizedAudio(jobId);
    if (!await audio.exists()) return;
    try {
      await _retrying(audio.delete, attempts: 10);
    } catch (_) {
      // Held by the player, most likely. It will still be there next time, and
      // the offer to remove it with it.
    }
  }

  /// Purpose: Find something for the viewer to play.
  /// Inputs: [jobId] and the [sourcePath] the job was created from.
  /// Returns: The file to play, or null when neither is on this device.
  /// Side effects: None beyond reading the file system.
  /// Notes: The converted copy first: it is small, it is certainly readable,
  /// and on a phone it is often the only copy the app can still reach after the
  /// file picker's cache is emptied. The original is the fallback, which covers
  /// both a recording small enough to have been sent whole — those never had a
  /// converted copy at all, and the viewer used to say there was nothing to
  /// play with the recording sitting right there — and one whose copy the user
  /// has since removed.
  static Future<File?> playbackAudio(String jobId, String sourcePath) async {
    final converted = await normalizedAudio(jobId);
    if (await converted.exists()) return converted;
    if (sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    return await source.exists() ? source : null;
  }

  /// Purpose: Retry a file operation that a momentary lock defeated.
  /// Inputs: [action], and how many [attempts] to make.
  /// Returns: What [action] returns.
  /// Side effects: Whatever [action] does, possibly more than once.
  /// Notes: Internal helper used within this file only. The delay grows with
  /// each attempt, so six attempts span about a tenth of a second and ten span
  /// about a third — far longer than a scanner or a concurrent reader holds a
  /// small file, and short enough that nobody notices. The final failure is
  /// thrown, not swallowed: a record that truly cannot be written is worth
  /// reporting, and a caller that can carry on says so by catching it.
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
