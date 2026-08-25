% checkMotionLetterMaskOverlay  One-trial check: does the letter contour sit
% on the MT opponent blob?
%
% Left panel = old mapping (imresize the whole stimulus). The contour is too
% small. Right panel = center-crop, which matches how the model drops edges.
%
%   run explore/checkMotionLetterMaskOverlay.m

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

LETTER      = 'H';
SPEED_DEG_S = 1;
OUT_SZ      = [96 96 60];   % small on purpose — this is a geometry check
SEED        = 1;

pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'custom';
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';
w = load(fullfile(repoRoot, 'pars', ...
    'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat'));
pars.rgc.v1Weights = w.v1Weights;

u = shModelUnits();
stimSz = shGetDims(pars, 'mtPattern', OUT_SZ);
letterPx = round(0.6 * min(stimSz(1:2)));

fprintf('Overlay check: letter %s, %.1f deg/s, stim [%d %d %d]\n', ...
    LETTER, SPEED_DEG_S, stimSz(1), stimSz(2), stimSz(3));

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
cleanupObj = onCleanup(@() warning(warnState)); %#ok<NASGU>

[stim, info] = mkMotionLetter(stimSz, LETTER, ...
    'referenceDisplaySize', [], 'ppd', u.pixelsPerDegree, ...
    'frameRate', u.framesPerSecond, 'dotSpeedDegS', SPEED_DEG_S, ...
    'letterSizePx', letterPx, 'dotSize', 3, 'fCovered', 0.3, 'seed', SEED);

[popMt, indMt] = shModel(stim, pars, 'mtPattern');
met = motionLetterMetrics(popMt, indMt, [], [], pars, info);

oldMask = imresize(double(info.binaryMask), size(met.mtOpp), 'nearest') > 0.5;
newMask = met.mask;

fprintf('stim %dx%d  map %dx%d  letter %d px\n', ...
    stimSz(1), stimSz(2), size(met.mtOpp, 1), size(met.mtOpp, 2), letterPx);
fprintf('old (imresize) letter fraction %.2f   new (crop) %.2f\n', ...
    mean(oldMask(:)), mean(newMask(:)));

figure('Color', 'w', 'Name', 'Letter contour vs MT blob', 'Position', [80 400 980 420]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
imagesc(met.mtOpp); axis image off; colormap(gca, parula); colorbar;
hold on; contour(oldMask, [0.5 0.5], 'w', 'LineWidth', 1.2); hold off;
title(sprintf('Old: imresize (too small)\nletter covers %.0f%% of map', 100*mean(oldMask(:))));

nexttile;
imagesc(met.mtOpp); axis image off; colormap(gca, parula); colorbar;
hold on; contour(newMask, [0.5 0.5], 'w', 'LineWidth', 1.2); hold off;
title(sprintf('New: center-crop\nletter covers %.0f%% of map', 100*mean(newMask(:))));

sgtitle(sprintf(['MT opponent, ''%s'' @ %.1f deg/s. ' ...
    'The white contour should sit on the letter blob, with only a blur halo outside it.'], ...
    LETTER, SPEED_DEG_S));
