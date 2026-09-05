# Keeping one speaker one person

*Delivered by milestone M5. The matching itself is a pure function, so it can be tested against
synthetic window results without a network or a model.*

Each window is labelled independently, so a person is "Speaker 1" in one window and "Speaker 2" in
the next. Something has to decide those are the same person, and the transcript has to be able to
change its mind later without being rebuilt.

## The shape of the answer

A transcript has **global speakers**, and every segment points at one. Separately, a map records
which window-local label became which global speaker.

That indirection is what makes the rest cheap. Renaming a speaker changes one record and every
paragraph follows. Merging two changes the segments' pointers and nothing else. And because the
provider's raw answers are kept, the whole matching can be re-run from scratch after a manual
correction without uploading a single byte again.

## Evidence from the overlap

Consecutive windows share a stretch of audio, and when speakers were requested that stretch is
deliberately longer. Both windows transcribed it, so both labelled the same speech — which is direct
evidence rather than inference.

For each boundary, the segments both windows produced inside the shared stretch are compared. Each
possible pairing of a new label with an existing speaker scores by how much speaking time the two
actually overlap, weighted up when the two windows also transcribed the same words there. Similar
text matters because two people alternating quickly can overlap in time by accident; agreeing on the
words as well is much harder to do by chance.

The best consistent assignment of new labels to existing speakers is taken, subject to two
conditions: a pairing must rest on enough shared speech to mean something, and it must be clearly
better than the runner-up. **A label that fails either becomes a new speaker.** That asymmetry is
deliberate: an extra speaker the user merges in one tap is a small annoyance; two people silently
merged into one is a transcript that misattributes what somebody said, and nothing in the interface
would reveal it.

Windows are processed in order, so a match chains: the third window matches against speakers the
second already established.

## Evidence from voice samples

Some services accept short reference clips with names attached, and return those names in the
result. Where that is available the app cuts a few seconds of each speaker from where they were
first identified, and sends them with the following windows. A returned name maps directly and
skips the inference entirely. It is the reliable path, and it also survives a speaker being silent
through an overlap, which the voting cannot.

The number of references a request may carry is limited, so the speakers who have talked the most
are the ones carried forward. Beyond that limit, the rest fall back to voting.

## What the user can do

Rename, recolour, merge two speakers into one, split a speaker's segments out into a new one,
reassign a single segment, and re-run the matching. Every operation is a change to records, never a
rewrite of the text.

The boundaries the matching was least confident about are recorded, so the panel can point at them:
"these two might be the same person" is a far better prompt than making somebody read an hour of
transcript looking for the seam.

## The limit, stated plainly

A person who says nothing at all during an overlap, on a service without voice samples, comes back
as a new speaker. There is no evidence connecting them and the app will not invent any. The
confidence flags exist so the correction is one tap in a place the app already suspects.
