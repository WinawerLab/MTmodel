% verifyClassPathFourPop  Check shRgcClassesFourPop + shClassV1Basis reproduces
% the legacy fourPop feature basis (shModelV1LinearFromRgc / shModelRgc) exactly.
%
% Increment 3c of the pars.rgc.classes refactor (docs/RGC_V1_unification_plan.md):
% the class-based basis matrix S is column-permuted relative to the legacy
% basis (legacy loops temporal-order-outer / spatial-order-descending; the
% class path's default readoutOrders = [0 1 2 3] loops spatial-order-ascending),
% but should be numerically identical once permuted. See tests/testClassPathFourPop.m
% for the pass/fail guardrail; this script just reports the errors.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(7);

pars = shPars;
parsFP = pars; parsFP.rgc.mode = 'fourPop';

parsCls = pars;
parsCls.rgc.classes = shRgcClassesFourPop(parsFP);
parsCls.rgc.combine = 'weights';

% within-channel column permutation: old (torder outer, s descending) -> new
% (s ascending, readoutOrders default [0 1 2 3]). See shClassV1Basis / shSwts
% column-order comments.
permOldToNew = [7 8 9 10 4 5 6 2 3 1];

dims = shGetDims(pars, 'mtPattern', [1 1 18]);
stims = { randn(dims), mkSin(dims, pi/4, 0.08, 0.10, 1), mkDots(dims, pi/3, 0.9, 0.12, 1) };

fprintf('%-10s | %-10s | %s\n', 'lag', 'stimulus', 'max abs err (permuted)');
for lagCase = 1:2
    if lagCase == 1
        parsFPi = parsFP; parsClsi = parsCls;   % no lag (default)
        label = 'no lag';
    else
        parsFPi = parsFP; parsFPi.rgc.temporal.fastLag = 2; parsFPi.rgc.temporal.slowLag = 3;
        parsClsi = parsCls; parsClsi.rgc.classes = shRgcClassesFourPop(parsFPi);
        label = 'lag 2/3';
    end

    for i = 1:numel(stims)
        s = stims{i};
        [~, ~, Sold] = shModelV1LinearFromRgc(s, parsFPi);
        [Snew, ~, ~] = shClassV1Basis(s, parsClsi);

        nChan = size(Sold, 2) / 10;
        perm = [];
        for c = 1:nChan
            perm = [perm, (c - 1) * 10 + permOldToNew]; %#ok<AGROW>
        end
        e = max(abs(Sold(:) - reshape(Snew(:, perm), [], 1)));
        fprintf('%-10s | stim %-3d | %.3e\n', label, i, e);
    end
end

fprintf('\nExpectation: err ~1e-13 or better (identical channel + basis math, permuted columns).\n');
