# lib/features/local/services/pcm_window_cutter.dart

Application contracts and orchestration over shared AI/data services; storage paths, record identities and job history remain application-owned.

## Declarations

| Declaration | Purpose |
|---|---|
| `library;` | Cut one window of the normalized recording as the PCM a local |
| `const PcmWindow({` | Create a window description. |
| `Future<Float32List> readSamples() async {` | Read the samples as floats from -1 to 1. |
| `Future<PcmWindow> readPcmWindow(File file) async {` | Read and check the header of a 16 kHz mono 16-bit WAV. |
| `const PcmWindowCutter(this.toolkit);` | Create a cutter. |
| `Future<PcmWindow> cut(` | Write one window as PCM and check what was written. |
