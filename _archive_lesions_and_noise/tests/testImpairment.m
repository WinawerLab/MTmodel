% testImpairment  Optic-neuritis impairment on the unified class path
% (increment 3c). Amplitude/delay deficits are applied to each class channel via
% the shared shApplyRgcImpairment.

rng(1);
pars = shPars;                                   % derivative, class path
dims = shGetDims(pars, 'v1Complex', [1 1 24]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);
Y = dims(1); X = dims(2);

v1Healthy = shModelV1Linear(stim, pars);

% disabled by default -> identical to healthy
shAssert(pars.rgc.impairmentEnabled == 0, 'impairment must default to disabled');

% uniform amplitude deficit: the linear (derivative) path scales exactly.
parsAmp = pars;
parsAmp.rgc.impairmentEnabled = 1;
parsAmp.rgc.impairmentAmplitudeMap = 0.5 * ones(Y, X);
v1Amp = shModelV1Linear(stim, parsAmp);
shAssert(all(isfinite(v1Amp(:))), 'amplitude-impaired V1 must be finite');
shAssert(max(abs(v1Amp(:) - 0.5 * v1Healthy(:))) < 1e-10, ...
    'a uniform 0.5 amplitude map must scale the linear V1 response by exactly 0.5');

% localized deficit (silence top half) changes the output but stays finite.
parsLoc = pars;
parsLoc.rgc.impairmentEnabled = 1;
amp = ones(Y, X); amp(1:round(Y / 2), :) = 0;
parsLoc.rgc.impairmentAmplitudeMap = amp;
v1Loc = shModelV1Linear(stim, parsLoc);
shAssert(all(isfinite(v1Loc(:))), 'localized-deficit V1 must be finite');
shAssert(any(v1Loc(:) ~= v1Healthy(:)), 'a localized amplitude deficit must change the output');

% integer-frame delay map changes the output and stays finite.
parsDel = pars;
parsDel.rgc.impairmentEnabled = 1;
parsDel.rgc.impairmentDelayMap = 2 * ones(Y, X);
v1Del = shModelV1Linear(stim, parsDel);
shAssert(all(isfinite(v1Del(:))), 'delay-impaired V1 must be finite');
shAssert(any(v1Del(:) ~= v1Healthy(:)), 'a delay map must change the output');

% a non-integer delay map must error.
threw = false;
try
    parsBad = pars; parsBad.rgc.impairmentEnabled = 1;
    parsBad.rgc.impairmentDelayMap = 1.5 * ones(Y, X);
    shModelV1Linear(stim, parsBad);
catch
    threw = true;
end
shAssert(threw, 'a non-integer delay map must error');
