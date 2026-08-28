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
discarded in silence. Figures go to `_figs/`, which is **gitignored**: regenerable
output, never a record.

## Current scripts

| script | what it does |
|---|---|
| `runMotionLetterDemo.m` | the motion-defined-letter result: V1 against MT opponent d′, plus the motion controls. The healthy baseline for lesioning. |
| `showMotionLetterModel.m` | builds the motion letter in model units and runs it through both presets. `showMotionLetter.m` shows the stimulus alone. |
| `fitMagnoMtPopulation.m` | fits the parasol-only V1 weight matrix (stream A) and caches it for `pars.rgc.mtMix`. |
| `knockoutAndAlphaCalibration.m` | the Maunsell (1990) knockout check and the `alpha` bisection. Produces the table in the report §4.4. |
| `measurePreferredTfSf.m` | measured preferred spatial and temporal frequency for both V1 populations — why the parasol-only fit loses the slow neurons. |
| `measureMtSpeedTuning.m` | MT speed tuning for both presets. Found that the nominal 6 px/frame tier actually peaks near 3.1 (derivative) or 3.7 (lagged), while the 1 px/frame tier lands correctly. Report §4.3. |
| `compensationIndex.m` | how much of a uniform amplitude lesion divisive normalization absorbs, over stimulus speed **x dot coherence**. Re-expresses the deficit against unlesioned drive rather than speed, which is the discriminating test for the operating-point account (`../docs/NOISE_AND_DEMYELINATION.md` §5.5, `../docs/TODO.md` §1 step 1). Report §4.8 holds the speed-only results. The coherence axis has **not been run in MATLAB yet**. |
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
