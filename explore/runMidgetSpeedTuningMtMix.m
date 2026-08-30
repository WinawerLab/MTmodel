% runMidgetSpeedTuningMtMix  Unconfound report §4.5 (midget cost vs speed).
%
% §4.5 found midget knockout hits slow MT units 10–30× more than fast ones,
% but every unit was probed with the same grating (optimal for the slow
% neuron). This is the proper test: each MT neuron's own speed tuning, dots
% in that neuron's preferred direction, shPars('lagged') with mtMix.
%
% Conditions (noise off):
%   healthy     — default alpha = 0.10
%   midget_ko   — midget class gain 0 (retinal; stream A is unchanged)
%   magno_only  — alpha = 0 (no stream B; not a cell-type lesion)
%
% Same 7-neuron probe as measureMtSpeedTuning (1 static + 3 per moving
% tier). Motion letter at 1 and 5 deg/s is the clinical read-out.
%
%   run explore/runMidgetSpeedTuningMtMix.m
%
% First look done 2026-08-29: GRADIENT YES (−61% at 0 px/fr vs −1% at 6).
% SLOW_LETTER YES but modest (−0.21 d′ at 1 deg/s). See report §4.5.
% Do not overwrite explore/_figs/midget_speed_mtMix/ without renaming.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% ======================== CONFIG ========================================
LETTER       = 'C';
SPEEDS_DEG_S = [1, 5];
OUT_SZ       = [128 128 120];
DOT_SEED     = 7;            % letter movie
TUNE_SEED    = 1000;         % rng(TUNE_SEED*n + si) per speed point
NF           = 71;
N_SPEED      = 13;           % log2 grid 0.125 .. 16 px/frame
%% ========================================================================

warnState = warning('off', 'motionLetterMetrics:speedMismatch');
warnCleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
oldVis = get(0, 'DefaultFigureVisible');
set(0, 'DefaultFigureVisible', 'off');
visCleanup = onCleanup(@() set(0, 'DefaultFigureVisible', oldVis)); %#ok<NASGU>

outDir = fullfile(repoRoot, 'explore', '_figs', 'midget_speed_mtMix');
if ~exist(outDir, 'dir'), mkdir(outDir); end

u = shModelUnits();
kDeg = u.degPerSecPerPixelPerFrame;
speedPx = 2 .^ linspace(-3, 4, N_SPEED);

[cfgMl, parsH] = motionLetterPars( ...
    'letter', LETTER, 'speedDegS', SPEEDS_DEG_S(1), 'outSz', OUT_SZ, ...
    'seed', DOT_SEED, 'mtMix', true, 'rgcPreset', 'lagged');

parsM = lesionApply(parsH, 'amplitude_midget', 'cellTypeGain', 0);
parsA = parsH;
parsA.rgc.mtMix.alpha = 0;

condNames = {'healthy', 'midget_ko', 'magno_only'};
condPars  = {parsH, parsM, parsA};

V = parsH.mtPopulationVelocities;
nomSpeeds = [0 1 6];
probe = [];
for nv = nomSpeeds
    g = find(abs(V(:,2) - nv) < 1e-9);
    if nv == 0
        pick = g(1);
    else
        pick = g(round(linspace(1, numel(g), 3)));
    end
    probe = [probe; pick(:)]; %#ok<AGROW>
end
probe = unique(probe, 'stable');

dims = shGetDims(parsH, 'mtPattern', [25 25 NF]);
nTune = numel(probe) * numel(speedPx) * numel(condNames);
nLet  = numel(condNames) * numel(SPEEDS_DEG_S);
fprintf('=== midget vs speed, two-stream MT (unconfound §4.5) ===\n');
fprintf('alpha healthy = %.2f  midget_ko gain = 0  magno_only alpha = 0\n', ...
    parsH.rgc.mtMix.alpha);
fprintf('probe neurons %s  dims [%d %d %d]  %d speeds\n', ...
    mat2str(probe'), dims(1), dims(2), dims(3), numel(speedPx));
fprintf('forwards = %d speed + %d letter (MT only). Studio.\n\n', nTune, nLet);

tWall = tic;
Tune = struct();
for iC = 1:numel(condNames)
    fprintf('[%s] speed curves...\n', condNames{iC});
    Tune.(condNames{iC}) = localSpeedCurves(condPars{iC}, V, probe, ...
        speedPx, dims, TUNE_SEED);
end

Letter = struct('speedDegS', {}, 'condition', {}, 'dMt', {});
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
        [popMt, indMt] = shModel(stim, condPars{iC}, 'mtPattern');
        m = motionLetterMetrics(popMt, indMt, [], [], condPars{iC}, stimInfo);
        nL = nL + 1;
        Letter(nL).speedDegS = spd;
        Letter(nL).condition = condNames{iC};
        Letter(nL).dMt = m.dMt;
        fprintf('        d'' = %+.4f\n', m.dMt);
    end
end

elapsedSec = toc(tWall);
meta = struct('letter', LETTER, 'speedsDegS', SPEEDS_DEG_S, 'outSz', OUT_SZ, ...
    'dotSeed', DOT_SEED, 'tuneSeed', TUNE_SEED, 'kDeg', kDeg, ...
    'speedPx', speedPx, 'probe', probe, 'V', V, 'nomSpeeds', nomSpeeds, ...
    'dims', dims, 'alphaHealthy', parsH.rgc.mtMix.alpha, ...
    'elapsedSec', elapsedSec);

localWriteSummary(outDir, Tune, Letter, meta, condNames);
localWriteFigs(outDir, Tune, Letter, meta, condNames);

save(fullfile(outDir, 'results.mat'), 'Tune', 'Letter', 'meta', 'cfgMl', '-v7.3');
fprintf('\nSaved %s  (%.1f min). Paste summary.txt into chat.\n', outDir, elapsedSec / 60);

function C = localSpeedCurves(pars, V, probe, speedPx, dims, tuneSeed)
nP = numel(probe);
nS = numel(speedPx);
C.curves = nan(nP, nS);
C.prefPx = nan(nP, 1);
C.peak = nan(nP, 1);
for k = 1:nP
    n = probe(k);
    for si = 1:nS
        rng(tuneSeed * n + si);
        s = mkDots(dims, V(n,1), speedPx(si), 0.12, 1, 3, 'exact');
        [pop, ind] = shModel(s, pars, 'mtPattern');
        C.curves(k, si) = mean(shGetNeuron(pop, ind, n), 'all');
    end
    C.prefPx(k) = localParabolaPeak(speedPx, C.curves(k,:));
    C.peak(k) = max(C.curves(k,:));
    fprintf('        neuron %d (%d/%d)  pref %.3g px/fr  peak %.4g\n', ...
        n, k, nP, C.prefPx(k), C.peak(k));
end
end

function pref = localParabolaPeak(speedPx, c)
[~, i0] = max(c);
if i0 > 1 && i0 < numel(speedPx)
    x = log2(speedPx(i0-1:i0+1));
    y = c(i0-1:i0+1);
    d = y(1) - 2*y(2) + y(3);
    if d ~= 0
        pref = 2 ^ (x(2) + 0.5*(y(1)-y(3))/d * (x(2)-x(1)));
    else
        pref = speedPx(i0);
    end
else
    pref = speedPx(i0);
end
end

function localWriteSummary(outDir, Tune, Letter, meta, condNames)
h = Tune.healthy;
m = Tune.midget_ko;
a = Tune.magno_only;
lines = {};
lines{end+1} = sprintf('midget vs speed / mtMix  %s', datestr(now, 31));
lines{end+1} = sprintf('shPars(''lagged'')  alpha healthy = %.2f  probe %s', ...
    meta.alphaHealthy, mat2str(meta.probe'));
lines{end+1} = sprintf('letter %s  speeds %s deg/s  elapsed %.1f min', ...
    meta.letter, mat2str(meta.speedsDegS), meta.elapsedSec / 60);
lines{end+1} = '';
lines{end+1} = 'Peak remaining vs healthy (same neuron, own speed curve):';
lines{end+1} = sprintf('%-6s %-8s %10s %12s %12s', ...
    'neuron', 'nomPx', 'healthy', 'midget_ko', 'magno_only');
dropM = zeros(numel(meta.probe), 1);
dropA = zeros(numel(meta.probe), 1);
for k = 1:numel(meta.probe)
    n = meta.probe(k);
    dropM(k) = 1 - m.peak(k) / max(h.peak(k), eps);
    dropA(k) = 1 - a.peak(k) / max(h.peak(k), eps);
    lines{end+1} = sprintf('%-6d %-8g %10.4g %8.4g (%+.0f%%) %8.4g (%+.0f%%)', ...
        n, meta.V(n,2), h.peak(k), m.peak(k), -100*dropM(k), ...
        a.peak(k), -100*dropA(k)); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'Median peak drop by nominal tier (midget_ko / magno_only):';
dropSlowM = NaN; dropFastM = NaN;
for nv = meta.nomSpeeds
    sel = abs(meta.V(meta.probe, 2) - nv) < 1e-9;
    medM = median(dropM(sel));
    medA = median(dropA(sel));
    if nv == 0, dropSlowM = medM; end
    if nv == 6, dropFastM = medM; end
    lines{end+1} = sprintf('  nominal %g px/fr (%g deg/s):  midget_ko %+.0f%%   magno_only %+.0f%%', ...
        nv, nv * meta.kDeg, -100*medM, -100*medA); %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'Letter MT d'' (noise off):';
lines{end+1} = sprintf('%-8s  %12s  %12s  %12s', 'deg/s', condNames{:});
for iS = 1:numel(meta.speedsDegS)
    spd = meta.speedsDegS(iS);
    row = sprintf('%8.0f', spd);
    for iC = 1:numel(condNames)
        row = sprintf('%s  %12.4f', row, localLetterD(Letter, spd, condNames{iC}));
    end
    lines{end+1} = row; %#ok<AGROW>
end
d1h = localLetterD(Letter, 1, 'healthy');
d1m = localLetterD(Letter, 1, 'midget_ko');
d5h = localLetterD(Letter, 5, 'healthy');
d5m = localLetterD(Letter, 5, 'midget_ko');
lines{end+1} = sprintf('letter Δd'' midget_ko−healthy:  1 deg/s %+.3f   5 deg/s %+.3f', ...
    d1m - d1h, d5m - d5h);
lines{end+1} = '';
if ~(dropSlowM > 0.15)
    lines{end+1} = 'GRADIENT: UNCLEAR — slow-tier midget_ko drop ≤ 15%.';
elseif dropSlowM > 3 * max(dropFastM, 0.01)
    lines{end+1} = 'GRADIENT: YES — slow-tier midget_ko drop > 3× the 6 px/fr tier.';
    lines{end+1} = 'That is the unconfounded §4.5 prediction (own speed curves).';
else
    lines{end+1} = 'GRADIENT: NO — slow-tier midget_ko drop is not 3× the fast tier.';
end
lines{end+1} = 'GRADIENT uses peak drop on each neuron''s own curve, median by nominal tier.';
if (d1h - d1m) > (d5h - d5m) + 0.10
    lines{end+1} = 'SLOW_LETTER: YES — midget_ko costs the 1 deg/s letter more than 5.';
else
    lines{end+1} = 'SLOW_LETTER: NO — letter cost is not larger at 1 deg/s than at 5.';
end
lines{end+1} = 'Old §4.5 (one grating): −45% at 0 px/fr vs −1.4% at 6, alpha=0.10.';
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

function localWriteFigs(outDir, Tune, Letter, meta, condNames)
cols = [0.45 0.45 0.45; 0.80 0.25 0.20; 0.20 0.45 0.75];
nom = meta.nomSpeeds;
fig = figure('Color', 'w', 'Position', [60 60 900 720], 'Visible', 'off');
for iN = 1:numel(nom)
    subplot(numel(nom), 1, iN); hold on;
    sel = find(abs(meta.V(meta.probe, 2) - nom(iN)) < 1e-9);
    k0 = sel(1);
    for iC = 1:numel(condNames)
        C = Tune.(condNames{iC});
        semilogx(meta.speedPx, C.curves(k0,:), '-', 'Color', cols(iC,:), 'LineWidth', 1.6);
    end
    set(gca, 'XScale', 'log');
    xlabel('speed (px/frame)'); ylabel('response');
    title(sprintf('neuron %d  nominal %g px/fr = %g deg/s', ...
        meta.probe(k0), nom(iN), nom(iN)*meta.kDeg));
    if iN == 1
        legend(condNames, 'Location', 'best', 'FontSize', 8);
    end
    grid on; box off;
end
exportgraphics(fig, fullfile(outDir, 'speed_by_tier.png'), 'Resolution', 130);
close(fig);

figB = figure('Color', 'w', 'Position', [60 60 560 360], 'Visible', 'off');
x = 1:numel(meta.probe);
dropM = 1 - Tune.midget_ko.peak ./ max(Tune.healthy.peak, eps);
dropA = 1 - Tune.magno_only.peak ./ max(Tune.healthy.peak, eps);
bar(x, 100 * [dropM, dropA]);
set(gca, 'XTick', x, 'XTickLabel', arrayfun(@(n) sprintf('%d', n), meta.probe, 'UniformOutput', false));
xlabel('MT neuron'); ylabel('peak drop vs healthy (%)');
legend({'midget_ko', 'magno_only'}, 'Location', 'best');
title('Unconfounded peak drop (own speed curve)');
grid on; box off;
exportgraphics(figB, fullfile(outDir, 'peak_drop.png'), 'Resolution', 130);
close(figB);

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
end
