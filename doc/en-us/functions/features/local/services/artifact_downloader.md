# lib/features/local/services/artifact_downloader.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `ArtifactDownloader({` | Create a downloader. Inputs: HTTP factory and timeouts. |
| `Future<File> download(` | Fetch and verify a file. Inputs: file, partial, progress, cancel. |
