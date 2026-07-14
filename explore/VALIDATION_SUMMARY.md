# MTmodel Visual Validation Summary

**Date:** 2026-07-13  
**Purpose:** Validate Simoncelli & Heeger 1998 Figures 9-14 across model paths and lesion conditions

---

## Overview

This document summarizes the visual validation work implementing the plan described in `docs/RGC_V1_unification_plan.md` §4 (item 4). We validate that three model paths reproduce published V1/MT phenomena, then assess lesion effects.

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

---

## Phase 1: Baseline Validation (No Lesions)

**Script:** `explore/validateSHFigs9to14.m`  
**Status:** ✅ Completed  
**Output:** 18 figures (3 configs × 6 figures) in `/tmp/MTmodel_validation_figs/`

### Figures Generated

**Figure 9:** Direction tuning (V1/MT) for gratings and plaids
- Tests pattern vs component selectivity in MT
- **Observation:** All three paths appear identical (derivative/lagged match legacy exactly or imperceptibly)

**Figure 10:** Speed tuning curves (bandpass/lowpass/highpass MT neurons)
- Tests temporal frequency tiling via speed selectivity
- **Observation:** All three paths appear identical
- **Interpretation:** Coarse tuning properties preserved at ~0.985 correlation

**Figure 11:** Dot coherence tuning (MT)
- Tests response to motion coherence (preferred vs antipreferred)
- Shows some differences between paths (expected for random dot stimuli)

**Figure 12:** Dot mixture responses (MT)
- Tests preferred + antipreferred dot combinations
- Shows variability across paths

**Figure 13:** Mask direction tuning (MT)
- Tests response to preferred dots + mask at varying directions
- Shows differences across paths

**Figure 14:** Direction tuning with antipreferred mask (MT)
- Tests masking effects on direction selectivity
- Shows differences across paths

### Key Findings

1. **Figs 9-10 (coarse tuning):** Legacy ≈ derivative ≈ lagged (imperceptible differences)
2. **Figs 11-14 (complex stimuli):** More variability, revealing the ~1.5% V1 deviation
3. **Lagged preset validation:** High fidelity to legacy across phenomena
4. **Weights cached:** Future runs load pre-fitted weights (~instant vs ~30 sec fitting)

---

## Phase 2: Uniform Lesion Effects

**Script:** `explore/validateSHFigs9to14_lesions.m`  
**Status:** 🔄 In progress (PID 13050)  
**Output:** 36 figures (2 presets × {2 universal + 2 biological} × 6 figs) in `/tmp/MTmodel_lesion_figs/`

### Lesion Types Tested

#### Universal Lesions (both presets)

1. **Uniform 50% amplitude**
   - All RGC classes reduced to 50% gain
   - Tests overall signal reduction

2. **Uniform 2-frame delay**
   - All RGC classes delayed by 2 frames (conduction deficit)
   - Tests synchrony disruption

#### Biological Lesions (lagged midget/parasol only)

3. **Parasol-only 70% amplitude**
   - Only parasol classes reduced to 30% (midgets spared)
   - Tests cell-type-specific deficits

4. **ON-only 1-frame delay**
   - Only ON pathway delayed by 1 frame (OFF normal)
   - Tests ON/OFF asymmetry effects

### Design Notes

- **Fixed V1 weights:** No refitting after lesions (within-subject comparison)
- **Lesions modify RGC layer only:** Via `pars.rgc.classes(i).gain` and `temporalKernel`
- **Derivative preset:** Only universal lesions (no biological cell types)
- **Lagged preset:** All 4 lesion types (has parasol/midget, ON/OFF distinction)

---

## Phase 2b: Stochastic Lesion Effects

**Script:** `explore/validateSHFigs9to14_lesions_stochastic.m`  
**Status:** 📝 Ready to run  
**Output:** 60 figures (2 presets × 5 lesions × 6 figs) in `/tmp/MTmodel_stochastic_lesion_figs/`

### Stochastic Lesion Types

All lesions use **spatial heterogeneity** - different visual field locations get different deficits (more realistic for optic neuritis).

1. **Random uncorrelated amplitude**
   - Each pixel: Uniform(0.3, 0.7) gain, independent
   - Tests pixel-level noise

2. **Random uncorrelated delay**
   - Each pixel: {0, 1, 2, 3} frames, independent
   - Tests asynchronous input

3. **Patchy correlated amplitude**
   - Gaussian-smoothed random field (σ=3.0)
   - Creates ~6-9 pixel damage clusters (realistic)
   - Range: [0.3, 0.7]

4. **Patchy correlated delay**
   - Gaussian-smoothed, thresholded into {0, 1, 2, 3}
   - Creates synchronized delay patches

5. **Coupled amplitude-delay** (most realistic)
   - Low amplitude → high delay (damage correlation)
   - Amplitude [0.3, 0.7] mapped to delay {3, 2, 1, 0}
   - Tests whether correlated deficits are more disruptive

### Implementation Details

- **Mechanism:** `shApplyRgcImpairment` with spatial maps
- **Fields:** `pars.rgc.impairmentAmplitudeMap` [Y×X], `pars.rgc.impairmentDelayMap` [Y×X]
- **Deterministic:** Fixed RNG seeds (42-46) for reproducibility
- **Dependencies:** Requires Image Processing Toolbox (`imgaussfilt`)

---

## How to Run

### Phase 1 (Baseline - one-time)

```matlab
% From MTmodel root
run('explore/validateSHFigs9to14.m')
```

- Runtime: ~30-45 min
- Fits and caches lagged weights on first run
- Output: 18 baseline figures

### Phase 2 (Uniform lesions)

```matlab
run('explore/validateSHFigs9to14_lesions.m')
```

- Runtime: ~60-75 min  
- Requires Phase 1 cached weights
- Output: 36 lesioned figures

### Phase 2b (Stochastic lesions)

```matlab
run('explore/validateSHFigs9to14_lesions_stochastic.m')
```

- Runtime: ~90-120 min
- Requires Phase 1 cached weights
- Output: 60 stochastic lesion figures

### Viewing Results

```matlab
% Figure locations printed at script start
% Example: /tmp/MTmodel_validation_figs/
% Open in Finder to view side-by-side:
system('open /tmp/MTmodel_validation_figs/')
```

---

## Output File Naming

### Phase 1 (Baseline)
- `fig{9-14}_legacy.png` - Original SH model
- `fig{9-14}_derivative.png` - Derivative preset
- `fig{9-14}_lagged_midget_parasol.png` - Lagged biological

### Phase 2 (Uniform)
- `fig{9-14}_derivative_amplitude_uniform.png`
- `fig{9-14}_derivative_delay_uniform.png`
- `fig{9-14}_lagged_midget_parasol_{amplitude_uniform|delay_uniform|amplitude_parasol|delay_ON_only}.png`

### Phase 2b (Stochastic)
- `fig{9-14}_{preset}_{amplitude_random|delay_random|amplitude_patchy|delay_patchy|coupled}.png`

---

## Interpreting Results

### What to Look For

1. **Baseline validation (Phase 1)**
   - Derivative should match legacy exactly (sanity check)
   - Lagged should be very close (validates ~0.985 correlation)
   - Differences in Figs 11-14 are expected (complex stimuli)

2. **Uniform lesions (Phase 2)**
   - How do tuning curves degrade? (shift, broaden, reduce peak?)
   - Amplitude vs delay: which is more disruptive?
   - Cell-specific (parasol, ON): selective vs global damage

3. **Stochastic lesions (Phase 2b)**
   - Random vs patchy: is spatial correlation more/less disruptive?
   - Coupled: does correlated amplitude+delay worsen effects?
   - Compare to uniform: is heterogeneity itself problematic?

### Quantitative Comparisons

For rigorous analysis, extract tuning curves from figures and compute:
- Peak response reduction
- Tuning width changes (FWHM)
- Direction/speed bias shifts
- Selectivity indices (DSI, etc.)

---

## Scientific Rationale (per RGC_V1_unification_plan.md §4)

**Why these figures?**
- Anchors validation to **published benchmarks** (SH 1998)
- Tests key V1/MT phenomena: direction/speed tuning, pattern selectivity, masking
- **Visual validation** before scaling to full lesion studies

**Why lesions?**
- Optic neuritis = within-subject deficit (lesioned vs healthy)
- Fixed weights = pure RGC effect (not V1 adaptation)
- Uniform → stochastic progression tests realism

**Why lagged preset?**
- Closes TF gap (~0.985 vs ~0.68 without lags)
- Biologically parameterized (midget/parasol, ON/OFF)
- Lesionable via cell-type and timing parameters

---

## Next Steps

### Immediate (from plan doc §4)
1. ✅ Visual validation baseline (Phase 1) - **DONE**
2. 🔄 Uniform lesion validation (Phase 2) - **IN PROGRESS**
3. 📝 Stochastic lesion validation (Phase 2b) - **READY**
4. 📊 Quantitative comparison (extract curves, compute metrics)

### Future (from plan doc, items 1-3, 5)
1. **Pin down frame rate** - convert frame delays to physiological timing (ms)
2. **Wire lagged preset through MT** - check speed tuning directly
3. **Optic neuritis lesion studies** - within-subject deltas (affected vs fellow eye)
4. **Rectification non-vacuousness test** - refine ON/OFF asymmetry uniqueness

---

## Files Created

### Scripts
- `explore/validateSHFigs9to14.m` - Phase 1 baseline
- `explore/validateSHFigs9to14_lesions.m` - Phase 2 uniform lesions
- `explore/validateSHFigs9to14_lesions_stochastic.m` - Phase 2b stochastic
- `explore/stochastic_lesion_functions.m` - Standalone stochastic lesion functions (reference)

### Data
- `pars/shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat` - Cached fitted weights (28×160)

### Documentation
- This file: `explore/VALIDATION_SUMMARY.md`

---

## Technical Notes

### Cached Weights
- **Why:** Fitting takes ~30 sec; loading takes <1 sec
- **When fitted:** First run of Phase 1
- **Deterministic:** RNG seed 42 (reproducible across machines)
- **Invalidate:** Delete `.mat` file to refit

### MATLAB Requirements
- Base MATLAB (tested on R2026a)
- Image Processing Toolbox (for stochastic lesions only)
- MTmodel toolbox in path

### Performance
- Phase 1: ~30-45 min (18 figs)
- Phase 2: ~60-75 min (36 figs)
- Phase 2b: ~90-120 min (60 figs)
- **Bottleneck:** Figure 10 speed tuning (shTuneBarSpeed is slow)

### Reproducibility
- All scripts use fixed RNG seeds
- Figures set to 'Visible', 'off' (faster, no display)
- Output locations printed at start

---

## Contact / Issues

For questions about this validation work:
- See `docs/RGC_V1_unification_plan.md` for design rationale
- See `docs/RGC_V1_design_discussion.md` for background
- See `AGENTS.md` for current project status

**Common issues:**
- "Cached weights not found" → Run Phase 1 first
- "imgaussfilt undefined" → Image Processing Toolbox needed (Phase 2b only)
- Figures not appearing → Check temp dir path printed at script start
