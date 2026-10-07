# lib/features/local/services/tested_here.dart

共享 AI/数据服务之上的应用契约与编排；存储路径、记录 ID 与任务历史仍由应用管理。

## 声明

| Declaration | Purpose |
|---|---|
| `library;` | The routes this project has verified on real hardware, by device |
| `String currentDeviceClass() => localDeviceClass(` | Name this device's class. |
| `bool isTestedHere(EngineRoute route, {String? deviceClass}) {` | Say whether a route was verified on this device's class. |
| `EvidenceLevel get cpuEvidence => currentDeviceClass() == 'android'` | The evidence grade of whisper.cpp's CPU route on this device. |
| `String gpuBackendName(String name) {` | Name a GPU route's backend from the device name ggml reports. |
| `EvidenceLevel gpuEvidence(` | The evidence grade of a whisper.cpp GPU route on this device. |
