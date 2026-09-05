# Chunking and resume

*Delivered by milestone M3.*

A transcription service will not accept an arbitrarily large recording. OpenAI stops at 25 MB;
OpenRouter stops waiting after ten minutes of audio whatever its size; some models refuse anything
over 1500 seconds. A two-hour lecture meets all three limits at once. This page describes how the
app divides such a recording, and what happens when a run is interrupted part way through.

## Why windows overlap

The obvious division — cut the recording into pieces and send each one — loses a word at every cut,
because a cut lands in the middle of a sentence and neither piece contains the whole of it.

So the pieces overlap. Each window runs past where the next one begins, the shared seconds are
transcribed twice, and the duplicate is removed afterwards. The overlap is five seconds normally
and twenty when speakers are being identified, because the speaker matching needs enough shared
speech to recognise a voice under two different labels. See
[`../algorithms/overlap-merge.md`](../algorithms/overlap-merge.md) and
[`../algorithms/speaker-unification.md`](../algorithms/speaker-unification.md).

## Convert once, cut many

The recording is converted **once** to mono 16 kHz 64 kbps MP3, and the windows are copied out of
that converted file without re-encoding. Three things follow:

- One decode pass instead of one per window.
- A window's size becomes predictable: 8000 bytes a second, exactly, whatever the original was.
  That is what lets the planner choose a window length that will fit rather than guess at one.
- The converted file outlives the windows, and becomes the copy the transcript viewer plays. On a
  phone, where the file picker's cache is emptied without warning, it is often the only copy the
  app can still reach.

A recording that is already small enough, short enough and in a format the model accepts skips all
of this and is uploaded exactly as it is. That is the fast path, and it is why the app can
transcribe a short clip on a machine with no FFmpeg at all.

## What the plan says, and why

The planner produces a plan and a list of reasons for it, and the new-job page shows both before
anything is uploaded. The original scripts made the user pass a chunk length as an argument and
told them afterwards whether it had worked; here the choice is made, explained, and can be
overridden in advance.

The reasons are specific: too large to send whole, longer than the model accepts, the source's own
time limit, the app's safety ceiling, or a length the user chose. A user who disagrees with the
answer can see which limit produced it.

The numbers themselves are in [`../algorithms/chunk-planner.md`](../algorithms/chunk-planner.md).

## Resuming

The job record is rewritten after **every** finished window, and the source's raw answer is kept
beside it. Closing the app, losing the network, or a source refusing one window costs at most the
window that was in flight.

Resuming re-runs the planner and compares its fingerprint — the source, the model, the window
length, the overlap, the language hints, the prompt, the keywords and whether speakers were asked
for. When the fingerprint matches, the finished windows are reused and only the rest are sent. When
it differs, they are all discarded: a result produced under different settings is not the result
the user is now asking for.

A job left mid-run when the app was closed is re-queued at startup rather than left showing a
progress bar that will never move.

## What this costs

Each window is one request, so a recording split into five windows is billed five times, and the
overlapping seconds are paid for twice. That is the price of a recording too large to send whole;
the alternative is not sending it at all.

Windows are uploaded one at a time. Sending them together would be faster and would multiply the
requests a source sees at once, which is how rate limits are hit — and it would make the resume
ordering much harder to reason about.
