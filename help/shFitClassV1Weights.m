% W = shFitClassV1Weights(pars, stimSet)
%
% Fit per-neuron weights mapping the class-based RGC feature matrix
% (shClassV1Basis, from pars.rgc.classes) onto legacy V1 linear responses (RGC
% disabled), by ridge regression over a stimulus set. This is the general
% ('weights') combine path for shModelV1LinearFromClasses -- the analog of
% shFitRgcV1Weights for the unified class front-end.
%
% Required arguments:
% pars     parameters with pars.rgc.classes set
% stimSet  cell array of 3D movies [Y X T]
%
% Output:
% W        [nNeurons x nFeatures] weight matrix; assign to pars.rgc.v1Weights
%          and set pars.rgc.combine = 'weights'.

function W = shFitClassV1Weights(pars, stimSet)

    parsLeg = pars;
    parsLeg.rgc.enabled = 0;

    scale = pars.scaleFactors.v1Linear;
    nNeurons = size(pars.v1PopulationDirections, 1);

    SStack = [];
    targetStack = [];
    for i = 1:numel(stimSet)
        s = stimSet{i};
        popLegacy = shModelV1Linear(s, parsLeg);
        S = shClassV1Basis(s, pars);
        SStack = [SStack; S]; %#ok<AGROW>
        targetStack = [targetStack; popLegacy ./ scale]; %#ok<AGROW>
    end

    nW = size(SStack, 2);
    lambda = 1e-4 * trace(SStack' * SStack) / nW;
    A = SStack' * SStack + lambda * eye(nW);

    W = zeros(nNeurons, nW);
    for n = 1:nNeurons
        W(n, :) = (A \ (SStack' * targetStack(:, n)))';
    end

end
