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

[cfg, pars, stimSz, stimArgs] = motionLetterPars( ...
    'letter', 'H', 'speedDegS', 1, 'outSz', [96 96 60], 'seed', 1);

fprintf('Overlay check: letter %s, %.1f deg/s, stim [%d %d %d]\n', ...
    cfg.letter, cfg.speedDegS, stimSz(1), stimSz(2), stimSz(3));

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
cleanupObj = onCleanup(@() warning(warnState)); %#ok<NASGU>

[stim, info] = mkMotionLetter(stimSz, cfg.letter, stimArgs{:});

[popMt, indMt] = shModel(stim, pars, 'mtPattern');
met = motionLetterMetrics(popMt, indMt, [], [], pars, info);

oldMask = imresize(double(info.binaryMask), size(met.mtOpp), 'nearest') > 0.5;
newMask = met.mask;

fig = figure('Color', 'w', 'Position', [80 420 820 360]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
imagesc(met.mtOpp); axis image off; colormap(gca, parula); colorbar;
hold on; contour(oldMask, [0.5 0.5], 'w', 'LineWidth', 1); hold off;
title('imresize mask (wrong)');

nexttile;
imagesc(met.mtOpp); axis image off; colormap(gca, parula); colorbar;
hold on; contour(newMask, [0.5 0.5], 'w', 'LineWidth', 1); hold off;
title('center-crop mask (motionLetterMaskOnMap)');

sgtitle(sprintf('Letter ''%s'' @ %.1f deg/s — mask overlay check', ...
    cfg.letter, cfg.speedDegS));
