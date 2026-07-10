% [RFrgc, RFstim, info] = shV1Rf(pars, neuronIdx)
%
% Compute one V1 neuron's linear receptive field, referred two ways, from the
% unified class-based front-end (pars.rgc.classes). Class-agnostic: works for the
% derivative preset or any biological preset.
%
%   RFrgc   [fsz x fsz x nClass]  RGC-referred: the neuron's spatial weighting of
%           each RGC class channel (independent of the class's own RF/kernel).
%   RFstim  [fsz x fsz x nLag]    stimulus-referred: the linear space-time RF,
%           RFrgc_c convolved with each class's spatial RF (if any) and combined
%           with its temporal kernel, summed over classes. NOTE: for biological
%           presets this is the LINEAR kernel only (it ignores the ON/OFF
%           rectification, which is nonlinear).
%
% The per-neuron weights come from the combine mode: 'steer' -> shSwts(direction)
% (derivative diagonal), 'weights' -> pars.rgc.v1Weights(neuronIdx,:).
%
% Required arguments:
% pars       parameters with pars.rgc.classes set (e.g. from shPars)
% neuronIdx  index into pars.v1PopulationDirections (1..N)
%
% Output:
% info       struct: .classNames, .weights, .direction, .columnMap [class x y],
%            .readoutOffsets, .combine

function [RFrgc, RFstim, info] = shV1Rf(pars, neuronIdx)

    classes = pars.rgc.classes;
    SF = pars.v1SpatialFilters;
    fsz = size(SF, 1);
    nClass = numel(classes);

    combine = 'steer';
    if isfield(pars.rgc, 'combine') && ~isempty(pars.rgc.combine)
        combine = pars.rgc.combine;
    end

    % Column -> (class, xorder, yorder) map, mirroring shClassV1Basis's loop.
    map = zeros(0, 3);
    for c = 1:nClass
        for s = classes(c).readoutOrders
            for xorder = 0:s
                map(end + 1, :) = [c, xorder, s - xorder]; %#ok<AGROW>
            end
        end
    end
    nCols = size(map, 1);

    % Per-neuron weights over the columns.
    dir = pars.v1PopulationDirections(neuronIdx, :);
    switch lower(combine)
        case 'steer'
            if nCols ~= 10
                error('shV1Rf:steer', 'combine=''steer'' expects 10 columns, got %d.', nCols);
            end
            w = shSwts(dir);                 % 1 x 10
        case 'weights'
            w = pars.rgc.v1Weights(neuronIdx, :);
        otherwise
            error('shV1Rf:combine', 'pars.rgc.combine must be ''steer'' or ''weights''.');
    end

    % RGC-referred RF: per-class spatial weighting = sum over that class's columns
    % of w(n) * (flipud(yfilt) outer xfilt), matching the effective kernel applied
    % to the class channel in shClassV1Basis.
    RFrgc = zeros(fsz, fsz, nClass);
    for n = 1:nCols
        c = map(n, 1); xorder = map(n, 2); yorder = map(n, 3);
        sy = flipud(SF(:, yorder + 1));
        sx = SF(:, xorder + 1);
        RFrgc(:, :, c) = RFrgc(:, :, c) + w(n) * (sy * sx.');
    end

    % Stimulus-referred (linear) RF: convolve each class map with its spatial RF
    % (if any) and combine with its temporal kernel, then sum over classes.
    nLag = 0;
    for c = 1:nClass, nLag = max(nLag, numel(classes(c).temporalKernel)); end
    RFstim = zeros(fsz, fsz, nLag);
    for c = 1:nClass
        spatialMap = RFrgc(:, :, c);
        if ~isempty(classes(c).spatialRF)
            spatialMap = localDoGSame(spatialMap, classes(c).spatialRF);
        end
        tf = classes(c).temporalKernel;
        for tau = 1:numel(tf)
            RFstim(:, :, tau) = RFstim(:, :, tau) + spatialMap * tf(tau);
        end
    end

    info = struct('classNames', {{classes.name}}, 'weights', w, 'direction', dir, ...
                  'columnMap', map, 'readoutOffsets', {reshape([classes.readoutOffset], 2, [])'}, ...
                  'combine', combine);

end

function out = localDoGSame(in, sp)
    c = mkGaussianFilter(sp.centerSigma);
    s = mkGaussianFilter(sp.surroundSigma);
    out = conv2(c(:), c(:)', in, 'same') - sp.surroundWeight .* conv2(s(:), s(:)', in, 'same');
end
