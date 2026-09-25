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
| **Windows ARM64** — Snapdragon X Elite; X2 Elite | CPU **B** (L1); GPU OpenCL **E** (L3); NPU **A** for turbo only (Qualcomm AI Hub asset, ONNX Runtime QNN, L5a); large-v3 NPU **U** | CPU **B** (L2); GPU **U**; NPU **E** | CPU **B** (L2); GPU **E** (llama.cpp over OpenCL, L3); NPU **U** | **yes** on the X Elite: CPU, OpenCL, QNN; the X2 Elite is unverified |
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

None yet — the first engine arrives in L1.

## Unverified routes

Routes that ship without a test on their class of hardware, with the reason and what gates them.

None yet — no route ships before L1.

## Reports from other hardware

Diagnostics reports sent by people with hardware this project does not have, recorded with their
date. A report can raise a route's evidence grade; it never makes the route tested here.

None yet.
