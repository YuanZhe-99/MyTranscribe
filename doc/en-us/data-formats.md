# Data formats

Every file the app writes, where it lives, and whether it travels.

## Inventory

All paths are relative to the app directory, which is `<documents>/MyTranscribe` unless the user set
a custom storage path. `storage_config.json` is the exception: it always lives in the platform
default directory, because it is the file that records the custom path.

| File | Contents | Synced | Backup / ZIP |
|---|---|---|---|
| `transcribe_settings.json` | sources, models, local models, defaults | yes — a data module | yes |
| `transcribe_transcripts.json` | every finished transcription's record and text | yes — a data module | yes |
| `transcribe_secrets.json` | API keys, one per source | only to a secure endpoint, by a separate exchange | **no** |
| `storage_config.json` | device-local preferences | no | no |
| `webdav_config.json` | server URL, credentials, auto-sync flag | no | no |
| `.sync_base/` | the last agreed copy of each module, the client id, the local upload lock | no | no |
| `backups/` | bundles, and a content-addressed blob store | no | no |
| `jobs/<id>/` | one transcription job: audio, chunks, raw responses, transcript, exports | **no** — but the record and the transcript are projected into the module above | **no**, likewise |
| `models/<artifactId>/` | one installed local model package and its `manifest.json` | **no** | **no** |
| `models/.downloads/` | partial downloads and the staging folders an install is assembled in | no | no |
| `local_engine_state.json` | this device's route checks, in-flight marker, route choices and fallback policy | no | no |

`models/` is under the app directory on Android and Windows. On iOS and macOS it is in the system's
caches directory instead, which iCloud backup and Time Machine leave out, and a desktop user may
point it anywhere with `modelsPath`. Either way it is never a data module.

The exclusions are structural. The sync, backup and ZIP engines only ever touch the file names in
the registry in `lib/app/data_modules.dart`, which is what keeps hours of audio and every API key
out of a bundle that goes to a server. The transcripts module is how the *text* of a transcription
travels anyway: it is a projection of the job folders, described below.

## `transcribe_settings.json` — the synced document

```jsonc
{
  "records": [
    {
      "id": "provider:openai",
      "kind": "provider",
      "createdAt": "2026-09-05T10:00:00.000Z",
      "modifiedAt": "2026-09-05T10:00:00.000Z",
      "payload": { "name": "OpenAI", "baseUrl": "https://api.openai.com/v1", "...": "..." }
    },
    { "id": "model:openai:gpt-transcribe", "kind": "model", "payload": { "...": "..." } },
    { "id": "local:whisper-large-v3-turbo", "kind": "localModel", "payload": { "...": "..." } },
    { "id": "defaults", "kind": "defaults", "payload": { "...": "..." } }
  ]
}
```

### What each payload holds

| Kind | Payload |
|---|---|
| `provider` | `name`, `dialect` (`openai`, `openrouter`, `openaiCompatible`), `baseUrl`, `authScheme` (`bearer`, `none`, `header`) and `authHeaderName`, `extraHeaders`, `maxFileBytes`, `maxRequestSeconds`, `requestTimeoutSeconds`, `defaultModelId`, `templateId`, `overriddenFields`, `templateVersion` |
| `model` | `providerId`, `modelName` (what goes on the wire), `displayName`, `maxFileBytes`, `maxDurationSeconds`, `diarization` / `wordTimestamps` / `segmentTimestamps` (each `supported`, `unsupported` or `unknown`), `supportsPrompt`, `supportsKeywords`, `languageParamStyle` (`languages`, `language`, `none`), `responseFormats`, `inputFormats`, `maxKnownSpeakers`, `requiresChunkingStrategy`, `templateId`, `overriddenFields`, `templateVersion` |
| `defaults` | `providerId`, `modelId`, `languages`, `prompt`, `keywords`, `diarize` (true, false, or absent for "whatever the model does best"), `plainOverlapSeconds`, `diarizedOverlapSeconds`, `enrollmentEnabled`, `knownSpeakerNames` |
| `localModel` | `displayName`, `family` (`whisper`, `parakeet`, `qwen`, `custom`), `languages` (empty: no restriction), `maxDurationSeconds`, `diarization` / `wordTimestamps` / `segmentTimestamps`, `supportsPrompt`, `supportsKeywords`, `artifacts` (package ids by adapter id), `templateId`, `overriddenFields`, `templateVersion` — nothing about any one device |

`overriddenFields` is what makes a template refresh safe: a later build's values reach every field
**not** named there, and leave the ones the user changed. `templateVersion` records which build's
values a record was last refreshed from.

A capability has **three** states, not two. "Not verified" is a real answer for an endpoint the user
configured themselves, and the app acts on it differently from "no": it offers the feature with a
warning rather than hiding it.

The document is a **flat list of records** and every record carries an opaque `payload`. The sync
engine needs only an id and a timestamp per record, so keeping the typed shapes one layer above
means a record written by a newer build still merges correctly here even when this build cannot
interpret its payload. An unrecognised `kind` reads as `unknown` and is carried through untouched
rather than dropped — including the kind string itself, which is written back exactly as it was
found. 0.2.x wrote the literal `unknown` in its place; a local model record that passed through such
a build therefore arrives as `kind: unknown`, and because every local model id starts with `local:`,
this build reads it as `localModel` again.

Timestamps are **UTC**. A local-time value read on a device in another zone would silently reorder
edits. Every edit goes through `SettingsRecord.touch`, which is the one way to set `modifiedAt`, so
no edit can forget to move it and then lose to an older remote copy.

Unknown top-level fields, on the document and on each record, are kept in an `extraJson` map and
written back out, so an older build never deletes a newer build's data. A missing or unreadable
timestamp falls back to the Unix epoch, never to "now" — "now" would make an untouched record look
newer than the remote copy on every read and win every merge.

Record ids are a compatibility contract: a record is addressed by its id across devices, and
template records use derived ids (`provider:openai`, `model:openai:gpt-transcribe`) so two fresh
devices seed the same ones and the first sync merges instead of producing duplicates.

Deletion is a real removal, not a tombstone. The shared merge engine reads deletions from the base
snapshot: a record present in the base and absent locally is a deletion this device made, and it
propagates.

## `transcribe_transcripts.json` — the transcripts projection

The second data module, and the only one nothing writes to directly. It is a **projection** of
`jobs/`: rebuilt from the job folders before a sync, a backup or a ZIP export, and applied back into
them afterwards. `jobs/` stays the source of truth; this file is a transport artefact.

```jsonc
{ "records": [ { "id": "<jobId>",
                 "createdAt": "2026-09-01T09:00:00.000Z",
                 "modifiedAt": "2026-09-09T11:30:00.000Z",
                 "job":        { /* the whole of job.json */ },
                 "transcript": { /* the whole of transcript.json */ } } ] }
```

Records are sorted by id and pretty-printed with two spaces, so two devices holding the same data
produce byte-identical files and hit the sync engine's raw-equality fast path. `modifiedAt` is the
later of the record's own time and the transcript's `editedAt`, because renaming a speaker does not
touch the record but is exactly the kind of change that has to travel.

`job` and `transcript` are the **raw maps**, carried through unparsed. The nested types inside a job
record — the options, the plan, each chunk result, the media probe — have no `extraJson` of their
own, so parsing a record written by a newer build and writing it back would drop whatever that build
added; the two devices would then take turns stripping each other's fields and re-uploading for
ever.

What is projected, and what applying one is allowed to do to the folders, is in
[`sync.md`](sync.md): only finished transcriptions are projected fresh, a job being re-run is frozen
rather than dropped, deletions come only from the three-way merge, and a record that cannot be read
stops the projection rather than leaving a gap in it.

## `transcribe_secrets.json` — the keys

```jsonc
{
  "version": 1,
  "keys": {
    "provider:openai": { "apiKey": "sk-...", "updatedAt": "2026-09-05T10:00:00.000Z" },
    "provider:removed": { "apiKey": null, "updatedAt": "2026-09-06T10:00:00.000Z" }
  }
}
```

Not a data module, on purpose. Keyed by the source's record id, so a key follows its source. An
`apiKey` of `null` is a tombstone: without one, deleting a key on one device would let the other
device's copy come back on the next exchange.

Merged per key by `updatedAt`, last writer wins. There is no three-way merge and no base snapshot,
which is why the exchange is safe to run outside the sync lock — see
[`features/secure-secrets-sync.md`](features/secure-secrets-sync.md).

## `storage_config.json` — device-local preferences

Read and written by the storage hub through typed accessors. **A default is stored as an absent
key**, so a later build that changes a default changes it for everyone who never touched the
setting. A value of the wrong type reads as unset, so a hand-edited file cannot crash the app.

| Key | Meaning |
|---|---|
| `storagePath` | custom app directory; absent means the platform default |
| `themeMode` | `light` or `dark`; absent follows the system |
| `locale` | `language` or `language_COUNTRY`; absent follows the system |
| `lastTab` | the tab to open on |
| `viewerFontSize`, `viewerShowTimestamps`, `viewerGroupSpeakers` | transcript viewer preferences |
| `keepChunkFiles` | keep a job's split audio after it finishes |
| `autoSaveTranscriptFiles` | write a Markdown and a text file beside the recording when a job finishes; off by default |
| `syncIncludesAudio` | also copy each transcription's converted audio to the server; off by default |
| `ffmpegPath`, `ffprobePath` | the user's own tool paths |
| `modelsPath` | where downloaded models live, when the user moved them; nothing is moved when it changes |
| `secretsTrustedHosts` | hosts the user marked safe for keys over plain HTTP |
| `autoBackupEnabled`, `backupRetentionDays` | owned by the shared backup engine |

Everything here is device-local by design. A tool path that exists on a desktop names nothing on a
phone; a trusted host can resolve to a machine on this network here and something else entirely on
another device; and a window preference is a property of the device, not of the account.

## `jobs/<id>/` — one transcription

Written by the job runner. Never synced, never backed up, never exported in a ZIP: hours of private
audio have no business in a bundle that goes to a server.

| Entry | Contents |
|---|---|
| `job.json` | the job record: source, the name the user gave it, options, plan, per-chunk results, stage, error; for a local model also `options.device`, `route`, `artifactRevision`, `fallbacks`, and each chunk's `placement` and `routeKey` |
| `audio.mp3` | the normalized recording, mono 16 kHz 64 kbps — also the viewer's listening copy, and removable from the detail page once the transcript has been read |
| `source.<ext>` | on mobile only, a copy of the picked file |
| `chunks/chunk_0000.mp3` | one window, deleted when the job finishes unless the user keeps them; one a locked file left behind is swept at the next start |
| `chunks/chunk_0000.wav` | a local model's window: 16 kHz mono 16-bit PCM, deleted like the MP3 windows |
| `chunks/chunk_0000.response.json` | the provider's raw answer, kept — this is what makes a resume and a re-run of speaker unification possible without uploading again |
| `speakers/<id>.wav` | a short sample per speaker, where the API accepts known-speaker references |
| `transcript.json` | segments, speakers, the mapping between window-local labels and global speakers, and the user's corrections |
| `audio.discarded` | a marker saying the converted audio was removed on purpose, so sync never fetches it back |
| `exports/` | rendered Markdown, text, subtitles and so on |

The job record is rewritten atomically after every chunk, which is what a resume reads. A chunk is
reused when its saved result matches the chunk file's size on disk, and the whole cache is discarded
when the plan fingerprint — source, model, window size, overlap, prompt, keywords — no longer
matches, because a result produced under different settings is not the result the user asked for.
A local job's fingerprint names the local model, the package revision and the device asked for
instead of the source.

## `models/<artifactId>/` — one installed package

Written by the artifact manager, never by hand. The folder holds the package's files and
`manifest.json`:

| Field | Meaning |
|---|---|
| `artifactId`, `modelId`, `adapterId` | the package, the local model it serves, the adapter that loads it |
| `format`, `quantization`, `revision` | `ggml`, `onnx`, `coreml` or `qnn`; e.g. `f16`, `q5_0`, `int8`; the upstream revision the URLs are pinned to |
| `files[]` | what was downloaded: `path`, `bytes`, `sha256`, `sourceUrl`, and optionally `platforms`, `unpack` (`zip`, `tarBz2`) and `unpackedBytes` |
| `installed[]` | what is on disk after unpacking: `path`, `bytes`, and the `sha256` measured on this device |
| `licenseId`, `licenseUrl`, `attribution` | the model's licence and the attribution it asks for |
| `minimumRamBytes`, `ramEstimateSource` | the memory a loaded session needs, and whether that figure is `measured`, `documented` or `unknown` |
| `installedAt` | when, in UTC |

A folder without a readable manifest counts as not installed. Partial downloads live in
`models/.downloads/<artifactId>/`, named after the file and the start of its hash, so a changed
manifest never resumes an old file's bytes.

## `local_engine_state.json` — this device's engines

Written by the engine state store, atomically, one read-modify-write at a time.

| Key | Meaning |
|---|---|
| `smokeTests` | each route's check on this device, keyed by adapter version, model hash, OS version, driver version, processor and precision joined with `\|`: `routeKey`, `outcome` (`notRun`, `passed`, `failed`, `crashed`), `text`, `similarity`, `realTimeFactor`, `reason`, `checkedAt` |
| `inFlight` | the native call running now, when there is one: `routeKey`, `smokeKey`, `jobId`, `startedAt`; a marker found at startup records that route as `crashed` |
| `routeChoices` | the route the user chose per local model id: `cpu` or a route key; absent means Auto |
| `fallbackPolicy` | `none` or `systemRecognizer`; absent means the default, the same model on the CPU |
| `allowServerSpeechRecognition` | whether the system recogniser may send audio to its vendor; absent means no |

## Atomicity

Every write goes through `atomicWriteString` from the shared package: write a temporary file beside
the destination, flush it, then rename. A crash mid-write leaves the previous file intact rather
than a half-written one. Pretty-printing with two-space indentation is not cosmetic — sync compares
raw strings before merging, so a file the engine wrote differently from the storage hub would look
changed on every sync and re-upload forever.

Job records and transcripts are also **retried**. An atomic replace is a rename, and on Windows a
rename fails outright while anything else holds the file open — a virus scanner, the search indexer,
the list reading it. The collision lasts milliseconds, and losing an hour-long job or a page of
corrections to it would be absurd, so `retryingFileOperation` makes six attempts over about a tenth
of a second before giving up.
