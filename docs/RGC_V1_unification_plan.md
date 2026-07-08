# RGC → V1 Unification: Design Notes & Handoff

Last updated: 2026-07-08 (session with J. Winawer)

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

| RGC classes | held-out test corr vs legacy | NRMSE |
|---|---|---|
| derivative (delta × SH temporal-derivative) | **0.99991** (1.0 modulo ridge λ) | 0.0015 |
| fourPop (DoG × biphasic) | 0.693 | 0.079 |

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

## 3. Decisions made this session

1. **Keep the SH analytic derivative basis** as the healthy-baseline path (it is
   exact and provides the SF/TF range MT needs for speed tuning).
2. **Unify** `derivative` and `fourPop` into one class-based implementation; they
   become *parameter presets*, not code branches (see §2.2).
3. **Adopt the ON/OFF delay as the temporal-phase source for DS** (Chariker/
   Shapley), rather than downstream lag-copy channels. Apply it for **two class
   types — midgets and parasols** — giving ON/OFF × midget/parasol with distinct
   midget vs parasol kernels and ON delayed ~10 ms within each type. This gives a
   little more spatiotemporal-tuning variety.
4. **The ON-vs-OFF spatial offset lives in the V1 read-out** and is *where DS is
   actually assembled* — design it explicitly, not as an accident of the
   derivative read-out.
5. **The MT/TF-range gap is separate from DS.** The high-TF (order 2–3) channels
   have no single-RGC counterpart and remain *synthesized* (keep SH basis for the
   healthy baseline; optionally build via multi-timescale + delays later).
6. If explicit ON/OFF spatial-offset wiring becomes cumbersome, fall back to a
   clean Adelson–Bergen skeleton (even/odd spatial × 2 temporal phases).

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

**(1) Prototype the ON/OFF-delay + spatial-offset read-out** on the parasol
(fast) and midget classes; measure **DS as a function of TF** and reproduce
Chariker's broadband-DS signature (Pref/Opp roughly constant across TF). Use
~10 ms ON delay. This validates route (b) before committing the schema.

**Guardrails:**
- Keep the legacy (RGC-disabled) path as the oracle. The derivative preset must
  still reproduce it to ~1e-16 at `nScales = 1`. Run `tests/runAllTests.m`.
- Convert relative timing to frames using the model's frame duration (TODO:
  confirm the intended frame rate — needed to place Chariker's 10 ms / Kling's
  time-to-peak on the model's frame axis).

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
