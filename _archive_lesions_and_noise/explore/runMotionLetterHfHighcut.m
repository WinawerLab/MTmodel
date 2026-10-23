% runMotionLetterHfHighcut  HF failure as a passband-unity high-cut.
%
% Not `hf_lowpass`. Frequency-domain Butterworth, H(0) = 1, no L1 renorm.
% Cutoff 0.05 cyc/frame sits between midget peak (~0.02) and parasol peak
% (~0.10), so it is the parasol-selective cut §3.1 asked for. Exponential
% τ = 2 and τ = 8 both *raised* letter d′.
%
% Conditions, same movie per speed:
%   healthy
%   amp_matched  — class-agnostic gain = mean L1 remaining after the cut
%   hf_cut       — lesionApply 'hf_highcut'
%
% HIT_MT is a signed drop. HIGH_SPEED requires a positive cost at 5 deg/s.
% Do not overwrite hf_failure/ or hf_failure_tau8/.
%
%   run explore/runMotionLetterHfHighcut.m
%
% Done 2026-08-31: +0.44 d' at 1 deg/s, −0.29 at 5. STILL_HELPS YES.
% HIGH_SPEED YES (real cost at 5). Wrong clinical end.
% Do not overwrite hf_failure/, hf_failure_tau8/, or hf_highcut/.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER       = 'C';
SPEEDS_DEG_S = [1, 5];
OUT_SZ       = [128 128 120];
DOT_SEED     = 7;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
oldVis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
visCleanup = onCleanup(@() set(0, 'DefaultFigureVisible', oldVis)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'hf_highcut');
if ~exist(outDir, 'dir'), mkdir(outDir); end

lp = lesionPars();
[~, parsH0] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(1), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

parsCut = lesionApply(parsH0, 'hf_highcut');
nC = numel(parsH0.rgc.classes);
ratios = zeros(1, nC);
for i = 1:nC
    s0 = sum(abs(parsH0.rgc.classes(i).temporalKernel(:)));
    s1 = sum(abs(parsCut.rgc.classes(i).temporalKernel(:)));
    ratios(i) = s1 / max(s0, eps);
end
kMatch = mean(ratios);
parsAmp = lesionApply(parsH0, 'amplitude_uniform', 'uniformGain', kMatch);

fprintf('=== High-frequency failure (passband-unity high-cut) ===\n');
fprintf('fc = %.3f cyc/frame  order %d  matched gain k = %.4f\n', ...
    lp.hfCutCycPerFrame, lp.hfCutOrder, kMatch);
fprintf('L1 remaining min/max across classes: %.3f / %.3f\n', min(ratios), max(ratios));
fprintf('speeds %s deg/s  letter %s  seed %d\n', mat2str(SPEEDS_DEG_S), LETTER, DOT_SEED);
fprintf('forwards = %d  (3 conditions x %d speeds x MT+V1). Not hf_lowpass.\n\n', ...
    3 * numel(SPEEDS_DEG_S) * 2, numel(SPEEDS_DEG_S));

localWriteKernelFig(outDir, parsH0, parsCut, lp);

condPars = {parsH0, parsAmp, parsCut};
condNames = {'healthy', 'amp_matched', 'hf_cut'};

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
    'dotSeed', DOT_SEED, 'hfCutCycPerFrame', lp.hfCutCycPerFrame, ...
    'hfCutOrder', lp.hfCutOrder, 'kMatch', kMatch, ...
    'l1Ratios', ratios, 'elapsedSec', elapsedSec);

localWriteSummary(outDir, R, meta);
localWriteBars(outDir, R, meta);
save(fullfile(outDir, 'results.mat'), 'R', 'meta', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function localWriteSummary(outDir, R, meta)
lines = {};
lines{end+1} = sprintf('High-frequency failure HIGHCUT  %s', datestr(now, 31));
lines{end+1} = sprintf('letter %s  seed %d  fc %.3f cyc/fr  order %d  matched gain %.4f', ...
    meta.letter, meta.dotSeed, meta.hfCutCycPerFrame, meta.hfCutOrder, meta.kMatch);
lines{end+1} = sprintf('elapsed %.1f min  (not hf_lowpass; H(0)=1, no L1)', ...
    meta.elapsedSec / 60);
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
    s = localPick(R, spd, 'hf_cut');
    dAmp = a.dMt - h.dMt;
    dCut = s.dMt - h.dMt;
    dropMt = h.dMt - s.dMt;
    dropAmp = h.dMt - a.dMt;
    dropV1 = h.dV1 - s.dV1;
    hit = (dropMt > 0.10) && (dropMt > max(dropAmp, 0) + 0.05);
    sel = dropMt > dropV1 + 0.05;
    lines{end+1} = sprintf('%.0f deg/s  Delta d'' MT  amp %+.3f  hf_cut %+.3f', ...
        spd, dAmp, dCut); %#ok<AGROW>
    lines{end+1} = sprintf('         HIT_MT (hf_cut drop >0.10 and > amp drop):  %s', ...
        localYn(hit)); %#ok<AGROW>
    lines{end+1} = sprintf('         SELECTIVE (MT cost > V1 cost, hf_cut):  %s', ...
        localYn(sel)); %#ok<AGROW>
end
h1 = localPick(R, meta.speedsDegS(1), 'healthy');
s1 = localPick(R, meta.speedsDegS(1), 'hf_cut');
h2 = localPick(R, meta.speedsDegS(end), 'healthy');
s2 = localPick(R, meta.speedsDegS(end), 'hf_cut');
drop1 = h1.dMt - s1.dMt;
drop5 = h2.dMt - s2.dMt;
if (s1.dMt - h1.dMt) > 0.10
    lines{end+1} = 'STILL_HELPS: YES — high-cut still raised d'' at 1 deg/s by >0.10.';
else
    lines{end+1} = 'STILL_HELPS: NO — high-cut did not raise the slow letter by >0.10.';
end
highOk = (drop5 > 0.10) && (drop5 > drop1 + 0.05);
lines{end+1} = sprintf('HIGH_SPEED (positive cost at %.0f larger than at %.0f):  %s', ...
    meta.speedsDegS(end), meta.speedsDegS(1), localYn(highOk));
lines{end+1} = '';
lines{end+1} = 'HIT_MT is a signed cost vs amp_matched. Not exponential hf_lowpass.';
lines{end+1} = 'Do not overwrite explore/_figs/hf_failure/ or hf_failure_tau8/.';
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

function localWriteKernelFig(outDir, parsH, parsC, lp)
names = {parsH.rgc.classes.name};
iP = find(strcmp(names, 'parasolOff_lag0'), 1);
iM = find(strcmp(names, 'midgetOff_lag0'), 1);
if isempty(iP), iP = 1; end
if isempty(iM), iM = min(2, numel(names)); end

fig = figure('Color', 'w', 'Position', [50 50 980 520], 'Visible', 'off');
pairs = {iP, 'parasolOff_lag0'; iM, 'midgetOff_lag0'};
NFFT = 512;
f = (0:NFFT/2) / NFFT;
H = 1 ./ (1 + (f / lp.hfCutCycPerFrame).^(2 * lp.hfCutOrder));
for p = 1:2
    k0 = parsH.rgc.classes(pairs{p, 1}).temporalKernel(:);
    k1 = parsC.rgc.classes(pairs{p, 1}).temporalKernel(:);
    subplot(2, 2, p);
    plot(0:numel(k0)-1, k0, 'k-', 'LineWidth', 1.3); hold on;
    plot(0:numel(k1)-1, k1, 'r-', 'LineWidth', 1.3);
    yline(0, 'k:');
    title(sprintf('%s  time', pairs{p, 2}));
    xlabel('frames'); ylabel('amp');
    legend({'healthy', 'hf_cut'}, 'Location', 'best', 'FontSize', 8);
    subplot(2, 2, p+2);
    a0 = abs(fft(k0, NFFT)); a0 = a0(1:NFFT/2+1);
    a1 = abs(fft(k1, NFFT)); a1 = a1(1:NFFT/2+1);
    plot(f, a0, 'k-', 'LineWidth', 1.3); hold on;
    plot(f, a1, 'r-', 'LineWidth', 1.3);
    plot(f, max(a0) * H, 'b--', 'LineWidth', 0.8);
    title(sprintf('%s  |A| (not peak-norm)', pairs{p, 2}));
    xlabel('cyc/frame'); xlim([0 0.5]);
    legend({'healthy', 'hf_cut', 'H(f) scale'}, 'Location', 'best', 'FontSize', 7);
end
exportgraphics(fig, fullfile(outDir, 'kernels.png'), 'Resolution', 130);
close(fig);
end

function localWriteBars(outDir, R, meta)
fig = figure('Color', 'w', 'Position', [50 50 980 420], 'Visible', 'off');
conds = {'healthy', 'amp_matched', 'hf_cut'};
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    dMt = zeros(1, 3);
    dV1 = zeros(1, 3);
    for iC = 1:3
        r = localPick(R, spd, conds{iC});
        dMt(iC) = r.dMt;
        dV1(iC) = r.dV1;
    end
    subplot(1, 2, iS);
    bar([dMt; dV1]');
    set(gca, 'XTick', 1:3, 'XTickLabel', conds);
    ylabel('d''');
    title(sprintf('%.0f deg/s  high-cut f_c=%.2f', spd, meta.hfCutCycPerFrame));
    legend({'MT', 'V1'}, 'Location', 'best');
    grid on;
end
exportgraphics(fig, fullfile(outDir, 'dprime_bars.png'), 'Resolution', 130);
close(fig);
end
