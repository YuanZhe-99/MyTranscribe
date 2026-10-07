# lib/features/local/engines/fluid_audio_engine.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `FluidAudioEngine()` | Create a runtime. Inputs: None. Returns: Engine. |
| `List<AsrSegment> segmentsFrom(` | Join timed tokens. Inputs: result, seconds. Returns: Segments. |
