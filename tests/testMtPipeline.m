% testMtPipeline  Verify MT model pipeline runs and produces sensible responses.

rng(1);
pars = shPars();
dims = shGetDims(pars, 'mtPattern', [1 1 1]);

% Rightward dot motion at speed 1
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

% --- mtPattern stage ---
[pop, ind] = shModel(stim, pars, 'mtPattern');
shAssert(~isempty(pop),             'mtPattern: pop must be non-empty');
shAssert(all(isfinite(pop(:))),     'mtPattern: pop must be finite');

p = shGetNeuron(pop, ind);
shAssert(all(isfinite(p(:))),       'mtPattern: shGetNeuron must be finite');
shAssert(all(p(:) >= 0),            'mtPattern: MT responses must be nonneg');
shAssert(size(p, 1) == size(pars.mtPopulationVelocities, 1), ...
    'mtPattern: shGetNeuron must return one row per MT population neuron');

% Neuron tuned to rightward motion should respond best
vels = pars.mtPopulationVelocities;
dists = abs(vels(:,1) - 0) + abs(vels(:,2) - 1);
[~, prefIdx] = min(dists);
shAssert(mean(p(prefIdx,:)) > median(mean(p, 2)), ...
    'mtPattern: preferred MT neuron should have above-median response');

% --- additionalNeurons argument ---
extraNeuron = [0, 1];
[pop2, ind2, res2] = shModel(stim, pars, 'mtPattern', extraNeuron);
shAssert(~isempty(res2),            'mtPattern: res must be non-empty with additionalNeurons');
shAssert(all(isfinite(res2(:))),    'mtPattern: res must be finite');

% --- Zero stimulus -> near-baseline MT responses ---
stimZero = zeros(dims);
[popZ, indZ] = shModel(stimZero, pars, 'mtPattern');
pZ = shGetNeuron(popZ, indZ);
shAssert(max(pZ(:)) < pars.mtBaseline + 0.05, ...
    'mtPattern: zero stimulus should give near-baseline MT responses');
