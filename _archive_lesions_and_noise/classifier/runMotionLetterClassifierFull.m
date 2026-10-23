% runMotionLetterClassifierFull  Full letter-identity pass (template match).
%
% 10 Sloan letters x 16 random-dot seeds x 2 speeds, healthy vs amp-parasol.
% Templates are the Sloan masks (alphabet knowledge). The classifier never
% sees a mask at test time. Same movie is used for healthy and lesioned;
% only pars.rgc.classes(:).gain changes.
%
% Speeds are classified separately (locked plan: 1 and 5 deg/s = 0.2 and 1 px/frame).
% Chance = 10%.
%
% Edit CONFIG, then:
%   run classifier/runMotionLetterClassifierFull.m
%
% First run is long (~10 letters x 16 seeds x 2 speeds x 2 conditions = 640
% MT forwards). Re-runs skip cached trials. Maps -> classifier/_cache/full/
% figures -> classifier/_figs/full/.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTERS     = 'CDHKNORSVZ';    % full Sloan set from the experiment
SEEDS       = 1:16;
SPEEDS_DEG_S = [1 5];          % clinical low band + MT slow unit (1 px/frame)
OUT_SZ      = [128 128 120];   % same as the pilot / Phase 2
FORCE_RECOMPUTE = false;
INCLUDE_SAME_DRIFT = true;     % 1 seed per letter at 1 deg/s
SAME_DRIFT_SEED = 1;

CACHE_DIR = fullfile(repoRoot, 'classifier', '_cache', 'full');
FIG_DIR   = fullfile(repoRoot, 'classifier', '_figs', 'full');
%% ========================================================================

if ~exist(CACHE_DIR, 'dir'), mkdir(CACHE_DIR); end
if ~exist(FIG_DIR, 'dir'), mkdir(FIG_DIR); end

condNames  = {'healthy', 'amp_parasol'};
condLabels = {'Healthy', 'Amp parasol'};
nCond = numel(condNames);

parsHealthy = motionLetterModelPars('lagged', true);
parsLesion  = lesionApply(parsHealthy, 'amplitude_parasol');
parsByCond  = {parsHealthy, parsLesion};

[cfg, ~, stimSz, ~] = motionLetterPars('outSz', OUT_SZ, 'speedDegS', SPEEDS_DEG_S(1));
letterPx = cfg.letterPx;

nLetters = numel(LETTERS);
nSeeds = numel(SEEDS);
nSpeeds = numel(SPEEDS_DEG_S);
nTrials = nLetters * nSeeds * nSpeeds * nCond;

fprintf('=== Motion-letter classifier full pass ===\n');
fprintf('letters %s (%d)   seeds %d   speeds %s deg/s\n', ...
    LETTERS, nLetters, nSeeds, mat2str(SPEEDS_DEG_S));
fprintf('conditions: %s vs %s\n', condLabels{1}, condLabels{2});
fprintf('stim [%d %d %d]   letter %d px   %d trials   lagged preset\n', ...
    stimSz(1), stimSz(2), stimSz(3), letterPx, nTrials);
fprintf('cache -> %s\n\n', CACHE_DIR);

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

%% Templates (shape only; speed and dots do not matter)
[~, ~, ~, stimArgsT] = motionLetterPars('outSz', OUT_SZ, 'speedDegS', SPEEDS_DEG_S(1));
templates = localLetterTemplates(stimSz, LETTERS, stimArgsT, OUT_SZ(1), OUT_SZ(2));
save(fullfile(CACHE_DIR, 'templates.mat'), 'templates', 'LETTERS', 'stimSz', ...
    'letterPx', 'SPEEDS_DEG_S', 'OUT_SZ');

%% Run / load every (letter, seed, speed, condition)
blank = struct('letter', ' ', 'seed', 0, 'speedDegS', 0, ...
    'condition', '', 'mtOpp', [], 'dMt', NaN);
trials = repmat(blank, nTrials, 1);

iTrial = 0;
nRan = 0;
nCached = 0;
tAll = tic;

for iSp = 1:nSpeeds
    speedDegS = SPEEDS_DEG_S(iSp);
    [~, ~, ~, stimArgs] = motionLetterPars('outSz', OUT_SZ, 'speedDegS', speedDegS);
    for iL = 1:nLetters
        letter = LETTERS(iL);
        for iS = 1:nSeeds
            seed = SEEDS(iS);
            cacheFiles = cell(1, nCond);
            haveAll = true;
            for iC = 1:nCond
                cacheFiles{iC} = localTrialFile(CACHE_DIR, letter, seed, ...
                    speedDegS, condNames{iC});
                if FORCE_RECOMPUTE || exist(cacheFiles{iC}, 'file') ~= 2
                    haveAll = false;
                end
            end

            stim = [];
            info = [];
            if ~haveAll
                [stim, info] = mkMotionLetter(stimSz, letter, stimArgs{:}, ...
                    'seed', seed, 'backgroundVelocityScale', -1);
            end

            for iC = 1:nCond
                iTrial = iTrial + 1;
                trials(iTrial).letter = letter;
                trials(iTrial).seed = seed;
                trials(iTrial).speedDegS = speedDegS;
                trials(iTrial).condition = condNames{iC};

                if ~FORCE_RECOMPUTE && exist(cacheFiles{iC}, 'file') == 2
                    S = load(cacheFiles{iC});
                    trials(iTrial).mtOpp = S.mtOpp;
                    trials(iTrial).dMt = S.dMt;
                    nCached = nCached + 1;
                    fprintf('[%d/%d] %s seed %02d  %5.0f deg/s  %-12s cache  d''=%+.3f\n', ...
                        iTrial, nTrials, letter, seed, speedDegS, ...
                        condNames{iC}, S.dMt);
                    continue;
                end

                rec = localRunOnStim(stim, info, parsByCond{iC});
                trials(iTrial).mtOpp = rec.mtOpp;
                trials(iTrial).dMt = rec.dMt;
                localSaveTrial(cacheFiles{iC}, rec, letter, seed, ...
                    condNames{iC}, speedDegS);
                nRan = nRan + 1;
                fprintf(['[%d/%d] %s seed %02d  %5.0f deg/s  %-12s ran ' ...
                    '%.1f s  d''=%+.3f\n'], iTrial, nTrials, letter, seed, ...
                    speedDegS, condNames{iC}, rec.elapsedSec, rec.dMt);
            end
        end
    end
end

[mapY, mapX] = size(trials(1).mtOpp);
if size(templates, 1) ~= mapY || size(templates, 2) ~= mapX
    templates = localLetterTemplates(stimSz, LETTERS, stimArgsT, mapY, mapX);
end

%% Classify per speed x condition
chance = 1 / nLetters;
clsTab = repmat(struct('speedDegS', 0, 'condition', '', 'label', '', ...
    'acc', NaN, 'nCorrect', 0, 'n', 0, 'meanD', NaN, 'C', [], ...
    'pred', [], 'trueLab', []), nSpeeds * nCond, 1);
k = 0;
for iSp = 1:nSpeeds
    for iC = 1:nCond
        k = k + 1;
        hit = [trials.speedDegS] == SPEEDS_DEG_S(iSp) ...
            & strcmp({trials.condition}, condNames{iC});
        maps = cat(3, trials(hit).mtOpp);
        trueLab = [trials(hit).letter]';
        out = motionLetterTemplateClassify(maps, templates, LETTERS);
        nCorrect = sum(out.pred == trueLab);
        clsTab(k).speedDegS = SPEEDS_DEG_S(iSp);
        clsTab(k).condition = condNames{iC};
        clsTab(k).label = condLabels{iC};
        clsTab(k).n = numel(trueLab);
        clsTab(k).nCorrect = nCorrect;
        clsTab(k).acc = nCorrect / numel(trueLab);
        clsTab(k).meanD = mean([trials(hit).dMt]);
        clsTab(k).C = localConfusion(trueLab, out.pred, LETTERS);
        clsTab(k).pred = out.pred;
        clsTab(k).trueLab = trueLab;
        clsTab(k).scores = out.scores;
    end
end

fprintf('\n--- Template match (chance %.1f%%) ---\n', 100 * chance);
fprintf('%-8s  %-12s  %8s  %8s  %8s\n', 'Speed', 'Condition', 'Acc', 'n', 'mean d''');
for k = 1:numel(clsTab)
    fprintf('%5.0f deg/s  %-12s  %6.1f%%  %3d/%3d  %8.3f\n', ...
        clsTab(k).speedDegS, clsTab(k).label, 100 * clsTab(k).acc, ...
        clsTab(k).nCorrect, clsTab(k).n, clsTab(k).meanD);
end

fprintf('\nAccuracy drop (healthy minus amp parasol), same movies:\n');
for iSp = 1:nSpeeds
    h = clsTab([clsTab.speedDegS] == SPEEDS_DEG_S(iSp) ...
        & strcmp({clsTab.condition}, 'healthy'));
    L = clsTab([clsTab.speedDegS] == SPEEDS_DEG_S(iSp) ...
        & strcmp({clsTab.condition}, 'amp_parasol'));
    fprintf('  %5.0f deg/s   %.1f%% -> %.1f%%   Delta = %+.1f pp\n', ...
        SPEEDS_DEG_S(iSp), 100 * h.acc, 100 * L.acc, 100 * (L.acc - h.acc));
end

fprintf('\nPer letter, %.0f deg/s:\n', SPEEDS_DEG_S(1));
localPrintPerLetter(clsTab, SPEEDS_DEG_S(1), LETTERS);
fprintf('\nPer letter, %.0f deg/s:\n', SPEEDS_DEG_S(end));
localPrintPerLetter(clsTab, SPEEDS_DEG_S(end), LETTERS);

%% Same-drift control (no relative motion)
if INCLUDE_SAME_DRIFT
    speedCtl = 1;
    [~, ~, ~, stimArgs] = motionLetterPars('outSz', OUT_SZ, 'speedDegS', speedCtl);
    ctlMaps = zeros(mapY, mapX, nLetters);
    ctlD = zeros(1, nLetters);
    fprintf('\n--- Same-drift control at %.0f deg/s ---\n', speedCtl);
    for iL = 1:nLetters
        letter = LETTERS(iL);
        cacheFile = localTrialFile(CACHE_DIR, letter, SAME_DRIFT_SEED, ...
            speedCtl, 'samedrift');
        if ~FORCE_RECOMPUTE && exist(cacheFile, 'file') == 2
            S = load(cacheFile);
            ctlMaps(:, :, iL) = S.mtOpp;
            ctlD(iL) = S.dMt;
            fprintf('  %s  cache  d''=%+.3f\n', letter, S.dMt);
        else
            rec = localRunTrial(stimSz, letter, SAME_DRIFT_SEED, stimArgs, ...
                parsHealthy, +1);
            ctlMaps(:, :, iL) = rec.mtOpp;
            ctlD(iL) = rec.dMt;
            localSaveTrial(cacheFile, rec, letter, SAME_DRIFT_SEED, ...
                'samedrift', speedCtl);
            fprintf('  %s  ran %.1f s  d''=%+.3f\n', letter, rec.elapsedSec, rec.dMt);
        end
    end
    ctlCls = motionLetterTemplateClassify(ctlMaps, templates, LETTERS);
    ctlTrue = LETTERS(:);
    ctlAcc = mean(ctlCls.pred == ctlTrue);
    fprintf('same-drift accuracy  %d / %d  =  %.1f%%   (expect ~%.0f%% chance)\n', ...
        sum(ctlCls.pred == ctlTrue), nLetters, 100 * ctlAcc, 100 * chance);
    fprintf('same-drift mean d''  %+.3f\n', mean(ctlD));
end

%% Figures
accMat = zeros(nSpeeds, nCond);
dMat = zeros(nSpeeds, nCond);
for iSp = 1:nSpeeds
    for iC = 1:nCond
        row = clsTab([clsTab.speedDegS] == SPEEDS_DEG_S(iSp) ...
            & strcmp({clsTab.condition}, condNames{iC}));
        accMat(iSp, iC) = row.acc;
        dMat(iSp, iC) = row.meanD;
    end
end

fig1 = figure('Color', 'w', 'Position', [60 420 900 380], ...
    'Name', 'Full pass — accuracy');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
b = bar(accMat * 100, 0.7);
b(1).FaceColor = [0.25 0.45 0.85];
b(2).FaceColor = [0.85 0.40 0.25];
set(gca, 'XTick', 1:nSpeeds, 'XTickLabel', ...
    arrayfun(@(s) sprintf('%.0f deg/s', s), SPEEDS_DEG_S, 'UniformOutput', false));
ylim([0 100]);
yline(100 * chance, 'k--', 'LineWidth', 1);
ylabel('Accuracy (%)');
legend(condLabels, 'Location', 'south');
title(sprintf('Template match  (chance %.0f%%)', 100 * chance));
grid on;

nexttile;
b = bar(dMat, 0.7);
b(1).FaceColor = [0.25 0.45 0.85];
b(2).FaceColor = [0.85 0.40 0.25];
set(gca, 'XTick', 1:nSpeeds, 'XTickLabel', ...
    arrayfun(@(s) sprintf('%.0f deg/s', s), SPEEDS_DEG_S, 'UniformOutput', false));
ylabel('Mean MT d''');
legend(condLabels, 'Location', 'south');
title('Letter vs background d'' (uses true mask)');
grid on;
sgtitle('Healthy vs amp parasol, same movies');
exportgraphics(fig1, fullfile(FIG_DIR, 'full_accuracy.png'), 'Resolution', 130);

fig2 = figure('Color', 'w', 'Position', [60 40 1100 900], ...
    'Name', 'Full pass — confusion');
tiledlayout(nSpeeds, nCond, 'Padding', 'compact', 'TileSpacing', 'compact');
for iSp = 1:nSpeeds
    for iC = 1:nCond
        nexttile;
        row = clsTab([clsTab.speedDegS] == SPEEDS_DEG_S(iSp) ...
            & strcmp({clsTab.condition}, condNames{iC}));
        localShowConfusion(row.C, LETTERS);
        title(sprintf('%s   %.0f deg/s   %.0f%%', ...
            row.label, row.speedDegS, 100 * row.acc));
    end
end
sgtitle('Rows = true, columns = predicted');
exportgraphics(fig2, fullfile(FIG_DIR, 'full_confusion.png'), 'Resolution', 130);

showLetters = 'CHOKN';
fig3 = figure('Color', 'w', 'Position', [40 40 1400 560], ...
    'Name', sprintf('Full pass — example maps %.0f deg/s', SPEEDS_DEG_S(1)));
tiledlayout(2, numel(showLetters), 'Padding', 'compact', 'TileSpacing', 'compact');
for iC = 1:nCond
    for iL = 1:numel(showLetters)
        nexttile;
        idx = find([trials.letter] == showLetters(iL) ...
            & [trials.seed] == SEEDS(1) ...
            & [trials.speedDegS] == SPEEDS_DEG_S(1) ...
            & strcmp({trials.condition}, condNames{iC}), 1);
        tIdx = find(LETTERS == showLetters(iL), 1);
        localShowMap(trials(idx).mtOpp, templates(:, :, tIdx));
        title(sprintf('%s  %s\nd'' %+.2f', showLetters(iL), condLabels{iC}, ...
            trials(idx).dMt), 'FontSize', 10);
    end
end
sgtitle(sprintf(['MT opponent, %.0f deg/s, seed %d. White = true letter ' ...
    '(classifier does not see it).'], SPEEDS_DEG_S(1), SEEDS(1)));
exportgraphics(fig3, fullfile(FIG_DIR, 'full_exampleMaps.png'), 'Resolution', 130);

resultFile = fullfile(CACHE_DIR, 'full_results.mat');
save(resultFile, 'trials', 'clsTab', 'templates', 'LETTERS', 'SEEDS', ...
    'SPEEDS_DEG_S', 'OUT_SZ', 'stimSz', 'letterPx', 'chance', 'accMat', 'dMat');

fprintf('\nCached %d, ran %d new, elapsed %.1f min.\n', ...
    nCached, nRan, toc(tAll) / 60);
fprintf('Results ->\n  %s\n  %s\n', resultFile, FIG_DIR);

%% ---- helpers -----------------------------------------------------------
function templates = localLetterTemplates(stimSz, letters, stimArgs, mapY, mapX)
maskSz = [stimSz(1) stimSz(2) 1];
nL = numel(letters);
templates = false(mapY, mapX, nL);
for iL = 1:nL
    [~, info] = mkMotionLetter(maskSz, letters(iL), stimArgs{:}, 'seed', 0);
    templates(:, :, iL) = motionLetterMaskOnMap(info.binaryMask, mapY, mapX);
end
end

function rec = localRunOnStim(stim, info, pars)
tic;
[popMt, indMt] = shModel(stim, pars, 'mtPattern');
met = motionLetterMetrics(popMt, indMt, [], [], pars, info);
rec = struct();
rec.mtOpp = met.mtOpp;
rec.mask = met.mask;
rec.dMt = met.dMt;
rec.mtNote = met.mtNote;
rec.elapsedSec = toc;
end

function rec = localRunTrial(stimSz, letter, seed, stimArgs, pars, bgScale)
tic;
[stim, info] = mkMotionLetter(stimSz, letter, stimArgs{:}, ...
    'seed', seed, 'backgroundVelocityScale', bgScale);
[popMt, indMt] = shModel(stim, pars, 'mtPattern');
met = motionLetterMetrics(popMt, indMt, [], [], pars, info);
rec = struct();
rec.mtOpp = met.mtOpp;
rec.mask = met.mask;
rec.dMt = met.dMt;
rec.mtNote = met.mtNote;
rec.elapsedSec = toc;
end

function localSaveTrial(cacheFile, rec, letter, seed, condition, speedDegS)
mtOpp = rec.mtOpp;
mask = rec.mask;
dMt = rec.dMt;
mtNote = rec.mtNote;
save(cacheFile, 'mtOpp', 'mask', 'dMt', 'mtNote', 'letter', 'seed', ...
    'condition', 'speedDegS');
end

function f = localTrialFile(cacheDir, letter, seed, speedDegS, condition)
f = fullfile(cacheDir, sprintf('%s_seed%02d_spd%g_%s.mat', ...
    letter, seed, speedDegS, condition));
end

function C = localConfusion(trueLab, pred, letters)
nL = numel(letters);
C = zeros(nL);
for i = 1:numel(trueLab)
    r = find(letters == trueLab(i), 1);
    c = find(letters == pred(i), 1);
    C(r, c) = C(r, c) + 1;
end
end

function localShowConfusion(C, letters)
imagesc(C);
axis image;
nL = numel(letters);
set(gca, 'XTick', 1:nL, 'XTickLabel', num2cell(letters), ...
    'YTick', 1:nL, 'YTickLabel', num2cell(letters));
xlabel('Predicted'); ylabel('True');
colormap(gca, parula);
colorbar;
for iR = 1:nL
    for iC = 1:nL
        if C(iR, iC) == 0, continue; end
        text(iC, iR, sprintf('%d', C(iR, iC)), ...
            'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8);
    end
end
end

function localShowMap(map, mask)
imagesc(map); axis image off; colormap(gca, parula); colorbar;
hold on; contour(mask, [0.5 0.5], 'w', 'LineWidth', 1.1); hold off;
end

function localPrintPerLetter(clsTab, speedDegS, letters)
h = clsTab([clsTab.speedDegS] == speedDegS & strcmp({clsTab.condition}, 'healthy'));
L = clsTab([clsTab.speedDegS] == speedDegS & strcmp({clsTab.condition}, 'amp_parasol'));
fprintf('  letter  healthy  lesion\n');
for iL = 1:numel(letters)
    nH = sum(h.trueLab == letters(iL));
    nL = sum(L.trueLab == letters(iL));
    cH = sum(h.trueLab == letters(iL) & h.pred == letters(iL));
    cL = sum(L.trueLab == letters(iL) & L.pred == letters(iL));
    fprintf('    %s     %2d/%2d    %2d/%2d\n', letters(iL), cH, nH, cL, nL);
end
end
