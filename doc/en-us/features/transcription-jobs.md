# Transcription jobs

*Delivered by milestone M3.*

A **job** is one recording being turned into text. It is a record on disk, not just a running task,
which is what lets it survive the app being closed and pick up where it stopped.

## Stages

```
queued -> probing -> planning -> normalizing -> [ cutting -> uploading -> parsing ]* -> merging
       -> naming speakers -> rendering -> done
```

Any stage can fail or be cancelled. A failed or cancelled job keeps the windows it finished, so
resuming does not pay for them again.

- **probing** reads the recording's duration and bit rate. Without a media toolkit this is skipped
  and only the file's size can inform the plan.
- **planning** decides whether to split at all and, if so, into what. See
  [`../algorithms/chunk-planner.md`](../algorithms/chunk-planner.md).
- **normalizing** converts the whole recording once; skipped when the file is uploaded unchanged.
- **cutting, uploading, parsing** run once per window, in order, one at a time. The job record is
  rewritten after each one, and the provider's raw answer is kept.
- **merging** joins the windows back into one transcript. See
  [`../algorithms/overlap-merge.md`](../algorithms/overlap-merge.md).
- **naming speakers** runs only when the model returned speaker labels. See
  [`diarization-and-speakers.md`](diarization-and-speakers.md).
- **rendering** writes the transcript and the requested output files, then deletes the window audio
  unless the user chose to keep it. A window another program is holding at that moment survives the
  delete; it is swept away the next time the app starts, rather than sitting in the job folder for
  good at a tenth of the size of the recording.

## Resuming

A resume recomputes the plan's fingerprint — source, model, window size, overlap, language, prompt,
keywords, whether speakers were requested. If it no longer matches, every cached window result is
discarded: a result produced under different settings is not the result the user asked for. That is
the same rule the scripts used when their progress file did not match the current arguments.

A cached window is reused when its saved result matches the size of the window file on disk. A
missing window file is cut again from the normalized audio, which is cheap. A missing normalized
file is rebuilt from the source; if the source itself is gone, the job fails and says so.

## One at a time

Jobs run in a queue, one at a time, and the windows within a job upload sequentially. This keeps the
resume ordering simple and respects a provider's rate limits. Cutting a window is cheap next to
uploading it, so overlapping the two would buy little.

The screen is kept awake for the duration of a job and released in every exit path, including
failure and cancellation.

## When something goes wrong

- Network trouble, a timeout, or a server error: retried twice with a growing delay.
- Rate limited: retried, honouring the delay the server asks for.
- Rejected by the server: not retried. The server's own message is shown, because it usually says
  exactly what is wrong — a bad key, a file too large, an unsupported format.
- A rejection that names a feature the model does not have, such as speaker labels, offers to run
  again without it rather than making the user find the setting.
- A window that turns out to exceed the upload limit after it is cut re-plans with smaller windows
  instead of failing.

## What the pages watch

A job has three copies at any moment: the record on disk, the runner's own copy of whatever it is
working on, and whatever a page last managed to read. The pages take the most recently written of
the three, so none of them has to know about the others.

The runner keeps the job it has just finished, so a page showing that job can say so at once, and
counts every record it writes. The list and the detail page watch that count and re-read. Before
that counter existed, a record was only ever re-read when a page happened to refresh its list after
a button was pressed — so a job that finished while its own page was open went on showing the stage
it started at, with a Start button, until the app was restarted. Pressing that button rebuilt the
transcript from the windows and threw away every correction.

A finished job therefore offers **Run again** and never plain Start, and running again asks first:
the transcript is built from scratch, so speaker names and edited lines go.

## Output

`<name>.transcript.md` and `<name>.transcript.txt`, in the format the scripts produced, written
beside the source recording on desktop when that directory is writable and into the job's own
exports folder otherwise. The viewer offers the other formats.

Both carry the speaker names the cross-window matching settled on, so one person has one name from
end to end rather than whatever label each window happened to use. Somebody nobody has named is
`Speaker 1` in English there, because the runner has no interface language to ask. They are named
after the **recording**, not after any name the user later gives the transcription: a folder of
these files is read by file name.

## Naming a transcription

A transcription is called after its recording until somebody says otherwise. The name can be changed
from the detail page or by holding a row in the list, and clearing it puts the recording's file name
back.

It is a label and only a label. The two files written beside the recording — when that option is on;
it is off by default — keep the recording's own name, because a folder of them is read by file name and renaming something inside the app is not a
reason to rename anything on disk. A file exported from the viewer does take the name, because that
is a file the user is deliberately saving somewhere — with the characters a file name may not
contain replaced by underscores. The `- Audio:` line in every rendered transcript goes on naming the
recording.

Renaming works while a job is running. The runner re-applies the name to everything it writes, so it
survives the next window rather than being overwritten seconds later.

## What a transcription is holding

The detail page says how much room the job takes on this device, and offers to remove the converted
copy of the recording once the transcript exists. That copy is about a third of the size of the
original — thirty-nine megabytes for an eighty-minute lecture — and it is kept because it is what
the viewer plays. Removing it leaves the record, the transcript, the raw replies and the speaker
samples, so the transcript is still readable, still correctable, and the speaker matching can still
be re-run without uploading anything. Playback falls back to the original recording.

It is not offered while the job is running, because the windows are cut from it.
