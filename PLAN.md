# MyTranscribe!!!!! — plan: local models

The phased roadmap for transcribing **on the device**. `AGENTS.md` says how to work here;
`doc/en-us/` says what the code does; this file says what is to be built, in what order, and why
the order is what it is. It was written on 2026-09-24 from a survey of the runtimes and model
packages available that day. Every external claim below carries the date it was checked, because
this field moves monthly, and an implementer who finds a claim stale should re-verify it and note
the correction in the decisions log rather than build on the stale version.

**The user asked for this plan and settled its open questions on 2026-09-24** (the first entry of
the decisions log): release 0.3.0 first, unverified support for the devices this project cannot
test (D20), the iOS 17 / macOS 14 deployment targets (D12), no Tensor SDK (D14), and the plan's
defaults for everything else. Nothing below waits for another decision from the user except the
two confirmations `AGENTS.md` always requires — the version of each later release and every push.
`AGENTS.md` still says this repository has no on-device AI; that sentence describes the app before
this plan, L0 rewrites it, and it is not a reason to stop work under this plan.

**This file is temporary.** It replaces the 0.1.0–0.2.1 plan, whose nine milestones are all closed
and recorded in `doc/en-us/version-history.md`. When the last milestone here is closed, the
closing steps in §10 delete it, and nothing in `doc/` may depend on it by then. Until then,
`AGENTS.md`'s rule stands: a change that touches a milestone updates its checklist in the same
commit, and a decision that later work should not quietly reverse goes into the decisions log at
the end.

## 1. Where this plan starts

At 0.2.1 the app sends every recording to a service the user configured — OpenAI, OpenRouter, or
any OpenAI-compatible endpoint, including one they run themselves. It splits a long recording into
overlapping windows with FFmpeg, uploads them one at a time, resumes an interrupted run, joins the
pieces back into one transcript with the overlap merge, and names who spoke where the model
supports it. The only network endpoints it knows are those services, the user's WebDAV server,
and the published FFmpeg build it offers to download on Windows.

What this plan adds, in order of certainty:

1. **A downloaded model transcribes the recording on this device.** No key, no network once the
   model is on disk, and the audio never leaves the device. Three model families, chosen because
   each has a maintained open-weight release and at least one runtime with a C ABI that a Flutter
   app can link on all four of our platforms: OpenAI **Whisper large-v3** and **large-v3-turbo**,
   NVIDIA **Parakeet TDT 0.6B v3**, and the newest open Qwen ASR release (§2.2 names it).
2. **The GPU or NPU, where a specific model × chip pair has a route.** Not a global "use
   hardware acceleration" switch: an option appears only when this device, this model package and
   this runtime have a route that passed its smoke test on this device, and what actually ran is
   recorded on the job. Most of the devices this app runs on cannot be tested by this project, so
   their routes ship as **unverified support**, say so, and are held to stricter rules (D20).
3. **Optionally, the operating system's own recogniser** on iOS, macOS and Android when nothing is
   downloaded — a fallback with its own privacy line, never a silent substitute.

Out of scope, deliberately: live microphone transcription (the app does not record; the only
microphone permission it will ever ask for is the one Android's recogniser checks even when it is
given a file, and only once the user turns that fallback on — L6), training or fine-tuning, a
model server, translation, Linux and Web. A request for one of those is a request for a different
app, per `AGENTS.md`.

Two constraints from the existing code shape everything below and are worth restating:

- **This project is developed on Windows on ARM64** (a Snapdragon X machine), and CI builds
  Windows x64 and ARM64 separately. A dependency that ships x86_64-only Windows binaries cannot be
  used; that is why FFmpeg is vendored and why `audioplayers` was chosen. Every native piece here
  is built from source for ARM64 or fetched as an ARM64 archive, and verified with a real
  `flutter build windows` on the ARM64 machine before it is called done.
- **The test phone is a Pixel 10** — a Google Tensor G5, not a Snapdragon. Qualcomm Android
  routes can be built here but not verified here; they ship as unverified support (D20), and the
  plan says so wherever it matters rather than pretending a build is a verification.

## 2. What the survey established (2026-09-24)

The basis is the research report `Flutter_Local_ASR_Integration_Guide_ZH.md` (checked
2026-09-09; kept outside this repository). Its architecture, its evidence grades (A official /
B community / E generic backend only / U none) and its rules are adopted. Four things it lacked,
and what was found:

### 2.1 Corrections and additions to the report

1. **Qwen: there is no newer open-weight Qwen ASR model.** The newest open weights are still
   **Qwen3-ASR-0.6B / 1.7B and Qwen3-ForcedAligner-0.6B** (released 2026-01-29; re-packaged as
   `-hf` repositories in the native Transformers format on 2026-06-26; a hotword chat-template
   change on 2026-07-22). Everything Alibaba has shipped for ASR since — `qwen-audio-3.0-asr-flash`
   (2026-07-30), `qwen-audio-3.1-asr-flash` / `-filetrans` / `-streaming` and the announced
   "ASR-Next" (2026-09-22/23), `qwen3.8-livetranslate-flash-realtime` (2026-09-17) — is
   **API-only** on Model Studio / QwenCloud, with no weights, no licence and no GitHub or Hugging
   Face release. A "Qwen3.5-Omni" open variant claimed by third-party blogs does not exist in the
   Qwen Hugging Face organisation. So this plan uses **Qwen3-ASR**, and the implementer re-checks
   `huggingface.co/Qwen` at lock time; the `localModel` record's `family` field and the manifest
   scheme are designed so that a newer open release becomes a new template, not a code change.
   (Checked 2026-09-24 against the QwenLM GitHub organisation, the Qwen HF organisation sorted by
   modification date, the Model Studio changelog and the arXiv report 2601.21337.)
   The API models could reach this app through the existing OpenAI-compatible source — Model
   Studio's `compatible-mode` endpoint accepts `input_audio` for `qwen3-asr-flash` only — but that
   is a cloud feature and out of this plan's scope.
2. **Google Tensor** (the Pixel 8/9/10 family — the test phone is a Pixel 10) is surveyed in §2.4.
   In one line: CPU is the shippable route; the GPU is a Vulkan experiment with a driver that has
   had correctness bugs; the NPU is reachable only through a sign-up-gated beta SDK, for Parakeet
   only, and the user decided not to apply for it (D14).
3. **Qualcomm on Windows and on Android are different targets** with different runtimes, packaging,
   signing rules and model assets — §2.5. The report's "Qualcomm" rows are split accordingly.
4. **The operating system's own recogniser** as a fallback — §2.6 — exists on iOS, macOS and
   Android with file input, and does not exist as a file-transcription API on Windows.

New since the report, independent of the four gaps:

- **whisper.cpp v1.9.4** (2026-09-11). Its ggml tree now carries an **OpenCL backend verified
  by upstream on Adreno on both Android and Windows 11 ARM64**, an experimental **Hexagon NPU
  backend** (Android and Windows on Snapdragon; the Windows guide requires test-signing), and a
  **full OpenVINO backend** (Intel CPU/GPU/NPU, validated on Core Ultra for LLMs) separate from the
  older encoder-only `WHISPER_OPENVINO` path. Whether whisper's own graph runs correctly on the
  OpenCL and OpenVINO backends is **E** until the smoke test says so; both are known to be
  LLM-first.
- **Flutter 3.44**: build hooks (`hook/build.dart`) are the recommended way to bind native code
  since 3.38 and need no per-OS build files; Swift Package Manager is the default for iOS and
  macOS. Both decide how the native packages here are built (D9, D12).
- **FluidAudio v0.17.1** (2026-09-23) requires **iOS 17 / macOS 14**; **argmax-oss-swift v1.1.0**
  (WhisperKit, 2026-08-06) requires iOS 16 / macOS 13. The app is at iOS 14 / macOS 10.15; the
  user approved raising it to iOS 17 / macOS 14 (D12).
- The two whisper.cpp pub packages (`whisper_ggml` 2.6.0, `whisper_cpp_flutter_plus` 0.4.1) are
  not usable on this project's Windows ARM64 machine (D9).
- NVIDIA has newer open ASR models than Parakeet v3 — `parakeet-unified-en-0.6b` (2026-04,
  English only) and `nemotron-3.5-asr-streaming-0.6b` (2026-06, 40 locales including Japanese,
  Korean and Mandarin; streaming RNNT; licence `openmdw-1.1`) — but neither has a sherpa-onnx or
  Core ML export verified today. Parakeet TDT 0.6B v3 stays the Parakeet in this plan; the
  Nemotron model is a watch item for CJK coverage. OpenAI has released no open Whisper since
  large-v3-turbo (2024-10); `gpt-realtime-whisper` (2026-05) is API-only.

### 2.2 The models

| Family | Exact model | Sizes (as published) | Languages | Timestamps | Licence | Do not confuse with |
|---|---|---|---|---|---|---|
| Whisper | `openai/whisper-large-v3` | ggml `large-v3` 2.9 GiB, `large-v3-q5_0` 1.1 GiB; whisper.cpp lists ~3.9 GB RAM for the f16 large model | ~100, incl. zh, ja, en | segment native; token/word via DTW (`dtw_aot_preset` for large-v3) | MIT (upstream); record per artifact | Turbo, Distil |
| Whisper | `openai/whisper-large-v3-turbo` | ggml `large-v3-turbo` 1.5 GiB, `large-v3-turbo-q5_0` 547 MiB | as large-v3 | as large-v3 (`dtw_aot_preset` for turbo) | MIT | large-v3 — four decoder layers, not thirty-two |
| Parakeet | `nvidia/parakeet-tdt-0.6b-v3` (2025-08-14) | sherpa-onnx int8 ≈ 0.6 GB (read the release page); LiteRT i8 614 MB | 25 European languages — **no zh, ja, ko** | token and segment, native | CC-BY-4.0 — attribution survives conversion | v2 (English), CTC, EOU, Unified |
| Qwen | `Qwen/Qwen3-ASR-0.6B` and `-1.7B` (2026-01-29; `-hf` 2026-06-26) | sherpa-onnx 0.6B int8 tarball 838 MiB (conv frontend 42 MB, encoder 174 MB, decoder 721 MB); GGUF Q8_0 0.6B 850 MB, 1.7B 2.19 GB (transcribe.cpp) or 805 MB + 214 MB mmproj, 2.17 GB + 356 MB (ggml-org); Core ML 0.6B f32 ~2.5 GB, int8 ~0.7 GB | 30 languages + 22 Chinese dialects, incl. zh, yue, ja, ko, en | **none natively**; only with `Qwen3-ForcedAligner-0.6B` (11 languages, ≤ 5 min per call), which none of the ports here carry | Apache-2.0 | Qwen3-ASR-Flash and Qwen-Audio-3.x (API only); Qwen3-Omni; Qwen3-TTS |

Practical limits that bound a window (§4.3): Whisper has no per-request limit of its own (the
runtime slides its own 30 s frames); Qwen's official runtime documents no limit, its GGUF port
takes about 87 minutes per call (a 65,536-token decoder context), the MLX port chunks at 20
minutes, and llama.cpp's port has an open bug past about two minutes; Parakeet v3 is bound by
attention memory, roughly 24 minutes on a workstation. **The record's `maxDurationSeconds` for a
local model is therefore an app ceiling chosen for memory and progress (10 minutes to start),
not a promise from the model**, and the planner says so in its reason.

Qwen3-ASR emits `language <name><asr_text>…`; the official runtimes and sherpa-onnx strip it,
llama.cpp's server does not (open issue). sherpa-onnx v1.13.7 (2026-09-01) aligned its Qwen
features to the centred-STFT convention and v1.13.8 (2026-09-10) fixed hallucinated text on
silence when hotwords or a language are set — pin at or above 1.13.8. The 1.7B model has no
published sherpa-onnx export (issue #3535, open since 2026-04-21); the export script exists, and
producing one is an optional task inside L2, not a dependency of it.

### 2.3 The runtimes and how each reaches Flutter

| Runtime | Version checked | Our platforms | Reaches Flutter by | Models here | Acceleration | Boundaries |
|---|---|---|---|---|---|---|
| **whisper.cpp** | v1.9.4 (2026-09-11) | all four | own FFI package, build hook + CMake on a pinned submodule (D9) | Whisper large-v3, large-v3-turbo | CPU (Arm dotprod/i8mm; x64 AVX2); Metal on Apple; Core ML encoder (`-DWHISPER_COREML=1`); Vulkan (`-DGGML_VULKAN=1`); OpenCL Adreno (`-DGGML_OPENCL=ON`); OpenVINO encoder (`-DWHISPER_OPENVINO=1`, OpenVINO 2026.3.0) and full backend (`-DGGML_OPENVINO=ON`); CUDA, HIP; VitisAI (`-DWHISPER_VITISAI=1`); Hexagon (`-DGGML_HEXAGON=ON`, experimental) | the library takes float PCM; its CLI reads 16-bit WAV. Backends load dynamically (D10). DTW word timestamps have presets for both large models |
| **sherpa-onnx** | 1.13.8 (2026-09-10); pub `sherpa_onnx` | all four (Windows ARM64: §2.5) | the official Dart package, or a trimmed vendored copy (D11) | Parakeet v3 int8, Qwen3-ASR 0.6B int8 (1.7B: own export, optional) | CPU via ONNX Runtime; providers `coreml`, `cuda`, `directml`, `nnapi` exist as strings but add no capability the binary lacks | takes float samples; Parakeet returns token timestamps, Qwen returns none; hotwords for Qwen |
| **transcribe.cpp** | at lock time | desktop | own C ABI over its C API, FFI | Parakeet v3 GGUF, Qwen3-ASR 0.6B/1.7B GGUF (its own conversions) | Metal, Vulkan, CUDA, HIP | Qwen: no timestamps, no streaming, ~87 min; Windows Vulkan build guide; ARM64 status §2.5 |
| **llama.cpp (mtmd)** | at lock time | desktop, Android | alternative to transcribe.cpp for Qwen only | `ggml-org/Qwen3-ASR-*-GGUF` | the same ggml backends as whisper.cpp, incl. OpenCL on Adreno | audio in fixed 30 s chunks; long-audio bug open; two ggml copies in one process must be one build (report §10.2) |
| **FluidAudio** | v0.17.1 (2026-09-23) | iOS 17+, macOS 14+ | Swift plugin, SwiftPM, Pigeon (D12) | Parakeet v3 Core ML (`FluidInference/parakeet-tdt-0.6b-v3-coreml`), Qwen3-ASR 0.6B Core ML (`FluidInference/qwen3-asr-0.6b-coreml`, f32 and int8; 1.7B not published) | Neural Engine, with CPU/GPU fallback decided by Core ML | Apache-2.0; auto-downloads from Hugging Face unless `offlineMode` — we load from our own `models/` (D17); diarization pipelines exist (L8) |
| **argmax-oss-swift / WhisperKit** | v1.1.0 (2026-08-06) | iOS 16+, macOS 13+ | same plugin, optional | Whisper Core ML packages | Neural Engine + GPU | optional; whisper.cpp's Core ML encoder covers Whisper on Apple without it |
| **ONNX Runtime + QNN EP** | §2.5 | Windows ARM64, Android (Snapdragon) | own plugin per OS | Qualcomm AI Hub Whisper-Large-V3-Turbo, per SoC | Hexagon NPU | §2.5 |
| **OpenVINO GenAI** | 2026.x | Windows x64 (Intel) | C++ plugin, later | Whisper large-v3 exported to IR | Intel GPU and NPU (WhisperPipeline) | L7; no verifying device here — shipped as unverified support (D20) |
| **Ryzen AI (VitisAI)** | at lock time | Windows x64 (AMD) | whisper.cpp flag | `amd/whisper-large-v3-onnx-npu` companion resources | encoder on the NPU | L7; no verifying device — unverified support (D20) |
| **LiteRT / Tensor SDK** | beta (2026-05-19) | Android (Tensor G5/G6) | would need a Kotlin/NDK plugin; none exists | `litert-community/parakeet-tdt-0.6b-v3` (Tensor G5 artifact) | Tensor TPU | not planned: the user declined the beta on 2026-09-24 (§2.4, D14) |
| **OS recognisers** | §2.6 | iOS, macOS, Android | Swift / Kotlin plugin, Pigeon | none — the OS's own | the OS's own | L6 |

### 2.4 Google Tensor (Pixel 8 / 9 / 10)

The test device is a Pixel 10. Facts, all checked 2026-09-24:

| | Tensor G3 (Pixel 8) | Tensor G4 (Pixel 9, 9a, 10a) | Tensor G5 (Pixel 10) |
|---|---|---|---|
| CPU | X3 + 4×A715 + 4×A510 | X4 + 3×A720 + 4×A520 | 1×Cortex-X4 3.78 GHz + 5×A725 3.05 GHz + 2×A520; TSMC 3 nm; Armv9.2 |
| GPU | Mali-G715 MP7 (Vulkan 1.3; **OpenCL not exposed to apps**) | Mali-G715 MP7 (Vulkan 1.3) | **PowerVR DXT-48-1536** (Vulkan 1.3, 1.4 from driver 1.634+; Android 17 reports 1.4.317 / driver 1.662.3024) |
| RAM | 8 / 12 GB | 12 / 16 / 8 GB | 12 GB; Pro and Fold 16 GB; ~3 GB reserved by Google for its own AI models |

- **CPU (the shippable route).** Armv9.2 cores have dot-product, fp16, i8mm and 128-bit SVE2 —
  what ggml's and ONNX Runtime's Arm kernels want — and **no SME2**, so Arm's KleidiAI SME2
  figures for Parakeet do not transfer. No published whisper.cpp or sherpa-onnx numbers exist for
  any Pixel; the nearest datapoint (Galaxy S10, sherpa-onnx int8) is Parakeet v3 at RTF 0.09 and
  Whisper small at 0.41. **Grade E** until this project measures it — which L1 and L2 do.
- **GPU (an experiment).** llama.cpp's Vulkan backend runs on the Mali-G715
  (community verified, grade B) and on the Pixel 10's PowerVR only fragilely: the vendor id was
  added in 2026-03 with shader-compile workarounds; all k-quant matrix-vector shaders produced
  wrong output on driver 1.662.3024 (2026-07); a shared-memory fallback was merged 2026-09-10;
  Imagination's own "initial PowerVR support" PR (2026-09-23) says "not optimally" with "multiple
  other shaders not working". ExecuTorch's Vulkan backend produced zeros and NaNs on the same GPU.
  No report exists of **whisper.cpp** Vulkan on either Pixel GPU: **grade E**. If tried: f16 or
  Q8_0 weights only, never k-quants; run ggml's backend-op self-test first; gate on driver
  ≥ 1.662.3024; keep the CPU fallback (D14).
- **NPU (not offered).** LiteRT lists Google Tensor as a supported NPU in **beta**: ahead-of-time
  compilation only through the `CompiledModel` API, Tensor **G5 and G6 only**, arm64-v8a, models
  delivered as Play AI Packs, access through a sign-up form, a Linux compile host with Bazel.
  Google publishes a Parakeet TDT 0.6B v3 artifact for it (`…_5s_f32_Google_Tensor_G5.tflite`,
  1.26 GB, five-second windows, no latency figures) — the only ASR model in its Tensor collection.
  Qwen3-ASR has LiteRT CPU exports only (i8 794 MB) and Whisper has LiteRT CPU exports with no KV
  cache (RTF above 1 on a desktop CPU). Tensor G3/G4 have no supported third-party NPU route at
  all (a community Gemma build proves the G4 path physically exists and is unsupported). NNAPI is
  deprecated since Android 15 and whether the Pixel driver reaches the TPU is unverified; AICore
  and the ML Kit GenAI APIs serve Gemini Nano only. **Grades: Parakeet × G5 = A for the artifact,
  U for speed and for a Flutter route; Whisper and Qwen × Tensor NPU = U.** Offering it would mean
  applying for the beta, shipping a 1.3 GB AI Pack for two chips, and a Kotlin plugin nobody has
  written. **The user decided on 2026-09-24 not to apply**, so the Tensor NPU is not offered and
  is not a milestone; an SDK that later needs no sign-up and has a route from Flutter would be a
  new decision for the user, not an implementer's call.
- **Memory.** Native allocations are not bounded by the Java heap; the low-memory killer decides by
  foreground state and pressure. A local job runs in a foreground service with a notification,
  prefers quantized artifacts (turbo q5_0 547 MiB; Parakeet int8 ~0.6 GB), refuses to load an
  artifact whose documented footprint exceeds available memory, and expects the 8 GB Pixel 8a/9a
  to fail large-v3 f16 outright.
- **The OS's own recogniser** on Pixel: ML Kit's GenAI Speech Recognition API (basic mode on API
  31+, "advanced" Gemini Nano mode on Pixel 10/11) requires audio fed **at real-time rate** —
  an hour of audio takes an hour — which rules it out as a batch engine. Android's
  `SpeechRecognizer` with a file descriptor is the route L6 evaluates (§2.6).

### 2.5 Qualcomm: Windows on Snapdragon is not Android on Snapdragon

Both have a Hexagon NPU, an Adreno GPU and an Oryon or Kryo CPU, and that is where the similarity
ends. Everything below was checked 2026-09-24.

| | **Windows on Snapdragon** (X Elite / X Plus / X2 Elite — the development machine is one) | **Android on Snapdragon** (8 Gen 3 / 8 Elite / 8 Elite Gen 5) |
|---|---|---|
| NPU developer route | ONNX Runtime **QNN plugin EP**: `Qualcomm.ML.OnnxRuntime.QNN` 2.6.0 (NuGet, 2026-09-10; QAIRT 2.50.40; the EP itself MIT; a separate `onnxruntime_providers_qnn.dll` registered by path against ORT ≥ 1.24.1). Or **Windows ML** (Windows App SDK 1.8.1+, GA 2025-09-23): the OS's own ORT, with the QNN EP downloaded and serviced through Windows Update — X Elite and X Plus only, **X2 Elite not listed**. Microsoft's own `Microsoft.ML.OnnxRuntime.QNN` stopped at 1.24.4 (2026-03-17). | ONNX Runtime QNN as **AARs**: `com.qualcomm.qti:onnxruntime-android-qnn` 2.6.0 (2026-09-09) + `com.qualcomm.qti:qnn-runtime` 2.50.0 (2026-09-02), or Microsoft's `onnxruntime-android-qnn` 1.29.0 (2026-08-12). sherpa-onnx also has a direct-QNN C++ runtime (v1.13.4, Android only) with Whisper and Parakeet **export code but no prebuilt models** for them. |
| Redistributable runtime | The plugin DLL plus the QAIRT DLLs in the NuGet/zip (~80 MB); Windows ML's C API in `Microsoft.Windows.AI.MachineLearning` 2.4.89 (self-contained mode, unpackaged apps allowed; "EP binaries must be included in your app package or installer"). | `.so` files inside the AARs; `qnn-runtime` is under the "Qualcomm AI Hub Model License" (its text could not be read — **redistribution is verified before L5 ships anything**). Known app-side requirements: `<uses-native-library>` for `libcdsprpc.so` and `libOpenCL.so`, `ADSP_LIBRARY_PATH` set to the app's native-lib dir, `useLegacyPackaging = true`, and the runtime pinned to the model's compile version. |
| OS-level ML API | Windows ML, EPs serviced by Windows Update (QNN EP 2.2480.49.0 → 2.2609.3.0 during 2026); DirectML in-box but "legacy". | NNAPI deprecated since Android 15; LiteRT Next exposes the Qualcomm NPU through `CompiledModel` (SM8650/8750/8850), Google-managed and separate from QNN. |
| Model assets | Qualcomm AI Hub `qualcomm/Whisper-Large-V3-Turbo` rows for **X Elite** and **X2 Elite** (Windows 11). Nothing for full large-v3, Parakeet or Qwen. | The same model card's rows for **8 Gen 3**, **8 Elite**, **8 Elite Gen 5**. Nothing for the others. |
| Model format | EPContext ONNX (`*_ctx.onnx` + `.bin`), compiled per **HTP architecture**: X Elite **v73**, X2 Elite **v81** (secondary source) — not interchangeable. A flexible multi-SoC context needs QNN ≥ 2.48 and still needs per-arch Stub/Skel pairs. | Same, per **v75 / v79 / v81**. An X Elite binary does not run on an 8 Elite. |
| Pipeline churn | AI Hub deprecated `precompiled_qnn_onnx` (2026-05-28) and removed the `qnn_context_binary` compile target on 2026-09-14 in favour of compile + link; QAIRT versions differ between AI Hub (2.49), the NuGet (2.50.40), Windows ML's catalog (2.48.40) and the Android runtime (2.50.0). A mismatch fails at context load. | Same churn; the same pinning rule. |
| GPU | **OpenCL** (ggml backend), verified by upstream on Adreno X1-85 and X2-90, **clang only** ("Visual Studio's cl compiler is not supported"); whisper.cpp ships `whisper-bin-win-opencl-adreno-arm64.zip` since b5130 (2026-09-11). Known driver crash in `clGetPlatformIDs` on X2 Elite / Windows 26H1 (2026-09-04, open). **Vulkan is not a route**: on Adreno X1 it produced gibberish and ran slower than the CPU. DirectML: sustained engineering only. | **OpenCL** (ggml backend), verified by upstream for LLMs on Adreno 750/830/840; whisper.cpp itself has an open assertion failure on Adreno 830 (2026-03) and a segfault on Adreno 643 (2026-07). **Vulkan is not a route**: whisper.cpp crashes in the Adreno Vulkan driver on 830. |
| CPU | ORT `onnxruntime-win-arm64-1.30.0`; sherpa-onnx builds for win-arm64 (its Flutter package gained `windows/arm64/` DLLs in PR #3957, merged 2026-09-20, **after** the 1.13.8 pub release); whisper.cpp `whisper-bin-win-cpu-arm64.zip` (clang; MSVC lacks the FP16 intrinsics). Oryon Gen 1/2: NEON, dotprod, i8mm, BF16, **no SVE/SVE2**; X2 Elite adds SVE2 and SME. | sherpa-onnx AAR / `sherpa_onnx_android_arm64`; whisper.cpp through the NDK. |
| Memory | 16–64 GB. AI Hub reports the precompiled Turbo encoder at ~1.7 GB peak on X Elite. | up to 24 GB; the same encoder at 63–73 MB peak on phones (AI Hub estimate). |
| Signing | The ggml **Hexagon** backend needs test-signing → developer only (D13). The QNN EP path uses Microsoft-signed drivers and needs nothing. | No test-signing for QNN; the HTP libraries come signed in the runtime AAR. |
| Verifiable in this project | **Yes** — the Snapdragon X development machine: CPU, OpenCL GPU, and the QNN NPU with an AI Hub asset. | **No** — no Snapdragon phone. Shipped as unverified support (D20), gated by the smoke test on each device; a diagnostics report from somebody who has one goes into the matrix as a community result. |

AI Hub's own profile numbers for Whisper-Large-V3-Turbo on the NPU (encoder for a 30 s frame /
one decoder step): X Elite 561 / 8.5 ms; X2 Elite 251 / 4.9 ms; 8 Gen 3 402 / 7.8 ms; 8 Elite
307 / 6.8 ms; 8 Elite Gen 5 302 / 6.5 ms. These are per-stage figures, not transcription times
(report §9.3), and a working third-party recipe exists for the 8 Elite Gen 5 (Galaxy S26,
`onnxruntime-android-qnn` 1.29.0 + `qnn-runtime` 2.45.0, Whisper-Small at RTF 0.093).

What this settles for the plan: on the development machine the NPU route is **A** for Turbo and
can be verified end to end (L5a); on Android it is **A** on paper and **unverified** here, and
ships as such (L5b, D20);
full large-v3, Parakeet and Qwen have **no** Qualcomm NPU package on either platform (**U**), and
the sherpa-onnx QNN export code is the only starting point for Parakeet (**E**). The GPU route on
every Qualcomm chip is OpenCL, and for whisper it is **E** until the smoke test passes on that
device. The NexaAI Parakeet NPU packages are CC-BY-NC and are not usable.

### 2.6 The operating systems' own recognisers

| Platform | API | File input | On-device | Timestamps | Duration limit | Min OS | Flutter plugin today |
|---|---|---|---|---|---|---|---|
| iOS, macOS | `SpeechAnalyzer` + `SpeechTranscriber` | yes — `analyzeSequence(from: AVAudioFile)` | **always**; never sends audio to Apple; the model is a system asset (`AssetInventory`), downloaded once, shared between apps, not counted against the app | per result, `audioTimeRange`, sample-precise; confidence; **no speakers** | none documented; built for long-form | iOS 26, macOS 26 (hardware-gated `isAvailable`) | `apple_speech` 0.1.0 (published 2026-09-23, unproven), `speech_kit` (macOS only) |
| iOS, macOS | `SFSpeechRecognizer` + `SFSpeechURLRecognitionRequest` | yes | only with `requiresOnDeviceRecognition = true`, honoured only where `supportsOnDeviceRecognition` is true for that locale on that device; otherwise **audio goes to Apple's servers** | segment `timestamp` / `duration` / confidence; no speakers | server path: about one minute per request plus daily quotas; on-device: none | iOS 13, macOS 10.15 for the on-device flag | none for files; `speech_to_text` is microphone-only |
| Android | `SpeechRecognizer` + `RecognizerIntent.EXTRA_AUDIO_SOURCE` | yes in the API (a `ParcelFileDescriptor` of raw 16 kHz mono 16-bit PCM) — "if the recognizer does not support this feature, it will open the mic" | guaranteed only by `createOnDeviceSpeechRecognizer` (API 31, when `isOnDeviceRecognitionAvailable`, an OEM overlay value); `EXTRA_PREFER_OFFLINE` is advisory | word offsets via `RECOGNITION_PARTS` (API 34) **if the service returns them** — unverified for Google's | the session ends when the descriptor is closed; segmented sessions (API 33) | API 33 for file input; API 31 for on-device | none exposes file input |
| Windows | `Windows.Media.SpeechRecognition` | **no** — microphone only; dictation is a web service | no | — | 10 s dictation | — | — |
| Windows | `Microsoft.Windows.AI.Speech` | yes (`BatchRecognition.RecognizeFromFile`) | yes | streaming offsets | none documented | Windows 11 24H2; Windows App SDK **2.2.2-experimental9 only**; MSIX with `systemAIModels` | none |

Facts that shape L6:

- **Apple.** `NSSpeechRecognitionUsageDescription` is required for the `SFSpeechRecognizer` path
  (the app crashes on the authorization call without it) and Siri or Dictation must be enabled on
  the device; the `SpeechAnalyzer` file path needs no authorization. One report (2026-09-16) says
  `SFSpeechURLRecognitionRequest` silently never starts on macOS 26.6.2, so the order is
  `SpeechAnalyzer` on 26 and later, `SFSpeechRecognizer` below. Apple publishes no list of
  on-device locales; the app asks `supportsOnDeviceRecognition` and `SpeechTranscriber.supportedLocales`
  at runtime and shows the answer. Whether a sandboxed macOS app also needs the audio-input
  entitlement for a URL request is unverified; the first sandboxed build answers it.
- **Android.** Google's own on-device recogniser backs it on Pixel; whether it honours a
  file-backed descriptor at full speed is unverified, and its ML Kit sibling explicitly requires
  data **at real-time rate**, so the adapter feeds PCM through a pipe paced at one second per
  second and detects the microphone fallback (a session that produces nothing as the pipe
  drains). `RECORD_AUDIO` is still checked by the recognition service even with a file source
  (from the AOSP source), so **this fallback adds the microphone permission the app has never
  asked for**. The user took the plan's default on 2026-09-24: L6 declares it in the manifest,
  requests it at runtime only when the fallback is switched on, and says why in the privacy
  policy. Language packs download through `checkRecognitionSupport` and `triggerModelDownload`
  (API 33/34) with a system prompt. Other OEMs are whatever their overlay says; one Android 15
  OEM build reports no on-device service while Google voice typing works, and Chinese Xiaomi ROMs
  have no Google services at all — their routes ship unverified (D20).
- **Windows.** Nothing shippable: the stable API takes no file and sends audio to a web service;
  the on-device one is an experimental SDK channel that requires an MSIX package with a capability
  this app's installer does not have. Not offered (D15).
- **Every path is a fallback, not a model**: no speaker labels anywhere, timestamps of varying
  quality, and a language list the OS decides. The job records `engine: system` and the transcript
  says so.

### 2.7 Support matrix, per target we ship

Grades per the report: **A** vendor or model author documents this model on this route; **B** a
third-party implementation exists; **E** a generic backend exists but this model × device is
unverified; **U** nothing found. "Tested here" means a device this project owns can run §7's
acceptance list on it. A target with "no" there still ships: its routes are **unverified
support** (D20) — built, covered by CI, gated by the smoke test on each device, marked as untested,
and never picked automatically unless D20's evidence rule allows it. The implementer copies this
table into `doc/en-us/local-asr-support-matrix.md` and keeps it current; the code's
`EvidenceLevel` carries the grades, and its tested-here table carries the last column.

| Target | Whisper large-v3 / turbo | Parakeet TDT v3 | Qwen3-ASR 0.6B (1.7B) | Tested here |
|---|---|---|---|---|
| **Windows x64** — Intel / AMD / NVIDIA GPU; Intel NPU; AMD NPU | CPU **B** (whisper.cpp); GPU Vulkan **B**; Intel NPU **A** (OpenVINO GenAI, L7); AMD NPU **A** for the encoder (Ryzen AI 300 on Windows, L7); CUDA **B** (not planned — a 1 GB dependency) | CPU **B** (sherpa-onnx); GPU **B** (transcribe.cpp Vulkan); NPU **U** | CPU **B** (sherpa-onnx int8; 1.7B **E**, own export); GPU **B** (transcribe.cpp Vulkan); NPU **U** | **no** — no x64 machine: shipped unverified (D20); the x64 build's CPU route also runs under emulation on the ARM64 machine, which checks the code path but not the speed |
| **Windows ARM64** — Snapdragon X Elite (this machine); X2 Elite | CPU **B**; GPU OpenCL **E** (upstream binary exists; whisper-specific bugs open on Adreno); NPU **A** for **Turbo only** (AI Hub asset, ORT QNN EP), large-v3 **U** | CPU **B** (sherpa-onnx, ARM64 DLLs pending a pub release); GPU **U** (transcribe.cpp has no OpenCL and no ARM64 evidence); NPU **E** (sherpa-onnx QNN export code; a PoC encoder on X Elite, 2026-09-22) | CPU **B**; GPU **E** (llama.cpp's Qwen port over OpenCL); NPU **U** | **yes** on the X Elite: CPU, OpenCL, QNN; the X2 Elite ships unverified (D20) |
| **Android** — Snapdragon 8 Gen 3 / 8 Elite / 8 Elite Gen 5 | CPU **B**; GPU OpenCL **E** (assertion open on 830); NPU **A** for **Turbo only** (per-SoC asset) | CPU **B**; GPU **E**; NPU **E** | CPU **B**; GPU **E**; NPU **U** | **no** — shipped unverified (D20) |
| **Android** — Google Tensor G3 / G4 / **G5 (Pixel 10)** | CPU **E** (no published numbers); GPU Vulkan **E** (PowerVR driver correctness bugs; Mali works for LLMs); NPU **U** | CPU **E**; GPU **E**; NPU **A/U** (a Google-published Tensor G5 artifact, beta SDK, no route from Flutter; not planned — D14) | CPU **E**; GPU **E**; NPU **U** | **yes** on the G5 (Pixel 10): CPU, Vulkan experiment; the G3 and G4 ship unverified (D20) |
| **Android** — MediaTek Dimensity, Samsung Exynos | CPU **E**; GPU Vulkan **E**; NPU **U** | CPU **E**; GPU **E**; NPU **U** | CPU **E**; GPU **E**; NPU **U** | **no** — shipped unverified (D20) |
| **macOS** — Apple Silicon (Intel Mac: CPU only) | CPU/Metal **B** (whisper.cpp, Metal on by default); Core ML encoder **B**; WhisperKit **B** (optional) | CPU **B** (sherpa-onnx); Neural Engine **B** (FluidAudio, macOS 14+) | CPU **B**; Neural Engine **B/E** (FluidAudio, 0.6B only; the converter's own WER 4.4 % vs 2.11 % is a signal to gate on) | **yes** on Apple Silicon: the 2024 Mac mini; Intel Macs ship unverified (D20) |
| **iOS** — A-series / M-series | CPU/Metal **B**; Core ML encoder **B**; WhisperKit **B** | CPU **B**; Neural Engine **B** (iOS 17+) | CPU **B**; Neural Engine **B/E** | an iPhone, if one is available; otherwise the Simulator on the Mac for the code path, and the device routes ship unverified (D20) |
| **OS recogniser** (L6) | iOS/macOS 26+ `SpeechAnalyzer` on-device **A**; below that `SFSpeechRecognizer` on-device **A** where the locale supports it; Android on-device **A** in the API, file input **E** on Google's service; Windows **none** | | | Pixel 10 and the Mac |

## 3. Decisions

Each of these was made on 2026-09-24 with the reasons given. They are repeated in the decisions
log at the end so that the log survives this file; an implementer who wants to reverse one writes
a new dated entry saying why, and does not silently do otherwise.

| # | Decision | Why |
|---|---|---|
| D1 | **A local model is a new synced record kind, `localModel`, not a new provider dialect.** Built-in definitions seed with derived ids (`local:whisper-large-v3-turbo`); a model the user adds from a file gets a uuid. The record carries identity, languages, limits and capabilities; nothing device-specific. | A 0.2.x build parses an unknown *dialect* as `openaiCompatible` and would show a phantom source with an empty URL; it parses an unknown record *kind* as `unknown` and carries it through untouched — that contract exists precisely for this. The list follows the user to their other device (a model added on the desktop shows as "not downloaded" on the phone) while the files do not. |
| D2 | **Everything device-specific lives outside the synced document.** Which artifacts are installed, their hashes, the chosen compute device, smoke-test results and the fallback policy are in device-local files (§4.4). | A path, a GPU and a smoke-test result are properties of the device, exactly like `ffmpegPath` and the trusted-host list. Syncing them would make one device's GPU choice appear as a promise on another. |
| D3 | **The model files are never a data module.** `models/` is not in `lib/app/data_modules.dart`, so sync, backup and ZIP export cannot touch it. | Structural exclusion, the same rule that keeps recordings and API keys out. A 1.5 GB model in a backup bundle would be absurd, and it is re-downloadable. |
| D4 | **One engine protocol, `LocalAsrEngine`, with adapters underneath; the job runner speaks to a `TranscriptionBackend` that is either the existing HTTP client or a local engine.** The runner's stage machine, per-window persistence, resume, cancel and the overlap merge are reused unchanged. | The runner is the most-tested code in the app and the merge already handles two transcriptions of the same seconds. A local engine that returns segments per window slots in where an HTTP reply did. |
| D5 | **Local engines receive 16 kHz mono PCM cut from the normalized MP3 by FFmpeg; they never receive the original file.** The normalized copy remains the viewer's listening copy. | Three runtimes, three feature extractors, one PCM contract (§8.1 of the report). whisper.cpp's library takes float samples, sherpa-onnx takes float samples, FluidAudio takes an `AVAudioPCMBuffer`; giving them all the same PCM removes a class of "works on one engine" bugs. It also means a local job needs the media toolkit — on Windows, FFmpeg — which the app already offers to download. |
| D6 | **Model identity is never substituted silently.** Turbo is not large-v3, the 0.6B Qwen is not the 1.7B, and the OS recogniser is not a model. The record the user chose is the record the job records as requested; an allowed fallback is a separate, visible event with its own reason, and the fallback policy is the user's setting (`none` / `same model on CPU` / `system recogniser`). | The report's rule 9. A transcript that quietly came from a weaker model is worse than a failed job, because nothing later reveals it. |
| D7 | **Capabilities are the intersection of four sources**: the model's own (`modelCapabilities`), what the converted package kept (`artifactCapabilities`), what the adapter on this platform exposes (`runtimeCapabilities`), and what this device's smoke test showed (`smokeTest`). The UI shows the intersection; the three-state `Capability` enum already in the app is reused, and `unknown` stays a real answer. | The report §2. Qwen3-ASR documents streaming and a forced aligner; the ONNX export, the GGUF port and the Core ML conversion keep neither, and this app needs neither — but the record must not claim them. |
| D8 | **Evidence grades are in the code, not only in the docs.** An `EvidenceLevel` enum (`official`, `community`, `experimental`, `none`) on every engine×model×device route, mirroring the report's A/B/E/U — `none` rather than `unverified`, which is the product's word for a route this project has not tested (D20) — and a `PlacementKind` (`cpu`, `gpu`, `npu`, `mixed`, `unknown`) recorded on every finished window from what the runtime actually reported. | "NPU" in a menu is a promise. `unknown` is what to say when the runtime gives no placement evidence; a fabricated percentage is a lie the diagnostics page would repeat forever. |
| D9 | **whisper.cpp is compiled from a pinned tag inside a build hook, in a package of our own (`packages/local_asr_whisper`).** Not a pub package: the two that exist ship x86_64-only Windows binaries (`whisper_ggml` 2.6.0, AVX2 prebuilt) or no desktop at all (`whisper_cpp_flutter_plus` 0.4.1, Android and iOS only) — checked 2026-09-24 — and neither would build on the ARM64 development machine. Build hooks are the recommended FFI route since Flutter 3.38, need no per-OS build files, and the hook may run CMake with the backend flags per target. On Windows, x64 and ARM64 alike, the hook compiles with **clang/LLVM**: it is what upstream builds its own Windows ARM64 binaries with (`whisper-bin-win-cpu-arm64.zip` and `whisper-bin-win-opencl-adreno-arm64.zip` since b5130, 2026-09-11), MSVC's `cl.exe` lacks the FP16 vector intrinsics, and the OpenCL backend does not support it at all. | The FFmpeg precedent: a plugin that cannot build on this machine is not a plugin this project can use. Pinning a tag (v1.9.4, released 2026-09-11, at the time of writing) is what makes a bug reproducible. |
| D10 | **GPU backends are separate dynamic libraries loaded at runtime (`GGML_BACKEND_DL`), never linked into the base library.** Vulkan on Windows x64, OpenCL on Windows ARM64 and Android, Metal on Apple; the CPU backend is always present. A backend whose vendor SDK is absent at build time is simply not produced, and the app reports "not built" rather than failing to start. | A missing `vulkan-1.dll` or a driver without OpenCL must not take the whole app down. The ggml backend registry is designed for exactly this, and it is how one binary can say honestly which routes it has. |
| D11 | **sherpa-onnx is the Parakeet and Qwen baseline on all four platforms**, from the official `sherpa_onnx` pub package at the first release whose Windows sub-package carries the ARM64 DLLs (upstream merged them on 2026-09-20, after the 1.13.8 release of 2026-09-10), otherwise vendored and trimmed exactly as FFmpeg was, with the ARM64 archive fetched by hash in a build hook. Pinned at or above 1.13.8 for the Qwen fixes. | It already publishes both models with Android, iOS, Windows and macOS support and has a Dart API; establishing the CPU baseline first is what §12 of the report and this app's own history (M1: verify on real hardware before optimising) both say. |
| D12 | **The Apple native adapter uses FluidAudio for Parakeet and Qwen on the Neural Engine, through a typed Pigeon channel; WhisperKit is optional and later.** This raises the deployment targets to **iOS 17 and macOS 14**, recorded in `platform-notes.md`. | FluidAudio's `Package.swift` declares `.macOS(.v14), .iOS(.v17)` (checked 2026-09-24, v0.17.1 released 2026-09-23); a Swift package cannot be weak-linked below its platform floor, so the choice is raise the targets or not ship the adapter. whisper.cpp's own Core ML encoder needs no SDK and stays available on the current targets, which is why Whisper comes first (L1) and the Swift adapter later (L4). **The user approved the bump on 2026-09-24.** It is still the one decision here that removes devices, so it lands in the first milestone that needs it — L4, or L1 if the pinned whisper.cpp's Metal backend or Core ML encoder turns out to need a newer floor than iOS 14 / macOS 10.15 — and that release's notes say which devices it drops. |
| D13 | **Qualcomm is two targets with two runtimes, never one.** Windows on Snapdragon (X Elite / X2 Elite, this project's own machine) and Android on Snapdragon (8 Gen 3 / 8 Elite / 8 Elite Gen 5) get separate adapters, separate model assets and separate verification records. The GPU route on both is the ggml OpenCL backend, which upstream verifies on exactly these chips (Adreno 750/830/840, X1-85, X2-90) on both operating systems (checked 2026-09-24); **Vulkan is not a Qualcomm route** — it produced gibberish and ran slower than the CPU on Adreno X1, and whisper.cpp crashes inside the Adreno Vulkan driver on the 830. The NPU route is ONNX Runtime's QNN execution provider with Qualcomm AI Hub's precompiled **Whisper-Large-V3-Turbo** assets, per SoC — and **the ggml Hexagon backend is not a shipping route on Windows**, because upstream's own guide requires `bcdedit /set TESTSIGNING ON` for its NPU libraries. | A Windows ARM64 build is not an Android build, an X Elite context binary is not an 8 Elite one, and a route that needs test-signing is a developer tool, not a feature. |
| D14 | **Google Tensor is CPU first, GPU experimental, NPU not offered.** The Pixel 10 verification is of the CPU path with Arm dot-product and i8mm kernels and, separately, of whether a Vulkan build of whisper.cpp runs correctly at all on its PowerVR GPU. The Tensor NPU is reachable only through Google's Tensor SDK beta — sign-up gated, ahead-of-time compiled, delivered as a Play AI Pack, G5 and G6 only — and only Parakeet has a published artifact for it; **the user decided on 2026-09-24 not to apply for it**, so it is not offered and not a milestone (§2.4). | The user's phone is the one Android device this project can verify on, and a plan that only verified Snapdragon would verify nothing. |
| D15 | **The OS recogniser is a fallback and an explicit choice, off by default.** On Apple platforms: `SpeechAnalyzer` where the OS has it, `SFSpeechRecognizer` with on-device recognition required below that; on Android: `SpeechRecognizer` on-device with file input where the OS has it. Server-side recognition is never used unless the user turns on a separately worded switch. Windows has no file-transcription OS API and offers nothing. On Android the recogniser checks `RECORD_AUDIO` even for a file, so the app declares it and asks for it only when the fallback is switched on — the default the user took on 2026-09-24. | The user asked for it as optional. Its value is a transcript on a phone with no model downloaded; its cost is a different privacy line, which the policy page states in the same words the switch uses. |
| D16 | **Heavy work never runs on the UI isolate, and one native handle has one owner.** FFI adapters run in a dedicated long-lived engine isolate that owns the model handle; platform-channel adapters run on a native worker thread. Cancellation is cooperative — a flag the runtime polls at a segment or token boundary — and resources are released only after the native call has returned. | Report §6.3. `await` on an FFI call is not concurrency; a model handle shared between isolates is a crash. |
| D17 | **Downloads are manifest-driven, resumable, hash-verified and atomic.** A manifest per artifact (§4.4) lists every file with size and SHA-256; the downloader uses HTTP range requests to resume, verifies each file, unpacks into a temporary directory and renames into place; a model in use holds a lease so an update cannot replace files under a running job. Downloads come only from the URL in the manifest, only when the user asks. | Report §4.2. Also the privacy promise: the app gains one new kind of endpoint — a model host — and contacts it only on a tap. |
| D18 | **Speaker labels are not offered by any local model in this plan's first release.** All three ASR families are `diarization: unsupported`; a later, optional milestone (L8) may add a separate diarization pipeline that produces window-local labels the existing unifier can join. | Report §8.3: timestamps are not speakers. The unifier's bias against a doubtful join is exactly the right shape for a local pipeline too, but that is a second model, a second download and a second memory budget, and it is not the point of this plan. |
| D19 | **The first release of this plan is 0.3.0** (`0.3.0+4` — the version the user confirmed on 2026-09-24), after L0–L2: local transcription on the CPU on all four platforms, with the honest capability model. The later milestones ship in later releases — 0.4.0 onward by default, one milestone per release or several together — each version confirmed by the user when it is ready, as `AGENTS.md` requires. No release waits for a verification this project cannot perform (D20). | A milestone that ships is a milestone that gets used, and the first real recording through a local model will find things no test does — that is what M8 and M9 taught. |
| D20 | **A route this project cannot test on real hardware ships as unverified support; it is not held back.** *Verified* means this project ran §7's acceptance list on hardware of that class and recorded it in the support matrix, and that stays the gate for the classes its own devices cover: Windows ARM64 on the Snapdragon X machine, Tensor G5 on the Pixel 10, Apple Silicon Macs on the Mac mini, and an iPhone if one becomes available. Every other route is **unverified**: built and linked in CI, covered by the host and fake-engine tests, exercised wherever anything here can run it (the x64 build under emulation on the ARM64 machine, the iOS Simulator), and shipped with five safeguards. (1) The product says it has not been tested on this kind of device. (2) Auto picks an accelerator route only when this project tested it on this kind of device, or when its evidence is **A** or **B**, it passed its smoke test here and ran faster than the CPU in it; an untested **E** or **U** route runs only when the user chooses it, and the CPU route is Auto's floor everywhere, tested or not. (3) Every route, verified or not, runs its smoke test on this device before its first job and again when the adapter, model, OS or driver changes; a failure disables it here, with the reason. (4) An in-flight marker is written before each native call and cleared after it; a marker found at the next start means the process died inside that route, which is recorded as `crashed` here and never picked automatically again, and the interrupted job resumes under the fallback policy, whose default is the same model on the CPU. (5) The diagnostics page copies a report — device, OS, driver, route, smoke-test result, speed; no file names, no text — that the user may send by hand; a report from real hardware goes into the matrix as a community result, which can raise a route's evidence grade but never makes it tested here. | The user decided this on 2026-09-24: most devices this app targets — Snapdragon and MediaTek phones, x64 PCs with Intel, AMD or NVIDIA graphics, Intel and AMD NPUs, iPhones — cannot be tested here, so unverified support is the only support they can have. The safeguards make an untested route cost its user a failed check or one lost window, never a crash loop or a silently wrong transcript. |

## 4. Architecture

### 4.1 Where it lives

A new feature, flat by domain like the others, plus native packages of our own:

```
lib/features/local/
  models/     local_model_config.dart      the synced record (D1): identity, languages, limits, capabilities
              artifact_manifest.dart       what one downloadable package is (§4.4)
              engine_capability.dart       EvidenceLevel, PlacementKind, ComputeDevice, FallbackPolicy
              local_engine_state.dart      the device-local state document (§4.4)
  services/   local_asr_engine.dart        the protocol (§4.2)
              engine_registry.dart         which adapters this build has, and their probe results
              engine_router.dart           choose a route for (model, device, options) — pure, tested
              artifact_manager.dart        download, verify, install, remove, lease
              artifact_downloader.dart     resumable HTTP with hashes; the FFmpeg downloader's shape
              local_transcription_backend.dart   TranscriptionBackend over an engine, for the runner
              local_model_templates.dart   the built-in localModel records and their manifests
              pcm_window_cutter.dart       FFmpeg: window of the normalized file → 16 kHz mono PCM
              route_smoke_test.dart        the check every route passes on this device first (D20)
  engines/    whisper_cpp_engine.dart      FFI adapter (isolate owner)
              sherpa_onnx_engine.dart      Dart-API adapter (isolate owner)
              apple_speech_engine.dart     Pigeon client for FluidAudio / WhisperKit / SpeechAnalyzer
              android_speech_engine.dart   Pigeon client for SpeechRecognizer
              qnn_engine.dart              ONNX Runtime QNN adapter (L5)
  views/      local_models_page.dart       Library › This device: the list, downloads, verification
              engine_diagnostics_page.dart what ran where, per device, per model
  widgets/    model_download_tile.dart, placement_chip.dart, …

packages/local_asr_whisper/      FFI package: hook/build.dart drives CMake on the pinned whisper.cpp
packages/whisper.cpp/            git submodule, pinned to a release tag (v1.9.4 at writing)
packages/local_asr_apple/        Swift plugin (SwiftPM): FluidAudio, optional WhisperKit, SpeechAnalyzer
```

`platform_capabilities.dart` stays the only file that branches on the platform; it gains
`localEngineBackends` (which adapters this platform can have at all) and `hasSystemSpeechRecognizer`.
`adaptive_layout.dart` gains nothing unless a new page needs a pane rule, in which case the rule
goes there with its provenance, per `AGENTS.md`.

The engine registry is a Riverpod provider like the media toolkit; adapters are registered by the
build (a backend not compiled in is absent, not disabled), and each adapter's `probe()` result is
cached per session and re-run when a model is installed or removed.

Submodule rule: `packages/whisper.cpp` is pinned by **tag**, its URL is the public upstream
(`https://github.com/ggml-org/whisper.cpp.git` — an absolute URL is correct here, unlike
`myapps_data`, because upstream lives in neither of our remotes), and `.gitmodules` still names no
private host.

### 4.2 The protocol

The report's §6.2 draft, reduced to what a file-transcribing app needs. No streaming: the app has
no microphone, and a window is a file. Types are illustrative; the implementer fixes the details
and documents them in `functions/`.

```dart
abstract interface class LocalAsrEngine {
  String get adapterId;                                     // 'whisper_cpp', 'sherpa_onnx', 'apple_fluid', …
  Future<List<EngineRoute>> probe();                        // every (model, device) this adapter could run here, with evidence
  Future<PreparedSession> prepare(PrepareRequest request);  // load a model on a device; reports effective placement
  Stream<AsrEvent> transcribe(TranscribeRequest request);   // one PCM window → progress, segments, completed | error
  Future<void> cancel(String jobId);                        // cooperative; completes when the native call has returned
  Future<void> release(String sessionId);
}
```

- `EngineRoute` carries `modelId`, `artifactId`, `device` (`cpu` / `gpu` / `npu`), `evidence`
  (`EvidenceLevel`), `testedHere` (this project verified the route on hardware of this device's
  class — the table in `engine-routing.md`, copied from the support matrix; D20), this device's
  smoke-test result, `available` with `unavailableReason`, the capabilities the route keeps
  (timestamp kinds, languages, `maxWindowSeconds`), and a memory estimate with its source
  (`measured` / `documented` / `unknown`).
- `PreparedSession` carries the session id, the artifact revision, the requested device, the
  **effective placement** (`PlacementKind`), preparation time and whether a compile cache was used.
- `AsrEvent` is one envelope — `jobId`, `sequence`, `type`, payload — with types `preparing`,
  `started`, `progress`, `segment`, `completed`, `cancelled`, `error`, `fallback`.
- Errors use one code set (report §11.2): `MODEL_MISSING`, `MODEL_CORRUPT`, `MODEL_FORMAT_MISMATCH`,
  `UNSUPPORTED_LANGUAGE`, `UNSUPPORTED_FEATURE`, `BACKEND_NOT_BUILT`, `DRIVER_MISSING`,
  `DEVICE_UNAVAILABLE`, `MODEL_COMPILE_FAILED`, `OUT_OF_MEMORY`, `INPUT_TOO_LONG`, `DEVICE_LOST`,
  `ROUTE_CRASHED` (the process died inside the route, found by the in-flight marker at the next
  start — D20), `CANCELLED`. Each carries a user-readable message, whether it is retryable, and
  the fallback routes the policy allows — the runner maps them onto `JobFailureKind` the way it
  maps HTTP failures today, adding kinds rather than reusing `rejected` for a missing driver.

### 4.3 The job, stage by stage

The stage machine is unchanged; two stages change what they do when the job's model is local.

```
queued → probing → planning → normalizing → [ cutting → transcribing → parsing ]* → merging → rendering → done
```

- **planning** — a local model has no byte budget, so the planner runs in a **time-only** mode:
  the window is bounded by the record's `maxDurationSeconds` (the engine's own limit — Whisper has
  none of its own; Qwen's GGUF port takes about 87 minutes and its aligner five; Parakeet is bound
  by attention memory), by the app's ceiling, and by a **memory budget** the route reports; the
  reason codes gain `windowCappedByEngine` and `windowCappedByMemory`. The "upload unchanged"
  fast path does not apply: a small recording is still decoded to PCM, as one window. The plan
  fingerprint gains the artifact revision and the requested device, so a model update or a device
  change discards cached windows exactly as a changed prompt does today.
- **normalizing** — unchanged: one decode to mono 16 kHz MP3, the listening copy.
- **cutting** — for a local model the window is written as **16 kHz mono 16-bit PCM WAV**
  (`-c:a pcm_s16le`) instead of a stream copy; the `MediaToolkit` interface gains that output
  option on both backends, and the integration test that holds the two backends to the same
  behaviour holds this too. The window file is deleted with the others at the end.
- **transcribing** — replaces **uploading**. The `TranscriptionBackend` for a local model prepares
  the session once per job (not per window), feeds each window, and turns segments into
  `ChunkResult`s with `hasRealTimestamps: true` when the route keeps timestamps. Progress events
  drive the same progress the upload stage shows.
- **merging** — unchanged: local engines return timestamps, so the timestamp cut point applies,
  and the token chain handles the rest. The overlap defaults stay (5 s; the 20 s diarized overlap
  does not apply since no local model labels speakers).
- **rendering** — unchanged, plus three new fields on the job record: the requested route, the
  effective placement per window, and the artifact revision. They are ordinary fields on a
  device-local record; the projection carries the job as a raw map, so a 0.2.x device on the other
  end keeps them.

A job whose model is not installed on this device does not start: it says which model, offers the
download, and — when the user has turned the fallback on — offers the system recogniser instead,
as a visibly different job.

### 4.4 Data on disk

Additions to `data-formats.md`, all under `getAppDir()` unless stated:

| Entry | Contents | Synced | Backup / ZIP |
|---|---|---|---|
| `transcribe_settings.json` › records of kind `localModel` | id, `templateId`, `displayName`, `family` (`whisper` / `parakeet` / `qwen` / `custom`), `languages`, `maxDurationSeconds`, `diarization` / `wordTimestamps` / `segmentTimestamps` (three-state), `artifacts` (the artifact ids this record may use, by adapter), `overriddenFields`, `templateVersion`, `extraJson` | yes — already a data module | yes |
| `models/<artifactId>/` | the installed files of one artifact, plus `manifest.json`: `modelId`, `artifactId`, `adapterId`, `format` (`ggml` / `onnx` / `coreml` / `qnn`), `quantization`, `revision`, `files[]` with `path`, `bytes`, `sha256`, `sourceUrl`, `licenseId`, `licenseText`, `attribution`, `installedAt`, `minimumRamBytes` with its `estimateSource` | **no** | **no** |
| `models/.downloads/` | partial downloads, resumable | no | no |
| `local_engine_state.json` | per device: installed artifacts and their smoke-test results (keyed by `adapterVersion + modelHash + osVersion + driverVersion + deviceId + precision` → `notRun` / `passed` / `failed` / `crashed`, with the output and the measured speed), the in-flight marker (route and UTC time, written before a native call and cleared after it — D20), the chosen device per model, `fallbackPolicy` (default: the same model on the CPU), `allowServerSpeechRecognition` | no | no |
| `storage_config.json` › `modelsPath` | an optional override for where `models/` lives, like `ffmpegPath` | no | no |
| `jobs/<id>/chunks/chunk_0000.wav` | a local job's PCM window, deleted like the MP3 windows | no | no |
| `jobs/<id>/job.json` › `route`, `chunks[].placement`, `artifactRevision` | what was asked for and what ran | via the projection, as a raw map | likewise |

Rules the implementer keeps: pretty-printed JSON, UTC timestamps, `extraJson` on every new model,
every write through `TranscribeStorage`, and `models/` marked excluded from iCloud backup on Apple
platforms (it is a cache of re-downloadable files, and a 3 GB model in a phone backup is a
support ticket).

### 4.5 The pages

- **Library › This device** — a section above the sources: each local model with its state
  (not downloaded / downloading with progress and a cancel / verifying / checking this device /
  ready / failed with the reason), size on disk, the routes this device offers — each saying in
  plain words whether it has been tested on this kind of device or not yet (D20), what backs it
  ("Documented by the vendor", "Experimental"), and whether it passed its check here — and
  Remove. Adding a model from a file the user already has (a GGML or an ONNX package) is here
  too, with the manifest built from the file's own metadata and marked `custom`.
- **New job** — the source dropdown gains "This device"; choosing a local model shows the
  compute-device chooser (Auto / Compatibility (CPU) / every route that passed its check here,
  the untested ones marked as such), the plan preview with the new reason codes, and a line
  saying the audio stays on the device.
- **Job detail** — the route requested, the placement that ran, per window in the advanced
  section; a fallback, when one happened, is a visible line with the reason.
- **Settings › Transcription** — the fallback policy; the system-recogniser switch (with its
  privacy wording) where the platform has one; the models location on desktop.
- **Settings › About › Diagnostics** — the device: OS, architecture, SoC where readable, GPU and
  driver where readable, RAM; every route with its probe result, evidence grade, whether this
  project has tested it on this kind of device, and its smoke-test result; a "Run smoke test" per
  route; and **Copy report** — the same facts as plain text, with no file names, paths or
  transcript text, for the user to send by hand if they choose (the app sends it nowhere). This
  is where "Encoder: GPU; decoder: CPU" is said, never on the job page.

Settings copy follows `AGENTS.md`: one line saying what it does for the person; the protocol
names and version numbers are on the diagnostics page and in the docs.

## 5. Milestones

Each milestone is a shippable increment with its own verification. `AGENTS.md`'s workflow applies
to every one: read the docs first, keep the change scoped, update the documentation in the same
commit, run `flutter analyze` and `flutter test` before committing, report in English and
Chinese, ask before pushing. The boxes below are the checklist that `AGENTS.md` says to keep
current; a box is ticked only when the "Done when" line holds. A verification that could not be
done on this project's hardware is never ticked as a verification: the route's box is ticked as
**shipped unverified** once it meets D20 — built and linked in CI, covered by the host tests,
exercised wherever anything here can run it, gated by the smoke test — and the support matrix
says so.

Order of work: **L0 → L1 → L2 → release 0.3.0 → L3 → L4 → L5 → L6 → L7 → L8 → L9**. The user
took the default on 2026-09-24, so L6 stays in its place rather than being pulled forward. L7
ships unverified support rather than being skipped for want of a device (D20); L8 closes on its
numbers either way. After 0.3.0, each milestone may ship in its own release or together with the
next (D19).

### L0 — Protocol, records and the artifact manager (no native code)

The Dart-only foundation, testable on the host in milliseconds, so that every later adapter plugs
into something already proven with a fake.

- [x] `AGENTS.md`, in the first commit of L0: the sentence under Required workflow that says this
      repository has no on-device AI is rewritten — on-device transcription is this app's
      feature from this plan on — so that it stops sending implementing agents back to ask
- [x] `localModel` record kind (D1): model, parsing, `extraJson`, template seeding with derived
      ids, refresh with `overriddenFields`; a test that a 0.2.1-shaped document with a
      `localModel` record round-trips through `TranscribeSettings` untouched, and that
      `SettingsRecordKind.parse` on the old enum reads it as `unknown`
- [x] `EvidenceLevel`, `PlacementKind`, `ComputeDevice`, `FallbackPolicy`, `EngineRoute`,
      `PreparedSession`, `AsrEvent`, the error code set (§4.2), each with its Function
      Explanation Layer comment
- [x] `LocalAsrEngine` and a `FakeLocalAsrEngine` in `test/` that scripts segments, delays,
      errors and placement, for every later test
- [x] `EngineRegistry` (which adapters exist in this build; probe caching) and `EngineRouter` as a
      pure function: filters by language (Parakeet is never a candidate for zh, ja or ko — report
      §2), by timestamp needs, by installed artifacts, by device availability and by this
      device's smoke-test result; Auto follows D20 — a route tested here on this kind of device,
      else an **A** or **B** route that passed its smoke test and beat the CPU in it, else the
      CPU, never an untested **E** or **U** route; never substitutes a model; emits a `fallback`
      decision only within the user's policy. The tested-here table lives in `engine-routing.md`
      beside the rules. Tests for each rule
- [x] `ArtifactManifest`, `ArtifactManager` and `ArtifactDownloader` (D17): resumable ranges,
      per-file SHA-256, atomic install, remove, the lease, disk-space checks that count download,
      unpack and install space separately; tests against a fake `http.Client` including a
      resumed download, a hash mismatch and a full disk
- [x] Built-in templates in `local_model_templates.dart` for the artifacts in §5.1, with pinned
      source revisions in the URLs and hashes measured at implementation time — never copied from
      a table in this file
- [x] `local_engine_state.json` and the `modelsPath` accessor in `TranscribeStorage`; `models/`
      excluded from iCloud backup on Apple platforms (by living in the caches directory — see the
      decisions log); smoke-test results keyed as §4.4 says, so an adapter, model, OS or driver
      change asks for a new check; the in-flight marker and its
      startup rule (a marker left behind → the route is `crashed` here, `ROUTE_CRASHED` on the
      interrupted job, which resumes under the fallback policy), tested with the fake engine
- [x] Planner **time-only mode** with `windowCappedByEngine` and `windowCappedByMemory`, the
      fingerprint additions, and the rule that a local job always decodes to PCM; tests in
      `chunk_planner_test.dart`
- [x] `MediaToolkit` PCM window output on both backends; `media_toolkit_live_test.dart` and
      `integration_test/media_toolkit_test.dart` extended so both backends produce byte-identical
      WAV headers and sample counts for the same window (the external backend verified on the
      ARM64 machine; the embedded one runs on a device by hand, per `integration_test/README.md`,
      at the next device session)
- [x] `LocalTranscriptionBackend` and the runner's `transcribing` stage; `job_runner_test.dart`
      drives a whole job through the fake engine: prepare once, three windows, a cancel mid-window
      that waits for the engine, a resume that reuses windows, a device change that discards them,
      a `fallback` event recorded on the job, an `OUT_OF_MEMORY` that fails the job with the new
      `JobFailureKind`
- [x] Docs: `features/local-models.md`, `algorithms/engine-routing.md`,
      `local-asr-support-matrix.md` (from §2.7) written in both languages; `data-formats.md`,
      `sync.md`, `architecture.md`, `platform-notes.md`, `chunking-and-resume.md`,
      `algorithms/chunk-planner.md`, `media-tools.md`, `functions/INDEX.md` updated; glossary
      terms added (§6)
- [x] **Done when**: `flutter analyze` is clean, `flutter test` is green, the fake engine carries a
      recording through the runner end to end, and `test/doc_mirror_test.dart` passes with the
      new pages

### L1 — Whisper on the CPU, on all four platforms (whisper.cpp)

The first real engine, and the first time the native build has to work on Windows ARM64, Android,
iOS and macOS at once. Metal comes with the Apple build and is reported honestly as `gpu`.

- [ ] `packages/whisper.cpp` submodule at a release tag (v1.9.4 at writing; re-check);
      `packages/local_asr_whisper` FFI package with `hook/build.dart` driving CMake:
      `GGML_BACKEND_DL=ON`, CPU backend always, with runtime feature dispatch
      (`GGML_CPU_ALL_VARIANTS` where the pinned ggml supports it on that target — check at lock
      time) so that a CPU nobody here has tested gets a kernel it can run rather than an illegal
      instruction; `GGML_METAL` and `WHISPER_COREML` on Apple; no GPU backend elsewhere yet
      (L3). On Windows the hook uses **clang/LLVM** (what upstream builds its own Windows ARM64
      binaries with; MSVC's `cl.exe` lacks the FP16 intrinsics and is unsupported by the OpenCL
      backend). A Linux host build is included because `flutter test` on the Ubuntu runner runs
      the Dart VM there
- [ ] `ffigen` bindings for `whisper.h`; `WhisperCppEngine` in its own isolate (D16): load,
      `whisper_full` with `abort_callback`, `progress_callback`, `new_segment_callback`; language
      from the job's first language or auto-detect; threads from the core count; DTW word
      timestamps through the `dtw_aot_preset` for large-v3 and large-v3-turbo; token and segment
      timestamps into `ChunkSegment`s with `hasRealTimestamps: true`
- [ ] Placement from `whisper_print_system_info` and the backend registry: `cpu` on CPU-only
      builds, `gpu` when the Metal backend took the graph, `mixed` when the Core ML encoder ran
      with a CPU decoder, `unknown` otherwise
- [ ] Android: a backup rule (`android:dataExtractionRules` and `android:fullBackupContent`) that
      excludes `models/` from Auto Backup and device transfer, before the first model can be
      downloaded there; `platform-notes.md` updated (L0 left it, recorded in the decisions log)
- [ ] Memory guard: refuse to load an artifact whose `minimumRamBytes` exceeds available memory,
      with `OUT_OF_MEMORY` and the numbers; measure the real peak on each verifying device and
      write it into the verification record
- [ ] The smoke test (D20): a bundled English clip of about ten seconds whose licence allows
      shipping it (whisper.cpp's `samples/jfk.wav`, a public-domain speech, is the usual one)
      through the route on this device; its text compared with the clip's expected text within
      a threshold fixed in `engine-routing.md`, its speed measured; run automatically after an
      install ("checking this device") and before a route's first job whenever its key has no
      `passed` result; the in-flight marker written around every native call from here on
- [ ] Library › This device, the new-job changes, the job-detail placement line, the
      diagnostics page with "Run smoke test" and "Copy report" (§4.5); ARB strings in all three
      catalogs; `flutter gen-l10n` committed; widget tests at the six geometries in Simplified
      Chinese
- [ ] `integration_test/local_asr_test.dart`: loads `ggml-tiny` (75 MB, fetched once and cached
      by the test), transcribes a bundled ten-second fixture, cancels a run, releases; on-device
      only. `test/local_asr_live_test.dart` does the same on the host behind
      `--dart-define=live_model=true`
- [ ] CI: every job builds the hook; LLVM installed on both Windows jobs; the whisper.cpp build
      output cached by submodule commit, OS, architecture and toolchain
- [ ] Verification on real hardware, each written into `local-asr-support-matrix.md` with the
      device, OS, driver, artifact hash, RTF and peak memory: **Windows ARM64** (this machine —
      the 81-minute lecture from M8 through large-v3-turbo and large-v3, compared line by line
      with the OpenRouter transcript), **Pixel 10** (CPU; turbo q5_0 and turbo; memory under the
      3 GB Google reserves; a foreground service with a notification keeps the job alive),
      **macOS** (the Mac mini; Metal placement recorded), **iOS** on an iPhone if one is
      available, otherwise the Simulator on the Mac for the code path and the device shipped
      unverified; **Windows x64** shipped unverified, its CPU route run under emulation on this
      machine; every other Android device shipped unverified (D20)
- [ ] Docs: `platform-notes.md` (the toolchain per platform, clang on Windows, the submodule),
      `ci-cd.md` (new steps and caches, the tiny-model tests), `features/local-models.md`
- [ ] **Done when**: a real recording is transcribed on Windows ARM64 and on the Pixel 10 with
      the placement it actually ran on, the targets nothing here can test ship unverified with
      their smoke test passing wherever anything can run it, the tests above are green, and both
      language trees say how

### L2 — Parakeet and Qwen on the CPU (sherpa-onnx), and release 0.3.0

- [ ] `sherpa_onnx` from pub at the first version that carries the Windows ARM64 DLLs (PR #3957,
      merged 2026-09-20, after 1.13.8); until then, a vendored trimmed copy with the ARM64 archive
      fetched by hash in a build hook, documented exactly as the FFmpeg copy is (`VENDORED.md`,
      `analysis_options.yaml` exclusion, the KGP rule from `platform-notes.md` checked for its
      Android plugin)
- [ ] `SherpaOnnxEngine` in its own isolate: Parakeet TDT 0.6B v3 int8 (token timestamps →
      segments), Qwen3-ASR 0.6B int8 (no timestamps → `hasRealTimestamps: false`, segments by
      the runtime's sentence splits; language from the job or auto; the job's keywords as
      Qwen hotwords); sherpa-onnx ≥ 1.13.8 for the silence and feature-alignment fixes
- [ ] The router's language rule proven with real audio: Chinese and Japanese never reach
      Parakeet; the new-job page says why a model is not offered for the chosen language rather
      than hiding it
- [ ] Optional inside this milestone: a Qwen3-ASR 1.7B int8 export by the documented sherpa-onnx
      script, as a `custom`-family template with our own hash — only if the 0.6B quality on the
      M9 meeting recording is not enough
- [ ] `coreml` and `directml` providers are **not** switched on: they are strings the binary may
      not honour (report §4.1). If tried later, as a route with `unknown` placement
- [ ] Verification as in L1 on the same devices and recordings; RTF and memory into the matrix
- [ ] Docs, glossary, `version-history.md` entry for 0.3.0; `AGENTS.md` behaviour contract
      gains the model-download endpoint and the "audio never leaves the device with a local model"
      promise; `PRIVACY_POLICY.md` and the privacy page gain the local-model paragraph
- [ ] **Release 0.3.0** — the version the user confirmed on 2026-09-24: `pubspec.yaml`
      `0.3.0+4` and `msix_version` `0.3.0.0`, the three `installer.iss` fields, the
      `version-history.md` entry, the annotated tag `v0.3.0`; the push still waits for the
      user's yes, per `AGENTS.md`
- [ ] **Done when**: all three model families transcribe on the CPU on Windows ARM64, the Pixel
      10 and the Mac, the language rule holds, iOS, Windows x64 and every other Android device
      ship unverified per D20, and 0.3.0 is tagged

### L3 — GPU routes, each behind its own smoke test

A route is offered when its backend was built, its driver answers, and its smoke test on this
device passed; Auto picks it only under D20's rule, so an **E** route is never on unless this
project tested it on that kind of device or the user chose it. The diagnostics page shows the
others as "not built", "no driver", "failed" or "crashed" with the reason.

- [ ] Runtime backend loading and the GPU half of the smoke test: load the backend library, run
      ggml's backend-operation self-test for the ops whisper uses, then L1's clip, its text
      compared with the CPU result as well as with the expected text, and its speed with the
      CPU's; record pass/fail with driver and library versions
- [ ] **Windows ARM64 — OpenCL on Adreno X1** (`-DGGML_OPENCL=ON`, clang, the trimmed Adreno
      OpenCL SDK from the `snapdragon-toolchain` releases, pinned by version and hash, installed
      by CI and on this machine). Verify here: turbo and large-v3 on this machine, RTF and memory
      versus the CPU; the open upstream OpenCL bugs (Adreno 830 assertion, X2 Elite driver crash)
      noted in the matrix
- [ ] **Windows x64 — Vulkan** (`-DGGML_VULKAN=ON`, the Vulkan SDK pinned on the runner).
      Shipped unverified (D20): no x64 machine here; the smoke test gates it on each user's
      device, and as a **B** route Auto may use it where it passed and beat the CPU
- [ ] **Android — OpenCL on Adreno** (`libggml-opencl.so`, headers and loader from the Khronos
      repositories as upstream's Android guide does). Shipped unverified (D20) — no Snapdragon
      phone; an **E** route, so until the evidence changes it runs only by the user's choice after
      its smoke test passes; the open upstream bugs (Adreno 830 assertion, 643 segfault) in the
      matrix
- [ ] **Android — Vulkan on Tensor G5** (`libggml-vulkan.so`; f16 and Q8_0 artifacts only, no
      k-quants; gated on driver ≥ 1.662.3024). Verify here on the Pixel 10: correctness first,
      then RTF and energy against the CPU; if the self-test fails on the PowerVR driver, the
      route stays "experimental, failed on this device" and that is a valid result
- [ ] **Desktop Parakeet and Qwen on the GPU**: transcribe.cpp (Metal, Vulkan) as its own FFI
      package for macOS and Windows x64; on Windows ARM64 it has no OpenCL and no evidence, so
      the Qwen candidate there is llama.cpp's Qwen3-ASR port over the same OpenCL backend — a
      single ggml build shared with whisper.cpp (report §10.2), only if the smoke test and a
      long-audio test pass. Each closes on its result: shipped (unverified where nothing here
      can run it), or dropped because a test that could be run here failed — recorded either way
- [ ] Docs and matrix updated with every result, including the negative ones
- [ ] **Done when**: the OpenCL route is verified on this machine, the Tensor Vulkan experiment
      has a recorded result either way, the routes nothing here can test ship unverified, and no
      GPU option ever appears without a passing smoke test

### L4 — Apple native: the Neural Engine

Raises the deployment targets to iOS 17 / macOS 14, which the user approved on 2026-09-24 (D12);
nothing here waits for another confirmation. If L1 already had to raise them, this milestone
uses them as they are.

- [ ] Deployment targets raised to iOS 17 / macOS 14 in the Xcode projects, the Podfiles and
      package manifests, and anything in CI that names them; `platform-notes.md`, the README's
      requirements and the release notes say which devices that drops — on Apple's lists at the
      time of writing, the iPhone 8, 8 Plus and X and the iPads of that generation, and Macs from
      before 2018 other than the 2017 iMac Pro; confirm both against Apple's pages when it is done
- [ ] `packages/local_asr_apple`: a SwiftPM plugin (Flutter 3.44 default) depending on
      FluidAudio pinned by exact version; a Pigeon API with `probe`, `prepare`, `transcribe`
      (events through a Flutter API callback), `cancel`, `release`; inference on a native queue
- [ ] Models through **our** artifact manager: FluidAudio's `ModelHub.offlineMode` on and the
      directory pointed at `models/<artifactId>/`, so no download ever happens outside the
      manifest (D17); manifests for `FluidInference/parakeet-tdt-0.6b-v3-coreml` and
      `FluidInference/qwen3-asr-0.6b-coreml` (int8), file by file
- [ ] Placement: Core ML does not report per-operation placement without profiling, so the
      route records `mixed` (configured for CPU + Neural Engine) or `unknown`, never "100 % ANE"
      (report §5.4)
- [ ] The Qwen quality gate: the same PCM through the Core ML route and the sherpa-onnx CPU route
      on a fixed set (Chinese, English, Japanese, mixed; the M9 meeting), with a WER/CER threshold
      chosen **before** the run; a route that fails the gate ships as "experimental" with the
      numbers on the diagnostics page
- [ ] Optional: WhisperKit through the same plugin for Whisper on the Neural Engine, only if the
      whisper.cpp Core ML encoder from L1 is measurably worse on the Mac
- [ ] Verification on the Mac mini (macOS) — memory under pressure (an 8 GB machine as well if
      one exists), background/foreground during a job; iOS on an iPhone if one is available,
      otherwise the Simulator for the code path and the iOS route shipped unverified (D20) — the
      Simulator runs neither the Neural Engine nor a phone's memory limit
- [ ] **Done when**: Parakeet and Qwen transcribe through FluidAudio on the Mac with the
      placement recorded, the Qwen gate has a number, and the docs say what the target bump cost

### L5 — Qualcomm NPU: two adapters

Whisper-Large-V3-Turbo only, because it is the only ASR model with a vendor package (§2.5). The
record is the **turbo** record; large-v3 is not offered on this route.

- [ ] Common: an `EPContext` model loader over ONNX Runtime's C API; a host-driven decoder loop
      (the encoder once per 30 s frame, the decoder step by step with its KV cache, the same
      tokenizer and special tokens as the Whisper record); SoC detection and a per-SoC asset
      table keyed by HTP architecture (v73 X Elite, v75 8 Gen 3, v79 8 Elite, v81 8 Elite Gen 5
      and X2 Elite — the last from a secondary source, verify); the runtime pinned to the version
      the asset was compiled with; placement `npu` for the encoder and decoder only when QNN's
      profiling says so, `mixed` otherwise
- [ ] Assets: rebuilt with AI Hub's current compile + link workflow (the context-binary target
      was removed 2026-09-14), one EPContext model per HTP architecture, hashed into manifests;
      the model licence (Apache-2.0) and the runtime licence recorded separately
- [ ] **L5a — Windows ARM64**: `Qualcomm.ML.OnnxRuntime.QNN` 2.6.0 (or the newest with the same
      ORT compatibility) as a build-hook download by hash; the plugin EP registered by path;
      Windows ML declined — the default the user took on 2026-09-24 — because its catalogue does
      not list the X2 Elite, which the NuGet EP covers. **Verify here**: the lecture through the
      NPU on this machine, encoder and decoder placement from QNN profiling, RTF against CPU and
      OpenCL, and — because an NPU that is slower may still be worth it — energy measured, not
      assumed; the X2 Elite (v81) asset ships unverified (D20)
- [ ] **L5b — Android**: `com.qualcomm.qti:onnxruntime-android-qnn` + `qnn-runtime` (or
      Microsoft's AAR), the manifest and packaging rules from §2.5 (`uses-native-library`,
      `ADSP_LIBRARY_PATH`, legacy packaging). The `qnn-runtime` licence text is read and the
      redistribution question answered **before** the AAR is added; if it does not clearly allow
      shipping the runtime inside an app, L5b closes on that answer, written into
      `platform-notes.md`, and nothing is shipped. Otherwise it **ships unverified** (D20) — no
      Snapdragon phone here — in both flavours, the per-SoC asset downloaded only for the SoC the
      device reports, gated by the smoke test. Its added size is measured; if it pushes the Play
      bundle past the store's limit, the store flavour leaves it out (the first feature gated on
      the flavour) rather than downloading native code, which Play's policy forbids
- [ ] Docs: `platform-notes.md` (the two runtimes, the packaging rules, the licence answer),
      the matrix, `features/local-models.md`
- [ ] **Done when**: L5a is verified on this machine with placement evidence; L5b ships
      unverified or is closed on the licence answer, and shows nothing on a device that has not
      passed the smoke test

### L6 — The operating system's recogniser (optional fallback)

Off by default; a visible choice; never a silent substitute (D15).

- [ ] Apple, in `packages/local_asr_apple`: `SpeechAnalyzer` + `SpeechTranscriber` with the
      `offlineTranscription` preset and `audioTimeRange` on iOS/macOS 26+, driven from
      `AVAudioFile` on the PCM window; below 26, `SFSpeechRecognizer` with
      `requiresOnDeviceRecognition = true` only where `supportsOnDeviceRecognition` is true, and
      the authorization prompt with `NSSpeechRecognitionUsageDescription` in both Info.plists;
      the server path only behind a separate switch whose wording says the audio goes to Apple,
      with the one-minute limit honoured by the planner
- [ ] Android, in a small Kotlin plugin: `createOnDeviceSpeechRecognizer` (API 31) when
      available; `EXTRA_AUDIO_SOURCE` (API 33) fed from a pipe at real-time pace with the three
      format extras and a segmented session; language packs via `checkRecognitionSupport` and
      `triggerModelDownload`; word timing from `RECOGNITION_PARTS` when returned; detection of the
      microphone fallback, first of all by the smoke test (a known clip through the pipe) before
      any real job uses the recogniser; `RECORD_AUDIO` declared in the manifest and requested at
      runtime only when this switch is turned on — the default the user took on 2026-09-24
      (§2.6) — with the privacy policy, the store listing and `platform-notes.md` saying why a
      file API needs it
- [ ] Windows: not offered; `hasSystemSpeechRecognizer` is false there and the setting is absent
- [ ] The job records `engine: system`, the transcript header says so, `diarization: unsupported`,
      timestamps marked by their kind
- [ ] Verification on the Pixel 10 and the Mac; on an iPhone if available; other Android
      devices, and iOS without an iPhone, ship unverified (D20)
- [ ] Docs: `features/system-speech.md` in both languages; the privacy page and
      `PRIVACY_POLICY.md`; `platform-notes.md` for the new plist keys and the Android permission
- [ ] **Done when**: a phone with no model downloaded transcribes a recording through the system
      recogniser after the user turned it on, the transcript says which engine produced it, and
      the policy says where the audio went

### L7 — Windows x64 NPUs (unverified support)

No Core Ultra or Ryzen AI machine exists here, so both routes ship as unverified support (D20)
rather than being skipped for want of one. A route closes only for a reason that is not
verification — its runtime cannot be fetched in CI without an account, its licence does not allow
shipping it, or it would more than double the Windows x64 download — and the matrix and the
decisions log say which.

- [ ] Intel: OpenVINO GenAI `WhisperPipeline` on `NPU` (large-v3 exported to IR by our tooling
      and hashed into a manifest like any artifact; the compile cache with a size cap; "preparing
      model" as its own state); a C++ wrapper in a build hook against the OpenVINO runtime pinned
      by version and hash, in the Windows x64 build only; the code path exercised with the `CPU`
      device wherever the x64 build can run here
- [ ] AMD: whisper.cpp `WHISPER_VITISAI` with the Ryzen AI runtime and the `.rai` encoder cache,
      Windows and Ryzen AI 300 only (report §5.2); the runtime is found on the user's machine at
      run time unless its licence allows bundling it
- [ ] The matrix says **A on paper, unverified here** for each route that ships, and gives the
      reason for each that closed

### L8 — Local speaker labels (a stretch that closes on its numbers)

- [ ] sherpa-onnx offline speaker diarization (segmentation model + speaker embedding model) as a
      second artifact family, run per window after the ASR window is released from memory,
      producing window-local labels the existing unifier joins by overlap — the diarized overlap
      of 20 s applies again; FluidAudio's diarization on Apple as the second implementation
- [ ] The M9 meeting (three speakers, 301 lines) as the acceptance recording; the unifier's
      thresholds unchanged unless a documented decision changes them
- [ ] **Done when**: the labels are at least as consistent as the OpenRouter ones on that
      recording, or the milestone is closed as "not good enough" with the numbers

### L9 — Closing

- [ ] Every milestone above closed — ticked, with each route it ships marked verified or
      unverified, or closed on a recorded reason that is not "could not be verified" (D20); every
      unverified route is in `local-asr-support-matrix.md` in both languages
- [ ] The closing steps in §10 executed, ending with the deletion of this file

### 5.1 The artifacts the templates ship with

Sources as found on 2026-09-24. The implementer pins each URL to a repository revision, measures
the SHA-256 of every file, and records licence and attribution per artifact — the numbers in this
table are for planning capacity, never for verification.

| Template id | Adapter | Files | Size | Licence | Source |
|---|---|---|---|---|---|
| `local:whisper-large-v3-turbo` | whisper_cpp | `ggml-large-v3-turbo.bin` (+ `…-encoder.mlmodelc.zip` on Apple) | 1.5 GiB | MIT | `huggingface.co/ggerganov/whisper.cpp` — SHA-1s in whisper.cpp `models/README.md` |
| `local:whisper-large-v3-turbo-q5` | whisper_cpp | `ggml-large-v3-turbo-q5_0.bin` | 547 MiB | MIT | same |
| `local:whisper-large-v3` | whisper_cpp | `ggml-large-v3.bin` (+ encoder on Apple) | 2.9 GiB | MIT | same |
| `local:whisper-large-v3-q5` | whisper_cpp | `ggml-large-v3-q5_0.bin` | 1.1 GiB | MIT | same |
| `local:parakeet-tdt-0.6b-v3` | sherpa_onnx | the int8 tarball's encoder, decoder, joiner, tokens | ≈ 0.6 GB | CC-BY-4.0 (attribute NVIDIA) | `github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models` |
| `local:qwen3-asr-0.6b` | sherpa_onnx | conv frontend, encoder int8, decoder int8, tokenizer | 838 MiB | Apache-2.0 | same, `sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25` |
| `local:parakeet-tdt-0.6b-v3` (Apple route) | apple_fluid | the Core ML package files | see repo | CC-BY-4.0 | `huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml` |
| `local:qwen3-asr-0.6b` (Apple route) | apple_fluid | int8 Core ML files | ≈ 0.7 GB | Apache-2.0 | `huggingface.co/FluidInference/qwen3-asr-0.6b-coreml` |
| `local:whisper-large-v3-turbo` (Qualcomm route) | qnn | one EPContext model per HTP architecture | per asset | Apache-2.0 (model); runtime licence separate | `huggingface.co/qualcomm/Whisper-Large-V3-Turbo`, rebuilt through AI Hub compile + link |

One record, several artifacts: `local:whisper-large-v3-turbo` lists the ggml artifact and the
Qualcomm one; `local:parakeet-tdt-0.6b-v3` lists the ONNX one and the Core ML one. The router
picks the artifact by adapter and device; the user picks the model.

## 6. Documentation obligations

`AGENTS.md` makes the docs the primary artifact; this section only lists what this plan touches so
nothing is forgotten. Every item is in **both** `doc/en-us/` and `doc/zh-cn/`, in the same
commit, with the same headings, and `test/doc_mirror_test.dart` is the judge.

New pages:

- `features/local-models.md` — what a local model is, downloading, verifying, choosing a device,
  what the job records, what the diagnostics page shows, what "unverified" means to the user.
- `algorithms/engine-routing.md` — the router's rules and their order (§4.2, L0), derived not
  described, with the same worked examples the tests use.
- `local-asr-support-matrix.md` — §2.7 as a living page, one row per target, with the
  verification records (device, OS, driver, artifact hash, RTF, peak memory, date), the routes
  that ship unverified, and any diagnostics report received from somebody else's hardware.
- `features/system-speech.md` (L6) — the fallback, per platform, and its privacy line.
- `decisions.md` — created in the closing step (§10) from the decisions log below.

Existing pages that change, with the milestone that changes them: `architecture.md` (the feature
list, the four kinds of data become five with "downloaded models — never synced, never backed
up"; L0), `data-formats.md` (§4.4; L0), `sync.md` (the `localModel` record kind and how older
builds carry it; L0), `backup-restore.md` (models excluded; L0), `platform-notes.md` (toolchains,
the submodule, clang on Windows, the OpenCL SDK, deployment targets, the Android permission, plist
keys; L1–L6), `ci-cd.md` (new steps, caches, the tiny-model tests; L1), `features/provider-library.md`
("This device"; L0), `features/transcription-jobs.md` (the `transcribing` stage; L0),
`features/chunking-and-resume.md` and `algorithms/chunk-planner.md` (time-only mode, PCM windows,
new reason codes; L0), `features/media-tools.md` (PCM output; L0), `features/exports.md`
(subtitles from local timestamps; L1), `version-history.md` (every release), `functions/INDEX.md`
(every new file, or the mirror test fails), `README.md` at the root and both `doc/*/README.md`
(status and contents).

Glossary (`translation-guide.md` §5.2, app-specific — none of these is cross-cutting, so no
sibling repository changes): local model, engine, download (a model), compute device, on this
device, verified / unverified / experimental, tested on this kind of device, smoke test (a
route's check on this device), placement, fallback, system recogniser, artifact (the downloaded
package), diagnostics report. The implementer chooses the Simplified and Traditional terms with
the guide's rule in mind (設定 not 設置, 檔案 not 文件, 轉寫 not 转写) and adds them before the
first ARB string that uses them.

Privacy: `PRIVACY_POLICY.md` and `privacy_policy_page.dart` gain, at L2, a paragraph saying that
with a downloaded model the audio never leaves the device, that the only new network contact is
the model download the user asks for, and that the diagnostics report is text the user copies and
the app sends nowhere; at L6, the paragraph on the system recogniser saying per platform whether
audio can leave the device and how the switch is worded; at L6 on Android, the microphone
permission and why an API needs it for a file.

`AGENTS.md`: in L0, the sentence saying this repository has no on-device AI is rewritten (the user
asked for this feature; the sentence predates it). As the features land, the opening paragraph
mentions the local models; the behaviour contract gains the local-model promises (audio stays on
the device; downloads only from the manifest, only on a tap; `models/` is never a data module;
model identity is never substituted; placement is recorded, never inferred; a route not tested on
this kind of device says so and is picked by Auto only as D20 allows); and in L1 the "Working with
the shared package" section gains the whisper.cpp submodule rule (§4.1). Only rules about how to
work go there; the explanations go in the docs.

## 7. Tests and verification

Host tests (`test/`), all runnable with no model, no network and no device:

- `local_model_config_test.dart` — parsing, `extraJson`, templates, the unknown-kind round trip
- `engine_router_test.dart` — every rule in `algorithms/engine-routing.md`, as pure cases, D20's
  Auto rule among them
- `local_engine_state_test.dart` — smoke-test keys, the in-flight marker, and what a marker left
  behind does at the next start
- `artifact_manager_test.dart` — resume, hash mismatch, full disk, atomic install, the lease
- `chunk_planner_test.dart` — time-only mode and the new reasons
- `job_runner_test.dart` — the fake engine through the whole machine (L0)
- `local_models_ui_test.dart`, `engine_diagnostics_ui_test.dart` — the pages at the six
  geometries, in Simplified Chinese, following `viewer_layout_ui_test.dart`
- `local_asr_live_test.dart` — the real whisper.cpp engine on the host with `ggml-tiny`, behind
  `--dart-define=live_model=true`, skipping itself otherwise, like the FFmpeg live test
- `doc_mirror_test.dart` and `l10n_arb_test.dart` — unchanged, and binding

On-device tests (`integration_test/`), run by hand per `integration_test/README.md`:

- `media_toolkit_test.dart` — extended with the PCM window
- `local_asr_test.dart` — load, transcribe, cancel, release with the tiny model; the same
  assertions on every platform, so a wrong architecture or a missing symbol fails at the first
  call in the test and not in front of the user; run in the iOS Simulator and, for the Windows
  x64 build, under emulation on the ARM64 machine too — as close as this project gets to those
  targets

Acceptance per route, before its box is ticked (report §11.1): artifact verification, cold load,
first compile where there is one, a short clip, a long recording split into windows, two jobs
back to back, cancel, switching models, low memory, background and foreground on mobile, offline
with the network switched off. Each record names the SoC, OS, driver, runtime versions, artifact
hash, quantization and decoding settings, and gives RTF, first-result latency and peak memory. A
route with no device here to run this list on gets no acceptance record: its box is ticked as
shipped unverified once D20's conditions hold, and a diagnostics report from somebody else's
hardware is recorded as that, with its date, never as this project's verification.

## 8. CI

`.github/workflows/build.yml` changes, all keeping the local gate where it is:

- Every job builds the build hooks as part of `flutter build`; CMake and Ninja are on every
  GitHub runner, the Android NDK comes with Flutter, Xcode with the macOS runners.
- **Both Windows jobs install LLVM** (a pinned release, by URL and hash; the ARM64 runner takes
  the `woa64` installer) — clang is the compiler for whisper.cpp there (L1).
- **windows-x64** installs the Vulkan SDK (pinned) for `ggml-vulkan.dll` (L3) and fetches the
  OpenVINO runtime (pinned, by hash) for the Intel NPU route (L7).
- **windows-arm64** unpacks the trimmed Adreno OpenCL SDK tarball from the `snapdragon-toolchain`
  releases (pinned version and hash) for `ggml-opencl.dll` (L3), and downloads the Qualcomm ORT
  QNN package by hash (L5a).
- **android** fetches the Khronos OpenCL headers and loader at pinned commits for
  `libggml-opencl.so` (L3), and the QNN AARs once the licence answer allows them (L5b).
- The native build directories are cached, keyed by submodule commit, OS, architecture, backend
  set and toolchain version, so a docs-only push does not rebuild ggml five times.
- `flutter test` on the Ubuntu runner runs the host live test with the tiny model cached by
  `actions/cache`; no other model is ever downloaded in CI.
- Artifact sizes: the app gains the native libraries (tens of MB) and no model; the Release
  assets stay as they are.

Windows Defender: a new native DLL with no reputation is the same problem the pinned Flutter tag
solves for `flutter_windows.dll` — pinned toolchains and pinned upstream commits keep each DLL's
hash stable between releases, which is the only lever this project has without a signing
certificate.

## 9. Risks and open questions

- **PowerVR (Pixel 10) Vulkan correctness.** Likely outcome: the experiment fails its self-test
  on the current driver. That is a recorded result, not a blocker; the CPU path is the product.
- **sherpa-onnx Windows ARM64 in the pub package** — merged upstream on 2026-09-20, not yet
  released. If the next release slips, L2 vendors (D11).
- **Deployment-target bump** (D12) — approved by the user on 2026-09-24. It still removes
  devices, so it lands only in the first milestone that needs it, and that release's notes say
  which.
- **Qualcomm runtime redistribution** — the AI Hub Model License text could not be read; the
  QAIRT EULA marks files confidential. L5b does not add the AAR until the answer is in the docs.
- **AI Hub pipeline churn** — assets must be rebuilt with compile + link; pin every version.
- **Android microphone permission for the fallback** (§2.6) — a stated property of the app
  changes; the user took the default on 2026-09-24: declared, asked for only when the fallback is
  switched on, explained in the privacy policy and the store listing.
- **Memory on 8 GB phones** — large-v3 f16 will not fit; the guard refuses with numbers rather
  than crashing, and the matrix says which artifacts fit which devices.
- **Long audio through Qwen ports** — llama.cpp's port fails past about two minutes; our windows
  are shorter, but the transcribe.cpp path is the primary desktop candidate for that reason.
- **Qwen 1.7B** has no published sherpa-onnx export; optional own export in L2.
- **Upstream drift** — every claim here is dated; the implementer re-verifies at lock time and
  records corrections in the decisions log.
- **Store review** — downloading model weights is data, not code; the privacy labels gain
  nothing new for local models. L6 adds the speech-recognition usage string on Apple platforms and
  the microphone permission on Android, and the store listings change in the release that ships
  them.
- **What this project cannot verify**: Snapdragon Android, MediaTek, Exynos, Intel and AMD NPUs,
  Windows x64 CPUs and GPUs, an iPhone unless one is available. These routes ship as unverified
  support (D20): built, CI-tested, gated by the smoke test on each device, marked as untested in
  the product, and picked by Auto only as D20 allows. A diagnostics report from somebody with the
  hardware is recorded in the matrix as a community result.
- **Unverified routes in users' hands** — a route that passes a ten-second check can still fail
  on a long recording: a GPU driver timeout, a leak, the Qwen port's long-audio bug. The
  in-flight marker, the fallback policy (the same model on the CPU by default) and the per-window
  persistence bound the damage to one window, and the job says what happened.
- **Tensor NPU** — not pursued: the user declined the Tensor SDK beta on 2026-09-24 (D14).

## 10. Closing this plan

When L9's first box is ticked, in one documentation-only commit:

1. Create `doc/en-us/decisions.md` and `doc/zh-cn/decisions.md` from the decisions log below —
   every entry, verbatim, newest first — and add both to the Reference lists in the two
   `doc/*/README.md` files.
2. Edit `AGENTS.md`: the sentence "The phased roadmap lives in `PLAN.md`", the table row "What is
   planned, in what order, and what is done | `PLAN.md`", and workflow step 4's `PLAN.md`
   checklist rule. Point "what is done" at `doc/en-us/version-history.md` and "why a choice was
   made" at `doc/en-us/decisions.md`; the checklist rule is deleted, not reworded.
3. Edit the root `README.md` ("`PLAN.md` is the roadmap") and the Status sections of both
   `doc/*/README.md`, which today still describe the 0.1.0 state.
4. `git rm PLAN.md`.
5. `flutter analyze`, `flutter test` — `test/doc_mirror_test.dart` proves the new page exists on
   both sides and every link still resolves.
6. Commit ("Close the local-models plan"), push `origin`, then `github`. No version bump, no tag:
   a documentation-only commit, per `AGENTS.md`.

Nothing else may still reference `PLAN.md` at that point; `grep -rn "PLAN.md" --include="*.md" .`
outside `packages/` must return nothing.

## Decisions log

Recorded when a choice is made that later work should not quietly reverse. Newest first within
each date. This log outlives this file: the closing step in §10 moves it, verbatim, to
`doc/en-us/decisions.md`.

- **2026-09-24** — L0: **0.2.x does not carry an unknown record kind "untouched".** It parses the
  kind to `unknown` and writes the literal `unknown` back, so a `localModel` record that passes
  through a 0.2.x device comes back without its kind — D1's premise was wrong on this one point.
  Two repairs, both in `SettingsRecord`: this build writes an unknown kind back exactly as it found
  it (so a later build's kind survives a round trip through this one), and every local model id
  starts with `local:` — built-in and user-added alike — so a `kind: unknown` record with such an id
  reads as `localModel` again and is written back with its kind at the next save. The 0.2.1 test
  that asserted the old behaviour was changed to assert the new one.
- **2026-09-24** — L0: **On Apple platforms `models/` lives in the caches directory** rather than
  under the app directory with the do-not-back-up flag set, because setting that flag needs native
  code and L0 has none. iCloud backup and Time Machine skip the caches directory; the cost is that
  the system may purge it when space is short, which the library shows as "not downloaded" — the
  honest state of a re-downloadable cache. On Android the manifest sets no backup rule, so Auto
  Backup (which already gives up on this app past 25 MB of recordings) is addressed in L1 with an
  explicit rule excluding `models/`, before a model can first be downloaded there.
- **2026-09-24** — L0: **Template hashes are the ones the hosts publish**, not hashes computed from
  whole downloads: Hugging Face's LFS object id for the whisper.cpp files — checked to be the file's
  own SHA-256 by downloading `ggml-tiny.bin` (`be07e048…`) — and GitHub's release-asset digests for
  the sherpa-onnx archives. The downloader verifies every file against them. An archive is verified
  as an archive; the files it unpacks are hashed on the device and recorded in the installed
  manifest, so the templates need not list what is inside.
- **2026-09-24** — L0: **D4 is realised as a local branch of the runner, not an interface over both
  transports.** Local jobs go through `LocalTranscriptionBackend` (route, one prepare per job, the
  in-flight marker, mid-job fallback); the upload path is unchanged, and the stage machine's probe,
  conversion, merge and rendering are shared helpers. Wrapping the HTTP client in the same interface
  would have moved the most-tested code for no behaviour gain. A job records what the user asked to
  run on as `options.device` and every fallback in a `fallbacks` list, beside the `route`,
  `artifactRevision` and per-window `placement` §4.4 names; and the router is told which adapters
  the build contains, since adapters describe routes only for installed packages and "nothing
  installed" must read as `MODEL_MISSING`, not `BACKEND_NOT_BUILT`.
- **2026-09-24** — **The user settled the plan's open questions** the day it was written:
  release **0.3.0** first (D19); **unverified support** for the devices this project cannot test
  (D20); the deployment targets raised to **iOS 17 / macOS 14** (D12); **no** application for
  Google's Tensor SDK (D14); and the plan's defaults for everything else — the Android microphone
  permission declared for the L6 fallback and asked for only when it is switched on, the NuGet QNN
  execution provider rather than Windows ML on Windows ARM64, L6 kept in its place in the order,
  L7 shipped as unverified support, L8 closed on its numbers, and the fallback policy defaulting
  to the same model on the CPU. The entries below are written as settled.
- **2026-09-24** — **Unverified is a shipping state** (D20). Most devices this app targets cannot
  be tested here, so a route this project has not tested on a class of device ships marked as
  untested instead of being held back. It is built and covered by CI; it passes a smoke test on
  each device before its first job; Auto uses it only when its evidence is A or B and it passed
  that test and beat the CPU in it, never when it is an untested E or U route; a crash inside it
  is found at the next start by the in-flight marker and ends its automatic use on that device;
  and a diagnostics report from somebody else's hardware can raise its evidence grade but never
  makes it tested here. The code's grade for "nothing found" is `none`, so that "unverified"
  means only this.
- **2026-09-24** — Local models enter the synced document as a **new record kind**,
  `localModel`, not as a new provider dialect. A 0.2.x build reads an unknown dialect as
  `openaiCompatible` and would show a phantom source; it reads an unknown kind as `unknown` and
  carries it untouched, which is the contract that kind was written for. The files themselves,
  the chosen compute device and every smoke-test result are device-local and never sync (D1,
  D2).
- **2026-09-24** — `models/` is not a data module and will not become one: a re-downloadable
  1.5 GB file has no place in a backup bundle, a ZIP or a WebDAV upload, and the exclusion is
  structural like the recordings' (D3).
- **2026-09-24** — The job runner is not forked for local models. A `TranscriptionBackend` seam
  replaces the HTTP client for a local job; the stage machine, per-window persistence, resume,
  cancel and the overlap merge are reused as they are (D4).
- **2026-09-24** — Every local engine receives 16 kHz mono PCM cut by FFmpeg from the normalized
  copy; none receives the original file. One audio contract for three feature extractors, and a
  local job therefore needs the media toolkit on every platform (D5).
- **2026-09-24** — No silent model substitution, ever: turbo is not large-v3, the OS recogniser is
  not a model, and a fallback is a visible event under the user's own policy (D6). Capabilities
  are the intersection of model, artifact, runtime and the device's smoke test, with `unknown` a
  real answer (D7). Evidence grades and placement kinds are enums in the code, and a placement
  the runtime did not report is `unknown`, never a guess (D8).
- **2026-09-24** — whisper.cpp is built from a pinned tag in a build hook of our own, with clang
  on Windows, because both existing pub packages ship x86_64-only Windows binaries or no desktop
  at all and neither builds on this project's ARM64 machine; GPU backends are separate dynamic
  libraries so a missing driver cannot take the app down (D9, D10).
- **2026-09-24** — sherpa-onnx is the Parakeet and Qwen CPU baseline on all four platforms, from
  the pub package once it publishes the Windows ARM64 DLLs merged upstream on 2026-09-20,
  vendored and trimmed like FFmpeg until then (D11).
- **2026-09-24** — **Qwen3-ASR (0.6B / 1.7B) is the Qwen model.** The survey found no open-weight
  Qwen ASR newer than it; the Qwen-Audio-3.x ASR models announced in July–September 2026 are
  API-only. The record scheme lets a future open release become a new template without code
  changes, and the implementer re-checks the Qwen organisation at lock time.
- **2026-09-24** — The Apple native adapter is FluidAudio on the Neural Engine, which needs iOS
  17 / macOS 14. The user approved the deployment-target bump; because it is the one decision in
  this plan that removes devices, it lands in the first milestone that needs it — L4, unless
  whisper.cpp's Metal or Core ML path needs it in L1. Whisper's Apple acceleration in L1 is
  whisper.cpp's own Metal and Core ML encoder (D12).
- **2026-09-24** — Qualcomm is two targets: Windows on Snapdragon and Android on Snapdragon get
  separate adapters, runtimes, assets and verification. The NPU route is ONNX Runtime's QNN
  execution provider with Qualcomm AI Hub's Whisper-Large-V3-Turbo assets per HTP architecture;
  the ggml Hexagon backend is not a shipping route on Windows because it requires test-signing.
  The GPU route on every Qualcomm chip is OpenCL; Vulkan produced gibberish on Adreno X1 and
  crashes on the 830 (D13).
- **2026-09-24** — Google Tensor is CPU first, a Vulkan experiment second, and no NPU: the Tensor
  SDK is a sign-up-gated beta for G5/G6 with a Parakeet artifact and no Flutter route, and the
  user decided not to apply for it (D14).
- **2026-09-24** — The OS recogniser is an off-by-default fallback with its own privacy line;
  server-side recognition only behind a separately worded switch; nothing on Windows, which has
  no shippable file-transcription API (D15). On Android it adds the microphone permission the
  app has never asked for; the user accepted that, with the permission asked for only when the
  fallback is switched on.
- **2026-09-24** — Downloads are manifest-driven, resumable, hash-verified and atomic, from the
  manifest's URL only, on a tap only (D17). Speaker labels are not offered by any local model in
  the first release; a diarization pipeline is an optional later milestone (D18). The first
  release of this plan is 0.3.0 after L0–L2, the version the user confirmed; later milestones
  ship in later releases without waiting for a verification this project cannot do (D19, D20).
- **2026-09-24** — This plan file is temporary. It replaces the closed 0.1.0–0.2.1 plan and is
  deleted by its own closing step once every milestone is closed, with the decisions log moved
  into the docs and every reference to `PLAN.md` removed in the same commit.
- **2026-09-05** — The settings merge compares a record's `id`, `kind` and `payload`, not its
  timestamps, when deciding whether two edits are really the same. Two devices that renamed a source
  to the same thing a minute apart would otherwise be asked to choose between identical
  configurations.
- **2026-09-05** — Recordings and transcripts are not a data module and will not become one without
  a deliberate decision: it would put hours of private audio into every backup bundle and every ZIP
  export. *Superseded in part on 2026-09-09, below: the text now travels, the audio still does not.*
- **2026-09-05** — A job that fails or is cancelled part-way is written back from the runner's
  latest saved state, not from the record it started with. The first version wrote the initial copy,
  which erased the plan and every finished window, so the next run paid for them all again — exactly
  what resuming exists to prevent. Caught by `test/job_runner_test.dart`, not by anything a human
  would have noticed until a long job failed.
- **2026-09-05** — `JobStore` retries its reads and writes. An atomic replace is a rename, and on
  Windows a rename fails outright while anything else holds the file open — the jobs list reading it,
  a virus scanner, the search indexer. Without the retry a running job could die on a collision that
  lasted a millisecond.
- **2026-09-05** — The transcript viewer reads its transcript, its job and its view settings from
  Riverpod providers rather than from disk in `initState`. Flutter widget tests run in a zone where
  `dart:io` futures never complete, so a page that awaits one can never be pumped — it hangs rather
  than failing, which is worse. Any page that needs a file should follow this shape.
- **2026-09-05** — `audioplayers` over `just_audio` and `media_kit`: its Windows backend is Media
  Foundation compiled from source, so it builds on ARM64, while the others ship an x86_64-only
  libmpv. Verified with a real `flutter build windows` on this machine.
- **2026-09-06** — A finished job's page reads the most recently written of three copies — the
  runner's live one, the one it wrote as the job stopped, and the record on disk — chosen by
  `modifiedAt`. The runner also counts every record it writes, and the providers watch that count.
  Before this the only thing that ever re-read a record was a page happening to refresh its list
  after a button was pressed, so a job that finished while its own page was open went on saying
  "Waiting" until the app was restarted.
- **2026-09-06** — Running a finished job again asks first and never appears as "Start". Rebuilding
  the transcript is what the stage machine does, and it overwrites the viewer's corrections; the
  out-of-date page used to offer exactly that as an innocent-looking Start button.
- **2026-09-06** — The seam search is sized from the overlap, not fixed. Twenty seconds of speech is
  about a hundred and sixty tokens and the comparison was capped at forty, so a long overlap could
  never line up. The shared speech is then followed as a chain of runs, each link starting where the
  last ended in **both** passages: two transcriptions of the same seconds disagree in scattered
  small ways, and requiring one unbroken run finds nothing, while allowing a match anywhere would
  latch onto a phrase the recording repeats throughout. The chain must cover six words, or eight
  characters in a script without spaces, before anything is cut — it starts at the later passage's
  first word but may match the earlier one anywhere, which is weaker evidence than the three-word
  rule has.
- **2026-09-06** — An unnamed speaker is numbered by their position in the transcript, never by the
  number inside their id. Ids are allocated per placed window label and can have gaps; they are also
  a contract, because they name the sample files and a source that accepts reference clips echoes
  them back, so they are never renumbered.
- **2026-09-06** — The files written beside a recording say `Speaker 1` in English whatever the
  interface language is. The runner has no `BuildContext`, and inventing a way to give it one so
  that two files could be localized is not worth the coupling; everything the user exports from the
  viewer is localized.
- **2026-09-06** — The converted listening copy is kept by default and removable by hand. It is a
  third of the size of the recording and the app gave no way to see it, let alone drop it short of
  deleting the whole transcription. Deleting it automatically would take away the viewer's audio
  from somebody who had not finished reading.
- **2026-09-06** — Renaming a transcription changes a label and nothing on disk. The files beside
  the recording keep the recording's name, because a folder of them is read by file name; an export
  takes the new name, because that is a file the user is deliberately saving somewhere.
- **2026-09-09** — Transcript *text* syncs; job folders still are not a data module. The record and
  the transcript of each finished job are projected into `transcribe_transcripts.json` before a sync
  and applied back into `jobs/` afterwards. This supersedes the 2026-09-05 entry above for the text
  only: the recordings and the chunk audio are still excluded structurally, and the converted
  listening copy travels only through an opt-in side channel, per device, off by default. The
  argument that changed: a transcript is what the user actually wants on their other device, and it
  is a few hundred kilobytes.
- **2026-09-09** — The projection carries `job.json` and `transcript.json` as **raw maps**, not
  parsed models. The nested types inside a job record have no `extraJson`, so a build that parsed a
  newer record and wrote it back would drop the newer build's fields; the two devices would then
  take turns stripping each other's and re-uploading for ever. Anything added to that document must
  keep this property.
- **2026-09-09** — A transcription that is being re-run is **frozen** in the projection rather than
  dropped from it. Only finished jobs are projected fresh, so without this rule a re-run would look
  like a deletion and the other device would delete the folder — audio included — while its owner
  watched the recording transcribe again. For the same family of reasons, deletions are honoured
  only on the three-way merge path, where the base snapshot proves an absence was a deletion; force
  download, backup restore and ZIP import are additive.
- **2026-09-09** — A `job.json` that exists but cannot be read **aborts** the projection instead of
  being left out of it. A gap in the document is indistinguishable from a deletion, and a transient
  Windows lock is not a reason to delete somebody's transcription on another device.
- **2026-09-09** — "Unknown" is manual only. The matching refuses a doubtful join rather than
  guessing, and the repair for its other failure — a label that is not one person — is the user
  saying so. A rule that decided this automatically is how a transcript loses speakers it had
  correctly identified.
- **2026-09-09** — The transcript files beside a recording became opt-in and default off. Writing
  them unasked left files in whatever folder the recording was in at the time, which is not
  somewhere the app should assume it may write, and not somewhere the user necessarily still has.
