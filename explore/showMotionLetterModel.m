% showMotionLetterModel  One motion-letter trial through V1/MT with figures.
%
% Generates a mkMotionLetter stimulus, runs shModel, and plots:
%   0. Stimulus movies: booth resolution vs model field (side-by-side)
%   1. Still frames: booth vs scaled vs letter mask
%   2. MT population time courses (center RF)
%   3. MT neurons × time heatmap
%   4. MT spatial response maps (mean over time) for right/left tuned units
%   5. V1 spatial response maps for matched direction tunings
%   6. Stimulus vs MT snapshot
%
% Edit the CONFIG block below, then:
%   run explore/showMotionLetterModel.m
%
% Tip: start with PRESET = 'quick'. Use 'experiment' once figures look sensible.
% RGC_PRESET 'derivative' = exact legacy SH; 'midgetParasolLagged' = biological
% midget/parasol with lagged copies (~0.985 healthy V1 fidelity).

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG (edit here) =============================
PRESET     = 'experiment';        % 'quick' | 'experiment'
RGC_PRESET = 'derivative';        % 'derivative' | 'midgetParasolLagged'
LETTER   = 'H';
STAGE_MT = 'mtPattern';
STAGE_V1 = 'v1Complex';
SEED     = 1;

% Desired model *output* spatial size [Y X T] (shGetDims adds convolution padding)
OUT_SZ   = [96 96 90];       % quick default; increase for finer maps (slower)
PLAYBACK_FPS = 60;           % stimulus movie playback rate
PLAY_STIM_MOVIE = true;      % Figure 0 side-by-side movie (after static figures)
MAX_MOVIE_FRAMES = 120;      % cap preview length (120 = 2 s @ 60 Hz)

% mkMotionLetter args (experiment defaults; overridden by PRESET)
STIM_ARGS = { ...
    'dotSpeedDegS', 1, ...
    'letterSizeArcmin', 168, ...
    'dotContrast', 1.0, ...
    'drawBackgroundDots', true, ...
    'frameRate', 60, ...
    'screenWidthCm', 39, ...
    'viewDistCm', 175, ...
    'seed', SEED ...
};
%% ========================================================================

switch lower(PRESET)
    case 'experiment'
        OUT_SZ = [384 512 240];   % ~4 s, ~40%% booth scale (4:3 aspect); clearer letter than 128²
        STIM_ARGS = [STIM_ARGS, {'screenWidthCm', 39}];
    otherwise
        % keep OUT_SZ above
end

pars = shPars;
pars = localConfigureRgcPreset(pars, RGC_PRESET, repoRoot);
stimSz = shGetDims(pars, STAGE_MT, OUT_SZ);
nFrames = stimSz(3);
STIM_ARGS = [STIM_ARGS, {'seed', SEED}];

fprintf('=== Motion letter → model ===\n');
fprintf('Letter: %s   preset: %s   RGC: %s   stim size: [%d %d %d]   MT output: [%s]\n', ...
    LETTER, PRESET, RGC_PRESET, stimSz(1), stimSz(2), stimSz(3), num2str(OUT_SZ));

fprintf('\n[1/3] Generating stimulus...\n');
tic;
% Full booth movie for visual preview (matches Experiment.m display)
boothSz = [960 1280 stimSz(3)];
[stimPreview, ~] = mkMotionLetter(boothSz, LETTER, STIM_ARGS{:});
% Scaled/padded to model input size (built at booth, then uniformly resized)
[stim, stimInfo] = mkMotionLetter(stimSz, LETTER, STIM_ARGS{:});
fprintf('      done (%.1f s).  letterContrast = %.3f\n', toc, stimInfo.letterContrast);
fprintf('      booth gen [%d %d] -> model field [%d %d], fieldScale = %.3f\n', ...
    960, 1280, stimInfo.outputSize(1), stimInfo.outputSize(2), stimInfo.fieldScale);
fprintf('      dotSize at model field ~%d px (booth = %d px)\n', ...
    stimInfo.dotSize, stimInfo.dotSizeNominal);

midBooth = round(size(stimPreview, 3) / 2);
midStim  = round(size(stim, 3) / 2);

fprintf('\n[2/3] Running MT (%s)...\n', STAGE_MT);
tic;
[popMt, indMt] = shModel(stim, pars, STAGE_MT);
mtCenter = shGetNeuron(popMt, indMt);
fprintf('      done (%.1f s).  pop %s, center traces %s\n', toc, mat2str(size(popMt)), mat2str(size(mtCenter)));

fprintf('[3/3] Running V1 (%s)...\n', STAGE_V1);
tic;
[popV1, indV1] = shModel(stim, pars, STAGE_V1);
v1Center = shGetNeuron(popV1, indV1);
fprintf('      done (%.1f s).  pop %s, center traces %s\n', toc, mat2str(size(popV1)), mat2str(size(v1Center)));

mtVels = pars.mtPopulationVelocities;
v1Dirs = pars.v1PopulationDirections;
speedPx = stimInfo.dotSpeedPxPerFrame;

[iRight, iLeft] = localBestOpponentIndices(mtVels, speedPx);
[iV1Right, iV1Left] = localBestOpponentIndices(v1Dirs, speedPx);

mtRightMap = squeeze(shGetSubPop(popMt, indMt, iRight));
mtLeftMap  = squeeze(shGetSubPop(popMt, indMt, iLeft));
v1RightMap = squeeze(shGetSubPop(popV1, indV1, iV1Right));
v1LeftMap  = squeeze(shGetSubPop(popV1, indV1, iV1Left));

maskOnMap = localMaskOnGrid(stimInfo.binaryMask, size(mtRightMap, 1), size(mtRightMap, 2));
midMt   = round(size(mtRightMap, 3) / 2);

%% Figure 1 — booth vs scaled still frames + mask
f1 = figure('Name', 'Booth vs model stimulus', 'Color', 'w', 'Position', [40 520 1000 380]);
tiledlayout(1, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
imagesc(stimPreview(:, :, midBooth), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Booth t=%d', midBooth));

nexttile;
imagesc(stim(:, :, midStim), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Model field t=%d', midStim));

nexttile;
imagesc(stimInfo.binaryMask); axis image off; colormap(gca, gray);
title(sprintf('Letter mask (''%s'')', LETTER));

nexttile;
imagesc(stimInfo.binaryMask); axis image off; colormap(gca, gray); hold on;
contour(stimInfo.binaryMask, [0.5 0.5], 'r', 'LineWidth', 1); hold off;
title('Mask on model field');

%% Figure 2 — MT time courses at center
f2 = figure('Name', 'MT population (center RF)', 'Color', 'w', 'Position', [40 80 900 380]);
[sortedMean, ord] = sort(mean(mtCenter, 2), 'descend');
plot(mtCenter(ord, :)', 'LineWidth', 1.1);
grid on; xlabel('time (frames)'); ylabel('response');
title(sprintf('MT at center — sorted by mean (letter ''%s'', speed %.3f px/frame)', LETTER, speedPx));
legStr = arrayfun(@(k) sprintf('[dir=%.2f spd=%.2f]', mtVels(ord(k), 1), mtVels(ord(k), 2)), ...
    1:min(5, numel(ord)), 'UniformOutput', false);
legend(legStr, 'Location', 'eastoutside', 'FontSize', 8);

%% Figure 3 — MT heatmap (tuning × time)
f3 = figure('Name', 'MT heatmap', 'Color', 'w', 'Position', [960 520 520 380]);
imagesc(mtCenter); colormap(gca, hot); colorbar;
set(gca, 'YDir', 'normal');
yticks(1:size(mtVels, 1));
yticklabels(arrayfun(@(k) sprintf('%.0f° %.2f', rad2deg(mtVels(k, 1)), mtVels(k, 2)), ...
    1:size(mtVels, 1), 'UniformOutput', false));
xlabel('time (frames)'); title('MT center response (all tunings)');

%% Figure 4 — MT spatial maps (mean over time)
f4 = figure('Name', 'MT spatial maps', 'Color', 'w', 'Position', [960 80 720 520]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

maps = {mtRightMap, mtLeftMap, mtRightMap - mtLeftMap};
titles = {sprintf('MT right [%.2f, %.2f]', mtVels(iRight, :)), ...
          sprintf('MT left  [%.2f, %.2f]', mtVels(iLeft, :)), ...
          'Right − left (opponent)'};

for k = 1:3
    nexttile;
    img = squeeze(mean(maps{k}, 3));
    imagesc(img); axis image off; colormap(gca, parula); colorbar;
    title(titles{k});
    hold on;
    %contour(maskOnMap, [0.5 0.5], 'w', 'LineWidth', 0.8);
    hold off;
end

nexttile([1 3]);
plot(squeeze(mean(mtRightMap, [1 2])), 'r', 'LineWidth', 1.2); hold on;
plot(squeeze(mean(mtLeftMap, [1 2])), 'b', 'LineWidth', 1.2);
plot(squeeze(mean(mtRightMap - mtLeftMap, [1 2])), 'k--', 'LineWidth', 1.2);
hold off; grid on;
xlabel('time (frames)'); ylabel('spatial mean');
legend('right-tuned', 'left-tuned', 'difference', 'Location', 'best');
title('MT spatial means over time');

%% Figure 5 — V1 spatial maps
f5 = figure('Name', 'V1 spatial maps', 'Color', 'w', 'Position', [200 200 720 420]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

v1Maps = {v1RightMap, v1LeftMap, v1RightMap - v1LeftMap};
v1Titles = {sprintf('V1 right [%.2f, %.2f]', v1Dirs(iV1Right, :)), ...
            sprintf('V1 left  [%.2f, %.2f]', v1Dirs(iV1Left, :)), ...
            'Right − left'};

for k = 1:3
    nexttile;
    imagesc(squeeze(mean(v1Maps{k}, 3))); axis image off; colormap(gca, parula); colorbar;
    title(v1Titles{k});
    hold on;
    %contour(maskOnMap, [0.5 0.5], 'w', 'LineWidth', 0.8);
    hold off;
end

%% Figure 6 — snapshot in time (optional diagnostic)
f6 = figure('Name', 'MT snapshot vs stimulus', 'Color', 'w', 'Position', [200 640 720 300]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
imagesc(stim(:, :, midStim), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Stimulus t=%d', midStim));
nexttile;
imagesc(mtRightMap(:, :, midMt)); axis image off; colormap(gca, hot); colorbar;
title(sprintf('Right-tuned MT t=%d', midMt));
hold on; %contour(maskOnMap, [0.5 0.5], 'w', 'LineWidth', 0.8); hold off;

%% Figure 0 — stimulus movies: booth vs model field (last, so model figures appear first)
if PLAY_STIM_MOVIE
    fprintf('\n[Figure 0] Playing booth vs model-field movies (caxis [0 1])...\n');
    playStimMovieCompare(stimPreview, stim, ...
        'labels', {sprintf('Booth [%d×%d]', size(stimPreview, 1), size(stimPreview, 2)), ...
                   sprintf('Model input [%d×%d]', size(stim, 1), size(stim, 2))}, ...
        'pauseSec', 1 / PLAYBACK_FPS, 'clim', [0 1], ...
        'maxFrames', MAX_MOVIE_FRAMES);
end

fprintf('\nDone. Seven figures:\n');
fprintf('  0 Booth vs model-field movies (side-by-side)\n');
fprintf('  1 Booth vs model still frames + mask\n');
fprintf('  2 MT time courses (center)\n');
fprintf('  3 MT heatmap (tuning x time)\n');
fprintf('  4 MT spatial maps (mean over time) + opponent\n');
fprintf('  5 V1 spatial maps\n');
fprintf('  6 Stimulus vs MT snapshot\n');
fprintf('\nEdit CONFIG at top of %s to change letter, PRESET, RGC_PRESET, or OUT_SZ.\n', mfilename);

%% --- local helpers ---
function pars = localConfigureRgcPreset(pars, preset, repoRoot)
    key = lower(strrep(preset, ' ', ''));
    switch key
        case 'derivative'
            return;
        case {'midgetparasollagged', 'midgetparasoltiled'}
            pars.rgc.enabled = 1;
            pars.rgc.mode = 'custom';
            pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
            pars.rgc.combine = 'weights';
            pars.rgc.classesMode = 'custom';
            pars.rgc.v1Weights = localLoadMidgetParasolLaggedWeights(repoRoot, pars);
        otherwise
            error('showMotionLetterModel:rgcPreset', ...
                'RGC_PRESET must be ''derivative'' or ''midgetParasolLagged'', got ''%s''.', preset);
    end
end

function W = localLoadMidgetParasolLaggedWeights(repoRoot, pars)
    weightsFile = fullfile(repoRoot, 'pars', ...
        'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
    if exist(weightsFile, 'file')
        fprintf('  Loading lagged RGC V1 weights from %s\n', weightsFile);
        cached = load(weightsFile);
        W = cached.v1Weights;
        return;
    end
    fprintf('  No cached lagged weights; fitting (one-time, may take a minute)...\n');
    rng(42);
    dims = shGetDims(pars, 'v1Complex', [5 5 20]);
    W = shFitClassV1Weights(pars, {rand(dims)});
    v1Weights = W; %#ok<NASGU>
    save(weightsFile, 'v1Weights', '-v7.3');
    fprintf('  Saved fitted weights to %s\n', weightsFile);
end

function [iPos, iNeg] = localBestOpponentIndices(vels, speedPx)
    targetPos = [0, speedPx];
    targetNeg = [pi, speedPx];
    dPos = hypot(angleDiff(vels(:, 1), targetPos(1)), vels(:, 2) - targetPos(2));
    dNeg = hypot(angleDiff(vels(:, 1), targetNeg(1)), vels(:, 2) - targetNeg(2));
    [~, iPos] = min(dPos);
    [~, iNeg] = min(dNeg);
end

function d = angleDiff(a, b)
    d = abs(atan2(sin(a - b), cos(a - b)));
end

function mask = localMaskOnGrid(fullMask, outY, outX)
    fullMask = double(fullMask);
    mask = imresize(fullMask, [outY outX], 'nearest');
    mask = mask > 0.5;
end
