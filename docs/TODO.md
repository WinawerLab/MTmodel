# TODO — parked items and the optic-neuritis work plan

Created 2026-08-13; reviewed 2026-08-19. Items here are **deliberately not being
worked on now**; this file exists so they are not lost. Ordered by bearing on the
driving question.

For the current state of the design and what the lesion tests have shown, see
[`MODEL_AND_LESIONS.md`](MODEL_AND_LESIONS.md). Sections 1 and 4 below are **done**
and are kept only as the record of why things were built the way they were.

## The driving question

> Can an RGC-level lesion explain the optic-neuritis pattern of
> **(a) increased VEP latency** and **(b) reduced recognition of motion-defined
> form at low speeds**?

Useful conversions, now that the frame rate is pinned
(`docs/RGC_lagged_preset_summary.md` §7.1): **1 pixel = 0.430 deg**,
**1 frame = 26.9 ms (37.2 fps)**, **1 pixel/frame = 16 deg/sec**.

| clinical speed | model units |
|---|---|
| 1 deg/s | 0.063 px/frame |
| 2 deg/s | 0.125 px/frame |
| 5 deg/s | 0.313 px/frame |
| 10 deg/s | 0.625 px/frame |

The Fig-10 **"lowpass"** neuron spans 0.0375–0.6 px/frame = **0.6–9.6 deg/s**,
which is squarely the clinically interesting low-speed band. The "highpass"
neuron spans 1–10 px/frame = 16–160 deg/s.

---

## 1. Give the M/P distinction meaning: masked refit + slow midget drive *(DONE 2026-08-14)*

**Status: DONE** — landed in `918e24f` (parasol-masked MT population + slow midget
drive) and `ee8a3ab` (knockout check reproduces Maunsell; `alpha = 0.10` adopted).
Maunsell et al. (1990) is reproduced: M block pronounced and near-universal (81%
population median, 95% of units), P block little effect on the typical unit (2.7%
median) but unequivocal for 1 of 19, combined block essentially eliminates the
response. `alpha >= 0.20` breaks it, so the criterion brackets alpha to 0.05–0.10.
See `AGENTS.md` for the summary. The design notes below are kept as the record of
why it was built this way.

The two Nassi & Callaway papers added on
2026-08-14 turned this from an open-ended fitting problem into a bounded change
with **one new fit and one new scalar**. This supersedes the earlier
"constrain the weight fit toward magno-dominance" framing and its three
unevaluated approaches, none of which are being pursued as written.

**The problem (unchanged).** The fitted 28×160 weight matrix makes this model's MT
**midget-dominated**: zeroing midget classes collapses MT direction tuning, while
zeroing parasol classes leaves it intact (and raises the peak). That is the
opposite of Maunsell et al. (1990), and contradicts SH's own p. 754 premise that
most MT afferents are magnocellular. The weights were fit to reproduce SH's V1,
which has no M/P distinction, so nothing in the objective encodes magno-dominance
— the midget/parasol labels are currently decorative with respect to the fit.
Every cell-type-specific lesion result from this preset therefore reflects an
arbitrary fitting outcome rather than biology.

### 1.1 The architectural fact that makes this cheap

`shMtWts` computes the V1→MT weights **analytically** from the direction geometry:

```matlab
tmp = sum(shQwts(dirs) * pinv(shQwts(pars.v1PopulationDirections)));
```

Nothing there is fit, and it carries no cell-type information — it depends only on
`v1PopulationDirections`. So **MT's M/P dependence is determined entirely by the
RGC→V1 weight matrix**, provided the direction tiling stays complete. The V1→MT
pathway needs no new parameters, and the original plan not to touch it survives.

Corollary, and a trap to avoid: this cannot be done by **subsetting** the 28 V1
neurons. The `pinv` needs the full tiling; dropping rows would wreck MT tuning for
geometric reasons unrelated to biology. Change *what drives* the 28, never *which*
of the 28.

### 1.2 What Nassi & Callaway constrain

- **Nassi & Callaway (2006)**, Fig 7A: disynaptic label in layer 4C after an MT
  injection is **~96–97% in M-dominated 4Cα, ~3% in P-dominated 4Cβ** (V3 is
  98/1). V2 is the mixed one: ~70% 4Cα / ~29% 4Cβ for blob-unbiased injections.
- **Nassi & Callaway (2006)**, 6-day survival: MT *does* receive substantial P
  input, but by a **3–5 synapse** detour — 4Cβ → layer 4B pyramids → V2 thick
  stripes → MT — bypassing the 4B stellates entirely.
- **Nassi & Callaway (2007)**: MT-projecting layer 4B cells are **76% spiny
  stellate** (which receive input only from 4Cα), with >2× the soma area
  (329 vs 146 µm²), more total dendrite (6908 vs 4163 µm), ~20% of dendritic
  length in 4Cα, and located deeper in 4B. V2-projecting 4B cells are **83%
  pyramidal** and integrate mixed M and P. Their Fig 5: ~20% of layer 4B projects
  to MT (M-dominated), ~80% to V2 (mixed).

Their conclusion: MT-projecting cells are specialized for **fast transmission of
M-pathway signals**; V2-projecting cells do slower computations on mixed M and P.

The key structural point: **biology puts M/P selectivity in two distinct
populations, not in a graded weighting.** This model currently has one, and it is
the mixed one.

### 1.3 The design

**Population A ("4B → MT").** Refit the same 28 neurons against the same SH target
with the feature matrix masked to the **80 parasol columns** (8 parasol classes ×
10 read-out orders, of 160). Parasol share = 1.0 by construction. `shMtWts` and the
direction tiling are untouched.

**Population B ("→ V2 → MT", the slow minority drive).** This is the **existing
mixed fit, unchanged** — no new fitting. Justified by §1.2: the V2 relay carries
*mixed* M and P (70/29), which is what `pars.rgc.v1Weights` already is. Population B
also remains the validated V1 stage, so nothing is duplicated.

**The mix**, applied to the post-normalization V1 population response just before
`shModelMtLinear`'s `pop*shMtWts(...)'`:

```
popMT = (1 - alpha)*popA + alpha*shift(popB, d)
```

Post-normalization, not at the linear stage, so the two streams do not share a V1
normalization pool — the faithful choice for two anatomically separate populations.
Because the MT stage is linear in `pop`, this is exactly
`(1-alpha)*MT(popA) + alpha*MT(popB delayed)`, so the streams can be computed
separately and combined, which makes knockout bookkeeping trivial.

**Why the midget drive is imposed and never fit.** Unmasking midget columns in
`shFitClassV1Weights` — even only the long-lag ones — would let ridge regression
use them to reduce SH reconstruction error, with nothing in the objective keeping
them small. That re-inflates the midget share and restores the original problem
with a delay bolted on. Fixed small amplitude only. This also matches the anatomy,
where the P route converges *on MT* rather than mixing inside the 4B cells.

### 1.4 Parameters

**`d` (delay): 0 frames. Costs nothing.** The P route is ~2–3 synapses longer than
the M route ≈ 5–10 ms, but **1 frame = 26.9 ms**, so the detour is *below the
model's temporal resolution* — the same trap already flagged below for the 0–3
frame lags. The latency separation is instead already present for free: the midget
kernel peaks at ~107 ms vs the parasol kernel's ~27 ms (`literature/NOTES.md`),
i.e. ~3 frames of intrinsic lateness from parvo RGC dynamics, not from synapse
count. `d = 1` is the minimum representable if the detour is wanted explicitly,
and already overstates it.

**`alpha` (mixing weight): the only new free parameter.** Do *not* read it off the
96/4 figure — that is the proportion of disynaptic retrograde *label* at 3-day
survival, which measures the fast route's purity, not the slow route's synaptic
strength (that only appeared at 6-day survival, and label density is not a weight).
Calibrate instead against Maunsell et al. (1990): parvocellular block "rarely
produced striking changes" and "typically had very little effect," but gave
unequivocal contributions for a **minority** of MT responses. So choose `alpha`
such that midget knockout is small for most MT units and detectable for a minority.
Monotone effect → bisection, a few runs. Start at `alpha ≈ 0.1`.

### 1.5 Stopping criteria — pre-registered

1. **Masked fit quality.** Report per-neuron *r* of population A against the SH
   targets. A partial failure is expected and is a *result*, not a rabbit hole:
   the parasol kernel is fast (τ = 0.6/1.2) and may not build the sustained low-TF
   V1 neurons — which are the ones MT cares least about. If so, score *r* on the
   MT-relevant subset of the tiling rather than demanding the whole tiling.
2. **Maunsell reproduction.** Re-run the two knockouts. Pass = parasol knockout
   collapses MT direction tuning; midget knockout leaves it largely intact, with a
   detectable effect on a minority. That is the whole point of the exercise.

Terminates after one fit plus one knockout run, plus the `alpha` bisection.

**Check 1 result — measured 2026-08-14 (`explore/fitMagnoMtPopulation.m`).**
The predicted partial failure happened, and it fell exactly where predicted.
Population B reproduced the previously recorded parasol share (0.249–0.377,
median 0.316), confirming the setup matches the existing fit; population A is
1.000 by construction. Reconstruction of the legacy V1 target on a held-out
stimulus, **binned by the neuron's tf/sf preference**:

| tf/sf band | neurons | median *r*, B (mixed) | median *r*, A (parasol) | loss |
|---|---|---|---|---|
| 0.22–0.30 (slow)  | 12 | 0.95 | ~0.55 | ~0.40 |
| 0.43–0.81 (mid)   | 9  | 0.93 | ~0.75 | ~0.17 |
| 1.41–1.63 (fast)  | 7  | 0.90 | ~0.82 | ~0.07 |

Monotonic in tf/sf. The parasol-only basis is a **good** V1 model for the fast
neurons — the ones MT weights most — and a poor one for the slow, sustained
neurons. That is precisely the Nassi & Callaway division of labour: the fast M
stream goes to MT, the slow/mixed computation goes to V2. So check 1 passes under
the pre-registered "score the MT-relevant subset" reading, and the whole-tiling
median (0.930 → 0.706) should **not** be quoted as the headline.

*Caveat on absolute numbers:* population B's median *r* here is 0.93–0.95, below
the ~0.985 quoted elsewhere in these docs. That earlier figure came from a
different measurement (cached weights / different stimulus), so the two are not
directly comparable. The A-vs-B *contrast* above is internally consistent — both
fits, both stimuli, one script.

**Why check 1 failed where it did — measured 2026-08-14
(`explore/measurePreferredTfSf.m`).** The reconstruction loss above has a
mechanism, visible in the tuning rather than the residual. Nominal preferred
(sf, tf) is *identical* for both populations by construction — `v12sin` places
them on a fixed-radius annulus (k = 0.2173) set purely by the neuron's tf/sf
ratio, and both fits share `v1PopulationDirections`. But the **measured**
preferences diverge, and only at the slow end:

| band | nominal | B (mixed) | A (parasol) |
|---|---|---|---|
| slow (tf/sf < 0.5, n=13) | 1.98 Hz | 1.90 Hz | **2.49 Hz** |
| fast (tf/sf > 1.0, n=7)  | 6.81 Hz | 9.71 Hz | 9.71 Hz |

At the fast end A and B agree for **6 of 7** neurons — the parasol-only basis
builds those exactly as well as the mixed basis. At the slow end A prefers a
higher tf than B for **13 of 13**, unanimously (median ×1.40 vs nominal, against
B's ×0.94). Denied midget input, the slow neurons drift toward the frequency the
fast parasol kernel (τ = 0.6/1.2) actually prefers. Population A costs little in
gain: median peak response A/B = 0.86.

Both populations overshoot nominal at the fast end (9.71 vs 6.81 Hz) — a property
of the model, not of the mask. *Caveats:* the log grid quantizes to ×1.31 per tf
step, so the ×1.40 shift is ~1 step — credible because unanimous across all 13
slow neurons, not because any single row is precise; and tf was swept at nominal
sf and vice versa, so these are 1D cuts through a possibly non-separable surface.

**Check 2 result — measured 2026-08-14 (`explore/knockoutAndAlphaCalibration.m`).**
**Maunsell reproduced; `alpha = 0.10` adopted (bracket 0.05–0.10).**

First, the old model's backwards result was reproduced almost exactly, which
validates the harness: parasol knockout *raises* the direction peak by **+25.1%**
(recorded previously as 1.033 → 1.291 = +25.0%) and cuts coherence by −72.7%
(previously −74.6%; the small gap is consistent with this script seeding the dot
stimuli, which the earlier one did not). Midget knockout annihilates it (−100%).

Knockout effects, as % change from each architecture's own intact model. "pop"
columns are over the 19-neuron MT population; the single-neuron columns use the
`[0 0.35]` test neuron:

| architecture | knockout | dir_peak | dir_DSI | coh_peak | pop med \|%\| | pop >20% |
|---|---|---|---|---|---|---|
| mixed (old) | parasol (M) | **+25.1** | −3.9 | −72.7 | 4.1 | 11% |
| mixed (old) | midget (P) | **−100.0** | −100.0 | −94.0 | 33.0 | 100% |
| alpha=0.05 | parasol (M) | −68.2 | −81.7 | −89.2 | 85.4 | 95% |
| alpha=0.05 | midget (P) | −18.3 | −0.0 | −8.9 | 1.4 | 5% |
| alpha=0.10 | parasol (M) | −60.1 | −66.6 | −88.3 | 81.0 | 95% |
| alpha=0.10 | midget (P) | −34.0 | −0.0 | −17.3 | 2.7 | 5% |
| alpha=0.10 | both | −78.7 | −100.0 | −90.5 | 89.5 | 100% |
| alpha=0.20 | midget (P) | −58.5 | −0.0 | −32.7 | 5.7 | 37% |

Against Maunsell: the M block is "pronounced and often complete" (81% population
median, 95% of units), the P block has "very little effect" on the typical unit
(2.7% population median) while being unequivocal for **a minority** (5% = 1 of 19
units over 20%), and the combined block "essentially eliminates" the response
(89.5%, DSI −100%). `alpha >= 0.20` breaks this — the P block reaches 37% of units
and rivals the M block, so the criterion brackets alpha tightly. Both 0.05 and
0.10 qualify; **0.10** is adopted because it keeps the P contribution real rather
than vanishing, which is what Maunsell actually reported.

Note the qualitative dissociation, which was not designed in: midget knockout
leaves **DSI unchanged at every alpha** (−0.0%) — it scales MT down without
disturbing direction tuning — whereas parasol knockout destroys it (−100% at
alpha = 0). The two pathways are not interchangeable in this model any more.

**Check 1.6 — first evidence, and it is positive.** Midget dependence concentrates
sharply at low preferred speed. Median midget-knockout effect by MT preferred
speed (px/frame; 1 px/frame = 16 deg/s):

| pref speed | alpha=0.05 | alpha=0.10 |
|---|---|---|
| 0 | −25.0% | −45.2% |
| 1 | −5.4 to −7.8% | −11.4 to −15.3% |
| 6 | −0.7 to −0.9% | −1.4 to −1.9% |

Monotonic, roughly a 10–30x gradient from slowest to fastest. This is the
mechanism item 3 needs: an insult to the midget pathway would preferentially cost
**low**-speed motion, which is where the clinical deficit is.

*Caveat, and it matters:* every MT neuron here was probed with the **same** grating,
optimal for the slow `[0 0.35]` test neuron, so the fast-preferring units were
driven off-peak and their small effects are partly confounded with that. This is
suggestive, not settled. The proper test is per-neuron speed tuning
(`shTuneBarSpeed`, as in `quantitativeAnalysisFigs9to14`) with alpha on vs off —
which is exactly the item 1.6 / item 3 experiment, now well motivated.

**Machinery built 2026-08-14:**
- `help/shClassFeatureMask.m` — logical column mask from a class-name regexp.
- `help/shFitClassV1Weights.m` — optional third argument `mask`; excluded columns
  are dropped from the regression and returned as exact zeros, at full width.
- `model/innerworkings/shModelV1ComplexForMt.m` — the two-stream mixture.
- `model/shModel.m` — the five MT cases now call it; `v1complex` is untouched, so
  the validated V1 stage is unchanged.

Plumbing verified by two bit-exact identities (`mtMix` with stream A set to the
default weights reproduces the no-mix baseline at both `alpha = 0` and
`alpha = 1`), and the full test suite passes 14/14.

### 1.6 Payoff to check immediately afterward

If MT's fast drive is parasol and its slow minority drive is midget, the **low-speed**
end of MT speed tuning may lean disproportionately on the midget term (slow,
sustained, long integration) while the high-speed end is parasol-driven. That would
be a candidate mechanism for deficit (b) and would resolve the tension in item 3
below, where the heterogeneous-delay result hits *high* speeds while the clinic
reports *low*. Hypothesis, not a prediction to bank — but cheap to test on the same
machinery: zero `alpha` and compare low-pass vs high-pass MT speed tuning.

Evidence and citations: `literature/NOTES.md`.

## 2. VEP latency: what the model can and cannot give (JW, 2026-08-13)

SH note (p. 758) that outputs correspond to **steady-state firing rates**, and an
earlier draft of this file over-read that as "the model cannot produce a latency."
**That is wrong.** Per JW:

- The **temporal impulse responses are causal** and have been deliberately
  reparameterised in this repo (difference-of-gamma RGC kernels, zero-padded lag
  copies). A latency shift *is* therefore measurable from the feedforward
  filtering — delaying or reshaping those kernels moves the model's response in
  time in a well-defined way.
- What is **not** built is the **cortical dynamics of normalization** — the
  divisive normalization here is static, computed on pooled steady-state signals.
  Dynamic-normalization accounts (ORGaNICs; JW's work on temporal dynamics /
  delayed normalization in visual cortex) are what would be needed for latency
  effects that arise *in cortex* rather than being inherited from the retinal
  filtering.

**So deficit (a) is approachable now**, with the scope limit stated explicitly:
predicted latency reflects retinal/feedforward filtering only, not cortical
normalization dynamics. Adding those dynamics is a later, separable project.

Open sub-question: what exactly is the model-side observable that corresponds to
VEP latency — time-to-peak of the population response to a transient? A
cross-correlation lag against the unlesioned response? Worth pinning down before
quoting any number in milliseconds.

## 3. The low-speed tension — highest-value next experiment *(see also §5)*

Phase 2b found that **spatially heterogeneous** delay (`delay_random`) crushes
coherence (−39% lagged) and **high-pass** speed tuning (−55%), whereas **uniform**
delay does essentially nothing to steady-state tuning.

That gives a candidate mechanism for the clinical picture from a single insult:
uniform conduction slowing → VEP latency; **de**synchronised conduction across the
visual field → motion deficit.

**But there is a tension.** The reported heterogeneous-delay effect was largest on
the **high-pass** (fast, 16–160 deg/s) neuron. The clinical deficit is at **low**
speeds. `docs/_archive/VALIDATION_SUMMARY.md` does not report the low-pass neuron under
`delay_random`, so this is currently unknown rather than contradicted.

**Experiment:** measure low-pass (0.6–9.6 deg/s) vs high-pass speed tuning under
heterogeneous delay directly. If heterogeneous delay preferentially spares low
speeds, the current mechanism does **not** explain the clinical deficit and the
hypothesis needs revising.

## 4. Motion-defined form stimulus: merged and validated *(DONE 2026-08-17)*

`origin/Kristin` adds `stim/mkMotionLetter.m` (283 lines), plus
`explore/showMotionLetter.m` and `showMotionLetterModel.m` — a motion-defined
letter generator, i.e. exactly the stimulus class for deficit (b). It also adds
`pars/shRgcClassesMidgetParasolTiled.m` and modifies the lagged preset.

**MERGED 2026-08-17** (`main`, merge commit). Clean auto-merge; `runAllTests.m`
is 14/14 on the merged tree and both RGC presets run the stimulus end to end.
Note the stimulus is *motion-defined form* (Regan letter: letter dots drift
right, background dots drift left) — the deficit-(b) stimulus — not
structure-from-motion in the 3D-shape sense.

Review findings 1-3 are **FIXED (2026-08-17)**; item 4 is documented:

1. **`localBestOpponentIndices` mixed radians and px/frame** in one `hypot`, so
   the speed term dominated and at slow stimulus speeds it selected the
   **static** `[0 deg, 0]` MT unit as "right-tuned". Replaced by
   `localOpponentPair`, which matches in the model's own 3-D Fourier geometry
   (elevation `atan3(speed,1)` + `sphere2rec`, as `shSwts` does) and matches the
   opponent to the *chosen unit's* speed, so "right - left" is direction
   opponency rather than a speed confound. Exact speed shells cannot be used:
   MT's nominal speeds differ in low-order bits and V1's rings have a different
   speed for every unit.
2. **The same helper was applied to `pars.v1PopulationDirections`.** Column 2
   there *is* a speed in px/frame (0.22-1.63), not a Fourier angle -- an earlier
   note in this file said otherwise and was wrong. It was still mis-selected for
   the same dimensional reason, and now uses `localOpponentPair` too. V1's four
   speed shells (3.5-26 deg/s) bracket the clinical band far better than MT's.
3. **Units were the real problem, not speed per se.** `mkMotionLetter` converted
   deg/s through *display* geometry (~100 px/deg at booth resolution) while the
   model's filters live at **2.33 px/deg, 37.2 fps**. The `ppd` option that
   would have fixed this was assigned and never read -- passing it did nothing.
   Now `ppd` is authoritative, `pars/shModelUnits.m` derives the pinned scale
   from SH Appendix I, and `explore/showMotionLetterModel.m` builds in model
   units with `SPEED_DEG_S` documented against the literature bands.

**Corrected empirical claim.** An earlier note here said letter/background
separation improved markedly with speed (d' 1.05 -> 1.26). That was an artifact
of the broken selector picking the static unit at low speed. With the selector
fixed, MT opponent d' is ~1.3 and **flat** from 1 to 48 deg/s (96x96 field,
derivative preset, seeded):

| deg/s | px/frame | MT opponent d' | V1 opponent d' |
|---|---|---|---|
| 1.0  | 0.0625 | 1.31 | 0.18 |
| 2.0  | 0.1250 | 1.31 | 0.26 |
| 5.0  | 0.3125 | 1.29 | 0.31 |
| 9.6  | 0.6000 | 1.31 | 0.33 |
| 16.0 | 1.0000 | 1.34 | 0.33 |
| 48.0 | 3.0000 | 1.29 | 0.32 |

So MT segregates the motion-defined letter robustly and **speed-invariantly**
over the clinical band, and V1's opponent signal is much weaker (0.18-0.33) and
does rise with speed. The standing tension in section 3 is unchanged: MT is tuned
to {0, 1, 6} px/frame = {0, 16, 96} deg/s, so the entire clinical band sits below
MT's slowest non-zero tuned speed. `localOpponentPair` now warns when the
population does not sample the stimulus speed.

4. **Booth preview and model stimulus are independent dot samples** (frame
   correlation ~0): `mkMotionLetter` builds directly at each size and the field
   area sets the dot count, so a shared seed does not align the draws. Not
   "fixed" -- the preview is now off by default (`SHOW_BOOTH_PREVIEW`), labelled
   as a separate sample, and the false "built at booth, then uniformly resized"
   comment is gone.

### First result: the model recovers a motion-defined letter (2026-08-17)

`explore/runMotionLetterDemo.m` — seeded, 5 deg/s (0.3125 px/frame), letter 'C',
128x128x120 output, both RGC presets. Figures in `explore/_figs/`
(gitignored; re-run the script).

| stage | derivative preset | midgetParasolLagged |
|---|---|---|
| V1 opponent d' | +0.23 | +0.22 |
| MT opponent d' | **+1.32** | **+1.32** |

**MT recovers the letterform legibly**; V1's opponent map is weak and noisy. The
two RGC presets are indistinguishable on this task, which is the expected result
for a healthy-condition stimulus and a useful baseline for lesioning.

**The segregation is genuinely motion-based**, established by three controls:

| control | MT d' |
|---|---|
| opposite drift (Regan stimulus) | +1.32 |
| static background | +1.30 |
| **same drift — no relative motion** | **−0.34** |

Static-luminance d' on the time-averaged image is ≈ 0 (−0.008), single-frame
luminance d' ≈ −0.002, and dot coverage is 0.3025 inside vs 0.3124 outside, so
there is no static cue to exploit. The same-drift control (new
`backgroundVelocityScale` option on `mkMotionLetter`, +1 = no relative motion)
collapses the letter completely — the decisive test.

Note a **discarded control**: temporally scrambling the frame order only drops MT
d' to +0.86, but that is not evidence of a non-motion cue. Permuting whole frames
displaces letter and background dots by equal and *opposite* amounts on every
transition, so relative direction survives scrambling. Do not use frame-scrambling
as a motion control for this stimulus.

**Next**, now that the healthy baseline is established: run the same stimulus
under the optic-neuritis lesions (uniform vs spatially heterogeneous delay,
amplitude) and see whether MT d' drops, and whether it drops preferentially at
low speeds — which is the section 3 tension stated as a direct test.

**Open decision — spatial scale.** At 2.33 px/deg a clinically sized letter
(168 arcmin = 2.8 deg) is only **~6.5 pixels**, far too small to be a letter.
`showMotionLetterModel.m` therefore sets the letter in model pixels (60% of the
field, ~34 deg implied) and reports the angular size. Reconciling this with the
known order-of-magnitude RGC spatial-scale offset is unresolved and is the main
thing standing between this stimulus and a quantitative clinical claim.

Also fixed: **the Sloan font was not installed**, and the fallback detector could
not notice -- MATLAB silently substitutes a face, so a missing font still renders
and `info.fontName` reported the requested name regardless. Every earlier run
therefore used a substituted face while claiming Sloan. Sloan is now installed
(letter mask 5022 px vs Arial's 1798), and availability is checked against
`listfonts` up front.

Smaller, still open: `numDots`/`letterContrast` use
disk area `pi*(d/2)^2` for dots that are square by default (~27% too many dots);
`localStampDots` clips dots at the field edge instead of wrapping, though the
positions wrap; `maskOnMap` is computed but only used in commented-out
`contour` calls; and `pars/shRgcClassesMidgetParasolTiled.m` is a
backward-compatibility alias for a name that never existed on `main`, so it can
probably just be deleted.

---

## 5. Re-run the lesion matrix through the two-stream MT *(added 2026-08-19)*

Every lesion number on record was measured before `pars.rgc.mtMix` existed, i.e.
through the midget-dominated MT. The class-agnostic results (uniform vs.
heterogeneous amplitude and delay) are statements about the front-end and will
probably survive; the **cell-type-specific ones — parasol-only, ON-only — are
not interpretable as biology at all** and must be redone. See
`MODEL_AND_LESIONS.md` §5 for the full ledger.

Two cells of the lesion matrix have also never been run:

- **uniform amplitude + uniform delay together.** There is no combined-uniform
  condition anywhere. The only combined condition (`coupled`) ties amplitude and
  delay together deterministically rather than varying them independently.
- **the low-pass (0.6–9.6 deg/s) neuron under `delay_random`.** This is the cell
  that decides item 3 above, and it was never reported.

One consolidated pass would clear most of this: the full matrix
{amplitude, delay, both} × {uniform, non-uniform}, through the two-stream MT,
**seeded**, with the motion-defined letter d′ as an extra read-out alongside the
Figs 9–14 tuning measures. `explore/compareLesionsToBaseline.m` is the template
(it seeds and plots against baseline on shared axes);
`explore/validateSHFigs9to14_lesions.m` still does not seed and should not be
extended as-is.

## 6. Internal noise: three sites, and the gain-compensation mechanism *(added 2026-08-19)*

**Full treatment now has its own document: `NOISE_AND_DEMYELINATION.md`** — the
demyelination pathophysiology and how it maps onto the lesion parameters, the
three noise sites, the gain-compensation mechanism, the predictions, and the
first measurement. Short version, and the framing is JW's:

The model is deterministic, so a uniform amplitude lesion is close to a contrast
reduction — and both cortical stages already implement
`R = s*N / (strength*D + sigma^2)` with `sigma = v1C50 = mtC50 = 0.1`, where the
pool `D` is computed from the **lesioned** input. So a lesion automatically raises
the effective gain. That is why §4.2's 50% gain cut barely moved direction tuning:
normalization absorbed it. **The compensation is the lesion's signature, not the
model failing to notice it** — once there is noise for the raised gain to act on.

Three injection sites, which are separable and should be run separately first:

1. **Optic nerve.** Demyelinated fibres noisier / worse SNR. Upstream of the
   amplitude loss, so a pure gain cut leaves this SNR unchanged — it needs an
   explicit noise increase to do work.
2. **Local cortical noise, upstream of the normalization gain.** Signal attenuated
   by *k*, this noise not. **The site that makes amplitude lesions bite.**
3. **Late / decision noise.** Gain compensation *helps* here, to the extent it
   restores the mean.

**The mechanism to take most seriously is (2) combined with the gain increase.**
Two distinct consequences, and only one is an SNR change: absolute output noise
rises (variability increases), while the mean response is restored toward normal
(so the deficit is invisible to tuning-curve measures — exactly the §4.2 null).
SNR itself falls by *k*, from signal loss against undiminished local noise; the
shared gain cancels in the ratio. Net: **near-normal tuning curves, substantially
degraded discriminability** — a tuning experiment calls the eye normal, a
psychophysical one does not.

A dynamic variant — gain control amplifying its own circuit noise, or losing
stability at low drive — needs normalization *dynamics* (ORGaNICs), the same gap
§2 flags for VEP latency. The static account is a lower bound.

**New testable prediction (report §6.4).** The normalization pool is spatially
blurred, so a damaged location sits in a pool partly supported by intact
neighbours and gets *less* gain rescue than a uniform lesion of the same local
severity, while intact locations get *more* gain and amplify more local noise.
§4.4 currently finds uniform and heterogeneous amplitude lesions interchangeable;
**with site-2 noise they should diverge**, scaling with the damage correlation
length relative to the pool width. Uses lesions that already exist.

**Compensation index — DONE 2026-08-19** (`explore/compensationIndex.m`).
Normalization absorbs most of a uniform amplitude lesion at every speed
(C = 0.64–0.92; a 50% gain cut costs only 12–25% of the MT response, not 75%),
which quantitatively explains §4.2's null result. MT's motion signal across the
clinical band is **4–5× smaller** than at 10–16 deg/s, confirming JW's
signal-starvation premise — and compensation is **strongest where drive is
weakest** (C = 0.89 at 1 deg/s vs 0.64 at 10 deg/s), i.e. the lesion-driven gain
increase is largest exactly where there is least signal. Both factors point the
same way, so the low-speed deficit needs no low-speed-selective damage. Drive is
**U-shaped** in speed, so the model predicts impairment at high speeds too.
Details and caveats in `NOISE_AND_DEMYELINATION.md` §6.

**Next, still no noise code:** add a coherence axis and re-express deficit against
unlesioned drive rather than speed — if low-speed, high-speed and low-coherence
conditions collapse onto one curve, the operating-point account wins outright.

Still to decide: response-scaled vs. fixed-variance noise (this changes the sign
of several predictions); and the deficit-(a) observable, which does not exist yet
(§2). Report motion-letter d′ **and** a trial-to-trial variability measure, since
the mechanism predicts mean and variability move in opposite directions.

## Smaller items found during the 2026-08-13 review

- **Lesion figure scripts never seed the RNG.** Figs 11–14 use random dot fields,
  so lesion-vs-baseline differences there were confounded with dot-sample noise.
  `explore/compareLesionsToBaseline.m` seeds explicitly and should be the model for
  any new script; `validateSHFigs9to14_lesions.m` still does not. Published numbers
  from the unseeded runs (e.g. the −52% parasol coherence effect) are ~5 percentage
  points off the seeded value (−47%).
- **DoG surround is far too weak.** Integrated surround is only 12–13% of centre
  (`surroundWeight = 0.25`), so these are near low-pass centres rather than
  band-pass centre-surround filters. Revisit if the surround is meant to do work.
- **Spatial scale is off by ~an order of magnitude.** At 0.43 deg/pixel the midget
  centre σ is 0.34 deg vs ~0.02–0.05 deg for real midgets. The midget/parasol
  *ratio* is preserved; the absolute scale is not.
- **Population lags are too long for conduction delay.** 0–3 frames = 0–81 ms;
  optic-nerve conduction differences are a few ms. Better justified as lagged LGN
  or delayed inhibition — relevant to how a "conduction delay" lesion is framed.
- **Worst-fitting V1 neuron is r = 0.709** while the median is 0.984. The headline
  ~0.985 fidelity hides real per-neuron spread.
- **Cosmetic:** `sgtitle` overlaps subplot titles in `validateSHFigs9to14*.m`
  Figs 9 and 10.
