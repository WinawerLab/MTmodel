function R = motionLetterBenchmarkTrials(varargin)
% motionLetterBenchmarkTrials  §1.4 benchmark harness (healthy + lesion, noise off).
%
%   R = motionLetterBenchmarkTrials();
%   R = motionLetterBenchmarkTrials('speedDegS', 1, 'nTrials', 20, 'seed', 7);
%
% Builds one dot movie, runs healthy and amplitude_uniform (gain 0.5) with
% identical dots. Lesion+noise arm added in Step 2 when Site-2 exists.
%
% Overrides: any motionLetterPars or noisePars name/value pairs.
%
% See also: docs/NOISE_TRIAL_DESIGN.md §1.4, runMotionLetterTrialsDemo.

[mlArgs, noiseArgs] = localSplitBenchmarkArgs(varargin);

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'speedDegS', 1, 'letter', 'C', 'mtMix', true, mlArgs{:});
cfgNoise = noisePars('nTrials', 50, noiseArgs{:});

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

parsL = lesionApply(parsH, 'amplitude_uniform');

R = struct();
R.cfgMl = cfgMl;
R.cfgNoise = cfgNoise;
R.stimInfo = stimInfo;
R.healthy = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgNoise, ...
    'conditionLabel', 'healthy', 'runV1', false);
R.lesion = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgNoise, ...
    'conditionLabel', 'amplitude_uniform', 'runV1', false);

end

function [mlArgs, noiseArgs] = localSplitBenchmarkArgs(args)
mlFields = {'letter', 'speedDegS', 'seed', 'outSz', 'modelStage', 'rgcPreset', ...
    'mtMix', 'dotSize', 'dotContrast', 'dotShape', 'fCovered', ...
    'drawBackgroundDots', 'fontName', 'letterSizeFraction', 'letterSizePx'};
noiseFields = {'enabled', 'spatialCorrelation', 'spatialCorrSigmaPx', ...
    'noiseSeed', 'nTrials', 'site2.enabled', 'site2.mode', 'site2.sigma'};

mlArgs = {};
noiseArgs = {};
i = 1;
while i <= numel(args)
    key = args{i};
    if i == numel(args)
        error('motionLetterBenchmarkTrials:badArgs', ...
            'Unpaired override ''%s''.', key);
    end
    val = args{i + 1};
    if any(strcmp(key, mlFields))
        mlArgs = [mlArgs, {key, val}]; %#ok<AGROW>
    elseif any(strcmp(key, noiseFields))
        noiseArgs = [noiseArgs, {key, val}]; %#ok<AGROW>
    else
        error('motionLetterBenchmarkTrials:unknownOverride', ...
            'Unknown override ''%s''.', key);
    end
    i = i + 2;
end
end
