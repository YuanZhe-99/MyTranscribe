import 'dart:io';

import 'package:myapps_ai_asr/myapps_ai_asr.dart' as shared;
import 'package:myapps_ai_models/myapps_ai_models.dart' as models;

import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import 'local_asr_engine.dart';
import 'local_engine_state_store.dart';
import 'shared_asr_adapter.dart';

export 'package:myapps_ai_asr/myapps_ai_asr.dart'
    show normalizedWords, textSimilarity;

const smokeTestMinSimilarity = shared.asrSelfTestMinSimilarity;

class SmokeClip {
  final File wav;
  final String expectedText;
  final double seconds;
  final String language;

  /// Purpose: Describe check audio. Inputs: wav, text, duration, language.
  /// Returns: Clip. Side effects: None. Notes: Application owns asset extraction.
  const SmokeClip({
    required this.wav,
    required this.expectedText,
    required this.seconds,
    this.language = 'en',
  });
}

/// Runs the shared ASR self-test with application storage and contracts.
class RouteSmokeTester {
  final LocalEngineStateStore _state;
  final DateTime Function() _clock;
  final Stopwatch Function() _stopwatch;

  /// Purpose: Create tester. Inputs: state, clock, stopwatch. Returns: Tester.
  /// Side effects: None. Notes: Existing fingerprint records remain valid.
  RouteSmokeTester({
    required LocalEngineStateStore state,
    DateTime Function()? clock,
    Stopwatch Function()? stopwatch,
  }) : _state = state,
       _clock = clock ?? DateTime.now,
       _stopwatch = stopwatch ?? Stopwatch.new;

  /// Purpose: Check one route. Inputs: engine, route, artifact, clip.
  /// Returns: Stored record. Side effects: Inference and device state writes.
  /// Notes: Shared runner writes crash markers and releases sessions on failure.
  Future<SmokeTestRecord> run({
    required LocalAsrEngine engine,
    required EngineRoute route,
    required ArtifactManifest manifest,
    required Directory artifactDir,
    required SmokeClip clip,
  }) async {
    final record =
        await models.SelfTestRunner(
          store: _state.sharedStore,
          clock: _clock,
        ).run(
          shared.AsrSelfTestFixture(
            engine: AppAsrAdapter(engine),
            route: sharedRoute(route),
            manifest: models.ArtifactManifest.fromJson(manifest.toJson()),
            artifactDir: artifactDir,
            clip: shared.AsrSmokeClip(
              wav: clip.wav,
              expectedText: clip.expectedText,
              seconds: clip.seconds,
              language: clip.language,
            ),
            stopwatch: _stopwatch,
          ),
        );
    final result = SmokeTestRecord.fromJson(record.toJson());
    if (sharedRoute(route).fingerprint.encode() != route.smokeKey) {
      await _state.recordSmokeTest(route.smokeKey, result);
    }
    return result;
  }
}
