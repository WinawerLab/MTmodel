% [pop, ind, S, res] = shModelV1LinearFromRgc(stimulus, pars, resdirs)
%
% Compute linear V1 responses as weighted sums of RGC channel outputs.
% Each RGC channel (4 base + optional lagged) is projected onto all 10
% spatial derivative combinations (xorder+yorder 0..3), matching the
% column ordering of shSwts so the default and fitted weight paths are
% consistent with shModelV1Linear.
%
% Required arguments:
% stimulus   raw 3D movie [Y X T]
% pars       model parameters with pars.rgc.enabled = 1
%
% Optional arguments:
% resdirs    additional neuron directions (same format as shModelV1Linear)
%
% Outputs match shModelV1Linear.

function varargout = shModelV1LinearFromRgc(varargin)

    M = varargin{1};
    pars = varargin{2};
    v1PopulationDirections = pars.v1PopulationDirections;
    if nargin > 2
        resdirs = varargin{3};
    end

    mSz = [size(M, 1), size(M, 2), size(M, 3)];
    if any(mSz < shGetDims(pars, 'v1lin'))
        error('Stimulus is too small for computation of V1lin stage.');
    end

    if nargout > 3 && nargin < 3
        error('You must specify which neuronal responses you want.');
    end

    rgcOut = shModelRgc(M, pars);

    % Channel list is derived from the RGC output so lagged channels (when
    % pars.rgc.temporal.fastLag / slowLag > 0) are picked up automatically.
    channelNames = fieldnames(rgcOut.channels);
    nChannels = length(channelNames);

    % nSpatialBasis is inferred from the first channel's projection so it
    % automatically reflects the 10-combo full-order basis.
    ind = [];
    nSpatialBasis = [];
    for ch = 1:nChannels
        [S_ch, ind] = localModelV1SpatialBasis(rgcOut.channels.(channelNames{ch}), pars);
        if ch == 1
            nSpatialBasis = size(S_ch, 2);
            S = zeros(size(S_ch, 1), nChannels * nSpatialBasis);
        end
        S(:, (ch - 1) * nSpatialBasis + 1:ch * nSpatialBasis) = S_ch;
    end

    customWeights = [];
    if isfield(pars.rgc, 'v1Weights') && ~isempty(pars.rgc.v1Weights)
        customWeights = pars.rgc.v1Weights;
    end

    pop = localCombineBasisResponses(S, v1PopulationDirections, customWeights, pars);
    pop = pop * pars.scaleFactors.v1Linear;

    varargout{1} = pop;
    varargout{2} = ind;
    varargout{3} = S;

    if nargout > 3
        res = localCombineBasisResponses(S, resdirs, customWeights, pars);
        res = res * pars.scaleFactors.v1Linear;
        varargout{4} = res;
    end

end

function [S, ind] = localModelV1SpatialBasis(movie, pars)

    v1SpatialFilters = pars.v1SpatialFilters;
    nScales = pars.nScales;

    order = 3;
    fsz = size(v1SpatialFilters, 1);
    % Number of (xorder, yorder) pairs with xorder+yorder <= order:
    % sum_{k=0}^{order} (k+1) = (order+1)(order+2)/2 = 10 for order=3.
    nSpatialCombos = (order + 1) * (order + 2) / 2;
    ind = zeros(nScales + 1, 4);

    if size(movie, 3) < fsz
        error('RGC movie is too short for the V1 spatial projection.');
    end

    % Match legacy V1lin timing without applying a V1 temporal filter:
    % output at time t depends on causal RGC samples up through that time.
    movie = movie(:, :, fsz:end);

    for scale = 1:nScales
        m = shBlurDn3(movie, scale);
        n = 1;
        % Mirror shModelV1Linear's loop order (torder outer, xorder inner)
        % so that each channel's 10 columns align with shSwts column order.
        for torder = 0:order
            for xorder = 0:(order - torder)
                yorder = order - torder - xorder;
                xfilt = reshape(v1SpatialFilters(:, xorder + 1), [1 fsz 1]);
                yfilt = reshape(flipud(v1SpatialFilters(:, yorder + 1)), [fsz 1 1]);
                tmp = shValidCorrDn3(shValidCorrDn3(m, yfilt), xfilt);

                ind(scale + 1, 2:4) = [size(tmp, 1), size(tmp, 2), size(tmp, 3)];
                tmp = tmp(:);
                ind(scale + 1, 1) = ind(scale, 1) + size(tmp, 1);
                if ~exist('S', 'var')
                    S = zeros(size(tmp, 1), nSpatialCombos);
                end
                if size(S, 1) ~= ind(scale + 1, 1)
                    S = [S; zeros(size(tmp, 1) - size(S, 1), nSpatialCombos)]; %#ok<AGROW>
                end
                S(ind(scale, 1) + 1:ind(scale + 1, 1), n) = tmp;
                n = n + 1;
            end
        end
    end

end

function pop = localCombineBasisResponses(S, directions, customWeights, ~)

    nNeurons = size(directions, 1);

    if ~isempty(customWeights)
        if size(customWeights, 2) ~= size(S, 2)
            error('pars.rgc.v1Weights has %d columns but the current RGC basis has %d. Refit with shFitRgcV1Weights.', ...
                size(customWeights, 2), size(S, 2));
        end
        pop = S * customWeights';
        return;
    end

    % Default weights: apply shRgcV1Weights for the first 4 canonical
    % channels (onFast/offFast/onSlow/offSlow).  Any additional lagged
    % channels get zero weight here — fit weights with shFitRgcV1Weights
    % to use lagged channels effectively.
    %
    % With the 10-combo spatial basis, swts has 10 columns aligned to the
    % same ordering, so it can be used directly (no column truncation).
    nBaseChannels = 4;
    nBasisPerChannel = 10;   % (order+1)*(order+2)/2 for order=3
    channelWeights = shRgcV1Weights(directions);
    swts = shSwts(directions);
    pop = zeros(size(S, 1), nNeurons);

    nCh = min(nBaseChannels, floor(size(S, 2) / nBasisPerChannel));
    for ch = 1:nCh
        cols = (ch - 1) * nBasisPerChannel + 1:ch * nBasisPerChannel;
        pop = pop + (S(:, cols) * swts') .* ...
            repmat(channelWeights(:, ch)', size(S, 1), 1);
    end

end
