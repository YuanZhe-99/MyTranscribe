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
