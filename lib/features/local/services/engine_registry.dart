/// Purpose: Know which local engine adapters this build has, what routes they
/// offer on this device, and what each route's check here found.
/// Inputs: The adapters compiled into the build, the artifact manager and the
/// engine state store.
/// Returns: Routes with their check results attached; an adapter by id.
/// Side effects: Probes the adapters, which may query drivers.
/// Notes: An adapter not compiled in is absent, not disabled — the registry
/// only ever lists what the build actually has, which is how the diagnostics
/// page can say "not built" honestly. Probe results are cached for the session
/// and dropped when a package is installed or removed; check results are read
/// fresh each time, since they change while the app runs. See
/// `doc/en-us/features/local-models.md`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/platform_capabilities.dart';
import '../engines/fluid_audio_engine.dart';
import '../engines/sherpa_onnx_engine.dart';
import '../engines/whisper_cpp_engine.dart';
import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import 'artifact_manager.dart';
import 'local_asr_engine.dart';
import 'local_engine_state_store.dart';

/// The adapters this build contains.
class EngineRegistry {
  /// Purpose: Create a registry.
  /// Inputs: The [engines] compiled in, the [artifacts] manager, the [state]
  /// store.
  /// Returns: A new registry.
  /// Side effects: None until [routes] is called.
  /// Notes: None.
  EngineRegistry({
    required List<LocalAsrEngine> engines,
    required this.artifacts,
    required this.state,
  }) : engines = List.unmodifiable(engines);

  /// The adapters, in the order they were registered.
  final List<LocalAsrEngine> engines;

  /// The packages on this device.
  final ArtifactManager artifacts;

  /// The device-local engine state.
  final LocalEngineStateStore state;

  List<EngineRoute>? _probed;

  /// Purpose: Find an adapter by id.
  /// Inputs: [adapterId].
  /// Returns: The adapter, or null when this build has none by that id.
  /// Side effects: None.
  /// Notes: None.
  LocalAsrEngine? engine(String adapterId) {
    for (final engine in engines) {
      if (engine.adapterId == adapterId) return engine;
    }
    return null;
  }

  /// Purpose: List every route this device has, with its check results.
  /// Inputs: [refresh] to probe again rather than use the session's cache.
  /// Returns: The routes.
  /// Side effects: Probes the adapters on the first call and after [refresh]
  /// or [invalidate]; reads the state file every time.
  /// Notes: An adapter whose probe throws contributes no routes rather than
  /// taking the others down with it.
  Future<List<EngineRoute>> routes({bool refresh = false}) async {
    if (refresh || _probed == null) {
      final installed = await artifacts.installedAll();
      final probed = <EngineRoute>[];
      for (final engine in engines) {
        final mine = <ArtifactManifest>[
          for (final manifest in installed)
            if (manifest.adapterId == engine.adapterId) manifest,
        ];
        try {
          probed.addAll(await engine.probe(mine));
        } catch (_) {
          // A broken adapter is reported by its absence on the diagnostics
          // page; it must not hide the routes of the adapters that work.
        }
      }
      _probed = probed;
    }
    final current = await state.load();
    return [
      for (final route in _probed!)
        route.withSmokeTest(current.smokeTestFor(route.smokeKey)),
    ];
  }

  /// Purpose: Forget the cached probe results.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: The next [routes] call probes again.
  /// Notes: Called after a package is installed or removed.
  void invalidate() => _probed = null;
}

/// The artifact manager, shared so leases are seen by every holder.
final artifactManagerProvider = Provider<ArtifactManager>(
  (ref) => ArtifactManager(),
);

/// The engine state store, shared so its writes are serialised in one place.
final localEngineStateStoreProvider = Provider<LocalEngineStateStore>(
  (ref) => LocalEngineStateStore(),
);

/// The whisper.cpp engine, one per app: its worker isolate owns every loaded
/// Whisper model.
final whisperCppEngineProvider = Provider<WhisperCppEngine>(
  (ref) => WhisperCppEngine(),
);

/// The Parakeet engine, one per app: whisper.cpp's own Parakeet runtime, with
/// a worker isolate of its own (decision D22 of the local-models plan).
final parakeetCppEngineProvider = Provider<WhisperCppEngine>(
  (ref) => WhisperCppEngine(family: GgmlFamily.parakeet),
);

/// The sherpa-onnx engine, one per app, for Qwen3-ASR (decision D22).
final sherpaOnnxEngineProvider = Provider<SherpaOnnxEngine>(
  (ref) => SherpaOnnxEngine(),
);

/// The FluidAudio engine, one per app: Parakeet on the Neural Engine (L4).
final fluidAudioEngineProvider = Provider<FluidAudioEngine>(
  (ref) => FluidAudioEngine(),
);

/// The engine registry: every adapter this build compiles in.
final engineRegistryProvider = Provider<EngineRegistry>(
  (ref) => EngineRegistry(
    engines: [
      ref.watch(whisperCppEngineProvider),
      ref.watch(parakeetCppEngineProvider),
      ref.watch(sherpaOnnxEngineProvider),
      // Only where the bridge exists, so no Core ML package is offered
      // elsewhere.
      if (hasNeuralEngineBridge) ref.watch(fluidAudioEngineProvider),
    ],
    artifacts: ref.watch(artifactManagerProvider),
    state: ref.watch(localEngineStateStoreProvider),
  ),
);
