% runMotionLetterSite2SigmaSweep  Choose Site-2 σ (V1 only, independent noise).
%
% Same movie as Phase A / the deterministic baseline. Noise-off arms run once.
% Each σ gets healthy+noise and lesion+noise at N_TRIALS.
%
%   run explore/runMotionLetterSite2SigmaSweep.m
%
% Pick σ where (a) lesion+noise still has higher SD than healthy+noise,
% (b) mean d' drops more under lesion than healthy, (c) healthy+noise is
% not destroyed. Then lock N=50 at that σ (runMotionLetterSite2PhaseA with
% SIGMA and N_TRIALS edited).
%
% Writes explore/_figs/site2_sigmaSweep/  (gitignored; Drive-sync to share)
% Paste summary.txt into chat when done.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER      = 'C';
SPEED_DEG_S = 1;
OUT_SZ      = [128 128 120];
DOT_SEED    = 7;
N_TRIALS    = 15;                    % enough to rank σ; not the N=50 lock
SIGMAS      = [0.03 0.05 0.08];      % 0.03 = Phase A
NOISE_SEED  = 9000;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'site2_sigmaSweep');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
parsL = lesionApply(parsH, 'amplitude_uniform');

fprintf('=== Site-2 σ sweep ===\n');
fprintf('letter %s  %.2f deg/s  seed %d  stim [%d %d %d]\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, stimSz(1), stimSz(2), stimSz(3));
fprintf('N=%d  sigmas %s\n', N_TRIALS, mat2str(SIGMAS));
fprintf('forwards ≈ %d  (2 off + 2 N per σ)\n\n', 2 + 2 * numel(SIGMAS) * N_TRIALS);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

cfgOff = noisePars('nTrials', 1, 'enabled', false, 'site2.enabled', false, ...
    'noiseSeed', NOISE_SEED);

tWall = tic;

fprintf('[off] Healthy...\n');
healthyOff = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOff, ...
    'conditionLabel', 'healthy_off', 'runV1', false);
fprintf('[off] Lesion...\n');
lesionOff = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOff, ...
    'conditionLabel', 'lesion_off', 'runV1', false);

nS = numel(SIGMAS);
sweep = struct('sigma', num2cell(SIGMAS), 'healthyOn', [], 'lesionOn', []);

for iS = 1:nS
    sig = SIGMAS(iS);
    fprintf('\n--- σ = %.3f  (%d/%d) ---\n', sig, iS, nS);
    cfgOn = noisePars('nTrials', N_TRIALS, 'enabled', true, 'site2.enabled', true, ...
        'site2.mode', 'fixed', 'site2.sigma', sig, 'spatialCorrelation', 'none', ...
        'noiseSeed', NOISE_SEED);
    fprintf('  healthy + noise...\n');
    sweep(iS).healthyOn = motionLetterTrials(stim, stimInfo, parsH, cfgMl, cfgOn, ...
        'conditionLabel', sprintf('healthy_on_s%.3f', sig), 'runV1', false);
    fprintf('  lesion + noise...\n');
    sweep(iS).lesionOn = motionLetterTrials(stim, stimInfo, parsL, cfgMl, cfgOn, ...
        'conditionLabel', sprintf('lesion_on_s%.3f', sig), 'runV1', false);
end

elapsedSec = toc(tWall);

meta = struct('letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'nTrials', N_TRIALS, 'sigmas', SIGMAS, ...
    'noiseSeed', NOISE_SEED, 'elapsedSec', elapsedSec, ...
    'stimInfo', stimInfo, 'cfgMl', cfgMl);

localWriteSummary(outDir, healthyOff, lesionOff, sweep, meta);
localWriteFigs(outDir, healthyOff, lesionOff, sweep, SIGMAS);

save(fullfile(outDir, 'results.mat'), 'healthyOff', 'lesionOff', 'sweep', ...
    'meta', 'stimInfo', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

% ---- helpers ----
function localWriteSummary(outDir, healthyOff, lesionOff, sweep, meta)
lines = {};
lines{end+1} = sprintf('Site-2 σ sweep  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  %.2f deg/s  out %s  dotSeed %d  N=%d', ...
    meta.letter, meta.speedDegS, mat2str(meta.outSz), meta.dotSeed, meta.nTrials);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('noise off:  healthy d''=%+.4f   lesion d''=%+.4f   delta=%+.4f', ...
    healthyOff.dMt_mean, lesionOff.dMt_mean, ...
    lesionOff.dMt_mean - healthyOff.dMt_mean);
lines{end+1} = '';
hdr = sprintf('%-8s %10s %10s %10s %10s %10s %10s %8s %8s', ...
    'sigma', 'h_dMean', 'h_dStd', 'L_dMean', 'L_dStd', 'dMean_L-h', 'SD_L/h', ...
    'rankSD', 'rankDrop');
lines{end+1} = hdr;
for i = 1:numel(sweep)
    h = sweep(i).healthyOn;
    L = sweep(i).lesionOn;
    dMean = L.dMt_mean - h.dMt_mean;
    sdRatio = L.dMt_std / max(h.dMt_std, eps);
    rankSD = L.dMt_std > h.dMt_std;
    rankDrop = L.dMt_mean < h.dMt_mean;
    healthyOk = h.dMt_mean >= 1.0;
    lines{end+1} = sprintf('%-8.3f %10.4f %10.4f %10.4f %10.4f %10.4f %10.3f %8s %8s', ...
        sweep(i).sigma, h.dMt_mean, h.dMt_std, L.dMt_mean, L.dMt_std, ...
        dMean, sdRatio, localYn(rankSD), localYn(rankDrop)); %#ok<AGROW>
    lines{end+1} = sprintf('         healthy d'' ≳ 1: %s (%.3f)   ctr SD h/L = %.4f / %.4f', ...
        localYn(healthyOk), h.dMt_mean, h.centerOppMt_std, L.centerOppMt_std); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'Pick σ: rankSD=YES, rankDrop=YES, healthy d'' still ≳ 1.';
lines{end+1} = 'Prefer the smallest such σ that also clearly separates SDs.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function s = localYn(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end

function localWriteFigs(outDir, healthyOff, lesionOff, sweep, sigmas)
nS = numel(sweep);
hMean = zeros(1, nS); hStd = zeros(1, nS);
LMean = zeros(1, nS); LStd = zeros(1, nS);
hCtr = zeros(1, nS); LCtr = zeros(1, nS);
for i = 1:nS
    hMean(i) = sweep(i).healthyOn.dMt_mean;
    hStd(i)  = sweep(i).healthyOn.dMt_std;
    LMean(i) = sweep(i).lesionOn.dMt_mean;
    LStd(i)  = sweep(i).lesionOn.dMt_std;
    hCtr(i)  = sweep(i).healthyOn.centerOppMt_std;
    LCtr(i)  = sweep(i).lesionOn.centerOppMt_std;
end

fig = figure('Color', 'w', 'Position', [60 60 1050 420], 'Visible', 'off');
subplot(1, 2, 1);
errorbar(sigmas, hMean, hStd, 'o-', 'LineWidth', 1.4); hold on;
errorbar(sigmas, LMean, LStd, 's-', 'LineWidth', 1.4);
yline(healthyOff.dMt_mean, 'k-');
yline(lesionOff.dMt_mean, 'k--');
xlabel('\sigma (Site-2)'); ylabel('MT d'' (mean \pm SD)');
legend({'healthy + noise', 'lesion + noise', 'healthy off', 'lesion off'}, ...
    'Location', 'best', 'FontSize', 8);
title('Mean d'' vs \sigma'); grid on;

subplot(1, 2, 2);
plot(sigmas, hStd, 'o-', 'LineWidth', 1.4); hold on;
plot(sigmas, LStd, 's-', 'LineWidth', 1.4);
plot(sigmas, hCtr, 'o--');
plot(sigmas, LCtr, 's--');
xlabel('\sigma (Site-2)'); ylabel('trial SD');
legend({'SD(d'') healthy', 'SD(d'') lesion', 'SD(ctr) healthy', 'SD(ctr) lesion'}, ...
    'Location', 'northwest', 'FontSize', 8);
title('Trial SD vs \sigma'); grid on;

exportgraphics(fig, fullfile(outDir, 'sweep.png'), 'Resolution', 130);
close(fig);
end
