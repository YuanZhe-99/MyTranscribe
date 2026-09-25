# Decisions

Recorded when a choice is made that later work should not quietly reverse, with the reason — the
reasoning is the part that is hard to recover later. Newest first; within a date, in the order they
were written. An entry is never edited to say something else: a choice that is reversed gets a new,
dated entry saying why.

The entries up to 2026-09-25 were kept in the local-models plan, a file at the repository root
that was deleted when the plan closed, and moved here verbatim. `D1`–`D22` are the numbered
decisions of that plan; each has its own entry below. Where an entry points at a
section of that plan (§7, report §11.1 and so on), the plan is in the repository's history.

## Log

- **2026-09-25** — **The local-models plan is closed (L9), and this log moves here.** Every
  milestone is closed: L0–L4 and L6 shipped, L5 and L7 were not built for the reasons in the entry
  below, and L8 shipped. Every route that ships is unverified support and is listed in
  `local-asr-support-matrix.md`. The acceptance list a route must pass to become *tested here*
  moved to that page, the roadmap file was deleted, and what is done is now read from
  `version-history.md`.
- **2026-09-25** — L8: **Speaker labels are one package for every local model, and closed without
  the meeting comparison.** sherpa-onnx's offline diarization (pyannote segmentation 3.0 + 3D-Speaker
  CAM++, 35 MB) runs over each window after its transcription; each segment takes the speaker it
  overlaps longest, and the existing unifier, with its thresholds unchanged, joins the window-local
  labels. A local job that asks for speakers takes the diarized overlap, as a remote one does. The
  acceptance comparison against OpenRouter's labels on the three-speaker meeting was not run — the
  user closed L2–L9 on CI passing — so the only check is sherpa-onnx's two-speaker clip, where both
  speakers were found. FluidAudio's diarization was not built: sherpa-onnx already covers macOS, and
  iOS, which has no sherpa-onnx here, has no speaker labels on the device.
- **2026-09-25** — **L5 and L7 are not built; L6 is Apple only; L8 uses sherpa-onnx.** The user's
  decision on the recommendation after 0.3.3. L5 (Qualcomm NPU) would need a whole Whisper pipeline
  around ONNX Runtime QNN — spectrogram, encoder, a decoder loop with its cache, the tokenizer —
  over runtime files whose redistribution terms were never read, for chips nothing here can run
  (this machine's v68 NPU is no longer supported). L7 (Windows x64 NPUs) would add OpenVINO, over
  100 MB, with no x64 machine to run it. L6 on Android would need Kotlin compiled in the app build,
  which D21 rules out, so the system recogniser comes to Apple only, inside the existing prebuilt
  bridge. L8 uses the offline speaker diarization of the sherpa-onnx C API the app already bundles —
  the one milestone left that this machine can actually run.
- **2026-09-25** — L4: **A prebuilt bridge, not a Swift plugin.** The plan had a SwiftPM plugin
  with a Pigeon API; under D21 no Swift may compile in the app build, and FluidAudio compiles C, C++
  and Swift. So `packages/local_asr_apple/bridge` wraps it in five `@_cdecl` functions,
  `apple-prebuild.yml` builds it once with `xcodebuild` (a multi-arch `swift build` could not find
  FluidAudio's prebuilt text-processing library), and the app binds it with ffigen like the other
  engines. The Core ML package is Parakeet v3 only — FluidAudio dropped Qwen3-ASR — pinned file by
  file. The first release packed the frameworks' dSYMs by mistake and was deleted; the workflow now
  refuses anything but a dynamic library.
- **2026-09-25** — **What this machine can run, and L2's runtimes (D22).** Research the same day,
  partly run on this machine: the CPU is 4× Cortex-X1C + 4× Cortex-A78C, ARMv8.2 with dot-product
  and FP16, no i8mm, BF16 or SVE — our ARMv8.2 build was the right baseline; the GPU has no native
  OpenCL or Vulkan driver (OpenCLOn12 lacks FP16, so ggml drops it); the NPU is Hexagon v68, which
  current QNN packages and AI Hub no longer support. So L3 and L5 cannot be verified here. For L2,
  whisper.cpp's own `parakeet` library runs Parakeet on the binaries already bundled, and Qwen3-ASR
  goes through sherpa-onnx's prebuilt C-API libraries rather than the pub package, which has no
  Windows ARM64 DLLs yet. FluidAudio has dropped Qwen3-ASR (L4).
- **2026-09-25** — **No device sessions; simple tests; L2–L9 in order.** The user decided, after
  0.3.0: the Pixel 10, Mac and iPhone runs are skipped, so everything on them ships as unverified
  support (D20) — L1's device-verification box closes on that; the CPU routes are not measured
  further; each milestone is tested simply (the package and live tests with the smallest model,
  CI green on all five platforms) and released as the next 0.3.x. **The development machine is a
  Snapdragon 8cx Gen 3** (Adreno "8cx Gen 3" GPU, driver 30.0.4122.4000; a Qualcomm Compute DSP),
  not the X Elite this plan assumed from the survey: the Qualcomm GPU and NPU routes are tried on
  it, and a route that does not run on this older generation is recorded as such — it says nothing
  about the X series, which stays unverified.
- **2026-09-24** — **Releases are v0.3.0, v0.3.1, …** The user approved tagging and chose the
  numbering: 0.3.0 when L1 is done rather than after L2, then one patch number per release. D19
  keeps its original text under the amendment.
- **2026-09-24** — L1: **Prebuilt binaries replace compiling in the app build (D21).** The user's
  decision after the first CI runs of the source build: Windows x64 spent over an hour compiling
  ggml's CPU variants without finishing, and the Linux test host, the Android analyze step and the
  x64 toolchain failed on `_GNU_SOURCE`, `-fPIC`, ccache and a newer clang in turn. Upstream's
  `b5130` release assets (the v1.9.4 commit) were listed and unpacked the same day: Windows x64,
  the Apple xcframework and Linux x64 qualify; the Windows ARM64 zip does not (a
  `debug_nonredist` OpenMP DLL, ARMv8.7); Android has none. Our own set for those two is built
  once by `native-prebuild.yml`. The C shim goes with the compiling — a shim is itself compiled —
  and the risk it removed is guarded by generated bindings plus a defaults read-back. The earlier
  L1 entries about the CPU variants, the shim and the hook's toolchain describe the superseded
  source build and stay as its record.
- **2026-09-24** — L1: **Where the CPU code is chosen at run time, and where it is not.** The
  pinned ggml builds every CPU variant and loads the best at run time on x86 and on Android, but
  its variant list has no Windows ARM64 entry (configuring with `GGML_CPU_ALL_VARIANTS` stops with
  "Unsupported ARM target OS"). Windows ARM64 is therefore one library at ARMv8.2 with dot-product
  and FP16 — upstream's own release uses ARMv8.7, which would stop older Snapdragon laptops with an
  illegal instruction — at the cost of the i8mm kernels an X Elite could use; a second, i8mm
  variant scored by ggml's own Windows feature detection is the way back if the lecture numbers
  call for it. Apple and Linux are one library as well: on Apple, Metal is part of the OS and
  nothing needs guarding; Linux is only the CI test host. 32-bit Android is not built. Android is
  packaged with legacy (extracted) native libraries, because ggml finds its CPU variants by
  listing the folder its libraries are in, and a folder inside an APK cannot be listed.
- **2026-09-24** — L1: **A C shim instead of `ffigen` bindings.** whisper.cpp's API passes its
  large parameter struct by value, and that struct changes between releases; bindings to it would
  turn every submodule bump into a silent memory-corruption risk. `lasr_whisper.c` exposes about
  twenty functions of plain types — load, transcribe, segments, devices, available memory — and
  loads ggml's backends from its own folder. Cancelling and progress are two integers in native
  memory the main isolate writes and reads while the worker isolate is blocked in the call;
  segments are returned when the window ends rather than streamed, which costs nothing at the
  window's granularity. DTW word timestamps are not wired: nothing reads word times yet.
- **2026-09-24** — L1: **whisper.cpp v1.9.4 ships a native Parakeet library** (`parakeet.h`,
  `parakeet-cli`), which the survey of this plan did not know. L2 stays on sherpa-onnx as D11
  says, but compares the two before locking: one ggml build for both families would be simpler to
  ship than a second runtime.
- **2026-09-24** — L1: **The hook uses `hooks` and `code_assets` 1.x**, not 2.x: Flutter 3.44 pins
  `meta` below what `hooks` 2.2 needs. The constraints accept both, so a later Flutter moves up
  without an edit. The Flutter tool hands the hook Visual Studio's `cl.exe` and its environment
  script, and the hook takes clang from the same Visual Studio; `dart test` hands it nothing on
  Windows, so the hook then finds Visual Studio itself.
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
