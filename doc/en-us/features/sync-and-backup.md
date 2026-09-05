# Settings, Data

Four rows, one job each.

## WebDAV sync

Point the app at your own WebDAV server, and your sources, models and preferences follow you to
another device. Off until you set it up; it talks only to the server you entered.

The page holds the server address, your credentials, the folder to use, a connection test, and an
auto-sync switch. Below them: sync now, and — behind a confirmation that says which side loses —
force upload and force download.

A banner under the address says whether your API keys will travel with the rest. They do over
HTTPS, and over a private address such as your own network, Tailscale or ZeroTier; over plain HTTP
to a public server, your settings still sync and the keys stay here. See
[`secure-secrets-sync.md`](secure-secrets-sync.md).

When both devices changed the same thing, the app asks which version to keep, one at a time, showing
both and when each was made. It never chooses for you, and backing out of the question leaves
everything as it was rather than half-applied.

## Backup

A local copy of your sources and models, kept on this device. Take one whenever, or leave the daily
automatic backup on and choose how long to keep them. Restoring asks which parts to bring back, and
checks the whole file before writing anything.

Backups never contain your API keys or your recordings. What that means in practice: restoring on a
fresh device gives you your sources and models, and you re-enter your keys once.

## Export and import

The same contents as a backup, as a `.zip` you can put anywhere — another machine, a USB stick, a
cloud folder of your own. Import replaces what is there, so it confirms first, and it validates the
whole archive before writing a single file.

## What is not here

Your recordings and transcripts. They stay on the device, and each transcript has its own export
options in the viewer. Sending hours of audio through a sync folder is not something the app does
quietly on your behalf. See [`../data-formats.md`](../data-formats.md).
