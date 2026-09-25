/// Purpose: Prove the whisper.cpp engine linked into this build loads and runs
/// on the device: install the tiny model, pass the route check on the bundled
/// clip, transcribe a window, cancel one, release.
/// Inputs: A device and the network, once: `ggml-tiny.bin` (75 MiB) is fetched
/// through the artifact manager, checked by hash, and kept in the app's
/// temporary directory for later runs.
/// Returns: None.
/// Side effects: Downloads a model; loads native code; writes temporary files.
/// Notes: The same assertions as `test/local_asr_live_test.dart`, so a wrong
/// architecture, a missing symbol, a CPU variant that did not load or a
/// packaging mistake fails here, at the first call, and not in front of a
/// user. Run per `integration_test/README.md`.
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_transcribe/features/local/engines/whisper_cpp_engine.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/local_asr_engine.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/route_smoke_test.dart';
import 'package:my_transcribe/features/local/services/smoke_clip.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('whisper.cpp loads, checks, transcribes and cancels', (_) async {
    final temp = await getTemporaryDirectory();
    final artifacts = ArtifactManager(
      modelsDir: () async => Directory(p.join(temp.path, 'live_models')),
    );
    if (await artifacts.installed(_tiny.artifactId) == null) {
      await artifacts.install(_tiny);
    }
    final manifest = (await artifacts.installed(_tiny.artifactId))!;
    final dir = await artifacts.artifactDir(_tiny.artifactId);
    final state = LocalEngineStateStore(
      file: () async => File(p.join(temp.path, 'live_state.json')),
    );
    final clip = (await loadSmokeClip(bundle: rootBundle, directory: temp))!;
    final engine = WhisperCppEngine();

    final info = await engine.runtime();
    expect(info.loaded, isTrue, reason: 'the native library must load');

    final cpu = (await engine.probe([manifest])).singleWhere((r) => r.isCpu);
    expect(cpu.available, isTrue, reason: cpu.unavailableReason);

    final record = await RouteSmokeTester(state: state).run(
      engine: engine,
      route: cpu,
      manifest: manifest,
      artifactDir: dir,
      clip: clip,
    );
    expect(record.outcome, SmokeTestOutcome.passed, reason: record.reason);

    final session = await engine.prepare(
      PrepareRequest(route: cpu, manifest: manifest, artifactDir: dir),
    );
    try {
      final events = await engine
          .transcribe(
            TranscribeRequest(
              jobId: 'device',
              sessionId: session.sessionId,
              pcmWindow: clip.wav,
              windowSeconds: clip.seconds,
              languages: const ['en'],
            ),
          )
          .toList();
      expect(events.last.type, AsrEventType.completed);
      expect(events.where((e) => e.type == AsrEventType.segment), isNotEmpty);

      final types = <AsrEventType>[];
      Future<void>? cancelled;
      await for (final event in engine.transcribe(
        TranscribeRequest(
          jobId: 'device-cancel',
          sessionId: session.sessionId,
          pcmWindow: clip.wav,
          windowSeconds: clip.seconds,
        ),
      )) {
        types.add(event.type);
        if (event.type == AsrEventType.started) {
          cancelled = engine.cancel('device-cancel');
        }
      }
      await cancelled;
      expect(types.last, AsrEventType.cancelled);
    } finally {
      await engine.release(session.sessionId);
      await engine.dispose();
    }
  });
}
