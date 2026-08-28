# Regan, Kothe & Sharpe (1991), Figure 4 — motion-defined vs contrast-defined letters

**Source.** Regan, Kothe & Sharpe, *Recognition of motion-defined shapes in
patients with multiple sclerosis and optic neuritis*, Brain 1991;114(3):1129–1155,
[doi:10.1093/brain/114.3.1129](https://doi.org/10.1093/brain/114.3.1129).

**Targets deficit (b)** — worse recognition of shapes defined only by motion. It is
the stronger test of deficit (b) than Raz Figure 1, for the reason in the next
section, and it is the study Raz et al. adapted their object-from-motion task from.

**The figure itself is not in this repository** — copyrighted (Oxford University
Press). What is committed is the numbers read off it, plus the counts the paper
states in prose.

## Why this figure is the good one

The two stimuli being compared are **identical in every respect except one**. Both
are the same 10 letters, the same 50 arcmin size (6/60 Snellen equivalent), and the
same random-dot sampling. The motion-defined (MD) letter is created by moving the
dots inside the letter one way and the dots outside it the other way; the
contrast-defined (CD) letter is created by switching the surrounding dots *off*.
Same dottiness, same size, same task, same 75%-correct criterion. So a patient who
fails one and passes the other cannot be failing because of blur, letter size, dot
sampling, or a naming problem.

Two measures, both plotted as sensitivities so that higher is better:

- **motion sensitivity** (ordinate) = reciprocal of the dot speed giving 75% correct
  reading of the MD letters, in s/deg;
- **contrast sensitivity** (abscissa) = reciprocal of the dot contrast giving 75%
  correct reading of the CD letters.

Subjects confirmed formally that reading scores for the MD letters are **at chance
when dot speed is zero** — the letter is perfectly camouflaged — and that the
letters sharpen as speed increases.

## The numbers

### Normal limits (digitized; these are the two dashed lines)

Both are set at 2.5 SD from the control group mean, giving an expected
false-positive rate of 1 in 100. Located by pixel detection of the dashed lines
against the log axes, so these are tight:

| limit | value | equivalent |
|---|---|---|
| motion sensitivity, lower normal limit | **10 s/deg** | speed threshold 0.1 °/s |
| contrast sensitivity, lower normal limit | **6.1** | contrast threshold ~16% |

The observed false-positive rate in the control group was 1/50 for each measure.

### Control distribution (digitized, approximate)

50 eyes of 50 control subjects, one eye per subject. The cluster is tight and
roughly log-normal: motion sensitivity spans about **9 to 49 s/deg** and contrast
sensitivity about **5.8 to 11**, with centres near 20 s/deg and 8.5. Inverting the
2.5-SD limits from those centres gives an implied SD of roughly 0.12 log units for
motion sensitivity and 0.06 for contrast sensitivity, which is consistent with the
observed upper edges — but that is an inference from the limits, not a published
number, and the paper reports no means or SDs.

### Patient results (these are the paper's own counts, not digitized)

50 eyes of 25 patients with MS or ON.

| finding | count |
|---|---|
| eyes below the motion-sensitivity limit | 34/50 |
| eyes below the contrast-sensitivity limit | 22/50 |
| eyes abnormal on one or other test | 36 |
| — abnormal for **MD only**, contrast sensitivity normal | **14** (13 with normal Snellen acuity) |
| — abnormal for **CD only**, motion sensitivity normal | **2** (1 with normal Snellen acuity) |
| — abnormal on both | 20 (10 with normal Snellen acuity) |
| eyes scoring at chance even at the fastest available speed ("NM") | 5 |

Correlation between the two sensitivities: **r = 0.05, p = 0.72 in controls**;
**r = 0.71, p = 0.0001 in patients**. The patient correlation is the group trend;
the 14 vs 2 asymmetry is the finding.

The 5 NM eyes scored at chance at the fastest dot speed the apparatus could
produce, **0.45 °/s per field, i.e. 0.90 °/s relative between letter and surround**.

### The blur control

This matters, because it rules out the obvious alternative explanation. 4 of the 5
NM eyes had decimal acuity better than 0.5. Blurring a control eye of acuity ≥1.0
down to 0.5 with a positive lens left its motion sensitivity **within normal
limits**; roughly **+3.0 dioptres**, taking acuity down to about 0.25, was needed to
halve the MD reading score. So the motion deficit is not a consequence of reduced
acuity over the range these patients had.

## How much to trust these

- **The counts, the correlations, the speeds and the blur control are published
  values, quoted from the text.** Use them as such.
- **The two normal limits and the control ranges are digitized.** The limits are
  read from dashed lines against labelled decade gridlines and are good to about
  ±3% (so 10 s/deg is 10, and 6.1 is 6.0–6.2). The control ranges are looser, ±10%.
- **No per-eye scatter is committed.** Per-point digitization was attempted and
  rejected: 50 points overlap heavily in a cluster about a third of a decade wide,
  several sit on the dashed lines, and automated blob detection resolved only about
  half of them as separable. A half-recovered point cloud would be worse than
  useless. If the joint distribution is ever needed, get it from the authors.
- **Appendix 2 does not contain numbers.** It is a per-eye table of asterisks
  marking which results were more than 2.5 SD from the control mean — the same
  information as the counts above, resolved by patient. Appendix 1 gives clinical
  data and Snellen acuities per case.

## An ambiguity in the ordinate: dot speed or relative speed?

The caption says motion sensitivity is "the reciprocal of the speed that gave 75%
reading scores" without saying which speed, and the paper uses both throughout
(the apparatus maximum is quoted as "0.45 deg/s dot speed, that is, a relative dot
speed ... of 0.90 deg/s"). This is a **factor of 2**, so it must not be guessed
silently.

The evidence favours **relative** speed. If the ordinate were 1/(dot speed), no
measurable eye could fall below 1/0.45 = 2.2 s/deg; if it is 1/(relative speed),
the floor is 1/0.90 = 1.1 s/deg. Digitized patient points sit at about 1.7 and 2.1
s/deg — below 2.2, above 1.1 — which is only consistent with the second reading.
The displacement on a log axis is far larger than the digitizing error.

Under that reading the normal limit of 10 s/deg is a **relative** speed threshold of
0.1 °/s, i.e. a dot speed of 0.05 °/s per field — which is exactly Raz et al.'s
slowest condition. The two papers' slow ends line up. Treat this as the working
interpretation and flag it if a conclusion turns on the factor of 2.

The same ambiguity applies to Raz et al., whose dots also move in opposite
directions inside and outside the object: their "0.05 to 2 °/s" is stated as the
dots' velocity, so the relative velocity across the object boundary is 0.1 to 4 °/s.

## What the model has to reproduce

1. **A motion-defined form deficit with contrast-defined form spared, on stimuli
   that differ only in how the form is defined.** 14 eyes abnormal for MD letters
   with normal contrast sensitivity for the identical dotted CD letters, against 2
   showing the converse. This is a sharper version of feature 2 in
   [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md), because here the
   static control is not merely "a static object" but the *same dotted letters*
   with the surround switched off. A model that damages MD reading must leave CD
   reading of the same array nearly intact.
2. **The deficit is not explained by acuity loss.** The blur control gives the model
   a quantitative bar: a manipulation that halves the model's MD read-out must not
   also be one that would degrade a static acuity read-out by the equivalent of
   +3 D of blur.
3. **The dissociation is asymmetric.** 14 versus 2. Motion-defined form is the more
   vulnerable of the two, not merely a separately-damageable one.

## Speed range: the same problem as Raz Figure 1

Under the current anchor (`pars/shModelUnits.m`: 1 px/frame = 5 °/s):

| quantity | °/s (relative) | px/frame | inside the model's range? |
|---|---|---|---|
| normal limit for motion sensitivity, 10 s/deg | 0.10 | 0.020 | no |
| slowest patient thresholds (~2 s/deg) | 0.50 | 0.100 | no |
| apparatus maximum | 0.90 | 0.180 | no |

The model's V1 population is tuned from 1.08 to 8.16 °/s and MT's slowest moving
unit sits at 5 °/s. **The whole of Figure 4 lies below the model's speed range** —
worse than Raz Figure 1, whose 1 and 2 °/s conditions at least reach the bottom of
V1's range. See [`../docs/RGC_lagged_preset_summary.md`](../docs/RGC_lagged_preset_summary.md)
§7.2.

So, as with Raz: **do not compare model output to these speeds condition by
condition.** What is testable now is feature 1 — the motion-defined versus
contrast-defined dissociation on matched stimuli, over whatever speed range the
model can represent — and feature 3, its asymmetry. Feature 2 becomes testable once
there is a model-side static acuity read-out to blur.
