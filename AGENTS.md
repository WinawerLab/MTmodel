# MTmodel Agent Working Plan (RGC Front-End Project)

Last updated: 2026-07-02

> **2026-07-10 — NEW DIRECTION (read first):** see
> [`docs/RGC_V1_unification_plan.md`](docs/RGC_V1_unification_plan.md). We decided
> to **unify** `derivative` and `fourPop` into one class-based implementation
> (they are the same machinery with different RGC-class parameters — validated),
> and to build direction selectivity from an **ON/OFF temporal delay** (~10 ms,
> Chariker/Shapley) for midget and parasol classes rather than downstream lag
> copies. Validated exploratory scripts are in [`explore/`](explore/). The
> sections below still describe the *current* code accurately.

## Primary Goal

Add a retinal ganglion cell (RGC) layer before V1 so the model can simulate optic neuritis impairments (amplitude and timing), while keeping healthy-condition V1 and MT responses as close as possible to the legacy model.

## Non-Negotiable Constraint

With impairment disabled, outputs should remain near legacy behavior.

## Two-Stage RGC Strategy

The RGC front-end now has two selectable modes, `pars.rgc.mode`:

1. **`'derivative'` (default)** -- a non-biological but computationally exact
   layer: 4 channels, one per temporal-derivative order (0-3) of the same
   kernel family `v1TemporalFilters` already uses, each with a single-pixel
   (delta) spatial RF. Combined with the existing V1 spatial-derivative basis,
   this reconstructs legacy V1/MT responses essentially exactly (see
   "Derivative Mode Architecture" below) -- no weight fitting is needed. Its
   purpose is to give a clean, principled 4-channel substrate for lesion
   studies (see `pars.rgc.derivative.channelGain`).
2. **`'fourPop'`** -- the original biological ON/OFF x fast/slow population
   model with DoG spatial RFs and causal biphasic temporal kernels, combined
   via a numerically fitted weight matrix (`shFitRgcV1Weights`). This is the
   path to extend with more realistic midget/parasol RGC properties.

## Derivative Mode Architecture (default, `pars.rgc.mode = 'derivative'`)

1. `shModelRgcDerivative` causally filters the raw stimulus in time with each
   of the 4 columns of `pars.v1TemporalFilters` (orders 0-3), using the same
   `convn(..., 'full')`-then-truncate approach as the causal kernel in
   `shModelRgcPopulation.m`. No spatial filtering happens at this stage
   (delta spatial RF). Output: `rgcOut.channels.order0 .. order3`.
2. `pars.rgc.derivative.channelGain` (1x4, default `ones(1,4)`) is applied as
   a per-channel scalar multiplier right after filtering -- a simple
   lesioning hook (set an entry to 0 to silence that temporal-derivative-order
   channel everywhere). More elaborate lesions (spatially restricted,
   random-subset, delay/SNR degradation) are deliberately not implemented yet
   -- see "Next Steps".
3. `shModelV1LinearFromRgcDerivative` rebuilds the same 10-column `S` matrix
   that legacy `shModelV1Linear` builds (10 = the number of
   `(torder,xorder,yorder)` combos with `torder+xorder+yorder=3`), sourcing
   each combo's temporal component from the RGC channel matching its
   `torder`, then applying `v1SpatialFilters` derivatives for `xorder`/`yorder`
   exactly as legacy does. `pop = S * shSwts(directions)' * scaleFactor` --
   the same combination formula as legacy, no fitted weights involved.
4. Why this is (near-)exact: causally filtering with `v1TemporalFilters(:,k+1)`
   via `'full'` convolution and then trimming the leading `fsz-1` frames
   (`shModelV1LinearFromRgcDerivative.m`) reproduces legacy's centered
   `'valid'`-convolution values exactly for the retained frames -- 'full'
   convolution's first T samples contain the same interior values as 'valid'
   convolution as a contiguous subsequence, so the trim removes exactly the
   boundary-affected samples and nothing else lines up differently. There is
   no delay and no shape distortion in the default single-scale
   (`pars.nScales = 1`) configuration.
5. Known limitation: for `pars.nScales > 1`, legacy blurs/downsamples
   (`shBlurDn3`, which also downsamples in time) *before* applying the
   temporal derivative filter; the derivative-mode RGC channel applies the
   causal temporal filter *before* blurring. These commute exactly only at
   `nScales = 1` (the default). Multi-scale exactness has not been verified.

## fourPop Mode Architecture (`pars.rgc.mode = 'fourPop'`)

Unchanged from the prior implementation:

1. Stimulus (Y x X x T) enters shModelRgc, which produces 4-8 neural images
   (same Y x X x T layout): onFast, offFast, onSlow, offSlow (always
   present), plus onFastLag/offFastLag/onSlowLag/offSlowLag when
   `fastLag`/`slowLag > 0`. Each channel applies a spatial center-surround
   (DoG) filter plus a causal biphasic temporal kernel to the luminance
   input.
2. shModelV1LinearFromRgc projects each neural image onto all 10 spatial
   derivative combinations (matching shModelV1Linear's loop order), giving 40
   features (4 channels x 10) or 80 (8 channels x 10).
3. A per-neuron weight matrix (fitted by shFitRgcV1Weights) linearly combines
   those features to approximate the legacy V1 linear responses -- this fit
   tops out around ~0.7-0.8 V1 correlation, because (unlike derivative mode)
   this basis never applies a genuine temporal-derivative filter; `torder` in
   the projection only rebalances the x/y spatial split.
4. Calibration/sweep tools (`shCalibrateRgcLayer`, `shSweepRgcTemporalPars`,
   `shShowRgcV1ReceptiveFields`, `shShowRgcFourPopDemo`) are specific to this
   mode and explicitly set `pars.rgc.mode = 'fourPop'` internally so they
   keep working regardless of the global default.
5. Amplitude/delay impairment maps (`pars.rgc.impairmentEnabled`,
   `impairmentAmplitudeMap`, `impairmentDelayMap`) are implemented only in
   this mode (`localApplyImpairment` in `shModelRgc.m`), not in derivative
   mode.

Implemented files:

* model/innerworkings/shModelRgc.m (mode dispatch)
* model/innerworkings/shModelRgcDerivative.m ('derivative' channels)
* model/innerworkings/shModelV1LinearFromRgcDerivative.m ('derivative' V1 projection)
* model/innerworkings/shModelV1LinearFromRgc.m ('fourPop' V1 projection)
* model/innerworkings/shModelV1Linear.m (mode dispatch)
* model/shModel.m
* pars/shPars.m
* help/shCalibrateRgcLayer.m, shFitRgcV1Weights.m, shSweepRgcTemporalPars.m, shTestRgcV1Corr.m (fourPop-specific)
* show/shShowRgcAndV1Comparison.m, shShowRgcAndMtComparison.m, shShowRgcFourPopDemo.m, shShowRgcV1ReceptiveFields.m
* tests/testRgcDerivativeVsLegacy.m, testRgcPath.m, testRgcVsLegacyCorr.m, testParsLoading.m
* README

## Next Steps

1. ~~Validate the derivative-mode baseline empirically~~ -- DONE (2026-07-02):
   `report = shShowRgcAndV1Comparison;` gives `v1Corr = 1.000000`,
   `v1NRMSE = 0.000000` against legacy with the new default (single-scale,
   `nScales = 1`). `tests/runAllTests.m` passes all 9 tests. `shCalibrateRgcLayer`
   confirmed still functional on the `fourPop` path (~0.95 correlation,
   consistent with its pre-existing behavior).

2. Explore lesioning of the derivative-mode RGC population (the original
   motivation for stage 1):

* Start with the uniform `pars.rgc.derivative.channelGain` hook already in
  place (per-order-class, spatially uniform).
* Planned follow-ups, not yet implemented: spatially restricted lesions (one
  channel silenced in a limited X-Y region), random-subset lesions across
  temporal class and space (per-RGC-unit rather than per-channel), and
  partial lesions (delay and/or reduced SNR rather than full silencing).
  These will need a per-pixel (not just per-channel) gain/delay/noise
  mechanism in `shModelRgcDerivative.m`.

3. Stage 2 (biological realism): redefine the RGC classes in `fourPop` mode
   with more realistic ON/OFF midget and parasol RGC spatial/temporal RF
   properties (already partially in place -- see "fourPop Mode Architecture").

## MATLAB Commands

1. Healthy RGC path (default, exact reconstruction):

* `pars = shPars;   % pars.rgc.enabled == 1, pars.rgc.mode == 'derivative'`
* To use legacy V1 directly: `pars.rgc.enabled = 0;`
* To lesion a temporal-derivative channel: `pars.rgc.derivative.channelGain(2) = 0;`

2. Biological (fourPop) path:

* `pars = shPars; pars.rgc.mode = 'fourPop'; pars.rgc.v1Weights = [];`
* `pars.rgc.v1Weights = shFitRgcV1Weights(pars, stimSet);` (or let
  `shShowRgcAndV1Comparison`/`shShowRgcAndMtComparison` fit it automatically)

3. Calibration quick run (fourPop only):

* `report = shCalibrateRgcLayer(60)`

4. Example impairment setup (fourPop only):

* `pars.rgc.mode = 'fourPop'; pars.rgc.impairmentEnabled = 1;`
* `pars.rgc.impairmentAmplitudeMap = ones(Y, X);  % edit map values`
* `pars.rgc.impairmentDelayMap = zeros(Y, X);     % integer frame delays`

## Notes for Future Agents

* RGC is enabled by default in `'derivative'` mode; any change to
  `pars.v1TemporalFilters`/`pars.v1SpatialFilters` or the derivative-mode
  wiring affects all users by default. Run `tests/runAllTests.m` before
  changing defaults.
* `'fourPop'`-specific tools (`shCalibrateRgcLayer`, `shSweepRgcTemporalPars`,
  `shShowRgcV1ReceptiveFields`, `shShowRgcFourPopDemo`, `shTestRgcV1Corr`) set
  `pars.rgc.mode = 'fourPop'` internally -- keep doing this in any new
  fourPop-specific tool so it isn't silently affected by the global default.
* Prioritize scientific comparability (healthy mode) before adding new complexity.
* Keep all new scripts deterministic where possible (set random seeds).
