# Physical units and spatial scale

**Where in the visual system this model sits.** What one pixel and one frame mean
in degrees and seconds, why the repo departed from the published paper on 2026-08-27,
and which scale problems no choice of units can fix.

The anchor itself lives in `pars/shModelUnits.m`. This document is the derivation
behind it. Everywhere else in the repo cites this file rather than restating it.

Contents:

1. [The anchor](#1-the-anchor)
2. [What it replaced](#2-what-it-replaced)
3. [Why the departure](#3-why-the-departure)
4. [What the current anchor gives](#4-what-the-current-anchor-gives)
5. [The one thing no anchor can fix](#5-the-one-thing-no-anchor-can-fix)
6. [The 0.05 deg/s threshold is out of reach in any units](#6-the-measured-005-degs-speed-threshold-is-out-of-reach-in-any-units)

> **The anchor changed on 2026-08-27, and it no longer agrees with the published
> paper.** Every angular, speed and time figure written in this repo before that
> date carries the old labels and is larger than the same quantity is now — 3.2x
> for speed, 4.3x for length, 1.34x for time. Nothing the model computes changed.
> Material in `docs/_archive/` predates the change and has not been converted.

---

## 1. The anchor

Nothing in the model computes in degrees or seconds. Every filter is defined in
samples — receptive fields in pixels, kernels in frames, the V1 bank as a fixed
9-tap set. The physical scale is a **label** for that grid, held in
`pars/shModelUnits.m`. Changing it changes no computation, invalidates no
result, and needs no refit. It changes only where in the visual system the whole
cascade is taken to sit.

| quantity | value |
|---|---|
| 1 pixel | **0.1 deg** (6 arcmin), i.e. 10 pixels/deg |
| 1 frame | **20 ms**, i.e. **50 frames/sec** |
| 1 pixel/frame | **5 deg/sec** |

## 2. What it replaced

Simoncelli & Heeger (1998) **Appendix I, p. 761** fixes the units explicitly:

> frequency units are fixed so the peak of the annulus crosses the temporal
> frequency axis at ω_t = 8 cycles/sec and the spatial frequency axes at
> ω_x = 0.5 cycles/deg.

In this codebase the 3rd-derivative spatial and temporal filters have the same
shape and both peak at **0.2148 cycles/sample**, so SH's convention determines
both axes: 1 pixel = 0.430 deg (2.33 px/deg), 1 frame = 26.9 ms (37.2 fps), and
1 pixel/frame = 16 deg/sec. SH's own description of their normalization pool as
tuned to "moderate speeds (16 deg/sec)" is consistent with that.

**This repo no longer uses those anchors.** Under the current ones the model's
filters peak at 2.148 cyc/deg and 10.74 cyc/sec, not SH's 0.5 and 8, and the
preferred speed is 5 deg/sec, not 16. Every angular and temporal figure in this
repo is therefore smaller than the same figure computed SH's way — 3.2x for
speed, 4.3x for length, 1.34x for time. **Do not cite SH's Appendix I as the
source of these numbers, and check the date on any older material that carries
the SH labels.** Material in `docs/_archive/` predates the change and has not
been converted.

## 3. Why the departure

Under SH's anchors every stage of the model sits 3–15x too coarse. This is the
model's spatial ladder, with the pixels-per-degree each stage would need in
order to land on its biological target:

| stage | size in pixels | biological target | px/deg it wants |
|---|---|---|---|
| midget centre σ | 0.8 | 0.02–0.05 deg | 16–40 |
| parasol centre σ | 1.6 | 0.1–0.2 deg | 8–16 |
| V1 filter peak | 0.2148 cyc/px | 1–4 cyc/deg | 5–19 |
| V1 receptive field (4σ, σ = 1.28) | 5.1 | ~0.5 deg | ~10 |
| MT receptive field (4σ of the cascade, σ = 3.72) | 14.9 | 1–2 deg | 7–15 |

SH's 2.33 px/deg is below **every** one of those ranges. It is not that the
retina is wrong and the rest is right; the whole cascade sits too coarse. At 10
px/deg, four of the five land in range.

## 4. What the current anchor gives

| parameter | in pixels/frames | in physical units | plausible? |
|---|---|---|---|
| parasol filter peak | 1 frame | 20 ms | yes — real parasol peaks at 20–40 ms |
| midget filter peak | 4 frames | 80 ms | yes, at the slow edge of a real 50–80 ms |
| midget sign reversal | 14 frames | 280 ms | still slow |
| filter length | 24 frames | 480 ms | still long for a ganglion cell impulse response |
| population lags 0–3 | 0–3 frames | 0, 20, 40, 60 ms | too long for conduction delay (a few ms), but in range for lagged LGN cells or delayed inhibition |
| parasol centre σ | 1.6 px | 0.16 deg | yes — real parasol centres are 0.1–0.2 deg |
| midget centre σ | 0.8 px | 0.08 deg | **still 2–4x too large** — real midget centres are 0.02–0.05 deg |
| V1 preferred sf, tf | 0.2148 cyc/sample | 2.15 cyc/deg, 10.7 cyc/sec | yes |
| MT receptive field | 14.9 px | 1.5 deg | yes, parafoveal |
| MT preferred speeds | 0, 1, 6 px/frame | 0, 5, 30 deg/sec | the clinical band is no longer entirely below MT |
| V1 population speeds | 0.216–1.63 px/frame | 1.1–8.2 deg/sec | covers the clinical band |
| a clinically sized letter (2.8 deg) | 28 px | — | usable; it was 6.5 px |

## 5. The one thing no anchor can fix

The midget centre is still 2–4x too large, and that residual is structural. From
midget centre (σ 0.8 px) to MT receptive field (σ 3.72 px) the model's spatial
ladder spans about **4.6x**. In real cortex the same span — a foveal midget
centre to an MT receptive field — is more like **25–35x**. The ladder is
compressed by roughly a factor of six, so no single pixels-per-degree can put
both ends right at once. Pushing the anchor finer to fix the midget breaks MT,
and vice versa.

The only real fix is to stop using one grid for the whole cascade: run the
retina on a grid several times finer than V1 and decimate in between. The hook
already exists — `shClassV1Basis` computes each class channel at input
resolution and calls `shBlurDn3` before the V1 read-out — but the machinery to
use a single coarse scale rather than the whole `1:nScales` stack does not.
That is a project, not a setting: it needs a refit of both 28×160 weight
matrices and debugging of the multi-scale paths, which are plumbed everywhere
but exercised nowhere (every test asserts `nScales == 1`).

---

## 6. The measured 0.05 deg/s speed threshold is out of reach in any units

Human observers reach criterion performance on motion-defined letters at about
**0.05 deg/sec**. The model cannot be brought to that speed by choosing units,
and it is worth recording why so that it is not rediscovered as a calibration
problem.

For speed, the only thing an anchor controls is the single derived constant
`degPerPixel × framesPerSecond`, which is 5 deg/sec now and was 16 before. So:

| anchor | 0.05 deg/s becomes | displacement over a 26-frame movie |
|---|---|---|
| SH's (2.33 px/deg, 37.2 fps) | 0.0031 px/frame | 0.08 px |
| current (10 px/deg, 50 fps) | 0.010 px/frame | 0.26 px |
| the booth's (100 px/deg, 75 fps) | 0.067 px/frame | 1.7 px |

The slowest unit in `v1PopulationDirections` is 0.216 px/frame and MT's slowest
*moving* unit is 1 px/frame. Reaching even the V1 floor would need the constant
about 70x smaller than it is; reaching MT's slow unit, about 320x. Either would
put the MT receptive field at a fraction of an arcminute.

### It is not a low-frequency cutoff, and it is not a wall

An earlier version of this section said "a motion-energy filter cannot tell that
from static". That is too strong, and it invites a reasonable objection: nothing
in this preset blocks DC, so where would a lower limit come from?

The objection is right about the front end. In the lagged preset the parasol
kernel has DC = +0.234 and its DoG passes 0.75 of DC; the midget kernel's DC is
larger still. And `shClassV1Basis` never touches `pars.v1TemporalFilters` at all
-- it uses `v1SpatialFilters` for the **spatial** read-out only, while all
temporal filtering is each class's own causal kernel plus its integer frame lag,
combined by the fitted `v1Weights`. (Only the *derivative* preset routes the
zero-DC 3rd-derivative temporal filters into V1, via `shRgcClassesDerivative`.)
So there is no stage in this preset with structurally zero DC gain, and V1 units
here do respond to arbitrarily slow -- indeed perfectly static -- input.

But responding to a slow stimulus and reporting its direction are different
quantities, and the object-from-motion task needs the second. The
direction-selectivity index

    DSI = (Rpref - Rnull) / (Rpref + Rnull)

is **exactly zero at zero speed for any system whatever**, because at zero speed
the preferred-direction and null-direction stimuli are the same movie. That is a
symmetry argument; it assumes nothing about DC, filter shape, or linearity. Just
above zero, Rpref and Rnull are both smooth in speed and equal at s = 0, so their
difference is 2R'(0)s + O(s³) while their sum tends to 2R(0): **DSI grows
linearly from zero.**

So the slow-speed limit is a collapse of direction *contrast* onto a large
direction-blind pedestal, not a cutoff in responsiveness — and it is graded, not
a wall. Measured DSI at the v1Complex stage, each neuron at its own preferred
spatial frequency:

| stimulus speed | px/frame | median \|DSI\| | as a fraction of the 2 deg/s value |
|---|---|---|---|
| 0 | 0 | 0.000 | 0.00 |
| 0.05 deg/s | 0.010 | 0.044 | 0.05 |
| 0.10 | 0.020 | 0.083 | 0.09 |
| 0.25 | 0.050 | 0.199 | 0.22 |
| 0.50 | 0.100 | 0.395 | 0.43 |
| 1.0 | 0.200 | 0.685 | 0.75 |
| 2.0 | 0.400 | 0.909 | 1.00 |
| 5.0 | 1.000 | 0.909 | 1.00 |

Linear at the bottom, as predicted. At Raz et al.'s slowest condition the model
retains about **5% of the direction signal it has at 2 deg/s** — not zero, but
far too little to segment an object whose only cue is the direction difference
across its boundary. (Regan et al. confirmed formally that letter reading is at
chance when dot speed is zero; the whole signal in these tasks is that
difference.)

Two consequences worth keeping:

* **Raising spatial frequency does not help.** For a directional-derivative
  read-out the response goes as f_x³(a_x + a_t·s)³, so f_x cancels out of the
  pref/null ratio entirely — only s·a_t/a_x survives. Broadband dot stimuli buy
  nothing at the slow end. The only lever is units with a larger a_t/a_x, i.e.
  longer temporal filters and slower-tuned units.
* **Filter support is still the right intuition, stated correctly.** The V1
  read-out spans 9 pixels and the class kernels plus lags span about 27 frames.
  At 0.01 px/frame the stimulus moves under 0.3 px across that whole window, so
  R'(0)·s is tiny against R(0) — which is the same statement as the table above,
  in the time domain.

Provenance: the DSI table is regenerated by
`explore/measureDirectionSelectivityVsSpeed_reduced.py`, a reduced 1-D
reimplementation of `shClassV1Basis`/`localClassChannel` (the stimulus is
constant in y, where every yorder ≥ 1 read-out is identically zero, so dropping
y is exact rather than approximate).
`explore/measureDirectionSelectivityVsSpeed.m` runs the same measurement through
the full pipeline; **run it before quoting these numbers in a manuscript**, since
the reduced version has not yet been cross-checked against it. Both carry the
same built-in check: the zero-speed row must come out exactly 0.

**What to do instead.** For a proof of principle, test lesion effects at speeds
that are slow *relative to the model's own MT tuning* and compare the shape of
the effect, rather than trying to match an absolute deg/sec. Closing the gap for
real would mean lengthening the temporal filters and adding slow units to both
the V1 and MT populations — which changes what the model is, and is not on the
current path.
