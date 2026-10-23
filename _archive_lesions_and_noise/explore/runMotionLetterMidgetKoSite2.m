% runMotionLetterMidgetKoSite2  Midget knockout + V1 Site-2 (letter 1 vs 5 deg/s).
%
% Deterministic midget gain 0 cost only −0.21 d′ at 1 deg/s (report §4.5).
% That is the amplitude-cut pattern: small mean shift until Site-2 noise is
% on. This is that read. Gaussian V1 Site-2 (σ = 0.05, σ_corr = 3 px, N = 20).
% MT Site-2 off. Same movie per speed (dot seed 7).
%
%   run explore/runMotionLetterMidgetKoSite2.m
%
% First look done 2026-08-29: NOISE_AMPLIFIES NO (gap 0.210 off / 0.215 on).
% See docs/NOISE_TRIAL_DESIGN.md §3.12. Do not overwrite
% explore/_figs/midgetKo_site2_sigma005/ without renaming.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER       = 'C';
SPEEDS_DEG_S = [1, 5];
OUT_SZ       = [128 128 120];
DOT_SEED     = 7;
N_TRIALS     = 20;           % first look
SIGMA        = 0.05;         % Phase A lock
SIGMA_CORR   = 3;            % px; gaussian (Phase B)
NOISE_SEED   = 9000;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'midgetKo_site2_sigma005');
if ~exist(outDir, 'dir'), mkdir(outDir); end

nFwd = numel(SPEEDS_DEG_S) * (2 + 2 * N_TRIALS);
fprintf('=== Midget knockout + V1 Site-2 (gaussian) ===\n');
fprintf('letter %s  speeds %s deg/s  sigma %.3f  sigma_corr %.1f px  N=%d\n', ...
    LETTER, mat2str(SPEEDS_DEG_S), SIGMA, SIGMA_CORR, N_TRIALS);
fprintf('MT Site-2 OFF. forwards = %d  (2 off + 2 N per speed).\n\n', nFwd);

cfgOff = noisePars('nTrials', 1, 'enabled', false, ...
    'site2.enabled', false, 'mtSite2.enabled', false, ...
    'site2.sigma', SIGMA, 'noiseSeed', NOISE_SEED);
cfgOn = noisePars('nTrials', N_TRIALS, 'enabled', true, ...
    'site2.enabled', true, 'mtSite2.enabled', false, ...
    'site2.mode', 'fixed', 'site2.sigma', SIGMA, ...
    'spatialCorrelation', 'gaussian', 'spatialCorrSigmaPx', SIGMA_CORR, ...
    'noiseSeed', NOISE_SEED);

tWall = tic;
S = struct('speedDegS', {}, 'healthyOff', {}, 'midgetOff', {}, ...
    'healthyOn', {}, 'midgetOn', {});

for iS = 1:numel(SPEEDS_DEG_S)
    spd = SPEEDS_DEG_S(iS);
    [cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
        'letter', LETTER, 'speedDegS', spd, 'outSz', OUT_SZ, ...
        'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
    parsM = lesionApply(parsH, 'amplitude_midget', 'cellTypeGain', 0);
    rng(cfgMl.seed);
    [stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});
    fprintf('--- %.0f deg/s  stim [%d %d %d] ---\n', spd, stimSz(1), stimSz(2), stimSz(3));

    fprintf('[off] healthy...\n');
    hOff = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOff, ...
        'conditionLabel', sprintf('h%.0f_off', spd), 'runV1', false);
    fprintf('[off] midget_ko...\n');
    mOff = motionLetterTrials(stim, stimInfo, parsM, cfgMl, cfgOff, ...
        'conditionLabel', sprintf('m%.0f_off', spd), 'runV1', false);
    fprintf('[on]  healthy...\n');
    hOn = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOn, ...
        'conditionLabel', sprintf('h%.0f_on', spd), 'runV1', false);
    fprintf('[on]  midget_ko...\n');
    mOn = motionLetterTrials(stim, stimInfo, parsM, cfgMl, cfgOn, ...
        'conditionLabel', sprintf('m%.0f_on', spd), 'runV1', false);

    S(iS).speedDegS = spd;
    S(iS).healthyOff = hOff;
    S(iS).midgetOff = mOff;
    S(iS).healthyOn = hOn;
    S(iS).midgetOn = mOn;
    S(iS).stimInfo = stimInfo;
    S(iS).cfgMl = cfgMl;
end

elapsedSec = toc(tWall);
meta = struct('letter', LETTER, 'speedsDegS', SPEEDS_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'nTrials', N_TRIALS, 'sigma', SIGMA, ...
    'sigmaCorrPx', SIGMA_CORR, 'noiseSeed', NOISE_SEED, ...
    'elapsedSec', elapsedSec);

localWriteSummary(outDir, S, meta);
localWriteFigs(outDir, S, meta);

cfgMl = S(1).cfgMl; %#ok<NASGU>
stimInfo = S(1).stimInfo; %#ok<NASGU>
save(fullfile(outDir, 'results.mat'), 'S', 'meta', 'stimInfo', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function localWriteSummary(outDir, S, meta)
lines = {};
lines{end+1} = sprintf('Midget knockout + V1 Site-2  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  speeds %s deg/s  out %s  dotSeed %d', ...
    meta.letter, mat2str(meta.speedsDegS), mat2str(meta.outSz), meta.dotSeed);
lines{end+1} = sprintf('V1 gaussian  sigma %.4f  sigma_corr %.1f px  N=%d  MT Site-2 OFF', ...
    meta.sigma, meta.sigmaCorrPx, meta.nTrials);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('%-6s %-8s %10s %10s %10s %10s', ...
    'deg/s', 'noise', 'h_dMean', 'h_dStd', 'm_dMean', 'm_dStd');
dropOff = zeros(1, numel(S));
dropOn = zeros(1, numel(S));
for iS = 1:numel(S)
    h0 = S(iS).healthyOff; m0 = S(iS).midgetOff;
    h1 = S(iS).healthyOn;  m1 = S(iS).midgetOn;
    dropOff(iS) = h0.dMt_mean - m0.dMt_mean;
    dropOn(iS)  = h1.dMt_mean - m1.dMt_mean;
    spd = S(iS).speedDegS;
    lines{end+1} = sprintf('%6.0f %-8s %10.4f %10.4f %10.4f %10.4f', ...
        spd, 'off', h0.dMt_mean, h0.dMt_std, m0.dMt_mean, m0.dMt_std); %#ok<AGROW>
    lines{end+1} = sprintf('%6.0f %-8s %10.4f %10.4f %10.4f %10.4f', ...
        spd, 'on', h1.dMt_mean, h1.dMt_std, m1.dMt_mean, m1.dMt_std); %#ok<AGROW>
    lines{end+1} = sprintf('       drop (h−m)  off %+.3f   on %+.3f   SD ratio on %.2f', ...
        dropOff(iS), dropOn(iS), m1.dMt_std / max(h1.dMt_std, eps)); %#ok<AGROW>
end
lines{end+1} = '';
i1 = find([S.speedDegS] == 1, 1);
i5 = find([S.speedDegS] == 5, 1);
if dropOn(i1) > dropOff(i1) + 0.10
    lines{end+1} = 'NOISE_AMPLIFIES: YES — Site-2 widened the 1 deg/s healthy−midget gap.';
else
    lines{end+1} = 'NOISE_AMPLIFIES: NO — 1 deg/s gap did not grow by >0.10 with noise on.';
end
if dropOn(i1) > dropOn(i5) + 0.10
    lines{end+1} = 'SLOW_MORE: YES — noise-on gap larger at 1 deg/s than at 5.';
else
    lines{end+1} = 'SLOW_MORE: NO — noise-on gap is not larger at 1 deg/s than at 5 by >0.10.';
end
rankOk = S(i1).midgetOn.dMt_mean < S(i1).healthyOn.dMt_mean;
if rankOk
    lines{end+1} = 'RANK_1: YES — midget+noise mean d′ < healthy+noise at 1 deg/s.';
else
    lines{end+1} = 'RANK_1: NO — midget+noise mean is not below healthy+noise at 1 deg/s.';
end
lines{end+1} = 'NOISE_AMPLIFIES / SLOW_MORE use (healthy − midget) mean d′, not |Δ|.';
lines{end+1} = 'Deterministic 1 deg/s drop was −0.21 (report §4.5). Phase B healthy+gauss ~2.86.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function localWriteFigs(outDir, S, meta)
fig = figure('Color', 'w', 'Position', [60 60 1050 420], 'Visible', 'off');
subplot(1, 2, 1);
i1 = find([S.speedDegS] == 1, 1);
histogram(S(i1).healthyOn.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45); hold on;
histogram(S(i1).midgetOn.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
xlabel('MT d'''); ylabel('pdf');
legend({'healthy', 'midget_ko'}, 'Location', 'best', 'FontSize', 8);
title('Trial d'' at 1 deg/s (Site-2 on)');
grid on;

subplot(1, 2, 2);
spd = [S.speedDegS];
hOff = [S.healthyOff];
mOff = [S.midgetOff];
hOn  = [S.healthyOn];
mOn  = [S.midgetOn];
errorbar(spd - 0.08, [hOff.dMt_mean], [hOff.dMt_std], 'o-', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.3); hold on;
errorbar(spd - 0.08, [mOff.dMt_mean], [mOff.dMt_std], 's--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.3);
errorbar(spd + 0.08, [hOn.dMt_mean], [hOn.dMt_std], 'o-', 'Color', [0.80 0.25 0.20], 'LineWidth', 1.3);
errorbar(spd + 0.08, [mOn.dMt_mean], [mOn.dMt_std], 's--', 'Color', [0.80 0.25 0.20], 'LineWidth', 1.3);
set(gca, 'XTick', spd);
xlabel('letter speed (deg/s)'); ylabel('MT d'' (mean \pm SD)');
legend({'healthy off', 'midget off', 'healthy on', 'midget on'}, ...
    'Location', 'best', 'FontSize', 8);
title('Site-2 should widen the 1 deg/s gap');
grid on; xlim([min(spd)-0.6, max(spd)+0.6]);
exportgraphics(fig, fullfile(outDir, 'dprime.png'), 'Resolution', 130);
close(fig);
end
