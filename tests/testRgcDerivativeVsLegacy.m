% testRgcDerivativeVsLegacy  Verify the default 'derivative' RGC mode
% reconstructs legacy V1/MT responses almost exactly (no fitted weights).

rng(1);
pars = shPars();

dims = shGetDims(pars, 'v1Complex', [1 1 24]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

parsNo  = pars; parsNo.rgc.enabled  = 0;
parsRgc = pars; parsRgc.rgc.enabled = 1; parsRgc.rgc.mode = 'derivative';

[v1Legacy, ~] = shModel(stim, parsNo,  'v1Complex');
[v1Deriv,  ~] = shModel(stim, parsRgc, 'v1Complex');

shAssert(all(isfinite(v1Deriv(:))), 'derivative RGC: V1 output must be finite');

r = corrcoef(v1Legacy(:), v1Deriv(:));
corrDeriv = r(1, 2);
shAssert(corrDeriv > 0.98, ...
    sprintf('derivative-mode V1 correlation too low: %.4f', corrDeriv));

nrmse = norm(v1Legacy(:) - v1Deriv(:)) / max(norm(v1Legacy(:)), eps);
shAssert(nrmse < 0.2, sprintf('derivative-mode V1 NRMSE too high: %.4f', nrmse));

% MT stage should also be finite and closely correlated.
dimsMt = shGetDims(pars, 'mtPattern', [1 1 24]);
stimMt = mkDots(dimsMt, 0, 1.0, 0.12, 1.0);
[mtLegacy, ~] = shModel(stimMt, parsNo,  'mtPattern');
[mtDeriv,  ~] = shModel(stimMt, parsRgc, 'mtPattern');
shAssert(all(isfinite(mtDeriv(:))), 'derivative RGC: MT output must be finite');
rMt = corrcoef(mtLegacy(:), mtDeriv(:));
shAssert(rMt(1, 2) > 0.95, sprintf('derivative-mode MT correlation too low: %.4f', rMt(1, 2)));

% --- Lesioning smoke test: zeroing each channel changes output but keeps it finite ---
for k = 1:4
    parsLesion = parsRgc;
    parsLesion.rgc.derivative.channelGain = ones(1, 4);
    parsLesion.rgc.derivative.channelGain(k) = 0;
    [v1Lesion, ~] = shModel(stim, parsLesion, 'v1Complex');
    shAssert(all(isfinite(v1Lesion(:))), sprintf('lesioned channel %d: V1 output must be finite', k));
    shAssert(any(v1Lesion(:) ~= v1Deriv(:)), sprintf('lesioned channel %d: output must differ from healthy', k));
end
