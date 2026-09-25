# Version history

Newest first. Each entry says what changed and, where it matters, why — the reasoning is the part
that is hard to recover later.

## 0.3.4 — 2026-09-25

The system's own speech recognition as a fallback, on Apple devices (L6 of the local-models plan).

- Settings › Local models › "If the chosen processor fails" gains a third choice on iPhone, iPad and
  Mac: the system's speech recognition. When a model on this device cannot run, the job carries on
  with it, and says so.
- It runs on the device only — the app requires on-device recognition, so the audio is not sent to
  Apple — and the app asks for permission to use speech recognition the first time it runs, never
  before you chose it. The privacy policy says the same.
- Not on Android: its recogniser would need code compiled into the app that this project keeps out.

## 0.3.3 — 2026-09-25

Parakeet on the Apple Neural Engine (L4 of the local-models plan).

- On iPhones, iPads and Macs, Parakeet can now run on the Neural Engine through FluidAudio, from a
  Core ML package of its own (483 MB). The app downloads it like any other package — file by file,
  checked against published hashes — and FluidAudio's own downloader stays off.
- **iOS 17 and macOS 14 (Sonoma) are now the minimum.** FluidAudio needs them. The iPhone 8,
  8 Plus and X, and Macs from before 2018 (the iMac before 2019, except the 2017 iMac Pro), stay on
  0.3.2.
- The route has not run on an Apple device here: it is built on GitHub's macOS machines and marked
  as untested, and like every route it runs its ten-second check on the device first.

## 0.3.2 — 2026-09-25

Local models on the GPU, where the device's own driver can take them (L3 of the local-models plan).

- Whisper and Parakeet now offer a route for each GPU the device has: Vulkan on Windows x64 PCs and
  on Android phones from Android 9, OpenCL on Qualcomm Adreno GPUs under Windows on ARM and Android,
  and Metal on Apple devices as before. A GPU route appears only when the device's own driver loads
  it, and runs only after its ten-second check on that device passed.
- None of these routes has been tested on real hardware here — the development machine's
  Snapdragon 8cx Gen 3 has no driver the GPU backends can use — so every one is marked as untested.
  Auto uses a Vulkan GPU on a Windows x64 PC when it passed its check and beat the CPU in it; the
  Adreno and Android routes run only when you choose them.
- The GPU backends make the app larger: about 55 MB more on Windows x64 and 45 MB on Android.

## 0.3.1 — 2026-09-25

Two more model families on the device: Parakeet TDT 0.6B v3 and Qwen3-ASR 0.6B (L2 of the
local-models plan).

**Parakeet, on the libraries already there**

- Parakeet runs on whisper.cpp's own Parakeet runtime, which ships beside Whisper in the same
  prebuilt libraries, so it adds no second runtime to the app — only a 638 MiB model when you
  download it. On the development machine it checks in at a third of real time on the CPU, where
  Whisper turbo took two and a half times real time. It writes 25 European languages and none of
  Chinese, Japanese or Korean, and a job in one of those is never sent to it.
- Its windows are two minutes long: the runtime reads a whole window at once, and shorter windows
  keep a phone's memory in hand. Sentences are cut from the times it gives every word.

**Qwen3-ASR, for everything Parakeet does not cover**

- Qwen3-ASR runs on sherpa-onnx, from sherpa-onnx's own prebuilt libraries, pinned by hash like
  whisper.cpp's. It takes a job's keywords as words to prefer. It gives no timestamps, so each
  30-second window becomes one line spanning it, marked as not really timed.
- Not on iOS yet: sherpa-onnx publishes no library for it, and the model says it cannot run there.
- A cancelled Qwen window finishes before the job stops: sherpa-onnx cannot stop one midway.

**Also**

- On a desktop, a local model now leaves two processor cores free: on the development machine, using
  every core made the model 60 % slower.

## 0.3.0 — 2026-09-25

The first release that can transcribe without a transcription service: Whisper large-v3 and
large-v3-turbo run on the device itself, with whisper.cpp, on every platform the app ships to. It is
the first two milestones of the local-models plan (`PLAN.md`, L0 and L1).

**This device**

- Library › This device lists the models the app can run locally. A download is fetched only when
  you tap it, resumes where it stopped, is checked file by file against its published hash and is
  installed in one step, so a half-downloaded model never appears as installed. Models stay on the
  device: they are never synced, backed up or exported, and on Android they are kept out of Auto
  Backup.
- After an install the app checks the model on this device with a ten-second public-domain clip
  before its first job, and records how fast it ran. A route that fails the check, or that crashed
  the app mid-run, is not used again automatically; the job carries on under the fallback policy in
  Settings, which by default is the same model on the CPU.
- A new job can choose "This device" as its source. It is cut into windows like any other job, the
  audio never leaves the device, and the job page says where each window actually ran.
- Settings › Local models › Diagnostics shows what the engine found — its version, the CPU
  features, the devices — and can copy a report without file names or text.

**Honest about what has been tested**

- Most devices this app runs on are not ones this project can test. A model on such a device is
  offered as untested and says so; Auto uses an accelerator there only under the rules in
  `engine-routing.md`, and the CPU is always the floor.
- On the Snapdragon development machine, turbo in full precision transcribed an 81-minute lecture
  on the CPU at 1.8 × real time — slower than real time. It is usable for a recording that can wait;
  a quantized package and the GPU routes of the next milestones are what make it fast.

**How it is built**

- whisper.cpp arrives as prebuilt libraries, pinned by hash: upstream's own for Windows x64 and the
  Apple platforms, and this project's build of the same version for Windows ARM64 and Android. The
  app build compiles no native code, which is what keeps every platform's build to a few minutes.
- The privacy policy gains a Downloads section: the app contacts a model host only for a download
  you asked for.

## 0.2.1 — 2026-09-09

What the first recording somebody actually kept found. A Microsoft meeting, three speakers, three
hundred lines, read and corrected and left overnight. Six things came out of it.

**A rename that would not stay**

- Renaming a speaker, going back and opening the transcript again showed "Speaker 1" once more. The
  write was correct all along; the provider holding the transcript was never refreshed, so every
  open after the first was served the copy read at the first one, for the rest of the session.
  There is a revision counter now — the same shape the job list already used — and the viewer keeps
  the last copy it read so that a refresh does not replace the page with a spinner and lose the
  scroll position. A newer copy arriving from sync replaces the one the page is holding.
- Two adjacent defects went with it. In a narrow window the speakers panel opens as a bottom sheet,
  which is built once and outlives the build that opened it, so a second rename in one sheet session
  was made against the transcript as it was before the first and undid it. And the rename dialog
  disposed its text field the moment it was dismissed, while the dialog was still animating away —
  which threw on the very next frame.

**Files the app wrote without being asked**

- A finished transcription used to leave a Markdown and a text file in whatever folder the recording
  happened to be in. That is not somewhere the app should assume it may write, and not somewhere the
  user necessarily still has. It is now a switch in Settings › Transcription, **off by default**.
  The transcript itself lives in the app's own folder either way.
- The detail page no longer lists those paths. It was showing file locations that may have been
  moved or emptied since.

**Naming people**

- Names you have given speakers before are remembered and offered in the rename dialog as chips that
  apply in one tap. The same handful of people turn up in recording after recording, and retyping
  them each time is the kind of friction that makes a feature go unused. The list syncs with the
  rest of the configuration, because the people in your recordings are the same people on either
  device, and Settings › Transcription › Speaker names manages it.
- **Unknown.** The speaker matching fails in two directions and only one of them had a repair. One
  person coming back as two is fixed by merging. A label that is not one person at all — a stretch
  of crosstalk, or a guess made on too little evidence — is now fixed by marking it unknown, which
  is more honest than folding it into somebody who is a person. Those lines read "Unknown" on screen
  and in all six export formats; a diarized Markdown export used to print a bare `**Speaker**` over
  them. Nothing does this automatically.

**Transcripts sync**

- The text of every finished transcription now travels to your own WebDAV server, is in every local
  backup and is in a ZIP export, so a transcription made on one device is readable on the other.
  Job folders are still not a data module: the small half of each one — the record and the
  transcript, never the audio — is projected into a file of its own before a sync and applied back
  afterwards, so hours of private audio still cannot end up in a bundle by accident.
- Deleting a transcription reaches your other devices at the next sync. A transcription being re-run
  does not: it is frozen in the projection rather than dropped from it, because otherwise its
  temporary absence would read as a deletion and the other device would delete the folder — audio
  included — while its owner watched the recording transcribe again. Force download, restoring a
  backup and importing a ZIP are additive: none of them has a base snapshot to tell "the server
  never had this" apart from "somebody deleted this".
- A transcription that arrived over sync has no recording on this device, so its page does not offer
  to run it again.

**Audio, if you want it**

- The converted listening copy can travel too, under "Also sync audio" on the sync page. It is
  **off by default and set per device**: a laptop with room to spare and a phone that is nearly full
  want different answers, and the transcripts sync either way. With the switch off, no request about
  audio is made at all. Original recordings never travel.
- Settings › Data › **Remove converted audio** frees every listening copy on the device at once and
  says how much that is. Every transcript stays, still readable and still syncing, and the next sync
  does not bring the audio back.

**Also**

- Transcript files are written with the same retry the job records have had since 0.1.0. An atomic
  replace is a rename, and on Windows a rename fails outright while anything else holds the file
  open.

## 0.2.0 — 2026-09-06

What the first real recording found. An eighty-one-minute lecture went through OpenRouter end to
end, with speakers, in eighty seconds. Every piece of the transcribing worked. Everything this
release fixes is what the app then did with the result.

**The page that never noticed**

- A job that finished while its own page was open went on saying "Waiting", with a Start button,
  until the app was restarted — beside a list that said Finished. The runner published an empty
  queue as it stopped and the page fell back to the record it had read while the job was waiting,
  because nothing ever re-read a job record except a page happening to refresh its list after a
  button was pressed. The runner now keeps the job it has just finished and counts every record it
  writes; the pages watch that count and take the most recently written copy of the three that can
  exist at once.
- That Start button was not harmless: pressing it rebuilds the transcript from the windows and
  throws away every correction made in the viewer. A finished job now offers **Run again** instead,
  and says what running again costs before doing it.

**The transcript itself**

- Nineteen seconds of speech were duplicated at all eight seams. The cut point that removes an
  overlap assumes a segment is short next to it; a model that answers in paragraphs returns
  segments several minutes long, so the segment on each side of the cut covered the whole shared
  stretch. How far the comparison looks is now derived from the overlap instead of fixed at forty
  tokens, and the repetition is followed as a chain of matching runs that steps over the scattered
  words two transcriptions of the same seconds disagree about. Seven of the eight seams come out
  clean; the eighth wrote "two vectors" against "2 vectors" and shares almost nothing exactly, so
  nothing is removed there, which is the rule the merge has always had.
- Five different people printed as one. The two files written beside the recording rendered each
  window's own speaker labels, so every window's `S1` read as the same person. They are rendered
  from the unified transcript now, through the same formatters the viewer's exports use.
- Speakers were numbered 1, 2, 3, 5, 6. The number came out of the id, and an id is allocated for
  every window label the matching places — including one whose only line then fell inside an
  overlap that was trimmed. The number shown is the speaker's position now. Ids are untouched:
  they name the sample files, and a source that accepts reference clips echoes them back.

**Room on the device**

- The detail page says how much a transcription is holding, and offers to give the converted copy
  of the recording back once the transcript exists — thirty-nine megabytes for that lecture, with
  no way to see it before and no way to remove it short of deleting the whole transcription. The
  transcript, the raw replies and the speaker samples all stay.
- Playback falls back to the original recording when there is no converted copy. A recording small
  enough to have been sent whole never had one, and the player bar used to say there was nothing to
  play with the file sitting right there.
- A window audio file another program was holding when a job finished stayed for good. Deletes are
  retried, and anything still left is swept away at the next start.

**Naming**

- A transcription can be given a name of its own, from the detail page or by holding its row. It is
  a label: the files beside the recording keep the recording's name, an export takes the new one.
  Renaming works while a job is running.

## 0.1.0 — 2026-09-05

The first release: a recording goes in, a transcript comes out, and the app knows how to divide a
recording too large to send whole, pick up where an interrupted run stopped, keep a speaker's
identity across the pieces, and refuse to send an API key anywhere it should not go.

**Transcribing**

- Sources and models as a library, with each model's real limits and a three-state answer for every
  capability, so "nobody has verified this" can be said out loud instead of guessed at.
- A planner that decides how to divide a recording and says why, before anything is uploaded. The
  original scripts made the user pass a chunk length and told them afterwards whether it worked.
- A job engine that records its state after every window, so closing the app mid-run costs at most
  the window that was in flight, and resuming reuses everything already paid for.
- FFmpeg linked in on Android, iOS and macOS; external executables on Windows, with a download
  helper, because the maintained plugin ships x86_64 Windows binaries only.

**Reading**

- A viewer with two modes: flowing paragraphs for reading, one row per line for correcting. Search,
  text size, speaker names and colours, an audio bar that seeks from a line and follows playback.
- Six export formats. Subtitles are offered only when the model returned real times — an SRT file a
  minute out of step looks like it works, which is worse than not having one.

**Speakers**

- Cross-window matching over the seconds two windows share, plus voice samples carried forward to
  sources that accept them.
- The thresholds refuse a doubtful match rather than guessing at it, and merging two speakers by
  hand is one tap. A wrong merge is a transcript that lies about who said what and nothing later
  reveals it; a missed one is an extra speaker in a list.

**Keys**

- API keys travel to a WebDAV server only over HTTPS, or over plain HTTP to an address that cannot
  leave the user's own network — a private range, a Tailscale or ZeroTier name, an mDNS name, or a
  host they trusted on that device. Everything else syncs regardless.
- A refused address makes no request at all, in either direction.

**Shell and conventions**

- Three tabs — Transcribe, Library, Settings — over a single `go_router` `ShellRoute`, with a
  navigation rail from 600 logical pixels and a bottom bar below that, built from one list of
  destinations so the two cannot drift.
- `FlexScheme.tealM3`, chosen to be distinguishable at a glance from the four sibling apps.
- Localization in English, Simplified Chinese and Traditional Chinese, with a test that fails when
  the catalogs drift apart, when a translation renames a placeholder, or when a Chinese catalog
  still holds the English text.
- The series' adaptive-layout policy module, copied core-for-core and extended with this app's own
  pane rules. Their derivation is in `adaptive-layout.md`.

**Data**

- One synced data module, `transcribe_settings.json`, holding sources, models and defaults as a flat
  list of records with opaque payloads — so a record written by a newer build merges correctly here
  even when this build cannot interpret it.
- The four shared-service facades over `myapps_data` v1.0.2, and the WebDAV, backup, licence and
  privacy pages.
- API keys and job folders are deliberately **not** data modules, which is what keeps them out of
  sync, backups and ZIP exports structurally rather than by a filter.

**Decisions worth remembering**

- The settings merge decides whether two edits are "the same" from a record's id, kind and payload,
  **not** its timestamps. Two devices that both renamed a source to the same thing a minute apart
  have not disagreed about anything, and the shared engine would otherwise raise a conflict between
  two identical configurations.
- Windows uses external FFmpeg executables rather than a plugin's bundled libraries, because the
  maintained plugin ships x86_64 Windows binaries only and this project is developed on Windows on
  ARM64. `platform-notes.md` records the whole arrangement.

**Defects found by the tests, not by a user**

- A job that failed or was cancelled part way was written back from the record it *started* with,
  erasing the plan and every finished window. The next run would have paid for them all again,
  which is the one thing resuming exists to prevent.
- An atomic write is a rename, and on Windows a rename fails outright while anything else holds the
  file open — the jobs list reading it, a virus scanner, the search indexer. A collision lasting a
  millisecond could kill an hour-long job. Reads and writes now retry.
- A bracketed public IPv6 address contains no dot, so it fell through to the rule that accepts a
  bare hostname as local, and would have been treated as a safe place to send a key.
