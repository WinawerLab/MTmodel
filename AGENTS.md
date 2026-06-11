# MTmodel Agent Working Plan (RGC Front-End Project)

Last updated: 2026-06-11

## Primary Goal

Add a retinal ganglion cell (RGC) layer before V1 so the model can simulate optic neuritis impairments (amplitude and timing), while keeping healthy-condition V1 and MT responses as close as possible to the legacy model.

## Non-Negotiable Constraint

With impairment disabled, outputs should remain near legacy behavior.

## Current Implementation Status

Completed in first pass:


1. Optional RGC preprocessing hook is integrated before V1 computation.
2. RGC parameter schema exists in default parameter structure.
3. First-pass calibration script exists and runs in MATLAB.
4. README includes basic RGC/calibration usage notes.

Implemented files:

* model/innerworkings/shModelRgc.m
* model/shModel.m
* pars/shPars.m
* help/shCalibrateRgcLayer.m
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

1. Run the runbook:

* `runbook = shRunRgcPlan(120, [0.1 0.3 0.5], [1 2 3], '')`
* Confirm the healthy-vs-legacy V1 and MT correlations are still high.

2. Decide whether to lock in the calibrated healthy RGC defaults:

* If calibration looks good, copy `runbook.calibration.bestRgcPars` into `pars/shPars.m`.
* Keep `pars.rgc.enabled = 0` by default so legacy behavior remains unchanged.

3. Inspect the visualization helpers on a known stimulus:

* `shShowRgcAndV1Comparison`
* `shShowRgcAndMtComparison`
* Confirm the figures match the expected healthy-mode behavior.

4. Compare healthy vs impaired settings:

* Sweep `pars.rgc.impairmentEnabled`, `pars.rgc.impairmentAmplitudeMap`, and `pars.rgc.impairmentDelayMap`.
* Record the effect on V1 and MT summary metrics.

5. Only after those checks, add the next implementation increment:

* A deterministic regression script for baseline vs healthy RGC.
* A small impairment demo script (amplitude only, timing only, combined).

## RGC Extension Sketch

The current RGC layer is a conservative preprocessing block. The next
scientifically useful extension would be an explicit retinal population
with separate ON and OFF streams and more than one temporal profile.

1. Retinal split

* Compute ON and OFF channels separately from the stimulus.
* Use positive rectification for ON and negative rectification for OFF,
	or an equivalent sign-split formulation.
* Keep a shared spatial organization so the two channels can be compared
	and calibrated against one another.

2. Spatial receptive fields

* Use a center-surround DoG family rather than a single Gaussian blur.
* Allow center and surround strengths, widths, and relative delay/temporal
	constants to vary by channel.
* Preserve a healthy-mode calibration target that makes the combined ON/OFF
	output as close as possible to the current first-pass RGC behavior.

3. Temporal structure

* Add at least two temporal kernels, for example a fast and a slow profile.
* Let ON and OFF channels share or differ in temporal parameters depending on
	the desired level of biological detail.
* Keep these kernels separable from spatial filtering so calibration remains
	tractable.

4. Output to V1

* Feed the combined retinal output into the existing V1 pipeline as a movie.
* In healthy mode, fit retinal parameters so V1/MT population responses stay
	near the legacy model.
* In impaired mode, apply amplitude attenuation and timing shifts at the RGC
	stage before V1.

5. Calibration strategy

* First fit healthy parameters on the existing calibration movie set.
* Then freeze healthy defaults and introduce impairment parameters.
* Validate on the same regression set used for the first-pass RGC layer.

6. Practical implementation order

* Step 1: refactor shModelRgc into a small dispatcher that can handle
	multiple retinal channels.
* Step 2: add ON/OFF channel outputs with shared calibration logic.
* Step 3: add temporal variants and compare healthy-mode drift.
* Step 4: update visualization and runbook scripts to inspect each channel.

## MATLAB Commands


1. Calibration quick run:

* report = shCalibrateRgcLayer(60)


2. Healthy RGC enabled path:

* pars = shPars; pars.rgc.enabled = 1;


3. Example impairment setup:

* pars.rgc.impairmentEnabled = 1;
* pars.rgc.impairmentAmplitudeMap = ones(Y, X);  % edit map values
* pars.rgc.impairmentDelayMap = zeros(Y, X);     % integer frame delays

## Notes for Future Agents

* Do not change default behavior for users who do not enable RGC.
* Prioritize scientific comparability (healthy mode) before adding new complexity.
* Keep all new scripts deterministic where possible (set random seeds).


