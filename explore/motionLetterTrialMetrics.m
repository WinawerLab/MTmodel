function m = motionLetterTrialMetrics(popMt, indMt, popV1, indV1, pars, stimInfo)
% motionLetterTrialMetrics  Per-trial scalars for the motion-letter trial loop.
%
% Wraps motionLetterMetrics and adds letter-region means for trial-to-trial SD
% (docs/NOISE_TRIAL_DESIGN.md §1.3).
%
% See also: motionLetterTrials, motionLetterMetrics, motionLetterSummarizeTrials.

m = motionLetterMetrics(popMt, indMt, popV1, indV1, pars, stimInfo);

m.centerOppMt = mean(m.mtOpp(m.mask));
m.centerOppBg = mean(m.mtOpp(~m.mask));
m.letterMinusBg = m.centerOppMt - m.centerOppBg;

if isempty(m.v1Opp)
    m.centerOppV1 = NaN;
    m.centerOppV1Bg = NaN;
    m.letterMinusBgV1 = NaN;
else
    m.centerOppV1 = mean(m.v1Opp(m.mask));
    m.centerOppV1Bg = mean(m.v1Opp(~m.mask));
    m.letterMinusBgV1 = m.centerOppV1 - m.centerOppV1Bg;
end

end
