% report = shShowRgcAndV1Comparison(stimulus, pars, showMovies)
%
% Visualize:
% (a) RGC outputs for a test movie
% (b) V1 outputs with and without the RGC layer
%
% Optional arguments:
% stimulus   3D movie [Y X T]. If omitted, a default dots movie is created.
% pars       model parameters from shPars. If omitted, defaults are used.
% showMovies if 1, plays input and RGC movies using flipBook. Default = 0.
%
% Output:
% report     struct with summary metrics and extracted V1 center-neuron responses.

function report = shShowRgcAndV1Comparison(stimulus, pars, showMovies)

    if nargin < 2 || isempty(pars)
        pars = shPars;
    end

    if nargin < 1 || isempty(stimulus)
        dims = shGetDims(pars, 'v1Complex', [1 1 24]);
        stimulus = mkDots(dims, 0, 1.0, 0.12, 1.0);
    end

    if nargin < 3 || isempty(showMovies)
        showMovies = 0;
    end

    parsNoRgc = pars;
    parsNoRgc.rgc.enabled = 0;
    parsNoRgc.rgc.impairmentEnabled = 0;

    parsRgc = pars;
    parsRgc.rgc.enabled = 1;
    if ~isfield(parsRgc.rgc, 'impairmentEnabled')
        parsRgc.rgc.impairmentEnabled = 0;
    end

    rgcStimulus = shModelRgc(stimulus, parsRgc);

    if showMovies == 1
        figure('Name', 'Input movie');
        flipBook(stimulus);
        figure('Name', 'RGC movie');
        flipBook(rgcStimulus);
    end

    [v1NoRgcPop, v1NoRgcInd] = shModel(stimulus, parsNoRgc, 'v1Complex');
    [v1RgcPop, v1RgcInd] = shModel(stimulus, parsRgc, 'v1Complex');

    v1NoRgcCenter = shGetNeuron(v1NoRgcPop, v1NoRgcInd);
    v1RgcCenter = shGetNeuron(v1RgcPop, v1RgcInd);

    v1NoRgcMean = mean(v1NoRgcCenter, 2);
    v1RgcMean = mean(v1RgcCenter, 2);

    v1Corr = localSafeCorr(v1NoRgcCenter(:), v1RgcCenter(:));
    v1Nrmse = localNrmse(v1NoRgcCenter(:), v1RgcCenter(:));

    midT = round(size(stimulus, 3) / 2);
    centerPatch = localCenterPatch(stimulus, rgcStimulus);

    figure('Name', 'RGC output overview', 'Color', 'w');
    subplot(2, 2, 1);
    imagesc(stimulus(:, :, midT)); axis image off; colormap gray;
    title(sprintf('Input frame t=%d', midT));

    subplot(2, 2, 2);
    imagesc(rgcStimulus(:, :, midT)); axis image off; colormap gray;
    title(sprintf('RGC frame t=%d', midT));

    subplot(2, 2, 3);
    plot(centerPatch.inputTrace, 'k', 'LineWidth', 1.4); hold on;
    plot(centerPatch.rgcTrace, 'r', 'LineWidth', 1.4); hold off;
    xlabel('Frame'); ylabel('Center-patch mean');
    legend('Input', 'RGC', 'Location', 'best');
    title('Temporal trace at center patch');

    subplot(2, 2, 4);
    scatter(stimulus(:), rgcStimulus(:), 6, '.');
    xlabel('Input pixel values'); ylabel('RGC pixel values');
    title('Input vs RGC transfer');

    figure('Name', 'V1 with/without RGC', 'Color', 'w');
    subplot(2, 2, 1);
    plot(v1NoRgcMean, 'k', 'LineWidth', 1.3); hold on;
    plot(v1RgcMean, 'r', 'LineWidth', 1.3); hold off;
    xlabel('V1 neuron index'); ylabel('Mean response');
    legend('No RGC', 'With RGC', 'Location', 'best');
    title('Center-neuron V1 mean response');

    subplot(2, 2, 2);
    scatter(v1NoRgcMean, v1RgcMean, 40, 'filled'); hold on;
    mn = min([v1NoRgcMean; v1RgcMean]);
    mx = max([v1NoRgcMean; v1RgcMean]);
    plot([mn mx], [mn mx], 'k--', 'LineWidth', 1.0); hold off;
    xlabel('No RGC mean'); ylabel('With RGC mean');
    title('Per-neuron mean comparison');

    subplot(2, 2, 3);
    plot(mean(v1NoRgcCenter, 1), 'k', 'LineWidth', 1.4); hold on;
    plot(mean(v1RgcCenter, 1), 'r', 'LineWidth', 1.4); hold off;
    xlabel('Frame'); ylabel('Population-mean response');
    legend('No RGC', 'With RGC', 'Location', 'best');
    title('V1 temporal profile');

    subplot(2, 2, 4);
    axis off;
    text(0.02, 0.8, sprintf('V1 corr: %.4f', v1Corr), 'FontSize', 12);
    text(0.02, 0.6, sprintf('V1 NRMSE: %.4f', v1Nrmse), 'FontSize', 12);
    text(0.02, 0.4, sprintf('RGC enabled: %d', parsRgc.rgc.enabled), 'FontSize', 12);
    text(0.02, 0.2, sprintf('RGC impairment: %d', parsRgc.rgc.impairmentEnabled), 'FontSize', 12);
    title('Summary metrics');

    report = struct;
    report.v1Corr = v1Corr;
    report.v1NRMSE = v1Nrmse;
    report.v1NoRgcCenter = v1NoRgcCenter;
    report.v1RgcCenter = v1RgcCenter;
    report.stimulus = stimulus;
    report.rgcStimulus = rgcStimulus;

end

function patch = localCenterPatch(inputMovie, rgcMovie)

    ysz = size(inputMovie, 1);
    xsz = size(inputMovie, 2);
    cy = round(ysz / 2);
    cx = round(xsz / 2);
    hw = max(1, round(min([ysz, xsz]) * 0.08));

    y1 = max(1, cy - hw);
    y2 = min(ysz, cy + hw);
    x1 = max(1, cx - hw);
    x2 = min(xsz, cx + hw);

    inputPatch = inputMovie(y1:y2, x1:x2, :);
    rgcPatch = rgcMovie(y1:y2, x1:x2, :);

    patch = struct;
    patch.inputTrace = squeeze(mean(mean(inputPatch, 1), 2));
    patch.rgcTrace = squeeze(mean(mean(rgcPatch, 1), 2));

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
