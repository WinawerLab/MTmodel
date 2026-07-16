# MTmodel Visual Validation Summary

**Date:** 2026-07-13 (started), completed and corrected 2026-07-16
**Purpose:** Validate Simoncelli & Heeger 1998 Figures 9-14 across model paths and lesion conditions, then quantify lesion effects.
**Status: All phases complete.** Phase 1/2/2b figures (114 total) generated and regenerated after a bug fix (see below); quantitative analysis complete.

---

## Overview

This document summarizes the visual + quantitative validation work implementing the plan described in `docs/RGC_V1_unification_plan.md` §4 (item 4). We validate that three model paths reproduce published V1/MT phenomena, then assess lesion effects, then quantify them.

### Three Model Paths Tested

1. **Legacy SH** (`pars.rgc.enabled = 0`)
   - Original Simoncelli-Heeger model with no RGC layer
   - The baseline oracle for comparison

2. **Derivative preset** (`pars.rgc.mode = 'derivative'`)
   - RGC layer enabled with analytic temporal-derivative basis
   - Should match legacy **exactly** (err = 0 at `nScales = 1`)
   - Uses classes: `order0`, `order1`, `order2`, `order3`
   - V1 weights: analytic via `shSwts` (no fitting)

3. **Lagged midget/parasol** (`shRgcClassesMidgetParasolLagged`)
   - Biological DoG spatial RFs + temporal kernels
   - ON/OFF × midget/parasol × lags [0,1,2,3] = 16 classes
   - **No offset/quadrature** (retired per 2026-07-12 scope pivot)
   - Lags close TF gap: ~0.985 legacy V1 correlation (vs ~0.68 without lags)
   - V1 weights: fitted via ridge regression, **cached** to disk
   - File: `pars/shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat`
   - Requires `pars.rgc.mode = 'custom'` (see bug note below) - without it, the lagged
     classes are silently discarded and the model computes the derivative preset instead.

---

## Critical bug found and fixed (2026-07-16)

While building the quantitative analysis (below), the "lagged" and "derivative" conditions
turned out to be **bit-identical to 14 significant digits** on every Fig 9/10 metric -
impossible for a nonlinear model unless the lagged classes never reached the computation.

**Root cause:** `model/innerworkings/shModelV1Linear.m` dispatches on `pars.rgc.mode`,
defaulting to `'derivative'` whenever that field is unset. The lagged preset's setup
function sets `pars.rgc.classesMode = 'custom'` and `pars.rgc.combine = 'weights'` but
never set `pars.rgc.mode` - so the dispatch fell into its `'derivative'` case, saw
`classesMode ~= 'derivative'`, and **rebuilt `pars.rgc.classes` from scratch** via
`shRgcClassesDerivative(pars)`, discarding the custom lagged classes, the fitted
`v1Weights`, and (in the lesion scripts) any per-class `gain`/`temporalKernel` lesion
edits already applied.

This means every "lagged" condition in all three figure scripts below - and the earlier
draft of the quantitative analysis - was **silently computing the plain derivative
preset**, mislabeled as lagged. The line below (from the original 2026-07-13 draft of
this doc) was describing that bug, not a real finding:

> ~~Figs 9-10: All three paths appear identical (derivative/lagged match legacy exactly
> or imperceptibly)~~ - **this was the bug**, not validation of high fidelity.

**Fix:** added an explicit `'custom'` case to the mode dispatch in `shModelV1Linear.m`
(commit `40c7dff`) so pars that fully configure `classes`/`combine` themselves are used
as-is, no rebuild; then added `pars.rgc.mode = 'custom'` to `setupLaggedBiological()` in
all three figure scripts + the quantitative analysis script (commit `f87b05d`), and
regenerated all figures.

**Post-fix sanity check:** derivative-mode output is unchanged (no regression); the
lagged preset now genuinely differs from derivative (Fig 9 direction-tuning curve
correlation 0.995 - consistent with, not identical to, the documented ~0.985 legacy-V1
fidelity). Spot-checked visually in `fig9_derivative.png` vs `fig9_lagged_midget_parasol.png`
(see locations below): baselines look close but not pixel-identical, and the
parasol-lesion panel shows a visibly larger MT response scale, matching the quantitative
+22% peak-response finding.

---

## Phase 1: Baseline Validation (No Lesions)

**Script:** `explore/validateSHFigs9to14.m`
**Status:** Complete (regenerated post-fix 2026-07-16)
**Output:** 18 figures (3 configs x 6 figures) in `explore/_figs/MTmodel_validation_figs/`

### Figures Generated

**Figure 9:** Direction tuning (V1/MT) for gratings and plaids - pattern vs component selectivity in MT.
**Figure 10:** Speed tuning curves (bandpass/lowpass/highpass MT neurons) - temporal frequency tiling via speed selectivity.
**Figure 11:** Dot coherence tuning (MT) - response to motion coherence (preferred vs antipreferred).
**Figure 12:** Dot mixture responses (MT) - preferred + antipreferred dot combinations.
**Figure 13:** Mask direction tuning (MT) - response to preferred dots + mask at varying directions.
**Figure 14:** Direction tuning with antipreferred mask (MT) - masking effects on direction selectivity.

### Key Findings (post-fix)

1. Derivative reproduces legacy exactly (by construction).
2. Lagged is close to but genuinely distinct from derivative/legacy (~0.985-0.995
   correlation on coarse tuning, more visible divergence on the complex Figs 11-14
   stimuli) - a real fidelity result now, not an artifact of the mode-dispatch bug.
3. Weights cached: future runs load pre-fitted weights (~instant vs ~30 sec fitting).

---

## Phase 2: Uniform Lesion Effects

**Script:** `explore/validateSHFigs9to14_lesions.m`
**Status:** Complete (regenerated post-fix 2026-07-16)
**Output:** 36 figures (2 presets x {2 universal + 2 biological} x 6 figs) in `explore/_figs/MTmodel_lesion_figs/`

### Lesion Types Tested

#### Universal Lesions (both presets)

1. **Uniform 50% amplitude** - all RGC classes reduced to 50% gain. Tests overall signal reduction.
2. **Uniform 2-frame delay** - all RGC classes delayed by 2 frames (conduction deficit). Tests synchrony disruption.

#### Biological Lesions (lagged midget/parasol only)

3. **Parasol-only 70% amplitude** - only parasol classes reduced to 30% (midgets spared). Tests cell-type-specific deficits.
4. **ON-only 1-frame delay** - only ON pathway delayed by 1 frame (OFF normal). Tests ON/OFF asymmetry effects.

### Design Notes

- Fixed V1 weights: no refitting after lesions (within-subject comparison).
- Lesions modify RGC layer only, via `pars.rgc.classes(i).gain` and `.temporalKernel`.
- Derivative preset: only universal lesions (no biological cell types).
- Lagged preset: all 4 lesion types (has parasol/midget, ON/OFF distinction).

---

## Phase 2b: Stochastic Lesion Effects

**Script:** `explore/validateSHFigs9to14_lesions_stochastic.m`
**Status:** Complete (run 2026-07-16, post-fix)
**Output:** 60 figures (2 presets x 5 lesions x 6 figs) in `explore/_figs/MTmodel_stochastic_lesion_figs/`

### Stochastic Lesion Types

All lesions use **spatial heterogeneity** - different visual field locations get different deficits (more realistic for optic neuritis).

1. **Random uncorrelated amplitude** - each pixel: Uniform(0.3, 0.7) gain, independent.
2. **Random uncorrelated delay** - each pixel: {0, 1, 2, 3} frames, independent.
3. **Patchy correlated amplitude** - Gaussian-smoothed random field (sigma=3.0), ~6-9 pixel damage clusters, range [0.3, 0.7].
4. **Patchy correlated delay** - Gaussian-smoothed, thresholded into {0, 1, 2, 3}, synchronized delay patches.
5. **Coupled amplitude-delay** (most realistic) - low amplitude -> high delay (damage correlation).

### Implementation Details

- Mechanism: `shApplyRgcImpairment` with spatial maps (`pars.rgc.impairmentAmplitudeMap`/`impairmentDelayMap`).
- Each Fig 9-14 panel builds a differently-sized stimulus (19x19 up to 51x51); a single
  FIELD_SIZE=51x51 physical damage field is defined once per lesion and center-cropped
  per call (`cropLesionForCall`) to match whatever size that panel's stimulus needs -
  so every panel is measuring the same physical lesion.
- Deterministic: fixed RNG seeds (42-46) for reproducibility.
- Dependencies: requires Image Processing Toolbox (`imgaussfilt`).

---

## Quantitative Analysis

**Script:** `explore/quantitativeAnalysisFigs9to14.m`
**Status:** Complete (2026-07-16)
**Output:** `explore/_figs/MTmodel_quantitative_analysis/`
- `all_conditions_metrics.csv` - raw metrics, one row per condition (19 total: 3 baseline + 6 uniform/biological + 10 stochastic)
- `pct_change_vs_baseline.csv` - % change (or octave shift for preferred-speed) vs. matched-preset baseline
- `uniform_vs_stochastic_comparison.csv` - amplitude-type and delay-type lesions side by side
- `lesion_comparison_bars.png` - grouped bar summary (direction peak, DSI, FWHM, coherence peak)

Metrics computed per condition (mtPattern stage): direction-tuning peak/DSI/FWHM (Fig 9),
speed-tuning peak + preferred speed for bandpass/lowpass/highpass MT cells (Fig 10),
coherence-tuning peak/slope (Fig 11). Runs in a few minutes (not the ~90-120 min the
Phase 2b figure-rendering script takes), since it extracts numbers directly from the
tuning functions instead of rendering 60 figures.

### Key Conclusions

- **Lagged vs. derivative baseline:** direction peak 1.033 vs 1.120 (curve correlation
  0.995), FWHM slightly broader (176 deg vs 164 deg), coherence peak lower (1.37 vs 1.53)
  - a real, modest fidelity gap, not the zero-gap the pre-fix bug implied.
- **Uniform delay** (2-frame, all classes): ~0% effect on direction/speed peak/DSI/FWHM
  for both presets - expected, since a uniform phase shift doesn't change the
  time-averaged response to a periodic drifting grating.
- **Uniform amplitude** (50% gain): cuts speed-tuning peaks substantially (-35% to -49%)
  and coherence peak (-9% to -18%), but barely touches direction peak/DSI/FWHM.
- **Parasol-only 70% knockout** (biological, lagged only) is qualitatively different from
  uniform amplitude: it *raises* direction peak (+22%) while broadening tuning (FWHM
  +7.4%), degrading DSI (-3.2%), and crashing coherence sensitivity (-52%) - consistent
  with losing the parasol pathway's fast, high-gain contribution shifting the population
  toward slower, broader, midget-dominated responses.
- **Uniform vs. stochastic, the core question:** for **amplitude**-type lesions, uniform
  and stochastic (random/patchy/coupled) land in a similar range (~9-18% coherence-peak
  drop). For **delay**-type lesions they diverge sharply: `delay_random` devastates
  coherence (-59% derivative, -39% lagged) and high-pass speed tuning (-64%/-55%), while
  `delay_uniform` does almost nothing, and `delay_patchy` (spatially correlated, not
  fully random) tracks close to uniform. **Conclusion: it's spatial heterogeneity /
  decorrelation in conduction delay - not delay magnitude itself - that disrupts
  motion/coherence pooling**, since desynchronized timing across space breaks the
  spatial pooling that coherence and speed tuning depend on.

---

## Figure & Data Locations

All generated output now lives under `explore/_figs/` (gitignored - regenerate via the
scripts below, don't expect it to be present after a fresh clone):

| Phase | Script | Location | Count |
|---|---|---|---|
| 1 (baseline) | `validateSHFigs9to14.m` | `explore/_figs/MTmodel_validation_figs/` | 18 |
| 2 (uniform/biological lesions) | `validateSHFigs9to14_lesions.m` | `explore/_figs/MTmodel_lesion_figs/` | 36 |
| 2b (stochastic lesions) | `validateSHFigs9to14_lesions_stochastic.m` | `explore/_figs/MTmodel_stochastic_lesion_figs/` | 60 |
| Quantitative analysis | `quantitativeAnalysisFigs9to14.m` | `explore/_figs/MTmodel_quantitative_analysis/` | 4 files (3 CSV + 1 PNG) |

**Total: 114 figures + 4 analysis files.**

The scripts themselves write to `tempdir` (`/tmp/MTmodel_*` on macOS/Linux) by default -
that's ephemeral. Copy to `explore/_figs/` (as done here) for anything you want to keep
past a reboot.

---

## How to Run

### Phase 1 (Baseline - one-time)

```matlab
run('explore/validateSHFigs9to14.m')
```
Fits and caches lagged weights on first run. Output: 18 baseline figures.

### Phase 2 (Uniform lesions)

```matlab
run('explore/validateSHFigs9to14_lesions.m')
```
Requires Phase 1 cached weights. Output: 36 lesioned figures.

### Phase 2b (Stochastic lesions)

```matlab
run('explore/validateSHFigs9to14_lesions_stochastic.m')
```
Requires Phase 1 cached weights and the Image Processing Toolbox. Output: 60 stochastic lesion figures.

### Quantitative analysis

```matlab
run('explore/quantitativeAnalysisFigs9to14.m')
```
Requires Phase 1 cached weights. Output: metrics CSVs + summary bar chart (a few minutes).

### Viewing Results

```matlab
system('open explore/_figs/MTmodel_validation_figs/')
```

---

## Output File Naming

### Phase 1 (Baseline)
- `fig{9-14}_legacy.png`, `fig{9-14}_derivative.png`, `fig{9-14}_lagged_midget_parasol.png`

### Phase 2 (Uniform/biological)
- `fig{9-14}_derivative_{amplitude_uniform|delay_uniform}.png`
- `fig{9-14}_lagged_midget_parasol_{amplitude_uniform|delay_uniform|amplitude_parasol|delay_ON_only}.png`

### Phase 2b (Stochastic)
- `fig{9-14}_{preset}_{amplitude_random|delay_random|amplitude_patchy|delay_patchy|coupled}.png`

---

## Scientific Rationale (per RGC_V1_unification_plan.md §4)

**Why these figures?** Anchors validation to published benchmarks (SH 1998); tests key
V1/MT phenomena (direction/speed tuning, pattern selectivity, masking) before scaling to
full lesion studies.

**Why lesions?** Optic neuritis is a within-subject deficit (lesioned vs healthy); fixed
weights isolate the pure RGC effect (not V1 adaptation); uniform -> stochastic
progression tests realism.

**Why lagged preset?** Closes the TF gap (~0.985 vs ~0.68 without lags); biologically
parameterized (midget/parasol, ON/OFF); lesionable via cell-type and timing parameters.

---

## Next Steps

### From plan doc (docs/RGC_V1_unification_plan.md §4, items 1-3, 5) - not yet addressed here
1. **Pin down frame rate** - convert frame delays to physiological timing (ms).
2. **Optic-neuritis lesion studies proper** - within-subject deltas (affected vs fellow eye), building on the lesion machinery validated here.
3. **Rectification non-vacuousness refinement** (lower priority).

Note: `AGENTS.md` and the plan doc's own status notes still describe this Figs 9-14
validation (item 4) as pending/in-progress as of their last update (2026-07-12) - they
haven't been synced to this completed status yet.

---

## Files

### Scripts
- `explore/validateSHFigs9to14.m` - Phase 1 baseline
- `explore/validateSHFigs9to14_lesions.m` - Phase 2 uniform/biological lesions
- `explore/validateSHFigs9to14_lesions_stochastic.m` - Phase 2b stochastic lesions
- `explore/quantitativeAnalysisFigs9to14.m` - quantitative metrics across all 19 conditions
- `explore/stochastic_lesion_functions.m` - standalone stochastic lesion functions (reference)

### Model fix
- `model/innerworkings/shModelV1Linear.m` - added `'custom'` mode-dispatch case (commit `40c7dff`)

### Data
- `pars/shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat` - cached fitted weights (28x160)

### Documentation
- This file: `explore/VALIDATION_SUMMARY.md`
- `explore/SESSION_PROGRESS_2026-07-13.md` - session log (see 2026-07-16 update at top)

---

## Technical Notes

### Cached Weights
- Fitting takes ~30 sec; loading takes <1 sec. Fitted on first Phase 1 run, RNG seed 42
  (reproducible). Delete the `.mat` file to refit.

### MATLAB Requirements
- Base MATLAB (tested on R2026a); Image Processing Toolbox (stochastic lesions only); MTmodel toolbox in path.

### Performance (observed 2026-07-16, faster than originally estimated)
- Phase 1: well under the originally-estimated 30-45 min.
- Phase 2: well under the originally-estimated 60-75 min.
- Phase 2b: well under the originally-estimated 90-120 min.
- Quantitative analysis: a few minutes for all 19 conditions.

### Reproducibility
- All scripts use fixed RNG seeds; figures set to `'Visible', 'off'` (faster, no display); output locations printed at start.

---

## Contact / Issues

- See `docs/RGC_V1_unification_plan.md` for design rationale.
- See `docs/RGC_V1_design_discussion.md` for background.
- See `AGENTS.md` for project status (not yet synced to this completed validation - see Next Steps above).

**Common issues:**
- "Cached weights not found" -> run Phase 1 first.
- "imgaussfilt undefined" -> Image Processing Toolbox needed (Phase 2b only).
- "Lagged" condition looks identical to "derivative" -> check `pars.rgc.mode = 'custom'`
  is set (see bug note above); without it, the lagged classes are silently discarded.
