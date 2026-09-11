function proportionCorrect = shMafcProportionCorrect(dprime, nAlternatives)
% shMafcProportionCorrect  Proportion correct in an m-alternative forced choice, from d'.
%
%   pc = shMafcProportionCorrect(dprime, m) is the proportion correct for an
%   observer who picks the largest of m independent, unit-variance Gaussian
%   decision variables, one of which (the correct one) is shifted up by d':
%
%       pc = integral of phi(x - d') * Phi(x)^(m - 1) dx
%
%   d' = 0 gives chance, 1/m.
%
%   shRunLetterTrials uses it to turn the known-letter score into a predicted
%   10-AFC proportion correct. That prediction assumes the other nine scores
%   are independent and centred on zero. Real letters overlap (O and C share
%   most of their pixels), so it is optimistic. The classifier's measured
%   proportion correct is the one to compare with data.
%
%   Inputs:
%     dprime          any size. NaN or Inf entries give NaN.
%     nAlternatives   number of alternatives, m
%
%   Output:
%     proportionCorrect   same size as dprime
%
%   See also shRunLetterTrials

    arguments
        dprime double
        nAlternatives (1,1) double {mustBeInteger, mustBePositive}
    end

    halfWidth = 8;        % integrate over at least -8..8, and d' +/- 8 SD
    nGridPoints = 4001;

    proportionCorrect = nan(size(dprime));
    for k = 1:numel(dprime)
        d = dprime(k);
        if isfinite(d)
            x = linspace(min(-halfWidth, d-halfWidth), max(halfWidth, d+halfWidth), nGridPoints);
            density = exp(-(x-d).^2/2)/sqrt(2*pi);
            cumulative = 0.5*erfc(-x/sqrt(2));
            proportionCorrect(k) = trapz(x, density.*cumulative.^(nAlternatives-1));
        end
    end
end
