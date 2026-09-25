/// Purpose: Test installing model packages: resuming a download, refusing a
/// file whose hash is wrong, refusing when the disk is full, the atomic
/// rename, unpacking, and the lease a running job holds.
/// Inputs: None; a fake HTTP server serves the files.
/// Returns: None.
/// Side effects: Writes into a temporary directory.
/// Notes: A model is gigabytes on a phone that changes networks. The cases
/// here are the ones a user meets: a download interrupted halfway, a host
/// that replaced a file, a full disk, and a model updated while a
/// transcription is using it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/services/artifact_downloader.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:path/path.dart' as p;

/// A server holding files by URL, honouring ranges unless told not to.
class _Server {
  _Server(this.files);

  /// The bytes at each URL.
  final Map<String, List<int>> files;

  /// Whether range requests are answered with 206.
  bool honourRanges = true;

  /// The Range header of every request, or null when there was none.
  final List<String?> ranges = [];

  /// When set, a response stream stops after this many bytes and waits
  /// forever — a connection that hangs until cancelled.
  int? stallAfter;

  /// Purpose: Make an HTTP client that talks to this server.
  /// Inputs: None.
  /// Returns: A [MockClient].
  /// Side effects: Records each request.
  /// Notes: None.
  http.Client client() => MockClient.streaming((request, _) async {
    ranges.add(request.headers['Range']);
    final body = files[request.url.toString()];
    if (body == null) {
      return http.StreamedResponse(const Stream.empty(), 404);
    }
    var start = 0;
    final range = request.headers['Range'];
    if (range != null && honourRanges) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    }
    final bytes = body.sublist(start);
    Stream<List<int>> stream;
    if (stallAfter != null) {
      final controller = StreamController<List<int>>();
      controller.add(bytes.sublist(0, stallAfter!));
      stream = controller.stream;
    } else {
      stream = Stream.fromIterable([
        for (var i = 0; i < bytes.length; i += 1000)
          bytes.sublist(i, (i + 1000).clamp(0, bytes.length)),
      ]);
    }
    return http.StreamedResponse(
      stream,
      start > 0 ? 206 : 200,
      contentLength: bytes.length,
    );
  });
}

/// Purpose: Describe a file as a manifest would.
/// Inputs: Its [path], [bytes] and [url].
/// Returns: An [ArtifactFile] with the real hash.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArtifactFile _file(
  String path,
  List<int> bytes,
  String url, {
  ArchiveKind unpack = ArchiveKind.none,
  List<String> platforms = const [],
}) => ArtifactFile(
  path: path,
  bytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  sourceUrl: url,
  unpack: unpack,
  platforms: platforms,
);

/// Purpose: Build a manifest.
/// Inputs: The [files], and optionally the [revision].
/// Returns: An [ArtifactManifest] with id `pkg`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
ArtifactManifest _manifest(
  List<ArtifactFile> files, {
  String revision = 'r1',
}) => ArtifactManifest(
  artifactId: 'pkg',
  modelId: 'local:test',
  adapterId: 'whisper_cpp',
  format: ArtifactFormat.ggml,
  revision: revision,
  files: files,
  licenseId: 'MIT',
);

void main() {
  late Directory root;
  late Directory models;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_artifacts_');
    models = Directory(p.join(root.path, 'models'));
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  /// Purpose: Make a manager over the temporary models folder.
  /// Inputs: The [server], and an optional [freeSpace] figure.
  /// Returns: An [ArtifactManager] for Windows.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  ArtifactManager manager(_Server server, {int? freeSpace}) => ArtifactManager(
    modelsDir: () async => models,
    downloader: ArtifactDownloader(clientFactory: server.client),
    freeSpace: (_) async => freeSpace,
    platform: 'windows',
    clock: () => DateTime.utc(2026, 9, 24),
  );

  final model = Uint8List.fromList(List.generate(10000, (i) => i % 251));
  const url = 'https://example.test/r1/model.bin';

  test('installs a file, hashed and renamed into place', () async {
    final server = _Server({url: model});
    final installed = await manager(
      server,
    ).install(_manifest([_file('model.bin', model, url)]));
    final dir = Directory(p.join(models.path, 'pkg'));
    expect(File(p.join(dir.path, 'model.bin')).readAsBytesSync(), model);
    expect(installed.installed.single.sha256, sha256.convert(model).toString());
    expect(installed.installedAt, DateTime.utc(2026, 9, 24));

    final text = File(p.join(dir.path, 'manifest.json')).readAsStringSync();
    expect(text, contains('\n  "artifactId": "pkg"'), reason: 'pretty JSON');
    expect((await manager(server).installedAll()).single.artifactId, 'pkg');
    expect(await manager(server).verify('pkg'), isTrue);
    expect(
      Directory(p.join(models.path, '.downloads', 'pkg.staging')).existsSync(),
      isFalse,
    );
  });

  test('resumes a download from where it stopped', () async {
    final server = _Server({url: model});
    final file = _file('model.bin', model, url);
    final partial = File(
      p.join(
        models.path,
        '.downloads',
        'pkg',
        'model.bin.${file.sha256.substring(0, 12)}.part',
      ),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(model.sublist(0, 4000));

    final budget = await manager(server).spaceNeeded(_manifest([file]));
    expect(budget.download, 6000, reason: 'what is on disk is not counted');

    await manager(server).install(_manifest([file]));
    expect(server.ranges, ['bytes=4000-']);
    expect(
      File(p.join(models.path, 'pkg', 'model.bin')).readAsBytesSync(),
      model,
    );
  });

  test('restarts when the server ignores the range', () async {
    final server = _Server({url: model})..honourRanges = false;
    final file = _file('model.bin', model, url);
    final partial = File(
      p.join(
        models.path,
        '.downloads',
        'pkg',
        'model.bin.${file.sha256.substring(0, 12)}.part',
      ),
    );
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(model.sublist(0, 4000));

    await manager(server).install(_manifest([file]));
    expect(
      File(p.join(models.path, 'pkg', 'model.bin')).readAsBytesSync(),
      model,
      reason: 'the whole file once, not the prefix twice',
    );
  });

  test('refuses a file whose hash is wrong, and throws it away', () async {
    final tampered = Uint8List.fromList(model)..[5000] ^= 0xff;
    final server = _Server({url: tampered});
    await expectLater(
      manager(server).install(_manifest([_file('model.bin', model, url)])),
      throwsA(
        isA<ArtifactException>().having(
          (e) => e.failure,
          'failure',
          ArtifactFailure.hashMismatch,
        ),
      ),
    );
    expect(Directory(p.join(models.path, 'pkg')).existsSync(), isFalse);
    final leftovers = Directory(p.join(models.path, '.downloads', 'pkg'));
    expect(
      leftovers.existsSync() ? leftovers.listSync() : const [],
      isEmpty,
      reason: 'a corrupt prefix is not resumed',
    );
  });

  test('refuses before downloading when the disk is too full', () async {
    final server = _Server({url: model});
    await expectLater(
      manager(
        server,
        freeSpace: 5000,
      ).install(_manifest([_file('model.bin', model, url)])),
      throwsA(
        isA<ArtifactException>().having(
          (e) => e.failure,
          'failure',
          ArtifactFailure.diskFull,
        ),
      ),
    );
    expect(server.ranges, isEmpty, reason: 'nothing was requested');
  });

  test('counts unpacking separately from the download', () async {
    final archive = Archive()
      ..add(ArchiveFile.bytes('inner/encoder.bin', model));
    final zip = ZipEncoder().encodeBytes(archive);
    const zipUrl = 'https://example.test/r1/pkg.zip';
    final manifest = _manifest([
      ArtifactFile(
        path: 'pkg.zip',
        bytes: zip.length,
        sha256: sha256.convert(zip).toString(),
        sourceUrl: zipUrl,
        unpack: ArchiveKind.zip,
        unpackedBytes: 10000,
      ),
    ]);
    final server = _Server({zipUrl: zip});
    final budget = await manager(server).spaceNeeded(manifest);
    expect(budget.download, zip.length);
    expect(budget.unpack, 10000);
    expect(budget.peak, zip.length + 10000);
    await expectLater(
      manager(server, freeSpace: zip.length + 5000).install(manifest),
      throwsA(isA<ArtifactException>()),
    );

    final installed = await manager(server).install(manifest);
    final unpacked = File(p.join(models.path, 'pkg', 'inner', 'encoder.bin'));
    expect(unpacked.readAsBytesSync(), model);
    expect(
      File(p.join(models.path, 'pkg', 'pkg.zip')).existsSync(),
      isFalse,
      reason: 'the archive is deleted once unpacked',
    );
    expect(installed.installed.single.path, 'inner/encoder.bin');
    expect(
      installed.installed.single.sha256,
      sha256.convert(model).toString(),
      reason: 'what was unpacked is hashed here',
    );
  });

  test('downloads only the files this platform needs', () async {
    const appleUrl = 'https://example.test/r1/encoder.zip';
    final server = _Server({url: model});
    await manager(server).install(
      _manifest([
        _file('model.bin', model, url),
        _file('encoder.zip', model, appleUrl, platforms: ['ios', 'macos']),
      ]),
    );
    expect(server.ranges, hasLength(1));
  });

  test('keeps the old version when an update fails', () async {
    final server = _Server({url: model});
    await manager(server).install(_manifest([_file('model.bin', model, url)]));

    const newUrl = 'https://example.test/r2/model.bin';
    final newer = Uint8List.fromList(List.filled(3000, 7));
    server.files[newUrl] = Uint8List.fromList(List.filled(3000, 8));
    await expectLater(
      manager(
        server,
      ).install(_manifest([_file('model.bin', newer, newUrl)], revision: 'r2')),
      throwsA(isA<ArtifactException>()),
    );
    expect((await manager(server).installed('pkg'))!.revision, 'r1');
    expect(await manager(server).verify('pkg'), isTrue);
  });

  test('refuses to replace or remove a package a job holds', () async {
    final server = _Server({url: model});
    final artifacts = manager(server);
    final manifest = _manifest([_file('model.bin', model, url)]);
    await artifacts.install(manifest);

    final lease = artifacts.lease('pkg');
    final second = artifacts.lease('pkg');
    for (final action in [
      () => artifacts.remove('pkg'),
      () => artifacts.install(manifest),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<ArtifactException>().having(
            (e) => e.failure,
            'failure',
            ArtifactFailure.leased,
          ),
        ),
      );
    }
    lease.release();
    lease.release();
    expect(artifacts.isLeased('pkg'), isTrue, reason: 'two holders');
    second.release();
    await artifacts.remove('pkg');
    expect(await artifacts.installed('pkg'), isNull);
  });

  test('keeps a cancelled download for the next attempt', () async {
    final server = _Server({url: model})..stallAfter = 3000;
    final cancel = DownloadCancelToken();
    final install = manager(server).install(
      _manifest([_file('model.bin', model, url)]),
      cancel: cancel,
      onProgress: (progress) {
        if (progress.receivedBytes >= 3000) cancel.cancel();
      },
    );
    await expectLater(
      install,
      throwsA(
        isA<ArtifactException>().having(
          (e) => e.failure,
          'failure',
          ArtifactFailure.cancelled,
        ),
      ),
    );
    final partials = Directory(
      p.join(models.path, '.downloads', 'pkg'),
    ).listSync().whereType<File>().toList();
    expect(partials.single.lengthSync(), 3000);

    server.stallAfter = null;
    await manager(server).install(_manifest([_file('model.bin', model, url)]));
    expect(server.ranges.last, 'bytes=3000-');
  });

  test('refuses a manifest that names a path outside its folder', () async {
    final server = _Server({url: model});
    await expectLater(
      manager(server).install(_manifest([_file('../escape.bin', model, url)])),
      throwsA(
        isA<ArtifactException>().having(
          (e) => e.failure,
          'failure',
          ArtifactFailure.badManifest,
        ),
      ),
    );
  });

  test('finds a changed file when asked to verify', () async {
    final server = _Server({url: model});
    await manager(server).install(_manifest([_file('model.bin', model, url)]));
    final file = File(p.join(models.path, 'pkg', 'model.bin'));
    final bytes = file.readAsBytesSync()..[10] ^= 1;
    file.writeAsBytesSync(bytes);
    expect(await manager(server).verify('pkg'), isFalse);
  });

  test('round-trips a manifest, keeping unknown fields', () {
    final json = {
      ..._manifest([_file('model.bin', model, url)]).toJson(),
      'futureField': [1, 2],
    };
    final back = ArtifactManifest.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(back.toJson(), json);
  });
}
