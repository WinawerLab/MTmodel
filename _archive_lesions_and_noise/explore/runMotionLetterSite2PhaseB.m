% runMotionLetterSite2PhaseB  Site-2 spatially correlated noise (survival check).
%
% Same movie and σ = 0.05 as the locked Phase A. Runs independent ('none') and
% gaussian spatial correlation (σ_corr px) on healthy and lesion. The question:
% does lesion+noise still have lower mean d' and higher SD than healthy+noise?
%
% The white field is drawn first, then optionally blurred, so independent and
% gaussian consume the same RNG per trial (paired).
%
%   run explore/runMotionLetterSite2PhaseB.m
%
% Writes explore/_figs/site2_phaseB_sigma005/
% First look done 2026-08-28 (N = 20): ranking survived. See
% docs/NOISE_TRIAL_DESIGN.md §3.6. Do not overwrite that folder without
% renaming it.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER      = 'C';
SPEED_DEG_S = 1;
OUT_SZ      = [128 128 120];
DOT_SEED    = 7;
N_TRIALS    = 20;            % first look; 50 matches the Phase A lock
SIGMA       = 0.05;          % locked Phase A
SIGMA_CORR  = 3;             % px; MT pooling (mkGaussianFilter(3)). V1 pool is identity.
NOISE_SEED  = 9000;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'site2_phaseB_sigma005');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
parsL = lesionApply(parsH, 'amplitude_uniform');

fprintf('=== Site-2 Phase B (spatial correlation) ===\n');
fprintf('letter %s  %.2f deg/s  seed %d  stim [%d %d %d]\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, stimSz(1), stimSz(2), stimSz(3));
fprintf('sigma %.3f  sigma_corr %.1f px  N=%d\n', SIGMA, SIGMA_CORR, N_TRIALS);
fprintf('forwards = %d  (2 off + 4 N)\n\n', 2 + 4 * N_TRIALS);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

cfgOff = noisePars('nTrials', 1, 'enabled', false, 'site2.enabled', false, ...
    'site2.sigma', SIGMA, 'noiseSeed', NOISE_SEED);

tWall = tic;

fprintf('[off] Healthy...\n');
R.healthyOff = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOff, ...
    'conditionLabel', 'healthy_off', 'runV1', false);
fprintf('[off] Lesion...\n');
R.lesionOff = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOff, ...
    'conditionLabel', 'lesion_off', 'runV1', false);

corrModes = {'none', 'gaussian'};
corrLabels = {'indep', 'gauss'};
for iC = 1:2
    mode = corrModes{iC};
    tag = corrLabels{iC};
    fprintf('\n--- correlation = %s ---\n', mode);
    cfgOn = noisePars('nTrials', N_TRIALS, 'enabled', true, 'site2.enabled', true, ...
        'site2.mode', 'fixed', 'site2.sigma', SIGMA, ...
        'spatialCorrelation', mode, 'spatialCorrSigmaPx', SIGMA_CORR, ...
        'noiseSeed', NOISE_SEED);
    fprintf('  healthy + noise...\n');
    R.(['healthy_' tag]) = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOn, ...
        'conditionLabel', ['healthy_' tag], 'runV1', false);
    fprintf('  lesion + noise...\n');
    R.(['lesion_' tag]) = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOn, ...
        'conditionLabel', ['lesion_' tag], 'runV1', false);
end

elapsedSec = toc(tWall);

meta = struct('letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'nTrials', N_TRIALS, 'sigma', SIGMA, ...
    'sigmaCorrPx', SIGMA_CORR, 'noiseSeed', NOISE_SEED, ...
    'elapsedSec', elapsedSec, 'cfgMl', cfgMl, 'stimInfo', stimInfo);

localWriteSummary(outDir, R, meta);
localWriteFigs(outDir, R);

save(fullfile(outDir, 'results.mat'), 'R', 'meta', 'stimInfo', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function localWriteSummary(outDir, R, meta)
lines = {};
lines{end+1} = sprintf('Site-2 Phase B  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  %.2f deg/s  out %s  dotSeed %d  sigma %.4f  sigma_corr %.1f px  N=%d', ...
    meta.letter, meta.speedDegS, mat2str(meta.outSz), meta.dotSeed, ...
    meta.sigma, meta.sigmaCorrPx, meta.nTrials);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('noise off:  healthy d''=%+.4f   lesion d''=%+.4f', ...
    R.healthyOff.dMt_mean, R.lesionOff.dMt_mean);
lines{end+1} = '';
lines{end+1} = sprintf('%-12s %10s %10s %10s %10s %10s %10s %10s %10s  %s', ...
    'corr', 'h_dMean', 'h_dStd', 'L_dMean', 'L_dStd', 'dMean_L-h', 'SD_L/h', ...
    'h_ctrSD', 'L_ctrSD', 'rank');
arms = {'indep', 'gauss'};
survives = true(1, 2);
for i = 1:2
    h = R.(['healthy_' arms{i}]);
    L = R.(['lesion_' arms{i}]);
    dMean = L.dMt_mean - h.dMt_mean;
    sdRatio = L.dMt_std / max(h.dMt_std, eps);
    okDrop = L.dMt_mean < h.dMt_mean;
    okSD = L.dMt_std > h.dMt_std;
    survives(i) = okDrop && okSD;
    rank = 'PASS';
    if ~survives(i), rank = 'FAIL'; end
    lines{end+1} = sprintf('%-12s %10.4f %10.4f %10.4f %10.4f %10.4f %10.3f %10.6f %10.6f  %s', ...
        arms{i}, h.dMt_mean, h.dMt_std, L.dMt_mean, L.dMt_std, ...
        dMean, sdRatio, h.centerOppMt_std, L.centerOppMt_std, rank); %#ok<AGROW>
end
lines{end+1} = '';
if survives(1) && survives(2)
    lines{end+1} = 'SURVIVAL: YES — gaussian correlation does not reverse the Phase A ranking.';
elseif survives(1) && ~survives(2)
    lines{end+1} = 'SURVIVAL: NO — independent passes, gaussian reverses or loses the ranking. Do not treat Phase A as final.';
else
    lines{end+1} = 'SURVIVAL: check table — independent arm unexpected.';
end
lines{end+1} = 'PASS = lesion mean d'' < healthy and lesion SD(d'') > healthy, for that correlation.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function localWriteFigs(outDir, R)
fig = figure('Color', 'w', 'Position', [60 60 1050 420], 'Visible', 'off');
subplot(1, 2, 1);
histogram(R.healthy_indep.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45); hold on;
histogram(R.lesion_indep.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
histogram(R.healthy_gauss.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
histogram(R.lesion_gauss.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
xlabel('MT d'''); ylabel('pdf');
legend({'healthy indep', 'lesion indep', 'healthy gauss', 'lesion gauss'}, ...
    'Location', 'best', 'FontSize', 8);
title('Trial d'' : independent vs gaussian');
grid on;

subplot(1, 2, 2);
names = {'indep', 'gauss'};
hMean = [R.healthy_indep.dMt_mean, R.healthy_gauss.dMt_mean];
LMean = [R.lesion_indep.dMt_mean, R.lesion_gauss.dMt_mean];
hStd = [R.healthy_indep.dMt_std, R.healthy_gauss.dMt_std];
LStd = [R.lesion_indep.dMt_std, R.lesion_gauss.dMt_std];
errorbar(1:2, hMean, hStd, 'o-', 'LineWidth', 1.4); hold on;
errorbar(1:2, LMean, LStd, 's-', 'LineWidth', 1.4);
set(gca, 'XTick', 1:2, 'XTickLabel', names);
xlabel('spatial correlation'); ylabel('MT d'' (mean \pm SD)');
legend({'healthy', 'lesion'}, 'Location', 'best');
title('Ranking must not reverse');
grid on; xlim([0.5 2.5]);

exportgraphics(fig, fullfile(outDir, 'phaseB_compare.png'), 'Resolution', 130);
close(fig);
end
