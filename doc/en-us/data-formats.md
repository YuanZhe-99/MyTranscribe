# Data formats

Every file the app writes, where it lives, and whether it travels.

## Inventory

All paths are relative to the app directory, which is `<documents>/MyTranscribe` unless the user set
a custom storage path. `storage_config.json` is the exception: it always lives in the platform
default directory, because it is the file that records the custom path.

| File | Contents | Synced | Backup / ZIP |
|---|---|---|---|
| `transcribe_settings.json` | sources, models, defaults | yes — the only data module | yes |
| `transcribe_secrets.json` | API keys, one per source | only to a secure endpoint, by a separate exchange | **no** |
| `storage_config.json` | device-local preferences | no | no |
| `webdav_config.json` | server URL, credentials, auto-sync flag | no | no |
| `.sync_base/` | the last agreed copy of each module, the client id, the local upload lock | no | no |
| `backups/` | bundles, and a content-addressed blob store | no | no |
| `jobs/<id>/` | one transcription job: audio, chunks, raw responses, transcript, exports | **no** | **no** |

The last three exclusions are structural. The sync, backup and ZIP engines only ever touch the file
names in the registry in `lib/app/data_modules.dart`, and that registry holds exactly one entry.

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
    { "id": "defaults", "kind": "defaults", "payload": { "...": "..." } }
  ]
}
```

The document is a **flat list of records** and every record carries an opaque `payload`. The sync
engine needs only an id and a timestamp per record, so keeping the typed shapes one layer above
means a record written by a newer build still merges correctly here even when this build cannot
interpret its payload. An unrecognised `kind` reads as `unknown` and is carried through untouched
rather than dropped.

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
| `ffmpegPath`, `ffprobePath` | the user's own tool paths |
| `secretsTrustedHosts` | hosts the user marked safe for keys over plain HTTP |
| `autoBackupEnabled`, `backupRetentionDays` | owned by the shared backup engine |

Everything here is device-local by design. A tool path that exists on a desktop names nothing on a
phone; a trusted host can resolve to a machine on this network here and something else entirely on
another device; and a window preference is a property of the device, not of the account.

## `jobs/<id>/` — one transcription

Planned for M3; recorded here so the shape is fixed before it is built.

| Entry | Contents |
|---|---|
| `job.json` | the job record: source, options, plan, per-chunk results, stage, error |
| `audio.mp3` | the normalized recording, mono 16 kHz 64 kbps — also the viewer's listening copy |
| `source.<ext>` | on mobile only, a copy of the picked file |
| `chunks/chunk_0000.mp3` | one window, deleted when the job finishes unless the user keeps them |
| `chunks/chunk_0000.response.json` | the provider's raw answer, kept — this is what makes a resume and a re-run of speaker unification possible without uploading again |
| `speakers/<id>.wav` | a short sample per speaker, where the API accepts known-speaker references |
| `transcript.json` | segments, speakers and the mapping between window-local labels and global speakers |
| `exports/` | rendered Markdown, text, subtitles and so on |

The job record is rewritten atomically after every chunk, which is what a resume reads. A chunk is
reused when its saved result matches the chunk file's size on disk, and the whole cache is discarded
when the plan fingerprint — source, model, window size, overlap, prompt, keywords — no longer
matches, because a result produced under different settings is not the result the user asked for.

## Atomicity

Every write goes through `atomicWriteString` from the shared package: write a temporary file beside
the destination, flush it, then rename. A crash mid-write leaves the previous file intact rather
than a half-written one. Pretty-printing with two-space indentation is not cosmetic — sync compares
raw strings before merging, so a file the engine wrote differently from the storage hub would look
changed on every sync and re-upload forever.
