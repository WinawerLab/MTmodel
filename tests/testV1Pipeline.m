% testV1Pipeline  Verify V1 model stages run and produce sensible responses.

rng(1);
pars = shPars();
dims = shGetDims(pars, 'v1Complex', [1 1 1]);

% Build a grating at the preferred direction/speed of a known neuron
g = v12sin([0, 1]);
stim = mkSin(dims, 0, g(2), g(3), 1);

% --- v1Complex stage ---
[pop, ind] = shModel(stim, pars, 'v1Complex');
shAssert(~isempty(pop),             'v1Complex: pop must be non-empty');
shAssert(all(isfinite(pop(:))),     'v1Complex: pop must be finite');
shAssert(all(pop(:) >= 0),          'v1Complex: pop must be nonneg after rectification');

p = shGetNeuron(pop, ind);
shAssert(size(p, 1) == size(pars.v1PopulationDirections, 1), ...
    'v1Complex: shGetNeuron must return one row per population neuron');
shAssert(all(isfinite(p(:))),       'v1Complex: shGetNeuron must be finite');

% Neuron tuned to direction 0 / speed 1 should respond above the median
dirs = pars.v1PopulationDirections;
dists = abs(dirs(:,1) - 0) + abs(dirs(:,2) - 1);
[~, prefIdx] = min(dists);
shAssert(mean(p(prefIdx,:)) > median(mean(p, 2)), ...
    'v1Complex: preferred neuron should have above-median mean response');

% --- v1lin stage returns 3 outputs ---
[popLin, indLin, S] = shModel(stim, pars, 'v1lin');
shAssert(~isempty(popLin),          'v1lin: pop must be non-empty');
shAssert(~isempty(S),               'v1lin: S output must be non-empty');

% --- Zero stimulus -> near-zero V1 responses ---
stimZero = zeros(dims);
[popZ, indZ] = shModel(stimZero, pars, 'v1Complex');
pZ = shGetNeuron(popZ, indZ);
shAssert(max(pZ(:)) < 0.01,         'v1Complex: zero stimulus must give near-zero responses');
