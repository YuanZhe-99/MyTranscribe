# Joining the windows back up

*Delivered by milestone M3. A pure function.*

Consecutive windows share a stretch of audio, so the same words come back twice. The merge removes
the duplication without cutting anything real.

## With timestamps

When the model returns times, the join is simple and exact: pick a cut point in the middle of the
shared stretch, keep the earlier window's segments that end before it and the later window's
segments that start after it. Each segment's times are shifted to their place in the whole
recording. A pair straddling the cut is then checked for repeated words, in case both windows
transcribed the same phrase slightly differently.

## When segments are paragraphs

The cut point works because a segment is short next to the overlap. Some models do not return short
segments: one that answers in paragraphs returns three of them for a ten-minute window, each several
minutes long. Then the segment on each side of the cut covers the whole shared stretch, both are
kept, and the recording says the same thing twice at every seam.

The first real recording this app transcribed did exactly that — nine windows, twenty seconds of
overlap, and nineteen seconds duplicated at all eight seams.

Two things fix it. First, how far the comparison looks is derived from the seam instead of fixed:
twenty seconds of speech is roughly a hundred and sixty tokens, and a search capped at forty could
never line the two sides up.

Second, the repetition is followed as a **chain** rather than looked for as one unbroken run. Two
windows transcribing the same seconds disagree in scattered small ways — a word misheard, a
hesitation one side dropped, "x squared" against "s square" — so the shared speech comes back as
several matching runs with a stranger or two between them. The chain starts at the beginning of the
later passage, each link starts where the last one ended in **both** passages, and the later passage
is cut at the end of the last link. Moving forwards on both sides is what stops the chain latching
onto a phrase the recording repeats throughout, which for a mathematics lecture is most of its
vocabulary.

Matching from the start of the later passage but anywhere in the earlier one is weaker evidence than
the three-word rule has, so the chain must find more before it is believed: six words in total, or
eight characters in a script without spaces. The earlier passage is never altered, and the trimmed
segment's start time moves to where the earlier window stopped, so a subtitle does not claim seconds
it no longer covers.

On the recording this was built from, seven of the eight seams come out clean. The eighth is two
transcriptions that share almost no exact sequence of words — one wrote "two vectors" where the
other wrote "2 vectors" — and there nothing is removed, which is the rule below.

## Without timestamps

Some models return text and nothing else, and this is where the original scripts' rule earns its
keep.

Compare the tail of what has been kept so far with the head of the new window, longest first, and on
the first match drop that head. Words are normalized before comparing — case folded, punctuation
stripped — because two windows rarely punctuate a boundary identically.

The rule requires **at least three matching words** in a row. Two would fire on any repeated "you
know" or "and then", and the merge would eat real speech. It compares at most about forty, because
beyond that the match is no longer about an overlap.

## Chinese and Japanese

The scripts split on spaces, which works for English and does nothing for a language that does not
use them: a Chinese lecture came back with the whole overlap duplicated. The tokenizer here treats a
run of Han characters, kana or Hangul as individual characters, and requires more of them to match —
a few characters of Chinese carry far less information than three English words, so the threshold
has to be higher to mean the same thing.

## When nothing matches

Nothing is removed. A boundary where the two windows genuinely disagree leaves a few duplicated
words in the transcript, which the user can see and delete. Guessing more aggressively risks
deleting a sentence that happened to resemble the one before it, and a silently missing sentence is
much harder to notice than a repeated one.
