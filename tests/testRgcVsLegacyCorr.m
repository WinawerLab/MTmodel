% testRgcVsLegacyCorr  Verify that the RGC V1 path correlates with the legacy path.

rng(1);
pars = shPars();

dims = shGetDims(pars, 'v1Complex', [1 1 24]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

% Pin the biological 'fourPop' path explicitly: this test measures the
% fitted-weight correlation ceiling of that mode. The default mode
% ('derivative') is covered separately by testRgcDerivativeVsLegacy, which
% expects near-exact (not just > 0.7) reconstruction.
%
% On the unified class path, combine='weights' has no default fallback (the
% legacy shModelV1LinearFromRgc's default shRgcV1Weights combination for the
% first 4 channels is gone) -- fourPop mode always needs a fit.
parsNo  = pars; parsNo.rgc.enabled  = 0;
parsRgc = pars; parsRgc.rgc.enabled = 1; parsRgc.rgc.mode = 'fourPop'; parsRgc.rgc.v1Weights = [];

[v1Legacy, ~] = shModel(stim, parsNo,  'v1Complex');

% Unfitted weights must error, not silently fall back.
threw = false;
try
    shModel(stim, parsRgc, 'v1Complex');
catch
    threw = true;
end
shAssert(threw, 'fourPop mode: combine=weights must error before weights are fit');

% Fitted weights should improve correlation to > 0.7
stimSet = localBuildStimSet(stim, dims);
parsRgc.rgc.classes = shRgcClassesFourPop(parsRgc);
parsRgc.rgc.combine = 'weights';
parsRgc.rgc.v1Weights = shFitClassV1Weights(parsRgc, stimSet);
[v1Fitted, ~] = shModel(stim, parsRgc, 'v1Complex');
shAssert(all(isfinite(v1Fitted(:))),   'RGC path: fitted V1 output must be finite');
shAssert(any(v1Fitted(:) ~= v1Legacy(:)), 'RGC path: fitted output must differ from legacy (not a no-op)');
r2 = corrcoef(v1Legacy(:), v1Fitted(:));
corrFitted = r2(1, 2);
shAssert(corrFitted > 0.7, ...
    sprintf('RGC-legacy V1 correlation too low (fitted weights): %.3f', corrFitted));

function stimSet = localBuildStimSet(stimulus, dims)
    stimSet = cell(1, 4);
    stimSet{1} = stimulus;
    stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);
    g1 = v12sin([0, 1.0]);
    g2 = v12sin([pi/3, 1.6]);
    stimSet{3} = mkSin(dims, 0,    g1(2), g1(3), 1);
    stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);
end
