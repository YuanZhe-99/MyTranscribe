/// Purpose: The check every route passes on this device before its first job:
/// a short clip with known words, through the route, compared with those
/// words, and timed.
/// Inputs: An engine, a route, its installed package, and the clip.
/// Returns: A `SmokeTestRecord`, also written to the device's engine state.
/// Side effects: Loads and runs the model; writes the in-flight marker around
/// the native calls and the result afterwards.
/// Notes: This is what makes shipping an untested route bearable (decision D20
/// of the local-models plan): a route that cannot transcribe ten seconds of
/// clear speech correctly on this device never reaches a real recording, and
/// a route that kills the process is caught by the marker at the next start.
/// The threshold is stated in `doc/en-us/algorithms/engine-routing.md`.
library;

import 'dart:async';
import 'dart:io';

import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import 'local_asr_engine.dart';
import 'local_engine_state_store.dart';

/// How close the check's text must be to the expected text, from 0 to 1.
///
/// One minus the word error rate after normalising case and punctuation.
/// 0.8 lets a model spell a number or split a compound differently and still
/// fails one that produced a different sentence, or nothing — which is what a
/// broken GPU kernel usually produces.
const smokeTestMinSimilarity = 0.8;

/// The clip a check transcribes.
class SmokeClip {
  /// The clip, as a 16 kHz mono 16-bit WAV.
  final File wav;

  /// What is said in it.
  final String expectedText;

  /// Its length, in seconds.
  final double seconds;

  /// Its language.
  final String language;

  /// Purpose: Create a clip description.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const SmokeClip({
    required this.wav,
    required this.expectedText,
    required this.seconds,
    this.language = 'en',
  });
}

/// Purpose: Reduce text to comparable words.
/// Inputs: [text].
/// Returns: Lower-case words with punctuation removed.
/// Side effects: None.
/// Notes: Letters and digits of any script are kept, so the same rule works
/// for a clip in another language later.
List<String> normalizedWords(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ')
    .replaceAll("'", '')
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .toList();

/// Purpose: Score how close a transcription is to the expected text.
/// Inputs: The [expected] and [actual] text.
/// Returns: One minus the word error rate, clamped to 0..1.
/// Side effects: None.
/// Notes: Word-level edit distance, so a dropped or invented word costs the
/// same wherever it is. An empty expectation matches only an empty result.
double textSimilarity(String expected, String actual) {
  final a = normalizedWords(expected);
  final b = normalizedWords(actual);
  if (a.isEmpty) return b.isEmpty ? 1 : 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      current[j] = [
        substitution,
        deletion,
        insertion,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  final errors = previous[b.length];
  return (1 - errors / a.length).clamp(0.0, 1.0);
}

/// Runs route checks.
class RouteSmokeTester {
  /// Purpose: Create a tester.
  /// Inputs: The [state] store, and an optional [clock] and [stopwatch]
  /// factory for tests.
  /// Returns: A new tester.
  /// Side effects: None.
  /// Notes: None.
  RouteSmokeTester({
    required LocalEngineStateStore state,
    DateTime Function()? clock,
    Stopwatch Function()? stopwatch,
  }) : _state = state,
       _clock = clock ?? DateTime.now,
       _stopwatch = stopwatch ?? Stopwatch.new;

  final LocalEngineStateStore _state;
  final DateTime Function() _clock;
  final Stopwatch Function() _stopwatch;

  /// Purpose: Check one route on this device.
  /// Inputs: The [engine], the [route], its installed [manifest] and
  /// [artifactDir], and the [clip].
  /// Returns: The record written.
  /// Side effects: Loads and runs the model; writes the in-flight marker and
  /// the result.
  /// Notes: The time counted is the transcription alone, not loading, because
  /// a job loads once and transcribes many windows. An error is a failed check
  /// with its message, never an exception out of here: a check that throws
  /// would leave the route in "not checked" and ask again forever.
  Future<SmokeTestRecord> run({
    required LocalAsrEngine engine,
    required EngineRoute route,
    required ArtifactManifest manifest,
    required Directory artifactDir,
    required SmokeClip clip,
  }) async {
    const jobId = 'smoke-test';
    SmokeTestRecord record;
    String? sessionId;
    await _state.markInFlight(routeKey: route.key, smokeKey: route.smokeKey);
    try {
      final session = await engine.prepare(
        PrepareRequest(
          route: route,
          manifest: manifest,
          artifactDir: artifactDir,
        ),
      );
      sessionId = session.sessionId;
      final watch = _stopwatch()..start();
      final text = StringBuffer();
      LocalAsrException? error;
      await for (final event in engine.transcribe(
        TranscribeRequest(
          jobId: jobId,
          sessionId: session.sessionId,
          pcmWindow: clip.wav,
          windowSeconds: clip.seconds,
          languages: [clip.language],
        ),
      )) {
        if (event.type == AsrEventType.segment && event.segment != null) {
          if (text.isNotEmpty) text.write(' ');
          text.write(event.segment!.text.trim());
        } else if (event.type == AsrEventType.error) {
          error = event.error;
        }
      }
      watch.stop();

      final seconds = watch.elapsedMicroseconds / 1e6;
      final rtf = clip.seconds > 0 ? seconds / clip.seconds : null;
      if (error != null) {
        record = SmokeTestRecord(
          routeKey: route.key,
          outcome: SmokeTestOutcome.failed,
          checkedAt: _clock().toUtc(),
          reason: '${error.code.wire}: ${error.message}',
        );
      } else {
        final similarity = textSimilarity(clip.expectedText, '$text');
        final passed = similarity >= smokeTestMinSimilarity;
        record = SmokeTestRecord(
          routeKey: route.key,
          outcome: passed ? SmokeTestOutcome.passed : SmokeTestOutcome.failed,
          checkedAt: _clock().toUtc(),
          text: '$text',
          similarity: similarity,
          realTimeFactor: rtf,
          reason: passed
              ? null
              : 'The check clip came back ${(similarity * 100).round()} % '
                    'right; ${(smokeTestMinSimilarity * 100).round()} % is '
                    'needed.',
        );
      }
    } on LocalAsrException catch (error) {
      record = SmokeTestRecord(
        routeKey: route.key,
        outcome: SmokeTestOutcome.failed,
        checkedAt: _clock().toUtc(),
        reason: '${error.code.wire}: ${error.message}',
      );
    } catch (error) {
      record = SmokeTestRecord(
        routeKey: route.key,
        outcome: SmokeTestOutcome.failed,
        checkedAt: _clock().toUtc(),
        reason: '$error',
      );
    } finally {
      if (sessionId != null) {
        try {
          await engine.release(sessionId);
        } catch (_) {}
      }
      await _state.clearInFlight();
    }
    await _state.recordSmokeTest(route.smokeKey, record);
    return record;
  }
}
