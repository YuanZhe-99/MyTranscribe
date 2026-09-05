# MyTranscribe!!!!! — plan

The phased roadmap. `AGENTS.md` says how to work here; `doc/en-us/` says what the code does. This
file says what is built, what is next, and why the order is what it is.

## What this app is

Three Python scripts did the job before this app existed: pick a recording, split it into
overlapping windows with FFmpeg when it is too big to upload whole, send each window to a
transcription API, resume from a progress file when a run is interrupted, remove the words the
overlap duplicated, and write a Markdown and a plain-text transcript. This app is that, with a
window, on four platforms, plus the parts a script could not reasonably have: a library of sources
and models with their limits, a transcript you can read and correct, speakers you can name, and
configuration that follows you to another device.

## Decisions already made

| Decision | Choice | Why |
|---|---|---|
| Shell tabs | Transcribe, Library, Settings | Three things: the recordings, the services, everything else. Starting a job and reading a transcript are full-window routes, not tabs. |
| Theme | `FlexScheme.tealM3` | Distinct from MyAnime deep purple, MyDay indigo, MyDevice blue, MyNihongo sakura. |
| Media pipeline | Normalize the whole recording once to mono 16 kHz 64 kbps MP3, then cut windows with `-c:a copy` | One decode instead of one per window; chunk sizes become predictable at 8000 bytes a second; the normalized file doubles as the transcript's listening copy. |
| FFmpeg | Linked in on Android, iOS and macOS; external executables on Windows | The maintained plugin publishes x86_64 Windows binaries only, and this project's development machine is Windows on ARM64. |
| Sync scope | Configuration only | Recordings and transcripts are large and private; only config backup was asked for. |
| API keys | Local file outside the module registry; synced only to a secure endpoint | Sync, backup and ZIP only touch registry files, so exclusion is structural. |
| Remotes | Gitea only, no CI | One remote, no hosted runner; `flutter analyze` and `flutter test` are the gate. |

## Milestones

### M0 — Scaffold and conventions ✅

- [x] `flutter create` for Android, iOS, Windows, macOS; identifiers `com.yuanzhe.my_transcribe` /
      `com.yuanzhe.myTranscribe` / `com.yuanzhe.mytranscribe`
- [x] Git repository, `main`, local identity, `origin` on Gitea, `myapps_data` submodule pinned to
      `v1.0.2` with the masked relative URL
- [x] Root convention files: `AGENTS.md`, `analysis_options.yaml`, `l10n.yaml`, `.gitattributes`,
      `.gitignore`, `LICENSE`, `tool/generate_ios_icons.dart`
- [x] Theme, router, app shell with three tabs, locale resolution, ARB catalogs in en / zh / zh_TW
- [x] Layout policy module: the series core verbatim plus this app's own pane rules
- [x] Storage hub, settings document model, data module, the four shared-service facades
- [x] WebDAV config, backup, licence and privacy pages
- [x] Platform deltas: Gradle (AGP 9.1.1, Kotlin 2.2.20, Java 17, `builtInKotlin=false`), manifest
      permissions and `configChanges`, iOS Files keys and ATS, macOS entitlements, Windows names
- [x] Tests: adaptive layout, ARB mirror, data modules, settings merge, shell navigation, smoke
- [x] `flutter analyze` clean, `flutter test` green, Windows ARM64 debug build runs

### M1 — Media toolkit ✅

- [x] `MediaToolkit` interface: probe, normalize, extract a window, cut a sample; progress and
      cancellation
- [x] External-binary backend for Windows: `Process`, `-progress pipe:1` parsing, `ffprobe` JSON
- [x] Binary discovery: user override → app support → app dir → working dir → `PATH`
- [x] Windows download helper for a published FFmpeg build, arch-aware
- [x] Settings rows for tool status, a manual path, and the download
- [x] Vendored `ffmpeg_kit_flutter_new_audio` trimmed to Android, iOS and macOS, and the embedded
      backend; the vendoring and how to redo it are in the package's `VENDORED.md`
- [x] Windows ARM64 probes, normalizes, splits and cuts a real recording, verified by
      `test/media_toolkit_live_test.dart` against a downloaded FFmpeg
- [x] **Done**: the same six behaviours verified on a Pixel 10 through the linked-in libraries,
      by `integration_test/media_toolkit_test.dart`. Both backends produce a normalized file
      within 15% of the planner's 8000 bytes a second, which is the number the two have to agree
      on. `flutter build windows` still succeeds on ARM64 with the plugin in the tree

### M2 — Sources, models and keys ✅

- [x] `ProviderConfig` and `ModelConfig` over the settings record payload, with capabilities as a
      three-state answer so "not verified" can be said out loud
- [x] Built-in templates for OpenAI and OpenRouter with derived ids, and starter presets for a local
      server, Groq, Mistral and a blank compatible endpoint
- [x] Template refresh: a newer build's values reach every field the user has not overridden, and
      leave the ones they have
- [x] Library tab: grouped list, two-pane editor for both sources and models, override markers,
      reset to the built-in values
- [x] Secrets store and the key field: a stored key is never displayed, clearing writes a tombstone,
      and `test/settings_storage_test.dart` proves no key reaches the settings file
- [x] **Done**: two fresh devices seed byte-identical documents, so the first sync merges instead of
      duplicating (`test/settings_repository_test.dart`)
- [x] Adding a source from a starter preset, and importing models from a provider's own model
      list — capabilities come from a matching template or stay unknown, never from a guess

### M3 — Transcription jobs ✅

- [x] Dialect layer: OpenAI multipart, OpenRouter multipart and JSON, generic compatible
- [x] Chunk planner, with the reasons for its choice carried through to the page that shows them
- [x] Job runner: the stage machine, per-window persistence, resume, cancel, retry policy, wakelock
- [x] Overlap merge, both the token rule and the timestamp cut point, with a CJK-aware tokeniser
      the original scripts did not have
- [x] Transcribe tab, new-job page with a plan preview, job detail, Markdown and text output
- [x] **Done**: `test/job_runner_test.dart` proves the whole machine against a fake toolkit and a
      fake server — chunking, a failure at one window followed by a resume that reuses the rest, a
      settings change that discards the cache, cancellation, and each failure a user can meet. It
      found two real defects on the way: a failed job was written back from its initial record, and
      an atomic write could lose a job to a momentary Windows file lock
- [ ] Still to verify with a key: a real recording over the upload limit, end to end, against
      OpenAI and OpenRouter. Nothing else in M3 depends on it

Whether speaker labels are offered comes from the model's three-state capability, read directly by
the new-job page. The rest of what this plan first called a diarization policy — JSON mode,
enrollment, dropping the prompt for the diarizing model — belongs with M5 and is written there.

### M4 — Transcript viewer ✅

- [x] Transcript model and store, search, exports (TXT, Markdown, SRT, VTT, JSON, CSV)
- [x] Viewer: transcript and segment modes, grouping, timestamps, text size, editing, speaker
      naming
- [x] Audio player bar, seek from a line, current-line highlight, following playback
- [x] **Done**: `test/viewer_layout_ui_test.dart` pumps the viewer at all six geometries, and
      `test/export_formatters_test.dart` checks every format against what reads it

Two things this milestone settled. Subtitle exports are offered only for a transcript whose model
returned real times: a subtitle file a minute out looks like it works, which is worse than not
having one, so SRT and VTT are shown disabled with the reason. And the viewer takes its data from
providers rather than reading files itself — a widget test runs in a zone where `dart:io` futures
never complete, so a page that awaited one in `initState` could not be pumped at all.

Speaker merging, splitting and cross-window matching are M5; the panel names only what it can
honestly do today.

### M5 — Speakers

- [ ] Diarized response paths, OpenRouter JSON mode with provider options
- [ ] Cross-window speaker unification by overlap voting
- [ ] Speaker enrollment chaining where the API supports known speakers
- [ ] Speakers panel: rename, colour, merge, split, reassign, re-run unification
- [ ] **Done when** a two-speaker recording spanning three windows comes back with two speakers

### M6 — Sync and secrets

- [ ] Secure-endpoint policy and its test vectors
- [ ] Secrets exchange over WebDAV with conditional PUT
- [ ] WebDAV page: the verdict banner, the key row, the trusted-host editor
- [ ] **Done when** keys reach a second device over HTTPS and over a Tailscale address, and stay
      local over plain HTTP to a public host

### M7 — Release preparation

- [ ] `doc/zh-cn` complete, `functions/INDEX.md` measured
- [ ] App icon pipeline, `installer.iss`, MSIX metadata
- [ ] Version locations aligned, `v0.1.0` tagged and pushed after the user confirms

## Decisions log

Recorded when a choice is made that later work should not quietly reverse.

- **2026-09-05** — The settings merge compares a record's `id`, `kind` and `payload`, not its
  timestamps, when deciding whether two edits are really the same. Two devices that renamed a source
  to the same thing a minute apart would otherwise be asked to choose between identical
  configurations.
- **2026-09-05** — Recordings and transcripts are not a data module and will not become one without
  a deliberate decision: it would put hours of private audio into every backup bundle and every ZIP
  export.
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
