function fit = shFitSpeedCoherencePsychometric(speed, coherence, isCorrect, options)
% shFitSpeedCoherencePsychometric  Fit the joint speed-by-coherence psychometric function to trials.
%
%   fit = shFitSpeedCoherencePsychometric(speed, coherence, isCorrect) fits
%   shSpeedCoherencePsychometric to single trials by maximum likelihood, in
%   the same way as the "joint" model of analysis/mt_coh_fit.m in
%   EXPLORING_Speed_Coherence_Psychometrics:
%     - chance gamma fixed;
%     - threshold a power law of coherence, one shared slope sigma;
%     - lapse rate lambda kept in [0, MaxLapse] by a logistic;
%     - sigma kept positive by fitting log(sigma);
%     - Bernoulli likelihood, several fminsearch starts, each run twice.
%   Model and human fits are therefore comparable in b and sigma.
%
%   Two differences from mt_coh_fit, both needed for model data:
%     - Starting values come from where each coherence's data cross the
%       midpoint of the curve. mt_coh_fit starts from each series' median
%       speed, which is meaningful for a staircase but not for a fixed grid.
%     - With a single coherence, b cannot be estimated. It is held at 0 and
%       reported as NaN.
%
%   fit = shFitSpeedCoherencePsychometric(..., Gamma=g, MaxLapse=m, NumStarts=n)
%
%   Inputs:
%     speed       [nTrials 1] dot speed on each trial. Use deg/s to compare
%                 with the control data.
%     coherence   [nTrials 1] coherence on each trial
%     isCorrect   [nTrials 1] logical
%     Gamma       chance level. Default 0.1 (10 letters).
%     MaxLapse    upper bound on the lapse rate. Default 0.06, as for the controls.
%     NumStarts   number of fminsearch starts. Default 8, as for the controls.
%
%   Output fields:
%     mu0, b, sigma, lambda, gamma   a params struct for shSpeedCoherencePsychometric
%     thresholdAtCoherence1          10^mu0, in the units of speed
%     negLogLikelihood, nTrials
%
%   The random restarts use a private random stream, so the fit is
%   reproducible and leaves the global random numbers untouched.
%
%   See also shSpeedCoherencePsychometric, shRunLetterTrials

    arguments
        speed (:,1) double {mustBePositive}
        coherence (:,1) double {mustBePositive}
        isCorrect (:,1) logical
        options.Gamma (1,1) double {mustBeBetween(options.Gamma, 0, 1)} = 0.1
        options.MaxLapse (1,1) double {mustBeBetween(options.MaxLapse, 0, 1)} = 0.06
        options.NumStarts (1,1) double {mustBeInteger, mustBePositive} = 8
    end

    if numel(coherence) ~= numel(speed) || numel(isCorrect) ~= numel(speed)
        error("shFitSpeedCoherencePsychometric:size", ...
            "speed, coherence and isCorrect must have one entry per trial.");
    end

    startSigma = 0.35;          % as in mt_coh_fit
    perturbationScale = [0.3; 0.5; 0.4; 1];   % mu0, b, log sigma, lapse logit
    fitOptions = optimset("Display", "off", "MaxIter", 1e4, "MaxFunEvals", 4e4, ...
        "TolX", 1e-8, "TolFun", 1e-8);

    logSpeed = log10(speed);
    logCoherence = log10(coherence);
    [levels, ~, levelIndex] = unique(coherence);
    nLevels = numel(levels);
    midpoint = (1 + options.Gamma)/2;

    startThreshold = zeros(nLevels, 1);
    for k = 1:nLevels
        inLevel = levelIndex == k;
        startThreshold(k) = localCrossing(logSpeed(inLevel), isCorrect(inLevel), midpoint);
    end

    fitsB = nLevels > 1;
    if fitsB
        line = polyfit(log10(levels), startThreshold, 1);
        start = [line(2); line(1); log(startSigma); 0];
        toFull = @(theta) theta;
    else
        start = [startThreshold; log(startSigma); 0];
        toFull = @(theta) [theta(1); 0; theta(2); theta(3)];
        perturbationScale = perturbationScale([1 3 4]);
    end

    objective = @(theta) localNegLogLikelihood(toFull(theta), logSpeed, logCoherence, ...
        isCorrect, options.Gamma, options.MaxLapse);
    stream = RandStream("mt19937ar", Seed=0);
    best = start;
    bestValue = objective(start);
    for r = 1:options.NumStarts
        if r == 1
            theta = start;
        else
            theta = start + perturbationScale.*randn(stream, numel(start), 1);
        end
        theta = fminsearch(objective, theta, fitOptions);
        [theta, value] = fminsearch(objective, theta, fitOptions);
        if value < bestValue
            best = theta;
            bestValue = value;
        end
    end

    full = toFull(best);
    if fitsB
        b = full(2);
    else
        b = NaN;
    end
    fit = struct( ...
        "mu0", full(1), ...
        "b", b, ...
        "sigma", exp(full(3)), ...
        "lambda", options.MaxLapse*localLogistic(full(4)), ...
        "gamma", options.Gamma, ...
        "thresholdAtCoherence1", 10^full(1), ...
        "negLogLikelihood", bestValue, ...
        "nTrials", numel(speed));
end

function value = localNegLogLikelihood(theta, logSpeed, logCoherence, isCorrect, gamma, maxLapse)
    probabilityFloor = 1e-12;
    params = struct("mu0", theta(1), "b", theta(2), "sigma", exp(theta(3)), ...
        "lambda", maxLapse*localLogistic(theta(4)), "gamma", gamma);
    p = shSpeedCoherencePsychometric(params, 10.^logSpeed, 10.^logCoherence);
    p = min(max(p, probabilityFloor), 1-probabilityFloor);
    value = -sum(isCorrect.*log(p) + (1-isCorrect).*log(1-p));
end

% Log speed at which the proportion correct first reaches criterion,
% interpolated between the two grid speeds that bracket it. If it never does,
% the fastest speed; if it already does at the slowest, the slowest.
function crossing = localCrossing(logSpeed, isCorrect, criterion)
    [grid, ~, speedIndex] = unique(logSpeed);
    proportion = accumarray(speedIndex, isCorrect, [], @mean);
    above = find(proportion >= criterion, 1);
    if isempty(above)
        crossing = grid(end);
    elseif above == 1
        crossing = grid(1);
    else
        fraction = (criterion-proportion(above-1))/(proportion(above)-proportion(above-1));
        crossing = grid(above-1) + fraction*(grid(above)-grid(above-1));
    end
end

function y = localLogistic(z)
    y = 1./(1 + exp(-z));
end
