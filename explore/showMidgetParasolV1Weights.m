% showMidgetParasolV1Weights  Fit and visualize the RGC-class -> V1 weight
% matrix for the biological midget/parasol preset (shRgcClassesMidgetParasol).
%
% Each of the 28 V1 neurons reads out a weighted combination of 40 features
% (4 classes x 10 spatial-derivative read-outs: parasolOn, parasolOff,
% midgetOn, midgetOff). This script fits that weight matrix
% (shFitClassV1Weights) and shows:
%   1. the full 28 x 40 weight matrix, with class-block boundaries marked
%   2. per-class summed weight (28 x 4) -- which class channel dominates
%      each neuron's read-out
%   3. per-class weight energy vs. each neuron's preferred direction angle
%
% Self-locating.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(0);

% Export figures as PNGs (open them to view); the MATLAB MCP tool auto-closes
% on-screen figure windows, so PNGs are the reliable way to inspect results.
outDir = tempdir;

pars = shPars;
parsBio = pars;
parsBio.rgc.classes = shRgcClassesMidgetParasol(parsBio);
parsBio.rgc.combine = 'weights';

classNames = {parsBio.rgc.classes.name};   % {parasolOn, parasolOff, midgetOn, midgetOff}
nClass = numel(classNames);
nBasisPerClass = 10;

% ---------------------------------------------------------------------
% Fit weights on a varied training set (directions/speeds/SF), matching
% tests/testClassPathBiological.m's training set.
% ---------------------------------------------------------------------
dims = shGetDims(pars, 'mtPattern', [1 1 18]);
p1 = v12sin([0 1.0]); p2 = v12sin([pi/3 1.6]); p3 = v12sin([pi 0.8]); p4 = v12sin([-pi/4 1.2]);
trainSet = { mkDots(dims,0,1.0,0.12,1), mkDots(dims,pi/2,0.7,0.12,0.7), ...
             mkSin(dims,0,p1(2),p1(3),1), mkSin(dims,pi/3,p2(2),p2(3),1), ...
             mkSin(dims,pi,p3(2),p3(3),1), mkSin(dims,-pi/4,p4(2),p4(3),1) };

W = shFitClassV1Weights(parsBio, trainSet);   % [28 x 40]
fprintf('Fitted W: %d neurons x %d features (%d classes x %d basis)\n', ...
        size(W, 1), size(W, 2), nClass, nBasisPerClass);

% ---------------------------------------------------------------------
% 1. Full weight matrix
% ---------------------------------------------------------------------
f1 = figure('Name', 'RGC class -> V1 weights (midget/parasol)', 'Color', 'w', ...
       'Position', [80 400 900 480]);
clim = max(abs(W(:)));
imagesc(W, [-clim clim]);
colormap(localDivergingMap(256)); colorbar;
xlabel('feature column (class x spatial-derivative read-out)');
ylabel('V1 neuron index');
title('Fitted weights W [28 neurons x 40 features]');
hold on;
for c = 1:nClass - 1
    xline(c * nBasisPerClass + 0.5, 'k-', 'LineWidth', 1);
end
set(gca, 'XTick', nBasisPerClass * (0:nClass-1) + nBasisPerClass/2 + 0.5, ...
         'XTickLabel', strrep(classNames, '_', '\_'));
hold off;

% ---------------------------------------------------------------------
% 2. Per-class summed weight (which class dominates each neuron)
% ---------------------------------------------------------------------
Wchan = zeros(size(W, 1), nClass);
for c = 1:nClass
    cols = (c - 1) * nBasisPerClass + 1:c * nBasisPerClass;
    Wchan(:, c) = sum(W(:, cols), 2);
end

f2 = figure('Name', 'Per-class summed V1 weight (midget/parasol)', 'Color', 'w', ...
       'Position', [80 40 700 480]);
clim2 = max(abs(Wchan(:)));
imagesc(Wchan, [-clim2 clim2]);
colormap(localDivergingMap(256)); colorbar;
xlabel('RGC class'); ylabel('V1 neuron index');
set(gca, 'XTick', 1:nClass, 'XTickLabel', strrep(classNames, '_', '\_'));
title('Sum of weights within each class''s 10-column read-out block');

% ---------------------------------------------------------------------
% 3. Per-class weight energy vs. preferred direction
% ---------------------------------------------------------------------
dirAngle = pars.v1PopulationDirections(:, 1);   % direction-related angle, radians
[sortedAngle, order] = sort(dirAngle);

f3 = figure('Name', 'Per-class weight energy vs. preferred direction', 'Color', 'w', ...
       'Position', [780 400 700 480]);
energy = abs(Wchan);
plot(sortedAngle, energy(order, :), '-o', 'LineWidth', 1.3, 'MarkerSize', 4);
xlabel('neuron direction parameter (v1PopulationDirections(:,1), rad)');
ylabel('|summed class weight|');
legend(strrep(classNames, '_', '\_'), 'Location', 'best');
title('Class read-out strength vs. preferred direction');
grid on;

exportgraphics(f1, fullfile(outDir, 'midgetParasol_weights_full.png'), 'Resolution', 150);
exportgraphics(f2, fullfile(outDir, 'midgetParasol_weights_perClass.png'), 'Resolution', 150);
exportgraphics(f3, fullfile(outDir, 'midgetParasol_weights_vsDirection.png'), 'Resolution', 150);
fprintf('\nDone. PNGs written to %s\n', outDir);

function cmap = localDivergingMap(m)
    g = linspace(0, 1, m / 2)';
    cmap = [[g g ones(m / 2, 1)]; [ones(m / 2, 1) flipud(g) flipud(g)]];
end
