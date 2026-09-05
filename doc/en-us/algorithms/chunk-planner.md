# Dividing a recording

*Delivered by milestone M3. Implemented as a pure function so the whole table below is testable
without a file, a network or a device.*

## The question

Given a recording and a chosen model, produce a plan: upload it whole, or cut it into windows of
what length, overlapping by how much. Get it wrong in one direction and the request is rejected;
in the other, and a two-hour lecture becomes fifty needless round trips.

## The budgets

Two limits bound one window, and the smaller wins.

**Bytes.** The upload limit, less a margin. Because the app normalizes to a fixed 64 kbps first, a
second of audio is exactly 8000 bytes, so a byte budget converts straight to a time budget. A 24 MiB
budget is a little under 50 minutes of audio.

**Time.** Some models cap how much audio one request may carry, and some *providers* cap how long
one request may take regardless of the model behind it — a gateway that times out after a minute of
processing needs shorter windows than the model itself would. Both are fields on the record, so
neither is hardcoded and both can be corrected by the user when a service changes.

A ceiling applies on top of both: a very long single request fails slowly and costs the whole window
again on retry.

## The fast path

If the recording already fits — small enough, short enough, and in a format the model accepts — it
is uploaded **unchanged**, with no FFmpeg at all. This is the common case for a short clip, and it
is what the original scripts did too. It also means the app is useful before FFmpeg is set up.

## Windows and overlap

Windows advance by a **stride** and each one extends past it by the **overlap**, so consecutive
windows share a stretch of audio. The overlap exists so a word cut in half is transcribed whole by
at least one window; the merge then removes the duplication.

The overlap is larger when speaker labels were requested, because there it does a second job: it is
the evidence that connects a speaker in one window to the same speaker in the next. See
[`speaker-unification.md`](speaker-unification.md).

A final window shorter than a few seconds is folded into the one before it. A three-second window is
a round trip that returns almost nothing and often ends mid-word.

## Saying why

The plan carries the reasons it came out the way it did, and the new-job page shows them: split
because the file is too large, or because this provider times out; windows capped by the model, or
by the upload size; a longer overlap because speakers were requested. A user who disagrees can
override the window length, and a user who thinks a limit is wrong can change it on the model.

## When a window still does not fit

Audio is not perfectly uniform, so a window can come out larger than predicted. Rather than failing
the job, the planner is asked again with a smaller stride and the windows are re-cut. The scripts
stopped and told the user to retry with a different argument; this does it for them.
