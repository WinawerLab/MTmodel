# Archive: lesion, impairment and noise work

Moved here on 2026-10-23 to reset the live repo to the healthy
retina -> V1 -> MT pathway. **Nothing was deleted.** Every file sits at the
same relative path it had in the repo root (for example
`explore/compensationIndex.m` was `MTmodel/explore/compensationIndex.m`).

The last git commit before the move was `e152dca` (2026-08-31, "noise and
lesions"). `git checkout e152dca` gives the exact pre-move state.

## What is here

| folder | contents |
|---|---|
| `classifier/` | motion-letter classifier (healthy vs `amp_parasol` vs `samedrift`), pilot + full runs. `_cache/` (~80 MB, gitignored) and `_figs/`. |
| `explore/` | every lesion / noise / trial-loop script: Site-2 phases A/B, sigma sweep, uniform vs patchy, HF failure (tau 2, tau 8, high-cut), delay_random, midget KO, uniform amp+delay, compensation index, deterministic baseline, Figs 9-14 lesion variants and quantitative analysis, ON/OFF asymmetry test, `stochastic_lesion_functions.m`. |
| `explore/_figs/` | results (`results.mat`, `summary.txt`, PNGs) for each of the runs above. |
| `explore/_archive/lesionDeltaTest.m` | older lesion delta check (was already archived). |
| `pars/` | `lesionApply`, `lesionCatalog`, `lesionCropForCall`, `lesionCropToStim`, `lesionPars`, `noisePars`. |
| `tests/testImpairment.m` | test of the RGC impairment hook (removed from `tests/runAllTests.m`, commented out). |
| `docs/` | `NOISE_AND_DEMYELINATION.md`, `NOISE_TRIAL_DESIGN.md`, `TODO.md` (the lesion/noise work plan), and the two PDFs on lesion and noise implementations. |

## What was deliberately left in the live repo

These are built into the core model. They are **off by default** and do
nothing unless switched on, so the healthy model is unchanged. Moving them
would have broken the model.

- `model/innerworkings/shApplyRgcImpairment.m` - called by `shClassV1Basis.m`; no-op unless `pars.rgc.impairmentEnabled = 1`.
- `model/innerworkings/shApplySite2Noise.m` - called by `shModelV1Normalization_Tuned.m` and `shModelMtNormalization_Tuned.m`; no-op unless `pars.noise.*.enabled`.
- `model/innerworkings/shSite2LastND.m` - noise instrumentation; only runs when noise is on.
- `pars/shPars.m` fields `pars.rgc.impairmentEnabled = 0`, `impairmentAmplitudeMap`, `impairmentDelayMap`.
- `docs/MODEL_AND_LESIONS.md` - the main report; it documents the healthy model as well as the lesions, so it stayed.

## To use the archived code again

Most scripts add the repo to the MATLAB path from their own location, which
assumed they lived in `explore/`. The simplest way to rerun one is to move it
(and anything it calls from `pars/`) back to its original folder.
