/// Purpose: Run the real whisper.cpp engine on this host: install a model
/// through the artifact manager, probe the routes, pass the route check on
/// the bundled clip, transcribe, cancel, release.
/// Inputs: `--dart-define=live_model=true`; the network, once, to fetch
/// `ggml-tiny.bin` (75 MiB), which is then cached in the temporary directory.
/// Returns: None.
/// Side effects: Downloads a model; builds and loads the native library.
/// Notes: **Opt-in.** Every other test uses the fake engine and needs no
/// model and no network. Run:
///   flutter test test/local_asr_live_test.dart --dart-define=live_model=true
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/engines/whisper_cpp_engine.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/engine_registry.dart';
import 'package:my_transcribe/features/local/services/local_asr_engine.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/route_smoke_test.dart';
import 'package:my_transcribe/features/local/services/smoke_clip.dart';
import 'package:path/path.dart' as p;

/// Whether to run.
const _live = bool.fromEnvironment('live_model');

/// The tiny Whisper model, pinned like the templates are.
const _tiny = ArtifactManifest(
  artifactId: 'whisper-tiny-ggml',
  modelId: 'local:whisper-tiny',
  adapterId: 'whisper_cpp',
  format: ArtifactFormat.ggml,
  quantization: 'f16',
  revision: '5359861c739e955e79d9a303bcbc70fb988958b1',
  files: [
    ArtifactFile(
      path: 'ggml-tiny.bin',
      bytes: 77691713,
      sha256:
          'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
      sourceUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/'
          '5359861c739e955e79d9a303bcbc70fb988958b1/ggml-tiny.bin',
    ),
  ],
  licenseId: 'MIT',
);

void main() {
  late WhisperCppEngine engine;
  late ArtifactManager artifacts;
  late LocalEngineStateStore state;
  late Directory work;

  setUpAll(() async {
    if (!_live) return;
    // Kept across runs, so the model is fetched once per machine.
    final models = Directory(
      p.join(Directory.systemTemp.path, 'mytranscribe_live_models'),
    );
    artifacts = ArtifactManager(modelsDir: () async => models);
    if (await artifacts.installed(_tiny.artifactId) == null) {
      await artifacts.install(_tiny);
    }
    work = await Directory.systemTemp.createTemp('mytranscribe_live_asr_');
    state = LocalEngineStateStore(
      file: () async => File(p.join(work.path, 'state.json')),
    );
    engine = WhisperCppEngine(threads: 4);
  });

  tearDownAll(() async {
    if (!_live) return;
    await engine.dispose();
    try {
      await work.delete(recursive: true);
    } catch (_) {}
  });

  test('the engine loads and offers a CPU route', () async {
    if (!_live) return markTestSkipped('pass --dart-define=live_model=true');
    final info = await engine.runtime();
    expect(info.loaded, isTrue);
    expect(info.version, isNotEmpty);
    final registry = EngineRegistry(
      engines: [engine],
      artifacts: artifacts,
      state: state,
    );
    final routes = await registry.routes();
    final cpu = routes.singleWhere((r) => r.isCpu);
    expect(cpu.available, isTrue, reason: cpu.unavailableReason);
    expect(cpu.smokeKey, contains(_tiny.files.single.sha256));
    expect(cpu.smokeTest.outcome, SmokeTestOutcome.notRun);
  });

  test('passes the route check on the bundled clip', () async {
    if (!_live) return markTestSkipped('pass --dart-define=live_model=true');
    final cpu = (await engine.probe([
      (await artifacts.installed(_tiny.artifactId))!,
    ])).singleWhere((r) => r.isCpu);
    final record = await RouteSmokeTester(state: state).run(
      engine: engine,
      route: cpu,
      manifest: (await artifacts.installed(_tiny.artifactId))!,
      artifactDir: await artifacts.artifactDir(_tiny.artifactId),
      clip: SmokeClip(
        wav: File(smokeClipAsset),
        expectedText: smokeClipText,
        seconds: smokeClipSeconds,
      ),
    );
    // ignore: avoid_print
    print(
      'check: ${record.outcome.name}, similarity ${record.similarity}, '
      'RTF ${record.realTimeFactor?.toStringAsFixed(3)}: ${record.text}',
    );
    expect(record.outcome, SmokeTestOutcome.passed, reason: record.reason);
    expect((await state.load()).inFlight, isNull);
  });

  test('transcribes a window with times, and stops when cancelled', () async {
    if (!_live) return markTestSkipped('pass --dart-define=live_model=true');
    final manifest = (await artifacts.installed(_tiny.artifactId))!;
    final cpu = (await engine.probe([manifest])).singleWhere((r) => r.isCpu);
    final session = await engine.prepare(
      PrepareRequest(
        route: cpu,
        manifest: manifest,
        artifactDir: await artifacts.artifactDir(_tiny.artifactId),
      ),
    );
    expect(session.placement, PlacementKind.cpu);
    try {
      final events = await engine
          .transcribe(
            TranscribeRequest(
              jobId: 'live',
              sessionId: session.sessionId,
              pcmWindow: File(smokeClipAsset),
              windowSeconds: smokeClipSeconds,
              languages: const ['en'],
            ),
          )
          .toList();
      final segments = [
        for (final e in events)
          if (e.type == AsrEventType.segment) e.segment!,
      ];
      expect(segments, isNotEmpty);
      expect(segments.last.endSeconds, closeTo(11, 1.5));
      expect(events.last.type, AsrEventType.completed);
      expect(events.last.placement, PlacementKind.cpu);

      // A cancel issued as the window starts returns once the native call
      // has stopped, and the window ends as cancelled.
      final stream = engine.transcribe(
        TranscribeRequest(
          jobId: 'live-cancel',
          sessionId: session.sessionId,
          pcmWindow: File(smokeClipAsset),
          windowSeconds: smokeClipSeconds,
        ),
      );
      // Not awaited inside the loop: the cancel completes when the window's
      // stream has finished, which needs this loop to keep reading it.
      final types = <AsrEventType>[];
      Future<void>? cancelled;
      await for (final event in stream) {
        types.add(event.type);
        if (event.type == AsrEventType.started) {
          cancelled = engine.cancel('live-cancel');
        }
      }
      await cancelled;
      expect(types.last, AsrEventType.cancelled);
    } finally {
      await engine.release(session.sessionId);
    }
  });
}
