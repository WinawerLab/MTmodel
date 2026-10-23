% runMotionLetterLesionPhase2  Phase 2 optic-neuritis lesions on motion-defined letters.
%
% Runs one seeded mkMotionLetter trial under the healthy lagged midget/parasol
% preset and each Phase 2 lesion from validateSHFigs9to14_lesions.m (uniform
% amplitude/delay, parasol-only amplitude, midget-only amplitude, ON-only delay).
% Optionally includes the headline Phase 2b stochastic delay lesion (spatially heterogeneous delay).
%
% For every condition the script computes MT and V1 letter-vs-background d' and
% plots comparison figures with the healthy baseline on the same axes / color
% limits as the lesioned runs. A stimulus movie plays first (PLAY_STIM_MOVIE).
%
% Edit CONFIG below, then:
%   run explore/runMotionLetterLesionPhase2.m
%
% Optional overrides (set in base workspace before running):
%   OUT_DIR         folder for exported PNGs (default explore/_figs/motionLetter_phase2)
%   ONLY_LESIONS    cellstr subset, e.g. {'healthy','delay_uniform','delay_random'}
%   INCLUDE_PHASE2B true/false — include stochastic delay_random (default true)
%
% Stimulus and model defaults live in pars/motionLetterPars.m. Override below
% only what this script needs (letter, speed, output size, mtMix, seed).

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
% Overrides for pars/motionLetterPars.m (defaults: letter C, 5 deg/s, dotSize 3, …)
ML_OVERRIDES = { ...
    'letter',    'V', ...
    'speedDegS', 2, ...          % clinical low band (0.4 px/frame); see MODEL_AND_LESIONS §1
    'outSz',     [128 128 120], ...
    'seed',      1, ...
    'mtMix',     true ...
};

% FIELD_SIZE  optional override for stochastic impairment maps; if omitted,
%             sized automatically from the padded stimulus (see below).
INCLUDE_PHASE2B = true;       % delay_random stochastic lesion
PLAY_STIM_MOVIE = true;       % play stimulus movie before running the model
MAX_MOVIE_FRAMES = [];        % [] = all frames; set e.g. 120 to cap preview length
%% ========================================================================

if exist('OUT_DIR', 'var') && ~isempty(OUT_DIR)
    figDir = OUT_DIR;
else
    figDir = fullfile(repoRoot, 'explore', '_figs', 'motionLetter_phase2_1degpersec');
end
if ~exist(figDir, 'dir'), mkdir(figDir); end
if exist('INCLUDE_PHASE2B', 'var')
    includePhase2b = logical(INCLUDE_PHASE2B);
else
    includePhase2b = INCLUDE_PHASE2B;
end

[cfg, parsBase, stimSz, stimArgs] = motionLetterPars(ML_OVERRIDES{:});
units = cfg.units;

% Padded input size (shGetDims adds RF support); stochastic maps must cover this.
fieldSize = max(stimSz(1:2));
if exist('FIELD_SIZE', 'var') && ~isempty(FIELD_SIZE)
    fieldSize = max(fieldSize, FIELD_SIZE);
end

fprintf('=== Motion letter Phase 2 lesions ===\n');
fprintf('Letter %s   %.1f deg/s   stim [%d %d %d]   field %d   mtMix %d   seed %d\n', ...
    cfg.letter, cfg.speedDegS, stimSz(1), stimSz(2), stimSz(3), fieldSize, ...
    isfield(parsBase.rgc, 'mtMix') && ~isempty(parsBase.rgc.mtMix), cfg.seed);
fprintf('Results -> %s\n\n', figDir);

rng(cfg.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfg.letter, stimArgs{:});
fprintf('Stimulus: %.4f px/frame, letter %d px (%.1f deg), dot %d px, font %s\n\n', ...
    stimInfo.dotSpeedPxPerFrame, stimInfo.letterSizePx, stimInfo.letterSizeDeg, ...
    stimInfo.dotSize, stimInfo.fontName);

if exist('PLAY_STIM_MOVIE', 'var') && PLAY_STIM_MOVIE
    nPlay = size(stim, 3);
    if exist('MAX_MOVIE_FRAMES', 'var') && ~isempty(MAX_MOVIE_FRAMES)
        nPlay = min(nPlay, MAX_MOVIE_FRAMES);
    end
    fprintf('Playing stimulus movie (%d frames @ %.1f fps)...\n', ...
        nPlay, units.framesPerSecond);
    figure('Name', sprintf('Motion letter ''%s'' @ %.1g deg/s', cfg.letter, cfg.speedDegS), ...
        'Color', [0.5 0.5 0.5]);
    playStimMovie(stim(:, :, 1:nPlay), 1 / units.framesPerSecond, [0 1]);
    fprintf('\n');
end

%% Lesion catalogue (pars/lesionCatalog.m + pars/lesionPars.m)
lesions = lesionCatalog('motionLetterPhase2', 'fieldSize', fieldSize);
if ~includePhase2b
    lesions = lesions(~strcmp({lesions.name}, 'delay_random'));
end

if exist('ONLY_LESIONS', 'var') && ~isempty(ONLY_LESIONS)
    lesions = lesions(ismember({lesions.name}, ONLY_LESIONS));
end

%% Run all conditions
nCond = numel(lesions);
results = repmat(struct(), nCond, 1);

for iC = 1:nCond
    L = lesions(iC);
    fprintf('[%d/%d] %s — %s\n', iC, nCond, L.name, L.description);
    pars = L.applyFn(parsBase);
    pars = lesionCropToStim(pars, stimSz(1), stimSz(2));

    tic;
    [popMt, indMt] = shModel(stim, pars, 'mtPattern');
    [popV1, indV1] = shModel(stim, pars, 'v1Complex');
    fprintf('        V1+MT in %.1f s\n', toc);

    met = motionLetterMetrics(popMt, indMt, popV1, indV1, pars, stimInfo);
    fprintf('        d'' : MT %+.3f   V1 %+.3f\n', met.dMt, met.dV1);

    results(iC).lesion = L;
    results(iC).metrics = met;
end

baseIdx = find(strcmp({lesions.name}, 'healthy'), 1);
if isempty(baseIdx), baseIdx = 1; end
base = results(baseIdx).metrics;

%% Figure 1 — d' bar chart (healthy vs lesions)
figD = figure('Color', 'w', 'Position', [80 520 900 420], ...
    'Name', 'Motion letter d'' — Phase 2 lesions');
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

labels = {lesions.shortLabel};
dMt = arrayfun(@(r) r.metrics.dMt, results);
dV1 = arrayfun(@(r) r.metrics.dV1, results);

nexttile;
bar(dMt, 0.7, 'FaceColor', [0.25 0.45 0.85]);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
yline(base.dMt, 'k--', 'LineWidth', 1.2);
grid on; ylabel('d'''); title('MT opponent');
xtickangle(30);
subtitle(sprintf('Baseline MT d'' = %+.2f', base.dMt));

nexttile;
bar(dV1, 0.7, 'FaceColor', [0.85 0.45 0.25]);
set(gca, 'XTick', 1:numel(labels), 'XTickLabel', labels);
yline(base.dV1, 'k--', 'LineWidth', 1.2);
grid on; ylabel('d'''); title('V1 opponent');
xtickangle(30);
subtitle(sprintf('Baseline V1 d'' = %+.2f', base.dV1));

sgtitle(sprintf('Letter ''%s'' @ %.1f deg/s — Phase 2 lesion comparison', cfg.letter, cfg.speedDegS));
exportgraphics(figD, fullfile(figDir, 'motionLetter_phase2_dprime.png'), 'Resolution', 130);

%% Figure 2 — MT opponent maps (shared color limits from healthy)
climMt = max(abs(base.mtOpp(:)));
if climMt <= 0, climMt = 1; end

nCols = min(3, nCond);
nRows = ceil(nCond / nCols);
figMaps = figure('Color', 'w', 'Position', [80 60 360*nCols 320*nRows], ...
    'Name', 'MT opponent maps — Phase 2');
tiledlayout(nRows, nCols, 'Padding', 'compact', 'TileSpacing', 'compact');

for iC = 1:nCond
    nexttile;
    imagesc(results(iC).metrics.mtOpp, [-climMt climMt]);
    axis image off; colormap(gca, parula); colorbar;
    hold on;
    contour(results(iC).metrics.mask, [0.5 0.5], 'w', 'LineWidth', 0.8);
    hold off;
    title(sprintf('%s\nMT d''=%+.2f', lesions(iC).shortLabel, results(iC).metrics.dMt), ...
        'FontSize', 10);
end
sgtitle(sprintf('MT opponent (time avg, right−left) — shared limits ±%.3g', climMt));
exportgraphics(figMaps, fullfile(figDir, 'motionLetter_phase2_mtOpponentGrid.png'), 'Resolution', 130);

%% Figure 3 — each lesion overlaid on baseline (difference + side-by-side for key lesions)
figOverlay = figure('Color', 'w', 'Position', [100 100 1100 720], ...
    'Name', 'Baseline vs lesion — MT opponent');
overlayLesions = setdiff({lesions.name}, {'healthy'}, 'stable');
nOverlay = numel(overlayLesions);
if nOverlay > 0
    nOC = min(3, nOverlay);
    nOR = ceil(nOverlay / nOC);
    tiledlayout(nOR, nOC, 'Padding', 'compact', 'TileSpacing', 'compact');
    for iO = 1:nOverlay
        idx = find(strcmp({lesions.name}, overlayLesions{iO}), 1);
        nexttile;
        diffMap = results(idx).metrics.mtOpp - base.mtOpp;
        climD = max(abs(diffMap(:)));
        if climD <= 0, climD = 1; end
        imagesc(diffMap, [-climD climD]);
        axis image off; colormap(gca, redbluecmap); colorbar;
        hold on;
        contour(base.mask, [0.5 0.5], 'k', 'LineWidth', 0.6);
        hold off;
        title(sprintf('%s − healthy\nΔd''=%+.2f', lesions(idx).shortLabel, ...
            results(idx).metrics.dMt - base.dMt), 'FontSize', 10);
    end
    sgtitle('MT opponent change vs healthy baseline');
    exportgraphics(figOverlay, fullfile(figDir, 'motionLetter_phase2_mtOpponentDelta.png'), 'Resolution', 130);
else
    close(figOverlay);
end

%% Console summary table
fprintf('\n--- Summary (letter vs background d'') ---\n');
fprintf('%-18s  %8s  %8s  %8s\n', 'Condition', 'MT d''', 'V1 d''', 'ΔMT d''');
for iC = 1:nCond
    fprintf('%-18s  %8.3f  %8.3f  %8.3f\n', lesions(iC).name, ...
        results(iC).metrics.dMt, results(iC).metrics.dV1, ...
        results(iC).metrics.dMt - base.dMt);
end

fprintf('\nWrote figures to:\n  %s\n', figDir);

function cmap = redbluecmap
% Simple diverging red-blue for difference maps (no toolbox dependency).
n = 256;
half = floor(n / 2);
r = [linspace(0, 1, half), ones(1, n - half)];
g = [linspace(0, 1, half), linspace(1, 0, n - half)];
b = [ones(1, half), linspace(1, 0, n - half)];
cmap = [r(:), g(:), b(:)];
end
