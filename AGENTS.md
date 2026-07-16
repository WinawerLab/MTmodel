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

## Current status (2026-07-16) — summary; see the plan doc for detail

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
- **Next:** (1) pin down the frame rate (gates whether lags/delays are
  physiological); (2) optic-neuritis lesion studies proper — the per-class and
  spatial lesion machinery is now built and validated (above), but the
  within-subject affected-vs-fellow-eye study itself is still open; (3)
  rectification non-vacuousness refinement (lower priority). See plan doc §4 for
  detail.

## Running the model & tests

```matlab
addpath(genpath('PATHNAME-OF-MTmodel'));
pars = shPars;                         % RGC on, mode 'derivative' (exact)
[pop, ind] = shModel(stim, pars, 'v1Complex');
pars.rgc.enabled = 0;                  % legacy (no-RGC) oracle
run tests/runAllTests.m                % must stay green (currently 14/14)
```

## Conventions for agents

- Keep `tests/runAllTests.m` green; the derivative preset must keep reproducing
  legacy to ~1e-16 at `nScales = 1`.
- Exploratory / one-off scripts live in `explore/` (self-locating, deterministic).
- Set random seeds; prefer real on-screen figures (see the memory note about
  `DefaultFigureVisible` on headless MATLAB).
- Prioritize scientific comparability (healthy mode) before adding complexity.
- `explainV1RFs.m` at the repo root is scratch/noodling — not authoritative.
