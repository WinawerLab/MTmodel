% W = shFitRgcV1Weights(pars, stimSet)
%
% Fit per-neuron weights over the four RGC separable bases (40 total
% channels = 4 populations x 10 derivative filters) so linear V1 responses
% match the legacy model (RGC disabled).
%
% Required arguments:
% pars     model parameters with pars.rgc.populationMode = 'fourPop'
% stimSet  cell array of 3D movies [Y X T]
%
% Output:
% W        Nx40 weight matrix

function W = shFitRgcV1Weights(pars, stimSet)

    if ~isfield(pars.rgc, 'populationMode') || ~strcmpi(pars.rgc.populationMode, 'fourPop')
        error('shFitRgcV1Weights requires pars.rgc.populationMode = ''fourPop''.');
    end

    parsLegacy = pars;
    parsLegacy.rgc.enabled = 0;

    parsRgc = pars;
    parsRgc.rgc.enabled = 1;
    parsRgc.rgc.v1Weights = [];

    nNeurons = size(pars.v1PopulationDirections, 1);
    nWeights = 40;

    SStack = [];
    targetStack = [];

    for i = 1:length(stimSet)
        s = stimSet{i};
        popLegacy = shModelV1Linear(s, parsLegacy);
        [~, ~, S] = shModelV1LinearFromRgc(s, parsRgc);

        target = popLegacy ./ pars.scaleFactors.v1Linear;
        SStack = [SStack; S];
        targetStack = [targetStack; target];
    end

    lambda = 1e-4 * trace(SStack' * SStack) / nWeights;
    A = SStack' * SStack + lambda * eye(nWeights);

    W = zeros(nNeurons, nWeights);
    for n = 1:nNeurons
        W(n, :) = (A \ (SStack' * targetStack(:, n)))';
    end

end
