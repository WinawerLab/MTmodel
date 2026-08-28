# Raz et al. (2012), Figures 2 and 3 — VEP latency, and the amplitude/latency dissociation

**Source.** Raz, Dotan, Chokron, Ben-Hur & Levin, *Demyelination affects temporal
aspects of perception: an optic neuritis study*, Annals of Neurology
2012;71(4):531–538, [doi:10.1002/ana.22692](https://doi.org/10.1002/ana.22692).

Same study, same cohort, as [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md),
which covers Figure 1. This file covers **Figure 2** (the 12-month time course of
VEPs and of visual function) and **Figure 3** (visual function split by VEP
amplitude, and then by VEP latency).

**Targets both deficits.** Figure 2B is the direct target for deficit (a), a
slower VEP. Figure 3C is the target for the *link* between (a) and (b): it is the
closest thing in the clinical literature to the model's own driving question,
because it varies conduction latency with the amount of input held fixed.

**The figures themselves are not in this repository** — copyrighted (Wiley). What
is committed is the numbers read off them.

## Cohort

21 patients, first-ever unilateral acute optic neuritis, aged 18–59 (mean 29 ± 9.5),
enrolled during hospitalisation. 21 age-, gender- and dominant-eye-matched controls.
Two patients had a recurrent attack during follow-up and were excluded from analysis.

**Subjects per time point: 21 (acute), 20 (1 month), 18 (4 months), 14 (12 months)**
— stated in the Figure 2 caption. This also settles the open question in
[`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md): the n *is* recoverable,
it does differ across time points, and the 12-month column rests on 14 subjects.

VEP: pattern-reversal, full-field checkerboard, 60 arcmin checks, screen 17° × 14°,
O1/O2 referenced to Fz, P100 measured. VEP latency was assessed at the **acute, 4-
and 12-month phases only** — there is no 1-month latency point. Patients whose
waveform was unobtainable were excluded from the latency analysis (n = 7 acute,
n = 2 later).

## Figure 2B — VEP latency over time

Digitized from the figure. The calibration was checked against the paper's own
normal-mean reference line, which digitizes to 104.2 ms against a stated 103.8 ms,
so the vertical scale is good to about 0.5 ms; the residual uncertainty is in
locating the marker centres, roughly ±1 ms.

| phase | P100 latency (ms) | error bar (ms) | vs normal mean |
|---|---|---|---|
| acute | 146 | 133 – 159 | *** |
| 4 months | 139 | 129 – 148 | *** |
| 12 months | 133 | 127 – 139 | *** |

Reference values quoted by the paper, not digitized:

- normal population **mean 103.8 ms**;
- upper limit of the **normal range 115 ms**.

So the affected eye is **+42 ms** at the acute phase, **+35 ms** at 4 months and
**+29 ms** at 12 months relative to the normal mean, and it never re-enters the
normal range. The shortening between acute and 4 months is significant; the change
between 4 and 12 months is not.

## Figure 2A, C, D, E — amplitude and visual function over time

Same digitization. Performance is a percentage of normal: 100% of visual acuity =
1 decimal, 100% of contrast sensitivity = Pelli-Robson logCS 1.84, 100% of OFM =
the control subjects' mean *in that phase*. VEP amplitude is the affected eye as a
percentage of the fellow eye.

| phase | VEP amp (AE/FE %) | VA (%) | CS (%) | OFM (%) |
|---|---|---|---|---|
| acute | 62 | 44 | 49 | 14 |
| 1 month | — | 81 | 78 | 36 |
| 4 months | ~100 | 87 | 84 | 46 |
| 12 months | 115 | 87 | 86 | 60 |

Error bars, as half-widths in the same units:

| phase | VEP amp | VA | CS | OFM |
|---|---|---|---|---|
| acute | 35 | 45 | 40 | 22 |
| 1 month | — | 38 | 35 | 23 |
| 4 months | 34 | 33 | 32 | 25 |
| 12 months | 45 | 37 | 37 | 26 |

There is no 1-month VEP point. The 4-month amplitude point sits on the printed
100% reference line and could not be separated from it, hence the tilde.

### These agree with everything the paper states in prose

This is the reason to trust the digitization, and it is worth recording:

- acute VA digitizes to 43.7%; the paper states VA at presentation was **0.44 decimal**;
- one-month improvements digitize to **36.8 / 28.2 / 21.1** for VA / CS / OFM; the
  paper states **36, 27 and 20%**;
- the 1-to-4-month rates digitize to **2.0 / 2.1 / 3.4 %/month**; the paper states
  **2, 2.5 and 3 %/month**;
- 12-month OFM digitizes to 59.8%; the paper states the maximum reached was
  **<60% of normal**.

Every independent check lands within about 1 unit, so treat these means as **±2**
and the error half-widths as **±3**.

### What the error bars are is still not stated

Neither the Figure 1 nor the Figure 2 caption says. They are almost certainly
standard deviations: the acute VA lower whisker runs to −3% and the acute OFM
lower whisker to −8%, which rules out a confidence interval on a bounded
quantity. **Do not compute a significance test from them.** The paper's own
asterisks are t tests of the per-patient delta from normal against zero.

## Figure 3 — the dissociation

The data for each patient are taken from the **latest time point available**, so
Figure 3 is a cross-sectional endpoint analysis, not a time course. Eyes are split
first by VEP amplitude, then — within the intact-amplitude group — by VEP latency
at the group median of 136 ms.

Digitized bar heights, in percent of normal. Treat as **±3**.

| group | n | VA | CS | OFM |
|---|---|---|---|---|
| **A.** impaired VEP amplitude | 5 | 31 * | 38 * | 9 *** |
| **B.** intact VEP amplitude | 16 | 98 | 95 | 57 *** |
| **C.** intact amplitude, latency ≤136 ms | 8 | 98 | 98 | 68 |
| **C.** intact amplitude, latency >136 ms | 8 | 99 | 94 | 42 |

Asterisks are the paper's, and denote a significant reduction of the affected eye
**against the normal value** (* p<0.05, *** p<0.001) — they are *not* tests
between the rows. Upper error whiskers, digitized: row A reaches ~72 / ~72 / ~26;
row B ~101 / ~102 / ~93; row C ≤136 ~101 / ~103 / ~93 and >136 ~99 / ~101 / ~81.

Note the caption and the body text disagree about the split: the text says
"≤136 or >136 milliseconds", the caption says "<136 milliseconds, n = 8; >136
milliseconds, n = 8". Immaterial here, but do not quote the boundary as exact.

## What the model has to reproduce

In descending order of how strongly it constrains the model:

1. **Latency alone, with input held fixed, produces a motion-only deficit.** This
   is row C, and it is the single most useful line in either paper. Within eyes
   whose VEP *amplitude* has recovered — that is, with the amount of signal
   reaching cortex normal — a median split on conduction latency leaves visual
   acuity (98 vs 99) and contrast sensitivity (98 vs 94) essentially untouched
   while object-from-motion falls **68 → 42**. The model-side analogue is direct:
   impose a conduction delay with no change in gain, and ask whether a motion
   read-out degrades while a static read-out does not.
2. **Amplitude explains the static functions; latency does not.** Row A against
   row B: when amplitude is impaired, everything is impaired (VA 31, CS 38, OFM 9).
   When amplitude is intact, VA and CS return to normal *even though every ON eye
   still had a prolonged latency*, while OFM stays at 57%. Whatever the model
   damages must have two separable consequences, one gain-like and one timing-like.
3. **Latency recovers partially and stops.** 146 → 139 → 133 ms against a normal
   103.8, with the only significant change in the first 4 months. A model of
   recovery must not return latency to normal.
4. **OFM recovers least and latest.** 14 → 36 → 46 → 60% while VA goes 44 → 87 and
   CS 49 → 86. Motion is the most impaired at baseline and the least recovered at
   12 months.

Also recorded, from the paper's own statistics rather than the figures, because it
constrains the same claim: across the acute-to-4-month change, **VEP amplitude
change correlated with CS change (r = 0.62, p = 0.01) but not with OFM change
(r = 0.13, n.s.), while VEP latency change correlated with OFM change (r = −0.87,
p = 0.0005) but not with CS change (r = 0.004, n.s.)** — Figure 4. That is the
same double dissociation as row C, measured longitudinally instead of
cross-sectionally.

## Caveats before any quantitative claim

- **Figure 3C has no between-group test.** The 26-point OFM difference between the
  two latency groups is a difference between two n = 8 groups whose asterisks are
  against normal, not against each other. The paper describes it as "an
  association", and does not report a test of the gap. Reproduce the *sign and
  rough size*; do not fit to 26.
- **The group mean latencies of the two halves of row C are not reported**, only
  that the split is at the median, 136 ms. So the effect size in milliseconds is
  unknown. The split point is +32 ms above the normal mean; the difference between
  the group means is plausibly of order 10–30 ms.
- **That is 0.5 to 1.5 frames on the model's temporal grid** (`pars/shModelUnits.m`:
  1 frame = 20 ms). The manipulation this figure asks the model to make is at or
  below the model's own temporal resolution. Any model-side version of row C has to
  say how a sub-frame delay is imposed, or work at a finer time step.
- **The model-side observable for VEP latency is still not settled** — `docs/TODO.md`
  §4. Rows 3 and 4 above are recorded so that they are ready when it is; the
  millisecond values in the Figure 2B table must not be compared against a model
  number until §4 is closed.
- **The OFM numbers in Figures 2 and 3 are not the whole speed range.** Only the
  lower three velocities — 0.05, 0.1 and 0.25 °/s — entered the paper's analyses;
  see the note in [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md).
  Every OFM value on this page is therefore an average over a speed band that lies
  **entirely below the model's range**, and the sanity check bears that out: the
  mean of the three slowest bars in Figure 1 is 14 / 33 / 44 / 62% at the four
  phases against 14 / 36 / 46 / 60% here. Feature 1 above is testable as a *shape*
  — motion read-out spared or not spared relative to a static read-out — not at
  these absolute speeds.
