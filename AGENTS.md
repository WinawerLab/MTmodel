# MTmodel Agent Working Plan (RGC Front-End Project)

Last updated: 2026-07-02

## Primary Goal

Add a retinal ganglion cell (RGC) layer before V1 so the model can simulate optic neuritis impairments (amplitude and timing), while keeping healthy-condition V1 and MT responses as close as possible to the legacy model.

## Non-Negotiable Constraint

With impairment disabled, outputs should remain near legacy behavior.

## Status Update (2026-07-02)

`pars.rgc.enabled` now defaults to 1: `shPars` fits `pars.rgc.v1Weights`
automatically at init time (via `shFitRgcV1Weights` on a standard stimulus
set), so the default model path runs through the RGC layer rather than
legacy V1 directly. Scale factors are still derived from the legacy path
before weight fitting, and `pars.rgc.impairmentEnabled` still defaults to 0.
A `tests/` suite (`tests/runAllTests.m`, 8 regression tests) now covers pars
loading, stimulus generation, V1/MT pipelines, the RGC path, and RGC-vs-legacy
correlation -- this fulfills the "deterministic regression script" item from
Canonical Plan step 4. `min2`/`max2`/`mean2` (Image Processing Toolbox) calls
have been removed/replaced throughout, dropping that toolbox dependency.

## Current Implementation Status

Completed:

1. Optional RGC preprocessing hook integrated before V1 computation.
2. RGC parameter schema in shPars with full four-population defaults.
3. Four-population RGC layer: ON/OFF x fast/slow channel classes, each a
   full 2D neural image (same spatial layout as stimulus).
4. Optional lagged channels: fastLag and slowLag parameters add temporally
   phase-shifted copies of each base channel, giving up to 8 channel classes.
   Lagged channels introduce the temporal phase (quadrature) components needed
   to span V1's direction-selective temporal filter basis.
5. V1 spatial projection corrected: each RGC neural image is projected onto
   all 10 spatial derivative combinations (orders 0-3, matching shModelV1Linear
   loop structure and shSwts column order), not just the 4 third-order combos.
   This is the mechanism by which V1 neurons form orientation-selective
   receptive fields from spatially distributed RGC inputs.
6. Weight fitting (shFitRgcV1Weights) updated to handle 4- or 8-channel basis
   dynamically (nWeights inferred from feature matrix column count).
7. Parameter sweep tool (shSweepRgcTemporalPars) for grid search over RGC
   temporal parameters with per-combo weight refitting.
8. Calibration helper (shCalibrateRgcLayer) for healthy-mode parameter fitting.
9. Visualization helpers: shShowRgcAndV1Comparison, shShowRgcAndMtComparison,
   shShowRgcFourPopDemo -- all updated to use dynamic channel lists.

Implemented files:

* model/innerworkings/shModelRgc.m
* model/innerworkings/shModelV1LinearFromRgc.m
* model/shModel.m
* pars/shPars.m
* help/shCalibrateRgcLayer.m
* help/shFitRgcV1Weights.m
* help/shSweepRgcTemporalPars.m
* show/shShowRgcAndV1Comparison.m
* show/shShowRgcAndMtComparison.m
* show/shShowRgcFourPopDemo.m
* README

## Canonical Plan


1. Healthy-mode calibration lock

* Use baseline (RGC off) as reference.
* Fit healthy RGC defaults to maximize V1/MT similarity.
* Freeze defaults once fit quality is acceptable.


2. Validation metrics and acceptance criteria

* Population correlation (V1 and MT) over calibration stimulus set.
* Relative error / NRMSE on summary response vectors.
* Target: high correlation and low NRMSE compared to legacy baseline.


3. Impairment model expansion

* Amplitude impairment: multiplicative attenuation maps.
* Timing impairment: delay map and temporal filtering changes.
* Keep impairment off by default for backward compatibility.


4. Test and reproducibility hardening

* Add a deterministic regression script for baseline vs healthy RGC.
* Add a small impairment demonstration script (amplitude only, timing only, combined).

## Immediate Next Steps

Start here on the next session:

1. Re-run the parameter sweep with the corrected 10-combo spatial basis:

* `results = shSweepRgcTemporalPars;`
* Record the best V1 correlation (expected to exceed the previous ~0.80).
* If a clear optimum is found, write the best temporal parameters into shPars
  as the new defaults. RGC is now enabled by default (pars.rgc.enabled = 1),
  so any default-parameter change directly affects all users -- verify
  `tests/runAllTests.m` still passes and rerun `shShowRgcAndV1Comparison`
  before committing new defaults.

2. Validate the healthy-mode baseline:

* `report = shShowRgcAndV1Comparison;`
* Confirm V1 correlation and NRMSE are acceptable with best parameters.

3. Validate impairment model:

* Enable pars.rgc.impairmentEnabled = 1 with a known amplitude or delay map.
* Confirm impaired responses differ from healthy in the expected direction.
* Record V1/MT correlation and NRMSE under impairment.

## Current Architecture Summary

The RGC-to-V1 pipeline works as follows:

1. Stimulus (Y x X x T) enters shModelRgc.
2. shModelRgc produces 4-8 neural images (same Y x X x T layout):
   - onFast, offFast, onSlow, offSlow (always present)
   - onFastLag, offFastLag, onSlowLag, offSlowLag (present when fastLag/slowLag > 0)
   Each channel applies a spatial center-surround (DoG) filter plus a causal
   biphasic temporal kernel to the luminance input.  Lagged channels are
   frame-shifted copies that add temporal phase diversity.
3. shModelV1LinearFromRgc projects each neural image onto all 10 spatial
   derivative combinations (xorder+yorder from 0 to 3, in the same loop
   order as shModelV1Linear so columns align with shSwts).  This gives
   40 features (4 channels x 10) or 80 (8 channels x 10).
4. A per-neuron weight matrix (fitted by shFitRgcV1Weights) linearly combines
   those features to approximate the legacy V1 linear responses.

The spatial filtering step is the mechanism of V1 orientation/direction
selectivity: each V1 neuron performs a weighted sum over the spatial map of
RGC outputs, with the derivative filter weights determining its preferred
orientation and spatial frequency.

## Remaining Known Limitations

* The RGC spatial center-surround pre-filter shapes the frequency content
  reaching V1 in a way that has no analog in the legacy path.  This is an
  irreducible source of mismatch that parameter tuning cannot fully remove.
* The healthy-mode V1 correlation achievable with the current architecture
  should be re-measured after running shSweepRgcTemporalPars with the
  corrected 10-combo spatial basis (last measured ~0.80 with old 4-combo basis).
* Impairment model (amplitude/delay maps) has been implemented but not yet
  validated quantitatively against the legacy baseline.

## MATLAB Commands


1. Calibration quick run:

* report = shCalibrateRgcLayer(60)


2. Healthy RGC path (enabled by default):

* pars = shPars;   % pars.rgc.enabled == 1, v1Weights already fitted
* To use legacy V1 directly: pars.rgc.enabled = 0;


3. Example impairment setup:

* pars.rgc.impairmentEnabled = 1;
* pars.rgc.impairmentAmplitudeMap = ones(Y, X);  % edit map values
* pars.rgc.impairmentDelayMap = zeros(Y, X);     % integer frame delays

## Notes for Future Agents

* RGC is enabled by default (pars.rgc.enabled = 1); any change to default
  temporal/spatial parameters or v1Weights fitting affects all users, not
  just an opt-in path. Run `tests/runAllTests.m` before changing defaults.
* Prioritize scientific comparability (healthy mode) before adding new complexity.
* Keep all new scripts deterministic where possible (set random seeds).


