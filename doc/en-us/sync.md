# WebDAV sync

Sync is off until the user configures it, and it talks only to the server they entered. It carries
**configuration** — sources, models and defaults — and, when the endpoint is secure, their API keys.
Recordings and transcripts never sync.

The engine itself lives in the shared `myapps_data` package and is documented at
`packages/myapps_data/doc/en-us/`. This page describes how it is configured here.

## What is registered

One data module:

| Field | Value |
|---|---|
| File | `transcribe_settings.json` |
| Module id | `settings` |
| Remote path | `/MyTranscribe` |

`lib/app/data_modules.dart` is the only place those names appear. A second module would be appended
to the registry, never inserted before this one — the engine treats registry order as significant.

## How a sync goes

1. Acquire the remote `.lock`, so two devices cannot upload at once.
2. Download the remote settings file.
3. If it is absent, upload the local one as new. If the two raw strings are identical, save the base
   snapshot and stop — this is the fast path, and it is why the file's formatting must match what
   the storage hub writes.
4. Otherwise merge three ways: local, remote, and the base snapshot from the last agreed sync.
5. Write the merged file locally, upload it, save the new base snapshot, release the lock.

The base snapshot in `.sync_base/` is what makes a deletion propagate instead of resurrecting: a
record present in the base and absent locally was deleted here, rather than being new there.

## The merge

`lib/shared/services/sync_merge.dart` wraps the shared `mergeRecords` engine. Records are keyed by
id and compared by `modifiedAt`.

- Only one side changed → that side wins.
- Neither changed → local, unchanged.
- A record added on one side → kept.
- A record deleted on one side and untouched on the other → the deletion propagates.
- A record deleted on one side and edited on the other → the edit wins; a deliberate change beats an
  absence.
- Both sides changed → a **conflict**, unless the content is the same.

"The same content" compares a record's `id`, `kind` and `payload` — **not** its timestamps. Two
devices that both renamed a source to the same thing, a minute apart, have not disagreed about
anything, and asking the user to choose between two identical configurations would be noise.

Conflicts are **never** auto-resolved. `autoResolve` is false at every call site. The user is shown
one dialog per conflicting record, with both versions and their times, and dismissing any of them
aborts the whole resolution: nothing is uploaded, the conflict stays pending, and no record is
quietly kept. A conflict the user does answer is finalized under a freshly acquired lock.

Whichever version wins still absorbs the other's unknown fields, so losing a conflict never deletes
a field a newer build wrote.

## Force upload and force download

Both skip the merge. Force upload replaces the remote with the local file and loses remote changes
since the last sync; force download does the reverse. Both run under the same lock and the same
in-flight guard as a normal sync, and both are behind a confirmation dialog that says which side
loses.

## Auto-sync

`AutoSyncService` wraps the shared scheduler. Its triggers are fixed: once at launch, once on
resume, every 15 minutes, and 30 seconds after the last local save (a trailing-edge debounce, so a
burst of edits costs one sync). Overlapping triggers are dropped by an in-flight guard. Conflicts
found in the background are **not** resolved there — the status turns to "conflicts pending" and
waits for the user to open the sync page.

## API keys

Keys are not part of the module, so they do not travel with it. They are exchanged separately, and
only when the endpoint is secure. The exchange runs inside the WebDAV facade immediately after the
engine returns, using the same server and the same remote directory, with a conditional PUT rather
than the engine's lock — the keys file is a per-key last-writer-wins map with no base snapshot and
no merge state, so a concurrent write becomes a rejected request and a re-merge rather than a lost
update. Putting it inside the locked window would mean changing an engine four apps share, for no
safety gained.

See [`features/secure-secrets-sync.md`](features/secure-secrets-sync.md) for what counts as secure
and what the user is told.

## Credentials

The WebDAV server URL, username and password are stored in `webdav_config.json` in plain text, as in
the sibling apps. That is stated in the privacy policy. The file is never synced, backed up or
exported.
