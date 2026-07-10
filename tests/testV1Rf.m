% testV1Rf  Guardrail for the class-agnostic RF viewer (shV1Rf, increment 3b).
%
% Derivative preset: the stimulus-referred RF must reproduce the model's V1
% response on a single-location (fsz x fsz x fsz) stimulus to machine precision.
% Biological preset: shV1Rf must run and return finite arrays of the right shape.

rng(1);
pars = shPars;                               % derivative, classes populated
fsz = size(pars.v1SpatialFilters, 1);

% --- derivative: RFstim reproduces the model exactly ---
M = randn(fsz, fsz, fsz);
pop = shModelV1Linear(M, pars);              % 1 x 28, single output location
scale = pars.scaleFactors.v1Linear;
maxerr = 0;
for j = 1:size(pars.v1PopulationDirections, 1)
    [RFrgc, RFstim] = shV1Rf(pars, j);
    shAssert(isequal(size(RFrgc), [fsz fsz 4]), 'RFrgc must be fsz x fsz x 4 (derivative)');
    Kabs = flip(RFstim, 3);                  % lag axis <-> absolute-frame axis
    pred = scale * sum(Kabs(:) .* M(:));
    maxerr = max(maxerr, abs(pred - pop(j)));
end
shAssert(maxerr < 1e-10, sprintf('shV1Rf derivative RFstim vs model too far: %.3e', maxerr));

% --- biological: runs, finite, right shapes ---
parsB = shPars;
parsB.rgc.classes = shRgcClassesMidgetParasol(parsB);
parsB.rgc.combine = 'weights';
dims = shGetDims(parsB, 'mtPattern', [1 1 18]);
stimSet = { mkDots(dims,0,1,0.12,1), mkSin(dims,0,0.9,0.10,1), mkSin(dims,pi/3,1.4,0.12,1) };
parsB.rgc.v1Weights = shFitClassV1Weights(parsB, stimSet);

[RFrgcB, RFstimB, infoB] = shV1Rf(parsB, 5);
shAssert(isequal(size(RFrgcB), [fsz fsz 4]), 'biological RFrgc must be fsz x fsz x 4');
shAssert(all(isfinite(RFrgcB(:))) && all(isfinite(RFstimB(:))), 'biological RF arrays must be finite');
shAssert(numel(infoB.classNames) == 4, 'biological info must list 4 class names');
