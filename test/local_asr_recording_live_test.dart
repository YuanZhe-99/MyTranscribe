/// Purpose: Verify a local model on a real recording, through the whole app
/// pipeline — FFmpeg, the planner, the runner, the engine — and measure it.
/// Inputs: Dart defines: `live_recording` (the recording's path),
/// `live_reference` (a `transcript.json` of the same recording made by another
/// model, to compare with), and optionally `live_model` (a built-in local
/// model id; turbo by default) and `live_device` (`auto`, `cpu` or a route
/// key). FFmpeg must be findable, and the model is downloaded once, checked by
/// hash, into the temporary directory.
/// Returns: None; prints the measurements — never the transcript's text.
/// Side effects: Downloads a model; runs FFmpeg and the model; writes into a
/// temporary directory.
/// Notes: **Opt-in, and slow**: an hour of audio takes a large model most of
/// an hour on a laptop CPU. This is the acceptance run of `PLAN.md` §7 for a
/// route on this project's own hardware; its numbers go into
/// `doc/en-us/local-asr-support-matrix.md`. Run:
/// `flutter test test/local_asr_recording_live_test.dart
/// --dart-define=live_recording=AUDIO --dart-define=live_reference=JSON`
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/jobs/models/transcription_job.dart';
import 'package:my_transcribe/features/jobs/services/job_runner.dart';
import 'package:my_transcribe/features/jobs/services/job_store.dart';
import 'package:my_transcribe/features/local/engines/whisper_cpp_engine.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/engine_registry.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/local_model_templates.dart';
import 'package:my_transcribe/features/local/services/local_transcription_backend.dart';
import 'package:my_transcribe/features/local/services/route_smoke_test.dart';
import 'package:my_transcribe/features/local/services/smoke_clip.dart';
import 'package:my_transcribe/features/media/services/external_ffmpeg_media_toolkit.dart';
import 'package:my_transcribe/features/media/services/ffmpeg_locator.dart';
import 'package:my_transcribe/features/providers/services/settings_repository.dart';
import 'package:my_transcribe/features/transcript/services/transcript_store.dart';
import 'package:my_transcribe/shared/services/transcribe_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _recording = String.fromEnvironment('live_recording');
const _reference = String.fromEnvironment('live_reference');
const _model = String.fromEnvironment(
  'live_model',
  defaultValue: 'local:whisper-large-v3-turbo',
);
const _device = String.fromEnvironment('live_device', defaultValue: 'auto');

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

/// Purpose: Read a transcript file's text.
/// Inputs: [path] to a `transcript.json`.
/// Returns: Its segments' text, joined.
/// Side effects: Reads the file.
/// Notes: Internal helper used within this file only.
String _textOf(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map;
  return [
    for (final segment in (json['segments'] as List? ?? const []))
      (segment as Map)['text'] ?? '',
  ].join(' ');
}

void main() {
  // No TestWidgetsFlutterBinding: it answers every HTTP request with a 400,
  // and this test downloads its model for real.
  test(
    'transcribes a real recording on this device',
    () async {
      if (_recording.isEmpty) {
        markTestSkipped('pass --dart-define=live_recording=AUDIO');
        return;
      }
      final root = await Directory.systemTemp.createTemp('mytranscribe_rec_');
      PathProviderPlatform.instance = _FakePathProvider(root.path);
      await TranscribeStorage.setStoragePath(null);
      final repository = SettingsRepository();
      await repository.load();

      final template = buildLocalModelTemplates().firstWhere(
        (t) => t.model.id == _model,
      );
      final artifacts = ArtifactManager(
        modelsDir: () async => Directory(
          p.join(Directory.systemTemp.path, 'mytranscribe_live_models'),
        ),
      );
      for (final manifest in template.artifacts) {
        if (await artifacts.installed(manifest.artifactId) == null) {
          // ignore: avoid_print
          print('downloading ${manifest.artifactId}…');
          await artifacts.install(manifest);
        }
      }

      final state = LocalEngineStateStore(
        file: () async => File(p.join(root.path, 'state.json')),
      );
      final engine = WhisperCppEngine(
        family: _model.startsWith('local:parakeet')
            ? GgmlFamily.parakeet
            : GgmlFamily.whisper,
      );
      final registry = EngineRegistry(
        engines: [engine],
        artifacts: artifacts,
        state: state,
      );
      final runner = JobRunner(
        toolkit: () async => ExternalFfmpegMediaToolkit(locator: FfmpegLocator()),
        repository: repository,
        writeTranscriptFiles: () async => false,
        localBackend: LocalTranscriptionBackend(
          registry: registry,
          smokeTester: RouteSmokeTester(state: state),
          smokeClip: () async => SmokeClip(
            wav: File(smokeClipAsset),
            expectedText: smokeClipText,
            seconds: smokeClipSeconds,
          ),
        ),
      );

      final job = await runner.create(
        sourcePath: _recording,
        providerId: localJobProviderId,
        modelId: _model,
        modelName: _model.substring('local:'.length),
        options: JobOptions(
          languages: const ['en'],
          device: RouteRequest(_device),
        ),
      );
      final watch = Stopwatch()..start();
      runner.enqueue(job.id);
      TranscriptionJob? done;
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 5));
        done = await JobStore.load(job.id);
        if (done != null && done.stage.isFinished) break;
      }
      watch.stop();

      expect(
        done.stage,
        JobStage.done,
        reason: '${done.error?.kind} ${done.error?.message}',
      );
      final transcript = await TranscriptStore.load(job.id);
      final text = transcript!.segments.map((s) => s.text).join(' ');
      final seconds = done.media?.durationSeconds ?? 0;
      final check = (await state.load()).smokeTests.values.toList();
      final lines = <String>[
        'model: $_model, asked for: $_device',
        'route: ${done.route?.routeKey}, tested here: ${done.route?.testedHere}',
        'placements: ${done.chunks.map((c) => c.placement?.name).toSet()}',
        'fallbacks: ${done.fallbacks.length}',
        'check: ${check.map((c) => '${c.routeKey} ${c.outcome.name} '
            'rtf ${c.realTimeFactor?.toStringAsFixed(3)}').join('; ')}',
        'audio: ${(seconds / 60).toStringAsFixed(1)} min in '
            '${done.plan?.windowCount} windows',
        'wall time: ${(watch.elapsed.inSeconds / 60).toStringAsFixed(1)} min, '
            'RTF ${(watch.elapsed.inMilliseconds / 1000 / seconds).toStringAsFixed(3)}',
        'peak memory: ${(ProcessInfo.maxRss / 1e9).toStringAsFixed(2)} GB',
        'words: ${normalizedWords(text).length}',
        if (_reference.isNotEmpty)
          'agreement with the reference transcript: '
              '${(textSimilarity(_textOf(_reference), text) * 100).toStringAsFixed(1)} %',
      ];
      // ignore: avoid_print
      print(lines.join('\n'));

      await engine.dispose();
      try {
        await root.delete(recursive: true);
      } catch (_) {}
    },
    timeout: Timeout.none,
  );
}
