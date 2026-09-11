function proportionCorrect = shSpeedCoherencePsychometric(params, speed, coherence)
% shSpeedCoherencePsychometric  Joint psychometric function of dot speed and coherence.
%
%   pc = shSpeedCoherencePsychometric(params, speed, coherence) evaluates
%
%       pc = gamma + (1 - gamma - lambda) * Phi((log10(speed) - mu0 - b*log10(coherence)) / sigma)
%
%   This is the "joint" model fitted to the control observers in
%   EXPLORING_Speed_Coherence_Psychometrics (analysis/mt_coh_fit.m). Phi is the
%   standard normal cumulative distribution.
%     mu0     log10 threshold speed at coherence 1. It is where Phi = 0.5,
%             which is 55% correct when gamma = 0.1.
%     b       exponent of threshold speed on coherence:
%             threshold(c) = 10^mu0 * c^b. b = -1 means speed x coherence is
%             constant at threshold.
%     sigma   width of the curve, in log10 speed
%     lambda  lapse rate
%     gamma   chance level
%
%   Inputs:
%     params      struct with fields mu0, b, sigma, lambda, gamma
%     speed       dot speeds (any units; mu0 must be in the same units)
%     coherence   coherences, in (0, 1]. Expands against speed like any
%                 element-wise operation.
%
%   Output:
%     proportionCorrect   size of speed and coherence after implicit expansion
%
%   See also shFitSpeedCoherencePsychometric

    arguments
        params (1,1) struct
        speed double {mustBePositive}
        coherence double {mustBePositive}
    end

    z = (log10(speed)-params.mu0-params.b*log10(coherence))/params.sigma;
    proportionCorrect = params.gamma + (1-params.gamma-params.lambda)*0.5*erfc(-z/sqrt(2));
end
