% shShowRgcFourPopDemo
%
% Short self-contained demo of the four-population RGC layer:
%   onFast, offFast, onSlow, offSlow
%
% Run from the MTmodel root (with the toolbox on your path):
%   addpath(genpath('PATHNAME-OF-MTmodel'));
%   shShowRgcFourPopDemo
%
% Optional output:
%   report   struct with RGC channels, V1 comparison metrics, and weights

function report = shShowRgcFourPopDemo

    pars = shPars;
    pars.rgc.enabled = 1;
    pars.rgc.mode = 'fourPop';
    pars.rgc.impairmentEnabled = 0;

    dims = shGetDims(pars, 'v1Complex', [1 1 24]);
    stimulus = mkDots(dims, 0, 1.0, 0.12, 1.0);

    calReport = shCalibrateRgcLayer(3, pars);
    pars.rgc = calReport.bestRgcPars;
    pars.rgc.enabled = 1;

    rgcOut = shModelRgc(stimulus, pars);
    midT = round(size(stimulus, 3) / 2);

    channelNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
    titles = {'ON fast', 'OFF fast', 'ON slow', 'OFF slow'};

    figure('Name', 'Four-population RGC demo', 'Color', 'w');
    subplot(2, 3, 1);
    imagesc(stimulus(:, :, midT));
    axis image off;
    colormap gray;
    title(sprintf('Input (t=%d)', midT));

    for i = 1:4
        subplot(2, 3, i + 1);
        imagesc(rgcOut.channels.(channelNames{i})(:, :, midT));
        axis image off;
        colormap gray;
        title(titles{i});
    end

    subplot(2, 3, 6);
    imagesc(rgcOut.combined(:, :, midT));
    axis image off;
    colormap gray;
    title('Sum of four populations');

    W = pars.rgc.v1Weights;
    if isempty(W)
        W = shRgcV1Weights(pars.v1PopulationDirections);
        Wplot = W;
        weightTitle = 'Per-neuron RGC channel weights (analytical)';
    elseif size(W, 2) == 16
        Wplot = zeros(size(W, 1), 4);
        for ch = 1:4
            Wplot(:, ch) = sum(W(:, (ch - 1) * 4 + 1:ch * 4), 2);
        end
        weightTitle = 'Per-neuron RGC channel weights (fitted, summed over spatial basis)';
    elseif size(W, 2) == 40
        Wplot = zeros(size(W, 1), 4);
        for ch = 1:4
            Wplot(:, ch) = sum(W(:, (ch - 1) * 10 + 1:ch * 10), 2);
        end
        weightTitle = 'Per-neuron RGC channel weights (fitted, summed over basis)';
    else
        Wplot = W;
        weightTitle = 'Per-neuron RGC channel weights';
    end
    figure('Name', 'V1 weights over RGC channels', 'Color', 'w');
    imagesc(Wplot);
    colorbar;
    xlabel('RGC channel');
    ylabel('V1 neuron');
    set(gca, 'XTick', 1:4, 'XTickLabel', channelNames);
    title(weightTitle);

    v1Report = shShowRgcAndV1Comparison(stimulus, pars, 0);

    fprintf('\nFour-population RGC demo\n');
    fprintf('  stimulus size : %s\n', mat2str(size(stimulus)));
    fprintf('  V1 corr (no RGC vs calibrated RGC): %.4f\n', v1Report.v1Corr);
    fprintf('  V1 NRMSE                              : %.4f\n', v1Report.v1NRMSE);
    fprintf('  calibration corr (stim set)           : %.4f\n', calReport.afterCorrelation);
    fprintf('\n');

    report = struct;
    report.stimulus = stimulus;
    report.pars = pars;
    report.rgcOut = rgcOut;
    report.v1Weights = W;
    if exist('Wplot', 'var')
        report.v1ChannelWeights = Wplot;
    end
    report.v1Comparison = v1Report;
    report.calibration = calReport;

end
