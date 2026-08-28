function R = motionLetterTrials(stim, stimInfo, pars, cfgMl, cfgNoise, varargin)
% motionLetterTrials  N-trial motion-letter loop with seed discipline.
%
% Same dot movie (stim) for every trial; rng(cfgNoise.noiseSeed + tr) before
% each shModel call so Step 2 can inject Site-2 noise without changing callers.
%
% Inputs
%   stim, stimInfo   from mkMotionLetter (built once outside)
%   pars             model parameters (+ lesion already applied)
%   cfgMl            from motionLetterPars (needs .seed, .letter, …)
%   cfgNoise         from noisePars (.nTrials, .noiseSeed, …)
%
% Optional name/value:
%   'conditionLabel'  char   (default '')
%   'runV1'           logical — also run v1Complex (default false; MT is enough
%                     for the primary observables. Set true when you need dV1.)
%
% Output R: summary struct from motionLetterSummarizeTrials (includes .trials)
%
% See also: noisePars, motionLetterTrialMetrics, docs/NOISE_TRIAL_DESIGN.md.

p = inputParser;
p.addParameter('conditionLabel', '', @ischar);
p.addParameter('runV1', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
label = p.Results.conditionLabel;
runV1 = p.Results.runV1;

if ~isfield(cfgNoise, 'nTrials') || cfgNoise.nTrials < 1
    error('motionLetterTrials:badNTrials', 'cfgNoise.nTrials must be >= 1.');
end
if ~isfield(cfgNoise, 'noiseSeed')
    error('motionLetterTrials:badSeed', 'cfgNoise.noiseSeed is required.');
end

nT = cfgNoise.nTrials;

for tr = 1:nT
    rng(cfgNoise.noiseSeed + tr);
    [popMt, indMt] = shModel(stim, pars, 'mtPattern');
    if runV1
        [popV1, indV1] = shModel(stim, pars, 'v1Complex');
    else
        popV1 = [];
        indV1 = [];
    end
    m = motionLetterTrialMetrics(popMt, indMt, popV1, indV1, pars, stimInfo);
    if tr == 1
        trials = repmat(m, nT, 1);
    else
        trials(tr) = m;
    end
    fprintf('  trial %d/%d  dMt = %+.3f\n', tr, nT, m.dMt);
end

R = motionLetterSummarizeTrials(trials, cfgMl, cfgNoise, pars, ...
    'conditionLabel', label);

end
