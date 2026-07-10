% [pop, ind, S] = shModelV1LinearFromClasses(M, pars)
%
% Unified class-based V1 linear stage. Consumes pars.rgc.classes (an array of
% RGC-class specs from shRgcClass / a preset such as shRgcClassesDerivative) and
% computes V1 linear responses as:
%
%   1. for each class, filter the stimulus by the class's spatiotemporal RF and
%      rectification -> a class channel [Y X T];
%   2. trim the leading fsz-1 frames (causal-timing alignment with legacy);
%   3. project each class channel onto the V1 spatial-derivative read-outs it
%      declares (class.readoutOrders) -> feature columns of S;
%   4. combine the columns into per-neuron responses, either analytically
%      (pars.rgc.combine = 'steer', valid for the derivative diagonal) or with a
%      fitted weight matrix (pars.rgc.combine = 'weights', pars.rgc.v1Weights).
%
% This is the single forward that subsumes both the 'derivative' and 'fourPop'
% paths; the difference is entirely in pars.rgc.classes (see
% docs/RGC_V1_unification_plan.md). With the derivative preset and 'steer' it
% reproduces shModelV1LinearFromRgcDerivative (hence legacy) essentially exactly.
%
% Required arguments:
% M      raw 3D movie [Y X T]
% pars   parameters with pars.rgc.classes set and pars.rgc.combine in
%        {'steer','weights'}.
%
% Outputs match shModelV1Linear (pop, ind, S).

function [pop, ind, S] = shModelV1LinearFromClasses(M, pars)

    if ~isfield(pars.rgc, 'classes') || isempty(pars.rgc.classes)
        error('shModelV1LinearFromClasses:noClasses', ...
              'pars.rgc.classes must be set (e.g. shRgcClassesDerivative(pars)).');
    end
    combine = 'steer';
    if isfield(pars.rgc, 'combine') && ~isempty(pars.rgc.combine)
        combine = pars.rgc.combine;
    end

    classes = pars.rgc.classes;
    SF = pars.v1SpatialFilters;
    fsz = size(SF, 1);
    nScales = pars.nScales;

    mSz = [size(M, 1), size(M, 2), size(M, 3)];
    if any(mSz < shGetDims(pars, 'v1lin'))
        error('Stimulus is too small for computation of V1lin stage.');
    end

    % --- per-class channels (spatiotemporal RGC filtering), then causal trim ---
    nClass = numel(classes);
    chTrim = cell(1, nClass);
    for c = 1:nClass
        ch = localClassChannel(M, classes(c), pars);
        chTrim{c} = ch(:, :, fsz:end);
    end

    % total number of feature columns = sum over classes of sum_{s in orders}(s+1)
    nCols = 0;
    for c = 1:nClass
        nCols = nCols + sum(classes(c).readoutOrders + 1);
    end

    % --- build S (mirrors shModelV1LinearFromRgcDerivative's scale/row layout) ---
    ind = zeros(nScales + 1, 4);
    S = [];
    for scale = 1:nScales
        n = 1;
        for c = 1:nClass
            m = shBlurDn3(chTrim{c}, scale);
            for s = classes(c).readoutOrders
                for xorder = 0:s
                    yorder = s - xorder;
                    xfilt = reshape(SF(:, xorder + 1), [1 fsz 1]);
                    yfilt = reshape(flipud(SF(:, yorder + 1)), [fsz 1 1]);
                    tmp = shValidCorrDn3(shValidCorrDn3(m, yfilt), xfilt);

                    ind(scale + 1, 2:4) = [size(tmp, 1), size(tmp, 2), size(tmp, 3)];
                    tmp = tmp(:);
                    ind(scale + 1, 1) = ind(scale, 1) + size(tmp, 1);
                    if isempty(S)
                        S = zeros(size(tmp, 1), nCols);
                    end
                    if size(S, 1) ~= ind(scale + 1, 1)
                        S = [S; zeros(size(tmp, 1), nCols)]; %#ok<AGROW>
                    end
                    S(ind(scale, 1) + 1:ind(scale + 1, 1), n) = tmp;
                    n = n + 1;
                end
            end
        end
    end

    % --- combine feature columns into per-neuron responses ---
    switch lower(combine)
        case 'steer'
            % Analytic SH steering. Valid when the columns are the derivative
            % diagonal (10 columns in shSwts order), as produced by
            % shRgcClassesDerivative.
            if nCols ~= 10
                error('shModelV1LinearFromClasses:steerColumns', ...
                      'combine=''steer'' expects the 10-column derivative diagonal, got %d columns.', nCols);
            end
            pop = S * shSwts(pars.v1PopulationDirections)';
        case 'weights'
            if ~isfield(pars.rgc, 'v1Weights') || isempty(pars.rgc.v1Weights)
                error('shModelV1LinearFromClasses:noWeights', ...
                      'combine=''weights'' requires pars.rgc.v1Weights (fit with shFitRgcV1Weights).');
            end
            W = pars.rgc.v1Weights;
            if size(W, 2) ~= nCols
                error('shModelV1LinearFromClasses:weightShape', ...
                      'pars.rgc.v1Weights has %d columns but the class basis has %d.', size(W, 2), nCols);
            end
            pop = S * W';
        otherwise
            error('pars.rgc.combine must be ''steer'' or ''weights''.');
    end
    pop = pop * pars.scaleFactors.v1Linear;

end

% =====================================================================
function ch = localClassChannel(M, class, pars) %#ok<INUSD>
% Compute one class channel [Y X T] from the stimulus: spatial RF -> rectify ->
% causal temporal filter -> per-class gain. Increment 1 supports the derivative
% case (delta spatial RF, no rectification); spatial RF / rectification for the
% biological presets are declared but not yet implemented here.

    m = M;

    if ~isempty(class.spatialRF)
        error('shModelV1LinearFromClasses:spatialRFNotImplemented', ...
              'class.spatialRF is not yet consumed (biological preset TODO).');
    end
    if ~strcmpi(class.rectify, 'none')
        error('shModelV1LinearFromClasses:rectifyNotImplemented', ...
              'class.rectify=''%s'' is not yet implemented (biological preset TODO).', class.rectify);
    end

    % causal temporal filtering (convn 'full' then truncate), as in
    % shModelRgcDerivative.
    tf = class.temporalKernel;
    fullOut = convn(m, reshape(tf, [1 1 numel(tf)]), 'full');
    ch = fullOut(:, :, 1:size(m, 3));

    if isfield(class, 'gain') && ~isempty(class.gain)
        ch = ch .* class.gain;
    end

end
