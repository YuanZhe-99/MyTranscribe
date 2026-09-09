# Reading a transcript

*Delivered by milestone M4.*

The viewer is where a transcript stops being a file and becomes something you can read, correct and
send on. It is a full-window route: a transcript wants the whole window, and it is something you do
to one recording and leave when finished.

## Two ways to read

- **Transcript** — paragraphs of continuous prose. Where the recording has speakers, consecutive
  segments from one person are joined into a paragraph with their name and colour at the top. This
  is the reading view.
- **Segments** — one row per segment, each with its own time range. This is the correcting view:
  tap a row to hear it, edit its text, or move it to another speaker.

Grouping, timestamps and text size are preferences, remembered per device.

## Alongside the audio

A player bar runs along the bottom: play and pause, skip, a scrubber, and a speed control. Tapping
any segment seeks to it, and the segment under the playhead is highlighted as it plays. The audio is
the normalized copy the job already made, so it is there without keeping the original.

A recording small enough to have been sent whole never had a converted copy, and one whose copy the
user has given back no longer has one; in both cases the original recording is played instead while
it can still be found. The bar says there is nothing to play only when neither is on the device.

## Speakers

Where the model returned speaker labels, a panel lists them with a colour, a name and how much each
one spoke. Names are yours to set, and a name you have used before is offered as a chip that applies
in one tap. Two speakers that are really one person can be merged; a label that is not one person at
all can be marked unknown, which takes its lines away from everybody rather than giving them to the
wrong person. A single misattributed line is moved in the line editor. Splitting one speaker into two in bulk
is not built: moving lines one at a time does the same job, and until somebody meets a recording
where that is not enough, a bulk operation would be guesswork about what they wanted.

Every edit is written to disk the moment it is made, and re-read the next time the transcript is
opened. Nothing here rewrites the text: segments point at a speaker, so renaming, merging or marking
somebody unknown changes one record and every paragraph follows. Because the raw responses are kept, the speaker matching can
also be re-run from scratch without uploading anything again.

## Getting it out

An exported file is named after the transcription — the name the user gave it, or the recording when
they have not given one. Copy, save, or share, in whichever format fits:

| Format | For |
|---|---|
| Plain text | pasting somewhere |
| Markdown | notes, with speakers and timestamps |
| SRT, VTT | subtitles |
| JSON | another program |
| CSV | a spreadsheet |

Subtitle formats need timestamps, so they are offered only when the model returned them, with the
reason shown rather than the option silently missing.

## Without timestamps

Some models return text and nothing else. The transcript still works: timestamps read as
approximate, taken from where each window started, seeking jumps to the start of a window, and the
formats that need real timings are unavailable. The viewer says which of these applies rather than
pretending to precision it does not have.

## On a narrow window

The speaker and display panels move into a sheet you pull up, and the transcript keeps the full
width. The rule that decides is a double gate — the window must have the shape for two panes *and*
enough width for both — and it is described in [`../adaptive-layout.md`](../adaptive-layout.md).
