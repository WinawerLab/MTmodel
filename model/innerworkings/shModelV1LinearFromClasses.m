% [pop, ind, S] = shModelV1LinearFromClasses(M, pars)
%
% Unified class-based V1 linear stage. Consumes pars.rgc.classes (an array of
% RGC-class specs from shRgcClass / a preset such as shRgcClassesDerivative or
% shRgcClassesMidgetParasol) and computes V1 linear responses as:
%
%   1. for each class, filter the stimulus by the class's spatiotemporal RF and
%      rectification, causal-trim, and apply its ON/OFF readout offset;
%   2. project each class channel onto the V1 spatial-derivative read-outs it
%      declares (class.readoutOrders) -> feature columns of S (shClassV1Basis);
%   3. combine the columns into per-neuron responses, either analytically
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

    [S, ind, nCols] = shClassV1Basis(M, pars);

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
                      'combine=''weights'' requires pars.rgc.v1Weights (fit with shFitClassV1Weights).');
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
