# lib/features/local/services/speaker_labeler.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `List<RawSegment> labelSegments(` | Attach window-local labels. Inputs: segments, turns. Returns: Segments. |
| `SpeakerLabeler({required this.artifacts}) {` | Create a labeler. Inputs: artifacts. Returns: Labeler. |
| `Future<bool> available() async =>` | Check package presence. Inputs: None. Returns: Presence. |
| `Future<List<RawSegment>> label(File pcm, List<RawSegment> segments) async {` | Label a window. Inputs: pcm, segments. Returns: Labeled segments. |
