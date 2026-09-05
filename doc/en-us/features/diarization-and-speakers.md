# Who spoke

*Delivered by milestone M5.*

Some models return the text with speaker labels attached. Where that is available the transcript
says who spoke, and the user can name them.

## Whether it is offered

From the model's own capability field:

- **supported** — offered, and on by default.
- **unknown** — offered, off by default, with a note that it is not verified for this model. If the
  server rejects the request, the app offers to run again without it rather than making the user
  hunt for the setting.
- **not supported** — not offered, with a line saying the model cannot do it and that the field can
  be changed in the library if that is wrong.

Asking for speakers changes how the request is built, and sometimes how large a window may be. The
planner accounts for both.

## The hard part: one person, many windows

A long recording is split into windows, and each window is labelled independently. The model that
called someone "Speaker 1" in the first window has no idea it is the same person it calls
"Speaker 2" in the second. Left alone, an hour of two people talking comes back as a dozen speakers.

Two things fix it, and a third catches what they miss.

**Overlapping windows vote.** Consecutive windows deliberately share a stretch of audio — longer
when speakers were requested, because this is what that overlap is for. Both windows transcribed
that stretch, so both labelled the same speech. Lining the two up gives direct evidence: this
window's label B is the previous window's label A, because they cover the same seconds and say the
same words. Where the evidence is weak or ambiguous, the label becomes a new speaker rather than a
wrong guess — a stranger the user merges is a small annoyance, two people silently merged into one
is a broken transcript.

**Voice samples carry forward.** Where the API accepts known-speaker references, the app cuts a
short sample of each speaker from where they were first identified and sends it with the next
window. The model then returns that speaker under the same name, and no inference is needed. This is
the reliable path, and it is available on some services and not others.

**The user decides.** The speakers panel merges two speakers, and the line editor moves a single
line to somebody else. Every operation changes one record rather than rewriting the text, and
because the raw responses are kept, the matching can be re-run without uploading anything again.

## What this cannot do

A person who says nothing during a whole overlap, on a service without voice samples, will come back
as a second speaker. There is no evidence connecting them, and inventing some would be worse. The
panel flags the boundaries it was least sure about, so the correction is one tap in a place the app
already suspects, rather than a search through the whole transcript.

The details of the matching are in
[`../algorithms/speaker-unification.md`](../algorithms/speaker-unification.md).
