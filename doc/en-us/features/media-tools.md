# Media tools

*Delivered by milestone M1.*

Splitting a recording, reading its duration, and cutting a speaker sample all need FFmpeg. One
interface, `MediaToolkit`, describes what the app needs; two implementations provide it.

## What the app asks for

- **probe** — duration, bit rate, codec, whether there is video
- **normalize** — the whole recording to mono 16 kHz 64 kbps MP3, with progress
- **extract a window** — copy a time range out of the normalized file without re-encoding
- **cut a sample** — a few seconds as 16 kHz mono WAV, for speaker enrollment

Every long operation reports progress and can be cancelled.

## Normalize once, cut many

The scripts this app replaces decoded the source once per window. Doing it once instead has three
consequences worth stating: one decode instead of *n*, chunk sizes that are exactly predictable at
8000 bytes a second, and a normalized file that doubles as the transcript viewer's listening copy
and survives the system purging a picked file's cache. Quality is identical — the same codec
settings either way.

A recording that is already small enough and in a format the model accepts is uploaded unchanged,
with no FFmpeg involved at all. That is the common case for a short clip, and it is the fast path
the scripts had too.

## Two backends

**Embedded** (Android, iOS, macOS): the FFmpeg libraries are linked into the app. Progress comes
from the library's own statistics callback; cancelling cancels the session.

**External executables** (Windows): `ffmpeg` and `ffprobe` as child processes. Progress is parsed
from FFmpeg's machine-readable progress stream on stdout; the last lines of stderr are kept so a
failure can say what went wrong; cancelling kills the process and deletes the partial output.

Which one is asked is `platform_capabilities.dart`'s decision, and the reasoning — including why
Windows cannot use the plugin on this project's own hardware — is in
[`../platform-notes.md`](../platform-notes.md).

## Finding the tools

On Windows, in order: a path the user set, the app's support directory, the directory the executable
is in and its `bin/`, the working directory, then `PATH`. A candidate is checked by whether the file
exists rather than by running it, because running an executable to test it flashes a console window.

When nothing is found, Settings says so plainly and offers two things: download a published build,
or point at one you already have. The download fetches the right architecture, extracts only the two
executables, verifies they run, and records what it downloaded.

Until a toolkit is available the app is not broken — it can still transcribe a recording small
enough to upload whole. A job that needs splitting fails with a message that names the missing tool
and offers to set it up, rather than a generic error.
