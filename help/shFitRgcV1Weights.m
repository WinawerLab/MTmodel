% W = shFitRgcV1Weights(pars, stimSet)
%
% Fit per-neuron weights mapping RGC channels onto V1 linear responses so
% they match the legacy model (RGC disabled).  The number of channels is
% determined automatically: 4 RGC populations x 10 spatial basis functions
% = 40 columns (80 if lagged channels are enabled via pars.rgc.temporal.fastLag).
%
% Required arguments:
% pars     model parameters with pars.rgc enabled or ready to enable
% stimSet  cell array of 3D movies [Y X T]
%
% Output:
% W        Nx(nChannels) weight matrix

function W = shFitRgcV1Weights(pars, stimSet)

    parsLegacy = pars;
    parsLegacy.rgc.enabled = 0;

    parsRgc = pars;
    parsRgc.rgc.enabled = 1;
    parsRgc.rgc.v1Weights = [];

    nNeurons = size(pars.v1PopulationDirections, 1);

    SStack = [];
    targetStack = [];

    for i = 1:length(stimSet)
        s = stimSet{i};
        popLegacy = shModelV1Linear(s, parsLegacy);
        [~, ~, S] = shModelV1LinearFromRgc(s, parsRgc);

        target = popLegacy ./ pars.scaleFactors.v1Linear;
        SStack = [SStack; S]; %#ok<AGROW>
        targetStack = [targetStack; target]; %#ok<AGROW>
    end

    % nWeights is determined from S so lagged channels (8-channel basis)
    % are handled automatically alongside the standard 4-channel basis.
    nWeights = size(SStack, 2);
    lambda = 1e-4 * trace(SStack' * SStack) / nWeights;
    A = SStack' * SStack + lambda * eye(nWeights);

    W = zeros(nNeurons, nWeights);
    for n = 1:nNeurons
        W(n, :) = (A \ (SStack' * targetStack(:, n)))';
    end

end
