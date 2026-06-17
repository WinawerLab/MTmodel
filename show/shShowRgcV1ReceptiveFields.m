% report = shShowRgcV1ReceptiveFields(pars, neuronIdx, fitWeights)
%
% Visualize RGC and V1 linear front-end components:
%   (1) spatial receptive fields of the four RGC populations
%   (2) temporal receptive fields of the four RGC populations
%   (3) RGC-to-V1 weights (channel and separable-basis views)
%   (4) legacy V1 spatiotemporal filters (no RGC layer)
%
% Optional arguments:
% pars        model parameters from shPars (default). Use fourPop + calibrated
%             pars.rgc for the RGC panels and weights.
% neuronIdx   vector of V1 neuron indices for panel (4) (default = 4 spread)
% fitWeights  if 1 and pars.rgc.v1Weights is empty, fit weights on a small
%             calibration set (default = 1)
%
% Output:
% report      struct with kernels, weights, and legacy V1 filters

function report = shShowRgcV1ReceptiveFields(pars, neuronIdx, fitWeights)

    if nargin < 1 || isempty(pars)
        pars = shPars;
    end
    if nargin < 2 || isempty(neuronIdx)
        nNeurons = size(pars.v1PopulationDirections, 1);
        neuronIdx = round(linspace(1, nNeurons, min(4, nNeurons)));
    end
    if nargin < 3 || isempty(fitWeights)
        fitWeights = 1;
    end

    pars = localPreparePars(pars, fitWeights);
    channelNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
    polarities = {'on', 'off', 'on', 'off'};
    speeds = {'fast', 'fast', 'slow', 'slow'};

    kernels = struct;
    spatialRf = struct;
    temporalRf = struct;

    for i = 1:4
        kernels.(channelNames{i}) = shMkRgcPopulationFilter(pars, polarities{i}, speeds{i});
        spatialRf.(channelNames{i}) = localSpatialSlice(kernels.(channelNames{i}));
        temporalRf.(channelNames{i}) = squeeze(kernels.(channelNames{i})( ...
            ceil(end/2), ceil(end/2), :));
    end

    figure('Name', 'RGC spatial receptive fields', 'Color', 'w');
    for i = 1:4
        subplot(2, 2, i);
        imagesc(spatialRf.(channelNames{i}));
        axis image off;
        colormap(gca, redblueMap);
        colorbar;
        title(strrep(channelNames{i}, 'Fast', ' fast'));
    end
    sgtitle('RGC spatial RFs (impulse response slice at peak time)');

    figure('Name', 'RGC temporal receptive fields', 'Color', 'w');
    hold on;
    cols = lines(4);
    for i = 1:4
        plot(temporalRf.(channelNames{i}), 'Color', cols(i, :), 'LineWidth', 1.5);
    end
    hold off;
    xlabel('Frame');
    ylabel('Center-pixel response');
    legend(channelNames, 'Location', 'best');
    title('RGC temporal RFs (center-pixel impulse response)');
    grid on;

    figure('Name', 'RGC linear spatial kernels (DoG drive)', 'Color', 'w');
    dogKernels = localLinearSpatialDogKernels(pars.rgc);
    for i = 1:4
        subplot(2, 2, i);
        imagesc(dogKernels.(channelNames{i}));
        axis image off;
        colormap(gca, redblueMap);
        colorbar;
        title(['linear drive: ', channelNames{i}]);
    end
    sgtitle('Linear center-surround kernels before rectification');

    W = localGetV1Weights(pars);
    Wchan = localChannelWeightSummary(W);
    basisInfo = localV1BasisInfo(pars);

    figure('Name', 'RGC to V1 weights', 'Color', 'w');
    subplot(2, 2, 1);
    imagesc(W);
    colorbar;
    xlabel('Basis index (4 RGC channels x 10 derivatives)');
    ylabel('V1 neuron');
    title('Full fitted/analytical weights');
    hold on;
    for ch = 1:3
        xline(ch * 10 + 0.5, 'w--');
    end
    hold off;

    subplot(2, 2, 2);
    imagesc(Wchan);
    colorbar;
    set(gca, 'XTick', 1:4, 'XTickLabel', channelNames);
    xlabel('RGC channel');
    ylabel('V1 neuron');
    title('Weights summed over derivative basis');

    subplot(2, 2, 3);
    imagesc(basisInfo.spatialOrder, 1:4, localBasisSpatialWeightProfile(W, basisInfo));
    colorbar;
    set(gca, 'YTick', 1:4, 'YTickLabel', channelNames);
    xlabel('Spatial derivative order');
    title('Mean |weight| by spatial order');

    subplot(2, 2, 4);
    plot(basisInfo.temporalProfile, 'Color', [0.7 0.7 0.7]);
    hold on;
    cols = lines(4);
    for ch = 1:4
        wt = localBasisTemporalWeightProfile(W, ch);
        profile = basisInfo.temporalProfile * wt';
        plot(profile, 'LineWidth', 1.5, 'Color', cols(ch, :));
    end
    hold off;
    xlabel('Frame');
    ylabel('Weighted temporal basis');
    legend([{'basis components (gray)'}, channelNames], 'Location', 'best');
    title('Temporal derivative filters and channel-weighted sum');
    sgtitle('RGC to V1 weights');

    v1Neurons = pars.v1PopulationDirections(neuronIdx, :);
    legacyFilters = shMkV1Filter(pars, v1Neurons);

    figure('Name', 'Legacy V1 spatiotemporal filters (no RGC)', 'Color', 'w');
    for i = 1:length(neuronIdx)
        filt = legacyFilters(:, :, :, i);
        subplot(2, length(neuronIdx), i);
        imagesc(max(abs(filt), [], 3));
        axis image off;
        colormap(gca, gray);
        title(sprintf('n%d spatial env.', neuronIdx(i)));

        subplot(2, length(neuronIdx), length(neuronIdx) + i);
        plot(squeeze(filt(ceil(end/2), ceil(end/2), :)), 'k', 'LineWidth', 1.4);
        xlabel('Frame');
        title(sprintf('n%d center t', neuronIdx(i)));
        grid on;
    end
    sgtitle('V1 linear filters without RGC (shMkV1Filter)');

    fprintf('\nLegacy V1 filter movies: use flipBook on shMkV1Filter output, e.g.\n');
    fprintf('  f = shMkV1Filter(pars, pars.v1PopulationDirections(%d,:));\n', neuronIdx(1));
    fprintf('  flipBook(squeeze(f), ''default'', 0.1);\n\n');

    report = struct;
    report.pars = pars;
    report.kernels = kernels;
    report.spatialRf = spatialRf;
    report.temporalRf = temporalRf;
    report.dogKernels = dogKernels;
    report.v1Weights = W;
    report.v1ChannelWeights = Wchan;
    report.basisInfo = basisInfo;
    report.legacyFilters = legacyFilters;
    report.neuronIdx = neuronIdx;

end

function pars = localPreparePars(pars, fitWeights)

    if ~isfield(pars.rgc, 'enabled')
        pars.rgc.enabled = 1;
    end
    if ~isfield(pars.rgc, 'populationMode')
        pars.rgc.populationMode = 'fourPop';
    end

    if ~fitWeights || (isfield(pars.rgc, 'v1Weights') && ~isempty(pars.rgc.v1Weights))
        return;
    end

    dims = shGetDims(pars, 'v1Complex', [1 1 18]);
    stimSet = {mkDots(dims, 0, 1.0, 0.12, 1.0), mkSin(dims, 0, 1.0, 0.12, 1)};
    pars.rgc.v1Weights = shFitRgcV1Weights(pars, stimSet);

end

function slice = localSpatialSlice(kernel)

    [~, peakFrame] = max(abs(kernel(:)));
    [~, ~, t] = ind2sub(size(kernel), peakFrame);
    slice = kernel(:, :, t);

end

function dogKernels = localLinearSpatialDogKernels(rgcPars)

    channelNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
    sz = 31;
    center = mkGaussianFilter(rgcPars.spatial.centerSigma);
    surround = mkGaussianFilter(rgcPars.spatial.surroundSigma);
    dogKernels = struct;

    for i = 1:4
        impulse = zeros(sz, sz, 1);
        impulse(ceil(sz/2), ceil(sz/2), 1) = 1;
        localMean = localSeparableSpatialSame(impulse, surround);
        if i == 1 || i == 3
            drive = max(0, impulse - localMean);
        else
            drive = max(0, localMean - impulse);
        end
        outCenter = localSeparableSpatialSame(drive, center);
        outSurround = localSeparableSpatialSame(drive, surround);
        dogKernels.(channelNames{i}) = max(0, outCenter - rgcPars.spatial.surroundWeight .* outSurround);
    end

end

function out = localSeparableSpatialSame(in, filt)
    out = convn(in, reshape(filt, [length(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 length(filt) 1]), 'same');
end

function W = localGetV1Weights(pars)

    if isfield(pars.rgc, 'v1Weights') && ~isempty(pars.rgc.v1Weights)
        W = pars.rgc.v1Weights;
        return;
    end

    W4 = shRgcV1Weights(pars.v1PopulationDirections);
    W = zeros(size(W4, 1), 40);
    for ch = 1:4
        W(:, (ch - 1) * 10 + 1:ch * 10) = repmat(W4(:, ch), 1, 10);
    end

end

function Wchan = localChannelWeightSummary(W)

    Wchan = zeros(size(W, 1), 4);
    for ch = 1:4
        Wchan(:, ch) = sum(W(:, (ch - 1) * 10 + 1:ch * 10), 2);
    end

end

function info = localV1BasisInfo(pars)

    fsz = size(pars.v1SpatialFilters, 1);
    info = struct;
    info.spatialOrder = 0:3;
    info.temporalProfile = zeros(fsz, 10);
    info.basisLabels = cell(1, 10);

    n = 1;
    for torder = 0:3
        tf = flipud(pars.v1TemporalFilters(:, torder + 1));
        for xorder = 0:(3 - torder)
            yorder = 3 - torder - xorder;
            xf = pars.v1SpatialFilters(:, xorder + 1);
            yf = flipud(pars.v1SpatialFilters(:, yorder + 1));
            info.temporalProfile(:, n) = tf;
            info.basisLabels{n} = sprintf('t%d x%d y%d', torder, xorder, yorder);
            info.spatialOrderPerBasis(n) = xorder + yorder;
            n = n + 1;
        end
    end

end

function mat = localBasisSpatialWeightProfile(W, info)

    mat = zeros(4, 4);
    for ch = 1:4
        cols = (ch - 1) * 10 + 1:ch * 10;
        for order = 0:3
            idx = info.spatialOrderPerBasis == order;
            mat(ch, order + 1) = mean(abs(W(:, cols(idx))), 'all');
        end
    end

end

function wt = localBasisTemporalWeightProfile(W, ch)

    cols = (ch - 1) * 10 + 1:ch * 10;
    wt = mean(abs(W(:, cols)), 1);

end

function cmap = redblueMap()
    n = 64;
    r = [linspace(0, 1, n/2), ones(1, n/2)]';
    b = [ones(1, n/2), linspace(1, 0, n/2)]';
    g = zeros(n, 1);
    cmap = [r, g, b];
end
