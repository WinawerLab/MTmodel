# The design logic, and what the lesion tests have shown

**Written 2026-08-19.** This is the standing report: the chain of reasoning that
produced the current model, the validation each link rests on, and the lesion
results with an explicit statement of what each one is still good for.

It replaces the two long handoff documents and the validation summary, now in
`docs/_archive/`. Read `AGENTS.md` first for orientation and how to run things;
read `docs/TODO.md` for what is open.

---

## 1. The question

> Can an RGC-level lesion explain the optic-neuritis pattern of
> **(a) increased VEP latency** and **(b) reduced recognition of motion-defined
> form at low speeds**?

Answering it requires a model in which "an RGC-level lesion" is a thing you can
*state* — which cells are affected, by how much, and how that varies across the
visual field — and in which the healthy behaviour is trustworthy enough that a
lesion delta means something. Everything below is in service of those two
requirements.

Units are pinned (SH 1998 Appendix I, p. 761; derivation in
`docs/RGC_lagged_preset_summary.md` §7.1, code in `pars/shModelUnits.m`):

**1 pixel = 0.430 deg · 1 frame = 26.9 ms (37.2 fps) · 1 px/frame = 16 deg/s.**

---

## 2. The design logic

### 2.1 One mechanism, several presets

The Simoncelli–Heeger model drives V1 from an abstract basis: spatial/temporal
derivatives of the filtered stimulus, orders 0–3. The insight the whole
architecture rests on is that this is not a different *kind* of front-end from a
retina — it is one point in a space of front-ends, all of which are "some set of
filtered channels, linearly combined into V1."

So the model carries a single class-based path. `pars.rgc.classes` is a list of
RGC classes, each with a spatial RF, a temporal kernel, a rectification, and a
gain; `shModelV1LinearFromClasses` projects the stimulus through them and
`pars.rgc.combine` says how V1 reads them out — `'steer'` for the analytic SH
steering, `'weights'` for a fitted matrix. **Presets populate that field; they are
not code branches.** This is what makes the biological front-end substitutable for
the mathematical one without a second copy of the model.

**There are exactly two ways to run the model**, and `shPars` returns each one
fully assembled:

| call | front-end |
|---|---|
| `shPars` (or `shPars('derivative')`) | `shRgcClassesDerivative` — the SH basis |
| `shPars('lagged')` | `shRgcClassesMidgetParasolLagged` — the biological front-end, with **both MT streams on** (§ two-stream MT below) |

Anything else — a lesion, a custom gain, a cleared `mtMix` — is a *variation* on
one of these two, obtained by editing the struct a preset returned. There is no
third way to run the model. In particular `shRgcClassesFourPop` is an internal
regression oracle used only by `tests/`; it is not a preset you run.

> **Dispatch trap.** `shModelV1Linear` rebuilds `pars.rgc.classes` from the
> preset named by `pars.rgc.mode`, which defaults to `'derivative'`. `shPars`
> now sets `'custom'` for you, so this only bites if you assemble
> `pars.rgc.classes` by hand — don't. If you do, and omit
> `pars.rgc.mode = 'custom'`, your classes, fitted weights, and lesion edits are
> silently discarded and you compute the plain derivative preset instead. This
> produced a run of mislabelled results before it was caught on 2026-07-16 (the
> tell: "lagged" and "derivative" outputs that were bit-identical, impossible
> for a nonlinear model).

### 2.2 The branch that was retired, and why it matters

The first attempt at a biological front-end tried to build **direction
selectivity biologically** — an ON/OFF spatial read-out offset plus an ON
quadrature kernel, following Chariker & Shapley. It was retired on 2026-07-12
(code in `explore/_archive/`, argument in
`docs/_archive/RGC_V1_design_discussion.md` §9–15):

- The fixed translational ON/OFF offset **distorts V1 orientation tuning** and
  does not rotate with a neuron's preferred direction. Removing it recovers
  orientation best.
- Direction selectivity is something the SH steerable read-out already produces
  for free. Building it biologically fights the read-out rather than adding to it.

The conclusion that survived is the load-bearing one: **the value of a biological
front-end is not a different healthy computation. It is a lesionable
parameterization** — a statement of which cells co-vary under an insult, with
kernels constrained by measured physiology. It is a *physically grounded* lesion
model, not a mathematically richer lesion space than SH.

That distinction was itself once oversold, and the correction matters for how
lesion results should be phrased. An early test claimed a conduction delay was "a
lesion axis SH cannot express." It is not: SH's basis regrouped by temporal order
supports the same delay lesion, and in the lagged preset a delay is approximately
a reweighting of the lag channels. What the biological preset buys is that the
lesion is *stated in cell-type terms* — not that it is inexpressible otherwise.
A genuine non-vacuousness test, exploiting the ON/OFF rectification SH lacks, is
still outstanding (`docs/TODO.md`).

### 2.3 Validation leg 1 — the derivative preset as an exact oracle

The derivative preset is the *validation instrument*, not a scientific claim. Its
job is to prove that the class-based machinery introduces nothing: with
`pars.rgc.classes = shRgcClassesDerivative(pars)` and `combine = 'steer'`, the
class path reproduces the legacy no-RGC model **exactly — err = 0 at
`nScales = 1`**, including the `resdirs` output.

This is the non-negotiable constraint on the repo. `tests/runAllTests.m` (14 tests)
enforces it, and the legacy RGC-disabled path stays in the tree purely as the
machine-precision oracle. Every subsequent claim about the biological preset is a
claim about a *difference from* something known to be exactly right.

The same guarantee was extended to `fourPop` (err = 0 against the old
`shModelV1LinearFromRgc`, including lagged channels), which is why the old twin
forward functions could be deleted.

### 2.4 Validation leg 2 — the lagged midget/parasol preset

`pars/shRgcClassesMidgetParasolLagged.m` is the live biological front-end:
{parasol, midget} × {ON, OFF} × lags {0,1,2,3} = 16 classes, each a
difference-of-gaussians spatial RF with a causal difference-of-gamma temporal
kernel, half-wave rectified. No offset, no quadrature — direction selectivity
comes from the SH read-out, per §2.2. Each class feeds read-out orders 0–3
(10 combinations) → 160 features, combined by a fitted weight matrix.

**What the lags are for.** A single mono- or biphasic RGC kernel cannot supply
SH's high-temporal-frequency (order 2–3) channels, and that gap capped the earlier
preset at ~0.68 correlation with legacy V1. A *difference of lagged biphasic
kernels approximates a temporal derivative*, so lagged copies let the read-out
synthesize the high orders while every individual channel stays mono/biphasic and
therefore Kling-plausible. High order lives in the linear combination, not in any
cell.

**Fidelity.** Held-out correlation with legacy SH V1
(`tests/testClassPathBiological.m`, fit on 6 stimuli, evaluated on 4 unseen):
**pooled r = 0.984**, flat across temporal frequency, against ~0.68 for the
retired preset. Read with three qualifications, all of which are in the doc and
none of which are cosmetic:

1. It is a match **to the SH model, not to data**.
2. The pooled figure hides per-neuron spread: median 0.984, max 0.997,
   **minimum 0.709**.
3. Samples are not independent — neighbouring (y,x,t) locations overlap heavily
   under 9-tap filters, so effective *n* is far below nominal.

A later, independent measurement on a different stimulus with differently-cached
weights (`explore/fitMagnoMtPopulation.m`) put the same mixed population at median
r = 0.93–0.95. The two are not directly comparable; **the ~0.985 figure should not
be quoted as if it were a stable property of the preset.**

The healthy lagged copies are **not** pathological conduction delay. Optic-neuritis
timing deficits go through `pars.rgc.impairmentDelayMap` or per-class kernel edits.

**Known scale problems, carried openly** (`docs/RGC_lagged_preset_summary.md` §7.1):
at 0.43 deg/px the midget centre σ is 0.34 deg against ~0.02–0.05 deg for real
midgets — the midget/parasol *ratio* is preserved, the absolute scale is off by
roughly an order of magnitude. The 0–3 frame lags are 0–81 ms, far too long for
optic-nerve conduction differences (a few ms) and better justified as lagged LGN
or delayed inhibition. The DoG surround integrates to only 12–13% of centre, so
these are near-lowpass centres rather than genuine band-pass filters.

### 2.5 Validation leg 3 — making M/P mean something at MT

This is the step that turns the midget/parasol labels from decoration into
biology, and it is where the *previous* configuration failed.

**The failure.** The 160-column weight matrix was fitted to reproduce SH's V1,
which has no M/P distinction. Nothing in that objective encodes magno-dominance,
so the fit came out **midget-dominated**: zeroing midget classes collapsed MT
direction tuning, while zeroing parasol classes left it intact and *raised* the
peak (+25%). That is Maunsell et al. (1990) exactly backwards, and it contradicts
SH's own p. 754 premise. **Any cell-type-specific lesion result from that
configuration reflects an arbitrary fitting outcome, not biology.** This is the
"lagged preset without M/P segregation" configuration, and it is the reason the
2026-07 lesion campaign is archived rather than live.

**The architectural fact that made the fix cheap.** `shMtWts` computes V1→MT
weights *analytically* from the direction geometry
(`sum(shQwts(dirs) * pinv(shQwts(pars.v1PopulationDirections)))`). Nothing there
is fitted and it carries no cell-type information. **MT's M/P dependence is
therefore set entirely by the RGC→V1 weight matrix.** Corollary and trap: this
cannot be done by *subsetting* the 28 V1 neurons — the `pinv` needs the full
direction tiling. Mask the *features*, never the neurons.

**What the anatomy constrains** (Nassi & Callaway 2006, 2007): MT-projecting
layer-4B cells are 76% spiny stellate, receiving input only from M-dominated 4Cα
(disynaptic label after an MT injection is ~96–97% in 4Cα). MT *does* receive
parvocellular input, but by a 3–5 synapse detour through V2 thick stripes, and
V2-projecting 4B cells are 83% pyramidal and integrate mixed M and P. The
structural point: **biology puts M/P selectivity in two distinct populations, not
in a graded weighting.** The old model had one population, and it was the mixed one.

**The design.** MT pools a two-stream mixture, formed post-normalization in
`shModelV1ComplexForMt` so the streams do not share a V1 normalization pool:

```
popMT = (1 - alpha) * popA  +  alpha * delay(popB, d)
```

- **popA — "4B→MT", the fast magno drive.** The same 28 neurons refitted against
  the same SH target with the feature matrix masked to the 80 parasol columns
  (`shClassFeatureMask(pars, '^parasol')`). Parasol share = 1.0 by construction.
- **popB — "→V2→MT", the slow minority drive.** The **existing mixed fit,
  unchanged** — justified because the V2 relay carries mixed M and P. No second
  fit needed, and popB remains the validated V1 stage.
- **alpha = 0.10, d = 0.** The midget drive is *imposed and never fitted*:
  unmasking midget columns would let ridge regression re-inflate the midget share,
  with nothing in the objective holding it down. `d = 0` because the V2 detour is
  ~5–10 ms, well under one 26.9 ms frame — and the latency separation is already
  present for free, since the midget kernel peaks at ~107 ms against the parasol
  kernel's ~27 ms.

Because the MT stage is linear in `pop`, the mixture is exactly
`(1-alpha)*MT(popA) + alpha*MT(popB delayed)`, which makes knockout bookkeeping
trivial. Verified by two bit-exact identities (stream A set to the default weights
reproduces the no-mix baseline at both alpha = 0 and alpha = 1); the suite stays
14/14. `'v1Complex'` is untouched, so **the validated V1 stage is unchanged** —
only MT sees the mixture.

**Stopping criteria were pre-registered, and both were met.**

*Check 1 — masked fit quality.* The predicted partial failure happened, exactly
where predicted. Reconstruction of the legacy V1 target, binned by the neuron's
tf/sf preference:

| tf/sf band | neurons | median *r*, B (mixed) | median *r*, A (parasol) | loss |
|---|---|---|---|---|
| 0.22–0.30 (slow) | 12 | 0.95 | ~0.55 | ~0.40 |
| 0.43–0.81 (mid)  | 9  | 0.93 | ~0.75 | ~0.17 |
| 1.41–1.63 (fast) | 7  | 0.90 | ~0.82 | ~0.07 |

Monotonic. The parasol-only basis is a **good** V1 model for the fast neurons —
the ones MT weights most — and a poor one for the slow sustained ones. That is
precisely the Nassi & Callaway division of labour. The whole-tiling median
(0.930 → 0.706) should **not** be quoted as the headline.

The mechanism is visible in the tuning, not the residual
(`explore/measurePreferredTfSf.m`): nominal preferred (sf, tf) is identical for
both populations by construction, but at the slow end population A prefers a
higher tf than B for **13 of 13** neurons (median ×1.40 vs nominal, against B's
×0.94), while at the fast end A and B agree for 6 of 7. Denied midget input, slow
neurons drift toward the frequency the fast parasol kernel actually prefers.
*Caveat:* the log grid quantizes to ×1.31 per step, so ×1.40 is ~1 step —
credible because unanimous, not because any single row is precise.

*Check 2 — Maunsell reproduction.* Percent change from each architecture's own
intact model; "pop" columns are over the 19-neuron MT population:

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

Against Maunsell: M block "pronounced and often complete" (81% population median,
95% of units); P block "very little effect" on the typical unit (2.7% median)
while unequivocal for **a minority** (5% = 1 of 19 units over 20%); combined block
"essentially eliminates" the response (89.5%, DSI −100%). `alpha >= 0.20` breaks
it — the P block reaches 37% of units and rivals the M block — so the criterion
brackets alpha tightly to 0.05–0.10. **0.10 adopted**, because it keeps the P
contribution real rather than vanishing, which is what Maunsell actually reported.

Note a dissociation that was not designed in: midget knockout leaves **DSI
unchanged at every alpha** (−0.0%) — it scales MT down without disturbing
direction tuning — whereas parasol knockout destroys it. The two pathways are no
longer interchangeable in this model.

*First evidence for the clinical mechanism.* Midget dependence concentrates
sharply at **low** preferred speed — median midget-knockout effect by MT preferred
speed (1 px/frame = 16 deg/s):

| pref speed | alpha=0.05 | alpha=0.10 |
|---|---|---|
| 0 px/frame | −25.0% | **−45.2%** |
| 1 px/frame | −5.4 to −7.8% | −11.4 to −15.3% |
| 6 px/frame | −0.7 to −0.9% | **−1.4 to −1.9%** |

A 10–30× gradient from slowest to fastest. An insult to the midget pathway would
preferentially cost low-speed motion — which is where the clinical deficit is.
**Caveat, and it matters:** every MT neuron here was probed with the *same*
grating, optimal for the slow test neuron, so fast-preferring units were driven
off-peak and their small effects are partly confounded with that. Suggestive, not
settled; the proper test is per-neuron speed tuning with alpha on vs. off.

### 2.6 The healthy baseline on the target stimulus

`stim/mkMotionLetter.m` builds a Regan-style motion-defined letter (letter dots
drift one way, background dots the other) — the deficit-(b) stimulus. Seeded,
5 deg/s, letter 'C', 128×128×120, `explore/runMotionLetterDemo.m`:

| stage | derivative preset | midgetParasolLagged |
|---|---|---|
| V1 opponent d' | +0.23 | +0.22 |
| MT opponent d' | **+1.32** | **+1.32** |

**MT recovers the letterform; V1 barely does.** The two RGC presets are
indistinguishable, which is the expected result for a healthy-condition stimulus
and the right baseline for lesioning. Three controls establish that the
segregation is genuinely motion-based: opposite drift +1.32, static background
+1.30, **same drift (no relative motion) −0.34**. Static-luminance d' on the
time-averaged image is ≈0, so there is no static cue to exploit. MT d' is **flat**
from 1 to 48 deg/s (an earlier claim that it improved with speed was an artifact
of a broken opponent-unit selector, since fixed).

**Do not use frame-scrambling as the motion control** — permuting whole frames
displaces letter and background dots by equal and opposite amounts, so relative
direction survives it.

**Open, and it gates any quantitative clinical claim:** at 2.33 px/deg a
clinically sized letter (2.8 deg) is only ~6.5 pixels. The demo therefore sets the
letter in model pixels (~34 deg implied) and reports the angular size. Reconciling
that with the order-of-magnitude RGC spatial-scale offset (§2.4) is unresolved.

A standing scale tension for all of §4 too: MT is tuned to {0, 1, 6} px/frame =
{0, 16, 96} deg/s, so **the entire clinical low-speed band sits below MT's slowest
non-zero tuned speed.**

---

## 3. What "a lesion" means here

Three orthogonal choices, and the results in §4 are organized by them.

**Axis** — what is damaged:
- **amplitude**, a multiplicative gain reduction;
- **delay**, an integer-frame shift of the temporal kernel;
- **both together.**

**Scope** — which cells:
- **class-agnostic** (all RGC classes equally), which is a statement about the
  optic nerve as a whole;
- **class-selective** (parasol-only, midget-only, ON-only), which is the
  statement only a biological front-end can make — and which requires §2.5's
  two-stream MT to be interpretable.

**Spatial profile** — how it varies across the visual field:
- **uniform**, the same everywhere;
- **non-uniform**, via `shApplyRgcImpairment`'s amplitude/delay maps: *random*
  (independent per pixel), *patchy* (spatially correlated, Gaussian-smoothed
  σ = 3), or *coupled* (low amplitude ⇒ high delay, the most realistic).

Mechanically: spatial maps go through `pars.rgc.impairmentAmplitudeMap` /
`impairmentDelayMap`; class-selective damage is applied by editing
`pars.rgc.classes(i).gain` / `.temporalKernel` before the forward pass. Weights
are **not** refitted after a lesion — optic neuritis is a within-subject delta, so
fixed weights isolate the RGC effect from cortical re-adaptation.

---

## 4. Lesion results

**Read §5 before quoting any of these.** Every number below was measured through
the *pre-mtMix* MT (single mixed weight matrix). The class-agnostic rows are
statements about the front-end and V1 and are likely to survive; the
class-selective rows are not interpretable as biology.

### 4.1 The matrix as it stands

| axis | uniform | non-uniform |
|---|---|---|
| **amplitude** | gain 0.5, all classes ✓ | random U(0.3,0.7) ✓ · patchy σ=3 ✓ |
| **delay** | 2 frames, all classes ✓ | random {0,1,2,3} ✓ · patchy ✓ |
| **both** | **✗ never run** | coupled amp↔delay ✓ (deterministically tied) |

Two gaps, both worth closing: there is **no uniform amplitude + uniform delay
condition at all**, and the only combined condition (`coupled`) ties the two axes
together by construction rather than varying them independently.

### 4.2 Uniform amplitude — hits gain, spares tuning shape

Gain 0.5 on all classes: speed-tuning peaks fall **−35% to −49%**, coherence peak
**−9% to −18%**, while direction peak, DSI and FWHM are **barely touched**. A
uniform amplitude loss scales the response down without reorganizing what the
population is tuned to.

**Do not read this as "amplitude lesions don't matter."** §6.1 shows the flat
direction tuning is divisive normalization absorbing the lesion — the model's own
contrast-response nonlinearity — and §6.3 argues that the absorption is itself the
damage once cortical noise is present.

### 4.3 Uniform delay — does essentially nothing

2 frames on all classes: **~0%** on direction peak, DSI, FWHM, and speed peak, for
both presets. This is expected rather than surprising — a uniform phase shift does
not change the time-averaged response to a periodic drifting grating. It is also
the single most important negative result in the set, because it means **uniform
conduction slowing is invisible to steady-state tuning measures.** If uniform
slowing is to explain deficit (a), the observable has to be a latency measure, not
a tuning measure.

### 4.4 Non-uniform amplitude — behaves like uniform amplitude

Random, patchy and coupled amplitude lesions all land in a similar band
(**~9–18% coherence-peak drop**), comparable to the uniform case. Spatial
heterogeneity in *amplitude* buys little beyond its mean.

**§6.4 predicts this equivalence is an artifact of the deterministic model** and
should break once cortical noise is present, because the spatially blurred
normalization pool gives damaged locations less gain rescue under a heterogeneous
lesion than under a uniform one.

### 4.5 Non-uniform delay — the one large effect

This is the headline result, and it is a dissociation, not a magnitude:

| delay lesion | coherence peak | high-pass speed tuning |
|---|---|---|
| uniform, 2 frames | ~0% | ~0% |
| patchy (spatially correlated) | tracks uniform | tracks uniform |
| **random (per-pixel {0,1,2,3})** | **−59% derivative / −39% lagged** | **−64% / −55%** |

**It is spatial heterogeneity — decorrelation — in conduction delay, not delay
magnitude, that disrupts motion and coherence pooling.** Desynchronized timing
across space breaks the spatial pooling that coherence and speed tuning depend on;
a delay that is uniform, or correlated over patches, largely preserves it.

This is the sharpest thing the model has said, and it suggests a single insult
producing both clinical signs: *uniform* slowing → VEP latency; *desynchronized*
conduction across the field → motion deficit.

**But there is a standing tension.** The heterogeneous-delay effect was largest on
the **high-pass** neuron (1–10 px/frame = 16–160 deg/s). The clinical deficit is at
**low** speeds. The low-pass neuron (0.0375–0.6 px/frame = 0.6–9.6 deg/s) — which
is squarely the clinically interesting band — was **not reported** under
`delay_random`, so this is currently unknown rather than contradicted. This is the
highest-value open experiment (`docs/TODO.md` §3), and §2.5's speed-graded midget
dependence is the candidate mechanism that would resolve it.

### 4.6 Class-selective lesions — measured, but not interpretable as biology

For the record: parasol-only gain 0.3 *raised* direction peak (+22%) while
broadening tuning (FWHM +7.4%), degrading DSI (−3.2%), and crashing coherence
(−47% seeded; the −52% figure sometimes quoted came from an unseeded run and is
~5 points off). An ON-only 1-frame delay was also run.

These came from the midget-dominated MT of §2.5, so even the *sign* of the parasol
effect is a fitting artifact. **They must be re-run through the two-stream MT
before any of them is used.** A seeded rerun is what
`explore/compareLesionsToBaseline.m` exists for.

### 4.7 One methodological note that changed numbers

The 2026-07 lesion figure scripts **never seeded the RNG**, and Figs 11–14 use
random dot fields — so lesion-vs-baseline differences there were confounded with
dot-sample noise, worth ~5 percentage points on the parasol coherence effect.
`explore/compareLesionsToBaseline.m` seeds explicitly, plots lesion and baseline
on shared axes, and states remaining gain unambiguously; it is the model for any
new lesion script. `validateSHFigs9to14_lesions.m` still does not seed.

---

## 5. Validity ledger — what has to be re-run

| result | status |
|---|---|
| derivative preset reproduces legacy exactly | **current** — enforced by `tests/runAllTests.m` |
| lagged preset healthy fidelity to SH V1 | **current**, with the ~0.985 vs 0.93–0.95 discrepancy unresolved (§2.4) |
| two-stream MT reproduces Maunsell knockouts | **current** (2026-08-14) |
| speed-graded midget dependence | **current but confounded** — one fixed grating for all units |
| motion-letter healthy baseline, d' = 1.32 | **current** (2026-08-17) |
| uniform vs. non-uniform amplitude/delay lesions | **pre-mtMix** — the front-end conclusion likely survives, the MT numbers need re-measuring |
| parasol-only / ON-only lesions | **invalid as biology** — measured on the midget-dominated MT |
| the 114 campaign figures + metrics CSVs | **gone** — `explore/_figs/` is gitignored and has been cleared; the scripts still live |

The consolidated re-run that would clear most of this in one pass: the §4 lesion
matrix — with the missing uniform amp+delay cell added, and the low-pass neuron
reported under `delay_random` — through the two-stream MT, seeded, with the
motion-defined letter as an additional read-out alongside the SH Figs 9–14 tuning
measures.

---

## 6. Next: noise

Moved to its own document: **[`NOISE_AND_DEMYELINATION.md`](NOISE_AND_DEMYELINATION.md)**
— the demyelination pathophysiology and how it maps onto the lesion parameters,
the three noise sites, JW's gain-compensation mechanism, and the predictions that
follow. Its §6 is measured (`explore/compensationIndex.m`); the rest is design.

The three points from it that change how §4 above should be read:

1. **§4.2's null result is normalization, and this is now measured.** Both
   cortical stages compute `R = s*N / (strength*D + sigma^2)` with the pool `D`
   driven by the *lesioned* input, so a uniform amplitude lesion — which is, to
   first order, a contrast reduction — is absorbed by a gain that rises as the
   lesion deepens. Measured compensation index C = 0.64–0.92: **a 50% gain cut
   costs 12–25% of the MT response where without normalization it would cost
   75%.** The correct reading of "a 50% gain cut barely moves direction tuning"
   is not *amplitude lesions don't matter*; it is **normalization hid it, and with
   cortical noise present the hiding is itself the damage**: near-normal tuning
   curves, degraded discriminability.
2. **Three pathophysiological mechanisms are currently inexpressible** — trial-to-
   trial spike jitter, stochastic conduction block, and high-frequency conduction
   failure. The first two need noise; the third needs a kernel-shape lesion and
   could be run now. `delay_random` (§4.5) models only the *static* half of
   temporal dispersion, not the trial-varying half.
3. **§4.4's uniform/heterogeneous amplitude equivalence is predicted to break**
   once noise is present, because the spatially blurred normalization pool gives
   damaged locations less gain rescue under a heterogeneous lesion than under a
   uniform one.

Until that work is done, phrase the §4 conclusions as *"heterogeneous delay
disrupts steady-state tuning where uniform amplitude loss does not"* — which is
what was measured — rather than as *"amplitude lesions matter less"*, which is a
claim about behaviour that the deterministic model is not equipped to make.
