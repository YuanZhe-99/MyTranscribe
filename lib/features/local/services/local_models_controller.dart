/// Purpose: What the pages know about local models on this device, and the
/// actions they take: download, cancel, remove, verify, check.
/// Inputs: The engine registry, the artifact manager and the engine state.
/// Returns: Riverpod providers — the installed packages, the routes, the
/// engine state — and a controller holding each download's progress.
/// Side effects: Downloads, removes and checks packages when asked.
/// Notes: A download is followed by the route check ("checking this device")
/// on every route the new package has, so a model is ready — or says why it is
/// not — before the user starts a job with it (decision D20 of the
/// local-models plan). See `doc/en-us/features/local-models.md`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artifact_manifest.dart';
import '../models/engine_capability.dart';
import '../models/local_engine_state.dart';
import '../models/local_model_config.dart';
import 'artifact_downloader.dart';
import 'artifact_manager.dart';
import 'engine_registry.dart';
import 'local_model_templates.dart';
import 'route_smoke_test.dart';
import 'smoke_clip.dart';

/// Every package installed on this device, by id.
final installedArtifactsProvider =
    FutureProvider<Map<String, ArtifactManifest>>((ref) async {
      final list = await ref.watch(artifactManagerProvider).installedAll();
      return {for (final manifest in list) manifest.artifactId: manifest};
    });

/// Every route this device has, with its check results.
final localRoutesProvider = FutureProvider<List<EngineRoute>>((ref) async {
  ref.watch(installedArtifactsProvider);
  ref.watch(localEngineStateProvider);
  return ref.watch(engineRegistryProvider).routes();
});

/// This device's engine state.
final localEngineStateProvider = FutureProvider<LocalEngineState>(
  (ref) => ref.watch(localEngineStateStoreProvider).load(),
);

/// Where one model's download or check has got to.
class LocalModelActivity {
  /// The install's progress, while downloading.
  final InstallProgress? progress;

  /// Whether its routes are being checked.
  final bool checking;

  /// Why the last attempt failed, in the engine's or the downloader's words.
  final String? error;

  /// Purpose: Create an activity value.
  /// Inputs: All fields.
  /// Returns: A new immutable value.
  /// Side effects: None.
  /// Notes: None.
  const LocalModelActivity({this.progress, this.checking = false, this.error});

  /// Whether something is running.
  bool get busy => progress != null || checking;
}

/// Downloads, removes and checks local models.
class LocalModelsController
    extends StateNotifier<Map<String, LocalModelActivity>> {
  /// Purpose: Create the controller.
  /// Inputs: The [ref] to read the services through.
  /// Returns: A new controller with nothing running.
  /// Side effects: None.
  /// Notes: The state is keyed by local model id.
  LocalModelsController(this.ref) : super(const {});

  /// Reads the services.
  final Ref ref;

  final _cancels = <String, DownloadCancelToken>{};

  /// Purpose: The packages of [model] this build can use.
  /// Inputs: [model].
  /// Returns: Their template manifests.
  /// Side effects: None.
  /// Notes: Only adapters compiled into this build, and only packages with a
  /// built-in manifest: a package the user added from a file is installed
  /// already and needs no download.
  List<ArtifactManifest> downloadableFor(LocalModelConfig model) {
    final registry = ref.read(engineRegistryProvider);
    return [
      for (final entry in model.artifacts.entries)
        if (registry.engine(entry.key) != null)
          for (final id in entry.value) ?templateArtifact(id),
    ];
  }

  /// Purpose: Download a model's packages, then check its routes.
  /// Inputs: [model].
  /// Returns: None.
  /// Side effects: Downloads and installs; runs the route checks; updates the
  /// state as it goes.
  /// Notes: A failure is kept in the state for the page to show, not thrown.
  Future<void> download(LocalModelConfig model) async {
    if (state[model.id]?.busy ?? false) return;
    final artifacts = ref.read(artifactManagerProvider);
    final cancel = DownloadCancelToken();
    _cancels[model.id] = cancel;
    try {
      for (final manifest in downloadableFor(model)) {
        await artifacts.install(
          manifest,
          cancel: cancel,
          onProgress: (progress) =>
              _set(model.id, LocalModelActivity(progress: progress)),
        );
      }
      _refreshInstalled();
      await checkAll(model);
    } on ArtifactException catch (error) {
      _set(
        model.id,
        error.failure == ArtifactFailure.cancelled
            ? const LocalModelActivity()
            : LocalModelActivity(error: error.message),
      );
    } catch (error) {
      _set(model.id, LocalModelActivity(error: '$error'));
    } finally {
      _cancels.remove(model.id);
    }
  }

  /// Purpose: Stop a download.
  /// Inputs: [model].
  /// Returns: None.
  /// Side effects: Cancels the transfer; the partial file is kept for next
  /// time.
  /// Notes: None.
  void cancel(LocalModelConfig model) => _cancels[model.id]?.cancel();

  /// Purpose: Remove a model's packages from this device.
  /// Inputs: [model].
  /// Returns: None.
  /// Side effects: Deletes the packages.
  /// Notes: The library record stays: it belongs to every device.
  Future<void> remove(LocalModelConfig model) async {
    final artifacts = ref.read(artifactManagerProvider);
    try {
      for (final id in model.artifactIds) {
        await artifacts.remove(id);
      }
      _set(model.id, const LocalModelActivity());
    } on ArtifactException catch (error) {
      _set(model.id, LocalModelActivity(error: error.message));
    }
    _refreshInstalled();
  }

  /// Purpose: Check a model's installed files against their hashes.
  /// Inputs: [model].
  /// Returns: Whether every installed package is intact.
  /// Side effects: Reads every file.
  /// Notes: None.
  Future<bool> verify(LocalModelConfig model) async {
    final artifacts = ref.read(artifactManagerProvider);
    final installed = ref.read(installedArtifactsProvider).value ?? const {};
    for (final id in model.artifactIds) {
      if (!installed.containsKey(id)) continue;
      if (!await artifacts.verify(id)) return false;
    }
    return true;
  }

  /// Purpose: Check every route of a model on this device.
  /// Inputs: [model].
  /// Returns: None.
  /// Side effects: Runs the route checks; records their results.
  /// Notes: None.
  Future<void> checkAll(LocalModelConfig model) async {
    final routes = await ref.read(engineRegistryProvider).routes();
    for (final route in routes) {
      if (route.modelId != model.id || !route.available) continue;
      await check(model, route);
    }
  }

  /// Purpose: Check one route on this device.
  /// Inputs: The [model] and the [route].
  /// Returns: None.
  /// Side effects: Loads and runs the model on the check clip; records the
  /// result.
  /// Notes: None.
  Future<void> check(LocalModelConfig model, EngineRoute route) async {
    final registry = ref.read(engineRegistryProvider);
    final engine = registry.engine(route.adapterId);
    final manifest = await registry.artifacts.installed(route.artifactId);
    final clip = await loadSmokeClip();
    if (engine == null || manifest == null || clip == null) return;
    _set(model.id, const LocalModelActivity(checking: true));
    try {
      await RouteSmokeTester(
        state: ref.read(localEngineStateStoreProvider),
      ).run(
        engine: engine,
        route: route,
        manifest: manifest,
        artifactDir: await registry.artifacts.artifactDir(route.artifactId),
        clip: clip,
      );
    } finally {
      _set(model.id, const LocalModelActivity());
      ref.refresh(localEngineStateProvider);
    }
  }

  /// Purpose: Record one model's activity.
  /// Inputs: The model [id] and its [activity].
  /// Returns: None.
  /// Side effects: Publishes the state.
  /// Notes: Internal helper used within this file only.
  void _set(String id, LocalModelActivity activity) {
    if (!mounted) return;
    state = {...state, id: activity};
  }

  /// Purpose: Make every page re-read what is installed.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Drops the registry's probe cache and refreshes providers.
  /// Notes: Internal helper used within this file only.
  void _refreshInstalled() {
    ref.read(engineRegistryProvider).invalidate();
    ref.refresh(installedArtifactsProvider);
  }
}

/// The one controller.
final localModelsControllerProvider =
    StateNotifierProvider<
      LocalModelsController,
      Map<String, LocalModelActivity>
    >((ref) => LocalModelsController(ref));
