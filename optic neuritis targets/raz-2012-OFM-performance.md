# Raz et al. (2012), Figure 1 — object-from-motion performance vs dot speed

**Source.** Raz, Dotan, Chokron, Ben-Hur & Levin, *Demyelination affects
temporal aspects of perception: an optic neuritis study*, Annals of Neurology
2012;71(4):531–538, [doi:10.1002/ana.22692](https://doi.org/10.1002/ana.22692).

**Targets deficit (b)** — worse recognition of shapes defined only by motion, at
slow speeds.

**The figure itself is not in this repository.** It is copyrighted (Wiley), and the
PowerPoint export is kept locally and gitignored. This file holds the numbers read
off it, which is what the model is actually compared against.

## What the experiment measured

Observers identified an object defined only by the relative motion of random dots
(an object-from-motion, or OFM, task) — a variation of Regan's task, see
[`regan-1991-MD-vs-CD-letters.md`](regan-1991-MD-vs-CD-letters.md). Dot speed was
varied over 0.05, 0.10, 0.25, 0.50, 1 and 2 °/s. A static, luminance-defined object
was tested as a control condition — the same identification task with no motion
involved. Coherent moving noise, moving as a whole so that motion but no object is
apparent, was presented as foils.

**The dots inside the object move one way and the dots outside it the other**, so
the relative velocity across the object boundary is **twice** the quoted dot
velocity: the axis labelled 0.05 to 2 °/s spans relative speeds of 0.1 to 4 °/s.
The paper quotes the dots' velocity; both are recorded here because the factor of 2
matters for any comparison against the model's speed range.

Stimuli were viewed at 50 cm, each preceded by a 980 ms fixation and shown until
response or for at most 4 s, in blocks of 60 OFM stimuli (20 per velocity), 12
moving-noise foils and 10 static objects.

Performance of the optic-neuritis eye is expressed as a **percentage of the control
subjects' mean in that phase**, so 100 means normal. Patients were tested at four
time points: acute, 1 month, 4 months, and 12 months.

**Only the lower three velocities — 0.05, 0.10 and 0.25 °/s — entered the paper's
own analyses**, "due to their increased sensitivity in detecting the motion
perception deficit following ON". Every OFM number in the paper's other figures is
therefore an average over that band, not over the axis shown here. See
[`raz-2012-VEP-and-dissociation.md`](raz-2012-VEP-and-dissociation.md).

## The numbers

Values are **digitized from the published figure by eye**, not taken from a table
in the paper.

| dot speed | acute | 1 month | 4 months | 12 months |
|---|---|---|---|---|
| 0.05 °/s | 11 | 24 | 39 | 54 |
| 0.10 °/s | 12 | 35 | 39 | 62 |
| 0.25 °/s | 17 | 43 | 56 | 71 |
| 0.50 °/s | 24 | 58 | 65 | 66 |
| 1 °/s | 36 | 74 | 71 | 77 |
| 2 °/s | 45 | 77 | 74 | 76 |
| **static (luminance)** | **83** | **86** | **91** | **90** |

Half-width of the error bars, in the same units:

| dot speed | acute | 1 month | 4 months | 12 months |
|---|---|---|---|---|
| 0.05 °/s | 22 | 33 | 40 | 46 |
| 0.10 °/s | 20 | 35 | 38 | 47 |
| 0.25 °/s | 26 | 40 | 41 | 43 |
| 0.50 °/s | 30 | 38 | 41 | 42 |
| 1 °/s | 39 | 37 | 43 | 37 |
| 2 °/s | 44 | 35 | 42 | 35 |
| static | 35 | 33 | 30 | 25 |

### How much to trust these

- **Digitized, so treat the means as ±2–3 and the error half-widths as ±4.** The
  table was re-read independently from the PDF on 2026-08-28 and every cell agreed
  to within 1–2 units, so the stated precision is right. Use them for the *shape*
  of the effect. Do not quote any single cell as a published
  value; if a number has to appear in a manuscript, get it from the authors or
  refit from the paper's own statistics.
- **What the error bars represent is not stated in the figure caption.** They are
  probably standard deviations — at the acute time point the lower whisker runs
  below zero, which rules out a confidence interval on a bounded quantity. Do not
  assume, and do not compute a significance test from them.
- **The number of patients per time point is 21, 20, 18 and 14** at the acute, 1-,
  4- and 12-month phases. This is not in the Figure 1 caption — it is stated in the
  Figure 2 caption, and it does confirm the suspicion that attrition thins the later
  columns. The 12-month column rests on 14 subjects, two-thirds of the acute one.
- The cohort is 21 patients with first-ever unilateral acute ON, aged 18–59
  (mean 29 ± 9.5), against 21 controls matched for age, gender and dominant eye.

## What the model has to reproduce

Three features, in order of how strongly they constrain the model:

1. **The deficit is graded by speed, and worst at the slowest speeds.** At every
   time point performance rises monotonically with dot speed across 0.05 to 1 °/s.
   Acute: 11% of normal at 0.05 °/s against 45% at 2 °/s.
2. **The deficit is motion-specific.** Static, luminance-defined performance is
   83–91% of normal at *every* time point, including acute. Whatever the model
   damages must leave a static form task nearly intact while crushing the motion
   task. A general reduction in contrast or overall gain would not do this.
3. **Recovery is largest where the deficit is largest.** From acute to 12 months,
   0.05 °/s goes 11 → 54 while 2 °/s goes 45 → 76. The slow end starts worst and
   gains most, yet is still furthest from normal at 12 months. Any recovery account
   has to reproduce a *rate* difference across speeds, not a uniform lift.

## The problem: this whole figure sits below the model's speed range

At the current anchor (`pars/shModelUnits.m`: 1 px/frame = 5 °/s) the figure's
x-axis converts as:

| dot speed | px/frame | inside the model's range? |
|---|---|---|
| 0.05 °/s | 0.010 | no — below everything; unreachable in any units (see below) |
| 0.10 °/s | 0.020 | no |
| 0.25 °/s | 0.050 | no |
| 0.50 °/s | 0.100 | no |
| 1 °/s | 0.200 | marginal — just below the slowest V1 unit |
| 2 °/s | 0.400 | yes, but still well below MT's slowest moving unit |

The model's V1 population is tuned from **1.08 to 8.16 °/s** and MT's slowest
moving unit sits at **5 °/s**. So of the six motion conditions in the target
figure, **only 2 °/s is clearly inside the V1 population's range, and none reaches
MT's slowest moving unit.** The clinically interesting slow end is not
under-sampled by the model — it is outside it.

Re-anchoring does not fix this, and the 0.05 °/s condition is unreachable at any
anchor: the reasoning is in
[`../docs/UNITS_AND_SCALE.md`](../docs/UNITS_AND_SCALE.md) §6. Closing the gap
would mean lengthening the temporal filters and adding slow units to the V1 and MT
populations.

Note also that the relative speeds are twice the values in the x-axis column above,
which shifts the whole table one row up this list without changing the conclusion.

**Until then, do not compare model output to this table condition by condition.**
Compare shapes: whether the model's motion read-out degrades with slowing speed
while a static read-out is spared, over whatever speed range the model can actually
represent. Feature 2 above — the motion-specific sparing of static performance — is
the one that can be tested honestly right now, because it does not depend on
hitting the absolute speeds.
