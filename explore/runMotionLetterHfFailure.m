% runMotionLetterHfFailure  High-frequency failure as a change in filter shape.
%
% Deterministic. No Site-2 noise. A causal exponential low-pass is applied to
% every RGC temporalKernel (lesionApply 'hf_lowpass'). That is not a gain and
% not a whole-frame shift (NOISE §3.1 / §5.3).
%
% Conditions, same movie per speed:
%   healthy
%   amp_matched   — class-agnostic gain = mean L1 remaining after low-pass
%                   without renormalization ("same average size")
%   hf_shape      — low-pass, L1-renormalized (shape only)
%   hf_raw        — low-pass, no renorm (shape + energy drop)
%
% Speeds: 1 deg/s (Phase A geometry) and 5 deg/s (1 px/frame). The prediction
% is that HF hits MT harder than the matched amplitude cut, and more at the
% high speed (the wrong clinical end). Also run v1Complex: §5.3 says the
% lesion should be selective for MT.
%
%   run explore/runMotionLetterHfFailure.m
%
% First look done 2026-08-29 (τ = 2): raised d′, not a deficit. See
% docs/NOISE_TRIAL_DESIGN.md §3.9. Printed HIT_MT used |Δd′| — do not quote it.
% Do not overwrite explore/_figs/hf_failure/ without renaming.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER       = 'C';
SPEEDS_DEG_S = [1, 5];
OUT_SZ       = [128 128 120];
DOT_SEED     = 7;
HF_TAU       = 2;            % frames; first look, not locked
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'hf_failure');
if ~exist(outDir, 'dir'), mkdir(outDir); end

[~, parsH0] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(1), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

parsShape = lesionApply(parsH0, 'hf_lowpass', 'hfTauFrames', HF_TAU, 'hfRenorm', true);
parsRaw   = lesionApply(parsH0, 'hf_lowpass', 'hfTauFrames', HF_TAU, 'hfRenorm', false);
nC = numel(parsH0.rgc.classes);
ratios = zeros(1, nC);
for i = 1:nC
    s0 = sum(abs(parsH0.rgc.classes(i).temporalKernel(:)));
    s1 = sum(abs(parsRaw.rgc.classes(i).temporalKernel(:)));
    ratios(i) = s1 / max(s0, eps);
end
kMatch = mean(ratios);
parsAmp = lesionApply(parsH0, 'amplitude_uniform', 'uniformGain', kMatch);

fprintf('=== High-frequency failure (filter shape) ===\n');
fprintf('tau = %.1f frames  matched gain k = %.4f  (mean L1 remaining, no renorm)\n', ...
    HF_TAU, kMatch);
fprintf('L1 remaining min/max across classes: %.3f / %.3f\n', min(ratios), max(ratios));
fprintf('speeds %s deg/s  letter %s  seed %d\n', mat2str(SPEEDS_DEG_S), LETTER, DOT_SEED);
fprintf('forwards = %d  (4 conditions x %d speeds x MT+V1)\n\n', ...
    4 * numel(SPEEDS_DEG_S) * 2, numel(SPEEDS_DEG_S));

localWriteKernelFig(outDir, parsH0, parsShape, HF_TAU);

condPars = {parsH0, parsAmp, parsShape, parsRaw};
condNames = {'healthy', 'amp_matched', 'hf_shape', 'hf_raw'};

tWall = tic;
R = struct('speedDegS', {}, 'condition', {}, 'dMt', {}, 'dV1', {}, ...
    'centerOppMt', {}, 'centerOppV1', {});
nR = 0;
for iS = 1:numel(SPEEDS_DEG_S)
    spd = SPEEDS_DEG_S(iS);
    [cfgMl, ~, stimSz, stimArgs] = motionLetterPars( ...
        'letter', LETTER, 'speedDegS', spd, 'outSz', OUT_SZ, ...
        'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
    rng(cfgMl.seed);
    [stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});
    fprintf('--- %.2f deg/s  stim [%d %d %d] ---\n', spd, stimSz(1), stimSz(2), stimSz(3));
    for iC = 1:numel(condNames)
        parsC = condPars{iC};
        fprintf('  [%s] MT+V1...\n', condNames{iC});
        [popMt, indMt] = shModel(stim, parsC, 'mtPattern');
        [popV1, indV1] = shModel(stim, parsC, 'v1Complex');
        m = motionLetterTrialMetrics(popMt, indMt, popV1, indV1, parsC, stimInfo);
        nR = nR + 1;
        R(nR).speedDegS = spd;
        R(nR).condition = condNames{iC};
        R(nR).dMt = m.dMt;
        R(nR).dV1 = m.dV1;
        R(nR).centerOppMt = m.centerOppMt;
        R(nR).centerOppV1 = m.centerOppV1;
        fprintf('        d'' MT %+.3f   V1 %+.3f\n', m.dMt, m.dV1);
    end
end
elapsedSec = toc(tWall);

meta = struct('letter', LETTER, 'speedsDegS', SPEEDS_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'hfTauFrames', HF_TAU, 'kMatch', kMatch, ...
    'l1Ratios', ratios, 'elapsedSec', elapsedSec);

localWriteSummary(outDir, R, meta);
localWriteBars(outDir, R, meta);
save(fullfile(outDir, 'results.mat'), 'R', 'meta', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function localWriteSummary(outDir, R, meta)
lines = {};
lines{end+1} = sprintf('High-frequency failure  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  seed %d  tau %.1f frames  matched gain %.4f', ...
    meta.letter, meta.dotSeed, meta.hfTauFrames, meta.kMatch);
lines{end+1} = sprintf('elapsed %.1f min', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('%-8s %-12s %10s %10s %12s %12s', ...
    'deg/s', 'condition', 'dMt', 'dV1', 'ctrMt', 'ctrV1');
for i = 1:numel(R)
    lines{end+1} = sprintf('%-8.2f %-12s %10.4f %10.4f %12.4f %12.4f', ...
        R(i).speedDegS, R(i).condition, R(i).dMt, R(i).dV1, ...
        R(i).centerOppMt, R(i).centerOppV1); %#ok<AGROW>
end
lines{end+1} = '';
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    h = localPick(R, spd, 'healthy');
    a = localPick(R, spd, 'amp_matched');
    s = localPick(R, spd, 'hf_shape');
    raw = localPick(R, spd, 'hf_raw');
    dAmp = a.dMt - h.dMt;
    dSh  = s.dMt - h.dMt;
    dRaw = raw.dMt - h.dMt;
    hit = abs(dSh) > abs(dAmp);
    sel = abs(s.dMt - h.dMt) > abs(s.dV1 - h.dV1);
    lines{end+1} = sprintf('%.0f deg/s  Delta d'' MT  amp %+.3f  hf_shape %+.3f  hf_raw %+.3f', ...
        spd, dAmp, dSh, dRaw); %#ok<AGROW>
    lines{end+1} = sprintf('         HIT_MT ( |hf_shape| > |amp| ):  %s', localYn(hit)); %#ok<AGROW>
    lines{end+1} = sprintf('         SELECTIVE (MT drop > V1 drop, hf_shape):  %s', localYn(sel)); %#ok<AGROW>
end
h1 = localPick(R, meta.speedsDegS(1), 'healthy');
s1 = localPick(R, meta.speedsDegS(1), 'hf_shape');
h2 = localPick(R, meta.speedsDegS(end), 'healthy');
s2 = localPick(R, meta.speedsDegS(end), 'hf_shape');
highEnd = abs(s2.dMt - h2.dMt) > abs(s1.dMt - h1.dMt);
lines{end+1} = sprintf('HIGH_SPEED (hf_shape drop larger at %.0f than %.0f deg/s):  %s', ...
    meta.speedsDegS(end), meta.speedsDegS(1), localYn(highEnd));
lines{end+1} = '';
lines{end+1} = 'HIT_MT is the §5.3 prediction. HIGH_SPEED is the §3.1 caution';
lines{end+1} = '(wrong clinical end). Shape-only vs amp_matched is the fair test;';
lines{end+1} = 'hf_raw is the same energy drop plus the shape change.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function r = localPick(R, spd, name)
ix = find([R.speedDegS] == spd & strcmp({R.condition}, name), 1);
r = R(ix);
end

function s = localYn(tf)
if tf, s = 'YES'; else, s = 'NO'; end
end

function localWriteKernelFig(outDir, parsH, parsS, tau)
names = {parsH.rgc.classes.name};
iP = find(strcmp(names, 'parasolOff_lag0'), 1);
iM = find(strcmp(names, 'midgetOff_lag0'), 1);
if isempty(iP), iP = 1; end
if isempty(iM), iM = min(2, numel(names)); end

fig = figure('Color', 'w', 'Position', [50 50 980 520], 'Visible', 'off');
pairs = {iP, 'parasolOff_lag0'; iM, 'midgetOff_lag0'};
NFFT = 512;
f = (0:NFFT/2) / NFFT;
for p = 1:2
    k0 = parsH.rgc.classes(pairs{p, 1}).temporalKernel(:);
    k1 = parsS.rgc.classes(pairs{p, 1}).temporalKernel(:);
    subplot(2, 2, p);
    plot(0:numel(k0)-1, k0, 'k-', 'LineWidth', 1.3); hold on;
    plot(0:numel(k1)-1, k1, 'r-', 'LineWidth', 1.3);
    yline(0, 'k:');
    title(sprintf('%s  time', pairs{p, 2}));
    xlabel('frames'); ylabel('amp');
    legend({'healthy', sprintf('hf \\tau=%.1f', tau)}, 'Location', 'best', 'FontSize', 8);
    subplot(2, 2, p+2);
    a0 = abs(fft(k0, NFFT)); a0 = a0(1:NFFT/2+1);
    a1 = abs(fft(k1, NFFT)); a1 = a1(1:NFFT/2+1);
    plot(f, a0 / max(a0), 'k-', 'LineWidth', 1.3); hold on;
    plot(f, a1 / max(max(a1), eps), 'r-', 'LineWidth', 1.3);
    title(sprintf('%s  |A| (peak-norm)', pairs{p, 2}));
    xlabel('cyc/frame'); xlim([0 0.5]);
end
exportgraphics(fig, fullfile(outDir, 'kernels.png'), 'Resolution', 130);
close(fig);
end

function localWriteBars(outDir, R, meta)
fig = figure('Color', 'w', 'Position', [50 50 980 420], 'Visible', 'off');
conds = {'healthy', 'amp_matched', 'hf_shape', 'hf_raw'};
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    dMt = zeros(1, 4);
    dV1 = zeros(1, 4);
    for iC = 1:4
        r = localPick(R, spd, conds{iC});
        dMt(iC) = r.dMt;
        dV1(iC) = r.dV1;
    end
    subplot(1, 2, iS);
    bar([dMt; dV1]');
    set(gca, 'XTick', 1:4, 'XTickLabel', conds);
    ylabel('d''');
    title(sprintf('%.0f deg/s', spd));
    legend({'MT', 'V1'}, 'Location', 'best');
    grid on;
end
exportgraphics(fig, fullfile(outDir, 'dprime_bars.png'), 'Resolution', 130);
close(fig);
end
