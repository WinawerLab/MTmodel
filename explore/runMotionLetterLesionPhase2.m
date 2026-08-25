% runMotionLetterLesionPhase2  Phase 2 optic-neuritis lesions on motion-defined letters.
%
% Runs one seeded mkMotionLetter trial under the healthy lagged midget/parasol
% preset and each Phase 2 lesion from validateSHFigs9to14_lesions.m (uniform
% amplitude/delay, parasol-only amplitude, midget-only amplitude, ON-only delay).
% Optionally includes the headline Phase 2b stochastic delay lesion (spatially heterogeneous delay).
%
% For every condition the script computes MT and V1 letter-vs-background d' and
% plots comparison figures with the healthy baseline on the same axes / color
% limits as the lesioned runs.
%
% Edit CONFIG below, then:
%   run explore/runMotionLetterLesionPhase2.m
%
% Optional overrides (set in base workspace before running):
%   OUT_DIR         folder for exported PNGs (default explore/_figs/motionLetter_phase2)
%   ONLY_LESIONS    cellstr subset, e.g. {'healthy','delay_uniform','delay_random'}
%   INCLUDE_PHASE2B true/false — include stochastic delay_random (default true)
%
% Speed: default 2 deg/s matches the lab's typical supra-threshold trials.
% Set SPEED_DEG_S = 0.04 in CONFIG to probe near healthy participant threshold.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER      = 'H';
SPEED_DEG_S = 1;              % lab default (supra-threshold max ~2 deg/s)
                              % use 0.04 to probe near healthy threshold
OUT_SZ      = [128 128 120];  % model output [Y X T]; stim Y/X may be larger (padding)
SEED        = 1;
% FIELD_SIZE  optional override for stochastic impairment maps; if omitted,
%             sized automatically from the padded stimulus (see below).
INCLUDE_PHASE2B = true;       % delay_random stochastic lesion

STIM_ARGS = { ...
    'dotContrast', 1.0, ...
    'drawBackgroundDots', true, ...
    'fCovered', 0.3, ...
    'dotShape', 'square', ...
    'seed', SEED ...
};
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

units = shModelUnits();
parsBase = setupLaggedBiological(repoRoot);

stimSz = shGetDims(parsBase, 'mtPattern', OUT_SZ);
% Padded input size (shGetDims adds RF support); stochastic maps must cover this.
fieldSize = max(stimSz(1:2));
if exist('FIELD_SIZE', 'var') && ~isempty(FIELD_SIZE)
    fieldSize = max(fieldSize, FIELD_SIZE);
end
letterPx = round(0.6 * min(stimSz(1:2)));
STIM_ARGS = [STIM_ARGS, { ...
    'referenceDisplaySize', [], ...
    'ppd', units.pixelsPerDegree, ...
    'frameRate', units.framesPerSecond, ...
    'dotSpeedDegS', SPEED_DEG_S, ...
    'letterSizePx', letterPx, ...
    'dotSize', 3}];

fprintf('=== Motion letter Phase 2 lesions ===\n');
fprintf('Letter %s   %.1f deg/s   stim [%d %d %d]   field %d   seed %d\n', ...
    LETTER, SPEED_DEG_S, stimSz(1), stimSz(2), stimSz(3), fieldSize, SEED);
fprintf('Results -> %s\n\n', figDir);

rng(SEED);
[stim, stimInfo] = mkMotionLetter(stimSz, LETTER, STIM_ARGS{:});
fprintf('Stimulus: %.4f px/frame, letter %d px (%.1f deg), font %s\n\n', ...
    stimInfo.dotSpeedPxPerFrame, stimInfo.letterSizePx, stimInfo.letterSizeDeg, stimInfo.fontName);

%% Lesion catalogue (Phase 2 + optional Phase 2b headline)
lesions = struct( ...
    'name', {'healthy', 'amplitude_uniform', 'delay_uniform', ...
             'amplitude_parasol', 'amplitude_midget', 'delay_ON_only'}, ...
    'shortLabel', {'Healthy', 'Amp uniform', 'Delay uniform', ...
                   'Amp parasol', 'Amp midget', 'Delay ON'}, ...
    'description', { ...
        'Healthy baseline (no lesion)', ...
        'All classes, gain 0.5 (50% amplitude reduction)', ...
        'All classes, +2 frame conduction delay', ...
        'Parasol only, gain 0.3 (70% reduction; midgets spared)', ...
        'Midget only, gain 0.3 (70% reduction; parasols spared)', ...
        'ON pathway only, +1 frame delay (OFF spared)'}, ...
    'applyFn', {@(p) p, @lesionAmplitudeUniform, @lesionDelayUniform, ...
                @lesionAmplitudeParasol, @lesionAmplitudeMidget, @lesionDelayONOnly});

if includePhase2b
    lesions(end+1) = struct( ...
        'name', 'delay_random', ...
        'shortLabel', 'Delay random', ...
        'description', 'Stochastic spatial delay {0–3} frames (Phase 2b)', ...
        'applyFn', @(p) lesionDelayStochastic(p, fieldSize));
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
    pars = cropImpairmentToStim(pars, stimSz(1), stimSz(2));

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

sgtitle(sprintf('Letter ''%s'' @ %.1f deg/s — Phase 2 lesion comparison', LETTER, SPEED_DEG_S));
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

%% --- setup and lesion helpers (Phase 2 from validateSHFigs9to14_lesions.m) ---

function pars = setupLaggedBiological(repoRoot)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'custom';
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';
weightsFile = fullfile(repoRoot, 'pars', ...
    'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
if ~exist(weightsFile, 'file')
    error('Cached weights not found. Run validateSHFigs9to14.m first (Phase 1).');
end
c = load(weightsFile);
pars.rgc.v1Weights = c.v1Weights;
end

function pars = lesionAmplitudeUniform(parsBase)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    pars.rgc.classes(i).gain = 0.5;
end
end

function pars = lesionDelayUniform(parsBase)
pars = parsBase;
delayFrames = 2;
for i = 1:numel(pars.rgc.classes)
    origKernel = pars.rgc.classes(i).temporalKernel;
    pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); origKernel];
end
end

function pars = lesionAmplitudeParasol(parsBase)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).name, 'parasol', 'IgnoreCase', true)
        pars.rgc.classes(i).gain = 0.3;
    end
end
end

function pars = lesionAmplitudeMidget(parsBase)
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).name, 'midget', 'IgnoreCase', true)
        pars.rgc.classes(i).gain = 0.3;
    end
end
end

function pars = lesionDelayONOnly(parsBase)
pars = parsBase;
delayFrames = 1;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).rectify, 'on', 'IgnoreCase', true)
        origKernel = pars.rgc.classes(i).temporalKernel;
        pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); origKernel];
    end
end
end

function pars = lesionDelayStochastic(parsBase, fieldSize)
pars = parsBase;
rng(43);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = randi([0 3], fieldSize, fieldSize);
end

function parsOut = cropImpairmentToStim(pars, Y, X)
parsOut = pars;
if ~isfield(pars.rgc, 'impairmentEnabled') || pars.rgc.impairmentEnabled ~= 1
    return;
end
if isfield(pars.rgc, 'impairmentAmplitudeFieldFull') && ~isempty(pars.rgc.impairmentAmplitudeFieldFull)
    parsOut.rgc.impairmentAmplitudeMap = localCenterCrop( ...
        pars.rgc.impairmentAmplitudeFieldFull, Y, X);
end
if isfield(pars.rgc, 'impairmentDelayFieldFull') && ~isempty(pars.rgc.impairmentDelayFieldFull)
    parsOut.rgc.impairmentDelayMap = localCenterCrop( ...
        pars.rgc.impairmentDelayFieldFull, Y, X);
end
end

function out = localCenterCrop(F, Y, X)
if size(F, 1) < Y || size(F, 2) < X
    error('runMotionLetterLesionPhase2:fieldTooSmall', ...
        'Lesion field [%d %d] smaller than stimulus [%d %d]. Increase FIELD_SIZE.', ...
        size(F, 1), size(F, 2), Y, X);
end
offY = floor((size(F, 1) - Y) / 2);
offX = floor((size(F, 2) - X) / 2);
out = F(offY+1:offY+Y, offX+1:offX+X);
end

function cmap = redbluecmap
% Simple diverging red-blue for difference maps (no toolbox dependency).
n = 256;
half = floor(n / 2);
r = [linspace(0, 1, half), ones(1, n - half)];
g = [linspace(0, 1, half), linspace(1, 0, n - half)];
b = [ones(1, half), linspace(1, 0, n - half)];
cmap = [r(:), g(:), b(:)];
end
