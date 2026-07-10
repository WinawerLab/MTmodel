# MTmodel — Agent Guide (START HERE)

Last updated: 2026-07-10

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

## Current status (2026-07-10) — summary; see the plan doc for detail

- The RGC layer is enabled by default (`pars.rgc.enabled = 1`). Two legacy modes
  exist (`pars.rgc.mode = 'derivative'` and `'fourPop'`); they are being **unified
  into one class-based path** driven by `pars.rgc.classes`
  (`shModelV1LinearFromClasses` / `shClassV1Basis`).
- **Increments 1–2 done:** the derivative preset (`shRgcClassesDerivative`)
  reproduces legacy exactly (err = 0 at `nScales = 1`); the biological
  midget/parasol preset (`shRgcClassesMidgetParasol`, ON/OFF quadrature + spatial
  offset) fits legacy V1 to ~0.70, on par with the old fourPop.
- **Next: Increment 3** — switch `shModelV1Linear`'s dispatch to the class path,
  make the `pars.rgc.mode` presets populate `pars.rgc.classes`, retire the twin
  forwards, generalize the RF viewer, and measure the front-end's *intrinsic* DS.
  (See the plan doc.)

## Running the model & tests

```matlab
addpath(genpath('PATHNAME-OF-MTmodel'));
pars = shPars;                         % RGC on, mode 'derivative' (exact)
[pop, ind] = shModel(stim, pars, 'v1Complex');
pars.rgc.enabled = 0;                  % legacy (no-RGC) oracle
run tests/runAllTests.m                % must stay green (currently 11/11)
```

## Conventions for agents

- Keep `tests/runAllTests.m` green; the derivative preset must keep reproducing
  legacy to ~1e-16 at `nScales = 1`.
- Exploratory / one-off scripts live in `explore/` (self-locating, deterministic).
- Set random seeds; prefer real on-screen figures (see the memory note about
  `DefaultFigureVisible` on headless MATLAB).
- Prioritize scientific comparability (healthy mode) before adding complexity.
- `explainV1RFs.m` at the repo root is scratch/noodling — not authoritative.
