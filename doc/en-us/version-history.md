# Version history

Newest first. Each entry says what changed and, where it matters, why — the reasoning is the part
that is hard to recover later.

## 0.1.0 — unreleased

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
