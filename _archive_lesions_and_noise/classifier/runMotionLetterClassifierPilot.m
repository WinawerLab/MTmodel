% runMotionLetterClassifierPilot  Healthy letter-identity pilot (template match).
%
% Builds 4 letters x 8 random-dot seeds at 1 deg/s through the lagged
% midget/parasol front-end, caches the time-averaged MT opponent maps, then
% guesses letter identity by correlating each map with the four Sloan masks.
% No mask is given to the classifier at test time — that is the difference
% from d'. Chance is 25%.
%
% Optional same-drift controls (no relative motion) should fall to chance.
%
% Edit CONFIG, then:
%   run classifier/runMotionLetterClassifierPilot.m
%
% Re-runs skip cached trials unless FORCE_RECOMPUTE is true. Maps are written
% under classifier/_cache/ (gitignored); figures under classifier/_figs/.
% For a faster first look, set OUT_SZ = [96 96 90].

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTERS     = 'CHON';          % 4-letter Sloan subset for the pilot
SEEDS       = 1:8;             % independent random-dot movies per letter
SPEED_DEG_S = 1;               % matches the Phase 2 speed that produces a letter
OUT_SZ      = [128 128 120];   % model output [Y X T]; same as Phase 2
FORCE_RECOMPUTE = false;
INCLUDE_SAME_DRIFT = true;     % one extra movie per letter, no relative motion
SAME_DRIFT_SEED = 1;

CACHE_DIR = fullfile(repoRoot, 'classifier', '_cache', 'pilot');
FIG_DIR   = fullfile(repoRoot, 'classifier', '_figs', 'pilot');
%% ========================================================================

if ~exist(CACHE_DIR, 'dir'), mkdir(CACHE_DIR); end
if ~exist(FIG_DIR, 'dir'), mkdir(FIG_DIR); end

[cfg, pars, stimSz, stimArgs] = motionLetterPars( ...
    'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ);
letterPx = cfg.letterPx;

fprintf('=== Motion-letter classifier pilot ===\n');
fprintf('letters %s   %d seeds   %.1f deg/s   out %s\n', ...
    LETTERS, numel(SEEDS), cfg.speedDegS, mat2str(cfg.outSz));
fprintf('stim [%d %d %d]   letter %d px   lagged preset\n', ...
    stimSz(1), stimSz(2), stimSz(3), letterPx);
fprintf('cache -> %s\n\n', CACHE_DIR);

% 1 deg/s (0.2 px/frame) is below MT's slowest moving shell (5 deg/s = 1 px/frame);
% the metrics helper would warn on every trial. Hush it for this script only.
warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

%% Templates (letter shape only; independent of dots / seed / speed)
templates = localLetterTemplates(stimSz, LETTERS, stimArgs, OUT_SZ(1), OUT_SZ(2));
save(fullfile(CACHE_DIR, 'templates.mat'), 'templates', 'LETTERS', 'stimSz', ...
    'letterPx', 'SPEED_DEG_S', cfg.speedDegS, 'OUT_SZ', cfg.outSz);

%% Healthy trials
nLetters = numel(LETTERS);
nSeeds = numel(SEEDS);
nTrials = nLetters * nSeeds;
trials = repmat(struct('letter', ' ', 'seed', 0, 'condition', '', ...
    'mtOpp', [], 'mask', [], 'dMt', NaN, 'cacheFile', ''), nTrials, 1);

iTrial = 0;
nRan = 0;
nCached = 0;
for iL = 1:nLetters
    for iS = 1:nSeeds
        iTrial = iTrial + 1;
        letter = LETTERS(iL);
        seed = SEEDS(iS);
        cacheFile = localTrialFile(CACHE_DIR, letter, seed, 'healthy');
        trials(iTrial).letter = letter;
        trials(iTrial).seed = seed;
        trials(iTrial).condition = 'healthy';
        trials(iTrial).cacheFile = cacheFile;

        if ~FORCE_RECOMPUTE && exist(cacheFile, 'file')
            S = load(cacheFile);
            trials(iTrial).mtOpp = S.mtOpp;
            trials(iTrial).mask = S.mask;
            trials(iTrial).dMt = S.dMt;
            nCached = nCached + 1;
            fprintf('[%d/%d] %s seed %d  healthy  (cache)  d'' = %+.3f\n', ...
                iTrial, nTrials, letter, seed, S.dMt);
            continue;
        end

        rec = localRunTrial(stimSz, letter, seed, stimArgs, pars, -1);
        trials(iTrial).mtOpp = rec.mtOpp;
        trials(iTrial).mask = rec.mask;
        trials(iTrial).dMt = rec.dMt;
        localSaveTrial(cacheFile, rec, letter, seed, 'healthy', SPEED_DEG_S);
        nRan = nRan + 1;
        fprintf('[%d/%d] %s seed %d  healthy  (ran %.1f s)  d'' = %+.3f\n', ...
            iTrial, nTrials, letter, seed, rec.elapsedSec, rec.dMt);
    end
end

%% Classify healthy maps
[mapY, mapX] = size(trials(1).mtOpp);
if size(templates, 1) ~= mapY || size(templates, 2) ~= mapX
    templates = localLetterTemplates(stimSz, LETTERS, stimArgs, mapY, mapX);
end
maps = cat(3, trials.mtOpp);
trueLab = [trials.letter]';
cls = motionLetterTemplateClassify(maps, templates, LETTERS);
correct = cls.pred == trueLab;
nCorrect = sum(correct);
acc = nCorrect / nTrials;
chance = 1 / nLetters;

fprintf('\n--- Healthy template match ---\n');
fprintf('accuracy  %d / %d  =  %.1f%%   (chance %.1f%%)\n', ...
    nCorrect, nTrials, 100 * acc, 100 * chance);
fprintf('mean MT d'' (uses true mask, not the classifier)  %+.3f\n', ...
    mean([trials.dMt]));

fprintf('\nPer letter:\n');
for iL = 1:nLetters
    hit = trueLab == LETTERS(iL);
    fprintf('  %s   %d / %d   d'' mean %+.3f\n', LETTERS(iL), ...
        sum(correct(hit)), sum(hit), mean([trials(hit).dMt]));
end

C = localConfusion(trueLab, cls.pred, LETTERS);
fprintf('\nConfusion (rows = true, cols = predicted)  %s\n', LETTERS);
disp(C);

%% Same-drift control
if INCLUDE_SAME_DRIFT
    nCtl = nLetters;
    ctl = repmat(struct('letter', ' ', 'seed', 0, 'mtOpp', [], 'dMt', NaN), nCtl, 1);
    fprintf('\n--- Same-drift control (no relative motion) ---\n');
    for iL = 1:nLetters
        letter = LETTERS(iL);
        cacheFile = localTrialFile(CACHE_DIR, letter, SAME_DRIFT_SEED, 'samedrift');
        ctl(iL).letter = letter;
        ctl(iL).seed = SAME_DRIFT_SEED;
        if ~FORCE_RECOMPUTE && exist(cacheFile, 'file')
            S = load(cacheFile);
            ctl(iL).mtOpp = S.mtOpp;
            ctl(iL).dMt = S.dMt;
            fprintf('  %s  (cache)  d'' = %+.3f\n', letter, S.dMt);
        else
            rec = localRunTrial(stimSz, letter, SAME_DRIFT_SEED, stimArgs, pars, +1);
            ctl(iL).mtOpp = rec.mtOpp;
            ctl(iL).dMt = rec.dMt;
            localSaveTrial(cacheFile, rec, letter, SAME_DRIFT_SEED, 'samedrift', SPEED_DEG_S);
            fprintf('  %s  (ran %.1f s)  d'' = %+.3f\n', letter, rec.elapsedSec, rec.dMt);
        end
    end
    ctlCls = motionLetterTemplateClassify(cat(3, ctl.mtOpp), templates, LETTERS);
    ctlTrue = [ctl.letter]';
    ctlAcc = mean(ctlCls.pred == ctlTrue);
    fprintf('same-drift accuracy  %d / %d  =  %.1f%%   (expect ~chance)\n', ...
        sum(ctlCls.pred == ctlTrue), nCtl, 100 * ctlAcc);
end

%% Figures
fig1 = figure('Color', 'w', 'Position', [80 420 720 420], ...
    'Name', 'Classifier pilot — confusion');
imagesc(C);
axis image;
set(gca, 'XTick', 1:nLetters, 'XTickLabel', num2cell(LETTERS), ...
    'YTick', 1:nLetters, 'YTickLabel', num2cell(LETTERS));
xlabel('Predicted'); ylabel('True');
colormap(gca, parula);
colorbar;
title(sprintf('Healthy template match  %.0f%%  (chance %.0f%%)', ...
    100 * acc, 100 * chance));
for iR = 1:nLetters
    for iC = 1:nLetters
        text(iC, iR, sprintf('%d', C(iR, iC)), 'HorizontalAlignment', 'center', ...
            'Color', 'w', 'FontWeight', 'bold');
    end
end
exportgraphics(fig1, fullfile(FIG_DIR, 'pilot_confusion.png'), 'Resolution', 130);

fig2 = figure('Color', 'w', 'Position', [80 40 1100 720], ...
    'Name', 'Classifier pilot — example maps');
tiledlayout(nLetters, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
showSeeds = unique([SEEDS(1), SEEDS(min(2, nSeeds)), SEEDS(end)]);
showSeeds = showSeeds(1:min(3, numel(showSeeds)));
for iL = 1:nLetters
    for iShow = 1:numel(showSeeds)
        nexttile;
        idx = find([trials.letter] == LETTERS(iL) & [trials.seed] == showSeeds(iShow), 1);
        localShowMap(trials(idx).mtOpp, templates(:, :, iL));
        if cls.pred(idx) == trials(idx).letter, mark = 'ok'; else, mark = 'X'; end
        title(sprintf('true %s  pred %s  %s\nseed %d  d'' %+.2f', ...
            trials(idx).letter, cls.pred(idx), mark, trials(idx).seed, trials(idx).dMt), ...
            'FontSize', 9);
    end
end
sgtitle(sprintf(['MT opponent maps vs true-letter contour. ' ...
    'Classifier never sees the contour; it picks the best of {%s}.'], LETTERS));
exportgraphics(fig2, fullfile(FIG_DIR, 'pilot_exampleMaps.png'), 'Resolution', 130);

resultFile = fullfile(CACHE_DIR, 'pilot_results.mat');
save(resultFile, 'trials', 'cls', 'trueLab', 'acc', 'chance', 'C', ...
    'LETTERS', 'SEEDS', 'SPEED_DEG_S', cfg.speedDegS, 'OUT_SZ', cfg.outSz, 'stimSz', 'letterPx');

fprintf('\nCached %d trials, ran %d new. Results ->\n  %s\n  %s\n', ...
    nCached, nRan, resultFile, FIG_DIR);
fprintf(['\nHow to read this: >>25%% means identity survives in the map. ' ...
    'Near 25%% means d'' can still find the region while the shape does not ' ...
    'name a letter. Then we change features, not lesions.\n']);

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
rec.letterSizePx = info.letterSizePx;
rec.letterSizeDeg = info.letterSizeDeg;
rec.fontName = info.fontName;
rec.dotSpeedPxPerFrame = info.dotSpeedPxPerFrame;
end

function localSaveTrial(cacheFile, rec, letter, seed, condition, speedDegS)
mtOpp = rec.mtOpp;
mask = rec.mask;
dMt = rec.dMt;
mtNote = rec.mtNote;
save(cacheFile, 'mtOpp', 'mask', 'dMt', 'mtNote', 'letter', 'seed', ...
    'condition', 'speedDegS');
end

function f = localTrialFile(cacheDir, letter, seed, condition)
f = fullfile(cacheDir, sprintf('%s_seed%02d_%s.mat', letter, seed, condition));
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

function localShowMap(map, mask)
imagesc(map); axis image off; colormap(gca, parula); colorbar;
hold on; contour(mask, [0.5 0.5], 'w', 'LineWidth', 1.1); hold off;
end
