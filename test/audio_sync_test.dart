/// Purpose: Test the opt-in exchange that copies each transcription's converted
/// audio to and from the server.
/// Inputs: None; a fake server and a temporary app directory stand in.
/// Returns: None.
/// Side effects: Creates and deletes files under a temporary directory.
/// Notes: The cases that matter are the ones about restraint: a device that has
/// not asked for this must send no request at all, a listing that failed must
/// not be read as an empty server, and audio the user deliberately removed to
/// free space must not be downloaded straight back.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/app/data_modules.dart';
import 'package:my_transcribe/features/jobs/models/transcripts_document.dart';
import 'package:my_transcribe/features/jobs/services/audio_sync_service.dart';
import 'package:my_transcribe/features/jobs/services/job_store.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'golden/fake_webdav_store.dart';

/// A path provider that answers with one temporary directory.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late FakeWebDavStore store;

  final config = shared.WebDAVConfig(
    serverUrl: 'https://cloud.example.com/dav',
    username: 'user',
    password: 'pass',
    remotePath: transcribeDefaultRemotePath,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_audio_');
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    await TranscribeStorage.setStoragePath(null);
    await TranscribeStorage.setSyncIncludesAudio(true);
    store = FakeWebDavStore();
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Build a document naming the transcriptions in play.
  /// Inputs: The [ids].
  /// Returns: A [TranscriptsDocument].
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  TranscriptsDocument document(List<String> ids) => TranscriptsDocument(
    records: [
      for (final id in ids)
        TranscriptSyncRecord(
          id: id,
          createdAt: DateTime.utc(2026, 9, 1),
          modifiedAt: DateTime.utc(2026, 9, 9),
          job: {'id': id, 'title': 'Lecture $id'},
          transcript: {'jobId': id},
        ),
    ],
  );

  /// Purpose: Put a converted audio file in a job's folder.
  /// Inputs: The [id] and the [bytes] to write.
  /// Returns: None.
  /// Side effects: Writes the file.
  /// Notes: Internal helper used within this file only.
  Future<void> localAudio(String id, [List<int> bytes = const [1, 2, 3]]) async {
    final file = await JobStore.normalizedAudio(id);
    await file.writeAsBytes(bytes);
  }

  /// Purpose: Run the exchange against the fake server.
  /// Inputs: The [ids] in the document, the ids the merge [deleted], and the
  /// [mode].
  /// Returns: The outcome.
  /// Side effects: Network calls into the fake, and local file writes.
  /// Notes: Internal helper used within this file only.
  Future<AudioSyncOutcome> exchange(
    List<String> ids, {
    Set<String> deleted = const {},
    AudioSyncMode mode = AudioSyncMode.sync,
  }) => AudioSyncService.exchange(
    config,
    document: document(ids),
    deletedIds: deleted,
    mode: mode,
    clientFactory: (c) => shared.WebDavClient(c, httpClient: store),
  );

  group('when the device has not asked for audio', () {
    test('nothing is sent at all, not even a listing', () async {
      await TranscribeStorage.setSyncIncludesAudio(false);
      await localAudio('job-1');

      final outcome = await exchange(['job-1']);

      expect(outcome.status, AudioSyncStatus.off);
      expect(store.requests, isEmpty);
    });
  });

  group('exchanging audio', () {
    test('uploads a file the server does not have', () async {
      await localAudio('job-1');

      final outcome = await exchange(['job-1']);

      expect(outcome.uploaded, 1);
      expect(store.files.keys, contains('audio/job-1.mp3'));
    });

    test('downloads a file this device does not have', () async {
      store.collections.add(audioRemoteDirName);
      store.files['audio/job-1.mp3'] = Uint8List.fromList([9, 9, 9]);

      final outcome = await exchange(['job-1']);

      expect(outcome.downloaded, 1);
      final local = await JobStore.normalizedAudio('job-1');
      expect(await local.readAsBytes(), [9, 9, 9]);
    });

    test('leaves alone a file both sides already have', () async {
      await localAudio('job-1');
      store.collections.add(audioRemoteDirName);
      store.files['audio/job-1.mp3'] = Uint8List.fromList([9]);

      final outcome = await exchange(['job-1']);

      expect(outcome.uploaded, 0);
      expect(outcome.downloaded, 0);
      expect(store.files['audio/job-1.mp3'], [9]);
    });

    test('does not fetch back audio the user removed to free space', () async {
      // The whole point of removing it. Without the marker the next sync would
      // helpfully undo the cleanup.
      store.collections.add(audioRemoteDirName);
      store.files['audio/job-1.mp3'] = Uint8List.fromList([9]);
      await localAudio('job-1');
      await JobStore.deleteConvertedAudio('job-1');

      final outcome = await exchange(['job-1']);

      expect(outcome.downloaded, 0);
      expect(await (await JobStore.normalizedAudio('job-1')).exists(), isFalse);
    });

    test('a re-run clears the marker, so the audio can travel again', () async {
      await localAudio('job-1');
      await JobStore.deleteConvertedAudio('job-1');
      expect(await JobStore.hasAudioDiscardedMarker('job-1'), isTrue);

      await JobStore.clearAudioDiscardedMarker('job-1');
      store.collections.add(audioRemoteDirName);
      store.files['audio/job-1.mp3'] = Uint8List.fromList([9]);

      expect((await exchange(['job-1'])).downloaded, 1);
    });
  });

  group('which directions each mode allows', () {
    test('a force upload never downloads', () async {
      store.collections.add(audioRemoteDirName);
      store.files['audio/job-1.mp3'] = Uint8List.fromList([9]);

      final outcome = await exchange(
        ['job-1'],
        mode: AudioSyncMode.uploadOnly,
      );

      expect(outcome.downloaded, 0);
    });

    test('a force download never uploads', () async {
      await localAudio('job-1');

      final outcome = await exchange(
        ['job-1'],
        mode: AudioSyncMode.downloadOnly,
      );

      expect(outcome.uploaded, 0);
      expect(store.files, isEmpty);
    });

    test('only a real sync removes what the merge deleted', () async {
      store.collections.add(audioRemoteDirName);
      store.files['audio/gone.mp3'] = Uint8List.fromList([9]);

      await exchange([], deleted: {'gone'}, mode: AudioSyncMode.downloadOnly);
      expect(store.files.keys, contains('audio/gone.mp3'));

      final outcome = await exchange([], deleted: {'gone'});
      expect(outcome.deleted, 1);
      expect(store.files, isEmpty);
    });
  });

  group('when something goes wrong', () {
    test('a listing that failed is not read as an empty server', () async {
      // Otherwise one flaky PROPFIND would re-upload every file on the device.
      await localAudio('job-1');
      store.refuseListing = true;

      final outcome = await exchange(['job-1']);

      expect(outcome.status, AudioSyncStatus.skippedListing);
      expect(outcome.uploaded, 0);
      expect(outcome.warnings, isNotEmpty);
    });

    test('an upload that failed is a warning, not a thrown error', () async {
      await localAudio('job-1');
      await localAudio('job-2');
      store.refuseUploads = true;

      final outcome = await exchange(['job-1', 'job-2']);

      expect(outcome.status, AudioSyncStatus.synced);
      expect(outcome.uploaded, 0);
      expect(outcome.warnings, hasLength(2));
      expect(outcome.warnings.first, contains('Lecture job-1'));
    });

    test('an unusable id is skipped rather than followed', () async {
      final outcome = await AudioSyncService.exchange(
        config,
        document: TranscriptsDocument(
          records: [
            TranscriptSyncRecord(
              id: '../escape',
              createdAt: DateTime.utc(2026),
              modifiedAt: DateTime.utc(2026),
              job: const {},
              transcript: const {},
            ),
          ],
        ),
        clientFactory: (c) => shared.WebDavClient(c, httpClient: store),
      );

      expect(outcome.uploaded, 0);
      expect(outcome.downloaded, 0);
    });
  });
}
