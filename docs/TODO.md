# Open work

Rewritten 2026-08-25. **This file holds only what is still open**, ordered by how
much it bears on the driving question.

Finished work is not recorded here. What was built and what it showed is in
[`MODEL_AND_LESIONS.md`](MODEL_AND_LESIONS.md); the design record for choices that
were reversed is in `docs/_archive/`.

> **The driving question.** Can damage at the level of retinal ganglion cells
> explain the optic-neuritis pattern of **(a) a slower visual evoked potential**
> and **(b) worse recognition of shapes defined only by motion, at slow speeds**?

Conversions: 1 pixel = 0.430 deg, 1 frame = 26.9 ms (37.2 fps), 1 pixel/frame =
16 deg/sec. The Fig-10 **low-pass** neuron spans 0.0375–0.6 px/frame = 0.6–9.6
deg/s, which is the clinically interesting band. The **high-pass** neuron spans
1–10 px/frame = 16–160 deg/s.

---

## 1. Re-run the lesion matrix through the two-stream MT

**Highest value. It decides the standing low-speed tension.**

Every lesion number on record was measured before `pars.rgc.mtMix` existed, so it
came through the midget-dominated MT. The class-agnostic results probably survive.
The cell-type-specific ones — parasol-only, ON-only — cannot be read as biology at
all and must be redone. See `MODEL_AND_LESIONS.md` §5 for the full ledger.

Two cells of the matrix have also never been run:

- **uniform amplitude and uniform delay together.** There is no combined uniform
  condition anywhere. The only combined condition, `coupled`, ties the two axes
  together rather than varying them independently.
- **the low-pass (0.6–9.6 deg/s) neuron under `delay_random`.** This is the cell
  that decides the tension below, and it was never reported.

**The tension.** Patchy delay crushes coherence (−39% lagged) and **high-pass**
speed tuning (−55%), while uniform delay does essentially nothing. That would give
both clinical signs from a single insult: uniform slowing gives the VEP latency,
desynchronised conduction gives the motion deficit. But the effect was largest on
the **fast** neuron, and the clinical deficit is at **slow** speeds. The slow
neuron was never measured under `delay_random`, so this is unknown rather than
contradicted. If patchy delay turns out to spare low speeds, the mechanism does not
explain the clinical deficit and the hypothesis needs revising. The speed-graded
midget dependence in `MODEL_AND_LESIONS.md` §4.5 is the candidate that would
resolve it.

**One consolidated pass would clear most of this**: the full matrix
{amplitude, delay, both} × {uniform, non-uniform}, through the two-stream MT,
**seeded**, with motion-letter d′ as an extra read-out alongside the Figs 9–14
tuning measures. `explore/compareLesionsToBaseline.m` is the template — it seeds,
and it plots against baseline on shared axes. `explore/validateSHFigs9to14_lesions.m`
still does not seed and should not be extended as it stands.

## 2. Decide what the model's version of VEP latency is

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

## 3. Internal noise

**Full treatment: [`NOISE_AND_DEMYELINATION.md`](NOISE_AND_DEMYELINATION.md).**

Short version. The model is deterministic, so a uniform amplitude lesion is close
to a reduction in contrast — and normalization absorbs most of it, which is why a
50% gain cut barely moved direction tuning. **The compensation is the lesion's
signature, not the model failing to notice it**, but only once there is noise for
the raised gain to act on. Three of the mechanisms by which demyelination degrades a
signal — trial-to-trial jitter, stochastic conduction block, and failure at high
firing rates — cannot be written down at all without it.

Build order, from that document's §6:

1. **Coherence × speed drive map, still deterministic.** Extend
   `explore/compensationIndex.m` with a coherence axis and re-express the deficit
   against unlesioned drive rather than speed. If the low-speed, high-speed and
   low-coherence conditions collapse onto one curve, the operating-point account
   wins outright. No noise code needed.
2. **High-frequency failure** as a change in filter shape. Also no noise code.
3. **Noise, one site at a time**, starting with local cortical noise.
4. **Temporal noise** — jitter per trial, and Bernoulli dropout.

Two decisions have to be made before any of the noise steps: whether the noise
scales with the response or has fixed variance (this changes the *sign* of several
predictions), and how it is correlated across space.

## 4. Does the biological front-end say anything SH cannot?

Still outstanding. `explore/testONOFFAsymmetryNonvacuousness.m` established that
timing lesions are about 90% irreducible to an SH amplitude rescaling, but all
three lesion types scored similarly, so it does not yet isolate a signature that
depends on rectification specifically.

The point to test is narrow, and `MODEL_AND_LESIONS.md` §6.2 states why it matters:
a conduction delay is *not* a lesion SH cannot express. What the biological preset
buys is that a lesion can be stated in terms of cell types. A genuine test would
have to exploit the ON/OFF rectification that SH lacks.

## 5. Reconcile the spatial scale before making any quantitative clinical claim

Two problems that have to be resolved together:

- At 2.33 pixels per degree, a clinically sized letter (2.8 deg) is only about 6.5
  pixels across. `explore/showMotionLetterModel.m` therefore sets the letter in
  model pixels, implying about 34 deg, and reports the angular size it used.
- The model's RGC receptive fields are about an order of magnitude larger than real
  midget and parasol cells at this scale. The midget centre is 0.34 deg against a
  real 0.02–0.05 deg.

This is the main thing standing between the motion-letter stimulus and a
quantitative clinical claim.

A related standing tension: MT is tuned to {0, 1, 6} px/frame = {0, 16, 96} deg/s,
so the entire clinical low-speed band sits below MT's slowest moving unit.
`localOpponentPair` now warns when the population does not sample the stimulus
speed.

## 6. Calibrate the RGC filter time courses against Kling (2020)

Now actionable, since the frame rate is pinned. The preset's midget filter peaks at
about 107 ms and its parasol filter at about 27 ms. Real parasol cells peak at
20–40 ms, so parasol is fine; midget is slow, against a real 50–80 ms. The midget
sign reversal at 376 ms and the 645 ms filter length are both very long for an RGC
impulse response. These can finally be checked against measured time courses.

---

## Known problems, not currently being worked on

- **`validateSHFigs9to14_lesions.m` still does not seed the random number
  generator.** Figs 11–14 use random dot fields, so any lesion-versus-baseline
  difference it produces is mixed up with dot-sample noise, worth about 5 percentage
  points. Numbers published from the unseeded runs — for example the −52% parasol
  coherence effect — are about 5 points off the seeded value of −47%.
- **The difference-of-Gaussians surround is far too weak.** The integrated surround
  is only 12–13% of the centre (`surroundWeight = 0.25`), so these are close to
  low-pass centres rather than band-pass centre-surround filters. Revisit if the
  surround is meant to do real work.
- **The population lags are too long to be conduction delay.** 0–3 frames is
  0–81 ms; differences in optic nerve conduction are a few ms. They are better
  justified as lagged LGN cells or delayed inhibition. This matters for how a
  "conduction delay" lesion is framed.
- **The worst-fitting V1 neuron is r = 0.709** while the median is 0.984. The
  headline fidelity figure hides real spread across neurons. See
  `MODEL_AND_LESIONS.md` §4.2, including the separate measurement that puts the
  same population at 0.93–0.95.
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
