% classes = shRgcClassesMidgetParasolLagged(pars, lags)
%
% Biological RGC-class preset aligned with the 2026-07-12 scope pivot
% (docs/RGC_V1_design_discussion.md §14-15): ON/OFF x midget/parasol, each with
% a center-surround (DoG) spatial RF and a causal difference-of-gamma temporal
% kernel, PLUS lagged copies of every class. Two design choices distinguish it
% from shRgcClassesMidgetParasol:
%
%   * NO ON/OFF spatial read-out offset and NO ON quadrature kernel. The
%     biological direction-selectivity mechanism was demoted to a side-quest
%     (§14): it distorts orientation and fights the SH steerable read-out, which
%     already yields DS for free. Here DS comes from the V1 read-out as in SH.
%   * LAGGED copies (kernel zero-padded by d frames) at each lag in `lags`. A
%     difference of lagged biphasic kernels approximates a temporal derivative, so
%     lags let the read-out synthesize SH's high-TF (order 2-3) channels that a
%     single mono/biphasic RGC cannot (§15, explore/temporalTilingFromLags.m). Each
%     channel stays mono/biphasic (Kling-plausible); high order lives in the
%     linear combination.
%
% Classes = {parasol,midget} x {On,Off} x lags. With the default lags = [0 1 2 3]
% that is 2 x 2 x 4 = 16 classes, each feeding read-out orders 0..3 (10 combos) ->
% 160 features. Use pars.rgc.combine = 'weights' (fit via shFitClassV1Weights).
%
% Optional arguments:
% lags   vector of integer frame delays for the lagged copies. [ [0 1 2 3] ]

function classes = shRgcClassesMidgetParasolLagged(pars, lags) %#ok<INUSL>

    if nargin < 2 || isempty(lags), lags = [0 1 2 3]; end

    parasolK = localBiGamma(0.6, 1.2, 0.45, 2, 24);   % fast / magno
    midgetK  = localBiGamma(2.0, 4.0, 0.15, 2, 24);   % slow / parvo

    parasolRF = struct('centerSigma', 1.6, 'surroundSigma', 4.0, 'surroundWeight', 0.25);
    midgetRF  = struct('centerSigma', 0.8, 'surroundSigma', 2.0, 'surroundWeight', 0.25);

    types = { 'parasol', parasolK, parasolRF; 'midget', midgetK, midgetRF };
    pols  = { 'On', 'onHalf'; 'Off', 'offHalf' };

    classes = shRgcClass('placeholder', 1);   % seed; overwritten below
    n = 0;
    for t = 1:size(types,1)
        for p = 1:size(pols,1)
            for d = lags(:)'
                k = [zeros(d,1); types{t,2}(:)];
                nm = sprintf('%s%s_lag%d', types{t,1}, pols{p,1}, d);
                n = n + 1;
                classes(n) = shRgcClass(nm, k, 'spatialRF', types{t,3}, ...
                                        'rectify', pols{p,2}, 'readoutOffset', [0 0]);
            end
        end
    end

end

function k = localBiGamma(tau1, tau2, w, nn, L)
    t = 0:(L - 1);
    k = (t ./ tau1) .^ nn .* exp(-t ./ tau1) - w .* (t ./ tau2) .^ nn .* exp(-t ./ tau2);
    k = k ./ max(abs(k));
end
