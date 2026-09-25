# MyTranscribe!!!!! Documentation (Concepts)

**MyTranscribe!!!!!** (five exclamation marks in every user-facing name — app title, launcher label,
installer metadata and bundle names) turns a recording into text using a transcription service the
user configures. It splits a recording too large to upload in one piece into overlapping windows
with FFmpeg, resumes an interrupted run, joins the pieces back into one transcript, names who spoke
where the model supports it, and syncs its configuration through the shared `myapps_data` engines.

- **Author / package id:** `yuanzhe`, `com.yuanzhe.my_transcribe`
- **License:** GPL-3.0
- **Platforms:** Android, Windows, iOS, macOS (Linux and Web are not targeted)
- **Framework:** Flutter, Dart SDK `^3.11.3`; developed against Flutter `3.44.2`

This tree holds **concept** documentation — architecture, data formats, layout rules and per-feature
behavior — written for humans and agents who need to understand *why* the app behaves the way it
does. Function-by-function API documentation lives separately under [`functions/`](functions/) and
translation notes live in [`translation-guide.md`](translation-guide.md).

**These docs are the authoritative description of the code.** The repository's `AGENTS.md` is
deliberately limited to instructions for agents — workflow, authoring rules, the behavior contract,
and the release process — and points here for everything else. When code changes, these pages are
updated first; when docs and code disagree, verify against the code and then fix the page.

The shared WebDAV sync, backup, and ZIP engines are not in this repository. They live in the
`myapps_data` package embedded at `packages/myapps_data`, documented at
`packages/myapps_data/doc/en-us/`.

## Contents

### Core concepts

- [`architecture.md`](architecture.md) — app shell, state management, navigation, l10n, repository
  layout, and the core architectural rules the whole codebase follows.
- [`data-formats.md`](data-formats.md) — every file the app writes, what syncs and what does not,
  and the shape of each one.
- [`adaptive-layout.md`](adaptive-layout.md) — when a layout may split, where navigation lives, how
  many columns fit, and which rule each page uses.
- [`sync.md`](sync.md) — how the shared WebDAV engine is configured here: the one data module, its
  merge, how conflicts reach the user, and the separate API-key exchange.
- [`backup-restore.md`](backup-restore.md) — local backups and ZIP export/import as configured here.
- [`platform-notes.md`](platform-notes.md) — FFmpeg per platform, Android build state, Apple
  entitlements, Windows on ARM64, where downloaded models live.
- [`local-asr-support-matrix.md`](local-asr-support-matrix.md) — which local model runs on which
  processor of which device, how well each route is documented, and what this project has tested.
- [`ci-cd.md`](ci-cd.md) — the verification command set, build commands, and fresh-clone steps.
- [`version-history.md`](version-history.md) — release-by-release summary.

### Feature areas

- [`features/transcription-jobs.md`](features/transcription-jobs.md) — what a job is, its stages,
  and how it resumes.
- [`features/chunking-and-resume.md`](features/chunking-and-resume.md) — why a long recording is
  split, and what an interrupted run costs.
- [`features/provider-library.md`](features/provider-library.md) — sources, models and their
  capability fields.
- [`features/transcript-viewer.md`](features/transcript-viewer.md) — reading, correcting and
  exporting a transcript.
- [`features/exports.md`](features/exports.md) — the six formats a transcript can leave in, and
  which ones a given transcript may use.
- [`features/diarization-and-speakers.md`](features/diarization-and-speakers.md) — who spoke, and
  how the answer is kept consistent across windows.
- [`features/local-models.md`](features/local-models.md) — models that run on the device: the
  record, downloading a package, routes, the check on each device, fallbacks, what a job records.
- [`features/media-tools.md`](features/media-tools.md) — how the app finds or fetches FFmpeg.
- [`features/secure-secrets-sync.md`](features/secure-secrets-sync.md) — where API keys live and
  when they are allowed to travel.
- [`features/sync-and-backup.md`](features/sync-and-backup.md) — the screens under Settings › Data.

### Algorithms

- [`algorithms/chunk-planner.md`](algorithms/chunk-planner.md) — how a recording is divided.
- [`algorithms/overlap-merge.md`](algorithms/overlap-merge.md) — how the pieces are joined back up.
- [`algorithms/speaker-unification.md`](algorithms/speaker-unification.md) — how a speaker keeps one
  identity across windows.
- [`algorithms/secure-endpoint.md`](algorithms/secure-endpoint.md) — what counts as a safe place to
  send an API key.
- [`algorithms/engine-routing.md`](algorithms/engine-routing.md) — which processor a local model
  runs on, and what happens when it cannot.

### Reference

- [`functions/INDEX.md`](functions/INDEX.md) — one page per source file.
- [`translation-guide.md`](translation-guide.md) — English to Chinese terminology.

## Status

Milestones M0 to M6 are complete: the shell and conventions, the media toolkit on both backends, the
source and model library, the transcription engine with its planner and resume, the transcript
viewer with its exports, speaker matching across windows, and the API-key exchange with its
endpoint rule.

What remains is release preparation, and one thing that cannot be checked without a paid key: a real
recording over the upload limit, transcribed end to end against OpenAI and OpenRouter. Everything
else is verified by the test suite, which runs with no key, no network and no FFmpeg. See
`PLAN.md` at the repository root.

The local-models plan in `PLAN.md` is under way. Its foundation (L0) is in place: the local model
record, the package manager, the engine protocol and router, the device-local engine state and the
job runner's local path, all tested with a fake engine. No native engine is compiled in yet; the
first, whisper.cpp, is L1.
