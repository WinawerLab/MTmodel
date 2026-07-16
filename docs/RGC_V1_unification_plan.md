# RGC → V1 Unification: Design Notes & Handoff

Last updated: 2026-07-12 (session with J. Winawer)

> **This is the authoritative "current state + next steps" document for the RGC
> front-end work.** Start at `AGENTS.md` (repo root), then read this. For the
> reasoning behind the design, see `RGC_V1_design_discussion.md`.

This document is a **self-contained handoff**. If you are a fresh agent picking
this up (e.g. on the laptop after a `git pull`), read this top-to-bottom before
touching code. It records what we established, the decisions we made, and the
concrete next steps. It supplements `AGENTS.md` (which documents the *current*
code); this document describes the *direction we are moving toward*.

---

## 1. Goal (unchanged)

Add a biologically-motivated retinal ganglion cell (RGC) layer before V1 so the
model can simulate optic-neuritis impairments, while keeping healthy-condition
V1/MT responses close to the legacy Simoncelli–Heeger (SH) model.

## 2. What this session established

### 2.1 The two-view V1 receptive field (validated exactly)

A V1 neuron's linear RF can be viewed two equivalent ways, and we can build both
analytically from `pars`:

- **RGC-referred**: `RF_rgc` is `Y × X × nClass` — for each RGC class (temporal
  channel) `k`, the neuron's spatial weighting of that class:
  `RF_rgc(:,:,k) = Σ_{n: torder(n)=k} w(n) · yfilt_n ⊗ xfilt_n`.
- **Stimulus-referred**: `RF_stim` is `Y × X × lag` —
  `RF_stim(:,:,τ) = Σ_k RF_rgc(:,:,k) · tf_k(τ)`, i.e. the class maps carry the
  temporal kernels.

Here `w = shSwts(direction)` (10-vector), `xfilt/yfilt = v1SpatialFilters(:,order+1)`,
`tf_k = v1TemporalFilters(:,k+1)`. There are **28** V1 neurons, **9-tap** filters,
so `RF_rgc` is 9×9×4 and `RF_stim` is 9×9×9.

**Verification:** feeding a 9×9×9 stimulus (single output location) through the
real model and comparing to the analytic RF gives max error **6e-16** across all
28 neurons. Script: `explore/showV1RfDerivative.m`.

### 2.2 'derivative' and 'fourPop' are the SAME machinery (validated)

The `fourPop` path (`shModelV1LinearFromRgc` + `shFitRgcV1Weights`) is already the
*general* model: 4 RGC classes × 10 spatial-derivative read-outs = 40 features →
fitted weights → V1. `derivative` mode is the special case where the RGC classes
are (delta spatial RF, SH temporal-derivative kernels) and the weights are
available *analytically* (`shSwts`) instead of fitted.

**Experiment (`explore/unifyDerivativeVsFourPop.m`):** run the identical
40-feature projection + ridge fit, swapping only the RGC classes.

| RGC classes                                 | held-out test corr vs legacy     | NRMSE  |
| ------------------------------------------- | -------------------------------- | ------ |
| derivative (delta × SH temporal-derivative) | **0.99991** (1.0 modulo ridge λ) | 0.0015 |
| fourPop (DoG × biphasic)                    | 0.693                            | 0.079  |

Cross-check: the derivative 40-feature projection *contains the exact 10-column
structured basis* as a sub-selection (err = 0). **Conclusion: the two "modes" are
one implementation with different RGC-class parameters.** They should be collapsed.

### 2.3 Clarified the two levels (important — we confused these mid-session)

- **RGC classes** = populations, each = one spatial RF + one temporal kernel.
  There are **4** (both modes). The RGC layer emits 4 channel images `[Y X T]`.
- **V1 read-out** = spatial-derivative filters V1 applies to each RGC image. The
  "4/3/2/1", "10", and "40" are all counts of *V1 read-out filters*, never RGC
  classes.
- The SH basis constraint is **total order `t+x+y = 3`** (not spatial `x+y=3`).
  The 10 basis functions are the `(t,x,y)` triples summing to 3; grouped by
  temporal order they are 4/3/2/1. This is the **diagonal** of the 4×10
  (class × spatial-read-out) grid; `fourPop` fills the whole grid, `derivative`
  uses only the diagonal.

### 2.4 Temporal-frequency coverage: biological kernels vs SH (the MT concern)

SH's four temporal kernels are successive temporal derivatives (0–3 zero
crossings) that **tile** temporal frequency; peak TF marches 0 → 0.129 → 0.178 →
0.215 cyc/frame. The biological difference-of-gamma kernels currently in the code
(only **2 distinct**: fast/slow, reused across ON/OFF) peak at only 0.105 (fast)
and 0.021 (slow) cyc/frame — i.e. they cover **only the lower half** of SH's
range (≈ order 0–1). Kling (2020) Fig. 4A confirms all four human RGC classes are
monophasic-to-biphasic; there is **no single-RGC counterpart** to SH's tri-/quad-
phasic (order 2–3, high-TF) channels.

**Why it matters:** SH's V1 population deliberately tiles a *range* of SF/TF
(narrowband individually) so MT can build **speed tuning** by pooling across it.
Biological kernels alone truncate that range → truncated MT speed range. This is
a concern separate from direction selectivity. Script:
`explore/compareTemporalKernels.m`.

### 2.5 Adelson & Bergen (1985) — how DS is built, and the minimal basis

- Direction selectivity is a **cross-term**: an oriented (space-time inseparable)
  RF = (spatial phase A × temporal kernel 1) ± (spatial phase B × temporal
  kernel 2). "A single separable filter can never be directionally selective;
  the minimum is a sum of two separable filters."
- **Reconciliation of the "clean" idea:** V1 = a *time-invariant* spatial
  weighting of RGC outputs IS sufficient for DS, **provided the weighting differs
  per RGC class**. No temporal filter is needed between RGC and V1; the RGC
  classes supply the temporal diversity, V1 supplies class-specific spatial
  weights, DS emerges from the cross-term.
- Minimal basis for DS: **2 temporal × 2 spatial phases** (not 10 per class). The
  fourPop 4×10 grid is over-complete. Temporal variety should live in the
  classes; V1 reads each through only a **small number** of spatial phases.

### 2.6 Chariker & Shapley (2021 theory / 2022 params) — biological DS mechanism

DS in macaque 4Cα (magno/**parasol** input) arises from two ingredients:
1. **Spatial wiring:** ON and OFF fed to **spatially offset** subregions.
2. **Temporal difference:** ON pathway **delayed ~9–11 ms** (they use 10 ms)
   relative to OFF (Mechanism #1, a pure time shift; Mechanism #2 additionally
   reshapes the ON kernel). Sum → spatiotemporal inseparability → DS, **broadband
   in SF and TF**.

Their kernel (magno): `K(t) = t⁶/τ₀⁷·e^(−t/τ₀) − t⁶/τ₁⁷·e^(−t/τ₁)`, τ₀=3.66 ms,
τ₁=7.16 ms, power **n=6**, positive→negative crossover at 36 ms, peak TF ≈ 10 Hz.

This is Adelson–Bergen realized biologically: the two temporal phases = OFF
(early) & ON (late); the spatial phase = the ON/OFF subregion offset. It maps
directly onto §2.5's "class-specific spatial weighting of temporally-distinct
channels."

### 2.7 Prototype result: delay gives narrowband DS; quadrature gives broadband

`explore/prototypeOnOffDelayDS.m` is a 1D linear simulation of the mechanism (OFF
subregion at 0, ON subregion offset by `d`, ON kernel modified; measure F1 to
gratings drifting both ways across TF). Findings:

- **Both ingredients are required.** DSI is *exactly 0* when the ON delay OR the
  spatial offset is removed (controls). DS is a genuine cross-term.
- **A pure ON time delay gives frequency-dependent DS** (DSI rises with TF,
  strong only at high TF) — matching Chariker Mechanism #1 ("DS at TFs above
  ~4 Hz"). In this linear model the DS is *kernel-shape-independent*: parasol and
  midget give identical DSI. The kernel sets the response *passband*, the ON/OFF
  phase sets DS.
- **A constant-phase (≈90° quadrature) ON/OFF kernel difference gives broadband
  DS** (DSI roughly flat across TF; parasol quad mean 0.76, midget 0.58),
  reproducing Chariker's broadband-DS signature (their Mechanism #2). The exact
  Hilbert quad is acausal; biology approximates it with a *shaped causal* ON
  kernel.

**Design consequence:** implement the ON/OFF difference as a **kernel-shape
(phase) difference approximating quadrature**, not merely a fixed time lag — a
lag alone only buys high-TF DS. Parasol/midget kernels then set the TF passbands;
together they broaden TF coverage for MT.

## 3. Decisions made this session

1. **Keep the SH analytic derivative basis** as the healthy-baseline path (it is
   exact and provides the SF/TF range MT needs for speed tuning).
2. **Unify** `derivative` and `fourPop` into one class-based implementation; they
   become *parameter presets*, not code branches (see §2.2).
3. **Adopt an ON/OFF kernel-shape (phase) difference as the temporal-phase source
   for DS** (Chariker/Shapley), rather than downstream lag-copy channels. Apply it
   for **two class types — midgets and parasols** — giving ON/OFF × midget/parasol
   with distinct midget vs parasol kernels. **Refined by the §2.7 prototype:** the
   ON/OFF difference should approximate a constant-phase (~90° quadrature) causal
   kernel difference (Chariker Mechanism #2) for *broadband* DS — a pure ~10 ms
   delay alone (Mechanism #1) only yields high-TF DS. The schema should therefore
   carry a per-class ON/OFF kernel *pair* (or a phase parameter), not just a
   scalar delay.
4. **The ON-vs-OFF spatial offset lives in the V1 read-out** and is *where DS is
   actually assembled* — design it explicitly, not as an accident of the
   derivative read-out.
5. **The MT/TF-range gap is separate from DS.** The high-TF (order 2–3) channels
   have no single-RGC counterpart and remain *synthesized* (keep SH basis for the
   healthy baseline; optionally build via multi-timescale + delays later).
6. If explicit ON/OFF spatial-offset wiring becomes cumbersome, fall back to a
   clean Adelson–Bergen skeleton (even/odd spatial × 2 temporal phases).

## 3.5 SCOPE PIVOT (2026-07-12) — supersedes decisions 3, 4, 6 above

Full reasoning: `RGC_V1_design_discussion.md` §9–15. In brief, decisions 3/4/6
(build direction selectivity biologically via an ON/OFF temporal-quadrature +
spatial-offset mechanism) are **retired**. Why:

- The fixed translational ON/OFF offset **distorts V1 orientation** and does not
  cleanly rotate with a neuron's preferred direction (`explore/probeOffsetOrientation.m`);
  removing it recovers orientation *best*. DS is something the SH steerable
  read-out already yields for free — building it biologically fights that.
- The real value of a biological front-end is **not a different healthy
  computation** but a biologically-identifiable, **lesionable parameterization**
  (optic-neuritis timing/amplitude deficits) — a *physically-grounded lesion model*
  (which cells co-vary under an insult, with kernels constrained to measured
  physiology), **not a mathematically richer lesion space** than SH. NOTE
  (corrected 2026-07-13, design-discussion §16): the earlier claim that a
  conduction delay is "a lesion axis SH cannot express" (from
  `explore/lesionDeltaTest.m`) was **oversold**. That test's 85% measures
  delay-vs-amplitude *within* the biological model; SH's basis regrouped by
  temporal order supports the same delay lesion, and in the adopted *lagged* preset
  a delay is ≈ a reweighting of the lag channels. A genuine biological-vs-SH
  non-vacuousness test (exploiting the ON/OFF rectification SH lacks) is still TODO.
- The §2.4 high-TF gap is **closed by lags**, not by exotic biology: a bank of
  mono/biphasic kernels + small lags reconstructs SH's order 0–3 basis to
  R² ≥ 0.975 (`explore/temporalTilingFromLags.m`), and in the *real* model a
  **lagged** biological preset (no offset/quadrature) reaches **~0.985** legacy-V1
  correlation, flat across TF, vs ~0.68 for the offset+quadrature preset
  (`explore/testLaggedBiologicalFidelity.m`). The ~0.70 "biological ceiling" was a
  preset artifact (2 unlagged kernels), not a biological wall.

**Revised decisions (supersede 3, 4, 6):**

3′. DS for the healthy baseline comes from the **SH steerable read-out**, as in the
   derivative preset — not from an ON/OFF offset/quadrature mechanism. The
   biological-DS question (Chariker/Shapley) is an optional side-quest, not on the
   critical path.
4′. **Drop machine-precision healthy-equivalence as a requirement for the
   biological path.** Keep the derivative preset as the exact oracle; the
   biological path is an approximate baseline whose job is realistic lesion
   *deltas* (optic neuritis is a within-subject delta anyway). High fidelity is
   nonetheless *reachable* with lags (~0.985).
6′. Meet MT's SF/TF tiling by **adding lagged biphasic classes** (option i in
   decision 5), not by narrowing the range. New preset:
   `pars/shRgcClassesMidgetParasolLagged.m` (biological midget/parasol, DoG RFs,
   ON/OFF, **no offset/quadrature**, lagged copies).

Decisions 1, 2, 5 stand. Increments 1–3c (the unification refactor) are unaffected
and remain the current architecture.

## 4. Next steps (do these next)

**(2) Write the unified `pars.rgc.classes` schema.** Each class entry carries:
- `label` / `type` (e.g. 'onParasol'), `polarity` ('on'/'off'),
- `temporalKernel` (vector) and/or its generating params,
- `onOffDelayFrames` (≈10 ms → frames; ON delayed relative to OFF),
- `spatialRF` (delta for the analytic preset; DoG for biological),
- `spatialReadoutOrders` (which V1 spatial-derivative orders this class feeds —
  singleton `{3−k}` for the derivative preset's diagonal; `{0..3}` for fourPop),
- and, for DS, the ON-vs-OFF **spatial offset** used by the V1 read-out.

Presets that *populate* this field (not code branches):
`shRgcClassesDerivative(pars)` (analytic, exact) and a biological
`shRgcClassesMidgetParasol(pars)`. Then: **one** forward function, **one** weight
step (analytic for the derivative preset, fit otherwise), **one** RF extractor +
viewer (`shV1Rf` / `shShowV1Rf`, class-agnostic — the two-view viz in
`explore/showV1RfDerivative.m`).

**Refactor progress (incremental, keeping the oracle green):**

- **Increment 1 — DONE (2026-07-10).** Schema + generic forward for the
  derivative preset. New files: `pars/shRgcClass.m` (class constructor),
  `pars/shRgcClassesDerivative.m` (derivative preset), and
  `model/innerworkings/shModelV1LinearFromClasses.m` (the single class-based
  forward; `combine='steer'` for analytic SH steering, `combine='weights'` for a
  fitted matrix). Verified to reproduce the existing derivative path *and* legacy
  **exactly (err = 0)** — see `explore/verifyClassPathDerivative.m` and the new
  `tests/testClassPathDerivative.m` (now in `runAllTests`, 10/10 pass). Nothing in
  the existing dispatch was changed, so the default path is untouched.
- **Increment 2 — DONE (2026-07-10).** Biological preset on the class path. The
  feature builder was factored out to `model/innerworkings/shClassV1Basis.m`
  (shared by the forward and the fitter); its `localClassChannel` now implements
  the DoG spatial RF + ON/OFF half-wave rectification, and the ON/OFF `readoutOffset`
  is applied (a `circshift` of the class channel). New:
  `pars/shQuadratureKernel.m` (90-deg Hilbert phase shift, the ON/OFF constant-
  phase partner), `pars/shRgcClassesMidgetParasol.m` (ON/OFF x midget/parasol with
  quadrature ON kernels + spatial offset -> 4 classes x 10 read-outs = 40
  features), and `help/shFitClassV1Weights.m` (ridge fit for `combine='weights'`).
  Verified end-to-end (`explore/verifyClassPathBiological.m`, `tests/testClassPathBiological.m`,
  11/11 pass): held-out legacy-V1 correlation ~0.70, on par with the old fourPop
  ceiling (~0.69), finite. As expected, the quadrature aids DS but cannot recover
  the missing high-TF orders, so legacy reconstruction still caps ~0.7. Existing
  dispatch remains unchanged.
- **Increment 3a — DONE (2026-07-10).** Dispatch switch. `shModelV1Linear`'s
  default derivative path now routes through `shModelV1LinearFromClasses`; `shPars`
  populates `pars.rgc.classes` (derivative preset) + `pars.rgc.combine='steer'` so
  the class parameterization is live. Added the 4th (`resdirs`) output to the class
  forward. The legacy per-channel lesioning hook (`pars.rgc.derivative.channelGain`)
  is honored by mapping it onto the classes' per-class gains in the dispatch.
  Verified exact vs legacy incl. the `resdirs` output (err = 0); `testClassPathDerivative`
  extended to cover it; 11/11 pass. `'fourPop'` mode still uses its old path.
- **Increment 3b — DONE (2026-07-10).** Class-agnostic RF viewer. `help/shV1Rf.m`
  computes a V1 neuron's RF referred two ways from `pars.rgc.classes` (RGC-referred
  per-class spatial maps `RFrgc` [fsz x fsz x nClass]; stimulus-referred linear
  space-time RF `RFstim`), for either `steer` or `weights` combine.
  `show/shShowV1Rf.m` draws both figures. Verified: derivative `RFstim` reproduces
  the model to ~6e-16; biological preset renders per-class maps + distinct ON/OFF
  quadrature kernels. `tests/testV1Rf.m` added; 12/12 pass.
  (`explore/showV1RfDerivative.m` is now superseded by these.)
- **Increment 3c — DONE (2026-07-12).**
  - **(2026-07-10) optic-neuritis impairment on the class path.** Impairment
    logic (spatial amplitude deficit + integer-frame delay) was extracted to
    the shared `model/innerworkings/shApplyRgcImpairment.m`, used by both
    `shClassV1Basis` (class path) and `shModelRgc` (fourPop) so they stay
    consistent. `shClassV1Basis` applies it to each class channel. Verified: a
    uniform 0.5 amplitude map scales the linear V1 response by exactly 0.5;
    localized/delay deficits change the output and stay finite; non-integer
    delay errors. `tests/testImpairment.m` added; 13/13 pass.
  - **(2026-07-12) `'fourPop'` migrated to a class preset.** New
    `pars/shRgcClassesFourPop.m` builds the 4 base classes (onFast/offFast/
    onSlow/offSlow, DoG spatial RF + causal bi-gamma temporal kernel) plus
    optional lag classes (`onFastLag`/etc., built as the same class with a
    zero-padded kernel -- a post-hoc D-frame delay of a causally-filtered
    channel is algebraically identical to convolving with the kernel preceded
    by D zero taps) whenever `pars.rgc.temporal.fastLag`/`slowLag` > 0. Only
    `pars.rgc.onOffSignSplit = 'contrast'` and `pars.rgc.temporal.mode =
    'causal'` are supported (the only settings exercised elsewhere). Verified
    to reproduce the legacy fourPop feature basis (`shModelV1LinearFromRgc` /
    `shModelRgc`) **exactly (err = 0)**, including lagged channels, once
    columns are permuted for the two paths' different (but equivalent)
    read-out block ordering -- see `explore/verifyClassPathFourPop.m` and
    `tests/testClassPathFourPop.m` (now in `runAllTests`, 14/14 pass).
    `shModelV1Linear`'s `'fourpop'` dispatch now routes through
    `shModelV1LinearFromClasses` (mirroring `'derivative'`); a new
    `pars.rgc.classesMode` field records which preset built `pars.rgc.classes`
    so switching `pars.rgc.mode` on an already-built `pars` rebuilds the right
    preset instead of silently reusing stale classes from the other mode.
    `pars/shPars.m` now fits fourPop's `v1Weights` via `shFitClassV1Weights`
    (not `shFitRgcV1Weights`). All dependent tooling migrated to the class
    path: `help/shCalibrateRgcLayer.m`, `help/shSweepRgcTemporalPars.m`,
    `help/shTestRgcV1Corr.m`, `show/shShowRgcAndV1Comparison.m`,
    `show/shShowRgcAndMtComparison.m`, `show/shShowRgcV1ReceptiveFields.m`
    (including fixing its basis-column-label mapping to the class path's
    ascending spatial-order convention). **Behavior change:** the class
    path's `combine='weights'` has no default (unfitted) fallback -- unlike
    legacy `shModelV1LinearFromRgc`, which applied `shRgcV1Weights` to the
    first 4 channels when `v1Weights` was empty. fourPop mode now always
    requires a fit; `tests/testRgcVsLegacyCorr.m` and
    `help/shTestRgcV1Corr.m` were updated to expect an error instead of a
    silent fallback.
  - **Twin forwards retired.** `shModelV1LinearFromRgcDerivative` (already
    dead -- no dispatcher used it) is deleted; `explore/unifyDerivativeVsFourPop.m`
    updated to drop its cross-check (superseded by `testClassPathDerivative`'s
    exact err=0 guardrail). `help/shFitRgcV1Weights.m` is deleted (no callers
    remained after the tooling migration). `model/innerworkings/shModelV1LinearFromRgc.m`
    is **kept, but retired from the live dispatch** -- it is now only the
    independent reference oracle for `tests/testClassPathFourPop.m`'s exact-
    equivalence guardrail (analogous to how the legacy no-RGC path is kept as
    the oracle for the derivative preset). `model/innerworkings/shModelRgc.m`
    (raw fourPop channel builder) is unchanged and still used directly by a
    few `show/` scripts for channel visualization.
- **Increment 3d — REDEFINED by the §3.5 pivot; the original (measure intrinsic
  biological DS) is retired.** What was done instead (2026-07-12): established that
  the biological front-end is non-vacuous as a *lesion* parameterization
  (`explore/lesionDeltaTest.m`), that lags close the §2.4 TF gap
  (`explore/temporalTilingFromLags.m`), and built + validated the lagged biological
  preset `pars/shRgcClassesMidgetParasolLagged.m` (~0.985 legacy-V1 correlation,
  flat across TF; `explore/testLaggedBiologicalFidelity.m`). `runAllTests` 14/14.
- **Increment 4 — DONE (2026-07-16).** Added the clean "use my custom classes
  as-is" dispatch mode that item 2 (below) had flagged as missing —
  `shModelV1Linear.m` gets an explicit `'custom'` case alongside `'derivative'`/
  `'fourpop'`, so a pars that fully configures `classes`/`combine` itself is used
  without being rebuilt. This turned out to be more than a convenience: without
  it, the existing `pars.rgc.classesMode='custom'` convention (used by the lagged
  preset since increment 3d) did **not** prevent the rebuild — `pars.rgc.mode`
  defaults to `'derivative'` when unset, so `shModelV1Linear` was silently
  rebuilding the lagged preset's classes as plain derivative on every call,
  discarding the fitted `v1Weights` and any lesion edits with them. This had been
  running unnoticed through `testLaggedBiologicalFidelity.m`'s ~0.985 correlation
  number (unaffected — that test calls `shModelV1LinearFromClasses` directly,
  bypassing the dispatch) but silently corrupted every `shTuneGratingDirection`/
  `shTuneBarSpeed`/etc. call on the lagged preset (i.e. anything going through
  `shModel`/`shModelV1Linear`) — caught via item 4's visual-validation pass
  producing bit-identical "lagged" and "derivative" results. Fixed, and
  `pars.rgc.mode = 'custom'` added wherever the lagged preset is built
  (`explore/validateSHFigs9to14*.m`, `explore/quantitativeAnalysisFigs9to14.m`).
  Verified no regression to the `'derivative'`/`'fourpop'` paths.

**Next steps (post-pivot, do these next):**

1. **Pin down the frame rate** (the standing TODO below). It gates whether the
   lags (0–3 frames) and Kling/Chariker time constants map to physiological delays
   (a few ms vs tens of ms). Everything timing-related — lags, optic-neuritis
   conduction delays — needs this to be quantitative rather than in arbitrary
   frames. **Still open.**

2. **Wire the lagged preset through to MT and check speed tuning directly — DONE
   (2026-07-16).** The dispatch gap flagged below (no clean "use my custom classes
   as-is" path) was real and worse than suspected: without it, `shModelV1Linear`
   didn't just need help finding the custom classes, it silently *discarded* them,
   rebuilding `pars.rgc.classes` from `shRgcClassesDerivative(pars)` whenever
   `pars.rgc.mode` wasn't explicitly set — which every caller of the lagged preset
   had been hitting. Fixed by adding an explicit `'custom'` case to
   `shModelV1Linear`'s mode dispatch (use `pars.rgc.classes`/`combine` as-is, no
   rebuild) and setting `pars.rgc.mode = 'custom'` wherever the lagged preset is
   built. Verified: derivative-mode output unchanged; lagged now genuinely differs
   from derivative (Fig 9 direction-tuning curve correlation 0.995, consistent with
   but not identical to the ~0.985 legacy-V1 fidelity). MT speed tuning (Fig 10)
   confirmed via `explore/quantitativeAnalysisFigs9to14.m` — see item 4.

3. **Lesion studies (the primary deliverable):** use the lagged biological preset +
   `shApplyRgcImpairment` (per-class conduction delays + amplitude deficits) to
   model optic-neuritis, reporting within-subject V1/MT **deltas** (affected vs
   fellow eye). **Prerequisites substantially advanced (2026-07-16), full
   affected-vs-fellow-eye study still open.** Per-class targeting (e.g. delay only
   parasol classes, delay only ON classes) is now built and validated — not by
   extending `shApplyRgcImpairment` itself, but by editing
   `pars.rgc.classes(i).gain`/`.temporalKernel` directly before the forward pass
   (`explore/validateSHFigs9to14_lesions.m`'s `lesionAmplitudeParasol`/
   `lesionDelayONOnly`). Spatial heterogeneity (different visual-field locations
   getting different deficits, via `shApplyRgcImpairment`'s amplitude/delay maps)
   is also built and validated (`explore/validateSHFigs9to14_lesions_stochastic.m`,
   5 lesion types). Quantified in `explore/quantitativeAnalysisFigs9to14.m` — see
   item 4's conclusions. What's still open: an actual within-subject
   affected-vs-fellow-eye study design (this work used synthetic SH benchmark
   stimuli, not patient-eye-pair data).

4. **Visual validation against SH paper benchmarks (Simoncelli & Heeger 1998 Figs.
   9–14) — DONE (2026-07-16).** All four sub-steps below completed; see
   `explore/VALIDATION_SUMMARY.md` for the full writeup and
   `explore/_figs/` for all 114 figures + the quantitative analysis output
   (gitignored — regenerate via the scripts named below).

   a. **Reproduce Figs. 9–14 with legacy SH** — done,
      `explore/validateSHFigs9to14.m`, 18 figures in
      `explore/_figs/MTmodel_validation_figs/`.

   b. **Confirm derivative-preset equivalence** — done, same script; reproduces
      legacy exactly as expected.

   c. **Assess lagged biological-preset fidelity** — done, but this is where the
      item-2 dispatch bug was caught: the "lagged" panels were bit-identical to
      derivative (impossible for a nonlinear model), because
      `pars.rgc.classesMode='custom'` alone does **not** prevent the dispatch from
      rebuilding — `pars.rgc.mode` must also be set to `'custom'` (the note here
      that flagged this as a known gap undersold it; the workaround it assumed
      would suffice actually did nothing). Fixed per item 2; lagged now genuinely
      differs from derivative (0.995 curve correlation) across all three figure
      scripts.

   d. **Lesion effects (amplitude + latency)** — done, uniform + biological
      (`explore/validateSHFigs9to14_lesions.m`, 36 figures) and stochastic/spatial
      (`explore/validateSHFigs9to14_lesions_stochastic.m`, 60 figures), plus
      quantitative metrics across all 19 conditions
      (`explore/quantitativeAnalysisFigs9to14.m`: direction peak/DSI/FWHM, speed
      peak/preferred-speed, coherence peak/slope).

   **Key quantitative finding:** for **amplitude**-type lesions, uniform and
   stochastic (random/patchy/coupled) versions produce comparable disruption
   (~9–18% coherence-peak drop). For **delay**-type lesions they diverge sharply:
   a spatially *random* delay devastates coherence (−39% to −59%) and high-pass
   speed tuning (−55% to −64%), while a spatially *uniform* delay of the same
   average magnitude does almost nothing, and a spatially *correlated* (patchy)
   delay tracks the uniform case. **It's spatial heterogeneity in conduction
   delay — not delay magnitude itself — that disrupts motion/coherence pooling.**
   A biological parasol-only 70% amplitude knockout also produced a qualitatively
   distinct signature from a uniform amplitude lesion (raised peak response,
   broadened tuning, degraded DSI and coherence sensitivity together), rather than
   a simple scaled-down version of the uniform effect.

5. **Rectification non-vacuousness refinement (lower priority, theoretical
   validation).** The current `explore/testONOFFAsymmetryNonvacuousness.m`
   (2026-07-13) established that timing lesions (ON-only, OFF-only, uniform) are
   ~90% irreducible to SH amplitude rescaling, confirming timing ≠ amplitude.
   However, all three lesion types showed similar irreducibility (~89–96%), so the
   test doesn't isolate a rectification-specific signature. To test whether
   ON/OFF-asymmetric timing exploits the rectification nonlinearity in a way that
   uniform timing + amplitude cannot:
   
   - Build a richer SH comparison basis that includes both amplitude rescaling
     (current 4-column basis: one delta per temporal order) AND a uniform-delay
     delta (all RGC classes or all SH temporal orders delayed together by 1 frame
     — expressible in SH by delaying the stimulus input or equivalently
     circshifting all `v1TemporalFilters` columns).
   - Project the ON-only and OFF-only latency deltas onto this augmented basis.
   - If ON-only/OFF-only remain highly irreducible (high 1-R²) while the uniform
     lesion becomes mostly reproducible (low 1-R²), that isolates the rectification
     signature: asymmetric timing creates a V1 pattern that no combination of SH's
     linear operations (amplitude rescaling + uniform delay) can reproduce, because
     it acts through the ON/OFF separation + rectification that SH's linear basis
     lacks.
   
   **Why lower priority:** This is a theoretical validation question ("does the
   biological model offer mathematical expressiveness SH lacks?") rather than a
   step toward the optic-neuritis lesion deliverable. The current result already
   confirms timing is a distinct axis from amplitude, which suffices for practical
   lesion parameterization. Pursue this if/when there's interest in the deeper
   "is biology non-vacuous relative to SH?" question beyond the applied lesion
   model.

**(1) Prototype the ON/OFF DS mechanism — DONE (2026-07-10), now a side-quest.**
See §2.7 and `explore/prototypeOnOffDelayDS.m`. Kept for reference; per §3.5 the
biological-DS direction is off the critical path.

**Guardrails:**
- Keep the legacy (RGC-disabled) path as the oracle. The derivative preset must
  still reproduce it to ~1e-16 at `nScales = 1`. Run `tests/runAllTests.m`
  (currently 14/14).
- Convert relative timing to frames using the model's frame duration (TODO:
  confirm the intended frame rate — now the top next-step; needed to make lags and
  conduction delays physiological rather than arbitrary-frame).

## 5. Environment / workflow notes (READ if on a new machine)

- **MATLAB runs headless via the MATLAB MCP server** (`mcp__MATLAB__run_matlab_file`
  / `evaluate_matlab_code`). Figure windows are suppressed unless
  `DefaultFigureVisible` is `on`. On *this* (desktop) machine we fixed it with a
  `startup.m` in `userpath` (`/Users/jaw288/repos/Code`) that runs
  `set(0,'DefaultFigureVisible','on')`. **That startup.m is outside the repo and
  will not transfer.** On the laptop, either replicate it or run
  `set(0,'DefaultFigureVisible','on')` at the start of a session. Check with
  `feature('ShowFigureWindows')` (should be 1) and `get(0,'DefaultFigureVisible')`.
- The `explore/` scripts are self-locating (they `addpath(genpath(repoRoot))`
  from their own path) and show figures directly; they also export PNGs to
  `tempdir` for the record.
- Do **not** treat `explainV1RFs.m` (untracked) as authoritative — the user
  confirmed it is scratch/noodling, not how the code works.

## 6. Literature (in `literature/`)

- **Adelson & Bergen 1985** — motion energy; DS = sum of ≥2 separable filters;
  2 spatial × 2 temporal phases (Figs. 9–10).
- **Chariker, Shapley et al. 2021** (theory) / **2022** (params) — biological DS
  from ON/OFF temporal difference (~10 ms ON delay) + ON/OFF spatial offset.
- **Kling 2020** — human/macaque midget & parasol time courses (Fig. 4A: all
  mono/biphasic).
- **Simoncelli & Heeger 1998** — the base V1/MT model.
- De Valois 2000 (V1 spatial+temporal RFs), Priebe 2012, Freeman 2021 — further
  reference.
