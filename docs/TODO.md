# TODO — parked items and the optic-neuritis work plan

Created 2026-08-13. Items here are **deliberately not being worked on now**;
this file exists so they are not lost. Ordered by bearing on the driving question.

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

## 1. Constrain the weight fit toward magno-dominance *(parked — JW, 2026-08-13)*

**Status: parked deliberately.** Possibly complicated; not to be started without
a decision to take it on.

**Why it matters.** The fitted 28×160 weight matrix makes this model's MT
**midget-dominated**: zeroing midget classes collapses MT direction tuning, while
zeroing parasol classes leaves it intact (and raises the peak). That is the
opposite of Maunsell et al. (1990), and contradicts SH's own p. 754 premise that
most MT afferents are magnocellular. The weights were fit to reproduce SH's V1,
which has no M/P distinction, so nothing in the objective encodes magno-dominance
— the midget/parasol labels are currently decorative with respect to the fit.

**Consequence if left alone:** every cell-type-specific lesion result from this
preset reflects an arbitrary fitting outcome rather than biology. Any claim of the
form "parasol damage causes X" is not currently trustworthy.

Possible approaches, unevaluated:
- Penalise midget weight on MT-relevant channels in `shFitClassV1Weights`.
- Fit V1 and MT stages with separate objectives rather than one V1 reconstruction.
- Accept mixed V1 but constrain the **MT** pooling weights (`shMtWts`) instead —
  closer to the anatomy, where mixing happens in V1 but MT samples selectively.

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

## 3. The low-speed tension — highest-value next experiment

Phase 2b found that **spatially heterogeneous** delay (`delay_random`) crushes
coherence (−39% lagged) and **high-pass** speed tuning (−55%), whereas **uniform**
delay does essentially nothing to steady-state tuning.

That gives a candidate mechanism for the clinical picture from a single insult:
uniform conduction slowing → VEP latency; **de**synchronised conduction across the
visual field → motion deficit.

**But there is a tension.** The reported heterogeneous-delay effect was largest on
the **high-pass** (fast, 16–160 deg/s) neuron. The clinical deficit is at **low**
speeds. `VALIDATION_SUMMARY.md` does not report the low-pass neuron under
`delay_random`, so this is currently unknown rather than contradicted.

**Experiment:** measure low-pass (0.6–9.6 deg/s) vs high-pass speed tuning under
heterogeneous delay directly. If heterogeneous delay preferentially spares low
speeds, the current mechanism does **not** explain the clinical deficit and the
hypothesis needs revising.

## 4. Motion-defined form stimulus already exists — on the `Kristin` branch

`origin/Kristin` adds `stim/mkMotionLetter.m` (283 lines), plus
`explore/showMotionLetter.m` and `showMotionLetterModel.m` — a motion-defined
letter generator, i.e. exactly the stimulus class for deficit (b). It also adds
`pars/shRgcClassesMidgetParasolTiled.m` and modifies the lagged preset.

The branch has 2 commits not in `main` and was deliberately left aside on
2026-08-13. Merging or cherry-picking it is a prerequisite for testing (b) with
the actual clinical task rather than a proxy.

---

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
