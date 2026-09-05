# Sources and models

*Delivered by milestone M2.*

A **source** is somewhere the app can send audio: an API endpoint, how to authenticate to it, and
the models it offers. The user's word for it is 来源; in code it is a provider.

## Built-in templates

Three, seeded on first launch:

- **OpenAI** — the official API.
- **OpenRouter** — a gateway to many models, with its own request shape for provider-specific
  options.
- **OpenAI-compatible** — a blank endpoint for anything that speaks the same protocol: a local
  `whisper.cpp` or `faster-whisper` server, or another gateway. Authentication can be switched off
  entirely, which is what a server on your own machine usually wants.

Templates seed with **derived ids**, so two fresh devices produce byte-identical records and the
first sync merges them instead of leaving two of everything.

## What a model records

Not just its name. Each model carries what the app needs in order to decide how to split a
recording, and what it can ask for:

| Field | Used for |
|---|---|
| upload size limit | the byte budget for one window |
| duration limit | the time budget for one window |
| speaker labels | whether to offer them, and how to ask |
| word timestamps | whether the transcript can carry them |
| prompt, keywords | whether to send the ones the user typed |
| language parameter style | some models take a list, others a single code |
| response formats | which one to ask for |
| input formats | whether the recording can be uploaded unchanged |

A capability is `yes`, `no`, or **`unknown`**. Unknown is a real answer, not a placeholder: for a
custom endpoint the app genuinely does not know, so it offers the feature with a note rather than
hiding it or promising it.

## Overriding

Every field is editable, and a field the user changed is marked as overridden. That matters when a
later build ships an updated template: fields the user did not touch are refreshed, fields they did
are left alone. "Reset to template" clears the marks and takes the new values.

This is the escape hatch for everything the app cannot know. A provider raises a limit, a model
gains speaker support, a self-hosted server behaves differently — the user changes the field and
carries on, without waiting for a release.

## Importing models

A source can be asked for its own model list. Imported models arrive with capabilities from a
matching template where one exists and `unknown` where none does — the app does not guess, because a
wrong guess turns into a failed job with a confusing message.

## API keys

Not part of a source record. They live in a separate file that never enters a backup or a ZIP
export, and reach another device only over a connection that qualifies. See
[`secure-secrets-sync.md`](secure-secrets-sync.md).
