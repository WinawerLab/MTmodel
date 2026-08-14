% W = shFitClassV1Weights(pars, stimSet, mask)
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
% Optional arguments:
% mask     1 x nFeatures logical restricting the fit to a subset of the feature
%          columns (build with shClassFeatureMask). Unselected columns are
%          excluded from the regression entirely and returned as exactly zero,
%          so the pathway they represent cannot influence the fit at all. W is
%          still returned at full width, so it drops into
%          shModelV1LinearFromClasses unchanged. [ all true ]
%
% Output:
% W        [nNeurons x nFeatures] weight matrix; assign to pars.rgc.v1Weights
%          and set pars.rgc.combine = 'weights'.
%
% The masked form is how the MT-projecting ("population A") V1 fit is built: see
% docs/TODO.md item 1. Restricting to parasol columns makes that population
% magnocellular by construction, rather than leaving the M/P split to an
% objective that does not encode it.

function W = shFitClassV1Weights(pars, stimSet, mask)

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

    if nargin < 3 || isempty(mask)
        mask = true(1, nW);
    end
    mask = logical(mask(:)');
    if numel(mask) ~= nW
        error('shFitClassV1Weights:maskShape', ...
              'mask has %d entries but the class basis has %d columns.', numel(mask), nW);
    end
    if ~any(mask)
        error('shFitClassV1Weights:emptyMask', 'mask selects no columns.');
    end

    % Fit within the masked subspace only. lambda is scaled off the masked
    % submatrix so the regularization strength does not depend on how many
    % columns were excluded.
    Sm = SStack(:, mask);
    nM = size(Sm, 2);
    lambda = 1e-4 * trace(Sm' * Sm) / nM;
    A = Sm' * Sm + lambda * eye(nM);

    W = zeros(nNeurons, nW);
    for n = 1:nNeurons
        W(n, mask) = (A \ (Sm' * targetStack(:, n)))';
    end

end
