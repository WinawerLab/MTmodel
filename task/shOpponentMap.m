function [map, units, weights] = shOpponentMap(pop, ind, pars, options)
% shOpponentMap  Rightward-minus-leftward MT signal at every position, averaged over time.
%
%   map = shOpponentMap(pop, ind, pars) weights every MOVING MT unit
%   (preferred speed > 0) by the cosine of its preferred direction, sums them,
%   and averages over time. Rightward units count positive, leftward units
%   negative, and vertical units not at all, so the map is the horizontal
%   component of the MT population vector at each position. It pools both
%   speed tiers. The static unit is left out because it has no preferred
%   direction.
%
%   map = shOpponentMap(..., Weighting="pair") uses only the slowest-tier unit
%   closest to rightward minus the one closest to leftward (0 and 180 deg at
%   1 px/frame in the default model).
%
%   Inputs:
%     pop, ind   from shModel(stim, pars, "mtPattern"). Scale 1 only.
%     pars       the parameters the model was run with.
%
%   Outputs:
%     map        [Y X] on the MT output grid
%     units      the MT units used (rows of pars.mtPopulationVelocities)
%     weights    their weights
%
%   See also shTemplateScores, shRunLetterTrials

    arguments
        pop (:,:) double
        ind (:,4) double
        pars (1,1) struct
        options.Weighting (1,1) string {mustBeMember(options.Weighting, ["cosine", "pair"])} = "cosine"
    end

    velocities = pars.mtPopulationVelocities;
    switch options.Weighting
        case "cosine"
            units = find(velocities(:, 2) > 0);
            weights = cos(velocities(units, 1));
        case "pair"
            % Nominal speeds can differ in low-order bits, so match the tier
            % with a relative tolerance rather than exactly.
            relativeTolerance = 1e-6;
            slowest = min(velocities(velocities(:, 2) > 0, 2));
            tier = find(abs(velocities(:, 2)-slowest) < relativeTolerance*max(1, slowest));
            [~, iRight] = min(abs(angle(exp(1i*velocities(tier, 1)))));
            [~, iLeft] = min(abs(angle(exp(1i*(velocities(tier, 1)-pi)))));
            units = tier([iRight; iLeft]);
            weights = [1; -1];
        otherwise
            % Unreachable: the arguments block allows only the two cases above.
            error("shOpponentMap:weighting", "Weighting must be ""cosine"" or ""pair"".");
    end

    rows = (ind(1, 1)+1):ind(2, 1);
    mapSize = ind(2, 2:4);
    map = mean(reshape(pop(rows, units)*weights, mapSize), 3);
end
