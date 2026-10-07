# lib/features/local/services/artifact_manager.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `ArtifactManager({` | Create an installer. Inputs: storage, downloader, probes. |
| `Future<Directory> artifactDir(String artifactId) =>` | Locate an artifact. Inputs: artifactId. Returns: Directory. |
| `Future<ArtifactManifest?> installed(String artifactId) async {` | Read an installed manifest. Inputs: artifactId. Returns: Manifest. |
| `Future<List<ArtifactManifest>> installedAll() async => [` | List installed packages. Inputs: None. Returns: Manifests. |
| `Future<shared.SpaceBudget> spaceNeeded(ArtifactManifest manifest) =>` | Estimate required space. Inputs: manifest. Returns: Budget. |
| `shared.ArtifactLease lease(String artifactId) =>` | Hold package files. Inputs: artifactId. Returns: Lease. |
| `bool isLeased(String artifactId) => sharedManager.isLeased(artifactId);` | Check active leases. Inputs: artifactId. Returns: Whether held. |
| `Future<ArtifactManifest> install(` | Install a package. Inputs: manifest, progress, cancel. |
| `Future<bool> verify(String artifactId) => sharedManager.verify(artifactId);` | Verify installed files. Inputs: artifactId. Returns: Validity. |
| `Future<void> remove(String artifactId) => sharedManager.remove(artifactId);` | Remove downloaded files. Inputs: artifactId. Returns: Completion. |
