% report = shShowRgcV1ReceptiveFields(pars, neuronIdx, fitWeights)
%
% Visualize RGC and V1 linear front-end components:
%   (1) spatial receptive fields of the four RGC populations
%   (2) temporal receptive fields of the four RGC populations
%   (3) RGC-to-V1 weights (channel and separable-basis views)
%   (4) legacy V1 spatiotemporal filters (no RGC layer)
%
% Optional arguments:
% pars        model parameters from shPars (default). Use calibrated pars.rgc
%             for the RGC panels and weights.
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

    dogKernels = localLinearSpatialDogKernels(pars.rgc);

    figure('Name', 'RGC spatial receptive fields', 'Color', 'w');
    for i = 1:4
        subplot(2, 2, i);
        imagesc(dogKernels.(channelNames{i}));
        axis image off;
        colormap(gca, redblueMap);
        colorbar;
        title(strrep(channelNames{i}, 'Fast', ' fast'));
    end
    sgtitle('RGC spatial RFs (signed linear DoG of contrast image)');

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

    W = localGetV1Weights(pars);
    Wchan = localChannelWeightSummary(W);
    basisInfo = localV1BasisInfo(pars);

    figure('Name', 'RGC to V1 weights', 'Color', 'w');
    subplot(2, 2, 1);
    imagesc(W);
    colorbar;
    xlabel('Basis index (4 RGC channels x 4 spatial derivatives)');
    ylabel('V1 neuron');
    title('Full fitted/analytical weights');
    hold on;
    for ch = 1:3
        xline(ch * 4 + 0.5, 'w--');
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
    rgcTemporalProfiles = localRgcTemporalProfiles(temporalRf, channelNames);
    plot(rgcTemporalProfiles, 'LineWidth', 1.5);
    xlabel('Frame');
    ylabel('Center-pixel response');
    legend(channelNames, 'Location', 'best');
    title('Causal RGC temporal profiles');
    sgtitle('RGC to V1 weights');

    figure('Name', 'Legacy V1 temporal basis reference', 'Color', 'w');
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
    title('Legacy V1 temporal filters are not applied in RGC V1 mode');

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

    % This analysis is specific to the biological 'fourPop' channels
    % (onFast/offFast/onSlow/offSlow); it does not apply to 'derivative' mode.
    if ~isfield(pars.rgc, 'enabled')
        pars.rgc.enabled = 1;
    end
    pars.rgc.mode = 'fourPop';
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
    polarities = {'on', 'off', 'on', 'off'};
    speeds = {'fast', 'fast', 'slow', 'slow'};
    sz = 31;
    dogKernels = struct;

    baseCenterSigma = 0.8;
    baseSurroundSigma = 2.0;
    surroundWeight = 0.25;
    if isfield(rgcPars, 'spatial')
        if isfield(rgcPars.spatial, 'centerSigma'),   baseCenterSigma  = rgcPars.spatial.centerSigma;  end
        if isfield(rgcPars.spatial, 'surroundSigma'), baseSurroundSigma = rgcPars.spatial.surroundSigma; end
        if isfield(rgcPars.spatial, 'surroundWeight'), surroundWeight   = rgcPars.spatial.surroundWeight; end
    end

    for i = 1:4
        rfScale = 1.0;
        if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'fastRfScale')
            if strcmpi(speeds{i}, 'fast'), rfScale = rfScale * rgcPars.spatial.fastRfScale; end
        end
        if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'onRfScale')
            if strcmpi(polarities{i}, 'on'), rfScale = rfScale * rgcPars.spatial.onRfScale; end
        end
        centerSigma  = baseCenterSigma  * rfScale;
        surroundSigma = baseSurroundSigma * rfScale;
        if surroundSigma <= centerSigma, surroundSigma = centerSigma + 0.5; end

        center   = mkGaussianFilter(centerSigma);
        surround = mkGaussianFilter(surroundSigma);

        impulse = zeros(sz, sz, 1);
        impulse(ceil(sz/2), ceil(sz/2), 1) = 1;
        contrastImage = impulse - mean(impulse(:));

        outCenter   = localSeparableSpatialSame(contrastImage, center);
        outSurround = localSeparableSpatialSame(contrastImage, surround);
        csResponse = outCenter - surroundWeight .* outSurround;

        if strcmpi(polarities{i}, 'on')
            dogKernels.(channelNames{i}) = csResponse;
        else
            dogKernels.(channelNames{i}) = -csResponse;
        end
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
    W = zeros(size(W4, 1), 16);
    for ch = 1:4
        W(:, (ch - 1) * 4 + 1:ch * 4) = repmat(W4(:, ch), 1, 4);
    end

end

function Wchan = localChannelWeightSummary(W)

    nBasis = size(W, 2) / 4;
    Wchan = zeros(size(W, 1), 4);
    for ch = 1:4
        Wchan(:, ch) = sum(W(:, (ch - 1) * nBasis + 1:ch * nBasis), 2);
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
            info.temporalProfile(:, n) = tf;
            info.basisLabels{n} = sprintf('t%d x%d y%d', torder, xorder, yorder);
            info.spatialOrderPerBasis(n) = xorder + yorder;
            n = n + 1;
        end
    end

end

function mat = localBasisSpatialWeightProfile(W, info)

    nBasis = size(W, 2) / 4;
    mat = zeros(4, 4);
    for ch = 1:4
        cols = (ch - 1) * nBasis + 1:ch * nBasis;
        for order = 0:3
            idx = info.spatialOrderPerBasis(1:nBasis) == order;
            mat(ch, order + 1) = mean(abs(W(:, cols(idx))), 'all');
        end
    end

end

function wt = localBasisTemporalWeightProfile(W, ch)

    nBasis = size(W, 2) / 4;
    cols = (ch - 1) * nBasis + 1:ch * nBasis;
    wt = zeros(1, 10);
    wt(1:nBasis) = mean(abs(W(:, cols)), 1);

end

function profiles = localRgcTemporalProfiles(temporalRf, channelNames)

    nFrames = length(temporalRf.(channelNames{1}));
    profiles = zeros(nFrames, length(channelNames));
    for i = 1:length(channelNames)
        profiles(:, i) = temporalRf.(channelNames{i});
    end

end

function cmap = redblueMap()
    n = 64;
    r = [linspace(0, 1, n/2), ones(1, n/2)]';
    b = [ones(1, n/2), linspace(1, 0, n/2)]';
    g = zeros(n, 1);
    cmap = [r, g, b];
end
