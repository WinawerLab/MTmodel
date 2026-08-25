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
% Letter-vs-background d' (MT and V1 opponent maps) is printed and shown in
% figure titles. See explore/motionLetterMetrics.m for the definition.
%
% Edit the CONFIG block below, then:
%   run explore/showMotionLetterModel.m
%
% Tip: start with PRESET = 'quick'. Use 'experiment' once figures look sensible.
% RGC_PRESET 'derivative' = exact legacy SH; 'midgetParasolLagged' = biological
% midget/parasol with lagged copies (~0.985 healthy V1 fidelity).
%
% UNITS. The stimulus is built in the MODEL's units (shModelUnits: 2.33 px/deg,
% 37.2 frames/sec), NOT the booth's ~100 px/deg. Converting a deg/s speed with
% booth geometry makes it ~43x too slow in the units the MT filters live in.
%
% SPEED. Set SPEED_DEG_S in deg/s. In this lab's motion-defined-form task,
% supra-threshold trials are typically <= 2 deg/s; healthy recognition
% thresholds cluster near ~0.04 deg/s. In model units (1 px/frame = 16 deg/s):
%   0.04 deg/s  ~0.0025 px/frame   near healthy threshold (very slow)
%   0.6 - 2 deg/s                 the usual experimental band
% MT is tuned to {0, 1, 6} px/frame = {0, 16, 96} deg/s, so the whole
% experimental band sits BELOW MT's slowest non-zero tuned speed. V1 tiles four
% shells from 0.22 to 1.63 px/frame (3.5-26 deg/s), which reaches lower. Expect
% weak MT opponency at these speeds -- that is a real property of the model,
% not a bug, and it is the tension recorded in docs/TODO.md section 3.
%
% SPATIAL SCALE CAVEAT. At 2.33 px/deg a clinically sized letter (168 arcmin =
% 2.8 deg) is only ~6.5 pixels -- far too small to be a letter. LETTER_SIZE_PX
% below therefore sets the letter in model pixels and the script reports the
% implied angular size, which will be much larger than the booth's. This is the
% known order-of-magnitude spatial-scale offset (docs/TODO.md smaller items).

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

% Dot speed in deg/s. Default matches typical supra-threshold experiment speed.
SPEED_DEG_S = 2;             % lab default (max ~2 deg/s); try 0.04 for threshold

% Letter height in MODEL pixels (see SPATIAL SCALE CAVEAT in the header).
LETTER_SIZE_PX = [];         % [] = 60% of the shorter field dimension

% Desired model *output* spatial size [Y X T] (shGetDims adds convolution padding)
OUT_SZ   = [96 96 90];       % quick default; increase for finer maps (slower)
PLAY_STIM_MOVIE = true;      % Figure 0 side-by-side movie (after static figures)
MAX_MOVIE_FRAMES = 120;      % cap preview length
SHOW_BOOTH_PREVIEW = false;  % booth-resolution preview; costs ~2.3 GB (see below)

% mkMotionLetter args shared by both presets
STIM_ARGS = { ...
    'dotContrast', 1.0, ...
    'drawBackgroundDots', true, ...
    'fCovered', 0.3, ...
    'dotShape', 'square', ...
    'seed', SEED ...
};
%% ========================================================================

switch lower(PRESET)
    case 'experiment'
        OUT_SZ = [256 256 160];   % ~4.3 s at 37.2 fps; finer maps than 96²
    otherwise
        % keep OUT_SZ above
end

pars = shPars;
pars = localConfigureRgcPreset(pars, RGC_PRESET, repoRoot);
stimSz = shGetDims(pars, STAGE_MT, OUT_SZ);
nFrames = stimSz(3);

% Build the stimulus in the MODEL's units, not the booth's.
units = shModelUnits();
if isempty(LETTER_SIZE_PX)
    LETTER_SIZE_PX = round(0.6 * min(stimSz(1:2)));
end
STIM_ARGS = [STIM_ARGS, { ...
    'referenceDisplaySize', [], ...
    'ppd', units.pixelsPerDegree, ...
    'frameRate', units.framesPerSecond, ...
    'dotSpeedDegS', SPEED_DEG_S, ...
    'letterSizePx', LETTER_SIZE_PX, ...
    'dotSize', 3}];

fprintf('=== Motion letter → model ===\n');
fprintf('Letter: %s   preset: %s   RGC: %s   stim size: [%d %d %d]   MT output: [%s]\n', ...
    LETTER, PRESET, RGC_PRESET, stimSz(1), stimSz(2), stimSz(3), num2str(OUT_SZ));
fprintf('Model units: %.2f px/deg, %.1f frames/s, 1 px/frame = %.0f deg/s\n', ...
    units.pixelsPerDegree, units.framesPerSecond, units.degPerSecPerPixelPerFrame);

fprintf('\n[1/3] Generating stimulus...\n');
tic;
[stim, stimInfo] = mkMotionLetter(stimSz, LETTER, STIM_ARGS{:});
fprintf('      done (%.1f s).  letterContrast = %.3f\n', toc, stimInfo.letterContrast);
fprintf('      speed %.2f deg/s = %.4f px/frame;  letter %d px = %.1f deg;  dot %d px\n', ...
    stimInfo.dotSpeedDegS, stimInfo.dotSpeedPxPerFrame, ...
    stimInfo.letterSizePx, stimInfo.letterSizeDeg, stimInfo.dotSize);
fprintf('      duration %.2f s;  font %s\n', ...
    stimSz(3) / units.framesPerSecond, stimInfo.fontName);

% Optional booth-resolution preview. This is a display-referred rendering of
% what the observer saw (booth geometry, 60 Hz) -- an INDEPENDENT dot sample,
% not the model stimulus resized: mkMotionLetter builds directly at each size
% and the field area sets the dot count, so a shared seed does not align the
% draws. Costs ~2.3 GB at [960 1280 x nFrames], hence off by default.
if SHOW_BOOTH_PREVIEW
    boothSz = [960 1280 min(stimSz(3), MAX_MOVIE_FRAMES)];
    stimPreview = mkMotionLetter(boothSz, LETTER, 'seed', SEED, ...
        'dotSpeedDegS', SPEED_DEG_S, 'letterSizeArcmin', 168, 'frameRate', 60);
else
    stimPreview = [];
end

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

met = motionLetterMetrics(popMt, indMt, popV1, indV1, pars, stimInfo);
fprintf('\nOpponent pairs (speed-matched, so "right - left" is direction opponency):\n');
fprintf('  MT: %s\n', met.mtNote);
fprintf('  V1: %s\n', met.v1Note);
fprintf('Letter vs background d'':  MT %+.3f   V1 %+.3f\n', met.dMt, met.dV1);

mtRightMap = squeeze(shGetSubPop(popMt, indMt, met.iMtRight));
mtLeftMap  = squeeze(shGetSubPop(popMt, indMt, met.iMtLeft));
v1RightMap = squeeze(shGetSubPop(popV1, indV1, met.iV1Right));
v1LeftMap  = squeeze(shGetSubPop(popV1, indV1, met.iV1Left));
maskOnMap = met.mask;
midMt   = round(size(mtRightMap, 3) / 2);

mtVels = pars.mtPopulationVelocities;
v1Dirs = pars.v1PopulationDirections;
speedPx = stimInfo.dotSpeedPxPerFrame;
iRight = met.iMtRight;
iLeft = met.iMtLeft;

%% Figure 1 — still frames + mask
f1 = figure('Name', 'Model stimulus', 'Color', 'w', 'Position', [40 520 1000 380]);
tiledlayout(1, 3 + double(~isempty(stimPreview)), 'Padding', 'compact', 'TileSpacing', 'compact');

if ~isempty(stimPreview)
    nexttile;
    imagesc(stimPreview(:, :, midBooth), [0 1]); axis image off; colormap(gca, gray);
    title(sprintf('Booth t=%d (separate sample)', midBooth));
end

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
f4 = figure('Name', sprintf('MT spatial maps (d''=%+.2f)', met.dMt), ...
    'Color', 'w', 'Position', [960 80 720 520]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

maps = {mtRightMap, mtLeftMap, mtRightMap - mtLeftMap};
titles = {sprintf('MT right [%.2f, %.2f]', mtVels(iRight, :)), ...
          sprintf('MT left  [%.2f, %.2f]', mtVels(iLeft, :)), ...
          sprintf('Right − left (d''=%+.2f)', met.dMt)};

for k = 1:3
    nexttile;
    img = squeeze(mean(maps{k}, 3));
    imagesc(img); axis image off; colormap(gca, parula); colorbar;
    title(titles{k});
    hold on;
    contour(maskOnMap, [0.5 0.5], 'w', 'LineWidth', 0.8);
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
f5 = figure('Name', sprintf('V1 spatial maps (d''=%+.2f)', met.dV1), ...
    'Color', 'w', 'Position', [200 200 720 420]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

v1Maps = {v1RightMap, v1LeftMap, v1RightMap - v1LeftMap};
v1Titles = {sprintf('V1 right [%.2f, %.2f]', v1Dirs(met.iV1Right, :)), ...
            sprintf('V1 left  [%.2f, %.2f]', v1Dirs(met.iV1Left, :)), ...
            sprintf('Right − left (d''=%+.2f)', met.dV1)};

for k = 1:3
    nexttile;
    imagesc(squeeze(mean(v1Maps{k}, 3))); axis image off; colormap(gca, parula); colorbar;
    title(v1Titles{k});
    hold on;
    contour(maskOnMap, [0.5 0.5], 'w', 'LineWidth', 0.8);
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

%% Figure 0 — stimulus movie (last, so model figures appear first)
if PLAY_STIM_MOVIE
    fprintf('\n[Figure 0] Playing stimulus movie (caxis [0 1], %.1f fps)...\n', ...
        units.framesPerSecond);
    if isempty(stimPreview)
        figure('Name', 'Model stimulus', 'Color', [0.5 0.5 0.5]);
        playStimMovie(stim(:, :, 1:min(end, MAX_MOVIE_FRAMES)), ...
            1 / units.framesPerSecond, [0 1]);
    else
        playStimMovieCompare(stimPreview, stim, ...
            'labels', {sprintf('Booth [%d×%d] (separate sample)', ...
                        size(stimPreview, 1), size(stimPreview, 2)), ...
                       sprintf('Model input [%d×%d]', size(stim, 1), size(stim, 2))}, ...
            'pauseSec', 1 / units.framesPerSecond, 'clim', [0 1], ...
            'maxFrames', MAX_MOVIE_FRAMES);
    end
end

fprintf('\nDone. Seven figures (MT d''=%+.3f, V1 d''=%+.3f):\n', met.dMt, met.dV1);
fprintf('  0 Stimulus movie\n');
fprintf('  1 Stimulus still frame + mask\n');
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
