# Backup, restore and ZIP transfer

Two ways to keep a copy of the configuration: local bundles kept on the device, and a ZIP file the
user can put anywhere. Both carry **only** what the module registry lists: the settings file and
the transcripts projection. Neither carries API keys or recordings.

The engines live in the shared `myapps_data` package; this page describes how they are configured
here.

## Local backups

A backup is one JSON bundle in `backups/`, named `backup_<yyyyMMdd_HHmmss>.json`, holding the raw
content of each registered data file. MyTranscribe has no images, so the blob store the format also
supports stays empty here.

- **Automatic:** once a day, if the user turned it on, checked at launch, on resume and on the
  periodic tick, so a device left open across midnight still gets one.
- **Retention:** a chosen number of days, or forever. Cleanup runs after each new backup.
- **Listing:** newest first, with size, and a bundle that will not parse is flagged as corrupt
  rather than hidden — a backup you cannot restore is worth knowing about before you need it.

### Restoring

The user picks a bundle and which modules to restore from it. Then, in order:

1. WebDAV auto-sync is disabled **before the first write**. A restore replaces local data with older
   data; a sync firing in the middle would upload the half-restored state.
2. Every selected payload is validated by parsing it. A bundle that fails validation is rejected
   with nothing written.
3. The files are written atomically.
4. Auto-sync is re-enabled **only if the restore failed without writing anything**. After a
   successful restore the user is asked whether to upload the restored state, because that is a
   decision about the other devices, not about this one.

That ordering is invariant I5 of the shared package and is not ours to change.

## ZIP export and import

`mytranscribe_export_<yyyyMMdd_HHmmss>.zip` holds the registered data files and nothing else. The
engine is configured strictly here, because this app has no installed base to stay lenient for:

- unknown entries are rejected rather than ignored,
- payloads must be valid UTF-8,
- everything is validated before anything is written,
- writes are atomic.

Import is two-phase: classify and validate the whole archive, then write. A rejected archive leaves
the existing settings untouched. Path traversal is refused outright by the engine regardless of
these settings, and every entry is re-checked to resolve inside the app directory before it is
written.

Export asks for a directory; import asks for a `.zip` and then confirms, because an import replaces
what is there.

## What is deliberately not included

- **API keys.** A backup bundle is a plain JSON file that a user may copy, mail to themselves or
  restore on a borrowed machine. Keys reach a new device through a secure sync, or by being typed
  in. This is a trade the user should know about: restoring a backup on a fresh device gives you
  your sources and models, but you will re-enter your keys.
- **Recordings and audio.** Hours of private audio in every bundle, and a bundle would stop being
  something you can casually copy. The *text* of each transcription is included, through the
  transcripts module; the sound is not.
- **`webdav_config.json` and `storage_config.json`.** Server credentials, and preferences that
  describe *this* device.
- **Downloaded models and the engine state.** A model is gigabytes and can be downloaded again; the
  local model *records* are in the settings module and restore like the sources, so a restored
  device lists its models as not downloaded. `local_engine_state.json` describes this device's
  processors and is meaningless anywhere else.

All of these are excluded structurally: the engines only touch the file names in the registry.

Restoring the transcripts module is **additive**. What the bundle holds is written into `jobs/`, but
nothing local is deleted for being absent from it: a bundle says what it held when it was taken, not
what the user has deleted since. The same goes for a ZIP import.

One compatibility note: a 0.2.0 build ignores the new module in a bundle, but its ZIP import is
strict about unknown entries and will **reject** an archive exported by this build.
