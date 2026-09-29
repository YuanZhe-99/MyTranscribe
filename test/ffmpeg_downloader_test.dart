/// Purpose: Test the FFmpeg download helper's failure paths: a server that
/// never answers, a body that stops arriving, a cancel in the middle, and an
/// archive that will not unpack.
/// Inputs: None; a fake HTTP client stands in for the release host.
/// Returns: None.
/// Side effects: Writes into a temporary directory.
/// Notes: The download is around a hundred megabytes from a host the app does
/// not control. Before these guards a stalled connection left the settings
/// page spinning for ever, a cancel during the wait for the first byte was not
/// heard, and a failed unpack left the archive behind in the tools folder.
library;

import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_transcribe/features/media/services/ffmpeg_downloader.dart';
import 'package:my_transcribe/features/media/services/media_toolkit.dart';
import 'package:path/path.dart' as p;

/// A client whose behaviour the test scripts.
class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.respond);

  /// Builds the response to a request; may never complete.
  final Future<http.StreamedResponse> Function() respond;

  /// Requests that are still waiting for [respond], to fail on close.
  final _pending = <Completer<http.StreamedResponse>>[];

  /// Whether [close] was called.
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final completer = Completer<http.StreamedResponse>();
    _pending.add(completer);
    respond().then(completer.complete, onError: completer.completeError);
    return completer.future;
  }

  @override
  void close() {
    closed = true;
    for (final completer in _pending) {
      if (!completer.isCompleted) {
        completer.completeError(http.ClientException('closed'));
      }
    }
  }
}

void main() {
  late Directory destination;

  setUp(() async {
    destination = await Directory.systemTemp.createTemp('mytranscribe_ffdl_');
  });

  tearDown(() async {
    try {
      await destination.delete(recursive: true);
    } catch (_) {}
  });

  FfmpegDownloader downloader(
    _ScriptedClient client, {
    Duration connectTimeout = const Duration(milliseconds: 150),
    Duration stallTimeout = const Duration(milliseconds: 150),
  }) => FfmpegDownloader(
    destination: destination,
    clientFactory: () => client,
    abi: Abi.windowsX64,
    connectTimeout: connectTimeout,
    stallTimeout: stallTimeout,
  );

  Matcher failsWith(MediaFailureKind kind) =>
      throwsA(isA<MediaException>().having((e) => e.kind, 'kind', kind));

  test('a server that never answers is given up on', () async {
    final client = _ScriptedClient(
      () => Completer<http.StreamedResponse>().future,
    );
    await expectLater(
      downloader(client).download(),
      failsWith(MediaFailureKind.toolFailed),
    );
    expect(client.closed, isTrue);
  });

  test('a body that stops arriving is given up on, and cleaned up', () async {
    final stalled = StreamController<List<int>>()..add(Uint8List(1000));
    final client = _ScriptedClient(
      () async => http.StreamedResponse(stalled.stream, 200),
    );
    addTearDown(stalled.close);

    await expectLater(
      downloader(client).download(),
      failsWith(MediaFailureKind.toolFailed),
    );
    expect(
      File(p.join(destination.path, 'download.zip')).existsSync(),
      isFalse,
      reason: 'a half archive is of no use',
    );
  });

  test('a cancel while waiting for the first byte is heard', () async {
    final client = _ScriptedClient(
      () => Completer<http.StreamedResponse>().future,
    );
    final cancel = MediaCancelToken();
    final download = downloader(
      client,
      connectTimeout: const Duration(seconds: 30),
    ).download(cancel: cancel);
    final outcome = expectLater(
      download,
      failsWith(MediaFailureKind.cancelled),
    );

    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancel.cancel();
    await outcome.timeout(const Duration(seconds: 5));
    expect(client.closed, isTrue);
  });

  test('an archive that will not unpack is not left behind', () async {
    final client = _ScriptedClient(
      () async => http.StreamedResponse(
        Stream.value(Uint8List.fromList(List.filled(2048, 7))),
        200,
      ),
    );

    await expectLater(
      downloader(client).download(),
      failsWith(MediaFailureKind.toolFailed),
    );
    expect(
      destination.listSync(),
      isEmpty,
      reason: 'nothing left in the folder',
    );
  });

  test('an error status is reported as a failure', () async {
    final client = _ScriptedClient(
      () async => http.StreamedResponse(const Stream.empty(), 404),
    );
    await expectLater(
      downloader(client).download(),
      failsWith(MediaFailureKind.toolFailed),
    );
  });
}
