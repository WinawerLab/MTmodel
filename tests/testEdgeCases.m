% testEdgeCases  Verify error handling and boundary conditions.

rng(1);
pars = shPars();

% Too-small stimulus must raise an error
caughtError = false;
try
    shModel(zeros(5, 5, 5), pars, 'mtPattern');
catch
    caughtError = true;
end
shAssert(caughtError, 'shModel: must error when stimulus is too small for mtPattern');

% Unknown stage name must raise an error
caughtBadStage = false;
try
    shGetDims(pars, 'notAStage');
catch
    caughtBadStage = true;
end
shAssert(caughtBadStage, 'shGetDims: must error for unknown stage name');

% Zero-contrast stimulus (flat 0.5) produces finite, non-NaN responses
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
stimFlat = mkSin(dims, 0, 0.1, 0.05, 0);  % contrast = 0 -> all 0.5
[popFlat, indFlat] = shModel(stimFlat, pars, 'v1Complex');
shAssert(all(isfinite(popFlat(:))), 'v1Complex: zero-contrast stimulus must give finite responses');
pFlat = shGetNeuron(popFlat, indFlat);
shAssert(all(isfinite(pFlat(:))),   'v1Complex: zero-contrast shGetNeuron must be finite');

% Zero stimulus -> near-zero MT responses (< baseline + small buffer)
dimsM = shGetDims(pars, 'mtPattern', [1 1 1]);
stimZero = zeros(dimsM);
[popZ, indZ] = shModel(stimZero, pars, 'mtPattern');
pZ = shGetNeuron(popZ, indZ);
shAssert(max(pZ(:)) < pars.mtBaseline + 0.05, ...
    'mtPattern: zero stimulus must give near-baseline MT responses');

% v1NormalizationType = 'off' must still run v1Complex without error
parsOff = pars;
parsOff.v1NormalizationType = 'off';
dims2 = shGetDims(parsOff, 'v1Complex', [1 1 1]);
g = v12sin([0, 1]);
stim2 = mkSin(dims2, 0, g(2), g(3), 1);
[popOff, ~] = shModel(stim2, parsOff, 'v1Complex');
shAssert(all(isfinite(popOff(:))), 'v1Complex with normalization off must produce finite responses');
