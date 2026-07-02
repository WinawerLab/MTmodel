% results = shSweepRgcTemporalPars(pars, stimulus, sweepPars)
%
% Grid search over RGC temporal parameters to find the combination that
% maximises V1 correlation between the RGC-enabled and legacy (no-RGC)
% paths.  For each candidate the V1 weights are re-fitted via ridge
% regression so the comparison is always optimally calibrated.
%
% Optional arguments:
% pars        base parameters from shPars (default: shPars)
% stimulus    3D test movie [Y X T]
%             (default: dots at v1Complex minimum size, 24 frames)
% sweepPars   struct controlling the parameter grid:
%   .fastTau1      vector of fast-channel tau1 values in frames
%                  (default [0.5 1.0 1.5 2.0 3.0])
%   .slowTau1      vector of slow-channel tau1 values in frames
%                  (default [1.5 2.5 3.5 5.0 7.0])
%   .slowWeight    vector of slow second-lobe weights
%                  (default [0.0 0.1 0.2 0.3])
%   .fastWeight    scalar fast second-lobe weight (default 0.45)
%   .fastTau2Ratio fastTau2 = fastTau1 * ratio    (default 2.0)
%   .slowTau2Ratio slowTau2 = slowTau1 * ratio    (default 2.0)
%
% Combos where fastTau1 >= slowTau1 are skipped and stored as NaN.
%
% Output:
% results   struct with:
%   .F1grid .S1grid .SWgrid  ndgrid arrays (nF x nS x nSW)
%   .corrs    Nx1 V1 correlation per combo (NaN = skipped)
%   .nrmses   Nx1 V1 NRMSE per combo
%   .bestCorr best correlation found
%   .bestIdx  linear index into the grid
%   .bestPars pars configured for best combo with fitted v1Weights
%
% Example:
%   results = shSweepRgcTemporalPars;
%   pars    = results.bestPars;
%   report  = shShowRgcAndV1Comparison([], pars);

function results = shSweepRgcTemporalPars(pars, stimulus, sweepPars)

    if nargin < 1 || isempty(pars),      pars      = shPars; end
    if nargin < 3 || isempty(sweepPars), sweepPars = struct; end

    sweepPars = localDefault(sweepPars, 'fastTau1',      [0.5 1.0 1.5 2.0 3.0]);
    sweepPars = localDefault(sweepPars, 'slowTau1',      [1.5 2.5 3.5 5.0 7.0]);
    sweepPars = localDefault(sweepPars, 'slowWeight',    [0.0 0.1 0.2 0.3]);
    sweepPars = localDefault(sweepPars, 'fastWeight',    0.45);
    sweepPars = localDefault(sweepPars, 'fastTau2Ratio', 2.0);
    sweepPars = localDefault(sweepPars, 'slowTau2Ratio', 2.0);
    sweepPars = localDefault(sweepPars, 'fastLag',       1);
    sweepPars = localDefault(sweepPars, 'slowLag',       2);

    if nargin < 2 || isempty(stimulus)
        dims     = shGetDims(pars, 'v1Complex', [1 1 24]);
        stimulus = mkDots(dims, 0, 1.0, 0.12, 1.0);
    end

    stimSet = localCalibrationStimuli(pars, stimulus);

    % Reference: legacy V1 complex response on the test stimulus (fixed).
    parsLegacy                     = pars;
    parsLegacy.rgc.enabled         = 0;
    parsLegacy.rgc.impairmentEnabled = 0;
    [v1LegPop, v1LegInd] = shModel(stimulus, parsLegacy, 'v1Complex');
    v1LegCenter = shGetNeuron(v1LegPop, v1LegInd);

    % Pre-compute legacy linear targets for calibration stimuli so the
    % no-RGC path runs only once instead of once per parameter combo.
    legTargetStack = localLegacyTargets(stimSet, parsLegacy);

    [F1g, S1g, SWg] = ndgrid(sweepPars.fastTau1, sweepPars.slowTau1, sweepPars.slowWeight);
    nCombos = numel(F1g);

    corrs  = NaN(nCombos, 1);
    nrmses = NaN(nCombos, 1);

    fprintf('Sweeping %d parameter combinations...\n', nCombos);
    reportEvery = max(1, floor(nCombos / 10));

    for i = 1:nCombos

        if F1g(i) >= S1g(i)    % fast channel must be strictly faster than slow
            continue;
        end

        parsRgc = localApplyPars(pars, F1g(i), S1g(i), SWg(i), sweepPars);
        parsRgc.rgc.v1Weights = localFitWeights(parsRgc, stimSet, legTargetStack);

        [v1RgcPop, v1RgcInd] = shModel(stimulus, parsRgc, 'v1Complex');
        v1RgcCenter = shGetNeuron(v1RgcPop, v1RgcInd);

        corrs(i)  = localCorr(v1LegCenter(:), v1RgcCenter(:));
        nrmses(i) = norm(v1LegCenter(:) - v1RgcCenter(:)) / max(norm(v1LegCenter(:)), eps);

        if mod(i, reportEvery) == 0 || i == nCombos
            valid = corrs(~isnan(corrs));
            if ~isempty(valid)
                fprintf('  %d/%d  best so far: %.4f\n', i, nCombos, max(valid));
            end
        end

    end

    validIdx = find(~isnan(corrs));
    [bestCorr, rel] = max(corrs(validIdx));
    bestIdx = validIdx(rel);

    bestPars = localApplyPars(pars, F1g(bestIdx), S1g(bestIdx), SWg(bestIdx), sweepPars);
    bestPars.rgc.v1Weights = localFitWeights(bestPars, stimSet, legTargetStack);

    results.F1grid    = F1g;
    results.S1grid    = S1g;
    results.SWgrid    = SWg;
    results.corrs     = corrs;
    results.nrmses    = nrmses;
    results.bestCorr  = bestCorr;
    results.bestIdx   = bestIdx;
    results.bestPars  = bestPars;
    results.sweepPars = sweepPars;

    fprintf('\nBest: fastTau1=%.2f  slowTau1=%.2f  slowWeight=%.2f  corr=%.4f\n', ...
        F1g(bestIdx), S1g(bestIdx), SWg(bestIdx), bestCorr);

    localPlot(results, sweepPars);

end

% =========================================================================

function legTargetStack = localLegacyTargets(stimSet, parsLegacy)
    legTargetStack = [];
    for i = 1:length(stimSet)
        pop = shModelV1Linear(stimSet{i}, parsLegacy);
        legTargetStack = [legTargetStack; pop ./ parsLegacy.scaleFactors.v1Linear]; %#ok<AGROW>
    end
end

function W = localFitWeights(parsRgc, stimSet, legTargetStack)
    nNeurons = size(parsRgc.v1PopulationDirections, 1);
    SStack = [];
    for i = 1:length(stimSet)
        [~, ~, S] = shModelV1LinearFromRgc(stimSet{i}, parsRgc);
        SStack = [SStack; S]; %#ok<AGROW>
    end
    nWeights = size(SStack, 2);
    lambda = 1e-4 * trace(SStack' * SStack) / nWeights;
    A = SStack' * SStack + lambda * eye(nWeights);
    W = zeros(nNeurons, nWeights);
    for n = 1:nNeurons
        W(n, :) = (A \ (SStack' * legTargetStack(:, n)))';
    end
end

function parsRgc = localApplyPars(pars, f1, s1, sw, sweepPars)
    parsRgc                         = pars;
    parsRgc.rgc.enabled             = 1;
    parsRgc.rgc.mode                = 'fourPop';
    parsRgc.rgc.temporal.fastTau1   = f1;
    parsRgc.rgc.temporal.fastTau2   = f1 * sweepPars.fastTau2Ratio;
    parsRgc.rgc.temporal.fastWeight = sweepPars.fastWeight;
    parsRgc.rgc.temporal.fastLag    = sweepPars.fastLag;
    parsRgc.rgc.temporal.slowTau1   = s1;
    parsRgc.rgc.temporal.slowTau2   = s1 * sweepPars.slowTau2Ratio;
    parsRgc.rgc.temporal.slowWeight = sw;
    parsRgc.rgc.temporal.slowLag    = sweepPars.slowLag;
    parsRgc.rgc.v1Weights           = [];
end

function stimSet = localCalibrationStimuli(pars, stimulus)
    dims = size(stimulus);
    g1   = v12sin([0,    1.0]);
    g2   = v12sin([pi/3, 1.6]);
    if any(dims < shGetDims(pars, 'mtPattern', [1 1 dims(3)]))
        dims = shGetDims(pars, 'mtPattern', [1 1 dims(3)]);
    end
    stimSet = { ...
        mkDots(dims, 0,    1.0, 0.12, 1.0), ...
        mkDots(dims, pi/2, 0.7, 0.12, 0.7), ...
        mkSin(dims, 0,    g1(2), g1(3), 1), ...
        mkSin(dims, pi/3, g2(2), g2(3), 1)  ...
    };
end

function localPlot(results, sweepPars)
    f1vals = sweepPars.fastTau1;
    s1vals = sweepPars.slowTau1;
    swvals = sweepPars.slowWeight;
    nF     = length(f1vals);
    nS     = length(s1vals);
    nSW    = length(swvals);

    corrGrid = reshape(results.corrs, nF, nS, nSW);

    nCols = nSW;
    nRows = 2;
    figure('Name', 'RGC Temporal Parameter Sweep', 'Color', 'w', ...
        'Position', [50 80 220*nCols+100 520]);

    validCorrs = results.corrs(~isnan(results.corrs));
    clims = [0, max(validCorrs)];

    for sw = 1:nSW
        subplot(nRows, nCols, sw);
        slice = corrGrid(:, :, sw);
        slice(isnan(slice)) = 0;
        imagesc(s1vals, f1vals, slice, clims);
        set(gca, 'YDir', 'normal');
        colorbar;
        xlabel('slowTau1 (frames)');
        ylabel('fastTau1 (frames)');
        title(sprintf('slowWeight = %.2f', swvals(sw)));

        [~, bi] = max(slice(:));
        [r, c]  = ind2sub([nF nS], bi);
        hold on;
        plot(s1vals(c), f1vals(r), 'w*', 'MarkerSize', 12, 'LineWidth', 2);
        hold off;
    end

    % Bottom-left: ranked correlations across all combos.
    subplot(nRows, nCols, nCols + 1);
    nShow = min(30, length(validCorrs));
    sorted = sort(validCorrs, 'descend');
    bar(sorted(1:nShow), 'FaceColor', [0.4 0.6 0.8]);
    xlabel('Rank'); ylabel('V1 corr');
    title(sprintf('Sorted corrs (best = %.4f)', results.bestCorr));

    % Bottom-right (if space): temporal kernels at best parameters.
    if nCols >= 2
        subplot(nRows, nCols, nCols + 2);
        p  = results.bestPars.rgc.temporal;
        n  = p.power;
        t  = 0:max(ceil(8 * p.slowTau2), 20);
        tf_fast = localKernel(t, p.fastTau1, p.fastTau2, p.fastWeight, n);
        tf_slow = localKernel(t, p.slowTau1, p.slowTau2, p.slowWeight, n);
        plot(t, tf_fast, 'b', 'LineWidth', 1.5); hold on;
        plot(t, tf_slow, 'r', 'LineWidth', 1.5); hold off;
        legend('fast', 'slow', 'Location', 'best');
        xlabel('Frame'); ylabel('Amplitude (norm)');
        title('Best temporal kernels');
        grid on;
    end

    sgtitle(sprintf('Best: fastTau1=%.2f  slowTau1=%.2f  slowWeight=%.2f  corr=%.4f', ...
        results.F1grid(results.bestIdx), results.S1grid(results.bestIdx), ...
        results.SWgrid(results.bestIdx), results.bestCorr));
end

function tf = localKernel(t, tau1, tau2, w, n)
    tf = (t ./ tau1).^n .* exp(-t ./ tau1) - w .* (t ./ tau2).^n .* exp(-t ./ tau2);
    pk = max(abs(tf));
    if pk > 0, tf = tf / pk; end
end

function s = localDefault(s, field, val)
    if ~isfield(s, field) || isempty(s.(field))
        s.(field) = val;
    end
end

function c = localCorr(a, b)
    if std(a) == 0 || std(b) == 0, c = 0; return; end
    r = corrcoef(a, b);
    c = r(1, 2);
end
