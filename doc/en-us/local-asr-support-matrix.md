# Local model support matrix

Which local model runs on which processor of which device, how well each route is documented to
work, and whether this project has tested it. This page is kept current as routes ship: every
verification record, every route that ships unverified, and every diagnostics report received from
somebody else's hardware goes here. See [`features/local-models.md`](features/local-models.md) for
what the terms mean to the user and
[`algorithms/engine-routing.md`](algorithms/engine-routing.md) for how Auto uses them.

## Grades

The survey's evidence grades, carried in the code as `EvidenceLevel`:

| Grade | Code | Meaning |
|---|---|---|
| **A** | `official` | the runtime's or chip vendor's documentation covers this model on this route |
| **B** | `community` | a reproducible third-party implementation exists |
| **E** | `experimental` | a generic backend exists, but this model × device is unshown |
| **U** | `none` | nothing found |

**Tested here** is a separate fact: this project ran the acceptance list of `PLAN.md` §7 on hardware
of that class and recorded it below. A route that is not tested here still ships, as **unverified
support**: built and covered by CI, checked on each device before its first job, marked as untested
in the product, and used by Auto only when its grade is A or B and it beat the CPU in its check.

## Per target

As surveyed on 2026-09-24. "Planned" names the milestone that builds a route; nothing but the
foundation (L0) exists yet.

| Target | Whisper large-v3 / turbo | Parakeet TDT v3 | Qwen3-ASR 0.6B (1.7B) | Tested here |
|---|---|---|---|---|
| **Windows x64** — Intel / AMD / NVIDIA GPU; Intel NPU; AMD NPU | CPU **B** (whisper.cpp, L1); GPU Vulkan **B** (L3); Intel NPU **A** (OpenVINO GenAI, L7); AMD NPU **A** for the encoder (Ryzen AI 300, L7) | CPU **B** (sherpa-onnx, L2); GPU **B** (transcribe.cpp Vulkan, L3); NPU **U** | CPU **B** (sherpa-onnx int8, L2; 1.7B **E**); GPU **B** (transcribe.cpp Vulkan, L3); NPU **U** | **no** — unverified support; the CPU route also runs under emulation on the ARM64 machine, which checks the code path but not the speed |
| **Windows ARM64** — Snapdragon X Elite; X2 Elite; 8cx Gen 3 | CPU **B** (L1); GPU OpenCL **E** (L3); NPU **A** for turbo only (Qualcomm AI Hub asset, ONNX Runtime QNN, L5a); large-v3 NPU **U** | CPU **B** (L2); GPU **U**; NPU **E** | CPU **B** (L2); GPU **E** (llama.cpp over OpenCL, L3); NPU **U** | **yes** on the 8cx Gen 3 (the development machine): CPU, and OpenCL and QNN where they run on that generation; the X Elite and X2 Elite are unverified |
| **Android** — Snapdragon 8 Gen 3 / 8 Elite / 8 Elite Gen 5 | CPU **B** (L1); GPU OpenCL **E** (L3); NPU **A** for turbo only (per-SoC asset, L5b) | CPU **B** (L2); GPU **E**; NPU **E** | CPU **B** (L2); GPU **E**; NPU **U** | **no** — unverified support |
| **Android** — Google Tensor G3 / G4 / G5 | CPU **E** (L1); GPU Vulkan **E** (L3, an experiment); NPU **U** | CPU **E** (L2); GPU **E**; NPU not planned (the Tensor SDK was declined) | CPU **E** (L2); GPU **E**; NPU **U** | **yes** on the G5 (Pixel 10): CPU, the Vulkan experiment; G3 and G4 are unverified |
| **Android** — MediaTek Dimensity, Samsung Exynos | CPU **E** (L1); GPU Vulkan **E**; NPU **U** | CPU **E** (L2); GPU **E**; NPU **U** | CPU **E** (L2); GPU **E**; NPU **U** | **no** — unverified support |
| **macOS** — Apple Silicon (Intel: CPU only) | CPU and Metal **B** (L1); Core ML encoder **B** (L1); WhisperKit **B** (optional, L4) | CPU **B** (L2); Neural Engine **B** (FluidAudio, L4) | CPU **B** (L2); Neural Engine **B/E** (FluidAudio, 0.6B only, behind a quality gate, L4) | **yes** on Apple Silicon (the 2024 Mac mini); Intel Macs are unverified |
| **iOS** — A-series / M-series | CPU and Metal **B** (L1); Core ML encoder **B** (L1) | CPU **B** (L2); Neural Engine **B** (L4) | CPU **B** (L2); Neural Engine **B/E** (L4) | on an iPhone if one is available; otherwise the Simulator checks the code path and the device routes are unverified |
| **OS recogniser** (L6) | iOS/macOS 26+ `SpeechAnalyzer` on-device **A**; below that `SFSpeechRecognizer` on-device **A** where the locale supports it; Android on-device **A**, file input **E**; Windows none | | | the Pixel 10 and the Mac |

## Verification records

One entry per route verified on this project's hardware: device, OS, driver, runtime versions,
package hash, quantization and decoding settings, real-time factor, first-result latency, peak
memory, and the date.

None yet. A route is recorded here only once §7's acceptance list holds for it, including the
line-by-line comparison of a real recording, which needs the user.

### Measured, not yet verified: Windows ARM64, whisper.cpp CPU, large-v3-turbo (2026-09-25)

- **Device**: a Snapdragon 8cx Gen 3 laptop, 8 cores, 32 GB; Windows 11 Pro 10.0.26200.9457. CPU
  only, so no driver is involved.
- **Runtime**: whisper.cpp v1.9.4 from this project's Windows ARM64 set (`whisper-bin-v1.9.4-1`:
  ARMv8.2 with dot-product and FP16, no OpenMP), bindings `prebuilt1`.
- **Package**: `ggml-large-v3-turbo.bin`, f16, SHA-256
  `1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69`; greedy decoding, flash
  attention off, 8 threads (the thread policy at the time).
- **Recording**: an 81.4-minute English lecture in 9 windows. Wall time 145.7 min, **RTF 1.79**;
  the route check on the 11-second clip ran at RTF 2.53 and passed. Peak memory 2.65 GB. Every
  window ran on the CPU; no fallback.
- **Against a MAI-Transcribe-2 transcript of the same recording**: 8,331 words against 6,809, and
  a word-level agreement (1 − WER) of 36.9 %. The measure counts every filler word and repetition
  Whisper keeps and the reference service drops, so it does not by itself show a quality problem
  — and it is not a pass either.
- **Threads**, large-v3-turbo on the check clip: 4 → RTF 2.43, 6 → 1.89, 7 → 1.91, 8 → 3.04.
  Upstream's own ARM64 command-line build (OpenMP, ARMv8.7) took RTF 4.75 at 8 threads on the same
  clip, so the build is not the slow part. The engine now leaves two cores free.
- **What it means**: turbo in f16 runs slower than real time on this CPU. The q5_0 package is the
  candidate for a CPU route that keeps up, and OpenCL on the Adreno GPU (L3) for an accelerated
  one. The route is not in the tested-here table.

## Unverified routes

Routes that ship without a test on their class of hardware, with the reason and what gates them.

Every route that ships is here, since none has a verification record yet (the user decided on
2026-09-25 that no device sessions are held). Each is gated the same way: its check on the device
before its first job, the in-flight marker, and the fallback policy (decision D20).

| Route | Since | Grade | Why unverified | What was run here |
|---|---|---|---|---|
| whisper.cpp CPU — Whisper, Parakeet | 0.3.0, 0.3.1 | **B** (**E** on Android) | no verification record on any class | the 8cx Gen 3: the JFK clip end to end; the 81-minute lecture through turbo, measured above |
| sherpa-onnx CPU — Qwen3-ASR | 0.3.1 | **B** (**E** on Android) | as above; not on iOS | the 8cx Gen 3: the JFK clip end to end |
| Metal — Whisper (Parakeet **E**) | 0.3.0 | **B** | no Mac or iPhone sessions | nothing |
| Vulkan — Windows x64 | 0.3.2 | **B** | no x64 machine | nothing |
| Vulkan — Android arm64 | 0.3.2 | **E** | no phone sessions; needs Android 9 | nothing |
| OpenCL — Adreno on Windows ARM64 and Android arm64 | 0.3.2 | **E** | the 8cx Gen 3 has no OpenCL driver ggml can use (Microsoft's OpenCLOn12 lacks FP16, so the device is dropped) | the backend loads and drops the device, as it should |

An **E** route runs only when the user chooses it, after its check on that device passed.

## Reports from other hardware

Diagnostics reports sent by people with hardware this project does not have, recorded with their
date. A report can raise a route's evidence grade; it never makes the route tested here.

None yet.
