% testGetNeuron  Verify shGetNeuron and shGetSubPop extraction utilities.

rng(1);
pars = shPars();
% Use [3 3 3] output so shGetSubPop returns a true 3D array rather than
% a 2D array squeezed by MATLAB when output is [1 1 1].
dims = shGetDims(pars, 'mtPattern', [3 3 3]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

[pop, ind] = shModel(stim, pars, 'mtPattern');
nNeurons = size(pars.mtPopulationVelocities, 1);

% Default call returns one row per MT population neuron
p = shGetNeuron(pop, ind);
shAssert(size(p, 1) == nNeurons, ...
    sprintf('shGetNeuron: expected %d rows, got %d', nNeurons, size(p, 1)));
shAssert(all(isfinite(p(:))), 'shGetNeuron: responses must be finite');

% Subsetting to specific neurons returns the right number of rows
sub = shGetNeuron(pop, ind, [1 3]);
shAssert(size(sub, 1) == 2, 'shGetNeuron with index [1 3]: must return 2 rows');
shAssert(all(isfinite(sub(:))), 'shGetNeuron subset: must be finite');

% Rows from subset match rows from full extraction
shAssertNear(sub(1,:), p(1,:), 1e-12, 'shGetNeuron subset row 1 must match full row 1');
shAssertNear(sub(2,:), p(3,:), 1e-12, 'shGetNeuron subset row 2 must match full row 3');

% shGetSubPop returns a 3D array
sp = shGetSubPop(pop, ind, 1, 1);
shAssert(ndims(sp) == 3, 'shGetSubPop: must return a 3D array');
shAssert(all(isfinite(sp(:))), 'shGetSubPop: must be finite');

% additionalNeurons res extraction
extraNeuron = [0, 1];
[pop2, ind2, res2] = shModel(stim, pars, 'mtPattern', extraNeuron);
pExtra = shGetNeuron(res2, ind2);
shAssert(size(pExtra, 1) == 1,        'additionalNeurons: shGetNeuron must return 1 row');
shAssert(all(isfinite(pExtra(:))),    'additionalNeurons: shGetNeuron must be finite');
