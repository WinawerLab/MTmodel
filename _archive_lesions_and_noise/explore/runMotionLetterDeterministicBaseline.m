% runMotionLetterDeterministicBaseline  Two full-field forwards, noise off.
%
% Locks the §1.4 geometry (letter C, 1 deg/s, lagged + mtMix, 128^2) with
% ONE healthy MT pass and ONE amplitude_uniform (gain 0.5) pass on the SAME
% movie. Do not use motionLetterBenchmarkTrials (N=50) until Site-2 noise exists.
%
% On MATLAB:
%   run explore/runMotionLetterDeterministicBaseline.m
%
% Writes explore/_figs/motionLetter_deterministicBaseline.mat (gitignored).
% See docs/NOISE_TRIAL_DESIGN.md §1.4.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% CONFIG
LETTER      = 'C';
SPEED_DEG_S = 1;              % 0.2 px/frame at 10 px/deg, 50 fps
OUT_SZ      = [128 128 120];  % model output; stim will be larger (RF pad)
SEED        = 7;              % same as the Step 1 smoke test
MT_MIX      = true;

%%
warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'seed', SEED, 'mtMix', MT_MIX, 'rgcPreset', 'lagged');

fprintf('=== Deterministic baseline (2 MT forwards, noise off) ===\n');
fprintf('letter %s   %.2f deg/s   seed %d   out %s   stim [%d %d %d]\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, mat2str(cfgMl.outSz), ...
    stimSz(1), stimSz(2), stimSz(3));
fprintf('preset %s   mtMix %d\n\n', cfgMl.rgcPreset, cfgMl.mtMix);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});
fprintf('stimulus: %.4f px/frame, letter %d px, %d dots\n\n', ...
    stimInfo.dotSpeedPxPerFrame, stimInfo.letterSizePx, stimInfo.numDots);

fprintf('[1/2] Healthy...\n');
tic;
[popH, indH] = shModel(stim, parsH, 'mtPattern');
mH = motionLetterTrialMetrics(popH, indH, [], [], parsH, stimInfo);
tH = toc;
fprintf('      MT d'' = %+.4f   center opp = %+.4f   (%.1f s)\n\n', ...
    mH.dMt, mH.centerOppMt, tH);

fprintf('[2/2] amplitude_uniform (gain 0.5), same movie...\n');
parsL = lesionApply(parsH, 'amplitude_uniform');
tic;
[popL, indL] = shModel(stim, parsL, 'mtPattern');
mL = motionLetterTrialMetrics(popL, indL, [], [], parsL, stimInfo);
tL = toc;
fprintf('      MT d'' = %+.4f   center opp = %+.4f   (%.1f s)\n\n', ...
    mL.dMt, mL.centerOppMt, tL);

fprintf('Delta (lesion - healthy)  d'' %+.4f   center opp %+.4f\n', ...
    mL.dMt - mH.dMt, mL.centerOppMt - mH.centerOppMt);
fprintf('Expect: healthy d'' typically ≳ +1; lesion drop modest (normalization).\n');

outDir = fullfile(repoRoot, 'explore', '_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end
outFile = fullfile(outDir, 'motionLetter_deterministicBaseline.mat');
save(outFile, 'cfgMl', 'stimInfo', 'mH', 'mL', 'tH', 'tL');
fprintf('\nSaved %s\n', outFile);
fprintf('Done. Next: Step 2 (Site-2 noise). Do not run N=50 until then.\n');
