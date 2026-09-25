# AGENTS.md

Operating guide for agents working on **MyTranscribe!!!!!**. This file holds **only** rules about
how to work here. Everything describing what the code *is* or *does* lives in `doc/en-us/` — see
[Where to read what](#where-to-read-what). The phased roadmap lives in `PLAN.md`.

MyTranscribe!!!!! turns a recording into text (Flutter; Android, Windows, iOS and macOS). It sends
audio to a transcription service the user configures — OpenAI, OpenRouter, or any OpenAI-compatible
endpoint including one they run themselves — splitting a long recording into overlapping windows
with FFmpeg, resuming an interrupted run, joining the pieces back into one transcript, and naming
who spoke where the model supports it. Treat the user's message as the change request: plan,
implement, verify, report.

## Reading order

When you need to understand code, read in this order and stop as soon as you have what you need:

1. **`doc/en-us/`** — start here, always. `architecture.md` for shape and rules;
   `functions/<mirrored path>.md` for a specific file's declarations; `functions/INDEX.md` to find
   the right page; the concept docs for behavior.
2. **Comments in the source** — the Function Explanation Layer above each declaration.
3. **The implementation** — only when the docs and comments are insufficient, or when you must
   confirm actual behavior before changing it.

Do not jump straight to reading source bodies. Where docs and code disagree on something you are
about to change, verify against the code, then fix the docs in the same commit.

## Where to read what

| Question | Read |
|---|---|
| What is planned, in what order, and what is done | `PLAN.md` |
| App shell, repository layout, core rules, shared package | `doc/en-us/architecture.md` |
| What a file or function does | `doc/en-us/functions/<mirrored path>.md` |
| Which page covers which source file | `doc/en-us/functions/INDEX.md` |
| WebDAV sync flow, lock, conflicts, as they apply here | `doc/en-us/sync.md` |
| How API keys are stored, and when they are allowed to sync | `doc/en-us/features/secure-secrets-sync.md` |
| Backup, restore, ZIP transfer | `doc/en-us/backup-restore.md` |
| Files on disk, what syncs, `storage_config.json` keys | `doc/en-us/data-formats.md` |
| Per-feature behavior | `doc/en-us/features/*.md` |
| Local models: records, packages, routes, which devices are tested | `doc/en-us/features/local-models.md`, `doc/en-us/algorithms/engine-routing.md`, `doc/en-us/local-asr-support-matrix.md` |
| A named algorithm, derived rather than described | `doc/en-us/algorithms/*.md` |
| When the UI splits into panes or columns; foldable rules | `doc/en-us/adaptive-layout.md` |
| FFmpeg per platform, Gradle/AGP state, Apple entitlements | `doc/en-us/platform-notes.md` |
| Build and verification commands, fresh-clone steps | `doc/en-us/ci-cd.md` |
| Why a behavior exists; past releases | `doc/en-us/version-history.md` |
| English→Chinese terminology | `doc/en-us/translation-guide.md` |

The shared sync/backup/ZIP engines are **not in this repo** — they live in `myapps_data`, embedded
at `packages/myapps_data`. Their documentation is at `packages/myapps_data/doc/en-us/`.

## Required workflow

1. Treat the user's message as the modification request.
2. Before editing, fetch the remote and check whether the local branch is behind. Resolve any
   divergence before starting.
3. Read per [Reading order](#reading-order).
4. Plan when the work is non-trivial, then implement it in this workspace. When a `PLAN.md`
   milestone is affected, update its checklist in the same change.
5. Keep changes scoped. Do not revert unrelated work in the tree.
6. Update documentation in the same change set — see [Documentation maintenance](#documentation-maintenance).
7. Verify with the narrowest meaningful checks, usually `flutter analyze` plus the relevant
   `flutter test` targets.
8. Report briefly, in English and Chinese: what changed, what was verified, the current/pre-change
   version, the configured remotes, and anything that could not be done.
9. For normal code changes, ask whether to push. The user must confirm the release version before a
   release push.

**If the request does not fit this app, say so instead of implementing it.** On-device
transcription with a downloaded model is this app's own feature (`PLAN.md`); any other on-device
AI, learning content, and media playback beyond a transcript's own audio are not, and a request
that assumes one of those was probably meant for a sibling app. Ask before building it.

## Documentation maintenance

**Docs are the primary artifact. Update them first, and never let them drift.**

Any change that adds, removes, or changes the behavior or signature of a function, a data format, a
sync rule, or a feature must update, in the same commit:

- the per-file page under `doc/en-us/functions/` and its `INDEX.md` row,
- every affected concept doc (`architecture.md`, `data-formats.md`, `sync.md`, `backup-restore.md`,
  `features/*.md`, `algorithms/*.md`, `adaptive-layout.md`, `platform-notes.md`, `ci-cd.md`).

Every language directory under `doc/` (currently `en-us` and `zh-cn`) mirrors the others exactly —
same files, headings, tables, and examples. `doc/en-us/` is authoritative: any documentation change
updates **all** language directories in the same commit, translated per `translation-guide.md`.
Adding a new language means creating a complete mirror of `doc/en-us/` in the same change. New
terminology goes into the glossary in `translation-guide.md`: cross-cutting terms into Section 5.1
in **every** sibling repo (MyAnime, MyDay, MyDevice, MyNihongo, MyApps-DATA), app-specific terms
into this repo's Section 5.2 only.

**Put explanation in the docs, not here.** This file is for agent instructions only. If you are
about to add a paragraph describing how the code works, it belongs in `doc/en-us/`. Only add to this
file when the rule is about how an agent should behave.

`test/doc_mirror_test.dart` enforces this: the same pages on both sides, the same heading structure
in each, every cross-link resolving, and `functions/INDEX.md` covering the whole of `lib/`. A page
added in one language and not the other fails the suite rather than drifting quietly.

Add a `doc/en-us/version-history.md` entry for each release. Documentation-only commits do not bump
versions or create tags.

## Authoring rules

**Function Explanation Layer.** Every function, method, significant callback helper, constructor,
getter, and setter carries a structured comment immediately above it:

- `Purpose: <one short sentence describing what the declaration is responsible for>`
- `Inputs: <important parameters only; omit obvious ones if trivial>`
- `Returns: <what the caller receives, or None>`
- `Side effects: <state changes, file/network/database/UI effects, logging, mutation, or None>`
- `Notes: <important assumptions, edge cases, invariants, or when the declaration should be used;
  prefer None when there is nothing special to add>`

Keep each explanation concise. Add one when adding a declaration, and update it in the same change
when editing an existing one. Use `///` doc comments in Dart, and matching doc comments in other
languages. Keep tracked generated localization files (`lib/l10n/app_localizations*.dart`) aligned by
running `flutter gen-l10n` whenever an ARB file changes, and commit the result.

These comments are the second layer of the [Reading order](#reading-order), so they have to stay
accurate: an agent that trusts a stale comment will make a wrong change. Still verify important
behavior in the implementation before relying on a comment for anything load-bearing.

Other conventions:

- **UTC timestamps** for anything compared across devices (`modifiedAt`, `createdAt`, a job's
  `finishedAt`). Local-time values break sync conflict detection.
- **Pretty-printed JSON** via `JsonEncoder.withIndent('  ')` for anything written to disk — sync
  relies on it so an unchanged file hits the raw-equality fast path.
- **Preserve unknown JSON fields** with the `extraJson` pattern, so an older build never deletes a
  newer build's data.
- **File I/O goes through `TranscribeStorage.getAppDir()`** so custom storage paths keep working,
  and **settings writes go through `TranscribeStorage.saveSettings()`** so auto-sync learns about
  them.
- **Layout numbers live in `lib/shared/utils/adaptive_layout.dart`.** A numeric width comparison
  inside a widget file is a bug; add a named constant with a doc comment saying where the number
  came from, and call a named predicate. Grep the whole tree before claiming none remain:
  `grep -rnE "maxWidth *[<>]=? *[0-9]|size\.width *[<>]=? *[0-9]" lib/`.
- **`lib/shared/utils/platform_capabilities.dart` is the only file that branches on the platform**,
  and it reads `defaultTargetPlatform` rather than `dart:io`'s `Platform`, so a widget test can
  drive any branch. A `Platform.isX` anywhere else in `lib/` is a bug.
- **User-facing strings go through the ARB files** (`lib/l10n/app_en.arb` is the template;
  `app_zh.arb` and `app_zh_TW.arb` mirror it key for key, and `test/l10n_arb_test.dart` fails when
  one of them does not). The two Chinese catalogs are **both hand-maintained**: Taiwan usage differs
  by vocabulary and not only by characters — 設定 not 設置, 檔案 not 文件, 轉寫 not 转写.
- **Settings copy is written for the person using the app.** One short line saying what a setting
  does for them. A file name, a protocol name or a number they cannot act on belongs in the docs,
  not in a subtitle.

## Behavior contract

Do not change these without the user explicitly deciding to:

- The **WebDAV wire format**, remote layout, and `.lock` semantics are a compatibility contract with
  every build in the field, shared with the sibling apps.
- Local formats — `webdav_config.json`, `.sync_base/`, `backups/` bundles — likewise.
- Conflicts are **never** silently auto-resolved; `autoResolve` stays false at every call site.
- Restore disables WebDAV auto-sync before the first write and re-enables it only if nothing was
  written.
- **The shared-service facades keep their public shape.** `WebDAVService`, `BackupService`,
  `ImportExportService`, and `AutoSyncService` are thin wrappers over `myapps_data`. If a change
  seems to require editing a facade's public API, stop — behavior changes belong in the package.
- `lib/app/data_modules.dart` is the single source of truth for data-file names, backup module keys,
  the remote path and the archive prefix. Never hardcode them elsewhere. The registry holds two
  modules — `transcribe_settings.json` then `transcribe_transcripts.json` — and a further one is
  appended, never inserted before them: the engines treat registry order as significant.
- **`transcribe_secrets.json` is never a data module, and job folders are never data modules.** The
  sync, backup and ZIP engines only touch the file names in the registry, which is what keeps API
  keys and recordings out of all three *structurally*. Adding either to the registry would silently
  start uploading them.
- **Transcriptions travel through the projection, not through the folders.**
  `transcribe_transcripts.json` carries the record and the transcript of each finished job; it is
  rebuilt from `jobs/` before a sync and applied back afterwards by `TranscriptSyncService`. Three
  rules in that file keep it from deleting somebody's recordings — a re-run is frozen rather than
  dropped, deletions come only from the three-way merge, and an unreadable record aborts the
  projection rather than leaving a gap in it. Do not relax one without reading why it is there.
- **Audio travels only through the opt-in side channel.** The converted `audio.mp3` goes to `audio/`
  beside the data files, and only when the device's own `syncIncludesAudio` is on; with it off, no
  request about audio is made at all. The original recording never travels.
- **API keys leave the device only to the service they belong to**, and to the user's WebDAV server
  only when the endpoint is secure — HTTPS, or plain HTTP to a private address. The rule lives in
  `secure_endpoint_policy.dart` and is stated in the privacy policy; changing what counts as secure
  changes a promise already made to the user.
- **Recordings stay on the device.** Audio goes to the configured transcription service and, when
  the user turns audio sync on, the converted copy goes to their own WebDAV server. Nothing is
  uploaded to a service the user did not configure.
- **Record ids are a compatibility contract.** A provider or model record is addressed by its id
  across devices; renaming a shipped template id orphans every device's overrides for it. Ids may be
  added; a shipped id is never changed.
- **Local models stay on the device, and are never swapped.** `models/` and
  `local_engine_state.json` are never data modules. Every local model id starts with `local:` —
  0.2.x writes an unknown record kind back as `unknown`, and the prefix is how the record is
  recognised again. The router only ever considers the chosen model's own packages; any move to
  another route is written on the job as a fallback, within the user's policy. Where a window ran
  is recorded from what the runtime reported, never inferred. A route not tested on this kind of
  device says so, and Auto picks it only as `doc/en-us/algorithms/engine-routing.md` allows.
- `android:configChanges` on the main activity keeps
  `screenLayout|screenSize|smallestScreenSize|density`, so folding does not recreate the activity.

## Working with the shared package

The submodule uses the **relative** URL `../MyApps-DATA.git`, so it resolves against whichever remote
this clone tracks. Never write a host name into `.gitmodules`.

Consume a newer shared version:

```bash
cd packages/myapps_data
git fetch origin --tags && git checkout vX.Y.Z
cd ../..
flutter analyze && flutter test
git add packages/myapps_data && git commit -m "Bump myapps_data to vX.Y.Z"
```

To change shared code: the submodule checks out detached, so `git switch main` inside it first, then
commit and **push before** committing the pointer bump here. A pointer to an unpushed commit breaks
every other clone. Pin to a **tagged** package commit before any app release.

**Native code is embedded as prebuilt binaries, never compiled in the app build** (decision D21 of
`PLAN.md`). whisper.cpp arrives through `packages/local_asr_whisper/native/binaries.json`, which pins
every archive by URL and SHA-256; never add a CMake step, a C file or a compiler to the app build or
to `build.yml`. Where upstream publishes no usable binary, add the target to
`.github/workflows/native-prebuild.yml`, run it, and pin its release asset. Never edit the generated
bindings or the vendored headers by hand. To move to a newer upstream version, change everything
together in one commit: the prebuild release, the manifest's URLs and hashes, the headers in
`third_party/`, the regenerated bindings (`dart run tool/ffigen.dart`), the layout check if the
defaults moved, and `_bindingsVersion` in `whisper_cpp_engine.dart`; then run the package test and
`test/local_asr_live_test.dart --dart-define=live_model=true`, pass the route check on this machine
again, and record the version in `doc/en-us/platform-notes.md`.

## Release, version, commit, tag, push

For ordinary feature/fix work, do not bump versions or tag until the user confirms the release
version and confirms pushing.

When the user confirms:

1. Update every version location:
   - `pubspec.yaml`: `version: X.Y.Z+N` (`N` increments for releases)
   - `pubspec.yaml` `msix_config.msix_version: X.Y.Z.0`
   - `installer.iss` `AppVersion=X.Y.Z`, `VersionInfoVersion=X.Y.Z.0`,
     `VersionInfoProductVersion=X.Y.Z` (the installer file names derive from `AppVersion`)
   - Never hand-edit the settings-page version display; it reads `PackageInfo.fromPlatform()`
2. Re-run verification.
3. Commit all intended changes, and add the `doc/en-us/version-history.md` entry.
4. Create an annotated tag `vX.Y.Z`.
5. Push **the commit first**, then the tag.

**This repo's branch is `main`** (MyDay and MyNihongo also use `main`; MyAnime and MyDevice use
`master`). Push `HEAD` or check `git branch --show-current` first, and verify with `git ls-remote`.

**CI runs on GitHub only.** `.github/workflows/build.yml` analyzes, tests and builds all five
targets on every push to `main`, every pull request, and on demand; a `v*` tag additionally creates
a Release from the artifacts. Gitea has no runner, so a push there is checked by nothing.

That does not move the gate. **Run `flutter analyze` and `flutter test` locally before every
commit** — CI is a second opinion on five platforms you do not have, not a substitute for the one
you do. A red build on GitHub after a green run locally almost always means a platform-specific
problem worth reading rather than a flake worth re-running. See `doc/en-us/ci-cd.md`.

## App icon

The icon pipeline is `assets/icon/app_icon.png` → `dart run tool/generate_ios_icons.dart` (iOS
default / dark / tinted sources) → `dart run flutter_launcher_icons` (Android mipmaps, iOS
`AppIcon.appiconset`, Windows and macOS icons). Never hand-edit generated icon files; change the
source and rerun both commands. `doc/en-us/platform-notes.md` describes the outputs.

## Agent co-author attribution

An agent that made a real, material contribution to a commit may add its own accurate
`Co-authored-by:` trailer. Attribution is per commit: do not add an agent merely because it reviewed,
observed, or continued another agent's work, and never copy a trailer automatically from an earlier
commit. When multiple agents materially contributed, include one accurate trailer each. Use the
agent's actual documented identity; never invent a provider, model, name, or email. Approved
examples are `Co-authored-by: Codex <noreply@openai.com>` and, for Claude Code,
`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>` with the model name replaced by the actual
model that did the work. For another agent, use its verified documented identity; if none is
verified, omit the AI trailer unless the repository owner approves one.

## Remotes and secrets

- `origin` → `<local_gitea_address>` (private Gitea) — the development remote
- `github` → `git@github.com:YuanZhe-99/MyTranscribe.git` (public) — the published mirror

Both carry the same `main` and the same tags. Push `origin` first, then `github`; a commit that has
not been through the local gate has no business being public.

Determine the repository path from the runtime workspace; do not hardcode a machine-specific absolute
path here.

**Masking rule:** keep the `origin` URL written as `<local_gitea_address>` in every committed file.
Never write the underlying Tailscale host or port anywhere in the repo, including `.gitmodules`. The
GitHub URL is public and is written out in full; the Gitea one never is. This matters more now than
it did: a private address in a committed file used to be visible to one person, and is now visible
to everyone. The same applies to the tailnet name itself — tests that need a Tailscale address use
`nas.tailnet-example.ts.net`, not a real one.

**The submodule URL stays relative.** `../MyApps-DATA.git` resolves against whichever remote the
clone came from, so a Gitea clone reaches the Gitea copy and a GitHub clone reaches
`github.com/YuanZhe-99/MyApps-DATA`. Both must therefore carry the tag this repository pins, and
today both carry `v1.0.2` at the same commit. Publishing a release that pins a tag which exists only
on Gitea would leave every public clone unable to run `flutter pub get`.

**Never commit:** secrets, API keys, credentials, WebDAV configuration, signing keys
(`key.properties`, `*.jks`), a user's recordings or transcripts, generated app data, or local-only
machine addresses.
