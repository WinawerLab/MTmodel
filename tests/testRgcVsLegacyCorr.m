% testRgcVsLegacyCorr  Verify that the RGC V1 path correlates with the legacy path.

rng(1);
pars = shPars();

dims = shGetDims(pars, 'v1Complex', [1 1 24]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

% Pin the biological 'fourPop' path explicitly: this test measures the
% fitted-weight correlation ceiling of that mode. The default mode
% ('derivative') is covered separately by testRgcDerivativeVsLegacy, which
% expects near-exact (not just > 0.7) reconstruction.
parsNo  = pars; parsNo.rgc.enabled  = 0;
parsRgc = pars; parsRgc.rgc.enabled = 1; parsRgc.rgc.mode = 'fourPop'; parsRgc.rgc.v1Weights = [];

[v1Legacy, ~] = shModel(stim, parsNo,  'v1Complex');
[v1Rgc,    ~] = shModel(stim, parsRgc, 'v1Complex');

% Both paths must produce finite, non-identical outputs
shAssert(all(isfinite(v1Rgc(:))),   'RGC path: V1 output must be finite');
shAssert(any(v1Rgc(:) ~= v1Legacy(:)), 'RGC path: output must differ from legacy (not a no-op)');

% Fitted weights should improve correlation to > 0.7
stimSet = localBuildStimSet(stim, dims);
parsRgc.rgc.v1Weights = shFitRgcV1Weights(parsRgc, stimSet);
[v1Fitted, ~] = shModel(stim, parsRgc, 'v1Complex');
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
