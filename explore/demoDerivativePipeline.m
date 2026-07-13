% demoDerivativePipeline  Walk a sample movie through the default ('derivative')
% RGC->V1->MT pipeline and visualize every stage:
%   1. input movie
%   2. RGC channel outputs (order0..order3)
%   3. RGC receptive fields (per-class: delta spatial RF x temporal kernel)
%   4. V1 outputs, with vs without the RGC front-end
%   5. MT outputs, with vs without the RGC front-end
%   6. V1 receptive fields (RGC-referred and stimulus-referred), two example
%      neurons with different preferred directions
%
% Self-locating; leaves figures on screen (run in a MATLAB session with
% DefaultFigureVisible = 'on').

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
rng(1);

pars = shPars;   % default: pars.rgc.mode = 'derivative'
fprintf('pars.rgc.mode = %s, pars.rgc.enabled = %d\n', pars.rgc.mode, pars.rgc.enabled);

% ---------------------------------------------------------------------
% 1. Sample movie: rightward-drifting dot field
% ---------------------------------------------------------------------
dims = shGetDims(pars, 'mtPattern', [1 1 24]);
stimulus = mkDots(dims, 0, 1.0, 0.12, 1.0);   % direction 0 (rightward), speed 1.0 px/frame
midT = round(size(stimulus, 3) / 2);

figure('Name', '1. Input movie', 'Color', 'w');
imagesc(stimulus(:, :, midT)); axis image off; colormap gray;
title(sprintf('Input frame t=%d (drifting dots)', midT));

% ---------------------------------------------------------------------
% 2. RGC channel outputs (order0..order3)
% ---------------------------------------------------------------------
rgcOut = shModelRgc(stimulus, pars);
chNames = fieldnames(rgcOut.channels);

figure('Name', '2. RGC channel outputs (derivative mode)', 'Color', 'w', ...
       'Position', [80 500 900 260]);
for i = 1:numel(chNames)
    subplot(1, numel(chNames), i);
    imagesc(rgcOut.channels.(chNames{i})(:, :, midT)); axis image off; colormap gray;
    title(strrep(chNames{i}, '_', '\_'));
end
sgtitle('RGC channel outputs at frame t = midT');

% ---------------------------------------------------------------------
% 3. RGC receptive fields: derivative classes have a DELTA spatial RF, so
% each class's "receptive field" is entirely its temporal kernel (a causal
% temporal-derivative filter of order 0..3).
% ---------------------------------------------------------------------
classes = pars.rgc.classes;
figure('Name', '3. RGC receptive fields (derivative classes)', 'Color', 'w', ...
       'Position', [80 200 900 260]);
for c = 1:numel(classes)
    subplot(1, numel(classes), c);
    tf = classes(c).temporalKernel;
    plot(0:numel(tf) - 1, tf, '-o', 'LineWidth', 1.4, 'MarkerSize', 3);
    yline(0, 'k:'); xlim([0 numel(tf) - 1]);
    xlabel('lag (frames)');
    title(sprintf('%s (spatial RF = delta)', strrep(classes(c).name, '_', '\_')));
end
sgtitle('RGC receptive fields: temporal kernel (spatial RF is a delta / single pixel)');

% ---------------------------------------------------------------------
% 4. V1 outputs, with vs without RGC
% ---------------------------------------------------------------------
v1Report = shShowRgcAndV1Comparison(stimulus, pars, 0);
fprintf('\nV1: RGC vs legacy corr = %.6f, NRMSE = %.6f (derivative should be near-exact)\n', ...
        v1Report.v1Corr, v1Report.v1NRMSE);

% ---------------------------------------------------------------------
% 5. MT outputs, with vs without RGC
% ---------------------------------------------------------------------
mtReport = shShowRgcAndMtComparison(stimulus, pars);
fprintf('MT: RGC vs legacy corr = %.6f, NRMSE = %.6f\n', mtReport.mtCorr, mtReport.mtNRMSE);

% ---------------------------------------------------------------------
% 6. V1 receptive fields (RGC-referred + stimulus-referred) for two example
% neurons with different preferred directions.
% ---------------------------------------------------------------------
dirs = pars.v1PopulationDirections;
[~, nIdx1] = min(dirs(:, 1));            % most negative/leftward-ish direction
[~, nIdx2] = max(dirs(:, 1));            % most positive/rightward-ish direction
fprintf('\nShowing V1 RF for neuron %d (dir=[%.2f %.2f]) and neuron %d (dir=[%.2f %.2f])\n', ...
        nIdx1, dirs(nIdx1, 1), dirs(nIdx1, 2), nIdx2, dirs(nIdx2, 1), dirs(nIdx2, 2));
shShowV1Rf(pars, nIdx1);
shShowV1Rf(pars, nIdx2);

fprintf('\nDone. Figures: 1 input, 1 RGC channels, 1 RGC RFs, 2 V1-comparison, 1 MT-comparison, 4 V1-RF (2 neurons x 2 views).\n');
