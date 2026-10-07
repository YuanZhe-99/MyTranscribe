import 'dart:io';

import 'package:myapps_ai_models/myapps_ai_models.dart' as shared;

import '../../../shared/services/transcribe_storage.dart';
import '../models/artifact_manifest.dart';
import 'artifact_downloader.dart';

export 'package:myapps_ai_models/myapps_ai_models.dart'
    show InstallStage, InstallProgress, SpaceBudget, ArtifactLease;

/// Preserves application model paths over the shared atomic installer.
class ArtifactManager {
  final shared.ArtifactManager sharedManager;

  /// Purpose: Create an installer. Inputs: storage, downloader, probes.
  /// Returns: Manager. Side effects: None. Notes: Existing downloads are reused.
  ArtifactManager({
    Future<Directory> Function()? modelsDir,
    ArtifactDownloader? downloader,
    Future<int?> Function(Directory)? freeSpace,
    String? platform,
    DateTime Function()? clock,
  }) : sharedManager = shared.ArtifactManager(
         storage: shared.CallbackModelStorageRoot(
           modelsDir ?? TranscribeStorage.modelsDir,
         ),
         downloader: (downloader ?? ArtifactDownloader()).sharedDownloader,
         freeSpace: freeSpace,
         clock: clock,
         platform: platform == null ? null : shared.ModelPlatform(platform),
       );

  /// Purpose: Locate an artifact. Inputs: artifactId. Returns: Directory.
  /// Side effects: Resolves storage. Notes: Existing path layout is preserved.
  Future<Directory> artifactDir(String artifactId) =>
      sharedManager.artifactDir(artifactId);

  /// Purpose: Read an installed manifest. Inputs: artifactId. Returns: Manifest.
  /// Side effects: Reads disk. Notes: Unknown fields survive conversion.
  Future<ArtifactManifest?> installed(String artifactId) async {
    final manifest = await sharedManager.installed(artifactId);
    return manifest == null
        ? null
        : ArtifactManifest.fromJson(manifest.toJson());
  }

  /// Purpose: List installed packages. Inputs: None. Returns: Manifests.
  /// Side effects: Reads disk. Notes: No downloads.
  Future<List<ArtifactManifest>> installedAll() async => [
    for (final manifest in await sharedManager.installedAll())
      ArtifactManifest.fromJson(manifest.toJson()),
  ];

  /// Purpose: Estimate required space. Inputs: manifest. Returns: Budget.
  /// Side effects: Reads partials. Notes: Includes unpacking.
  Future<shared.SpaceBudget> spaceNeeded(ArtifactManifest manifest) =>
      sharedManager.spaceNeeded(
        shared.ArtifactManifest.fromJson(manifest.toJson()),
      );

  /// Purpose: Hold package files. Inputs: artifactId. Returns: Lease.
  /// Side effects: Counts lease. Notes: Blocks removal and replacement.
  shared.ArtifactLease lease(String artifactId) =>
      sharedManager.lease(artifactId);

  /// Purpose: Check active leases. Inputs: artifactId. Returns: Whether held.
  /// Side effects: None. Notes: None.
  bool isLeased(String artifactId) => sharedManager.isLeased(artifactId);

  /// Purpose: Install a package. Inputs: manifest, progress, cancel.
  /// Returns: Installed manifest. Side effects: Downloads and disk.
  /// Notes: Shared installer verifies hashes before atomic publication.
  Future<ArtifactManifest> install(
    ArtifactManifest manifest, {
    void Function(shared.InstallProgress)? onProgress,
    shared.DownloadCancelToken? cancel,
  }) async => ArtifactManifest.fromJson(
    (await sharedManager.install(
      shared.ArtifactManifest.fromJson(manifest.toJson()),
      onProgress: onProgress,
      cancel: cancel,
    )).toJson(),
  );

  /// Purpose: Verify installed files. Inputs: artifactId. Returns: Validity.
  /// Side effects: Hashes disk files. Notes: No network.
  Future<bool> verify(String artifactId) => sharedManager.verify(artifactId);

  /// Purpose: Remove downloaded files. Inputs: artifactId. Returns: Completion.
  /// Side effects: Deletes package. Notes: Keeps source records and job history.
  Future<void> remove(String artifactId) => sharedManager.remove(artifactId);
}
