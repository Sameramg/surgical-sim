# How many titles before the AI is statistically trustworthy?

Sample-size planning for AI-assisted title/abstract screening, worked against this
review's own audit trail (1,376 records screened → 273 advanced → 21 included at
full text; 3 further studies added later).

```
screening-sample-size-planner.html   interactive planner (open in a browser)
sample_size_analysis.py              the same maths, reproducible (stdlib only)
```

## The short answer

**There is no such number.** Not because the screener is weak, but because recall
precision is bought with *included studies*, and a 3,000-record review contains
only about 45 of them.

Two different claims are constantly conflated, and they have very different prices.

### Claim 1 — "this review is ≥95% complete"

A finite-population statement about one corpus. Achievable, but not cheaply.
Sample from the pile the AI **rejected** (never from the whole corpus — 300 random
records hold ~4 includes, and 4-for-4 proves only recall >40%). Assuming a
3,000-record corpus, 1.5% include rate, and the AI rejecting 65%:

| Hand-screened from reject pile | Hidden includes (95% max) | Recall at least |
|---|---|---|
| 300 | 17 | 72.6% |
| 800 | 5 | 90.0% |
| 1,231 | 2 | 95.0% |
| 1,600 | 1 | 97.8% |

Reaching ≥95% costs ~1,231 reads — 41% of the corpus — and only if you find
**zero** includes in the sample. One hit and the guarantee collapses.

### Claim 2 — "the screener has ≥95% recall"

A statement about the tool, which must generalise. Governed by exact
Clopper–Pearson on the number of included studies observed:

| Recall lower bound | Includes needed (0 missed) |
|---|---|
| ≥80% | 17 |
| ≥90% | 36 |
| ≥95% | 72 |
| ≥99% | 368 |

A 3,000-record review at 1.5% yields ~45 includes. **Screen every record, find the
AI missed nothing, and the strongest defensible claim is still recall ≥92.1%.**
≥95% is unreachable at any sample size in a review this size.

This is also why the existing validation reads as it does: 28/28 retained is a
two-sided 95% bound of **87.7%**, matching the report's "approximately 88%".

## Why the union rule settles it

```
recall(union) = P(human advances OR AI advances)
              ≥ P(human advances)
              = recall(human alone)
```

An identity, not an estimate — true even if the AI's recall were zero, because a
union only adds records. **The number of titles you must screen before it is safe
to add the AI is zero.** Validation was never the safety gate; it only licenses
*dropping* the human, which the tables above price at roughly half the corpus.

## The real learning curve

The model does not learn — it is zero-shot, so record 3,000 is screened exactly as
record 1. What improves is the **rubric**, and only when a human sees a systematic
error and writes a rule against it (as with *"never exclude because duration is not
mentioned; duration is often only in a baseline table"*).

Chance of catching a blind spot at least once ≥95%:

| Blind spot affects | Includes to see | ≈ titles read (advance pile) |
|---|---|---|
| 30% of includes | 9 | 210 |
| 20% of includes | 14 | 327 |
| 10% of includes | 29 | 677 |

Read the AI's *advance* pile, where includes concentrate — the same insight costs a
fraction of the reading.

## Recommended procedure for a new 3,000-record review

1. **Calibrate, don't measure.** Dual-screen the first 150–200 records and read every
   disagreement, hunting rubric rules. Far too small for a recall figure — treating
   it as evidence of accuracy is the main failure mode.
2. **Freeze the rubric,** then record model ID and date. Later edits invalidate
   everything measured before them.
3. **Run the union rule** across the full corpus. No validation is owed beforehand.
4. **Audit the reject pile continuously** and bank the reads against the table above.
5. **Report the bound, not the point estimate.** "100% recall on 28 studies" is a
   claim of ~88%; stating it that way is what survives peer review.

## Methods

Clopper–Pearson (exact binomial) for recall bounds; exact hypergeometric for the
finite reject pile; `1−(1−f)ⁿ` for blind-spot detection. Bounds describe the
screener only and assume samples are drawn at random from the stated pile. Run
`python3 sample_size_analysis.py` to reproduce every figure.
