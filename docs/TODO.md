# Open work

Rewritten 2026-08-25; reordered 2026-08-27. **This file holds only what is still
open**, ordered by how much it bears on the driving question — but see the callout
below: §1–§3 are one iterative investigation and their numbering is not a sequence.

Finished work is not recorded here. What was built and what it showed is in
[`MODEL_AND_LESIONS.md`](MODEL_AND_LESIONS.md); the design record for choices that
were reversed is in `docs/_archive/`.

> **The driving question.** Can damage at the level of retinal ganglion cells
> explain the optic-neuritis pattern of **(a) a slower visual evoked potential**
> and **(b) worse recognition of shapes defined only by motion, at slow speeds**?

Conversions (`pars/shModelUnits.m`, re-anchored 2026-08-27 and **no longer SH's
Appendix I convention** — see `RGC_lagged_preset_summary.md` §7.1): 1 pixel = 0.1
deg, 1 frame = 20 ms (50 fps), 1 pixel/frame = 5 deg/sec. Every deg/s figure here
is 3.2x smaller than it would be under SH's anchors; nothing the model computes
changed. The Fig-10 **low-pass** neuron spans 0.0375–0.6 px/frame = 0.19–3 deg/s,
which is the clinically interesting band. The **high-pass** neuron spans 1–10
px/frame = 5–50 deg/s.

---

> **§1, §2 and §3 are one iterative investigation, not three independent tasks.**
> How lesions affect the results and how noise affects the results are the same
> question asked from two sides. A lesion result is hard to read without noise,
> because normalization absorbs most of a deterministic amplitude cut and the
> compensation only becomes a signature once there is noise for the raised gain to
> act on. Noise is hard to read without the full lesion picture, because you need
> the deterministic baseline across the whole matrix to know what noise has added.
>
> Neither blocks the other technically, so **where you start is a matter of
> convenience — but expect to go back and forth.** What you learn from noise will
> change which lesion conditions are worth running, and what the lesion matrix
> shows will change which noise model and which observables are worth building.
> Plan for several passes rather than one pass each. §3 is the recurring step that
> makes the loop deliberate instead of accidental, and it is not a closing
> ceremony: run it whenever either half moves, and treat neither half as finished
> until the pair stops changing each other's reading.

## 1. Internal noise

**Start here, by convenience rather than by dependency.** Nothing in this build
order depends on §2, and the first two steps need no noise code at all, so it is
the cheapest place to begin. The model is deterministic, and that is the single
biggest thing standing between it and the clinical question. Read the callout
above before treating any result from this section as final.

**Full treatment: [`NOISE_AND_DEMYELINATION.md`](NOISE_AND_DEMYELINATION.md).**

Short version. Because the model is deterministic, a uniform amplitude lesion is
close to a reduction in contrast — and normalization absorbs most of it, which is
why a 50% gain cut barely moved direction tuning. **The compensation is the
lesion's signature, not the model failing to notice it**, but only once there is
noise for the raised gain to act on. Three of the mechanisms by which
demyelination degrades a signal — trial-to-trial jitter, stochastic conduction
block, and failure at high firing rates — cannot be written down at all without
it.

Build order, from that document's §6. The first two steps need **no noise code**:

1. **Coherence × speed drive map, still deterministic.** Extend
   `explore/compensationIndex.m` with a coherence axis and re-express the deficit
   against unlesioned drive rather than speed. If the low-speed, high-speed and
   low-coherence conditions collapse onto one curve, the operating-point account
   wins outright.
2. **High-frequency failure** as a change in filter shape.
3. **Noise, one site at a time.** Site 2 first — added into `N` in
   `shModelV1Normalization_Tuned`, before the division — since it carries the
   mechanism. Site 1 goes into the class channels in `shClassV1Basis`; site 3 into
   the read-out. Run them separately before combining; they have different
   signatures, and combining first makes the result uninterpretable.
4. **Temporal noise** — jitter per trial, and Bernoulli dropout.

**Five decisions have to be made before any of the noise steps**, set out in full
in `NOISE_AND_DEMYELINATION.md` §6. Do not start from this list alone:

- **Does the noise scale with the response, or have fixed variance?** This changes
  the *sign* of several predictions. It is not a detail.
- **How is it correlated across space?** Independent everywhere is the easy default
  and it is wrong.
- **Dropout is not Gaussian.** Stochastic conduction block is multiplicative,
  all-or-none, and correlated in time.
- **Which observables?** Motion-letter d′ is the natural one, but it must be
  reported **alongside a measure of trial-to-trial variability** in the MT
  response, because §4.2 of that document predicts the mean and the variability
  move in opposite directions. Reporting only the mean reproduces the current blind
  spot with extra steps.
- **The observable for deficit (a) does not exist yet.** See §4 below.

## 2. Re-run the lesion matrix through the two-stream MT

**Decides the standing low-speed tension, and supplies the deterministic baseline
§1 has to be read against.** Can be done before or after §1.

Every lesion number on record was measured before `pars.rgc.mtMix` existed, so it
came through the midget-dominated MT. The class-agnostic results probably survive.
The cell-type-specific ones — parasol-only, ON-only — cannot be read as biology at
all and must be redone. See `MODEL_AND_LESIONS.md` §5 for the full ledger.

Two cells of the matrix have also never been run:

- **uniform amplitude and uniform delay together.** There is no combined uniform
  condition anywhere. The only combined condition, `coupled`, ties the two axes
  together rather than varying them independently.
- **the low-pass (0.0375–0.6 px/frame) neuron under `delay_random`.** This is the cell
  that decides the tension below, and it was never reported.

**The tension.** `delay_random` — delay drawn independently at every pixel —
crushes coherence (−39% lagged) and **high-pass** speed tuning (−55%), while
uniform delay does essentially nothing. (The `patchy` condition, which is
correlated across space, also does essentially nothing. It is desynchronisation
that bites, not heterogeneity as such.) That would give both clinical signs from a
single insult: uniform slowing gives the VEP latency, desynchronised conduction
gives the motion deficit. But the effect was largest on the **fast** neuron, and
the clinical deficit is at **slow** speeds. The slow neuron was never measured
under `delay_random`, so this is unknown rather than contradicted. If
`delay_random` turns out to spare low speeds, the mechanism does not explain the
clinical deficit and the hypothesis needs revising. The speed-graded midget
dependence in `MODEL_AND_LESIONS.md` §4.5 is the candidate that would resolve it.

**One consolidated pass would clear most of this**: the full matrix
{amplitude, delay, both} × {uniform, non-uniform}, through the two-stream MT,
**seeded**, with motion-letter d′ as an extra read-out alongside the Figs 9–14
tuning measures. `explore/compareLesionsToBaseline.m` is the template — it seeds,
and it plots against baseline on shared axes. `explore/validateSHFigs9to14_lesions.m`
still does not seed and should not be extended as it stands.

## 3. Re-read §1 and §2 against each other, repeatedly

**This is a recurring step, not a final one.** Run it every time either half
moves, not once at the end, and do not fold it into whichever of §1 and §2
happens to be in progress. Each half changes how the other reads:

- **Re-read every lesion result with noise present.** The deterministic matrix
  says how much of a lesion normalization absorbs. Only with noise does that
  absorption become a prediction about discriminability rather than about mean
  response. Results that looked like null results may not be.
- **Re-read every noise result against the full lesion picture.** A noise effect is
  only informative relative to the deterministic baseline for the same condition.
  Without the whole matrix, you cannot tell which effects noise created and which
  it merely revealed.
- **Report the mean and the variability together**, throughout. This is the
  decision from `NOISE_AND_DEMYELINATION.md` §6 that is easiest to lose, and it is
  what this review pass exists to enforce.
- **State plainly which conclusions survive the pairing and which do not.** The
  validity ledger in `MODEL_AND_LESIONS.md` §5 is where that belongs.

- **Feed the result back into what gets run next.** That is what makes this a loop
  rather than a report. A noise result that changes the operating-point account
  changes which lesion conditions are worth running; a lesion result that changes
  the drive map changes which noise model and which observables are worth building.

The standing low-speed tension (§2) is the specific thing to re-test on each pass:
whether `delay_random` spares low speeds is a different question once the read-out
is noisy. Stop iterating when the two halves no longer change each other's
reading — not when each has been done once.

## 4. Decide what the model's version of VEP latency is

Deficit (a) is approachable now, with one scope limit stated up front: predicted
latency reflects retinal and feedforward filtering only, not the dynamics of
cortical normalization.

Simoncelli & Heeger note (p. 758) that their outputs correspond to **steady-state
firing rates**. An earlier draft over-read that as "the model cannot produce a
latency." That is wrong:

- The **temporal filters are causal**, and they have been deliberately
  reparameterised in this repo (difference-of-gamma RGC filters, zero-padded lagged
  copies). A shift in latency *is* measurable from the feedforward filtering.
  Delaying or reshaping those filters moves the model's response in time in a
  well-defined way.
- What is **not** built is the **dynamics of normalization**. The divisive
  normalization here is static, computed on pooled steady-state signals. Dynamic
  accounts (ORGaNICs; delayed normalization in visual cortex) are what would be
  needed for latency effects that arise *in cortex* rather than being inherited
  from the retinal filtering. That is a later, separable project.

**Open sub-question, and it blocks quoting any number in milliseconds.** What
exactly is the model-side observable? Time to peak of the population response to a
transient? Cross-correlation lag against the unlesioned response? Pin this down
first.

## 5. Does the biological front-end say anything SH cannot?

Still outstanding. `explore/testONOFFAsymmetryNonvacuousness.m` established that
timing lesions are about 90% irreducible to an SH amplitude rescaling, but all
three lesion types scored similarly, so it does not yet isolate a signature that
depends on rectification specifically.

The point to test is narrow, and `MODEL_AND_LESIONS.md` §6.2 states why it matters:
a conduction delay is *not* a lesion SH cannot express. What the biological preset
buys is that a lesion can be stated in terms of cell types. A genuine test would
have to exploit the ON/OFF rectification that SH lacks.

## 6. What is left of the spatial-scale problem after the re-anchor

The 2026-08-27 re-anchor to 10 px/deg and 50 fps closed most of this. A clinically
sized letter (2.8 deg) is now 28 pixels rather than 6.5, and MT's tuning is
{0, 5, 30} deg/s rather than {0, 16, 96}, so the clinical low-speed band straddles
MT's slow moving unit instead of sitting entirely below it.

Three things are still open:

- **The midget centre is still 2–4x too large** (0.08 deg against a real 0.02–0.05).
  This is structural, not a units problem: the model's spatial ladder, from midget
  centre to MT receptive field, spans about 4.6x where real cortex spans 25–35x, so
  no single pixels-per-degree fixes both ends. The fix is a front-end that runs the
  retina on a finer grid than V1. `RGC_lagged_preset_summary.md` §7.1 sets out what
  that would take.
- **`explore/showMotionLetterModel.m` still sets the letter in model pixels** and
  reports the implied angular size. With 28 pixels available it can now set a real
  angular size instead. Not yet done.
- **The psychophysical 0.05 deg/s speed threshold is out of the model's reach in
  any units.** Do not treat this as a calibration problem; the reasoning is in
  `RGC_lagged_preset_summary.md` §7.2. For now, test lesion effects at speeds slow
  *relative to MT's own tuning* and compare the shape of the effect.

`localOpponentPair` warns when the population does not sample the stimulus speed.

## 7. Calibrate the RGC filter time courses against Kling (2020)

At 50 fps the preset's midget filter peaks at about 80 ms and its parasol filter at
about 20 ms. Real parasol cells peak at 20–40 ms and real midget cells at 50–80 ms,
so after the re-anchor both peaks are in range — parasol at its fast edge, midget
at its slow edge. What is still off is the tail: the midget sign reversal at 280 ms
and the 480 ms filter length are both long for an RGC impulse response. Check these
against measured time courses.

---

## Known problems, not currently being worked on

**Defects in live code only.** Caveats about *results* belong in
`MODEL_AND_LESIONS.md` §5 (the validity ledger); limits of the front-end's
parameters — the weak surround, the over-long lags, the spread in per-neuron
fidelity — belong in `RGC_lagged_preset_summary.md` §7 and `MODEL_AND_LESIONS.md`
§4.2. Do not restate them here.

- **`validateSHFigs9to14_lesions.m` does not seed the random number generator.**
  Consequences and the affected numbers: `MODEL_AND_LESIONS.md` §4.7.7.
- **`mkMotionLetter` details.** `numDots` and `letterContrast` use the area of a
  disk, `pi*(d/2)^2`, for dots that are square by default, so it makes about 27%
  too many. `localStampDots` clips dots at the edge of the field instead of
  wrapping them, though the positions themselves wrap. `maskOnMap` is computed but
  only used in `contour` calls that are commented out.
- **Booth preview and model stimulus are independent dot samples.**
  `mkMotionLetter` builds directly at each size and the area of the field sets the
  dot count, so sharing a seed does not align the two draws. The preview is off by
  default (`SHOW_BOOTH_PREVIEW`) and labelled as a separate sample.
- **Cosmetic:** `sgtitle` overlaps the subplot titles in Figs 9 and 10 of
  `validateSHFigs9to14*.m`.
