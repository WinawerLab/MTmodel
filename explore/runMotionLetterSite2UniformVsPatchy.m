% runMotionLetterSite2UniformVsPatchy  Uniform vs patchy amplitude + gaussian Site-2.
%
% Same movie and noise as Phase B (σ = 0.05, σ_corr = 3 px, gaussian). The
% question (NOISE §5.1): do matched-mean uniform and patchy amplitude lesions
% diverge once Site-2 noise is on? They should look interchangeable with noise
% off (report §4.7.4).
%
% Both lesions are spatial maps (impairmentAmplitudeMap), not the Phase A/B
% class-gain cut. Uniform is a constant map set to the mean of the patchy map
% so the only difference is spatial structure. patchySigma = 3 px matches
% σ_corr and MT pooling. V1's own pool is identity. They did not diverge;
% neither did the MT arm (§3.10). Do not drop the §5.1 claim.
%
%   run explore/runMotionLetterSite2UniformVsPatchy.m
%
% First look done 2026-08-29: DIVERGE NO. MT arm also DIVERGE NO
% (docs/NOISE_TRIAL_DESIGN.md §3.8, §3.10). Do not overwrite
% explore/_figs/site2_uniformVsPatchy_sigma005/ without renaming.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER      = 'C';
SPEED_DEG_S = 1;
OUT_SZ      = [128 128 120];
DOT_SEED    = 7;
N_TRIALS    = 20;            % first look
SIGMA       = 0.05;          % locked Phase A
SIGMA_CORR  = 3;             % px; gaussian Site-2 (Phase B)
NOISE_SEED  = 9000;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'site2_uniformVsPatchy_sigma005');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

fieldSize = max(stimSz(1:2));
parsP = lesionApply(parsH, 'amplitude_patchy', 'fieldSize', fieldSize);
parsP = lesionCropToStim(parsP, stimSz(1), stimSz(2));
mapP = parsP.rgc.impairmentAmplitudeMap;
meanGain = mean(mapP(:));
parsU = lesionApply(parsH, 'amplitude_uniform_map', ...
    'stimSize', stimSz(1:2), 'uniformGain', meanGain);
mapU = parsU.rgc.impairmentAmplitudeMap;

fprintf('=== Site-2 uniform vs patchy (gaussian) ===\n');
fprintf('letter %s  %.2f deg/s  seed %d  stim [%d %d %d]  field %d\n', ...
    cfgMl.letter, cfgMl.speedDegS, cfgMl.seed, stimSz(1), stimSz(2), stimSz(3), fieldSize);
fprintf('sigma %.3f  sigma_corr %.1f px  N=%d  matched mean gain %.4f\n', ...
    SIGMA, SIGMA_CORR, N_TRIALS, meanGain);
fprintf('patchy map min/max %.3f / %.3f\n', min(mapP(:)), max(mapP(:)));
fprintf('forwards = %d  (3 off + 3 N)\n\n', 3 + 3 * N_TRIALS);

rng(cfgMl.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});

cfgOff = noisePars('nTrials', 1, 'enabled', false, 'site2.enabled', false, ...
    'site2.sigma', SIGMA, 'noiseSeed', NOISE_SEED);
cfgOn = noisePars('nTrials', N_TRIALS, 'enabled', true, 'site2.enabled', true, ...
    'site2.mode', 'fixed', 'site2.sigma', SIGMA, ...
    'spatialCorrelation', 'gaussian', 'spatialCorrSigmaPx', SIGMA_CORR, ...
    'noiseSeed', NOISE_SEED);

conds = { ...
    'healthy', parsH; ...
    'uniform', parsU; ...
    'patchy',  parsP};
arms = {'Off', 'On'};
cfgs = {cfgOff, cfgOn};

tWall = tic;
R = struct();
for iC = 1:size(conds, 1)
    name = conds{iC, 1};
    parsC = conds{iC, 2};
    for iA = 1:2
        tag = [name arms{iA}];
        fprintf('[%s] %s...\n', arms{iA}, name);
        R.(tag) = motionLetterTrials(stim, stimInfo, parsC, cfgMl, cfgs{iA}, ...
            'conditionLabel', tag, 'runV1', false);
    end
end
elapsedSec = toc(tWall);

lp = lesionPars();
meta = struct('letter', LETTER, 'speedDegS', SPEED_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'nTrials', N_TRIALS, 'sigma', SIGMA, ...
    'sigmaCorrPx', SIGMA_CORR, 'noiseSeed', NOISE_SEED, ...
    'fieldSize', fieldSize, 'meanGain', meanGain, ...
    'patchySigma', lp.patchySigma, 'patchyAmpRange', lp.patchyAmpRange, ...
    'patchySeed', lp.patchySeed, 'elapsedSec', elapsedSec, ...
    'cfgMl', cfgMl, 'stimInfo', stimInfo, 'mapU', mapU, 'mapP', mapP);

localWriteSummary(outDir, R, meta);
localWriteFigs(outDir, R, meta);

save(fullfile(outDir, 'results.mat'), 'R', 'meta', 'stimInfo', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function localWriteSummary(outDir, R, meta)
lines = {};
lines{end+1} = sprintf('Site-2 uniform vs patchy  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  %.2f deg/s  out %s  stim padded  dotSeed %d', ...
    meta.letter, meta.speedDegS, mat2str(meta.outSz), meta.dotSeed);
lines{end+1} = sprintf('sigma %.4f  sigma_corr %.1f px  gaussian  N=%d  mean gain %.4f  patchySigma %.1f', ...
    meta.sigma, meta.sigmaCorrPx, meta.nTrials, meta.meanGain, meta.patchySigma);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('%-12s %10s %10s %12s %12s', ...
    'condition', 'dMt_mean', 'dMt_std', 'ctrOpp_mean', 'ctrOpp_std');
names = {'healthyOff', 'uniformOff', 'patchyOff', 'healthyOn', 'uniformOn', 'patchyOn'};
for i = 1:numel(names)
    s = R.(names{i});
    lines{end+1} = sprintf('%-12s %10.4f %10.6f %12.4f %12.6f', ...
        s.conditionLabel, s.dMt_mean, s.dMt_std, ...
        s.centerOppMt_mean, s.centerOppMt_std); %#ok<AGROW>
end
gapOff = abs(R.uniformOff.dMt_mean - R.patchyOff.dMt_mean);
gapOn  = abs(R.uniformOn.dMt_mean - R.patchyOn.dMt_mean);
sdOff  = abs(R.uniformOff.dMt_std - R.patchyOff.dMt_std);
sdOn   = abs(R.uniformOn.dMt_std - R.patchyOn.dMt_std);
lines{end+1} = '';
lines{end+1} = sprintf('|d'' uniform - patchy|  off = %.4f   on = %.4f', gapOff, gapOn);
lines{end+1} = sprintf('|SD  uniform - patchy|  off = %.4f   on = %.4f', sdOff, sdOn);
lines{end+1} = sprintf('d'' vs healthy (on): uniform %+.4f   patchy %+.4f', ...
    R.uniformOn.dMt_mean - R.healthyOn.dMt_mean, ...
    R.patchyOn.dMt_mean - R.healthyOn.dMt_mean);
lines{end+1} = '';
diverge = gapOn > gapOff + 0.10;
if diverge
    lines{end+1} = 'DIVERGE: YES — noise-on gap exceeds noise-off gap by > 0.10 d′.';
else
    lines{end+1} = 'DIVERGE: NO — uniform and patchy still match under gaussian Site-2.';
    lines{end+1} = 'If NO: V1 pool is identity (mkGaussianFilter(-1)). Try MT Site-2';
    lines{end+1} = 'before dropping NOISE §5.1.';
end
lines{end+1} = 'DIVERGE = |d′_uniform - d′_patchy| on > off + 0.10.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function localWriteFigs(outDir, R, meta)
figM = figure('Color', 'w', 'Position', [60 60 720 300], 'Visible', 'off');
subplot(1, 2, 1);
imagesc(meta.mapU, [min(meta.mapP(:)), max(meta.mapP(:))]);
axis image off; colormap(gray); colorbar;
title(sprintf('uniform (gain %.3f)', meta.meanGain));
subplot(1, 2, 2);
imagesc(meta.mapP, [min(meta.mapP(:)), max(meta.mapP(:))]);
axis image off; colormap(gray); colorbar;
title(sprintf('patchy (\\sigma = %.1f px)', meta.patchySigma));
exportgraphics(figM, fullfile(outDir, 'amp_maps.png'), 'Resolution', 130);
close(figM);

fig = figure('Color', 'w', 'Position', [60 60 1050 420], 'Visible', 'off');
subplot(1, 2, 1);
histogram(R.healthyOn.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45); hold on;
histogram(R.uniformOn.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
histogram(R.patchyOn.dMt_all, 10, 'Normalization', 'pdf', 'FaceAlpha', 0.45);
xlabel('MT d'''); ylabel('pdf');
legend({'healthy', 'uniform', 'patchy'}, 'Location', 'best', 'FontSize', 8);
title('Trial d'' (gaussian Site-2)');
grid on;

subplot(1, 2, 2);
names = {'off', 'on'};
hMean = [R.healthyOff.dMt_mean, R.healthyOn.dMt_mean];
uMean = [R.uniformOff.dMt_mean, R.uniformOn.dMt_mean];
pMean = [R.patchyOff.dMt_mean,  R.patchyOn.dMt_mean];
hStd  = [R.healthyOff.dMt_std,  R.healthyOn.dMt_std];
uStd  = [R.uniformOff.dMt_std,  R.uniformOn.dMt_std];
pStd  = [R.patchyOff.dMt_std,   R.patchyOn.dMt_std];
errorbar(1:2, hMean, hStd, 'o-', 'LineWidth', 1.4); hold on;
errorbar(1:2, uMean, uStd, 's-', 'LineWidth', 1.4);
errorbar(1:2, pMean, pStd, 'd-', 'LineWidth', 1.4);
set(gca, 'XTick', 1:2, 'XTickLabel', names);
xlabel('Site-2 noise'); ylabel('MT d'' (mean \pm SD)');
legend({'healthy', 'uniform', 'patchy'}, 'Location', 'best');
title('Should diverge only with noise on');
grid on; xlim([0.5 2.5]);

exportgraphics(fig, fullfile(outDir, 'uniform_vs_patchy.png'), 'Resolution', 130);
close(fig);
end
