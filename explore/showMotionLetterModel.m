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
% RGC_PRESET = 'derivative' | 'midgetParasolLagged' (alias: lagged biological preset)
% Model and stimulus defaults: pars/motionLetterPars.m (edit DEFAULTS there).
% Script-specific overrides below.
%
% UNITS. The stimulus is built in the MODEL's units (shModelUnits: 10 px/deg,
% 50 frames/sec), NOT the booth's ~100 px/deg. Converting a deg/s speed with
% booth geometry makes it ~10x too slow in the units the MT filters live in.
%
% SPEED. Set SPEED_DEG_S from the literature band you want to probe:
%   0.19 - 3 deg/s   the clinically interesting low-speed band, and the range
%                    the Fig-10 "lowpass" neuron spans (0.0375-0.6 px/frame)
%   5 - 50 deg/s     the "highpass" neuron's range (1-10 px/frame)
% MT is tuned to speeds {0, 1, 6} px/frame = {0, 5, 30} deg/s, so the clinical
% band straddles MT's slowest non-zero tuned speed rather than sitting wholly
% below it. V1 tiles four shells from 0.22 to 1.63 px/frame (1.1-8.2 deg/s),
% which reaches lower. Expect weak MT opponency at the bottom of the clinical
% band -- that is a real property of the model, not a bug, and it is the tension
% recorded in docs/TODO.md 2.
%
% SPATIAL SCALE. At 10 px/deg a clinically sized letter (168 arcmin = 2.8 deg)
% is 28 pixels, which is usable. LETTER_SIZE_PX below still sets the letter in
% model pixels and the script reports the implied angular size; setting a real
% angular size instead is open work (docs/TODO.md 6).

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG (edit here) =============================
PRESET     = 'experiment';        % 'quick' | 'experiment'
RGC_PRESET = 'derivative';        % 'derivative' | 'midgetParasolLagged' | 'lagged'
MT_MIX     = true;

% Overrides passed to pars/motionLetterPars.m (empty = use file defaults only)
ML_OVERRIDES = { ...
    'letter', 'H', ...
    'speedDegS', 5, ...          % 1 px/frame; clinical band is 0.19–3 deg/s (see header)
    'rgcPreset', RGC_PRESET, ...
    'mtMix', MT_MIX, ...
    'seed', 1 ...
};

STAGE_MT = 'mtPattern';
STAGE_V1 = 'v1Complex';

PLAY_STIM_MOVIE = true;
MAX_MOVIE_FRAMES = 120;
SHOW_BOOTH_PREVIEW = false;
%% ========================================================================

switch lower(PRESET)
    case 'experiment'
        ML_OVERRIDES = [ML_OVERRIDES, {'outSz', [256 256 160]}];  % 3.2 s at 50 fps
    otherwise
        ML_OVERRIDES = [ML_OVERRIDES, {'outSz', [96 96 90]}];
end

[cfg, pars, stimSz, stimArgs] = motionLetterPars(ML_OVERRIDES{:});
nFrames = stimSz(3);
units = cfg.units;
LETTER = cfg.letter;
SPEED_DEG_S = cfg.speedDegS;
SEED = cfg.seed;
LETTER_SIZE_PX = cfg.letterPx;

fprintf('=== Motion letter → model ===\n');
fprintf('Letter: %s   preset: %s   RGC: %s   mtMix: %d   stim size: [%d %d %d]   outSz: %s\n', ...
    LETTER, PRESET, cfg.rgcPreset, ...
    isfield(pars.rgc, 'mtMix') && ~isempty(pars.rgc.mtMix), ...
    stimSz(1), stimSz(2), stimSz(3), mat2str(cfg.outSz));
fprintf('Model units: %.2f px/deg, %.1f frames/s, 1 px/frame = %.0f deg/s\n', ...
    units.pixelsPerDegree, units.framesPerSecond, units.degPerSecPerPixelPerFrame);

fprintf('\n[1/3] Generating stimulus...\n');
tic;
[stim, stimInfo] = mkMotionLetter(stimSz, LETTER, stimArgs{:});
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
fprintf('\nEdit CONFIG at top of %s, or change defaults in pars/motionLetterPars.m\n', mfilename);
