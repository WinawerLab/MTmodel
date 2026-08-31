# `explore/`

One-off and exploratory scripts. Rough, but self-contained: each one adds the repo
to the MATLAB path from its own location and shows its figures directly. They are
exploration, not part of the model. Nothing in `model/`, `pars/` or `tests/`
depends on them.

Results, and how far each one can be trusted, are in
[`../docs/MODEL_AND_LESIONS.md`](../docs/MODEL_AND_LESIONS.md). Open work is in
[`../docs/TODO.md`](../docs/TODO.md).

**Three conventions.** Seed the random number generator — anything using dot
stimuli is otherwise confounded with dot-sample noise. Set
`pars.rgc.mode = 'custom'` whenever you build classes by hand, or they are
discarded in silence. Figures go to `_figs/`. PNG figures and `summary.txt` are
tracked; `results.mat` trial dumps are gitignored.

## Current scripts

| script | what it does |
|---|---|
| `runMotionLetterDemo.m` | the motion-defined-letter result: V1 against MT opponent d′, plus the motion controls. The healthy baseline for lesioning. |
| `showMotionLetterModel.m` | builds the motion letter in model units and runs it through both presets. `showMotionLetter.m` shows the stimulus alone. |
| `fitMagnoMtPopulation.m` | fits the parasol-only V1 weight matrix (stream A) and caches it for `pars.rgc.mtMix`. |
| `knockoutAndAlphaCalibration.m` | the Maunsell (1990) knockout check and the `alpha` bisection. Produces the table in the report §4.4. |
| `measurePreferredTfSf.m` | measured preferred spatial and temporal frequency for both V1 populations — why the parasol-only fit loses the slow neurons. |
| `measureMtSpeedTuning.m` | MT speed tuning for both presets. Found that the nominal 6 px/frame tier actually peaks near 3.1 (derivative) or 3.7 (lagged), while the 1 px/frame tier lands correctly. Report §4.3. |
| `runMotionLetterTrialsDemo.m` | Step 1 smoke test: small field, noise off, `std(d′)≈0`. |
| `runMotionLetterDeterministicBaseline.m` | **Two** full-field MT forwards (healthy + 50% amplitude lesion), same movie. Run this before Site-2 noise. |
| `runMotionLetterSite2PhaseA.m` | Locked Phase A: σ = 0.05, N = 50. Writes `explore/_figs/site2_phaseA_sigma005_n50/`. First look (σ = 0.03, N = 20) is in `site2_phaseA/`. |
| `runMotionLetterSite2PhaseB.m` | Phase B done 2026-08-28: independent vs gaussian at σ = 0.05, σ_corr = 3 px, N = 20. Ranking survived. Writes `explore/_figs/site2_phaseB_sigma005/`. |
| `runMotionLetterSite2UniformVsPatchy.m` | Done 2026-08-29: uniform vs patchy with gaussian Site-2. **No diverge.** Writes `explore/_figs/site2_uniformVsPatchy_sigma005/`. |
| `runMotionLetterMtSite2UniformVsPatchy.m` | Done 2026-08-29: MT Site-2 only (V1 off), same maps. **No diverge.** Same σ barely moved d′. Writes `explore/_figs/mtSite2_uniformVsPatchy_sigma005/`. |
| `runMotionLetterHfFailure.m` | HF first look 2026-08-29: τ = 2 raised d′. Writes `explore/_figs/hf_failure/`. Do not re-run. |
| `runMotionLetterHfFailureStronger.m` | Done 2026-08-31: τ = 8 still raised d′ (**STILL_HELPS YES**, HIT_MT NO). Writes `explore/_figs/hf_failure_tau8/`. Do not re-run. |
| `runMotionLetterHfHighcut.m` | Done 2026-08-31: +0.44 at 1 deg/s, −0.29 at 5. **HIGH_SPEED YES** (real cost). Writes `explore/_figs/hf_highcut/`. Do not re-run. |
| `runDelayRandomLowpassMtMix.m` | Done 2026-08-29: `delay_random` through mtMix. High-pass −77%, **low-pass spared**, letter d′ rose at 1 deg/s. Writes `explore/_figs/delayRandom_lowpass_mtMix/`. |
| `runMidgetSpeedTuningMtMix.m` | Done 2026-08-29: unconfound §4.5. **GRADIENT YES** (−61% vs −1%). Letter −0.21 d′ at 1 deg/s. Writes `explore/_figs/midget_speed_mtMix/`. |
| `runMotionLetterMidgetKoSite2.m` | Done 2026-08-29: midget KO + V1 Site-2. **NOISE_AMPLIFIES NO** (gap 0.21 off/on). Writes `explore/_figs/midgetKo_site2_sigma005/`. |
| `runUniformAmpDelayMtMix.m` | Done 2026-08-31: independent uniform gain 0.5 **and** +2-frame delay (not `coupled`). **BOTH_IS_AMP YES.** Writes `explore/_figs/uniformAmpDelay_mtMix/`. |
| `runMotionLetterSite2SigmaSweep.m` | Choose Site-2 σ (V1 only). Writes `explore/_figs/site2_sigmaSweep/`. |
| `compensationIndex.m` | how much of a uniform amplitude lesion divisive normalization absorbs, against stimulus speed **and coherence**. Measures the gain headroom that noise would act on. Report §4.8. |
| `compareLesionsToBaseline.m` | lesion and baseline on shared axes, **seeded**, with unambiguous gain labels. The template for any new lesion script. |
| `makeLaggedPresetDocFigures.m` | regenerates the figures in `docs/figures/` for the front-end summary. |
| `temporalTilingFromLags.m` | shows that lagged biphasic filters reconstruct SH's order 0–3 temporal basis — the justification for the lags. |
| `compareTemporalKernels.m` | the SH derivative basis against the biological fast and slow filters, in time and as amplitude spectra. |
| `demoDerivativePipeline.m` | end-to-end walkthrough of the derivative preset. |
| `testONOFFAsymmetryNonvacuousness.m` | the open question of whether ON/OFF-asymmetric timing exploits the rectification SH lacks. Established that timing lesions are about 90% irreducible to an SH amplitude rescaling, but all three lesion types scored similarly, so it does not yet isolate a signature specific to rectification. See `../docs/TODO.md` §5. |

## The SH Figs 9–14 campaign — still runs, but the results are superseded

These generate the validation and lesion figures. They still run. But everything
they produced was measured through the **pre-`mtMix` MT**, which used a single
mixed weight matrix, so the cell-type-specific results cannot be read as biology
and the class-agnostic ones need re-measuring. See the report §5 for the ledger.
Note that the two `_lesions` scripts do **not** seed the random number generator.

| script | output |
|---|---|
| `validateSHFigs9to14.m` | baseline figures for the legacy, derivative and lagged paths |
| `validateSHFigs9to14_lesions.m` | uniform and class-selective lesions |
| `validateSHFigs9to14_lesions_stochastic.m` | five spatially patchy lesions (needs the Image Processing Toolbox) |
| `quantitativeAnalysisFigs9to14.m` | metrics across all 19 conditions, written to CSVs |
| `stochastic_lesion_functions.m` | standalone reference implementations of the patchy lesions |

## `_archive/`

Retired material: the offset-plus-quadrature direction-selectivity preset, the
experiments that motivated retiring it, and ad-hoc checks now superseded by
`tests/`. See `_archive/README.md`.
