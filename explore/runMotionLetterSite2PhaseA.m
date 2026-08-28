% runMotionLetterSite2PhaseA  Site-2 noise Phase A: healthy/lesion × noise off/on.
%
% Full-field motion letter (same geometry as the deterministic baseline).
% Noise is independent, fixed σ, V1 normalization numerator only.
%
% Locked after the σ sweep (explore/_figs/site2_sigmaSweep/): σ = 0.05, N = 50.
% The first look (σ = 0.03, N = 20) is in explore/_figs/site2_phaseA/.
%
%   run explore/runMotionLetterSite2PhaseA.m
%
% Writes:
%   explore/_figs/site2_phaseA_sigma005_n50/
% Paste summary.txt into chat after it finishes.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER      = 'C';
SPEED_DEG_S = 1;
OUT_SZ      = [128 128 120];
DOT_SEED    = 7;             % same movie as runMotionLetterDeterministicBaseline
N_TRIALS    = 50;            % locked §1.4
SIGMA       = 0.05;          % locked after σ sweep 2026-08-28
NOISE_SEED  = 9000;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'site2_phaseA_sigma005_n50');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
parsL = lesionApply(parsH, 'amplitude_uniform');

cfgOff = noisePars('nTrials', 1, 'enabled', false, 'site2.enabled', false, ...
    'site2.sigma', SIGMA, 'noiseSeed', NOISE_SEED);
cfgOn  = noisePars('nTrials', N_TRIALS, 'enabled', true, 'site2.enabled', true, ...
    'site2.mode', 'fixed', 'site2.sigma', SIGMA, 'spatialCorrelation', 'none', ...
    'noiseSeed', NOISE_SEED);

fprintf('=== Site-2 Phase A ===\n');
fprintf('letter %s  %.2f deg/s  seed %d  stim [%d %d %d]  sigma %.3f  N=%d\n\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, stimSz(1), stimSz(2), stimSz(3), ...
    SIGMA, N_TRIALS);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

tWall = tic;

fprintf('[1/4] Healthy, noise off (1 trial)...\n');
R.healthyOff = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOff, ...
    'conditionLabel', 'healthy_off', 'runV1', false);

fprintf('[2/4] Lesion, noise off (1 trial)...\n');
R.lesionOff = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOff, ...
    'conditionLabel', 'lesion_off', 'runV1', false);

fprintf('[3/4] Healthy, Site-2 on (%d trials)...\n', N_TRIALS);
R.healthyOn = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOn, ...
    'conditionLabel', 'healthy_on', 'runV1', false);

fprintf('[4/4] Lesion, Site-2 on (%d trials)...\n', N_TRIALS);
R.lesionOn = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOn, ...
    'conditionLabel', 'lesion_on', 'runV1', false);

elapsedSec = toc(tWall);

meta = struct('letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'nTrials', N_TRIALS, 'sigma', SIGMA, ...
    'noiseSeed', NOISE_SEED, 'elapsedSec', elapsedSec, ...
    'site', 'V1 numerator (shModelV1Normalization_Tuned)', ...
    'stimInfo', stimInfo, 'cfgMl', cfgMl, 'cfgOn', cfgOn);

localWriteSummary(outDir, R, meta);
localWriteFigs(outDir, R);

resultsFile = fullfile(outDir, 'results.mat');
save(resultsFile, 'R', 'meta', 'stimInfo', 'cfgMl', '-v7.3');
fprintf('\nSaved:\n  %s\n  %s\n  %s\n  %s\n', ...
    resultsFile, ...
    fullfile(outDir, 'summary.txt'), ...
    fullfile(outDir, 'dprime_hist.png'), ...
    fullfile(outDir, 'mean_maps.png'));
fprintf('Wall time %.1f min. Paste summary.txt into chat.\n', elapsedSec / 60);

% ---- helpers ----
function localWriteSummary(outDir, R, meta)
lines = {};
lines{end+1} = sprintf('Site-2 Phase A  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  %.2f deg/s  out %s  dotSeed %d  sigma %.4f  N=%d', ...
    meta.letter, meta.speedDegS, mat2str(meta.outSz), meta.dotSeed, ...
    meta.sigma, meta.nTrials);
lines{end+1} = sprintf('noise in: %s', meta.site);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('%-14s %10s %10s %12s %12s', ...
    'condition', 'dMt_mean', 'dMt_std', 'ctrOpp_mean', 'ctrOpp_std');
rows = {R.healthyOff, R.lesionOff, R.healthyOn, R.lesionOn};
for i = 1:numel(rows)
    s = rows{i};
    lines{end+1} = sprintf('%-14s %10.4f %10.6f %12.4f %12.6f', ...
        s.conditionLabel, s.dMt_mean, s.dMt_std, ...
        s.centerOppMt_mean, s.centerOppMt_std); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = sprintf('Delta d'' (lesionOff - healthyOff) = %+.4f', ...
    R.lesionOff.dMt_mean - R.healthyOff.dMt_mean);
lines{end+1} = sprintf('Delta d'' (lesionOn  - healthyOn)  = %+.4f', ...
    R.lesionOn.dMt_mean - R.healthyOn.dMt_mean);
lines{end+1} = sprintf('Delta d'' (lesionOn  - lesionOff)  = %+.4f', ...
    R.lesionOn.dMt_mean - R.lesionOff.dMt_mean);
lines{end+1} = sprintf('SD d'' healthyOn / lesionOn = %.4f / %.4f', ...
    R.healthyOn.dMt_std, R.lesionOn.dMt_std);
lines{end+1} = '';
lines{end+1} = 'Step 0 checks:';
lines{end+1} = sprintf('  healthyOff d'' ≳ +1:  %s  (%.4f)', ...
    localYn(R.healthyOff.dMt_mean >= 1), R.healthyOff.dMt_mean);
lines{end+1} = sprintf('  lesionOn d'' < lesionOff:  %s', ...
    localYn(R.lesionOn.dMt_mean < R.lesionOff.dMt_mean));
lines{end+1} = sprintf('  lesionOn SD(d'') > healthyOff:  %s', ...
    localYn(R.lesionOn.dMt_std > R.healthyOff.dMt_std + 1e-12));
lines{end+1} = sprintf('  lesionOn SD(ctr) > healthyOff:  %s', ...
    localYn(R.lesionOn.centerOppMt_std > R.healthyOff.centerOppMt_std + 1e-12));
if isfield(R.lesionOn, 'Nmean_mean')
    lines{end+1} = sprintf('  mean N (healthyOn / lesionOn) = %.4g / %.4g', ...
        R.healthyOn.Nmean_mean, R.lesionOn.Nmean_mean);
    lines{end+1} = sprintf('  mean D (healthyOn / lesionOn) = %.4g / %.4g', ...
        R.healthyOn.Dmean_mean, R.lesionOn.Dmean_mean);
end
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function s = localYn(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end

function localWriteFigs(outDir, R)
fig1 = figure('Color', 'w', 'Position', [80 80 900 420], 'Visible', 'off');
subplot(1, 2, 1);
histogram(R.healthyOn.dMt_all, 12, 'Normalization', 'pdf', 'FaceAlpha', 0.55); hold on;
histogram(R.lesionOn.dMt_all, 12, 'Normalization', 'pdf', 'FaceAlpha', 0.55);
xline(R.healthyOff.dMt_mean, 'k-', 'LineWidth', 1.2);
xline(R.lesionOff.dMt_mean, 'k--', 'LineWidth', 1.2);
xlabel('MT d'''); ylabel('pdf');
legend({'healthy + noise', 'lesion + noise', 'healthy off', 'lesion off'}, ...
    'Location', 'best', 'FontSize', 8);
title('Trial d'' with Site-2 noise');
grid on;
subplot(1, 2, 2);
histogram(R.healthyOn.centerOppMt_all, 12, 'Normalization', 'pdf', 'FaceAlpha', 0.55); hold on;
histogram(R.lesionOn.centerOppMt_all, 12, 'Normalization', 'pdf', 'FaceAlpha', 0.55);
xlabel('center opponent'); ylabel('pdf');
title('Letter-region opponent');
grid on;
exportgraphics(fig1, fullfile(outDir, 'dprime_hist.png'), 'Resolution', 130);
close(fig1);

maps = {R.healthyOff.meanMtOpp, R.lesionOff.meanMtOpp, ...
        R.healthyOn.meanMtOpp,  R.lesionOn.meanMtOpp};
labs = {'healthy off', 'lesion off', 'healthy + noise (mean)', 'lesion + noise (mean)'};
clim = [min(cellfun(@(m) min(m(:)), maps)), max(cellfun(@(m) max(m(:)), maps))];
fig2 = figure('Color', 'w', 'Position', [80 80 1000 280], 'Visible', 'off');
for k = 1:4
    subplot(1, 4, k);
    imagesc(maps{k}, clim); axis image off; colormap(parula); colorbar;
    title(labs{k});
end
exportgraphics(fig2, fullfile(outDir, 'mean_maps.png'), 'Resolution', 130);
close(fig2);
end
