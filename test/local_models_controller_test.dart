import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_transcribe/features/local/models/artifact_manifest.dart';
import 'package:my_transcribe/features/local/models/engine_capability.dart';
import 'package:my_transcribe/features/local/services/artifact_downloader.dart';
import 'package:my_transcribe/features/local/services/artifact_manager.dart';
import 'package:my_transcribe/features/local/services/engine_registry.dart';
import 'package:my_transcribe/features/local/services/local_engine_state_store.dart';
import 'package:my_transcribe/features/local/services/local_model_templates.dart';
import 'package:my_transcribe/features/local/services/local_models_controller.dart';

import 'golden/fake_local_asr_engine.dart';

class _Installer extends ArtifactManager {
  /// Purpose: Fake file installation. Inputs: root. Returns: Manager.
  /// Side effects: None. Notes: Never contacts a model host.
  _Installer(Directory root) : super(modelsDir: () async => root);
  int installs = 0;

  /// Purpose: Complete an install without bytes. Inputs: manifest, callbacks.
  /// Returns: Manifest. Side effects: Counts calls. Notes: Test double.
  @override
  Future<ArtifactManifest> install(
    ArtifactManifest manifest, {
    void Function(InstallProgress)? onProgress,
    DownloadCancelToken? cancel,
  }) async {
    installs++;
    onProgress?.call(const InstallProgress(InstallStage.done, 1, 1));
    return manifest;
  }
}

class _ProbeTrap extends FakeLocalAsrEngine {
  /// Purpose: Detect unexpected native probes. Inputs: None. Returns: Engine.
  /// Side effects: None. Notes: No real native code.
  _ProbeTrap() : super(adapterId: whisperCppAdapterId, routes: const []);
  int probes = 0;

  /// Purpose: Count probes. Inputs: manifests. Returns: Routes.
  /// Side effects: Increments counter. Notes: Test double.
  @override
  Future<List<EngineRoute>> probe(List<ArtifactManifest> manifests) async {
    probes++;
    return [];
  }
}

/// Purpose: Verify download completion cannot initialize native runtimes.
/// Inputs: None. Returns: None. Side effects: Temporary storage. Notes: Fake install.
void main() {
  test(
    'download completes idle without probing or preparing any route',
    () async {
      final root = await Directory.systemTemp.createTemp('download_no_native');
      addTearDown(() => root.delete(recursive: true));
      final installer = _Installer(root);
      final engine = _ProbeTrap();
      final store = LocalEngineStateStore(
        file: () async => File('${root.path}/state.json'),
      );
      final registry = EngineRegistry(
        engines: [engine],
        artifacts: installer,
        state: store,
      );
      final container = ProviderContainer(
        overrides: [
          artifactManagerProvider.overrideWithValue(installer),
          engineRegistryProvider.overrideWithValue(registry),
          localEngineStateStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      final model = buildLocalModelTemplates().first.model;
      await container
          .read(localModelsControllerProvider.notifier)
          .download(model);
      expect(installer.installs, 1);
      expect(engine.probes, 0);
      expect(engine.prepared, isEmpty);
      expect(
        container.read(localModelsControllerProvider)[model.id]?.busy,
        isFalse,
      );
      expect(
        container.read(localModelsControllerProvider)[model.id]?.error,
        isNull,
      );
    },
  );
}
