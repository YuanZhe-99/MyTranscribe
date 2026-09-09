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
| Sync scope | Configuration and transcript text; audio opt-in; recordings never | The text is small and is the part worth having on both devices. Recordings are large and private, and the converted copy is large enough that a phone should be able to say no. |
| API keys | Local file outside the module registry; synced only to a secure endpoint | Sync, backup and ZIP only touch registry files, so exclusion is structural. |
| Remotes | Gitea for development, GitHub public | Gitea has no runner and is pushed first; GitHub runs the builds and carries the Releases. `flutter analyze` and `flutter test` locally remain the gate. |

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
Still to verify with a key: a real recording over the upload limit, end to end, against OpenAI and
OpenRouter. Nothing else in M3 depends on it, and it is carried to the end of this file rather than
left as an unticked box in a finished milestone.

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

### M5 — Speakers ✅

- [x] Diarized response paths, OpenRouter JSON mode with provider options
- [x] Cross-window speaker matching by overlap weight, refusing a doubtful join
      rather than guessing at it
- [x] Speaker enrollment chaining: a clip of each voice heard so far goes with the next window,
      and an id the source echoes back is taken as a voice match
- [x] Speakers panel: rename, colour, merge; reassigning one line is in the line editor
- [x] **Done**: `test/speaker_unifier_test.dart` holds the matching to fifteen cases including a
      three-window interview, swapped labels, Chinese audio and every way the evidence can be too
      weak; `test/job_runner_test.dart` proves the same end to end through the runner

The bias is deliberate and recorded here: a wrong merge is a transcript that lies about who said
what and nothing later reveals it, while a missed merge shows as an extra speaker the user joins in
one tap. So the thresholds refuse anything under 1.5 seconds of shared talking, or any match that
does not carry more than half of a label's overlap.

Splitting a speaker in two is not built. Reassigning a line does the same job one line at a time,
and until somebody meets a recording where that is not enough, the bulk operation is guesswork
about what they would want.

### M6 — Sync and secrets ✅

- [x] Secure-endpoint policy and its test vectors — 28 of them, on both sides of the rule
- [x] Secrets exchange over WebDAV with conditional PUT and a re-merge on 412
- [x] WebDAV page: the verdict banner as the address is typed, the key count, the trusted-host
      editor, and a sync message that says what became of the keys
- [x] **Done**: `test/secrets_sync_test.dart` shows keys reaching the server over HTTPS, over a
      LAN address, over a Tailscale name and over a trusted host, and staying put over plain HTTP
      to a public one — where **no request is made at all**, because reading a key over plain HTTP
      exposes it just as surely as writing one

Two findings worth keeping. A bracketed public IPv6 address fell through to the bare-hostname rule
and was accepted as local, because it contains no dot; addresses are now excluded from that rule
before it applies. And the trusted-host list is device-local rather than synced: trust is about the
network path this device takes to the server, so one device's decision must not start key uploads
on another.

### M7 — Release preparation ✅

- [x] `doc/zh-cn` complete — all 24 pages, translated rather than converted, with two new English
      pages written for the features that had none
- [x] `functions/INDEX.md` measured: 776 documented declarations across 81 files, every one listed
- [x] App icon pipeline, `installer.iss`, MSIX metadata
- [x] Version locations aligned: `pubspec.yaml` twice and `installer.iss` three times, all 0.1.0
- [x] `test/doc_mirror_test.dart` holds the mirror in place — the same pages, the same heading
      structure, every cross-link resolving, and the function index covering the tree. It caught a
      corrupted heading in the English data-formats page on its first run
- [x] Published to GitHub, with `.github/workflows/build.yml` building all five targets on every
      push and turning a `v*` tag into a Release
- [x] `v0.1.0` tagged and pushed to both remotes

### M8 — What the first real run found ✅

On 2026-09-06 an 81-minute lecture went through OpenRouter end to end, with speakers: nine windows,
all of them timed and labelled, eighty seconds of wall clock. Every piece worked. What the whole
thing did was another matter, and this milestone is the list.

- [x] **The page never noticed the job had finished.** The runner published an empty queue as it
      stopped, and the page fell back to the record it had read while the job was still waiting —
      so the pane said "Waiting" with a Start button until the app was restarted, beside a list
      that said Finished. Pressing that button would have rebuilt the transcript and thrown away
      every correction. The runner now keeps the job it has just finished and counts every record
      it writes; the providers watch that count and re-read
- [x] **A finished job offers Run again, never Start**, and asks first, saying what is lost
- [x] **Nineteen seconds duplicated at all eight seams.** The cut point assumes a segment is short
      next to the overlap; this model answers in paragraphs, so both sides of the cut carried the
      whole shared stretch. The seam search is now sized from the overlap rather than fixed at
      forty tokens, and the repetition is followed as a chain of runs that steps over the words two
      transcriptions of the same seconds disagree about. Seven of the eight seams come out clean
- [x] **Five people printed as one.** The files beside the recording rendered each window's own
      speaker labels, so every window's `S1` looked like the same person. They are rendered from
      the unified transcript now, through the viewer's own formatters
- [x] **Speakers numbered 1, 2, 3, 5, 6.** The number came out of the id, and ids have gaps. It is
      the speaker's position in the transcript now; ids are untouched, because they name the sample
      files and a source echoes them back
- [x] **The 39 MB listening copy was invisible and unremovable.** The detail page says what a
      transcription is holding and offers to give the converted audio back, keeping the transcript;
      playback falls back to the original recording, which also fixes a recording sent whole having
      nothing to play at all
- [x] **A window a locked file left behind stayed for good.** Deletes are retried, and a sweep at
      startup clears up after any that still failed
- [x] Renaming a transcription, which the user asked for while reading the first transcript
- [x] **Done**: `test/transcript_merger_test.dart` holds the seam rule to the shape the real
      recording produced, `test/jobs_two_pane_ui_test.dart` pumps the detail pane through the
      finish that used to be missed, and `test/job_runner_test.dart` covers the sweep, the
      listening copy and a rename that lands mid-run

Enrollment did not run, and that is correct: `microsoft/mai-transcribe-2` has no known-speaker
limit in its template and OpenRouter's JSON body has no field for a reference clip. The matching
worked on overlap alone.

### M9 — Six fixes from the first real recording ✅

The first recording somebody actually kept — a Microsoft meeting, three speakers, 301 lines — was
read, corrected and left overnight. Six things came out of that.

- [x] **A renamed speaker was back to "Speaker 1" on the next open.** The write was correct; the
      provider was never refreshed, so the second open was served the first read for the rest of
      the session. There is a revision counter now, the viewer caches the last copy it read so a
      refresh does not flash a spinner, and a newer copy arriving from sync replaces the one the
      page is holding. Two adjacent defects went with it: a second rename in one bottom-sheet
      session undid the first, and the rename dialog disposed its text controller while the dialog
      was still animating away
- [x] **The Markdown and text files beside the recording are now opt-in**, off by default, and the
      detail page no longer lists paths that may have been moved since
- [x] **Global speaker names.** The synced list existed in the model and had no call sites. Naming
      a speaker remembers the name; the next rename dialog offers it as a chip that applies in one
      tap; Settings › Transcription › Speaker names manages the list
- [x] **"Unknown".** The matching fails in two directions, and only one of them had a repair. A
      label that is not one person at all can now be marked unknown instead of being folded into
      somebody who is. Those lines read "Unknown" on screen and in all six export formats, which
      also fixed a diarized Markdown export printing a bare `**Speaker**`
- [x] **Transcripts sync.** A second data module, projected from `jobs/` before the engine runs and
      applied back afterwards, so job folders still are not modules and no audio travels with the
      text. Deleting a transcription reaches the other device; a re-run does not
- [x] **Audio is optional.** The converted copy travels through an app-level side channel, off by
      default and switched on per device, plus a bulk "remove converted audio" that keeps every
      transcript and stops sync from fetching the sound back
- [x] **Done**: `test/transcript_sync_test.dart` holds the three rules that keep the projection
      from deleting somebody's recordings, `test/transcripts_merge_test.dart` and
      `test/audio_sync_test.dart` cover the merge and the side channel, and
      `test/viewer_layout_ui_test.dart` has the rename regression that started all this

## What is not done, and why

The open item of the 0.1.0 plan is closed: an 81-minute lecture has now gone through OpenRouter end
to end. It was the most likely place for a surprise and it produced four, all of them in what the
app did with the result rather than in the transcribing itself. They are M8.

What is still open: nothing has been run against OpenAI, only OpenRouter, and no recording has been
transcribed on a phone with a real key. Splitting a speaker in bulk is still not built, for the
reason M5 gives.

## Decisions log

Recorded when a choice is made that later work should not quietly reverse.

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
