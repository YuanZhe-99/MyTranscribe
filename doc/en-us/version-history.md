# Version history

Newest first. Each entry says what changed and, where it matters, why — the reasoning is the part
that is hard to recover later.

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
