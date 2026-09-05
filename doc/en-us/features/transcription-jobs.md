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
  unless the user chose to keep it.

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

## Output

`<name>.transcript.md` and `<name>.transcript.txt`, in the format the scripts produced, written
beside the source recording on desktop when that directory is writable and into the job's own
exports folder otherwise. The viewer offers the other formats.
