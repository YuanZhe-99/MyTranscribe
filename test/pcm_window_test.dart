/// Purpose: Test the PCM window a local engine receives, and the check a route
/// passes on this device before its first job.
/// Inputs: None.
/// Returns: None.
/// Side effects: Writes into a temporary directory.
/// Notes: An engine fed the wrong sample rate transcribes nonsense without an
/// error, so the header check is tested against every way a WAV can be wrong.
/// The route check is tested with the fake engine: a pass, a wrong sentence,
/// an error, and the in-flight marker around it.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/local_asr_engine.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/pcm_window_cutter.dart';
import 'package:my_transcribe/features/local/services/route_smoke_test.dart';
import 'package:my_transcribe/features/media/services/media_toolkit.dart';
import 'package:path/path.dart' as p;

import 'golden/fake_local_asr_engine.dart';

/// Purpose: Build a WAV file's bytes.
/// Inputs: The [samples], and the header fields to vary.
/// Returns: The bytes.
/// Side effects: None.
/// Notes: [extraChunk] inserts a `LIST` chunk before the samples, which is
/// what an FFmpeg build writes unless told to be bit-exact.
Uint8List wav(
  List<int> samples, {
  int rate = 16000,
  int channels = 1,
  int bits = 16,
  int format = 1,
  bool extraChunk = false,
}) {
  final builder = BytesBuilder();
  void u32(int v) => builder.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );
  void u16(int v) => builder.add(
    (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
  );
  final list = extraChunk ? [..._list] : <int>[];
  builder.add('RIFF'.codeUnits);
  u32(36 + list.length + samples.length * 2);
  builder.add('WAVE'.codeUnits);
  builder.add('fmt '.codeUnits);
  u32(16);
  u16(format);
  u16(channels);
  u32(rate);
  u32(rate * channels * bits ~/ 8);
  u16(channels * bits ~/ 8);
  u16(bits);
  builder.add(list);
  builder.add('data'.codeUnits);
  u32(samples.length * 2);
  for (final s in samples) {
    u16(s & 0xffff);
  }
  return builder.toBytes();
}

/// A `LIST` chunk of the kind FFmpeg writes: an odd-sized body, padded.
final _list = [
  ...'LIST'.codeUnits,
  ...[9, 0, 0, 0],
  ...'INFOISFT\x00'.codeUnits,
  0,
];

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mytranscribe_pcm_');
  });

  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  File write(String name, List<int> bytes) =>
      File(p.join(root.path, name))..writeAsBytesSync(bytes);

  group('a PCM window', () {
    test('reads its header and samples', () async {
      final window = await readPcmWindow(
        write('a.wav', wav([0, 16384, -32768, 32767])),
      );
      expect(window.sampleRate, 16000);
      expect(window.sampleCount, 4);
      expect(window.dataOffset, 44);
      expect(window.seconds, 4 / 16000);
      final samples = await window.readSamples();
      expect(samples, [0.0, 0.5, -1.0, 32767 / 32768]);
    });

    test('finds the samples past a chunk it does not use', () async {
      final window = await readPcmWindow(
        write('b.wav', wav([1, 2, 3], extraChunk: true)),
      );
      expect(window.sampleCount, 3);
      expect(window.dataOffset, 44 + _list.length);
    });

    test('is refused in any other format', () async {
      for (final bad in [
        wav([1], rate: 44100),
        wav([1], channels: 2),
        wav([1], bits: 8),
        wav([1], format: 3),
        Uint8List.fromList('not a wav at all'.codeUnits),
      ]) {
        await expectLater(
          readPcmWindow(write('bad.wav', bad)),
          throwsA(
            isA<MediaException>().having(
              (e) => e.kind,
              'kind',
              MediaFailureKind.toolError,
            ),
          ),
        );
      }
    });
  });

  group('the words a check compares', () {
    test('ignore case and punctuation', () {
      expect(
        textSimilarity(
          'And so, my fellow Americans: ask not.',
          'and so my fellow americans ask not',
        ),
        1,
      );
    });

    test('count a dropped or invented word against the expected ones', () {
      expect(textSimilarity('one two three four', 'one two four'), 0.75);
      expect(textSimilarity('one two', 'something else entirely'), 0);
      expect(textSimilarity('', ''), 1);
      expect(textSimilarity('', 'noise'), 0);
    });
  });

  group('a route check', () {
    const expected = 'and so my fellow americans ask not what your country';
    late LocalEngineStateStore state;
    late SmokeClip clip;
    final route = fakeRoute(
      adapterId: 'whisper_cpp',
      modelId: 'local:w',
      artifactId: 'w',
      device: ComputeDevice.gpu,
    );
    const manifest = ArtifactManifest(
      artifactId: 'w',
      modelId: 'local:w',
      adapterId: 'whisper_cpp',
      format: ArtifactFormat.ggml,
      revision: 'r',
      files: [],
      licenseId: 'MIT',
    );

    setUp(() {
      state = LocalEngineStateStore(
        file: () async => File(p.join(root.path, 'state.json')),
      );
      clip = SmokeClip(
        wav: write('clip.wav', wav(List.filled(160, 0))),
        expectedText: expected,
        seconds: 10,
      );
    });

    Future<SmokeTestOutcome> check(FakeWindow window) async {
      final engine = FakeLocalAsrEngine(
        adapterId: 'whisper_cpp',
        routes: [route],
        script: (_, _) => window,
      );
      final record = await RouteSmokeTester(state: state).run(
        engine: engine,
        route: route,
        manifest: manifest,
        artifactDir: root,
        clip: clip,
      );
      expect(engine.released, hasLength(1), reason: 'always released');
      expect((await state.load()).inFlight, isNull, reason: 'marker cleared');
      expect(
        (await state.load()).smokeTestFor(route.smokeKey).outcome,
        record.outcome,
        reason: 'recorded under the route key',
      );
      return record.outcome;
    }

    test('passes a route that says the right words', () async {
      expect(
        await check(
          FakeWindow.text(
            'And so, my fellow Americans, ask not '
            'what your country',
          ),
        ),
        SmokeTestOutcome.passed,
      );
      final record = (await state.load()).smokeTests[route.smokeKey]!;
      expect(record.similarity, 1);
      expect(record.realTimeFactor, isNotNull);
    });

    test('fails a route that says something else', () async {
      expect(
        await check(FakeWindow.text('the the the the')),
        SmokeTestOutcome.failed,
      );
      expect(
        (await state.load()).smokeTests[route.smokeKey]!.reason,
        contains('%'),
      );
    });

    test('fails a route that errors, with its code', () async {
      expect(
        await check(
          const FakeWindow(
            error: LocalAsrException(
              LocalAsrErrorCode.deviceLost,
              'driver timeout',
            ),
          ),
        ),
        SmokeTestOutcome.failed,
      );
      expect(
        (await state.load()).smokeTests[route.smokeKey]!.reason,
        startsWith('DEVICE_LOST'),
      );
    });
  });
}
