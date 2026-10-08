# Shared AI integration

MyApps-AI v0.6.0 owns ASR runtimes, routing, model artifact infrastructure and
online transcription transport. The application retains record identities,
job recovery, FFmpeg windowing, storage paths and fallback preferences.

## Compatibility

Application adapters translate existing value types into shared contracts.
Artifact JSON, route keys and health fingerprints remain compatible. Existing
model files and self-test records must remain usable without another download.
Native runtime versions and hashes are pinned by the shared release.

## Settings

Source records remain synced configuration. Downloads, engine health and privacy acknowledgements remain device-local.
API keys use the separate secure WebDAV exchange and never enter backups or ZIP exports. Task selection remains per
job; shared routing never substitutes another model.

Sources and model records are in the source section. Downloaded artifacts use
shared local-model tiles; online endpoints and keys use the shared online editor
with MyApps-UI endpoint, secret and connection-test fields. Capability and template
editing remain reachable from those pages. Device fallback, speaker labeling and
diagnostics occupy their skeleton slots. The shell has Transcribe and Settings;
legacy `/library` links redirect to Settings. Opening Settings from a new job keeps
the job form and selection on the navigation stack.

## Privacy and exchange

WebDAV acknowledgement gates connection tests, sync, forced transfers, conflict
finalization and auto-sync. Online consent is scoped to provider ID and server
origin; saved jobs without consent fail before upload and can be resumed after
confirmation. Both acknowledgements live only in storage_config.json.

Secrets use namespace `provider` and the existing transcribe_secrets.json format.
Unknown entry fields survive edits and exchange; key counts exclude tombstones.
Forced secret upload/download use one-way exchange modes. Public HTTP trust requires
the shared warning checkbox before a host is saved. EasyTier uses `.et.net`.

## Native ownership and verification

Local ASR packages and the application's two prebuild workflows are removed.
MyApps-AI owns binaries, headers, bindings and hooks. Existing release asset URLs
remain accessible; downloading a model never follows an unpinned latest release.
FFmpeg remains application-owned. No llama backend is bundled by this app.

Host tests exercised real whisper tiny loading, transcription and cancellation.
Mock tests cover routing, jobs, transport and secure exchange. Platform builds do
not establish real inference on Windows, Android or Apple hardware, or real online
provider behavior.
