% report = shShowRgcAndMtComparison(stimulus, pars)
%
% Visualize MT responses with and without the optional RGC layer.
% This complements shShowRgcAndV1Comparison by focusing on MT outputs.
%
% Optional arguments:
% stimulus   3D movie [Y X T]. If omitted, a default dots movie is created.
% pars       model parameters from shPars. If omitted, defaults are used.
%
% Output:
% report     struct with MT summary metrics and extracted center-neuron responses.

function report = shShowRgcAndMtComparison(stimulus, pars)

    if nargin < 2 || isempty(pars)
        pars = shPars;
    end

    if nargin < 1 || isempty(stimulus)
        dims = shGetDims(pars, 'mtPattern', [1 1 24]);
        stimulus = mkDots(dims, 0, 1.0, 0.12, 1.0);
    end

    parsNoRgc = pars;
    parsNoRgc.rgc.enabled = 0;
    parsNoRgc.rgc.impairmentEnabled = 0;

    parsRgc = pars;
    parsRgc.rgc.enabled = 1;
    if ~isfield(parsRgc.rgc, 'impairmentEnabled')
        parsRgc.rgc.impairmentEnabled = 0;
    end
    parsRgc = localEnsureRgcV1Weights(parsRgc, stimulus);

    [mtNoRgcPop, mtNoRgcInd] = shModel(stimulus, parsNoRgc, 'mtPattern');
    [mtRgcPop, mtRgcInd] = shModel(stimulus, parsRgc, 'mtPattern');

    mtNoRgcCenter = shGetNeuron(mtNoRgcPop, mtNoRgcInd);
    mtRgcCenter = shGetNeuron(mtRgcPop, mtRgcInd);

    mtNoRgcMean = mean(mtNoRgcCenter, 2);
    mtRgcMean = mean(mtRgcCenter, 2);

    mtCorr = localSafeCorr(mtNoRgcCenter(:), mtRgcCenter(:));
    mtNrmse = localNrmse(mtNoRgcCenter(:), mtRgcCenter(:));

    figure('Name', 'MT with/without RGC', 'Color', 'w');
    subplot(2, 2, 1);
    plot(mtNoRgcMean, 'k', 'LineWidth', 1.3); hold on;
    plot(mtRgcMean, 'r', 'LineWidth', 1.3); hold off;
    xlabel('MT neuron index'); ylabel('Mean response');
    legend('No RGC', 'With RGC', 'Location', 'best');
    title('Center-neuron MT mean response');

    subplot(2, 2, 2);
    scatter(mtNoRgcMean, mtRgcMean, 40, 'filled'); hold on;
    mn = min([mtNoRgcMean; mtRgcMean]);
    mx = max([mtNoRgcMean; mtRgcMean]);
    plot([mn mx], [mn mx], 'k--', 'LineWidth', 1.0); hold off;
    xlabel('No RGC mean'); ylabel('With RGC mean');
    title('Per-neuron mean comparison');

    subplot(2, 2, 3);
    plot(mean(mtNoRgcCenter, 1), 'k', 'LineWidth', 1.4); hold on;
    plot(mean(mtRgcCenter, 1), 'r', 'LineWidth', 1.4); hold off;
    xlabel('Frame'); ylabel('Population-mean response');
    legend('No RGC', 'With RGC', 'Location', 'best');
    title('MT temporal profile');

    subplot(2, 2, 4);
    axis off;
    text(0.02, 0.8, sprintf('MT corr: %.4f', mtCorr), 'FontSize', 12);
    text(0.02, 0.6, sprintf('MT NRMSE: %.4f', mtNrmse), 'FontSize', 12);
    text(0.02, 0.4, sprintf('RGC enabled: %d', parsRgc.rgc.enabled), 'FontSize', 12);
    text(0.02, 0.2, sprintf('RGC impairment: %d', parsRgc.rgc.impairmentEnabled), 'FontSize', 12);
    text(0.02, 0.0, sprintf('RGC path: %s', parsRgc.rgc.mode), 'FontSize', 12);
    title('Summary metrics');

    report = struct;
    report.mtCorr = mtCorr;
    report.mtNRMSE = mtNrmse;
    report.mtNoRgcCenter = mtNoRgcCenter;
    report.mtRgcCenter = mtRgcCenter;

end

function parsRgc = localEnsureRgcV1Weights(parsRgc, stimulus)

    % 'derivative' mode needs no fitted weights -- only 'fourPop' does.
    if ~strcmpi(parsRgc.rgc.mode, 'fourPop')
        return;
    end

    if isfield(parsRgc.rgc, 'v1Weights') && ~isempty(parsRgc.rgc.v1Weights)
        return;
    end

    stimSet = localCalibrationStimuli(parsRgc, stimulus);
    parsRgc.rgc.v1Weights = shFitRgcV1Weights(parsRgc, stimSet);

end

function stimSet = localCalibrationStimuli(pars, stimulus)

  stimSet = cell(1, 4);
  dims = size(stimulus);

  stimSet{1} = stimulus;
  stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);

  g1 = v12sin([0, 1.0]);
  g2 = v12sin([pi/3, 1.6]);
  stimSet{3} = mkSin(dims, 0, g1(2), g1(3), 1);
  stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);

  if any(dims < shGetDims(pars, 'mtPattern', [1 1 dims(3)]))
      dims = shGetDims(pars, 'mtPattern', [1 1 dims(3)]);
      stimSet{1} = mkDots(dims, 0, 1.0, 0.12, 1.0);
      stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);
      stimSet{3} = mkSin(dims, 0, g1(2), g1(3), 1);
      stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);
  end

end

function c = localSafeCorr(a, b)

    if std(a) == 0 || std(b) == 0
        c = 0;
        return;
    end
    r = corrcoef(a, b);
    c = r(1, 2);

end

function e = localNrmse(a, b)

    d = a - b;
    den = max(norm(a), eps);
    e = norm(d) ./ den;

end
