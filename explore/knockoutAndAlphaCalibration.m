% knockoutAndAlphaCalibration
%
% Criterion 2 of docs/MODEL_AND_LESIONS.md 4.4, plus the alpha calibration.
%
% Two questions:
%
%   (1) KNOCKOUT CHECK. Does the parasol-masked MT population reproduce
%       Maunsell, Nealey & DePriest (1990)? Their result, from LGN layer blocks:
%         - magnocellular block: MT responses "consistently reduced", the
%           reduction "almost always pronounced and often complete";
%         - parvocellular block: "rarely produced striking changes", "typically
%           had very little effect", but unequivocal contributions for a
%           MINORITY of MT responses;
%         - combined block: responses "essentially eliminated".
%       The pre-existing (mixed) model gets this backwards -- midget knockout
%       collapses MT while parasol knockout leaves it intact. That is the whole
%       reason for item 1.
%
%   (2) ALPHA CALIBRATION. alpha is the single new free parameter: the weight on
%       the slow, mixed-M/P stream relayed via V2 (shModelV1ComplexForMt). It has
%       a monotone effect on how much midget knockout matters, so it is set by
%       bisection against the Maunsell criterion above, not explored.
%
% Knockouts are applied at the RGC stage (class gain -> 0), so they affect BOTH
% streams, as a retinal lesion would. Note that midget knockout has exactly zero
% effect on stream A by construction (its midget weights are exact zeros), so all
% of the midget-knockout effect is carried by alpha -- which is what makes alpha
% calibratable against Maunsell.
%
% Dot stimuli are explicitly seeded (docs/TODO.md known problems: the earlier
% lesion scripts did not seed, confounding lesion effects with dot-sample noise).

% Self-locating script
clear; clc;
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

DIR_PTS  = 21;    % direction-tuning samples (matches quantitativeAnalysisFigs9to14)
COH_PTS  = 8;     % coherence samples
DOT_SEED = 1234;  % all conditions see the same dots

fprintf('=== Knockout check + alpha calibration ===\n\n');

% ---------------------------------------------------------------- setup
pars = shPars;
pars.rgc.enabled     = 1;
pars.rgc.mode        = 'custom';
pars.rgc.classes     = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine     = 'weights';
pars.rgc.classesMode = 'custom';

WB = getfield(load(fullfile(repoRoot, 'pars', ...
     'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat')), 'v1Weights');
WA = getfield(load(fullfile(repoRoot, 'pars', ...
     'shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat')), 'v1WeightsMagnoA');
pars.rgc.v1Weights = WB;

nMT = size(pars.mtPopulationVelocities, 1);

% Architecture list. NaN alpha = the pre-existing mixed model (no mtMix at all).
alphas    = [0 0.05 0.10 0.20 0.35 0.50];
archAlpha = [NaN, alphas];
archNames = [{'mixed_old'}, arrayfun(@(a) sprintf('alpha=%.2f', a), alphas, ...
                                     'UniformOutput', false)];
kos = {'none', 'parasol', 'midget', 'both'};

fprintf('MT population: %d neurons\n', nMT);
fprintf('Architectures: %d (pre-existing mixed model + %d alphas)\n', numel(archNames), numel(alphas));
fprintf('Knockouts: %s\n\n', strjoin(kos, ', '));

figure('Visible', 'off');   % tune helpers plot; keep it off-screen

% ---------------------------------------------------------------- grid
R = cell(numel(archNames), numel(kos));
tGrid = tic;
for ia = 1:numel(archNames)
    for ik = 1:numel(kos)
        p = localArch(pars, archAlpha(ia), WA);
        p = localKnockout(p, kos{ik});

        [yDir, popPeak] = localDirTuning(p, [0 .35], DIR_PTS);
        [cohPeak, cohSlope] = localCoherence(p, COH_PTS, DOT_SEED);

        [prefResp, prefIdx] = max(yDir);
        n = numel(yDir);
        antiResp = yDir(mod(prefIdx - 1 + round(n/2), n) + 1);

        R{ia, ik} = struct( ...
            'dir_peak',  prefResp, ...
            'dir_dsi',   abs(prefResp - antiResp) / (prefResp + antiResp + eps), ...
            'coh_peak',  cohPeak, ...
            'coh_slope', cohSlope, ...
            'popPeak',   popPeak);
    end
    fprintf('  %-12s done (%.0fs elapsed)\n', archNames{ia}, toc(tGrid));
end
fprintf('\nGrid complete in %.0f s.\n\n', toc(tGrid));

% ---------------------------------------------------------------- part 1
fprintf('=== (1) KNOCKOUT CHECK ===\n');
fprintf('Each knockout as %% change from that architecture''s own intact model.\n');
fprintf('Maunsell: parasol(M) block large and near-universal; midget(P) block small,\n');
fprintf('detectable in a minority; combined block essentially eliminates the response.\n\n');
fprintf('%-11s %-8s %10s %10s %10s %11s %9s\n', ...
        'arch', 'knockout', 'dir_peak%', 'dir_dsi%', 'coh_peak%', 'pop med|%|', 'pop>20%');
for ia = 1:numel(archNames)
    base = R{ia, 1};
    for ik = 2:numel(kos)
        c = R{ia, ik};
        popPct = 100 * (c.popPeak - base.popPeak) ./ max(base.popPeak, eps);
        fprintf('%-11s %-8s %10.1f %10.1f %10.1f %11.1f %8.0f%%\n', ...
                archNames{ia}, kos{ik}, ...
                100*(c.dir_peak - base.dir_peak)/max(base.dir_peak, eps), ...
                100*(c.dir_dsi  - base.dir_dsi )/max(base.dir_dsi,  eps), ...
                100*(c.coh_peak - base.coh_peak)/max(base.coh_peak, eps), ...
                median(abs(popPct)), 100*mean(abs(popPct) > 20));
    end
end

% ---------------------------------------------------------------- part 2
fprintf('\n=== (2) ALPHA CALIBRATION ===\n');
fprintf('Target: midget (P) knockout SMALL, parasol (M) knockout LARGE.\n\n');
fprintf('%-7s %13s %13s %13s %13s %13s\n', 'alpha', ...
        'P-KO dirpeak%', 'P-KO popmed%', 'P-KO frac>20%', 'M-KO dirpeak%', 'M-KO popmed%');
for ia = 2:numel(archNames)
    base = R{ia, 1};
    pk   = R{ia, 2};   % parasol knockout  (the M block)
    mk   = R{ia, 3};   % midget  knockout  (the P block)
    mkPct = 100 * (mk.popPeak - base.popPeak) ./ max(base.popPeak, eps);
    pkPct = 100 * (pk.popPeak - base.popPeak) ./ max(base.popPeak, eps);
    fprintf('%-7.2f %13.1f %13.1f %12.0f%% %13.1f %13.1f\n', archAlpha(ia), ...
            100*(mk.dir_peak - base.dir_peak)/max(base.dir_peak, eps), ...
            median(abs(mkPct)), 100*mean(abs(mkPct) > 20), ...
            100*(pk.dir_peak - base.dir_peak)/max(base.dir_peak, eps), ...
            median(abs(pkPct)));
end
fprintf('\n(columns 2-4 are the P/midget block; columns 5-6 the M/parasol block)\n');

outMat = fullfile(repoRoot, 'explore', '_figs', 'knockoutAlphaResults.mat');
save(outMat, 'R', 'alphas', 'archAlpha', 'archNames', 'kos');
fprintf('\nSaved raw results to %s\n', outMat);

% =====================================================================
function p = localArch(pars, alphaVal, WA)
    p = pars;
    if isnan(alphaVal)
        return;   % pre-existing model: no mtMix, mixed weights throughout
    end
    p.rgc.mtMix = struct('weightsA', WA, 'alpha', alphaVal, 'delay', 0);
end

function p = localKnockout(p, which)
    switch which
        case 'none',    return;
        case 'parasol', pat = '^parasol';
        case 'midget',  pat = '^midget';
        case 'both',    pat = '^(parasol|midget)';
    end
    for c = 1:numel(p.rgc.classes)
        if ~isempty(regexpi(p.rgc.classes(c).name, pat, 'once'))
            p.rgc.classes(c).gain = 0;
        end
    end
end

% Direction tuning for one test neuron AND the whole MT population, in one pass.
% Mirrors shTuneGratingDirection (same stimulus size, sf/tf defaults) without its
% per-iteration plotting.
function [yDir, popPeak] = localDirTuning(pars, neuron, nPts)
    pg = mt2sin(neuron);
    stimSz = shGetDims(pars, 'mtPattern', [1 1 31]);
    xDir = linspace(0, 2*pi, nPts);
    yDir = zeros(1, nPts);
    popAll = [];
    for i = 1:nPts
        s = mkSin(stimSz, xDir(i), pg(2), pg(3), 1);
        [pop, ind, res] = shModel(s, pars, 'mtPattern', neuron);
        yDir(i) = mean(shGetNeuron(res, ind));
        popAll(:, i) = mean(shGetNeuron(pop, ind), 2); %#ok<AGROW>
    end
    yDir = yDir(1:end-1);           % drop duplicate 360deg == 0deg sample
    popPeak = max(popAll, [], 2);   % each MT neuron's peak over directions
end

function [cohPeak, cohSlope] = localCoherence(pars, nPts, seed)
    rng(seed);   % same dot sample for every condition
    [xCoh, yCoh] = shTuneDotCoherence(pars, [0 1], 'mtPattern', nPts, 71);
    cohPeak = max(yCoh);
    p = polyfit(xCoh, yCoh, 1);
    cohSlope = p(1);
end
