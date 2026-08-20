# `explore/`

One-off and exploratory scripts. Rough but self-contained: each adds the repo to
the path from its own location and shows figures directly. They are exploration,
not part of the model — nothing in `model/`, `pars/` or `tests/` depends on them.

Results and their validity are reported in
[`../docs/MODEL_AND_LESIONS.md`](../docs/MODEL_AND_LESIONS.md); the open work
plan is in [`../docs/TODO.md`](../docs/TODO.md).

**Conventions.** Seed the RNG (anything using dot stimuli is otherwise confounded
with dot-sample noise). Set `pars.rgc.mode = 'custom'` whenever you build custom
classes, or they are silently discarded. Figures go to `_figs/`, which is
**gitignored** — regenerable output, never a record.

## Current

| script | what it does |
|---|---|
| `runMotionLetterDemo.m` | the motion-defined-letter result: V1 vs MT opponent d′, plus the motion controls. The healthy baseline for lesioning. |
| `showMotionLetterModel.m` | builds the motion letter in model units and runs it through both RGC presets; `showMotionLetter.m` shows the stimulus alone. |
| `fitMagnoMtPopulation.m` | fits the parasol-masked V1 weight matrix (stream A) and caches it for `pars.rgc.mtMix`. |
| `knockoutAndAlphaCalibration.m` | the Maunsell (1990) knockout check and the `alpha` bisection. Produces the table in the report §2.5. |
| `measurePreferredTfSf.m` | measured preferred sf/tf for both V1 populations — why the parasol-masked fit loses the slow neurons. |
| `compensationIndex.m` | how much of a uniform RGC amplitude lesion divisive normalization absorbs, vs. stimulus speed. Measures the gain headroom that noise would act on. See `../docs/NOISE_AND_DEMYELINATION.md` §6. |
| `compareLesionsToBaseline.m` | lesion and baseline on shared axes, **seeded**, unambiguous gain labels. The template for any new lesion script. |
| `makeLaggedPresetDocFigures.m` | regenerates the figures in `docs/figures/` for the lagged-preset summary. |
| `temporalTilingFromLags.m` | shows that lagged biphasic kernels reconstruct SH's order 0–3 temporal basis — the justification for the lags. |
| `compareTemporalKernels.m` | SH derivative basis vs biological fast/slow kernels, in time and as amplitude spectra. |
| `demoDerivativePipeline.m` | end-to-end walkthrough of the derivative preset. |

## The SH Figs 9–14 campaign — runnable, but results are superseded

These generate the validation and lesion figures. They still run, but everything
they produced was measured through the **pre-`mtMix` MT** (single mixed weight
matrix), so the cell-type-specific results are not interpretable as biology and
the class-agnostic ones need re-measuring. See the report §5 for the ledger, and
note that the two `_lesions*` scripts do **not** seed the RNG.

| script | output |
|---|---|
| `validateSHFigs9to14.m` | baseline figures for legacy / derivative / lagged |
| `validateSHFigs9to14_lesions.m` | uniform and class-selective lesions |
| `validateSHFigs9to14_lesions_stochastic.m` | five spatially heterogeneous lesions (needs Image Processing Toolbox) |
| `quantitativeAnalysisFigs9to14.m` | metrics across all 19 conditions → CSVs |
| `stochastic_lesion_functions.m` | standalone reference implementations of the stochastic lesions |

## Open theoretical question

`testONOFFAsymmetryNonvacuousness.m` — whether ON/OFF-asymmetric timing exploits
the rectification SH lacks. Established that timing lesions are ~90% irreducible
to SH amplitude rescaling, but all three lesion types scored similarly, so it does
not yet isolate a rectification-specific signature. `unifyDerivativeVsFourPop.m`
demonstrates that `derivative` and `fourPop` are one projection with different
classes; the refactor it documents is finished, and `tests/testClassPath*.m` now
hold the guardrails.

## `_archive/`

Retired material: the offset+quadrature direction-selectivity preset and the
experiments that motivated retiring it, plus ad-hoc verification scripts now
superseded by `tests/`. See `_archive/README.md`.
