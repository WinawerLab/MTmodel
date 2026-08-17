# MTmodel — Agent Guide (START HERE)

Last updated: 2026-07-16

This is the entry point for any agent (or person) picking up work on this repo.
Read it first, then follow the reading order below.

## What this is

A MATLAB implementation of the Simoncelli–Heeger (SH) model of V1 and MT motion
responses, being extended with a **retinal ganglion cell (RGC) front-end** so it
can simulate optic-neuritis impairments (amplitude and timing) while keeping
healthy-condition V1/MT responses close to the legacy model.

**Non-negotiable constraint:** with impairment disabled, outputs must remain near
legacy behavior. The legacy (RGC-disabled) path is the machine-precision oracle.

## Where to start (reading order)

1. **This file** — orientation, current status, how to run.
2. **[docs/RGC_V1_unification_plan.md](docs/RGC_V1_unification_plan.md)** — the
   **authoritative** current state, decisions, refactor progress, and next steps.
   Read this before writing code.
3. **[docs/RGC_V1_design_discussion.md](docs/RGC_V1_design_discussion.md)** — the
   rationale (why the design is what it is; the literature-grounded reasoning).
4. **README** — base-toolbox usage (install, `tut/shTutorial1.m`, references).
   **literature/** — the papers the design is grounded in.

## Current status (2026-08-14) — summary; see the plan doc for detail

- The RGC layer is enabled by default (`pars.rgc.enabled = 1`). Both legacy modes
  (`pars.rgc.mode = 'derivative'` and `'fourPop'`) are now **unified onto one
  class-based path** driven by `pars.rgc.classes`
  (`shModelV1LinearFromClasses` / `shClassV1Basis`); `mode` just selects which
  preset + combine strategy `shModelV1Linear`'s dispatch builds.
- **Increments 1–3c done:** the derivative preset (`shRgcClassesDerivative`)
  reproduces legacy exactly (err = 0 at `nScales = 1`); the biological
  midget/parasol preset (`shRgcClassesMidgetParasol`, ON/OFF quadrature + spatial
  offset) fits legacy V1 to ~0.70; a class-agnostic RF viewer (`shV1Rf` /
  `shShowV1Rf`) is in place; optic-neuritis impairment
  (`shApplyRgcImpairment`) is shared by both presets; and `'fourPop'` now
  routes through a class preset (`shRgcClassesFourPop`), reproducing the old
  fourPop feature basis exactly (err = 0, incl. lagged channels). The old
  twin forwards are gone: `shModelV1LinearFromRgcDerivative` and
  `help/shFitRgcV1Weights.m` are deleted; `shModelV1LinearFromRgc` is retired
  from the live dispatch and kept only as the fourPop regression oracle.
  `tests/runAllTests.m` is 14/14.
- **Scope pivot (2026-07-12, corrected 2026-07-13) — read
  `docs/RGC_V1_design_discussion.md` §14–16 and plan doc §3.5 before continuing.** The biological direction-selectivity direction
  (ON/OFF spatial offset + temporal quadrature) is **retired**: the offset distorts
  orientation and fights the SH steerable read-out, which already yields DS. The
  biological front-end's value is instead a **lesionable parameterization** for
  optic neuritis — a *physically-grounded lesion model*, not a mathematically
  richer lesion space than SH. (The earlier "conduction delay is a lesion axis SH
  cannot express" claim was corrected 2026-07-13 as oversold — see design-discussion
  §16; a genuine biological-vs-SH test via the ON/OFF rectification SH lacks is
  TODO.) The §2.4 high-TF gap is
  closed by **lags**: `pars/shRgcClassesMidgetParasolLagged.m` (biological, no
  offset/quadrature, lagged copies) reaches ~0.985 legacy-V1 correlation flat
  across TF (vs ~0.70 for the offset/quadrature `shRgcClassesMidgetParasol`).
- **Visual validation + quantitative lesion analysis — DONE (2026-07-16).**
  Simoncelli & Heeger 1998 Figs. 9–14 reproduced across legacy SH, derivative
  preset, and lagged biological preset, then assessed under uniform, biological,
  and spatially-stochastic lesions (114 figures total) plus a quantitative
  metrics pass across all 19 conditions. See `explore/VALIDATION_SUMMARY.md` and
  `explore/_figs/` (gitignored — regenerate via the scripts it names). Headline
  finding: spatially heterogeneous conduction delay is far more disruptive to
  coherence/speed tuning than a uniform delay of the same average magnitude,
  while amplitude-type lesions (uniform vs. stochastic) are comparable.
- **Bug found + fixed along the way:** `shModelV1Linear`'s mode dispatch defaulted
  to `'derivative'` whenever `pars.rgc.mode` was unset, silently rebuilding
  `pars.rgc.classes` from scratch whenever `classesMode` wasn't `'derivative'` —
  discarding the lagged preset's custom classes/weights (and any lesion edits)
  on every call. Every "lagged" condition in the Figs. 9–14 scripts had been
  silently computing the plain derivative preset. Fixed by adding an explicit
  `'custom'` case to the dispatch (`pars.rgc.mode = 'custom'` now required
  wherever the lagged preset is built) — see plan doc §4 Increment 4.
- **M/P now means something — DONE (2026-08-14), `docs/TODO.md` item 1.**
  Superseded the earlier status here, which said MT was midget-dominated and that
  constraining the fit was parked. It is no longer parked and no longer true.
  Grounded in Nassi & Callaway (2006, 2007): `shMtWts` is analytic in the
  direction geometry and carries no cell-type information, so MT's M/P dependence
  is set **entirely** by the RGC→V1 weight matrix — mask the *features*, never
  subset the neurons (the `pinv` needs the full direction tiling). MT now pools a
  two-stream mixture, `popMT = (1-alpha)*popA + alpha*delay(popB, d)`:
  - **popA** "4B→MT", the fast magno drive — `shFitClassV1Weights` with a
    `shClassFeatureMask(pars, '^parasol')`, so it is magnocellular by construction.
  - **popB** "→V2→MT", the slow minority drive — the **existing mixed fit**, since
    the V2 relay carries mixed M and P. No second fit needed.
  - Formed post-normalization in `shModelV1ComplexForMt`, so the streams don't
    share a normalization pool. `alpha = 0.10`, `d = 0` (the V2 detour is ~5–10 ms,
    well under one 26.9 ms frame; the lateness is already in the midget kernel).
  **Maunsell et al. (1990) is reproduced:** M block pronounced and near-universal
  (81% population median, 95% of units), P block little effect on the typical unit
  (2.7% median) but unequivocal for a minority (1 of 19), combined block
  essentially eliminates the response. The old model had this exactly backwards.
  `alpha >= 0.20` breaks it, so the criterion brackets alpha to 0.05–0.10.
  Scripts: `explore/fitMagnoMtPopulation.m`, `explore/knockoutAndAlphaCalibration.m`.
- **Motion-defined form stimulus merged and validated — DONE (2026-08-17),
  `docs/TODO.md` item 4.** The `Kristin` branch is merged: `stim/mkMotionLetter.m`
  (Regan-style motion-defined letter), the `playStimMovie*` helpers, and two
  explore scripts. Three defects in the merged code were fixed first — an
  opponent-unit selector that mixed radians with px/frame (and so returned the
  *static* MT unit as "right-tuned" at slow speeds), angular units converted
  through display geometry rather than the model's own scale, and a font check
  that could not detect MATLAB's silent font substitution (runs claimed Sloan
  while using a substitute; Sloan is now installed). New `pars/shModelUnits.m`
  pins the SH Appendix I scale: **1 px = 0.430 deg, 1 frame = 26.9 ms,
  1 px/frame = 16 deg/s**. Use it for any physical-unit conversion.
  **Result:** MT recovers the letterform (d' = 1.32 at 5 deg/s), V1 barely
  (d' = 0.23), and the two RGC presets are indistinguishable. Controls confirm
  it is motion-based: no static cue (d' ≈ 0), and a same-drift control with no
  relative motion collapses it to −0.34. Run `explore/runMotionLetterDemo.m`.
  Note MT opponent d' is **flat** from 1 to 48 deg/s — an earlier claim that it
  improved with speed was an artifact of the broken selector.
- **Next: see `docs/TODO.md`** — the remaining items, ordered by bearing on the
  driving question ("can an RGC lesion explain increased VEP latency + reduced
  motion-defined-form recognition at low speeds?"). VEP latency *is* approachable
  since the temporal kernels are causal — what's missing is cortical normalization
  **dynamics**, not latency per se. The low-speed tension (item 3) is now the key
  experiment: the heterogeneous-delay result crushes motion at **high** speeds
  while the clinical deficit is at **low** speeds — but the new architecture gives
  a candidate mechanism, since midget dependence concentrates sharply at low
  preferred speed (−45% at 0 px/frame vs −1.7% at 6 px/frame under midget
  knockout). That measurement used one fixed grating for all MT units, so it needs
  confirming with per-neuron speed tuning before it is banked.
- **Frame rate: RESOLVED** (2026-08-13). SH Appendix I p. 761 pins the units:
  1 pixel = 0.430 deg, 1 frame = 26.9 ms (37.2 fps), 1 pixel/frame = 16 deg/sec.
  Derivation in `docs/RGC_lagged_preset_summary.md` §7.1. Item (1) below is done.
- Still open from the older list: optic-neuritis within-subject
  affected-vs-fellow-eye study; rectification non-vacuousness refinement (lower
  priority). See plan doc §4 for detail.

## Running the model & tests

```matlab
addpath(genpath('PATHNAME-OF-MTmodel'));
pars = shPars;                         % RGC on, mode 'derivative' (exact)
[pop, ind] = shModel(stim, pars, 'v1Complex');
pars.rgc.enabled = 0;                  % legacy (no-RGC) oracle
run tests/runAllTests.m                % must stay green (currently 14/14)
```

Magnocellular MT (the two-stream mixture; see the M/P status bullet above). Only
the MT stages are affected — `'v1Complex'` is untouched, so the validated V1 stage
is unchanged. Omitting `mtMix` reproduces the previous behavior bit-exactly:

```matlab
WA = getfield(load('pars/shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat'), 'v1WeightsMagnoA');
pars.rgc.mtMix = struct('weightsA', WA, 'alpha', 0.10, 'delay', 0);
[pop, ind] = shModel(stim, pars, 'mtPattern');   % alpha = 0 gives the pure magno drive
```

## Conventions for agents

- Keep `tests/runAllTests.m` green; the derivative preset must keep reproducing
  legacy to ~1e-16 at `nScales = 1`.
- Exploratory / one-off scripts live in `explore/` (self-locating, deterministic).
- Set random seeds; prefer real on-screen figures (see the memory note about
  `DefaultFigureVisible` on headless MATLAB).
- Prioritize scientific comparability (healthy mode) before adding complexity.
- `explainV1RFs.m` at the repo root is scratch/noodling — not authoritative.
