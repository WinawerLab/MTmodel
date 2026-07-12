% testClassPathFourPop  Guardrail for the fourPop preset on the unified class
% path (increment 3c): shRgcClassesFourPop + shClassV1Basis must reproduce the
% legacy fourPop feature basis (shModelV1LinearFromRgc / shModelRgc) exactly,
% including lagged channels. See docs/RGC_V1_unification_plan.md and
% explore/verifyClassPathFourPop.m.

rng(7);
pars = shPars;
parsFP = pars; parsFP.rgc.mode = 'fourPop';

% within-channel column permutation: legacy loops (torder outer, spatial
% order descending); the class path's default readoutOrders = [0 1 2 3]
% loops spatial order ascending. Same (xorder,yorder) values, different order.
permOldToNew = [7 8 9 10 4 5 6 2 3 1];

dims = shGetDims(pars, 'mtPattern', [1 1 18]);
stim = mkDots(dims, pi/3, 0.9, 0.12, 1);

% --- no lag (default) ---
parsCls = pars;
parsCls.rgc.classes = shRgcClassesFourPop(parsFP);
parsCls.rgc.combine = 'weights';

[~, ~, Sold] = shModelV1LinearFromRgc(stim, parsFP);
[Snew, ~, ~] = shClassV1Basis(stim, parsCls);

shAssert(isequal(size(Sold), size(Snew)), 'fourPop class basis must have the same size as the legacy basis');
nChan = size(Sold, 2) / 10;
shAssert(nChan == 4, 'no-lag fourPop basis must have 4 channels x 10 read-outs');
perm = [];
for c = 1:nChan
    perm = [perm, (c - 1) * 10 + permOldToNew]; %#ok<AGROW>
end
e = max(abs(Sold(:) - reshape(Snew(:, perm), [], 1)));
shAssert(e < 1e-10, sprintf('fourPop class basis (no lag) must match legacy exactly (err = %.3e)', e));

% --- with lag channels ---
parsFPLag = parsFP; parsFPLag.rgc.temporal.fastLag = 2; parsFPLag.rgc.temporal.slowLag = 3;
parsClsLag = pars;
parsClsLag.rgc.classes = shRgcClassesFourPop(parsFPLag);
parsClsLag.rgc.combine = 'weights';

[~, ~, SoldLag] = shModelV1LinearFromRgc(stim, parsFPLag);
[SnewLag, ~, ~] = shClassV1Basis(stim, parsClsLag);

nChanLag = size(SoldLag, 2) / 10;
shAssert(nChanLag == 8, 'lagged fourPop basis must have 8 channels x 10 read-outs');
permLag = [];
for c = 1:nChanLag
    permLag = [permLag, (c - 1) * 10 + permOldToNew]; %#ok<AGROW>
end
eLag = max(abs(SoldLag(:) - reshape(SnewLag(:, permLag), [], 1)));
shAssert(eLag < 1e-10, sprintf('fourPop class basis (with lag) must match legacy exactly (err = %.3e)', eLag));

% --- end-to-end: fit weights on the class path and confirm a finite, sane V1 output ---
trainSet = { mkDots(dims, 0, 1.0, 0.12, 1), mkSin(dims, pi/4, 0.10, 0.10, 1) };
parsCls.rgc.v1Weights = shFitClassV1Weights(parsCls, trainSet);
popCls = shModelV1LinearFromClasses(stim, parsCls);
shAssert(all(isfinite(popCls(:))), 'fitted fourPop class-path V1 output must be finite');
