% fitMagnoMtPopulation
%
% Fit the MT-projecting ("population A") V1 weights with the feature basis masked
% to parasol classes only, and report how well that restricted basis reproduces
% the legacy V1 target compared with the existing mixed fit (population B).
%
% This is step 1 of docs/TODO.md item 1 -- the change that gives the midget/parasol
% labels meaning. Motivation, in brief (Nassi & Callaway 2006, 2007):
%
%   * Disynaptic label in layer 4C after an MT injection is ~96-97% in
%     M-dominated 4Ca, ~3% in P-dominated 4Cb (Nassi 2006 Fig 7A).
%   * MT-projecting layer 4B cells are 76% spiny stellate, which receive input
%     only from 4Ca (Nassi 2007).
%   * So the V1 population MT reads is magnocellular; the mixed V1 population is
%     the one that projects to V2.
%
% shMtWts is analytic in the direction geometry and carries no cell-type
% information, so the M/P dependence of MT is set entirely by this weight matrix
% -- provided the direction tiling stays complete. Hence: mask the FEATURES, never
% subset the neurons.
%
% Pre-registered check (docs/TODO.md 1.5): a partial failure is expected and is a
% result, not a problem. The parasol kernel is fast (tau 0.6/1.2) and may not build
% the sustained low-TF V1 neurons -- which are the ones MT cares least about. If so,
% score r on the MT-relevant subset rather than the whole tiling.
%
% Outputs a cached weight matrix used by pars.rgc.mtMix.weightsA
% (see shModelV1ComplexForMt).

% Self-locating script: adds MTmodel path automatically (as validateSHFigs9to14)
clear; clc;
repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));

fprintf('=== Masked (parasol-only) refit of the MT-projecting V1 population ===\n\n');

% ---------------------------------------------------------------- setup
pars = shPars;
pars.rgc.enabled     = 1;
pars.rgc.mode        = 'custom';
pars.rgc.classes     = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine     = 'weights';
pars.rgc.classesMode = 'custom';

nNeurons = size(pars.v1PopulationDirections, 1);
fprintf('V1 population: %d neurons, %d RGC classes\n', nNeurons, numel(pars.rgc.classes));

% Feature masks. Column layout is contiguous per class, so a class owns a whole
% block of columns or none of it (see shClassFeatureMask).
[maskP, infoP] = shClassFeatureMask(pars, '^parasol');
[maskM, infoM] = shClassFeatureMask(pars, '^midget');
fprintf('Feature basis: %d columns (%d parasol, %d midget)\n\n', ...
        infoP.nCols, infoP.nSelected, infoM.nSelected);

% ---------------------------------------------------------------- stimuli
% Same training stimulus as validateSHFigs9to14 (rng 42) so population B matches
% the existing cached fit; a second, independently seeded stimulus is held out.
dims = shGetDims(pars, 'v1Complex', [5 5 20]);
rng(42);  trainStim = rand(dims);
rng(7);   testStim  = rand(dims);

% ---------------------------------------------------------------- fits
fprintf('Fitting population B (mixed, all %d columns)...\n', infoP.nCols);
WB = shFitClassV1Weights(pars, {trainStim});

fprintf('Fitting population A (parasol-masked, %d columns)...\n', infoP.nSelected);
WA = shFitClassV1Weights(pars, {trainStim}, maskP);

% ---------------------------------------------------------------- diagnostics
fprintf('\n--- Parasol share of |weight| per V1 neuron ---\n');
shareB = localParasolShare(WB, maskP);
shareA = localParasolShare(WA, maskP);
fprintf('  population B (mixed)  : %.3f - %.3f (median %.3f)\n', ...
        min(shareB), max(shareB), median(shareB));
fprintf('  population A (masked) : %.3f - %.3f (median %.3f)\n', ...
        min(shareA), max(shareA), median(shareA));

fprintf('\n--- Reconstruction of the legacy V1 target (per-neuron r) ---\n');
[rA_tr, rB_tr] = localFitQuality(pars, trainStim, WA, WB);
[rA_te, rB_te] = localFitQuality(pars, testStim,  WA, WB);

fprintf('  %-22s %8s %8s %8s %8s\n', '', 'median', 'min', 'p25', 'worst-5');
localReport('B mixed   (train)', rB_tr);
localReport('A parasol (train)', rA_tr);
localReport('B mixed   (test) ', rB_te);
localReport('A parasol (test) ', rA_te);

% Which neurons suffer most under the mask? Per TODO 1.5, the expectation is that
% the losses concentrate in sustained / low-TF neurons, which MT weights least.
dLoss = rB_te - rA_te;
[~, ordr] = sort(dLoss, 'descend');
fprintf('\n  Largest r losses under the mask (neuron: dirParam, tfsf, rB -> rA):\n');
for k = 1:min(5, numel(ordr))
    n = ordr(k);
    fprintf('    n=%2d: [%6.3f %6.3f]  %.3f -> %.3f  (loss %.3f)\n', ...
            n, pars.v1PopulationDirections(n, 1), pars.v1PopulationDirections(n, 2), ...
            rB_te(n), rA_te(n), dLoss(n));
end

% ---------------------------------------------------------------- save
outFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat');
v1WeightsMagnoA = WA;
save(outFile, 'v1WeightsMagnoA', '-v7.3');
fprintf('\nSaved population-A weights to %s\n', outFile);

fprintf(['\nNext: set pars.rgc.mtMix = struct(''weightsA'', WA, ''alpha'', 0.1, ''delay'', 0)\n' ...
         'and calibrate alpha against Maunsell et al. (1990) via the knockouts.\n']);

% =====================================================================
function share = localParasolShare(W, maskP)
    aw = abs(W);
    share = sum(aw(:, maskP), 2) ./ max(sum(aw, 2), eps);
end

function [rA, rB] = localFitQuality(pars, stim, WA, WB)
    parsLeg = pars; parsLeg.rgc.enabled = 0;
    target = shModelV1Linear(stim, parsLeg) ./ pars.scaleFactors.v1Linear;
    S = shClassV1Basis(stim, pars);
    predA = S * WA';
    predB = S * WB';
    n = size(target, 2);
    rA = zeros(n, 1); rB = zeros(n, 1);
    for i = 1:n
        rA(i) = localCorr(target(:, i), predA(:, i));
        rB(i) = localCorr(target(:, i), predB(:, i));
    end
end

function r = localCorr(a, b)
    c = corrcoef(a, b);
    r = c(1, 2);
end

function localReport(label, r)
    s = sort(r);
    fprintf('  %-22s %8.3f %8.3f %8.3f %8.3f\n', label, ...
            median(r), min(r), prctileLocal(r, 25), mean(s(1:min(5, numel(s)))));
end

function v = prctileLocal(x, p)
    % avoid a Statistics Toolbox dependency
    xs = sort(x(:));
    n = numel(xs);
    if n == 1, v = xs; return; end
    idx = 1 + (p / 100) * (n - 1);
    lo = floor(idx); hi = ceil(idx); w = idx - lo;
    v = (1 - w) * xs(lo) + w * xs(hi);
end
