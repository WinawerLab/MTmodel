%% compareLesionsToBaseline.m
% SH Figs 9-14 for the lagged midget/parasol preset, with each lesion plotted
% ON THE SAME AXES as the unlesioned baseline.
%
% Differences from validateSHFigs9to14_lesions.m (which remains the archival
% Phase 2 record, one figure per condition):
%
%   1. Baseline and lesion appear together on every panel - baseline in grey,
%      lesion in colour - with shared axis limits, so the comparison is direct.
%   2. Computation is separated from plotting: curves are computed once per
%      condition into a struct, then drawn. The baseline is cached to disk.
%   3. **The RNG is seeded identically for every condition.** Figs 11-14 use
%      random dot fields; without a fixed seed a lesion-vs-baseline difference is
%      confounded with dot-sample noise. The old script never seeded, so its
%      dot-based panels were not reproducible run to run.
%   4. Lesion labels state the REMAINING gain explicitly. The old descriptions
%      mixed conventions ('Uniform 50% amplitude' = gain 0.5 remaining, but
%      'Parasol-only 70% amplitude' = gain 0.3 remaining, a 70% *reduction*).
%
% Usage:
%   run('explore/compareLesionsToBaseline.m')
% Optional overrides, set before running:
%   OUT_DIR       destination folder
%   ONLY_LESIONS  cellstr subset of lesion names
%   FORCE_BASE    true to recompute the cached baseline

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

if exist('OUT_DIR', 'var') && ~isempty(OUT_DIR)
    outDir = OUT_DIR;
else
    outDir = fullfile(repoRoot, 'explore', '_figs', 'lesion_vs_baseline');
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

SEED = 42;   % every condition sees identical random dot fields

% Lesions. `gainRemaining` is what the affected classes are scaled TO.
lesions = struct( ...
    'name', {'parasol_gain0p3', 'uniform_gain0p5'}, ...
    'description', {'Parasol-only, gain 0.3 (70% reduction; midgets spared)', ...
                    'All classes, gain 0.5 (50% reduction)'}, ...
    'applyFn', {@lesionParasolGain, @lesionUniformGain});

if exist('ONLY_LESIONS', 'var') && ~isempty(ONLY_LESIONS)
    lesions = lesions(ismember({lesions.name}, ONLY_LESIONS));
end

parsBase = setupLaggedBiological(repoRoot);

%% Baseline curves (cached - identical for every lesion)
cacheFile = fullfile(outDir, 'baseline_curves.mat');
if exist(cacheFile, 'file') && ~(exist('FORCE_BASE','var') && FORCE_BASE)
    fprintf('Loading cached baseline curves from %s\n', cacheFile);
    S = load(cacheFile); base = S.base;
else
    fprintf('Computing baseline curves (no lesion)...\n');
    base = computeCurves(parsBase, SEED);
    save(cacheFile, 'base');
    fprintf('  cached to %s\n', cacheFile);
end

%% Each lesion, overlaid on the baseline
for iL = 1:numel(lesions)
    L = lesions(iL);
    fprintf('\nLesion: %s\n', L.description);
    parsL = L.applyFn(parsBase);
    les = computeCurves(parsL, SEED);

    plotFig9 (base, les, L, outDir);
    plotFig10(base, les, L, outDir);
    plotFig11(base, les, L, outDir);
    plotFig12(base, les, L, outDir);
    plotFig13(base, les, L, outDir);
    plotFig14(base, les, L, outDir);
    fprintf('  done %s\n', L.name);
end

fprintf('\nAll comparison figures written to:\n  %s\n', outDir);

%% ------------------------------------------------------------------ setup
function pars = setupLaggedBiological(repoRoot)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'custom';           % else shModelV1Linear rebuilds the classes
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
if ~exist(weightsFile, 'file')
    error('Cached weights not found. Run validateSHFigs9to14.m first.');
end
c = load(weightsFile);
pars.rgc.v1Weights = c.v1Weights;
end

%% --------------------------------------------------------------- lesions
function pars = lesionParasolGain(parsBase)
% ALL parasol classes scaled to gain 0.3 (a 70% reduction). Midgets untouched.
% Deterministic and uniform: `gain` is one scalar per class, so this is not a
% random subset of cells - per-location heterogeneity needs the stochastic path.
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    if contains(pars.rgc.classes(i).name, 'parasol', 'IgnoreCase', true)
        pars.rgc.classes(i).gain = 0.3;
    end
end
end

function pars = lesionUniformGain(parsBase)
% Every class scaled to gain 0.5 (a 50% reduction).
pars = parsBase;
for i = 1:numel(pars.rgc.classes)
    pars.rgc.classes(i).gain = 0.5;
end
end

%% ------------------------------------------------------- curve computation
function C = computeCurves(pars, seed)
% All Fig 9-14 measurements for one condition. Seeded so that random dot
% stimuli are identical across conditions.

% --- Fig 9: direction tuning, gratings vs plaids
rng(seed);
[C.f9.x,  C.f9.v1Sin]   = shTuneGratingDirection(pars, [0 .35], 'v1Complex', 21);
[~,       C.f9.v1Plaid] = shTunePlaidDirection  (pars, [0 .35], 'v1Complex', 21);
[~,       C.f9.mtSin]   = shTuneGratingDirection(pars, [0 .35], 'mtPattern', 21);
[~,       C.f9.mtPlaid] = shTunePlaidDirection  (pars, [0 .35], 'mtPattern', 21);

% --- Fig 10: speed tuning for three MT neuron types
rng(seed);
dims = shGetDims(pars, 'mtPattern');
neurons      = [0 1.5; 0 .125; 0 9];
speedMinMax  = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
n = 6;
C.f10.x = zeros(3,n); C.f10.pref = zeros(3,n);
C.f10.anti = zeros(3,n); C.f10.null = zeros(3,n);
for k = 1:3
    [xs, yp] = shTuneBarSpeed(pars, neurons(k,:), 'mtPattern', n, ...
        speedMinMax(k,1), speedMinMax(k,2), neurons(k,1), 1, barEdgeWidth(k));
    [~,  ya] = shTuneBarSpeed(pars, neurons(k,:), 'mtPattern', n, ...
        speedMinMax(k,1), speedMinMax(k,2), neurons(k,1)+pi, 1, barEdgeWidth(k));
    [~, ind, rn] = shModel(zeros(dims), pars, 'mtPattern', neurons(k,:));
    C.f10.x(k,:) = xs; C.f10.pref(k,:) = yp; C.f10.anti(k,:) = ya;
    C.f10.null(k,:) = mean(shGetNeuron(rn, ind)) .* ones(1,n);
end

% --- Fig 11: dot coherence
rng(seed);
[C.f11.x, C.f11.pref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71);
rng(seed + 1);
[~,       C.f11.anti] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71, pi);

% --- Fig 12: preferred/antipreferred dot mixtures
rng(seed);
dims12 = shGetDims(pars, 'mtPattern', [1 1 71]);
neuron = [0 1];
C.f12.nPref = [0, 8, 16, 64, 256];
C.f12.nMask = [0, 16, 64, 256];
rfArea = pi * 15.5^2;
[~, ind, rn] = shModel(zeros(dims12), pars, 'mtPattern', neuron);
C.f12.null = mean(shGetNeuron(rn, ind)) .* ones(1, numel(C.f12.nPref));
w = mkWin(dims12, 15, 2);
C.f12.y = zeros(numel(C.f12.nPref), numel(C.f12.nMask));
for j = 1:numel(C.f12.nMask)
    for i = 1:numel(C.f12.nPref)
        sD = mkDots(dims12, neuron(1),      neuron(2), C.f12.nPref(i)/rfArea);
        sM = mkDots(dims12, neuron(1)+pi,   neuron(2), C.f12.nMask(j)/rfArea);
        [~, ind, r] = shModel(10 .* (w .* min(sD + sM, 1)), pars, 'mtPattern', neuron);
        C.f12.y(i,j) = mean(shGetNeuron(r, ind));
    end
end

% --- Fig 13: mask direction
rng(seed);
[x13, y13] = shTuneDotMaskDirection(pars, [pi 1], 'mtPattern', 9, 101);
C.f13.x = [x13 .* 180/pi, 360];
C.f13.y = [y13, y13(1)];

% --- Fig 14: direction tuning with/without antipreferred mask
rng(seed);
dims14 = shGetDims(pars, 'mtPattern', [1 1 15]);
C.f14.x = linspace(-pi, pi, 9);
C.f14.dots = zeros(size(C.f14.x));
C.f14.mask = zeros(size(C.f14.x));
[~, ind, rn] = shModel(zeros(dims14), pars, 'mtPattern', neuron);
C.f14.null = mean(shGetNeuron(rn, ind)) .* ones(size(C.f14.x));
for i = 1:numel(C.f14.x)
    sD = mkDots(dims14, C.f14.x(i),   neuron(2), .15);
    sM = mkDots(dims14, neuron(1)+pi, neuron(2), .15);
    sB = min(sD + sM, 1);
    [~, ind, rD] = shModel(sD, pars, 'mtPattern', neuron);
    [~, ind, rB] = shModel(sB, pars, 'mtPattern', neuron);
    C.f14.dots(i) = mean(shGetNeuron(rD, ind));
    C.f14.mask(i) = mean(shGetNeuron(rB, ind));
end
end

%% ------------------------------------------------------------- plotting
% Shared style: baseline grey, lesion colour, shared limits.
function [cb, cl] = styles()
cb = [0.65 0.65 0.65];   % baseline grey
cl = [0.85 0.15 0.15];   % lesion red
end

function finishFig(f, L, figNum, outDir)
sgtitle(sprintf('Figure %d - %s', figNum, L.description), 'FontSize', 11);
saveas(f, fullfile(outDir, sprintf('fig%d_%s.png', figNum, L.name)));
close(f);
end

function plotFig9(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[100 100 850 850],'Visible','off');
panels = {'mtSin','MT, grating'; 'mtPlaid','MT, plaid'; 'v1Sin','V1, grating'; 'v1Plaid','V1, plaid'};
for k = 1:4
    subplot(2,2,k);
    fld = panels{k,1};
    axisMax = 1.25 * max([base.f9.(fld), les.f9.(fld)]);   % shared scale
    polar(0, axisMax); hold on;
    % keep the handles polar() returns; recolouring via findobj is fragile and
    % gives the legend the wrong swatches
    hB = polar(base.f9.x, base.f9.(fld), '-'); set(hB, 'Color', cb, 'LineWidth', 2);
    hL = polar(les.f9.x,  les.f9.(fld),  '-'); set(hL, 'Color', cl, 'LineWidth', 2);
    hold off; title(panels{k,2});
    if k == 1
        legend([hB hL], {'baseline','lesion'}, 'Location','southoutside', ...
               'Orientation','horizontal');
    end
end
finishFig(f, L, 9, outDir);
end

function plotFig10(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[150 100 560 950],'Visible','off');
names = {'"bandpass"','"lowpass"','"highpass"'};
for k = 1:3
    subplot(3,1,k); hold on;
    ymax = 1.2 * max([base.f10.pref(k,:), les.f10.pref(k,:)]);
    semilogx(base.f10.x(k,:), base.f10.pref(k,:), '-',  'Color',cb, 'LineWidth',2);
    semilogx(base.f10.x(k,:), base.f10.anti(k,:), '--', 'Color',cb, 'LineWidth',1);
    semilogx(les.f10.x(k,:),  les.f10.pref(k,:),  '-',  'Color',cl, 'LineWidth',2);
    semilogx(les.f10.x(k,:),  les.f10.anti(k,:),  '--', 'Color',cl, 'LineWidth',1);
    semilogx(base.f10.x(k,:), base.f10.null(k,:), 'k:');
    set(gca,'XScale','log');
    axis([base.f10.x(k,1) base.f10.x(k,end) 0 ymax]);
    title(sprintf('%s speed tuning', names{k}));
    xlabel('speed (px/frame)'); ylabel('response'); box off;
    if k == 1
        legend({'baseline pref','baseline anti','lesion pref','lesion anti'}, ...
               'Location','northwest','FontSize',7);
    end
    hold off;
end
finishFig(f, L, 10, outDir);
end

function plotFig11(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[100 100 720 520],'Visible','off'); hold on;
plot(base.f11.x, base.f11.pref, '-o', 'Color',cb, 'LineWidth',2, 'MarkerSize',4);
plot(base.f11.x, base.f11.anti, '--', 'Color',cb, 'LineWidth',1);
plot(les.f11.x,  les.f11.pref,  '-o', 'Color',cl, 'LineWidth',2, 'MarkerSize',4);
plot(les.f11.x,  les.f11.anti,  '--', 'Color',cl, 'LineWidth',1);
ylim([0 1.2*max([base.f11.pref, les.f11.pref])]);
xlabel('dot stimulus coherence'); ylabel('response'); box off;
legend({'baseline pref','baseline anti','lesion pref','lesion anti'}, 'Location','northwest');
hold off; finishFig(f, L, 11, outDir);
end

function plotFig12(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[100 100 720 520],'Visible','off'); hold on;
for n = 1:numel(base.f12.nMask)
    plot(base.f12.nPref, base.f12.y(:,n), '-o', 'Color',cb, 'LineWidth',1.5, 'MarkerSize',4);
    plot(les.f12.nPref,  les.f12.y(:,n),  '-o', 'Color',cl, 'LineWidth',1.5, 'MarkerSize',4);
end
ylim([0 1.2*max([base.f12.y(:); les.f12.y(:)])]);
xlabel('Number of dots in preferred direction'); ylabel('response'); box off;
legend({'baseline','lesion'}, 'Location','northwest');
title('one curve per antipreferred-dot count (0, 16, 64, 256)', 'FontWeight','normal','FontSize',9);
hold off; finishFig(f, L, 12, outDir);
end

function plotFig13(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[100 100 720 520],'Visible','off'); hold on;
plot(base.f13.x, base.f13.y, '-o', 'Color',cb, 'LineWidth',2, 'MarkerSize',4);
plot(les.f13.x,  les.f13.y,  '-o', 'Color',cl, 'LineWidth',2, 'MarkerSize',4);
yline(max(base.f13.y), ':', 'Color',cb); yline(max(les.f13.y), ':', 'Color',cl);
xlim([0 360]); ylim([0 1.2*max([base.f13.y, les.f13.y])]);
xlabel('mask direction (degrees)'); ylabel('response'); box off;
legend({'baseline','lesion'}, 'Location','southeast');
hold off; finishFig(f, L, 13, outDir);
end

function plotFig14(base, les, L, outDir)
[cb, cl] = styles();
f = figure('Color','w','Position',[100 100 720 520],'Visible','off'); hold on;
xd = 180*base.f14.x/pi;
plot(xd, base.f14.dots, '-o', 'Color',cb, 'LineWidth',2, 'MarkerSize',4);
plot(xd, base.f14.mask, '--', 'Color',cb, 'LineWidth',1.5);
plot(xd, les.f14.dots,  '-o', 'Color',cl, 'LineWidth',2, 'MarkerSize',4);
plot(xd, les.f14.mask,  '--', 'Color',cl, 'LineWidth',1.5);
xlim([-180 180]);
ylim([0 1.2*max([base.f14.dots, base.f14.mask, les.f14.dots, les.f14.mask])]);
xlabel('direction of motion (degrees)'); ylabel('response'); box off;
legend({'baseline dots','baseline +mask','lesion dots','lesion +mask'}, 'Location','northwest');
hold off; finishFig(f, L, 14, outDir);
end
