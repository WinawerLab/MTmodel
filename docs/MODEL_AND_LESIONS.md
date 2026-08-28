# The model, and what we have measured

**The standing report.** How the model is built, why it is built that way,
everything that has been measured, and how far each result can be trusted.

Rewritten 2026-08-25. Read `AGENTS.md` first for orientation and for how to run
things. Read `docs/TODO.md` for what is still open.

Contents:

1. [The question, and the units](#1-the-question-and-the-units)
2. [How the model is built](#2-how-the-model-is-built)
3. [What a lesion means here](#3-what-a-lesion-means-here)
4. [What has been measured](#4-what-has-been-measured)
5. [Validity ledger — what still holds](#5-validity-ledger--what-still-holds)
6. [Decisions we reversed, and why](#6-decisions-we-reversed-and-why)
7. [Where the noise work fits](#7-where-the-noise-work-fits)

---

## 1. The question, and the units

> Can damage at the level of retinal ganglion cells (RGCs) explain the
> optic-neuritis pattern of **(a) a slower visual evoked potential** and
> **(b) worse recognition of shapes defined only by motion, at slow speeds**?

To answer it we need two things. First, a model in which "damage to retinal
ganglion cells" is something you can actually *state*: which cells are hit, by how
much, and how that varies across the visual field. Second, healthy behaviour that
is trustworthy enough that a change caused by damage means something. Everything
below serves one of those two needs.

The physical scale is set in `pars/shModelUnits.m`. The derivation is in
`docs/RGC_lagged_preset_summary.md` §7.1:

**1 pixel = 0.1 deg · 1 frame = 20 ms (50 frames/sec) · 1 pixel/frame = 5 deg/sec**

> **This changed on 2026-08-27 and it disagrees with the published paper.** SH
> 1998 Appendix I, p. 761 would give 0.430 deg/pixel, 26.9 ms/frame and 16
> deg/sec per pixel/frame. Every deg/s figure below is therefore **3.2x smaller**
> than the same figure computed SH's way. Nothing the model computes changed —
> only the labels. Full statement of the departure, and why, in
> `RGC_lagged_preset_summary.md` §7.1.

Useful conversions for the clinical speed range:

| clinical speed | model units |
|---|---|
| 1 deg/s | 0.2 px/frame |
| 2 deg/s | 0.4 px/frame |
| 5 deg/s | 1.0 px/frame |
| 10 deg/s | 2.0 px/frame |

---

## 2. How the model is built

### 2.1 One code path, two presets

The Simoncelli–Heeger model drives V1 from an abstract mathematical basis: spatial
and temporal derivatives of the filtered stimulus, orders 0 to 3. The idea the
whole design rests on is that this is not a *different kind* of front-end from a
retina. It is one point in a space of front-ends, all of which are "some set of
filtered channels, added together to make V1 neurons."

So there is a single class-based code path. `pars.rgc.classes` is a list of cell
classes. Each class has a spatial receptive field, a temporal filter, a
rectification and a gain. `shModelV1LinearFromClasses` projects the stimulus
through them, and `pars.rgc.combine` says how V1 reads them out: `'steer'` for the
analytic SH steering, `'weights'` for a fitted matrix. **Presets fill in that list.
They are not separate branches of code.** That is what lets the biological
front-end stand in for the mathematical one without a second copy of the model.

There are exactly two ways to run it, and `shPars` returns each one fully
assembled:

| call | front-end |
|---|---|
| `shPars` or `shPars('derivative')` | `shRgcClassesDerivative` — the SH basis |
| `shPars('lagged')` | `shRgcClassesMidgetParasolLagged` — the biological front-end, with both MT streams on (§2.3) |

Anything else — a lesion, a changed gain, a cleared `mtMix` — is a *variation* on
one of these two, made by editing the struct a preset returned. `shPars` refuses
any other preset name.

> **The dispatch trap.** `shModelV1Linear` rebuilds `pars.rgc.classes` from the
> preset named in `pars.rgc.mode`, which defaults to `'derivative'`. `shPars` now
> sets `'custom'` for you, so this only bites if you build `pars.rgc.classes` by
> hand — don't. If you do, and you forget `pars.rgc.mode = 'custom'`, your classes,
> your fitted weights and your lesion edits are discarded in silence and you
> compute the plain derivative preset instead. This produced a run of mislabelled
> results before it was caught on 2026-07-16. The giveaway was `'lagged'` and
> `'derivative'` outputs that were identical bit for bit, which a nonlinear model
> cannot produce.

### 2.2 The biological front-end

`pars/shRgcClassesMidgetParasolLagged.m` is the live biological front-end:
{parasol, midget} × {ON, OFF} × lags {0, 1, 2, 3} = **16 classes**. Each class is a
difference-of-Gaussians receptive field with a causal difference-of-gamma temporal
filter, half-wave rectified. There is no spatial offset and no quadrature filter;
direction selectivity comes from the SH read-out, for the reason in §6.1. Each
class feeds read-out orders 0 to 3, which is 10 combinations, giving **160
features**, combined by a fitted weight matrix.

**What the lags are for.** A single RGC filter with one or two phases cannot supply
SH's high-temporal-frequency channels (orders 2 and 3). That gap held an earlier
preset to about 0.68 correlation with the original V1. But *a weighted difference
of the same filter at staggered delays approximates a time derivative*, the same
trick as a finite difference. So lagged copies let the read-out build the high
orders while every individual channel stays simple enough to be biologically
plausible. **The high-order structure lives in the combination, not in any cell.**

A full description of the front-end, with figures and with the physical sizes of
every parameter, is in `docs/RGC_lagged_preset_summary.md`.

Two known problems with the scale, carried openly (details in that document, §7.1):
at 0.1 deg per pixel the midget centre σ is 0.08 deg against roughly 0.02–0.05 deg
for real midget cells, so the midget-to-parasol *ratio* is right but the midget is
still 2–4x too large, and no choice of pixels-per-degree fixes that because the
model's spatial ladder is about six times more compressed than the real one; and
the 0–3 frame lags are 0–60 ms, far too long for differences in optic nerve
conduction (a few ms) and better justified as lagged LGN cells or delayed
inhibition.

### 2.3 Two streams into MT

This is the step that makes the midget and parasol labels mean something rather
than being decoration.

**What went wrong first.** The 160-column weight matrix was fitted to reproduce
SH's V1, and SH's V1 has no midget/parasol distinction. Nothing in that objective
says MT should be magnocellular, so the fit came out **midget-dominated**: setting
midget classes to zero collapsed MT direction tuning, while setting parasol classes
to zero left it intact and *raised* the peak by 25%. That is Maunsell et al. (1990)
exactly backwards, and it contradicts SH's own premise on p. 754. Any result about
specific cell types measured in that configuration reflects an arbitrary outcome of
the fitting, not biology. This is why the 2026-07 lesion campaign is archived
rather than live.

**Why the fix was cheap.** `shMtWts` computes the V1→MT weights *analytically* from
the geometry of the directions:
`sum(shQwts(dirs) * pinv(shQwts(pars.v1PopulationDirections)))`. Nothing there is
fitted, and it carries no information about cell type. **So MT's dependence on
midget versus parasol input is set entirely by the RGC→V1 weight matrix.** The trap
that follows: you cannot do this by *selecting a subset* of the 28 V1 neurons,
because the `pinv` needs the full set of directions. Mask the *features*, never the
neurons.

**What the anatomy says** (Nassi & Callaway 2006, 2007). Layer 4B cells that
project to MT are 76% spiny stellate and receive input only from 4Cα, which is
magnocellular-dominated; after an injection into MT, about 96–97% of the two-synapse
label lands in 4Cα. MT *does* get parvocellular input, but by a detour of 3 to 5
synapses through the thick stripes of V2, and the 4B cells projecting to V2 are 83%
pyramidal and mix magnocellular and parvocellular input. The structural point:
**biology puts the M/P selectivity in two separate populations, not in one graded
weighting.** The old model had one population, and it was the mixed one.

**The design.** MT pools a mixture of two streams, formed after normalization in
`shModelV1ComplexForMt` so that the two streams do not share a V1 normalization
pool:

```
popMT = (1 - alpha) * popA  +  alpha * delay(popB, d)
```

- **popA, "4B→MT", the fast magnocellular drive.** The same 28 neurons refitted
  against the same SH target, with the feature matrix masked down to the 80 parasol
  columns (`shClassFeatureMask(pars, '^parasol')`). Its parasol share is 1.0 by
  construction.
- **popB, "→V2→MT", the slow minority drive.** The **existing mixed fit,
  unchanged**. This is justified because the V2 relay carries mixed M and P input.
  No second fit was needed, and popB stays the validated V1 stage.
- **alpha = 0.10, d = 0.** The midget drive is *imposed and never fitted*. If the
  midget columns were unmasked, ridge regression would re-inflate the midget share,
  because nothing in the objective holds it down. `d = 0` because the V2 detour is
  roughly 5–10 ms, well under one 20 ms frame — and the difference in latency is
  already there for free, since the midget filter peaks at about 80 ms against the
  parasol filter's 20 ms.

The MT stage is linear in `pop`, so the mixture is exactly
`(1-alpha)*MT(popA) + alpha*MT(popB delayed)`. That makes knockout bookkeeping
trivial. Two bit-exact checks confirm the plumbing: setting stream A to the default
weights reproduces the no-mixture baseline at both `alpha = 0` and `alpha = 1`.
`'v1Complex'` is untouched, so **the validated V1 stage has not changed.** Only MT
sees the mixture.

The measurements that justify `alpha = 0.10` are in §4.4.

---

## 3. What a lesion means here

Three independent choices. The results in §4.7 are organised by them.

**Axis — what is damaged**

- **amplitude**: the gain is multiplied down.
- **delay**: the temporal filter is shifted by a whole number of frames.
- **both together.**

**Scope — which cells**

- **class-agnostic**: all RGC classes equally. This is a statement about the optic
  nerve as a whole.
- **class-selective**: parasol only, midget only, ON only. This is the statement
  only a biological front-end can make, and it needs the two-stream MT of §2.3 to
  be interpretable.

**Spatial profile — how the damage varies across the visual field**

- **uniform**: the same everywhere.
- **non-uniform**, through the amplitude and delay maps in
  `shApplyRgcImpairment`: *random* (independent at every pixel), *patchy*
  (correlated across space, Gaussian-smoothed with σ = 3), or *coupled* (low
  amplitude goes with high delay, which is the most realistic).

Mechanically: spatial maps go through `pars.rgc.impairmentAmplitudeMap` and
`impairmentDelayMap`; damage to particular cell types is applied by editing
`pars.rgc.classes(i).gain` or `.temporalKernel` before the forward pass. Weights
are **not** refitted after a lesion. Optic neuritis is a change within one person,
so holding the weights fixed isolates the RGC effect from any cortical
re-adaptation.

---

## 4. What has been measured

### 4.1 The derivative preset reproduces the original model exactly

The derivative preset is a *measuring instrument*, not a scientific claim. Its job
is to prove that the class-based machinery adds nothing of its own. With
`pars.rgc.classes = shRgcClassesDerivative(pars)` and `combine = 'steer'`, the class
path reproduces the old no-RGC model **exactly — error = 0 at `nScales = 1`**,
including the `resdirs` output.

This is the constraint that cannot be broken. `tests/runAllTests.m` (12 tests)
enforces it, and the old RGC-disabled path stays in the tree purely as the
machine-precision reference. Every later claim about the biological preset is a
claim about a *difference from* something known to be exactly right.

### 4.2 The lagged preset reproduces SH's V1 closely

From `tests/testClassPathBiological.m`, fitted on 6 stimuli and evaluated on 4 it
had not seen: **pooled r = 0.984**, flat across temporal frequency, against about
0.68 for the retired preset (§6.1).

Read that with four qualifications. None of them is cosmetic.

1. It is a match **to the SH model, not to data**. The target is the old V1 output.
2. The pooled figure hides the spread across neurons: median 0.984, best 0.997,
   **worst 0.709**.
3. The samples are not independent. Neighbouring (y, x, t) locations overlap
   heavily under 9-tap filters, so the effective sample size is far below the
   nominal one.
4. **A later measurement disagrees.** `explore/fitMagnoMtPopulation.m` put the same
   mixed population at median r = 0.93–0.95, on a different stimulus with
   differently cached weights. The two are not directly comparable, but
   **0.984 should not be quoted as a stable property of the preset** until the
   difference is understood.

The healthy lagged copies are **not** a pathological conduction delay. Timing
deficits in optic neuritis go through `pars.rgc.impairmentDelayMap` or through
edits to a class's temporal filter.

### 4.3 MT's nominal speeds are not its measured speeds

`pars.mtPopulationVelocities(:,2)` holds three speed tiers: 0, 1 and 6 px/frame,
which is 0, 5 and 30 deg/s at the anchored scale. Those are *construction*
parameters for the MT pooling weights. At the top tier they are not the tuning you
actually get. Measured with drifting dots at each neuron's preferred direction
(`explore/measureMtSpeedTuning.m`, 2026-08-25):

| nominal | derivative | lagged (both streams) |
|---|---|---|
| 0 deg/s | low-pass, peak ≤ 0.6 deg/s | low-pass, peak ≤ 0.6 deg/s |
| 5 deg/s | **4.7** (4.4–4.8) | **5.2** (5.0–5.3) |
| 30 deg/s | **15.5** (14.7–15.7) | **18.3** (17.1–18.9) |

The 1 px/frame tier lands on its nominal speed. The 6 px/frame tier peaks near
**half** its nominal value. The curves have a clean
interior peak with falloff on both sides, so this is real tuning and not an
artifact of the grid. It fits with 6 px/frame sitting past what the filter bank can
represent, since the V1 filters peak at 0.2148 cycles/sample on both axes.

**Do not quote 30 deg/s as those neurons' preferred speed.** The lagged preset also
prefers systematically faster speeds than the derivative one, by 11% at the low
tier and 18% at the high tier. That is the expected direction, since stream A is
parasol-masked and the parasol filter peaks at 1 frame against the midget filter's
4.

*Caveat:* 7 of the 19 MT neurons were probed, 3 per moving tier, spread across
directions, on a 13-point speed grid. Within a tier the spread was under 0.5
px/frame. Peak locations carry roughly ±5%.

### 4.4 The two-stream MT reproduces Maunsell's knockouts

Two stopping criteria were written down in advance, and both were met.

**Criterion 1 — how good is the masked fit?** The partial failure that was
predicted did happen, and it happened exactly where predicted. Reconstruction of
the old V1 target, binned by each neuron's preferred temporal and spatial
frequency:

| tf/sf band | neurons | median r, B (mixed) | median r, A (parasol) | loss |
|---|---|---|---|---|
| 0.22–0.30 (slow) | 12 | 0.95 | ~0.55 | ~0.40 |
| 0.43–0.81 (mid)  | 9  | 0.93 | ~0.75 | ~0.17 |
| 1.41–1.63 (fast) | 7  | 0.90 | ~0.82 | ~0.07 |

The pattern is monotonic. The parasol-only basis is a **good** V1 model for the
fast neurons — the ones MT weights most heavily — and a poor one for the slow
sustained ones. That is precisely the division of labour Nassi & Callaway describe.
The median over the whole set (0.930 → 0.706) should **not** be quoted as the
headline number.

Population B reproduced the previously recorded parasol share of the mixed fit
(0.249–0.377 of the absolute weight per V1 neuron, median 0.316), which confirms
the setup matches the existing fit. Population A is 1.0 by construction, and costs
little in gain: the median peak response of A relative to B is 0.86.

The mechanism shows up in the tuning rather than in the residual
(`explore/measurePreferredTfSf.m`). The nominal preferred spatial and temporal
frequency is identical for both populations by construction. Note that this
measurement bins the 28 V1 neurons **differently** from the reconstruction table
above: here "slow" means tf/sf < 0.5 and takes 13 neurons, where the table above
uses the narrower band 0.22–0.30 and takes 12. The two sets are not the same set.
But at the slow end, population A prefers a higher temporal frequency than B for
**13 of 13** neurons (median 1.40× nominal, against B's 0.94×), while at the fast
end A and B agree for 6 of 7. Denied midget input, the slow neurons drift toward the frequency the fast
parasol filter actually prefers.

| band | nominal | B (mixed) | A (parasol) |
|---|---|---|---|
| slow (tf/sf < 0.5, n = 13) | 1.98 Hz | 1.90 Hz | **2.49 Hz** |
| fast (tf/sf > 1.0, n = 7) | 6.81 Hz | 9.71 Hz | 9.71 Hz |

Note that both populations overshoot the nominal value at the fast end, 9.71
against 6.81 Hz. That is a property of the model, not of the mask.

*Caveats:* the log grid steps by 1.31×, so the 1.40× shift is about one step. It is
credible because it is unanimous across all 13 slow neurons, not because any single
row is precise. And temporal frequency was swept at the nominal spatial frequency
and vice versa, so these are one-dimensional cuts through a surface that may not be
separable.

**Criterion 2 — does it reproduce Maunsell?** Percent change from each
architecture's own intact model. The "pop" columns are over the 19-neuron MT
population.

| architecture | knockout | dir_peak | dir_DSI | coh_peak | pop med \|%\| | pop >20% |
|---|---|---|---|---|---|---|
| mixed (old) | parasol (M) | **+25.1** | −3.9 | −72.7 | 4.1 | 11% |
| mixed (old) | midget (P) | **−100.0** | −100.0 | −94.0 | 33.0 | 100% |
| alpha=0.05 | parasol (M) | −68.2 | −81.7 | −89.2 | 85.4 | 95% |
| alpha=0.05 | midget (P) | −18.3 | −0.0 | −8.9 | 1.4 | 5% |
| **alpha=0.10** | **parasol (M)** | **−60.1** | **−66.6** | **−88.3** | **81.0** | **95%** |
| **alpha=0.10** | **midget (P)** | **−34.0** | **−0.0** | **−17.3** | **2.7** | **5%** |
| **alpha=0.10** | **both** | **−78.7** | **−100.0** | **−90.5** | **89.5** | **100%** |
| alpha=0.20 | midget (P) | −58.5 | −0.0 | −32.7 | 5.7 | 37% |

The old model's backwards result was reproduced almost exactly, which validates the
harness: parasol knockout raises the direction peak by +25.1%, recorded previously
as 1.033 → 1.291 = +25.0%, and cuts coherence by 72.7%, previously 74.6%. The small
gap is consistent with this script seeding the dot stimuli, which the earlier one
did not.

Maunsell reported that a magnocellular block is "pronounced and often complete"
(here: 81% population median, 95% of units); that a parvocellular block has "very
little effect" on the typical unit (2.7% median) while being unequivocal for **a
minority** (5%, or 1 of 19 units, over 20%); and that a combined block "essentially
eliminates" the response (89.5%, DSI −100%). At `alpha >= 0.20` this breaks: the
parvocellular block reaches 37% of units and rivals the magnocellular one. So the
criterion brackets alpha tightly to 0.05–0.10. **0.10 was adopted**, because it
keeps the parvocellular contribution real rather than vanishing, which is what
Maunsell actually reported.

One dissociation appeared that was not designed in. Midget knockout leaves the
direction selectivity index **unchanged at every alpha** (−0.0%) — it scales MT
down without disturbing direction tuning — whereas parasol knockout destroys it.
The two pathways are no longer interchangeable in this model.

Scripts: `explore/fitMagnoMtPopulation.m` (the fit),
`explore/measurePreferredTfSf.m` (the mechanism),
`explore/knockoutAndAlphaCalibration.m` (the knockouts and the alpha bisection).

### 4.5 Midget damage costs slow speeds most — the first clue to the clinical picture

Dependence on midget input concentrates sharply at **low** preferred speed. Median
effect of a midget knockout, by the MT neuron's preferred speed (1 px/frame = 5
deg/s):

| preferred speed | alpha=0.05 | alpha=0.10 |
|---|---|---|
| 0 px/frame | −25.0% | **−45.2%** |
| 1 px/frame | −5.4 to −7.8% | −11.4 to −15.3% |
| 6 px/frame | −0.7 to −0.9% | **−1.4 to −1.9%** |

That is a gradient of 10 to 30 times from slowest to fastest. Damage to the midget
pathway would cost low-speed motion first, and low speed is where the clinical
deficit is.

**Caveat, and it matters.** Every MT neuron here was probed with the *same*
grating, chosen to be optimal for the slow test neuron. So the fast-preferring
units were driven off their peak, and their small effects are partly confounded
with that. This is suggestive, not settled. The proper test is per-neuron speed
tuning with alpha on and off.

### 4.6 MT recovers a motion-defined letter; V1 barely does

`stim/mkMotionLetter.m` builds a Regan-style motion-defined letter: the dots inside
the letter drift one way, the background dots drift the other. This is the
stimulus for deficit (b). Seeded, 0.3125 px/frame (1.6 deg/s at the current
anchor; it was run and reported as 5 deg/s under SH's), letter 'C', 128×128×120, from
`explore/runMotionLetterDemo.m`:

| stage | derivative preset | lagged preset |
|---|---|---|
| V1 opponent d′ | +0.23 | +0.22 |
| MT opponent d′ | **+1.32** | **+1.32** |

The two RGC presets are indistinguishable, which is what you want for a healthy
stimulus and is the right baseline for lesioning.

Three controls establish that the separation really is based on motion:

| control | MT d′ |
|---|---|
| opposite drift (the Regan stimulus) | +1.32 |
| static background | +1.30 |
| **same drift, no relative motion** | **−0.34** |

There is no static cue to exploit: d′ on the time-averaged image is −0.008, on a
single frame −0.002, and dot coverage is 0.3025 inside the letter against 0.3124
outside.

MT d′ is **flat** across the clinical band, while V1's weaker opponent signal does
rise with speed (96×96 field, derivative preset, seeded):

| px/frame | deg/s | MT opponent d′ | V1 opponent d′ |
|---|---|---|---|
| 0.0625 | 0.31 | 1.31 | 0.18 |
| 0.1250 | 0.63 | 1.31 | 0.26 |
| 0.3125 | 1.56 | 1.29 | 0.31 |
| 0.6000 | 3.0 | 1.31 | 0.33 |
| 1.0000 | 5.0 | 1.34 | 0.33 |
| 3.0000 | 15.0 | 1.29 | 0.32 |

An earlier claim that MT d′ improved with speed came from a broken opponent-unit
selector, since fixed.

**Do not use frame-scrambling as the motion control.** Permuting whole frames moves
the letter dots and the background dots by equal and opposite amounts, so relative
direction survives it.

**Largely resolved by the 2026-08-27 re-anchor, but the demo has not been re-run.**
At the old 2.33 pixels per degree a clinically sized letter (2.8 deg) was only
about 6.5 pixels across, so the demo set the letter size in model pixels, implying
about 34 deg, and reported the angular size it used. At 10 px/deg the same letter
is 28 pixels, which is usable directly. The demo still sets size in pixels and
should be revisited.

The related tension has also eased: MT is tuned to {0, 1, 6} px/frame, which is
{0, 5, 30} deg/s at the current anchor rather than {0, 16, 96}. The clinical
low-speed band now straddles MT's slow moving unit instead of sitting entirely
below it. What re-anchoring does *not* touch is the RGC size offset — the midget
centre is still 2–4x too large — or the psychophysical 0.05 deg/s threshold, which
is out of the model's reach in any units (`RGC_lagged_preset_summary.md` §7.2).

### 4.7 Lesion results

**Read §5 before quoting any of these.** Every number below was measured through
the *pre-mtMix* MT, which used a single mixed weight matrix. The class-agnostic
rows are statements about the front-end and V1 and are likely to survive. The
class-selective rows cannot be read as biology.

#### 4.7.1 What has and has not been run

| axis | uniform | non-uniform |
|---|---|---|
| **amplitude** | gain 0.5, all classes ✓ | random U(0.3,0.7) ✓ · patchy σ=3 ✓ |
| **delay** | 2 frames, all classes ✓ | random {0,1,2,3} ✓ · patchy ✓ |
| **both** | **✗ never run** | coupled amplitude↔delay ✓ (tied together) |

Two gaps, both worth closing. There is **no uniform amplitude plus uniform delay
condition at all**. And the only combined condition, `coupled`, ties the two axes
together by construction rather than varying them independently.

#### 4.7.2 Uniform amplitude loss — hits the gain, spares the shape of the tuning

Gain 0.5 on all classes: speed-tuning peaks fall **35% to 49%**, the coherence peak
falls **9% to 18%**, while direction peak, direction selectivity index and tuning
width are **barely touched**. A uniform loss of amplitude scales the response down
without reorganising what the population is tuned to.

**Do not read this as "amplitude lesions don't matter."** §4.8 shows that the flat
direction tuning is divisive normalization absorbing the lesion, and that once
cortical noise is present, the absorption is itself the damage.

#### 4.7.3 Uniform delay — does essentially nothing

2 frames on all classes: about **0%** change in direction peak, direction
selectivity index, tuning width and speed peak, for both presets. This is expected
rather than surprising. A uniform phase shift does not change the time-averaged
response to a periodic drifting grating.

It is also the single most important negative result in the set, because it means
**uniform conduction slowing is invisible to steady-state tuning measures.** If
uniform slowing is going to explain deficit (a), the observable has to be a latency
measure, not a tuning measure.

#### 4.7.4 Non-uniform amplitude loss — behaves like uniform amplitude loss

Random, patchy and coupled amplitude lesions all land in a similar band, around a
**9–18% drop in the coherence peak**, much like the uniform case. Making the
amplitude damage patchy buys little beyond its average.

**§5 of `NOISE_AND_DEMYELINATION.md` predicts this equivalence is an artifact of
the model being deterministic**, and that it should break once cortical noise is
present.

#### 4.7.5 Non-uniform delay — the one large effect

This is the headline result, and it is a dissociation rather than a magnitude:

| delay lesion | coherence peak | high-pass speed tuning |
|---|---|---|
| uniform, 2 frames | ~0% | ~0% |
| patchy (correlated across space) | tracks uniform | tracks uniform |
| **random (per-pixel {0,1,2,3})** | **−59% derivative / −39% lagged** | **−64% / −55%** |

**It is delay that is desynchronised from one location to the next, not the size
of the delay, that disrupts motion and coherence pooling.** Timing that varies
independently across space breaks the spatial pooling that coherence and speed
tuning depend on. A delay that is uniform, or correlated over patches, largely
preserves it.

Note the word *patchy* carefully. It is the name of one specific condition —
Gaussian-smoothed, σ = 3, correlated across space — and that condition does
**nothing**. The large effect is `delay_random`, which is independent at every
pixel. Do not use "patchy" as a loose word for "spatially heterogeneous" here; the
two conditions give opposite answers.

This is the sharpest thing the model has said. It suggests a single insult
producing both clinical signs: *uniform* slowing gives the VEP latency,
*desynchronised* conduction across the field gives the motion deficit.

**But there is a standing tension.** The heterogeneous-delay effect was largest on
the **high-pass** neuron (1–10 px/frame = 5–50 deg/s). The clinical deficit is at
**low** speeds. The low-pass neuron (0.0375–0.6 px/frame = 0.19–3 deg/s), which is
squarely the clinically interesting band, was **not reported** under
`delay_random`. So this is currently unknown rather than contradicted. It is the
highest-value lesion experiment (`docs/TODO.md` §2), and the speed-graded midget
dependence of §4.5 is the candidate mechanism that would resolve it.

#### 4.7.6 Class-selective lesions — do not use these

Parasol-only and ON-only lesions were run, but through the midget-dominated MT of
§2.3, so **even the sign of the parasol effect is an artifact of the fitting.**
Nothing measured here is usable. Re-run them through the two-stream MT with
`explore/compareLesionsToBaseline.m` before quoting anything.

A record of what was run, not of what is known: parasol-only gain 0.3, which
*raised* the direction peak by 22%, broadened the tuning by 7.4%, degraded the
direction selectivity index by 3.2% and cut coherence by 47% seeded (−52%
unseeded); and an ON-only 1-frame delay.

#### 4.7.7 Seeding changed the numbers

The 2026-07 lesion figure scripts never seeded the random number generator, and
Figs 11–14 use random dot fields, so lesion-versus-baseline differences were mixed
up with dot-sample differences — about 5 percentage points on the parasol coherence
effect. `explore/compareLesionsToBaseline.m` seeds and is the template for any new
lesion script. `validateSHFigs9to14_lesions.m` still does not seed
(`docs/TODO.md`, known problems).

### 4.8 Divisive normalization hides amplitude damage

Measured 2026-08-19 by `explore/compensationIndex.m`. A uniform RGC amplitude
lesion (gain *k* remaining) crossed with stimulus speed, on seeded drifting dots,
for both presets. Still deterministic — no noise anywhere.

The compensation index is **C = 1 − slope/2**, where slope = d log R / d log k.
C = 0 means no compensation, C = 1 means full compensation. The k² reference is
verified rather than assumed: with `v1NormalizationType = 'off'` the measured slope
is 2.000.

**Normalization absorbs most of a uniform amplitude lesion, at every speed.**
C = 0.64–0.92 for the best-driven moving MT unit, and 0.64–0.84 for V1. In plain
terms: **a 50% cut in RGC gain costs only 12–25% of the MT response**, where
without normalization it would cost 75%. Both presets agree, so this is a property
of the normalization and not of the front-end. This quantitatively explains
§4.7.2's null result.

The 12–25% is the response ratio R(k=0.5)/R(k=1) as measured, not a figure derived
from C. Do not try to recover it from the C range above: the slope is fitted over
the whole gain range down to k = 0.1, so extrapolating C back to k = 0.5 gives a
wider band (about 10–39%). C summarises the whole gain series; the ratio is the
single point of clinical interest.

**MT's motion signal is much weaker across the clinical speed band.** Unlesioned
best moving-MT response, lagged preset with two streams:

| stimulus speed, px/frame | 0.0625 | 0.125 | 0.3125 | 0.625 | 1 | 3 | 6 |
|---|---|---|---|---|---|---|---|
| = deg/s | 0.31 | 0.63 | 1.6 | 3.1 | 5 | 15 | 30 |
| MT, moving unit | 0.18 | 0.19 | 0.40 | 0.79 | **0.97** | 0.89 | 0.30 |
| V1, best unit | 0.46 | 0.47 | 0.34 | 0.47 | 0.48 | 0.40 | 0.24 |

Across the three slowest speeds the MT motion signal is 4 to 5 times smaller than
at 0.625–1 px/frame, while V1 is essentially flat over the same range. At 0.0625
px/frame in the derivative preset the *static* MT unit responds 1.60 against the
best moving unit's 0.22, so the population is dominated by a non-motion signal.
The starvation is specific to MT, which is what you would expect given that MT is
tuned to {0, 1, 6} px/frame. Note the shape is a **U**, not a ramp: drive
collapses again at the fastest speed.

**Compensation is strongest where the drive is weakest**, which is the opposite of
what was predicted:

| stimulus speed, px/frame | 0.0625 | 0.125 | 0.3125 | 0.625 | 1 | 3 | 6 |
|---|---|---|---|---|---|---|---|
| = deg/s | 0.31 | 0.63 | 1.6 | 3.1 | 5 | 15 | 30 |
| C, MT moving unit | **0.89** | 0.88 | 0.74 | 0.64 | 0.66 | 0.65 | **0.81** |

C tracks the inverse of drive: about 0.65 in the well-driven middle, about 0.9 at
the starved ends. The likely mechanism, which should be confirmed by instrumenting
the normalization pool directly rather than inferred: at low stimulus speed the
moving units are weakly driven *and* heavily normalized by a pool dominated by
static and low-speed energy. That large pool is what makes their response small to
begin with, and it also keeps them in the compensated regime down to small *k*.

Why this matters for the clinical question is set out in
`NOISE_AND_DEMYELINATION.md` §4 and §6. In short: high C means the lesion drives a
large *increase* in gain, and that gain increase is exactly what would amplify
cortical noise. So at the slow end the signal is smallest and the gain increase is
largest, and both point the same way.

Caveats on this measurement:

- **C describes the mean response only.** It measures the gain headroom that noise
  would act on. By itself it says nothing about discriminability.
- **The size of the starvation is specific to this model.** MT tiles only three
  speeds here. A real MT with denser speed tuning would be less starved in the
  middle of the range, so the 4–5× figure is not a quantitative clinical prediction.
- **Units far from their preferred speed behave erratically and should not be
  read.** They show C > 1, meaning the response *rises* under lesion, because the
  lesion cuts their normalization pool more than their numerator. That is real
  normalization behaviour, but at responses of order 1e-3 it is noise-floor
  bookkeeping, not a finding.
- The normalization pool was inferred, not measured. Instrumenting it is a one-line
  change to a copy of `shModelV1Normalization_Tuned`.

### 4.8.1 Drive, not speed, organizes compensation (coherence × speed)

Measured 2026-08-28 by extending `explore/compensationIndex.m` with a coherence
axis (7 speeds × 6 coherences × 5 gains). Output:
`explore/_figs/compensationIndex_speedCoherence/`. Still deterministic.

If JW's operating-point account is right, C should collapse onto **unlesioned MT
drive**, and low coherence at high speed should look like low speed. It does:

| Preset | R²(C ~ log10 drive) | R²(+ log speed) | C (weak drive) | C (strong drive) |
|--------|---------------------|-----------------|----------------|------------------|
| derivative | 0.966 | 0.981 | 0.91 | 0.68 |
| lagged + mtMix | **0.984** | 0.984 | 0.86 | 0.65 |

Nine high-speed (≥5 deg/s), low-coherence (≤0.25) cells, lagged: mean drive
0.23, mean C **0.85**, mean R(k=0.5)/R(k=1) **0.90**. The speed-only (coherence =
1) slice is unchanged from the table above.

**This is a result about the mean.** Trial-to-trial variability is §4.9.

### 4.9 Site-2 noise makes the amplitude lesion show in d′ and in trial SD

Measured 2026-08-28. Independent Gaussian noise, fixed σ, added to the V1
normalization numerator before the division (`shApplySite2Noise`). Letter C,
1 deg/s, lagged + mtMix, 128², seed 7. Contract:
[`NOISE_TRIAL_DESIGN.md`](NOISE_TRIAL_DESIGN.md).

Deterministic two-forward baseline (same movie): healthy MT d′ **+4.510**,
lesion (gain 0.5) **+4.423** (delta −0.087). Center opponent 0.109 → 0.089.

σ sweep (N = 15) chose **0.05** (SD ratio lesion/healthy peaked at 2.91; 0.03
already worked; 0.08 was harsher than needed).

Locked Phase A, σ = 0.05, N = 50
(`explore/_figs/site2_phaseA_sigma005_n50/`):

| Condition | Mean d′ | SD(d′) | Center opp mean | Center opp SD |
|-----------|---------|--------|-----------------|---------------|
| Healthy, noise off | 4.510 | 0 | 0.109 | 0 |
| Lesion, noise off | 4.423 | 0 | 0.089 | 0 |
| Healthy + noise | 4.388 | 0.033 | 0.093 | 0.0015 |
| Lesion + noise | **3.814** | **0.083** | **0.052** | **0.0034** |

Lesion+noise vs healthy+noise: mean d′ **−0.57** (noise-off lesion was only
−0.09); SD(d′) **2.5×**. Mean N and D scale as k² (0.115 vs 0.029). That is the
JW mechanism: the same σ is amplified more when the pool is smaller.

Phase B (same movie and σ, N = 20, σ_corr = 3 px, gaussian blur of the same white
field): ranking **survived**. Independent arm matched Phase A. Gaussian:

| corr | Healthy d′ | Lesion d′ | Δ mean | SD ratio |
|------|------------|-----------|--------|----------|
| independent | 4.378 ± 0.027 | 3.794 ± 0.072 | −0.58 | 2.62 |
| gaussian | 2.864 ± 0.142 | **1.008 ± 0.153** | **−1.86** | 1.08 |

Correlation does not reverse the Phase A sign, but it is not a small correction:
lesion + gaussian is the first Site-2 condition near a hard letter, and the SD
ratio collapses because healthy trial SD rises. Use gaussian for patchy vs
uniform. σ_corr was not swept. Full table: `NOISE_TRIAL_DESIGN.md` §3.6.

Caveats: d′ under independent noise remains high (~3.8); gaussian brings lesion
d′ to ~1.0 but N = 20 is a first look; MT Site-2 is not on.

---

## 5. Validity ledger — what still holds

| result | status |
|---|---|
| derivative preset reproduces the original model exactly | **current** — enforced by `tests/runAllTests.m` |
| lagged preset's healthy fidelity to SH V1 | **current**, with the 0.984 versus 0.93–0.95 discrepancy unresolved (§4.2) |
| MT's measured speed tuning | **current** (2026-08-25) |
| two-stream MT reproduces Maunsell's knockouts | **current** (2026-08-14) |
| midget dependence graded by speed | **current but confounded** — one fixed grating for all units (§4.5) |
| compensation index (speed) | **current** (2026-08-19) |
| C vs drive, coherence × speed | **current** (2026-08-28) — lagged R² = 0.984 |
| Site-2 Phase A (σ = 0.05, N = 50) | **current** (2026-08-28) — independent V1 noise only |
| Site-2 Phase B (σ_corr = 3 px, N = 20) | **current** (2026-08-28) — ranking survived; gaussian changes the size of the effect |
| motion-letter healthy baseline, d′ = 1.32 | **current** (2026-08-17) at 0.3125 px/frame; the 1 deg/s seed-7 baseline is d′ = 4.51 (report §4.9) |
| uniform versus non-uniform amplitude and delay lesions | **pre-mtMix** — the front-end conclusion probably survives, the MT numbers need re-measuring |
| parasol-only and ON-only lesions | **invalid as biology** — measured on the midget-dominated MT |
| the 114 campaign figures and metric CSVs | **gone** — those files were cleared; the scripts still exist. Current noise/compensation PNGs live in `explore/_figs/` and are tracked |

One consolidated re-run would clear most of this: the §4.7 lesion matrix, with the
missing uniform amplitude-plus-delay cell added and the low-pass neuron reported
under `delay_random`, through the two-stream MT, seeded, with the motion-defined
letter as an extra read-out alongside the SH Figs 9–14 tuning measures.

---

## 6. Decisions we reversed, and why

### 6.1 Building direction selectivity in the retina

The first attempt at a biological front-end tried to build **direction selectivity
biologically**: an ON/OFF spatial offset in the read-out plus an ON quadrature
filter, following Chariker & Shapley. It was retired on 2026-07-12. The code is in
`explore/_archive/` and the full argument is in
`docs/_archive/RGC_V1_design_discussion.md` §9–15. Two reasons:

- The fixed ON/OFF offset **distorts V1 orientation tuning**, and it does not
  rotate with a neuron's preferred direction. Removing it recovers orientation
  best.
- Direction selectivity is something the SH steerable read-out already produces for
  free. Building it biologically fights the read-out rather than adding to it.

The conclusion that survived is the one everything rests on: **the value of a
biological front-end is not a different healthy computation. It is a lesionable
parameterization** — a statement of which cells co-vary under an insult, with
filters constrained by measured physiology. It is a *physically grounded* lesion
model, not a mathematically richer one than SH.

### 6.2 The claim that SH cannot express a conduction delay

That distinction was itself once oversold, and the correction matters for how
lesion results should be phrased. An early test claimed a conduction delay was "a
lesion axis SH cannot express." It is not. SH's basis, regrouped by temporal order,
supports the same delay lesion, and in the lagged preset a delay is approximately a
reweighting of the lag channels.

What the biological preset buys is that the lesion is *stated in terms of cell
types* — not that it could not be expressed otherwise. A genuine test of
non-vacuousness, exploiting the ON/OFF rectification that SH lacks, is still
outstanding (`docs/TODO.md` §5).

---

## 7. Where the noise work fits

The whole argument has its own document:
**[`NOISE_AND_DEMYELINATION.md`](NOISE_AND_DEMYELINATION.md)** — the pathophysiology
of demyelination, how it maps onto the lesion parameters, where internal noise
would enter, and what the model would then predict.

Three points from it change how §4.7 above should be read.

1. **§4.7.2's null result is normalization, and that is now measured** (§4.8) **and
   it shows in discriminability once Site-2 noise is on** (§4.9). The right reading
   of "a 50% gain cut barely moves direction tuning" is not *amplitude lesions
   don't matter*. It is **normalization hid it, and once cortical noise is present
   the hiding is itself the damage**: a −0.09 d′ lesion becomes **−0.57** with
   **2.5×** trial SD.
2. **Three mechanisms of demyelination cannot currently be written down at all** —
   trial-to-trial spike jitter, stochastic conduction block, and failure at high
   firing rates. The first two need noise. The third needs a change in filter shape
   and could be run today. `delay_random` (§4.7.5) models only the *fixed* half of
   temporal dispersion, not the half that varies from trial to trial.
3. **§4.7.4's equivalence between uniform and patchy amplitude damage is predicted
   to break** once noise is present, because the normalization pool is blurred
   across space and therefore gives a damaged location less gain rescue under
   patchy damage than under uniform damage.

Until that work is done, phrase the §4.7 conclusions as *"delay that is
desynchronised pixel by pixel disrupts steady-state tuning where uniform amplitude
loss does not"*, which is what was measured — rather than as *"amplitude lesions
matter less"*, which is a claim about behaviour that a deterministic model cannot
make.
