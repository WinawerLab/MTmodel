% classes = shRgcClassesMidgetParasol(pars)
%
% Biological RGC-class preset for the unified class-based front-end: ON/OFF x
% midget/parasol (4 classes). Each class has a center-surround (DoG) spatial RF
% (parasol large, midget small), a causal difference-of-gamma temporal kernel
% (parasol fast, midget slow), and half-wave rectification by polarity.
%
% Direction-selectivity ingredients (Chariker/Shapley; see
% docs/RGC_V1_unification_plan.md §2.6-2.7):
%   * ON channels get a quadrature (90-deg phase-shifted) temporal kernel relative
%     to OFF -- a constant-phase ON/OFF difference (Mechanism #2, broadband DS);
%   * ON/OFF channels are given opposite spatial readout offsets, so a V1 neuron
%     reads them from displaced subregions (the ON/OFF spatial offset).
% Together with a fitted weight matrix (shFitClassV1Weights) these give V1 neurons
% oriented, direction-selective spatiotemporal RFs.
%
% Each class feeds all V1 spatial-derivative read-out orders (0..3 -> 10 combos),
% so the basis is 4 x 10 = 40 features. Use pars.rgc.combine = 'weights'.
%
% This is a first-pass parameterization (the temporal kernels/offsets are not yet
% calibrated to a frame rate or to Kling 2020 time courses).

function classes = shRgcClassesMidgetParasol(pars) %#ok<INUSD>

    % temporal kernels (difference-of-gamma, in frames): parasol fast, midget slow
    parasolK  = localBiGamma(0.6, 1.2, 0.45, 2, 24);
    midgetK   = localBiGamma(2.0, 4.0, 0.15, 2, 24);
    parasolKq = shQuadratureKernel(parasolK);   % ON partner (constant-phase shift)
    midgetKq  = shQuadratureKernel(midgetK);

    % center-surround spatial RFs (pixels): parasol large, midget small
    parasolRF = struct('centerSigma', 1.6, 'surroundSigma', 4.0, 'surroundWeight', 0.25);
    midgetRF  = struct('centerSigma', 0.8, 'surroundSigma', 2.0, 'surroundWeight', 0.25);

    offset = 2;   % ON/OFF spatial readout offset (pixels, along X)

    classes = [ ...
        shRgcClass('parasolOn',  parasolKq, 'spatialRF', parasolRF, 'rectify', 'onHalf',  'readoutOffset', [0 +offset]), ...
        shRgcClass('parasolOff', parasolK,  'spatialRF', parasolRF, 'rectify', 'offHalf', 'readoutOffset', [0 -offset]), ...
        shRgcClass('midgetOn',   midgetKq,  'spatialRF', midgetRF,  'rectify', 'onHalf',  'readoutOffset', [0 +offset]), ...
        shRgcClass('midgetOff',  midgetK,   'spatialRF', midgetRF,  'rectify', 'offHalf', 'readoutOffset', [0 -offset]) ];

end

function k = localBiGamma(tau1, tau2, w, n, L)
    t = 0:(L - 1);
    k = (t ./ tau1) .^ n .* exp(-t ./ tau1) - w .* (t ./ tau2) .^ n .* exp(-t ./ tau2);
    k = k ./ max(abs(k));
end
