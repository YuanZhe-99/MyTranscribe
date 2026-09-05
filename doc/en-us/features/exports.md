# Exports

*Delivered by milestone M4.*

A finished transcript can leave the app in six formats. Which ones are offered depends on what the
model actually returned, not on what was asked for.

## The formats

| Format | What it is for | Speakers appear as |
|---|---|---|
| TXT | Reading, pasting into anything | `Name: what they said`, one paragraph per run |
| Markdown | A document, or a folder that already holds the scripts' output | `**Name** [mm:ss]:` paragraphs, or `## Segment n` headings when nobody is identified |
| SRT | Subtitles, for players that read SubRip | The name on its own line above the text |
| VTT | Subtitles, for the web | A `<v Name>` tag, which players can style per speaker |
| JSON | Everything, including the app's own fields | As stored |
| CSV | A spreadsheet | A column |

The Markdown form of a transcript with no speakers is deliberately identical to what the original
Python scripts wrote. Somebody with a folder of transcripts from those scripts and a folder from
this app should not be able to tell which is which.

## Subtitles need real times

A model that returns no timestamps still produces a perfectly readable transcript: the times shown
are the app's own estimate, taken from where each window started, and the viewer says so.

Those estimates cannot become a subtitle file. A subtitle a minute out of step looks like it works
and is worse than having none, so SRT and VTT are offered **disabled**, with the reason, rather
than hidden. Hiding them would leave the user hunting for an option that is not there.

## What a file says matches what the screen says

The speaker names come from the viewer, not from the file on disk, so a name typed a moment ago
appears in the export immediately. The same applies to a merge, a reassignment, or a corrected
line.

## Where it goes

Every export is written into the job's own `exports/` folder first. Then:

- **On Windows and macOS**, a save dialog asks where to put it. A cancelled dialog still leaves the
  copy in the exports folder, so the work is not lost.
- **On Android and iOS**, which have no save dialog, the system share sheet takes it from there.

The CSV is written with a byte-order mark. Without it, Excel on Windows opens a Chinese transcript
as mojibake, and Excel on Windows is where most of these will be opened.

## Copying

The copy button puts the whole transcript on the clipboard in the plain-text form — grouped by
speaker and named, as the reader sees it, rather than as raw segments.
