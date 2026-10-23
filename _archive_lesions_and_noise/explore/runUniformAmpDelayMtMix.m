% runUniformAmpDelayMtMix  Uniform amplitude AND uniform delay (independent).
%
% The missing matrix cell (TODO §2, report §4.7.1): gain 0.5 on all classes
% plus a 2-frame delay on every kernel. Not `coupled` (that ties spatial
% maps). Deterministic. Noise off. shPars('lagged') with mtMix.
%
% Conditions, same movie per speed:
%   healthy
%   amplitude_uniform   — gain 0.5 (normalization should absorb most of this)
%   delay_uniform       — +2 frames (should be invisible to steady-state d′)
%   both                — lesionApply 'amplitude_delay_uniform'
%
%   run explore/runUniformAmpDelayMtMix.m
%
% Done 2026-08-31: DELAY_NULL YES, BOTH_IS_AMP YES, SUPERADDITIVE NO.
% Letter at 1 deg/s: amp −0.087, both −0.061. See report §4.7.8.
% Do not overwrite explore/_figs/uniformAmpDelay_mtMix/ without renaming.

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

outDir = fullfile(repoRoot, 'explore', '_figs', 'uniformAmpDelay_mtMix');
if ~exist(outDir, 'dir'), mkdir(outDir); end

lp = lesionPars();
[~, parsH0] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(1), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
parsA = lesionApply(parsH0, 'amplitude_uniform');
parsD = lesionApply(parsH0, 'delay_uniform');
parsB = lesionApply(parsH0, 'amplitude_delay_uniform');

condNames = {'healthy', 'amp', 'delay', 'both'};
condPars  = {parsH0, parsA, parsD, parsB};

nFwd = numel(condNames) * numel(SPEEDS_DEG_S);
fprintf('=== Uniform amplitude + uniform delay (independent, mtMix) ===\n');
fprintf('gain %.2f  delay +%d frames  letter %s  speeds %s deg/s  seed %d\n', ...
    lp.uniformGain, lp.uniformDelayFrames, LETTER, mat2str(SPEEDS_DEG_S), DOT_SEED);
fprintf('forwards = %d  (4 conditions x %d speeds, MT only). Not coupled.\n\n', ...
    nFwd, numel(SPEEDS_DEG_S));

tWall = tic;
R = struct('speedDegS', {}, 'condition', {}, 'dMt', {}, 'centerOppMt', {});
nR = 0;
for iS = 1:numel(SPEEDS_DEG_S)
    spd = SPEEDS_DEG_S(iS);
    [cfgMl, ~, stimSz, stimArgs] = motionLetterPars( ...
        'letter', LETTER, 'speedDegS', spd, 'outSz', OUT_SZ, ...
        'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
    rng(cfgMl.seed);
    [stim, stimInfo] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});
    fprintf('--- %.0f deg/s  stim [%d %d %d] ---\n', spd, stimSz(1), stimSz(2), stimSz(3));
    for iC = 1:numel(condNames)
        fprintf('[%s]...\n', condNames{iC});
        [popMt, indMt] = shModel(stim, condPars{iC}, 'mtPattern');
        m = motionLetterMetrics(popMt, indMt, [], [], condPars{iC}, stimInfo);
        nR = nR + 1;
        R(nR).speedDegS = spd;
        R(nR).condition = condNames{iC};
        R(nR).dMt = m.dMt;
        R(nR).centerOppMt = mean(m.mtOpp(m.mask), 'all');
        fprintf('        d'' = %+.4f\n', m.dMt);
    end
end

elapsedSec = toc(tWall);
meta = struct('letter', LETTER, 'speedsDegS', SPEEDS_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'uniformGain', lp.uniformGain, ...
    'uniformDelayFrames', lp.uniformDelayFrames, 'elapsedSec', elapsedSec);

localWriteSummary(outDir, R, meta, condNames);
localWriteFigs(outDir, R, meta, condNames);

save(fullfile(outDir, 'results.mat'), 'R', 'meta', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function d = localD(R, spd, name)
d = NaN;
for i = 1:numel(R)
    if R(i).speedDegS == spd && strcmp(R(i).condition, name)
        d = R(i).dMt;
        return;
    end
end
end

function localWriteSummary(outDir, R, meta, condNames)
lines = {};
lines{end+1} = sprintf('Uniform amp + delay (independent)  %s', datestr(now, 31));
lines{end+1} = sprintf('gain %.2f  +%d frames  letter %s  speeds %s deg/s  dotSeed %d', ...
    meta.uniformGain, meta.uniformDelayFrames, meta.letter, ...
    mat2str(meta.speedsDegS), meta.dotSeed);
lines{end+1} = sprintf('elapsed %.1f min  (not coupled)', meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = sprintf('%-8s  %10s  %10s  %10s  %10s', 'deg/s', condNames{:});
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    row = sprintf('%8.0f', spd);
    for iC = 1:numel(condNames)
        row = sprintf('%s  %10.4f', row, localD(R, spd, condNames{iC}));
    end
    lines{end+1} = row; %#ok<AGROW>
end
h1 = localD(R, 1, 'healthy');
a1 = localD(R, 1, 'amp');
d1 = localD(R, 1, 'delay');
b1 = localD(R, 1, 'both');
h5 = localD(R, 5, 'healthy');
a5 = localD(R, 5, 'amp');
d5 = localD(R, 5, 'delay');
b5 = localD(R, 5, 'both');
lines{end+1} = sprintf('Δ vs healthy at 1:  amp %+.3f   delay %+.3f   both %+.3f', ...
    a1 - h1, d1 - h1, b1 - h1);
lines{end+1} = sprintf('Δ vs healthy at 5:  amp %+.3f   delay %+.3f   both %+.3f', ...
    a5 - h5, d5 - h5, b5 - h5);
lines{end+1} = sprintf('both − amp at 1: %+.3f   (delay added on top of gain 0.5)', b1 - a1);
lines{end+1} = '';
if abs(d1 - h1) < 0.10 && abs(d5 - h5) < 0.10
    lines{end+1} = 'DELAY_NULL: YES — uniform delay still invisible to letter d′.';
else
    lines{end+1} = 'DELAY_NULL: NO — uniform delay moved letter d′ by ≥0.10.';
end
if abs(b1 - a1) < 0.10
    lines{end+1} = 'BOTH_IS_AMP: YES — adding uniform delay does not change the gain-0.5 letter.';
else
    lines{end+1} = 'BOTH_IS_AMP: NO — combined lesion differs from amplitude-only by ≥0.10 at 1 deg/s.';
end
addPred = (h1 - a1) + (h1 - d1);
if (h1 - b1) > addPred + 0.10
    lines{end+1} = 'SUPERADDITIVE: YES — both costs more than amp drop + delay drop.';
else
    lines{end+1} = 'SUPERADDITIVE: NO — both is not worse than the sum of the two singles.';
end
lines{end+1} = 'This is the independent-uniform cell. Do not call it coupled.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function localWriteFigs(outDir, R, meta, condNames)
spd = meta.speedsDegS;
y = zeros(numel(condNames), numel(spd));
for iC = 1:numel(condNames)
    for iS = 1:numel(spd)
        y(iC, iS) = localD(R, spd(iS), condNames{iC});
    end
end
fig = figure('Color', 'w', 'Position', [60 60 560 360], 'Visible', 'off');
bar(spd, y');
set(gca, 'XTick', spd);
xlabel('letter speed (deg/s)'); ylabel('MT d''');
legend(condNames, 'Location', 'best');
title('Uniform amp, delay, and both (noise off)');
grid on; box off;
exportgraphics(fig, fullfile(outDir, 'letter_dprime.png'), 'Resolution', 130);
close(fig);
end
