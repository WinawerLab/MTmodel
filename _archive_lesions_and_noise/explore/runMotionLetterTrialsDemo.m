% runMotionLetterTrialsDemo  Step 1 check: deterministic trial loop, noise off.
%
% Small field, MT only, a few trials. With noise disabled the model is
% deterministic: std(d') ≈ 0 and every trial matches a single forward pass.
%
%   run explore/runMotionLetterTrialsDemo.m
%
% Full §1.4 size (128^2, 50 trials, V1+MT) is for later, once Site-2 exists.
% See docs/NOISE_TRIAL_DESIGN.md §2.4.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

N_TRIALS = 3;
OUT_SZ   = [48 48 40];   % smoke-test size; not the 128^2 benchmark field

fprintf('=== Motion-letter trial loop (Step 1, noise off) ===\n\n');

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

cfgNoise = noisePars('nTrials', N_TRIALS);
[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'speedDegS', 1, 'letter', 'C', 'mtMix', true, 'seed', 7, ...
    'outSz', OUT_SZ);

fprintf('Stimulus: letter %s  %.2f deg/s  seed %d  stim [%d %d %d]\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, stimSz(1), stimSz(2), stimSz(3));
fprintf('Model: %s preset  mtMix %d  noise enabled %d  nTrials %d  (MT only)\n\n', ...
    cfgMl.rgcPreset, cfgMl.mtMix, cfgNoise.enabled, cfgNoise.nTrials);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

fprintf('[1/3] Single-trial reference...\n');
tic;
[popMt, indMt] = shModel(stim, parsH, 'mtPattern');
ref = motionLetterTrialMetrics(popMt, indMt, [], [], parsH, stimInfo);
fprintf('      dMt = %+.4f  (%.1f s)\n\n', ref.dMt, toc);

fprintf('[2/3] Healthy loop (%d trials, same movie)...\n', N_TRIALS);
R = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgNoise, ...
    'conditionLabel', 'healthy', 'runV1', false);

fprintf('\nHealthy (%d trials):\n', R.nTrials);
fprintf('  MT  d'' :  %+.4f ± %.6f\n', R.dMt_mean, R.dMt_std);
fprintf('  MT center opponent :  %+.4f ± %.6f\n', ...
    R.centerOppMt_mean, R.centerOppMt_std);
fprintf('  reference single-trial d'' (MT) = %+.4f\n\n', ref.dMt);

maxDev = max(abs([R.trials.dMt] - ref.dMt));
fprintf('Max |trial d'' - reference d''| = %.2e\n', maxDev);
if R.dMt_std < 1e-10 && maxDev < 1e-10
    fprintf('PASS: deterministic trials match single-trial d'' (std ≈ 0).\n');
else
    fprintf('WARN: expected std ≈ 0 with noise off — check for nondeterminism.\n');
end

fprintf('\n[3/3] Same movie, amplitude_uniform (gain 0.5)...\n');
parsL = lesionApply(parsH, 'amplitude_uniform');
RL = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgNoise, ...
    'conditionLabel', 'amplitude_uniform', 'runV1', false);
fprintf('\n  lesion  MT d'' : %+.4f ± %.6f  (delta vs healthy %+.4f)\n', ...
    RL.dMt_mean, RL.dMt_std, RL.dMt_mean - R.dMt_mean);

fprintf('\nStep 1 harness ready. Step 2: enable pars.noise.site2 in shModel.\n');
