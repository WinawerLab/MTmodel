% runDelayRandomLowpassMtMix  delay_random on Fig-10 neurons + motion letter.
%
% The standing tension (TODO §2, report §4.7.5): desynchronised delay crushed
% high-pass speed tuning (−55% lagged, pre-mtMix) while the clinical deficit is
% at slow speeds. The Fig-10 low-pass neuron (0.0375–0.6 px/frame = 0.19–3
% deg/s) was never reported. This is that cell, through shPars('lagged') with
% mtMix on, seeded. delay_uniform is the control (size of delay vs desync).
%
% Deterministic. Noise off. Do not use compareLesionsToBaseline.m as-is: that
% script still builds the lagged preset by hand (single-stream).
%
%   run explore/runDelayRandomLowpassMtMix.m
%
% First look done 2026-08-29: SPARES_LOW YES (high-pass −77%, low-pass 0%).
% Letter d′ rose at 1 deg/s. See docs/MODEL_AND_LESIONS.md §4.7.5.
% Do not overwrite explore/_figs/delayRandom_lowpass_mtMix/ without renaming.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER       = 'C';
SPEEDS_DEG_S = [1, 5];       % low-pass band vs near the 1 px/frame tier
OUT_SZ       = [128 128 120];
DOT_SEED     = 7;
BAR_SEED     = 42;
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
oldVis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
visCleanup = onCleanup(@() set(0, 'DefaultFigureVisible', oldVis)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'delayRandom_lowpass_mtMix');
if ~exist(outDir, 'dir'), mkdir(outDir); end

u = shModelUnits();
kDeg = u.degPerSecPerPixelPerFrame;

[cfgMl, parsH, stimSzLetter] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(1), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

[~, ~, stimSz5] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(end), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

dBar = shGetDims(parsH, 'mtPattern', [15 15 71]);
fieldSize = max([dBar(1), dBar(2), stimSzLetter(1), stimSzLetter(2), ...
    stimSz5(1), stimSz5(2)]);

parsU = lesionApply(parsH, 'delay_uniform');
parsR = lesionApply(parsH, 'delay_random', 'fieldSize', fieldSize);

condNames = {'healthy', 'delay_uniform', 'delay_random'};
condPars  = {parsH, parsU, parsR};

nBarFwd = 3 * numel(condNames) * (6 * 2);   % neurons x conds x (pref+anti) x 6 speeds
nLetFwd = numel(condNames) * numel(SPEEDS_DEG_S);
fprintf('=== delay_random, low-pass neuron, two-stream MT ===\n');
fprintf('mtMix on  field %d  bar window [%d %d]  letter stim [%d %d %d]\n', ...
    fieldSize, dBar(1), dBar(2), stimSzLetter(1), stimSzLetter(2), stimSzLetter(3));
fprintf('delay_random seed %d  frames {%d–%d}\n', ...
    lesionPars().stochasticDelaySeed, lesionPars().stochasticDelayFrames);
fprintf('forwards ≈ %d bars + %d letters (MT only). Studio.\n\n', nBarFwd, nLetFwd);

tWall = tic;

%% Fig 10 speed tuning (all three neurons; low-pass is the open cell)
F10 = struct();
for iC = 1:numel(condNames)
    fprintf('[fig10] %s...\n', condNames{iC});
    rng(BAR_SEED);
    F10.(condNames{iC}) = localFig10(condPars{iC});
end

%% Motion letter at 1 and 5 deg/s, same dot seed, MT only
Letter = struct('speedDegS', {}, 'condition', {}, 'dMt', {}, 'centerOppMt', {});
nL = 0;
for iS = 1:numel(SPEEDS_DEG_S)
    spd = SPEEDS_DEG_S(iS);
    [cfgS, ~, stimSzS, stimArgsS] = motionLetterPars( ...
        'letter', LETTER, 'speedDegS', spd, 'outSz', OUT_SZ, ...
        'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');
    rng(cfgS.seed);
    [stim, stimInfo] = mkMotionLetter(stimSzS, cfgS.letter, stimArgsS{:});
    for iC = 1:numel(condNames)
        fprintf('[letter %.0f deg/s] %s...\n', spd, condNames{iC});
        parsC = lesionCropToStim(condPars{iC}, stimSzS(1), stimSzS(2));
        [popMt, indMt] = shModel(stim, parsC, 'mtPattern');
        m = motionLetterMetrics(popMt, indMt, [], [], parsC, stimInfo);
        nL = nL + 1;
        Letter(nL).speedDegS = spd;
        Letter(nL).condition = condNames{iC};
        Letter(nL).dMt = m.dMt;
        Letter(nL).centerOppMt = mean(m.mtOpp(m.mask), 'all');
        fprintf('        d'' = %+.4f\n', m.dMt);
    end
end

elapsedSec = toc(tWall);
lp = lesionPars();
meta = struct('letter', LETTER, 'speedsDegS', SPEEDS_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'barSeed', BAR_SEED, 'fieldSize', fieldSize, ...
    'dBar', dBar, 'kDeg', kDeg, 'mtMix', true, ...
    'stochasticDelaySeed', lp.stochasticDelaySeed, ...
    'stochasticDelayFrames', lp.stochasticDelayFrames, ...
    'uniformDelayFrames', lp.uniformDelayFrames, ...
    'elapsedSec', elapsedSec, 'neuronNames', {{'bandpass', 'lowpass', 'highpass'}}, ...
    'speedMinMaxPx', [.3125 5; .0375 .6; 1 10]);

localWriteSummary(outDir, F10, Letter, meta, condNames);
localWriteFigs(outDir, F10, Letter, meta, condNames, parsR);

save(fullfile(outDir, 'results.mat'), 'F10', 'Letter', 'meta', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function C = localFig10(parsFull)
% Crop once to the window shTuneBarSpeed requests ([15 15 71] -> ~51^2 pre-mtMix).
parsBar = lesionCropForCall(parsFull, 'mtPattern', [15 15 71]);
parsNull = lesionCropForCall(parsFull, 'mtPattern', [1 1 1]);
dims = shGetDims(parsNull, 'mtPattern');
neurons      = [0 1.5; 0 .125; 0 9];
speedMinMax  = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
n = 6;
C.x = zeros(3, n); C.pref = zeros(3, n);
C.anti = zeros(3, n); C.null = zeros(3, n);
figTune = figure('Visible', 'off'); %#ok<NASGU>
for k = 1:3
    [xs, yp] = shTuneBarSpeed(parsBar, neurons(k,:), 'mtPattern', n, ...
        speedMinMax(k,1), speedMinMax(k,2), neurons(k,1), 1, barEdgeWidth(k));
    [~,  ya] = shTuneBarSpeed(parsBar, neurons(k,:), 'mtPattern', n, ...
        speedMinMax(k,1), speedMinMax(k,2), neurons(k,1)+pi, 1, barEdgeWidth(k));
    [~, ind, rn] = shModel(zeros(dims), parsNull, 'mtPattern', neurons(k,:));
    C.x(k,:) = xs; C.pref(k,:) = yp; C.anti(k,:) = ya;
    C.null(k,:) = mean(shGetNeuron(rn, ind)) .* ones(1, n);
    fprintf('        neuron %d/3 done\n', k);
end
end

function localWriteSummary(outDir, F10, Letter, meta, condNames)
names = meta.neuronNames;
h = F10.healthy;
lines = {};
lines{end+1} = sprintf('delay_random low-pass / mtMix  %s', datestr(now, 31));
lines{end+1} = sprintf('shPars(''lagged'') mtMix on  field %d  bar [%d %d]', ...
    meta.fieldSize, meta.dBar(1), meta.dBar(2));
lines{end+1} = sprintf('letter %s  speeds %s deg/s  dotSeed %d  delay {%d–%d}  elapsed %.1f min', ...
    meta.letter, mat2str(meta.speedsDegS), meta.dotSeed, ...
    meta.stochasticDelayFrames(1), meta.stochasticDelayFrames(2), meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = 'Fig-10 preferred-direction peak (remaining = lesion / healthy):';
dropU = zeros(1, 3);
dropR = zeros(1, 3);
for k = 1:3
    pkH = max(h.pref(k,:));
    pkU = max(F10.delay_uniform.pref(k,:));
    pkR = max(F10.delay_random.pref(k,:));
    dropU(k) = 1 - pkU / max(pkH, eps);
    dropR(k) = 1 - pkR / max(pkH, eps);
    lines{end+1} = sprintf('  %-9s  healthy %.4g  uniform %.4g (%+.0f%%)  random %.4g (%+.0f%%)', ...
        names{k}, pkH, pkU, -100 * dropU(k), pkR, -100 * dropR(k)); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'Letter MT d'' (noise off):';
lines{end+1} = sprintf('%-8s  %12s  %12s  %12s', 'deg/s', condNames{:});
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    row = sprintf('%8.0f', spd);
    for iC = 1:numel(condNames)
        d = localLetterD(Letter, spd, condNames{iC});
        row = sprintf('%s  %12.4f', row, d);
    end
    lines{end+1} = row; %#ok<AGROW>
end
d1h = localLetterD(Letter, 1, 'healthy');
d1r = localLetterD(Letter, 1, 'delay_random');
d5h = localLetterD(Letter, 5, 'healthy');
d5r = localLetterD(Letter, 5, 'delay_random');
lines{end+1} = sprintf('letter Δd'' random−healthy:  1 deg/s %+.3f   5 deg/s %+.3f', ...
    d1r - d1h, d5r - d5h);
lines{end+1} = '';
hpDrop = dropR(3);
lpDrop = dropR(2);
hpOk = hpDrop > 0.20;
spares = hpOk && (lpDrop < 0.5 * hpDrop);
if ~hpOk
    lines{end+1} = 'SPARES_LOW: UNCLEAR — high-pass did not drop >20% (check mtMix vs §4.7.5).';
elseif spares
    lines{end+1} = 'SPARES_LOW: YES — low-pass drop < half of high-pass drop.';
    lines{end+1} = 'That would leave the clinical slow-speed deficit unexplained by delay_random.';
else
    lines{end+1} = 'SPARES_LOW: NO — low-pass was hit in proportion to (or more than) high-pass.';
end
lines{end+1} = 'SPARES_LOW needs high-pass drop >20% and low-pass drop < 0.5× that.';
lines{end+1} = 'Old lagged high-pass was −55% (pre-mtMix). delay_uniform should be ~0.';
txt = strjoin(lines, newline);
fid = fopen(fullfile(outDir, 'summary.txt'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
fprintf('\n---- summary.txt ----\n%s\n', txt);
end

function d = localLetterD(Letter, spd, name)
d = NaN;
for i = 1:numel(Letter)
    if Letter(i).speedDegS == spd && strcmp(Letter(i).condition, name)
        d = Letter(i).dMt;
        return;
    end
end
end

function localWriteFigs(outDir, F10, Letter, meta, condNames, parsR)
names = meta.neuronNames;
cols = [0.45 0.45 0.45; 0.20 0.45 0.75; 0.80 0.25 0.20];
fig = figure('Color', 'w', 'Position', [60 60 720 900], 'Visible', 'off');
for k = 1:3
    subplot(3, 1, k); hold on;
    ymax = 0;
    for iC = 1:numel(condNames)
        ymax = max(ymax, max(F10.(condNames{iC}).pref(k,:)));
    end
    for iC = 1:numel(condNames)
        C = F10.(condNames{iC});
        semilogx(C.x(k,:), C.pref(k,:), '-', 'Color', cols(iC,:), 'LineWidth', 1.6);
        semilogx(C.x(k,:), C.anti(k,:), '--', 'Color', cols(iC,:), 'LineWidth', 1.0);
    end
    set(gca, 'XScale', 'log');
    axis([F10.healthy.x(k,1), F10.healthy.x(k,end), 0, 1.2 * max(ymax, eps)]);
    title(sprintf('%s  (%.3g–%.3g px/frame = %.2g–%.2g deg/s)', ...
        names{k}, meta.speedMinMaxPx(k,1), meta.speedMinMaxPx(k,2), ...
        meta.kDeg * meta.speedMinMaxPx(k,1), meta.kDeg * meta.speedMinMaxPx(k,2)));
    xlabel('speed (px/frame)'); ylabel('response');
    if k == 1
        legend(condNames, 'Location', 'best', 'FontSize', 8);
    end
    grid on; box off;
end
exportgraphics(fig, fullfile(outDir, 'fig10_speed.png'), 'Resolution', 130);
close(fig);

figL = figure('Color', 'w', 'Position', [60 60 560 360], 'Visible', 'off');
spd = meta.speedsDegS;
y = zeros(numel(condNames), numel(spd));
for iC = 1:numel(condNames)
    for iS = 1:numel(spd)
        y(iC, iS) = localLetterD(Letter, spd(iS), condNames{iC});
    end
end
bar(spd, y');
set(gca, 'XTick', spd);
xlabel('letter speed (deg/s)'); ylabel('MT d''');
legend(condNames, 'Location', 'best');
title('Motion letter (noise off)');
grid on; box off;
exportgraphics(figL, fullfile(outDir, 'letter_dprime.png'), 'Resolution', 130);
close(figL);

if isfield(parsR.rgc, 'impairmentDelayFieldFull') && ~isempty(parsR.rgc.impairmentDelayFieldFull)
    figM = figure('Color', 'w', 'Position', [60 60 420 360], 'Visible', 'off');
    imagesc(parsR.rgc.impairmentDelayFieldFull);
    axis image off; colorbar;
    title(sprintf('delay_random map (%d px, frames 0–3)', meta.fieldSize));
    exportgraphics(figM, fullfile(outDir, 'delay_map.png'), 'Resolution', 130);
    close(figM);
end
end
