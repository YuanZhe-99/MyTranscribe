# Profile

A display name and a round avatar, kept on every device you sync.

## What the user sees

- **The home tab.** The avatar sits left of the title on the Transcribe tab, and only there. Tapping
  it opens Settings.
- **The top of Settings.** An avatar and name row, the first item of the list. Tapping it opens a
  dialog to choose or remove the avatar and to edit the name. An avatar change is saved at once; the
  name is saved with Save.
- **Without a picture** the avatar shows the first letter of the name, or a person icon when there is
  no name either. A picture that has not arrived from sync yet shows the same placeholder and
  replaces it once the file is on the device.

## How it is stored

`profile.json` (see [data-formats.md](../data-formats.md)) holds the name and the avatar's path, each
with its own timestamp. The picture is `images/avatar_<uuid>.jpg`, a 512 x 512 centred square JPEG,
with the photo's orientation corrected first. Every change of avatar uses a **new file name**: the
engine's image phase is incremental and never overwrites a file of the same name, so reusing a name
would leave other devices with the old picture. The previous file is deleted on this device only, and
only when its name starts with `avatar_`. The old picture stays on the server, a known limit.

All edits go through one queued read-modify-write, and a save notifies auto-sync only when the bytes
changed. A `profile.json` that exists but cannot be parsed is never overwritten.

## How it syncs

The profile is the third data module, appended after the settings and the transcripts. It merges per
field, last writer wins, a tie keeps the local value, and it raises no conflict. `referencedImages`
names the avatar, which is what lets the engine's `images/` phase carry the picture; MyTranscribe's
own `audio/` side channel is separate and untouched. Details are in [sync.md](../sync.md). The
provider reloads the profile whenever auto-sync reports that local data changed, which covers
manual syncs and restores too.

## Backup and restore

The profile is a module in a backup bundle and in a ZIP export, labelled "Profile" in the restore
dialog; the avatar picture travels as a blob. Older backups have no profile and leave it alone.
