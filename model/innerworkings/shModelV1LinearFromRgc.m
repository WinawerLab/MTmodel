% [pop, ind, S, res] = shModelV1LinearFromRgc(stimulus, pars, resdirs)
%
% Compute linear V1 responses as weighted sums of four RGC populations.
% Each population is passed through the legacy separable derivative basis
% before combining, so healthy-mode responses can match the original model.
%
% Required arguments:
% stimulus   raw 3D movie [Y X T]
% pars       model parameters with pars.rgc.populationMode = 'fourPop'
%
% Optional arguments:
% resdirs    additional neuron directions (same format as shModelV1Linear)
%
% Outputs match shModelV1Linear.

function varargout = shModelV1LinearFromRgc(varargin)

    M = varargin{1};
    pars = varargin{2};
    v1PopulationDirections = pars.v1PopulationDirections;
    nChannels = 4;
    nBasis = 10;

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
    channelNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};

    ind = [];
    for ch = 1:nChannels
        [S_ch, ind] = shModelV1SeparableBasis(rgcOut.channels.(channelNames{ch}), pars);
        if ch == 1
            S = zeros(size(S_ch, 1), nChannels * nBasis);
        end
        S(:, (ch - 1) * nBasis + 1:ch * nBasis) = S_ch;
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

function pop = localCombineBasisResponses(S, directions, customWeights, pars)

    nNeurons = size(directions, 1);
    nBasis = 10;
    channelWeights = shRgcV1Weights(directions);

    if ~isempty(customWeights) && size(customWeights, 2) == size(S, 2)
        pop = S * customWeights';
        return;
    end

    swts = shSwts(directions);
    pop = zeros(size(S, 1), nNeurons);

    for ch = 1:4
        cols = (ch - 1) * nBasis + 1:ch * nBasis;
        pop = pop + (S(:, cols) * swts') .* repmat(channelWeights(:, ch)', size(S, 1), 1);
    end

end
