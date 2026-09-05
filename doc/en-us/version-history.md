# Version history

Newest first. Each entry says what changed and, where it matters, why — the reasoning is the part
that is hard to recover later.

## 0.1.0 — unreleased

The first milestone: the app exists, builds on every target platform, and carries the series'
conventions. Nothing transcribes yet.

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
