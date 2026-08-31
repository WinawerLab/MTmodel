# pars/ — parameter presets and helpers

## Start here

| Question | File |
|----------|------|
| How do I run the model? | `shPars.m` — **only two presets**: `'derivative'` and `'lagged'` |
| Physical units (px/deg, ms/frame)? | `shModelUnits.m` |
| Motion-letter dot size, speed, letter, model preset? | **`motionLetterPars.m`** — edit the DEFAULTS block |
| Trial noise defaults (Step 1: off)? | **`noisePars.m`** |
| N-trial motion-letter loop? | `explore/motionLetterTrials.m` |
| Site-2 Phase A (run on a fast machine)? | `explore/runMotionLetterSite2PhaseA.m` |
| Lesion gains, delays, stochastic seeds/ranges? | **`lesionPars.m`** — edit the DEFAULTS block |
| Apply a named lesion? | `lesionApply(pars, 'amplitude_uniform')` |
| Lesion condition lists for scripts? | `lesionCatalog('motionLetterPhase2', ...)` |
| Model preset only (no stimulus)? | `motionLetterModelPars.m` |
| One RGC class definition? | `shRgcClass.m` |
| SH basis classes (4)? | `shRgcClassesDerivative.m` |
| Biological classes (16 lagged)? | `shRgcClassesMidgetParasolLagged.m` |
| Big matrices (V1 filters, MT tunings)? | `defaultParameters.mat` (loaded by `shPars`) |
| Fitted V1 weights (lagged)? | `shRgcClassesMidgetParasolLagged_v1Weights_*.mat` |

## shPars.m — the model preset

```matlab
pars = shPars;                  % or shPars('derivative') — exact legacy SH
pars = shPars('lagged');        % biological front-end + two-stream MT
```

Do **not** hand-assemble `pars.rgc.classes`. Start from a preset, then edit
lesion fields (`impairmentAmplitudeMap`, `classes(i).gain`, `mtMix.alpha`, …).

Authoritative documentation: `docs/MODEL_AND_LESIONS.md`, `AGENTS.md`.

## motionLetterPars.m — the motion-letter preset

All explore/classifier scripts that call `mkMotionLetter` should use:

```matlab
[cfg, pars, stimSz, stimArgs] = motionLetterPars();   % defaults
[stim, info] = mkMotionLetter(stimSz, cfg.letter, stimArgs{:});
```

Per-script overrides without touching defaults:

```matlab
[cfg, pars, stimSz, stimArgs] = motionLetterPars('letter', 'V', 'speedDegS', 1);
```

## lesionPars.m — lesion parameters

Class-level lesions (gain, kernel delay) and spatial maps (stochastic Phase 2b)
share one defaults file:

```matlab
cfg = lesionPars();   % inspect defaults
pars = lesionApply(parsBase, 'amplitude_parasol');
pars = lesionApply(parsBase, 'delay_random', 'fieldSize', 128);
pars = lesionCropToStim(pars, stimSz(1), stimSz(2));   % before shModel

lesions = lesionCatalog('motionLetterPhase2', 'fieldSize', fieldSize);
pars = lesions(i).applyFn(parsBase);
```

Uniform amplitude has two mechanisms:

- **`amplitude_uniform`** — scales `classes(i).gain` (Phase 2 explore scripts)
- **`amplitude_delay_uniform`** — gain 0.5 **and** +2-frame delay on every class
  (independent; not `coupled`). `explore/runUniformAmpDelayMtMix.m`
- **`amplitude_uniform_map`** — sets `impairmentAmplitudeMap` (`compensationIndex.m`)
- **`hf_lowpass`** — causal exponential on every `temporalKernel` (NOISE §3.1).
  `hfRenorm` true (default) keeps L1 so it is shape only. See
  `explore/runMotionLetterHfFailure.m`. Default `hfTauFrames` stays 2 (the
  first look). Override in the script for a stronger kernel
  (`explore/runMotionLetterHfFailureStronger.m`, τ = 8).
- **`hf_highcut`** — frequency-domain Butterworth, H(0)=1, no L1. fc = 0.05
  cyc/frame. `explore/runMotionLetterHfHighcut.m`. Not `hf_lowpass`.

## What is not in this folder

- **Stimulus generators** live in `stim/` (`mkMotionLetter`, `mkDots`, …).
- **Lesion explore scripts** live in `explore/`; they call into `pars/` but do
  not define shared defaults.
- **Archived designs** (`fourPop`, offset/quadrature) are in `explore/_archive/`.

## Reorganization note

The flat layout is intentional for now: `shPars` and `defaultParameters.mat`
must stay together (hard-coded path in `shPars.m`). A future split could use
subfolders for documentation only, e.g. `pars/rgc/` for class builders, without
moving `shPars.m` itself.
