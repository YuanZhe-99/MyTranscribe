import 'dart:io';

import 'package:myapps_ai_models/myapps_ai_models.dart' as shared;

import '../../../shared/services/transcribe_storage.dart';
import '../models/local_engine_state.dart';

/// Application preferences over the shared compatible device-state store.
class LocalEngineStateStore {
  final shared.LocalEngineStateStore sharedStore;
  final DateTime Function() _clock;

  /// Purpose: Create a state store. Inputs: file, clock. Returns: Store.
  /// Side effects: None. Notes: Resolves custom storage for each operation.
  LocalEngineStateStore({
    Future<File> Function()? file,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       sharedStore = shared.LocalEngineStateStore(
         file: file ?? TranscribeStorage.localEngineStateFile,
         clock: clock,
       );

  /// Purpose: Read state. Inputs: None. Returns: App state.
  /// Side effects: Reads disk. Notes: Existing smokeTests format is preserved.
  Future<LocalEngineState> load() async =>
      LocalEngineState.fromJson((await sharedStore.load()).toJson());

  /// Purpose: Mutate state atomically. Inputs: change. Returns: Saved state.
  /// Side effects: Queues disk write. Notes: Keeps app fallback preferences.
  Future<LocalEngineState> update(
    LocalEngineState Function(LocalEngineState) change,
  ) async => LocalEngineState.fromJson(
    (await sharedStore.update(
      (current) => shared.LocalEngineState.fromJson(
        change(LocalEngineState.fromJson(current.toJson())).toJson(),
      ),
    )).toJson(),
  );

  /// Purpose: Mark native work. Inputs: routeKey, smokeKey, jobId. Returns: Completion.
  /// Side effects: Writes marker. Notes: Marker is durable before inference.
  Future<void> markInFlight({
    required String routeKey,
    required String smokeKey,
    String? jobId,
  }) async {
    await update(
      (state) => state.copyWith(
        inFlight: InFlightMarker(
          routeKey: routeKey,
          smokeKey: smokeKey,
          jobId: jobId,
          startedAt: _clock().toUtc(),
        ),
      ),
    );
  }

  /// Purpose: Clear native marker. Inputs: None. Returns: Completion.
  /// Side effects: Writes state. Notes: Called after native return.
  Future<void> clearInFlight() => sharedStore.clearInFlight();

  /// Purpose: Store a route check. Inputs: smokeKey, record. Returns: Completion.
  /// Side effects: Writes state. Notes: Retains original check keys.
  Future<void> recordSmokeTest(String smokeKey, SmokeTestRecord record) async {
    await update(
      (state) =>
          state.copyWith(smokeTests: {...state.smokeTests, smokeKey: record}),
    );
  }

  /// Purpose: Recover a crashed route. Inputs: None. Returns: Previous marker.
  /// Side effects: Records crash and clears marker. Notes: Never auto-reuses a crashed route.
  Future<InFlightMarker?> recoverFromCrash() async {
    final marker = await sharedStore.recoverFromCrash();
    return marker == null ? null : InFlightMarker.fromJson(marker.toJson());
  }
}
