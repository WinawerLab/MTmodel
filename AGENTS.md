# MTmodel — start here

Last updated: 2026-08-28.

Read this first, then follow the reading list at the bottom.

## What this project is

MATLAB code for the Simoncelli–Heeger (SH) model of visual motion processing. You
give it a movie. It returns the firing rates of two populations of neurons:
direction-selective cells in visual area V1, and pattern-selective cells in area MT.

This copy adds one thing: a layer of retinal ganglion cells (RGCs) in front of V1.
That layer can be damaged in specific, stated ways. It exists so we can ask one
question:

> Can damage at the level of retinal ganglion cells explain the two things seen in
> optic neuritis — (a) a slower visual evoked potential, and (b) worse recognition
> of shapes defined only by motion, especially at slow speeds?

## If you are picking this up cold: internal noise and the lesion matrix, iteratively

The open work is **[docs/TODO.md](docs/TODO.md) §1–§3**, and those three are one
investigation rather than three tasks. How lesions affect the results and how noise
affects the results are the same question asked from two sides:

- **§1, internal noise.** The model is deterministic, which is the single biggest
  thing standing between it and the clinical question. Normalization absorbs most
  of an amplitude lesion, and three of the mechanisms by which demyelination
  degrades a signal cannot be written down at all without noise. Full plan in
  [docs/NOISE_AND_DEMYELINATION.md](docs/NOISE_AND_DEMYELINATION.md) §6.
- **§2, the lesion matrix through the two-stream MT.** Supplies the deterministic
  baseline that §1 has to be read against, and decides the standing low-speed
  tension.
- **§3, re-read the two against each other — repeatedly.** Not a closing step. What
  noise shows changes which lesion conditions are worth running; what the matrix
  shows changes which noise model and which observables are worth building.

**Start with §1 for convenience, not because it comes first.** Neither blocks the
other. As of 2026-08-28 the coherence × speed map, Site-2 **Phase A** (σ = 0.05,
N = 50), and **Phase B** (gaussian, σ_corr = 3 px, N = 20; ranking survived) are
done; see [`NOISE_TRIAL_DESIGN.md`](docs/NOISE_TRIAL_DESIGN.md) §3. **Next is
uniform vs patchy lesions with gaussian Site-2.** High-frequency failure and the
lesion matrix through mtMix are still open. Expect several passes rather than one
pass each, and treat neither half as finished until the pair stops changing each
other's reading.

**Five decisions have to be settled before any noise step**, listed in
`NOISE_AND_DEMYELINATION.md` §6 and locked in
[`NOISE_TRIAL_DESIGN.md`](docs/NOISE_TRIAL_DESIGN.md) §1 (except the VEP observable).
σ_corr = 3 px was used in Phase B and not swept. Every observable must be reported
alongside a measure of trial-to-trial variability, never as a mean alone.

Read the report before writing anything. Everything below is context for doing
that well.

## The rule that cannot be broken

With damage switched off, the new code must reproduce the original model **exactly,
to machine precision**. The original no-RGC path stays in the tree as the reference
answer. `tests/runAllTests.m` (12 tests) checks this. Keep it green.

## Running the model

```matlab
addpath(genpath('PATHNAME-OF-MTmodel'));

pars = shPars;                          % way 1: the SH derivative front-end
pars = shPars('lagged');                % way 2: the biological front-end

[pop, ind] = shModel(stim, pars, 'mtPattern');
run tests/runAllTests.m                 % must stay green (12/12)
```

**There are exactly two ways to run the model**, and `shPars` returns each one
ready to use. Never build a front-end by hand.

| call | front-end | MT |
|---|---|---|
| `shPars` or `shPars('derivative')` | `shRgcClassesDerivative` — the SH basis, 4 classes. Reproduces the original model exactly. | one stream |
| `shPars('lagged')` | `shRgcClassesMidgetParasolLagged` — ON/OFF × midget/parasol × lags 0–3 = 16 classes, 160 features | **two streams, by default** |

Everything else is a *variation* on one of these two — a lesion, or a changed
setting. Start from a preset and edit what it returns. There is no third preset,
and `shPars` refuses any other name.

```matlab
pars = shPars; pars.rgc.enabled = 0;                % the original no-RGC model
pars = shPars('lagged'); pars.rgc.mtMix.alpha = 0;  % magnocellular drive only
pars = shPars('lagged'); pars.rgc = rmfield(pars.rgc, 'mtMix');  % one stream
```

## How the model is put together, in brief

Full account in [docs/MODEL_AND_LESIONS.md](docs/MODEL_AND_LESIONS.md) §2.

- **One code path, several presets.** `pars.rgc.classes` is a list of cell classes.
  Each class has a spatial receptive field, a temporal filter, a rectification and
  a gain. `shModelV1LinearFromClasses` and `shClassV1Basis` push the stimulus
  through them. `pars.rgc.combine` says how V1 reads them out: `'steer'` for the
  analytic SH steering, `'weights'` for a fitted matrix. Presets fill in that list.
  They are not separate branches of code.
- **MT is driven mainly by the magnocellular pathway, and `shPars('lagged')` sets
  this up already.** MT pools a mixture of two streams,
  `popMT = (1-alpha)*streamA + alpha*delay(streamB, d)`, built after normalization
  in `shModelV1ComplexForMt`. Stream A is the parasol-only read-out (the fast
  magnocellular drive), stream B the mixed read-out that reaches MT by way of V2.
  `alpha = 0.10`, `d = 0`. Why it has to be there, and how alpha was set: §2.3 and
  §4.4 of the report.
  - The switch is `pars.rgc.mtMix`, with fields `weightsA`, `alpha`, `delay`.
    Clearing it gives the single-stream model.
  - Both streams read out of the same 160-feature basis, as two 28×160 weight
    matrices. The basis is computed once per stream, so `'lagged'` costs about
    twice a single-stream run.
  - `'v1Complex'` is untouched. Only the MT stages see the mixture.
- **Lesions** go through `pars.rgc.impairmentAmplitudeMap` and
  `impairmentDelayMap` (these vary across the visual field), or by editing
  `pars.rgc.classes(i).gain` and `.temporalKernel` (these pick out cell types).
  Weights are never refitted after a lesion.
- **Physical units are anchored** in `pars/shModelUnits.m`: 1 pixel = 0.1 deg,
  1 frame = 20 ms (50 frames/sec), 1 pixel/frame = 5 deg/sec. Use it for every
  conversion; never hard-code the constants. This anchor was set on 2026-08-27
  and **disagrees with Simoncelli & Heeger 1998 Appendix I**, which would give
  0.430 deg/pixel and 16 deg/sec. Nothing the model computes depends on it — it
  is a label for the sample grid — but every deg/s figure written before that
  date is 3.2x larger than the same figure is now. See
  `docs/RGC_lagged_preset_summary.md` §7.1.

## Traps that have already cost time

- **Set `pars.rgc.mode = 'custom'` if you build classes by hand.** `shPars` does
  this for both presets, so this only bites if you assemble `pars.rgc.classes`
  yourself — don't. `shModelV1Linear` rebuilds the class list from the preset named
  in `pars.rgc.mode`, which defaults to `'derivative'`. Without `'custom'`, your
  classes, fitted weights and lesion edits are thrown away in silence, and you are
  running the plain derivative preset. This mislabelled a whole round of results.
  The giveaway: `'lagged'` and `'derivative'` outputs that are identical bit for
  bit, which is impossible for a nonlinear model.
- **Seed the random number generator whenever you use dot stimuli.** SH Figs 11–14
  use random dot fields. Unseeded, the difference between a lesion and its baseline
  is mixed up with the difference between two dot samples, worth about 5 percentage
  points in practice. Copy `explore/compareLesionsToBaseline.m`.
- **Mask features, never drop neurons.** `shMtWts` uses `pinv` over the full set of
  directions, so removing V1 neurons wrecks MT tuning for reasons of geometry that
  have nothing to do with biology. Change *what drives* the 28 neurons, not *which*
  28 they are.
- **Do not quote the 0.984 pooled correlation as a fixed property of the lagged
  preset.** A separate measurement puts the same population at 0.93–0.95, and the
  worst single neuron is 0.709. See the report §4.2.
- **Do not use frame-scrambling as a motion control** for the motion letter. It
  leaves relative direction intact.

## Conventions for working here

- Keep `tests/runAllTests.m` green. The derivative preset must keep matching the
  original model to about 1e-16 at `nScales = 1`.
- One-off and exploratory scripts live in `explore/`. They locate themselves, run
  deterministically, and seed their random numbers. Retired ones move to
  `explore/_archive/`.
- Generated figures go to `explore/_figs/`. **PNG figures and `summary.txt` are
  tracked** so a push keeps the record. Full `results.mat` trial dumps stay
  gitignored (tens of MB; regenerate via the scripts).
- Prefer real on-screen figures. On headless MATLAB, start a session with
  `set(0,'DefaultFigureVisible','on')`. This machine does that from a `startup.m`
  in `userpath`, which sits outside the repo and does not travel with it.
- Get the healthy model comparable before adding complexity.

## What to read next

| file | what it is |
|---|---|
| [docs/MODEL_AND_LESIONS.md](docs/MODEL_AND_LESIONS.md) | **The main report.** How the model is built and why, everything that has been measured, and how far each result can be trusted. Read before writing code or quoting a number. |
| [docs/RGC_lagged_preset_summary.md](docs/RGC_lagged_preset_summary.md) | A closer look at the biological front-end, with figures. |
| [docs/NOISE_AND_DEMYELINATION.md](docs/NOISE_AND_DEMYELINATION.md) | Why the model needs internal noise, and what it should predict. |
| [docs/NOISE_TRIAL_DESIGN.md](docs/NOISE_TRIAL_DESIGN.md) | **Noise contract:** locked Step 0 choices, trial API, and the 2026-08-28 tables (coherence map, σ sweep, N=50 Phase A, Phase B). |
| [docs/TODO.md](docs/TODO.md) | Open work and done items with what they showed. §1–§3 are one iterative investigation. |
| [literature/NOTES.md](literature/NOTES.md) | The papers, and what each one constrains. |
| [optic neuritis targets/NOTES.md](optic%20neuritis%20targets/NOTES.md) | The clinical figures the model should eventually match. |
| [explore/README.md](explore/README.md) | Index of the exploratory scripts. |
| `README` | The original toolbox documentation: installing it, and `help/shTutorial1.m`. |

`docs/_archive/` holds documentation that has been superseded — retired designs and
finished phases of work. Read `docs/_archive/README.md` before relying on anything
in there.
