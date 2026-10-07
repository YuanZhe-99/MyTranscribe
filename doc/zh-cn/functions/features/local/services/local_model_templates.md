# lib/features/local/services/local_model_templates.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | The local models the app offers out of the box, and the package |
| `const LocalModelTemplate({required this.model, required this.artifacts});` | Create a template. |
| `ArtifactManifest _whisper({` | Build the whisper.cpp manifest for one model file. |
| `LocalModelConfig _whisperRecord(String id, String name, String artifactId) =>` | Build the Whisper record every Whisper template shares. |
| `List<LocalModelTemplate> buildLocalModelTemplates() => [` | List the built-in local models. |
| `ArtifactManifest? templateArtifact(String artifactId) {` | Find a built-in package manifest by id. |
