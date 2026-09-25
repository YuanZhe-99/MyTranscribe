# Local models

A local model transcribes the recording on the device: no key, no network once the model is on
disk, and the audio never leaves the device. This page describes what is built so far — the record,
the packages, the routes, the checks and the job — and says where a piece arrives in a later
milestone of `PLAN.md`.

**State at L1:** the first engine, whisper.cpp, is bundled into every build as pinned prebuilt
libraries and runs the Whisper models on the CPU everywhere, and on Metal on Apple platforms (see
[`platform-notes.md`](../platform-notes.md)). Parakeet and Qwen are listed in the library but have
no engine in this build until L2, so their page says the build cannot run them here. GPU routes
other than Metal arrive in L3.

## The record and the packages

A local model is a synced record of kind `localModel` in `transcribe_settings.json`, beside the
sources and models (see [`data-formats.md`](../data-formats.md)). It holds only what is true on
every device: a name, a family (`whisper`, `parakeet`, `qwen`, `custom`), the languages it
transcribes, a window ceiling, its capabilities, and the ids of the **packages** (artifacts) it may
use, by adapter. Whether a package is downloaded, where, and which processor runs it are facts about
one device and live in device-local files. A model added on the desktop therefore shows on the phone
as "not downloaded" rather than as a promise.

Every local model id starts with `local:` — `local:whisper-large-v3-turbo` for a built-in one,
`local:` and a uuid for one the user adds from a file. The prefix matters for older builds: 0.2.x
reads the unknown kind as `unknown` and writes it back as `unknown`, and the prefix is how this build
recognises such a record as a local model again (see [`sync.md`](../sync.md)).

One record, several packages. Whisper large-v3 turbo lists a GGML file for whisper.cpp; later
milestones add a Qualcomm package to the same record. The router picks the package; the user picks
the model. The router never picks another model — Turbo is not large-v3, and a job that asked for one
never silently runs the other.

### The built-in models

| Model | Family | Package | Download | Timestamps | Languages |
|---|---|---|---|---|---|
| Whisper large-v3 turbo | whisper | `whisper-large-v3-turbo-ggml` (f16; plus the Core ML encoder on Apple) | 1.5 GiB (+1.1 GiB on Apple) | segment, word | any |
| Whisper large-v3 turbo (q5_0) | whisper | `whisper-large-v3-turbo-q5_0-ggml` | 547 MiB | segment, word | any |
| Whisper large-v3 | whisper | `whisper-large-v3-ggml` (f16; plus the encoder on Apple) | 2.9 GiB (+1.1 GiB on Apple) | segment, word | any |
| Whisper large-v3 (q5_0) | whisper | `whisper-large-v3-q5_0-ggml` | 1.0 GiB | segment, word | any |
| Parakeet TDT 0.6B v3 | parakeet | `parakeet-tdt-0.6b-v3-int8-onnx` | 465 MiB archive | segment, word | 25 European languages; **no Chinese, Japanese or Korean** |
| Qwen3-ASR 0.6B | qwen | `qwen3-asr-0.6b-int8-onnx` | 838 MiB archive | none | any (the model detects) |

No local model labels speakers. Every built-in window ceiling is 600 seconds — an app ceiling chosen
for memory and visible progress, not a promise from the model.

The built-in models are seeded when the settings document has no local model at all — a fresh
install, or the first start after upgrading — with derived ids, so two devices seed identical records
and the first sync merges them. Templates refresh like the source templates: a field the user never
changed follows the newer template.

## Downloading a package

A package's manifest lists every file with its exact size, its SHA-256 and the one URL it may come
from, pinned to a revision: a Hugging Face commit for the Whisper files, a GitHub release asset for
the sherpa-onnx archives. The hashes are the ones the hosts publish — Hugging Face's LFS object id,
which is the SHA-256 of the file's bytes, and GitHub's asset digest — and the downloader checks every
file against them, so a host that replaced a file fails loudly instead of installing something else.
The app contacts a model host only when the user asks for a download, and only at the manifest's URL.

An install:

1. **Checks space**, counting the download, the unpacked archive and the install separately — an
   archive and its contents sit side by side until the archive is deleted. A partial download already
   on disk is not counted again. Where the platform gives no free-space figure, the write's own
   disk-full error is the check.
2. **Downloads each file**, resuming a partial one with an HTTP range request. A server that ignores
   the range and sends the whole file restarts it. A file whose size or hash is wrong is deleted, not
   resumed: a corrupt prefix would corrupt every later attempt.
3. **Unpacks** an archive (ZIP for the Core ML encoders, `tar.bz2` for sherpa-onnx) only after its own
   hash matched, and hashes every unpacked file on the device.
4. **Assembles** the package in a staging folder and **renames** it into `models/<artifactId>/` in
   one step, writing `manifest.json` with what was installed. A half-installed package never exists
   under its own name, and a failed update leaves the previous version in place.

A running job **leases** its package. While a lease is held, the package can be neither replaced nor
removed. A cancelled download keeps its partial file, so the next attempt resumes it. "Verify" hashes
the installed files again against the manifest.

On iOS and macOS the models live in the caches directory, which iCloud backup and Time Machine leave
out — a model is a re-downloadable cache. The system may purge that directory when space runs short;
the model then shows as not downloaded. On Android and Windows, models live under the app directory,
so a custom storage path carries them along. A desktop user can point models at another folder.

## Routes, evidence and "tested on this kind of device"

A **route** is one way this device could run one package: an adapter, a backend (`cpu`, `metal`,
`opencl`, `vulkan`, `coreml`, `qnn`) and the processor it drives (CPU, GPU or NPU). Adapters describe
the routes they could run for the packages installed here; the registry attaches this device's check
result to each.

Each route carries two separate facts:

- **Evidence** — how well the route is documented to work on this kind of device, the survey's
  grades: A (the vendor documents it), B (reproducible community results), E (only the generic
  backend is documented) and U (nothing found).
- **Tested here** — whether this project verified the route on hardware of this device's class. Most
  devices this app runs on cannot be tested by this project; their routes ship as **unverified
  support**, and the product says so in plain words.

The router's rules, including when Auto may use an untested route, are in
[`algorithms/engine-routing.md`](../algorithms/engine-routing.md). Which classes have been tested is
in [`local-asr-support-matrix.md`](../local-asr-support-matrix.md).

## The check on this device

Every route, tested or not, passes a **smoke test** on this device before its first job: a short clip
with known words, through the route, compared with those words, and timed. The result is filed under
a key of six parts — the adapter version, the model file's hash, the OS version, the driver version,
the processor and the precision — so an update to any of them asks for a new check. A route whose
check failed is not used here, and the reason is kept for the diagnostics page.

The check clip is bundled with the app: the opening of President Kennedy's 1961 inaugural address,
eleven seconds of public-domain speech, as whisper.cpp ships it for the same purpose. A route is
checked right after its package is installed ("checking this device"), again whenever its key
changes, and whenever the user asks from the model's page or the diagnostics page. The speed the
check measures is what Auto compares an untested accelerator against the CPU with.

## When the app stops inside a route

Before every native call — loading a model, running a window, a check — the app writes an
**in-flight marker** naming the route, and clears it when the call returns, whether it succeeded,
failed or was cancelled. A marker found at the next start means the process died inside that route.
The route is recorded as `crashed` on this device and is never picked automatically again under that
key. The interrupted job resumes under the fallback policy, and the change of route is written on the
job with the reason `ROUTE_CRASHED`, so a crash costs one window and never a crash loop.

## The fallback policy

When the route a job asked for cannot run, the device-local fallback policy decides what happens:

| Policy | What happens |
|---|---|
| `sameModelOnCpu` (default) | The same model runs on the CPU. |
| `none` | The job fails and says why. |
| `systemRecognizer` | The operating system's own recogniser (a later milestone), a different engine announced as such. |

A fallback is a visible event, never a substitution: the job records what it asked for, what ran,
from which window, and why. Only a route problem — a missing driver, a lost device, memory on an
accelerator, a crash — can be answered by the CPU; a damaged model or an unsupported language fails
the same way everywhere, so the job fails.

## What a job records

A local job records `local` as its source and the local model's id as its model. On top of the usual
fields it keeps:

- `options.device` — what the user asked to run on: `auto` (absent), `cpu`, or a route key;
- `route` — what was asked for and the route chosen at the start, with its evidence grade and
  whether it was tested on this kind of device;
- `artifactRevision` — the package revision loaded;
- `chunks[].placement` and `chunks[].routeKey` — where each window actually ran, as the runtime
  reported it (`cpu`, `gpu`, `npu`, `mixed`, or `unknown` — never a guess);
- `fallbacks` — every move away from the route asked for.

The plan fingerprint includes the package revision and the device asked for, so an updated package or
a request for another processor discards cached windows. A fallback does not change it: windows the
GPU finished before a fallback came from the same model and are kept. See
[`chunking-and-resume.md`](chunking-and-resume.md).

The failure kinds a local job adds are `modelNotInstalled`, `modelDamaged`, `unsupportedByModel`,
`engineUnavailable`, `outOfMemory` and `routeCrashed`, each with the engine's own words.

## The pages

- **Library › This device** lists the local models above the sources, each with its state here:
  not downloaded, downloading with its progress, checking this device, ready, or failed with the
  reason. A model's page shows its download size, languages, timestamps and licence; its
  **download** asks first, naming the size and the host it comes from; once installed it offers to
  **verify** the files against their hashes and to **remove** them. Below that, every route: what
  it runs on, whether it was tested on this kind of device, its evidence in words, and its check
  here with its speed, and a **check now** button.
- **New job** gains "This device" as a source. Choosing a local model shows a **Run on** chooser —
  Automatic, the CPU, and every accelerator route of this model that passed its check here, the
  untested ones saying so in their own label — the local plan preview, and the line "The audio
  stays on this device." A model that is not downloaded, or that does not transcribe the languages
  typed in, says so under the picker rather than disappearing.
- **Job detail** says where a local job's windows ran, as the runtime reported it — one placement,
  or the runs of windows that shared one — and shows every fallback as its own line.
- **Settings › Local models** holds the fallback policy and the **Diagnostics** page: this device's
  class, OS and processors; the engine's version, build flags and compute devices; every route
  with its grade, whether it was tested here, and its check; and **Copy report**.

The copied report names the device, the engine, and each route's model id, adapter, backend, grade,
tested-here flag, availability, check outcome and speed. It holds no file names, no paths and no
transcript text — a failed check contributes its outcome and not its reason, because a reason can
quote a path — and the app sends it nowhere.

## What unverified means to the user

A route this project has not tested on this kind of device is labelled as such wherever routes are
shown. It is built and covered by the tests, it passed its check on this device before its first job,
and it is used automatically only as [`engine-routing.md`](../algorithms/engine-routing.md) allows; an
experimental one runs only when the user chooses it. If it misbehaves on a long recording, the
in-flight marker, the fallback policy and the per-window record bound the damage to one window. The
diagnostics page copies a report of the device, the route, its check and its speed — no file
names and no text — that the user may send by hand; the app sends it nowhere.
