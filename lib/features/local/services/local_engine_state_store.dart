/// Purpose: Read and write `local_engine_state.json`, and turn an in-flight
/// marker left behind by a crash into a recorded result.
/// Inputs: The state file, from the storage hub.
/// Returns: The state, and the marker a crash left behind.
/// Side effects: Reads and writes the state file.
/// Notes: Writes are serialised inside the store and each is a
/// read-modify-write, so a check result recorded while a job updates the
/// in-flight marker cannot lose either. Every write is atomic: a crash — the
/// very thing the marker exists for — must not also truncate the file that
/// records it. See `doc/en-us/features/local-models.md`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:myapps_data/myapps_data.dart' show atomicWriteString;

import '../../../shared/services/transcribe_storage.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';

/// Reads and writes the device-local engine state.
class LocalEngineStateStore {
  /// Purpose: Create a store.
  /// Inputs: Optional [file] resolver and [clock], for tests.
  /// Returns: A new store.
  /// Side effects: None.
  /// Notes: None.
  LocalEngineStateStore({
    Future<File> Function()? file,
    DateTime Function()? clock,
  }) : _file = file ?? TranscribeStorage.localEngineStateFile,
       _clock = clock ?? DateTime.now;

  final Future<File> Function() _file;
  final DateTime Function() _clock;
  Future<void> _tail = Future.value();

  /// Purpose: Read the state.
  /// Inputs: None.
  /// Returns: The state; the empty state when the file is absent or
  /// unreadable.
  /// Side effects: Reads the file.
  /// Notes: An unreadable file reads as a device that never checked anything,
  /// which costs a re-check and never a wrong answer.
  Future<LocalEngineState> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const LocalEngineState();
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, dynamic>
          ? LocalEngineState.fromJson(json)
          : const LocalEngineState();
    } catch (_) {
      return const LocalEngineState();
    }
  }

  /// Purpose: Change the state.
  /// Inputs: A [change] applied to the state as it is on disk now.
  /// Returns: The state written.
  /// Side effects: Rewrites the file atomically.
  /// Notes: Queued behind any write already running.
  Future<LocalEngineState> update(
    LocalEngineState Function(LocalEngineState current) change,
  ) {
    final result = Completer<LocalEngineState>();
    _tail = _tail.then((_) async {
      try {
        final next = change(await load());
        final file = await _file();
        await file.parent.create(recursive: true);
        await atomicWriteString(
          file,
          const JsonEncoder.withIndent('  ').convert(next.toJson()),
        );
        result.complete(next);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  /// Purpose: Record that a native call is starting on a route.
  /// Inputs: [routeKey], [smokeKey], and the [jobId] when it is for a job.
  /// Returns: None.
  /// Side effects: Writes the marker.
  /// Notes: Written and flushed before the call, so a process that dies inside
  /// it leaves the marker behind for [recoverFromCrash] to find.
  Future<void> markInFlight({
    required String routeKey,
    required String smokeKey,
    String? jobId,
  }) => update(
    (state) => state.copyWith(
      inFlight: InFlightMarker(
        routeKey: routeKey,
        smokeKey: smokeKey,
        jobId: jobId,
        startedAt: _clock().toUtc(),
      ),
    ),
  );

  /// Purpose: Record that the native call returned.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Removes the marker.
  /// Notes: Called whether the call succeeded, failed or was cancelled — only
  /// a process that died never reaches it.
  Future<void> clearInFlight() =>
      update((state) => state.copyWith(clearInFlight: true));

  /// Purpose: Record one route's check.
  /// Inputs: The encoded [smokeKey] and the [record].
  /// Returns: None.
  /// Side effects: Writes the result.
  /// Notes: None.
  Future<void> recordSmokeTest(String smokeKey, SmokeTestRecord record) =>
      update(
        (state) =>
            state.copyWith(smokeTests: {...state.smokeTests, smokeKey: record}),
      );

  /// Purpose: Find the marker a crash left behind and record the crash.
  /// Inputs: None.
  /// Returns: The marker, or null when the last run ended cleanly.
  /// Side effects: Records the route as `crashed` under the marker's key, and
  /// removes the marker.
  /// Notes: Called once at startup, before any job runs. From then on the
  /// router never picks that route automatically under that key; the job the
  /// marker names resumes under the fallback policy.
  Future<InFlightMarker?> recoverFromCrash() async {
    InFlightMarker? found;
    await update((state) {
      final marker = state.inFlight;
      if (marker == null) return state;
      found = marker;
      return state.copyWith(
        clearInFlight: true,
        smokeTests: {
          ...state.smokeTests,
          marker.smokeKey: SmokeTestRecord(
            routeKey: marker.routeKey,
            outcome: SmokeTestOutcome.crashed,
            checkedAt: _clock().toUtc(),
            reason:
                'The app stopped while this route was running '
                '(started ${marker.startedAt.toIso8601String()}).',
          ),
        },
      );
    });
    return found;
  }
}
