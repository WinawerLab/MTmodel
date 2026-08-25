# MTmodel — Agent Guide (START HERE)

Last updated: 2026-08-19.

Entry point for any agent (or person) picking up work on this repo. Read it
first, then follow the reading order below.

## What this is

A MATLAB implementation of the Simoncelli–Heeger (SH) model of V1 and MT motion
responses, extended with a **retinal ganglion cell (RGC) front-end** so it can
simulate optic-neuritis impairments (amplitude and timing) while keeping
healthy-condition V1/MT responses close to the legacy model.

The driving question:

> Can an RGC-level lesion explain the optic-neuritis pattern of
> **(a) increased VEP latency** and **(b) reduced recognition of motion-defined
> form at low speeds**?

**Non-negotiable constraint:** with impairment disabled, the derivative preset
must reproduce legacy behaviour to machine precision. The legacy (RGC-disabled)
path is the oracle, and `tests/runAllTests.m` (14 tests) enforces it.

## Where to start (reading order)

1. **This file** — orientation and how to run things.
2. **[docs/MODEL_AND_LESIONS.md](docs/MODEL_AND_LESIONS.md)** — **the report.**
   The design logic, what each validation leg establishes, the lesion results,
   and a validity ledger saying which results still hold. Read before writing
   code or quoting a number.
3. **[docs/NOISE_AND_DEMYELINATION.md](docs/NOISE_AND_DEMYELINATION.md)** — the
   demyelination pathophysiology, how it maps onto the lesion parameters, where
   internal noise would enter, and the predictions. Mostly design; its §6 is
   measured.
4. **[docs/TODO.md](docs/TODO.md)** — the open work plan, ordered by bearing on
   the driving question.
5. **[docs/RGC_lagged_preset_summary.md](docs/RGC_lagged_preset_summary.md)** —
   plain-language description of the live biological preset, with figures and
   the physical-units derivation.
6. **literature/NOTES.md** — the papers and what each one constrains.
   **optic neuritis targets/NOTES.md** — the clinical figures to reproduce.
   **README** — base-toolbox usage (install, `tut/shTutorial1.m`).

`docs/_archive/` holds superseded documentation — retired designs and finished
work phases. See its README before relying on anything in there.

## Current architecture, in brief

- **One class-based path.** `pars.rgc.classes` lists RGC classes (spatial RF,
  temporal kernel, rectification, gain); `shModelV1LinearFromClasses` /
  `shClassV1Basis` project through them; `pars.rgc.combine` selects the read-out
  (`'steer'` = analytic SH steering, `'weights'` = fitted matrix). Presets
  populate that field — they are not code branches.
- **There are exactly two ways to run the model**, and `shPars` returns both
  fully assembled — never hand-build a front-end:

  | call | front-end | MT |
  |---|---|---|
  | `shPars` (or `shPars('derivative')`) | `shRgcClassesDerivative` — the SH basis, 4 classes; reproduces legacy exactly | single stream |
  | `shPars('lagged')` | `shRgcClassesMidgetParasolLagged` — ON/OFF × midget/parasol × lags 0–3 = 16 classes → 160 features | **both streams, by default** |

  Everything else is a *variation* on one of these two — a lesion, or a custom
  setting — not a third way to run the model. Start from a preset and edit it.
  `shRgcClassesFourPop` is **not** a third way to run the model: it is an
  internal regression oracle used only by `tests/`, and it is the only
  machine-precision check on the DoG + rectification machinery that the lagged
  preset depends on. Leave it alone.
- **MT is magnocellular by construction, and `shPars('lagged')` already sets
  this up.** MT pools a two-stream mixture,
  `popMT = (1-alpha)*streamA + alpha*delay(streamB, d)`, formed
  post-normalization in `shModelV1ComplexForMt`. Stream A is the parasol-masked
  read-out (the dominant fast magno drive); stream B is the mixed M+P read-out
  relayed via V2. `alpha = 0.10`, `d = 0`. This reproduces Maunsell et al.
  (1990); stream B alone is midget-dominated, which is backwards.
  `'v1Complex'` is untouched — only the MT stages see the mixture.
  - **Both streams read out of the SAME 160-feature basis.** They are two
    28×160 weight matrices, not two bases — the basis is not doubled. (It *is*
    computed twice per call, once per stream, so `'lagged'` costs about 2× the
    single-stream model.)
  - The switch is `pars.rgc.mtMix` (fields `weightsA`, `alpha`, `delay`).
    Clearing it gives the single-stream, midget-dominated model and reproduces
    pre-2026-08-14 results bit-exactly.
- **Lesions** go through `pars.rgc.impairmentAmplitudeMap` /
  `impairmentDelayMap` (spatially varying), or by editing
  `pars.rgc.classes(i).gain` / `.temporalKernel` (class-selective). Weights are
  never refitted after a lesion.
- **Units are pinned** (`pars/shModelUnits.m`): 1 px = 0.430 deg,
  1 frame = 26.9 ms (37.2 fps), 1 px/frame = 16 deg/s. Use it for every
  physical-unit conversion.

## Running the model & tests

```matlab
addpath(genpath('PATHNAME-OF-MTmodel'));

pars = shPars;                         % way 1: the SH derivative basis (exact)
pars = shPars('lagged');               % way 2: biological front-end, both MT streams

[pop, ind] = shModel(stim, pars, 'mtPattern');
run tests/runAllTests.m                % must stay green (14/14)
```

Both calls return a ready-to-use struct. Variations, all starting from a preset:

```matlab
pars = shPars; pars.rgc.enabled = 0;               % legacy (no-RGC) oracle
pars = shPars('lagged'); pars.rgc.mtMix.alpha = 0; % pure magno drive (stream A only)
pars = shPars('lagged'); pars.rgc = rmfield(pars.rgc, 'mtMix');  % single-stream (pre-2026-08-14)
```

## Traps that have already cost time

- **`pars.rgc.mode = 'custom'` is mandatory for custom classes.** `shPars`
  handles this for both presets, so this only bites if you assemble
  `pars.rgc.classes` by hand — don't. `shModelV1Linear` rebuilds
  `pars.rgc.classes` from the preset named by `pars.rgc.mode`, which defaults to
  `'derivative'`; without `'custom'`, your classes, fitted weights and lesion
  edits are silently discarded and you are computing the plain derivative
  preset. This mislabelled a whole round of results before it was caught. The
  tell: `'lagged'` and `'derivative'` outputs that are bit-identical, which is
  impossible for a nonlinear model.
- **Seed the RNG in anything using dot stimuli.** SH Figs 11–14 use random dot
  fields; unseeded, a lesion-vs-baseline difference is confounded with
  dot-sample noise (worth ~5 percentage points in practice). Use
  `explore/compareLesionsToBaseline.m` as the template.
- **Mask features, never subset neurons.** `shMtWts` uses `pinv` over the full
  direction tiling, so dropping V1 neurons wrecks MT tuning for geometric
  reasons unrelated to biology. Change *what drives* the 28, not *which* 28.
- **Don't quote ~0.985 as a fixed property of the lagged preset.** A different
  measurement puts the same population at 0.93–0.95, and the per-neuron minimum
  is 0.709. See the report §2.4.
- **Don't use frame-scrambling as a motion control** for the motion letter — it
  preserves relative direction.

## Conventions for agents

- Keep `tests/runAllTests.m` green; the derivative preset must keep reproducing
  legacy to ~1e-16 at `nScales = 1`.
- Exploratory / one-off scripts live in `explore/` (self-locating,
  deterministic, seeded). Retired ones go to `explore/_archive/`.
- Generated figures go to `explore/_figs/`, which is **gitignored** — treat it
  as regenerable, never as a record. Anything that has to survive belongs in a
  doc.
- Prefer real on-screen figures. On headless MATLAB set
  `set(0,'DefaultFigureVisible','on')` at the start of a session (this machine
  does it from a `startup.m` in `userpath`, which is outside the repo and does
  not transfer).
- Prioritize scientific comparability (healthy mode) before adding complexity.
- `explainV1RFs.m` at the repo root is scratch/noodling — not authoritative.
