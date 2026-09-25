/// Purpose: Copy each transcription's converted audio to and from the WebDAV
/// server, when the device has asked for it.
/// Inputs: The WebDAV configuration and the transcripts that just synced.
/// Returns: What was uploaded, downloaded and removed.
/// Side effects: Network I/O, and writes `jobs/<id>/audio.mp3`.
/// Notes: Deliberately outside the shared sync engine, for the same reason the
/// API keys are: the engine merges text documents against a base snapshot under
/// a lock, and these are immutable blobs that need neither. Each one exists at
/// `audio/<jobId>.mp3` or it does not, so the exchange is additive in both
/// directions and cannot lose an edit.
///
/// What travels is the **converted** copy — the mono 16 kHz file the app made
/// to cut windows from and the viewer plays. The original recording never
/// leaves the device: it can be gigabytes, and the user chose where to keep it.
/// A recording small enough to have been sent whole never had a converted copy,
/// so other devices get no audio for it.
///
/// Off by default, per device. See `doc/en-us/sync.md`.
library;

import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:myapps_data/myapps_data.dart' show atomicWriteBytes;

import '../../../app/data_modules.dart';
import '../../../shared/services/transcribe_storage.dart';
import '../models/transcripts_document.dart';
import 'job_store.dart';

/// Which directions one exchange may move audio in.
enum AudioSyncMode {
  /// Both, and remove what the merge deleted. A normal sync.
  sync,

  /// Upload only, and remove nothing. Force upload.
  uploadOnly,

  /// Download only, and remove nothing. Force download.
  downloadOnly,
}

/// What became of the audio during a sync.
enum AudioSyncStatus {
  /// This device has not asked for audio, so nothing was requested.
  off,

  /// The exchange ran.
  synced,

  /// The remote listing failed, so nothing could be decided safely.
  skippedListing,

  /// The exchange could not start at all.
  failed,
}

/// The outcome of one exchange.
class AudioSyncOutcome {
  /// What happened.
  final AudioSyncStatus status;

  /// How many files were sent.
  final int uploaded;

  /// How many files were fetched.
  final int downloaded;

  /// How many were removed from the server.
  final int deleted;

  /// What went wrong with individual transfers, if anything.
  final List<String> warnings;

  /// Purpose: Record an outcome.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const AudioSyncOutcome({
    required this.status,
    this.uploaded = 0,
    this.downloaded = 0,
    this.deleted = 0,
    this.warnings = const [],
  });

  /// Whether anything moved, which is what decides if the user is told.
  bool get movedAnything => uploaded > 0 || downloaded > 0;
}

/// Exchanges the converted audio files.
class AudioSyncService {
  /// Purpose: Prevent instantiation; every entry point is static.
  /// Inputs: None.
  /// Returns: Nothing.
  /// Side effects: None.
  /// Notes: Matches the other services' shape.
  AudioSyncService._();

  /// Purpose: Exchange audio for the transcriptions that just synced.
  /// Inputs: The [config], the [document] the merge produced, the ids the merge
  /// [deletedIds], the [mode], and an optional [clientFactory] for tests.
  /// Returns: An [AudioSyncOutcome].
  /// Side effects: One listing, then one request per file that has to move.
  /// Notes: Nothing at all happens when the device has not opted in — not even
  /// the listing, so a user who never wants this never sends a request about
  /// it. A failed listing is not treated as an empty server: that would
  /// re-upload every file on one flaky PROPFIND. A file the user removed with
  /// "remove converted audio" carries a marker and is never fetched back, which
  /// is the whole point of freeing the space.
  static Future<AudioSyncOutcome> exchange(
    shared.WebDAVConfig config, {
    required TranscriptsDocument document,
    Set<String> deletedIds = const {},
    AudioSyncMode mode = AudioSyncMode.sync,
    shared.WebDavClient Function(shared.WebDAVConfig)? clientFactory,
  }) async {
    if (!await TranscribeStorage.getSyncIncludesAudio()) {
      return const AudioSyncOutcome(status: AudioSyncStatus.off);
    }

    final client = (clientFactory ?? shared.WebDavClient.new)(config);
    Set<String>? remote;
    try {
      await client.ensureRemoteSubDir(audioRemoteDirName);
      remote = await client.listSubDir(audioRemoteDirName);
    } catch (error) {
      return AudioSyncOutcome(
        status: AudioSyncStatus.failed,
        warnings: ['Could not reach the audio folder: $error'],
      );
    }
    if (remote == null) {
      return const AudioSyncOutcome(
        status: AudioSyncStatus.skippedListing,
        warnings: ['Could not list the audio folder; audio was left alone.'],
      );
    }

    final warnings = <String>[];
    var uploaded = 0;
    var downloaded = 0;
    var deleted = 0;

    for (final record in document.records) {
      final id = record.id;
      if (!TranscriptSyncRecord.isSafeId(id)) continue;
      final name = '$audioRemoteDirName/$id.mp3';
      final local = await JobStore.normalizedAudio(id);
      final here = await local.exists();
      final there = remote.contains('$id.mp3');

      if (here && !there && mode != AudioSyncMode.downloadOnly) {
        try {
          await client.uploadBytes(name, await local.readAsBytes());
          uploaded++;
        } catch (error) {
          warnings.add(
            'Could not upload the audio for ${record.displayName}: '
            '$error',
          );
        }
        continue;
      }

      if (!here && there && mode != AudioSyncMode.uploadOnly) {
        if (await JobStore.hasAudioDiscardedMarker(id)) continue;
        try {
          await atomicWriteBytes(local, await client.downloadBytes(name));
          downloaded++;
        } catch (error) {
          warnings.add(
            'Could not download the audio for ${record.displayName}: $error',
          );
        }
      }
    }

    if (mode == AudioSyncMode.sync) {
      for (final id in deletedIds) {
        if (!TranscriptSyncRecord.isSafeId(id)) continue;
        if (!remote.contains('$id.mp3')) continue;
        await client.delete('$audioRemoteDirName/$id.mp3');
        deleted++;
      }
    }

    return AudioSyncOutcome(
      status: AudioSyncStatus.synced,
      uploaded: uploaded,
      downloaded: downloaded,
      deleted: deleted,
      warnings: warnings,
    );
  }
}
