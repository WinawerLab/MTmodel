function S = motionLetterSummarizeTrials(trials, cfgMl, cfgNoise, pars, varargin)
% motionLetterSummarizeTrials  Aggregate per-trial motion-letter metrics.
%
% Pure aggregation — no shModel calls.
%
% Optional name/value: 'conditionLabel', char
%
% See also: motionLetterTrials, docs/NOISE_TRIAL_DESIGN.md §2.3.

p = inputParser;
p.addParameter('conditionLabel', '', @ischar);
p.parse(varargin{:});
label = p.Results.conditionLabel;

nT = numel(trials);
if nT == 0
    error('motionLetterSummarizeTrials:empty', 'trials array is empty.');
end

S = struct();
S.nTrials = nT;
S.conditionLabel = label;
S.dMt_mean = mean([trials.dMt]);
S.dMt_std  = std([trials.dMt], 0);
S.dV1_mean = mean([trials.dV1]);
S.dV1_std  = std([trials.dV1], 0);
S.centerOppMt_mean = mean([trials.centerOppMt]);
S.centerOppMt_std  = std([trials.centerOppMt], 0);
S.centerOppV1_mean = mean([trials.centerOppV1]);
S.centerOppV1_std  = std([trials.centerOppV1], 0);
S.trials = trials;
S.cfgMl = cfgMl;
S.cfgNoise = cfgNoise;
S.parsSnapshot = localParsSnapshot(pars);
S.mtNote = trials(1).mtNote;
S.v1Note = trials(1).v1Note;

end

function snap = localParsSnapshot(pars)
% Lightweight record for reproducibility (avoid saving full pop arrays).
snap = struct();
snap.rgcEnabled = isfield(pars, 'rgc') && isfield(pars.rgc, 'enabled') && pars.rgc.enabled;
if snap.rgcEnabled && isfield(pars.rgc, 'mode')
    snap.rgcMode = pars.rgc.mode;
end
if isfield(pars, 'rgc') && isfield(pars.rgc, 'mtMix') && ~isempty(pars.rgc.mtMix)
    snap.mtMixAlpha = pars.rgc.mtMix.alpha;
else
    snap.mtMixAlpha = NaN;
end
if isfield(pars, 'rgc') && isfield(pars.rgc, 'impairmentEnabled')
    snap.impairmentEnabled = pars.rgc.impairmentEnabled;
end
end
