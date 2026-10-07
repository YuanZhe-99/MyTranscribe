# lib/features/local/services/artifact_downloader.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `ArtifactDownloader({` | Create a downloader. Inputs: HTTP factory and timeouts. |
| `Future<File> download(` | Fetch and verify a file. Inputs: file, partial, progress, cancel. |
