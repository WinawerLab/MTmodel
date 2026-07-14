%% validateSHFigs9to14.m
% Reproduce Simoncelli & Heeger 1998 Figures 9-14 across three model paths:
% (a) legacy SH (pars.rgc.enabled=0) - baseline
% (b) derivative preset (pars.rgc.mode='derivative') - should match legacy exactly
% (c) lagged midget/parasol preset (shRgcClassesMidgetParasolLagged, lags [0 1 2 3])
%     - biological DoG RFs, no offset/quadrature, ~0.985 legacy correlation
%
% Based on shTutorial1.m section VIII (lines 341-591).
%
% Self-locating script: adds MTmodel path automatically
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

% Where to save figures
outDir = fullfile(tempdir, 'MTmodel_validation_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('Validation figures will be saved to:\n  %s\n\n', outDir);

%% Define the three model configurations
configs = struct(...
    'name', {'legacy', 'derivative', 'lagged_midget_parasol'}, ...
    'description', {'Legacy SH (no RGC)', 'Derivative preset (exact)', 'Lagged midget/parasol (lags 0-3, ~0.985 corr)'}, ...
    'setup', {@setupLegacy, @setupDerivative, @setupLaggedBiological});

%% Loop over each configuration and generate all figures
for iConfig = 1:length(configs)
    cfg = configs(iConfig);
    fprintf('\n========================================\n');
    fprintf('Configuration: %s\n', cfg.description);
    fprintf('========================================\n\n');

    % Setup parameters for this configuration
    pars = cfg.setup();

    % Generate each figure
    generateFig9(pars, cfg, outDir);
    generateFig10(pars, cfg, outDir);
    generateFig11(pars, cfg, outDir);
    generateFig12(pars, cfg, outDir);
    generateFig13(pars, cfg, outDir);
    generateFig14(pars, cfg, outDir);

    fprintf('\nCompleted %s\n', cfg.name);
end

fprintf('\n========================================\n');
fprintf('All validations complete!\n');
fprintf('Figures saved to: %s\n', outDir);
fprintf('========================================\n');

%% Configuration setup functions

function pars = setupLegacy()
% Legacy SH: no RGC layer
pars = shPars;
pars.rgc.enabled = 0;
end

function pars = setupDerivative()
% Derivative preset: RGC enabled, mode='derivative' (exact)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'derivative';
% classes are auto-populated by shPars for derivative mode
end

function pars = setupLaggedBiological()
% Lagged biological preset: midget/parasol with lags
pars = shPars;
pars.rgc.enabled = 1;
% Build lagged biological classes with lags [0 1 2 3] frames
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom'; % prevent dispatch from rebuilding
% Fit weights to legacy V1
fprintf('  Fitting lagged biological weights to legacy V1...\n');
pars = fitLaggedWeights(pars);
end

function pars = fitLaggedWeights(pars)
% Fit v1Weights for the lagged biological preset
% Saves/loads weights to avoid refitting each run
% Uses shFitClassV1Weights (the unified fitter)

% Define cache file for fitted weights
repoRoot = fileparts(fileparts(mfilename('fullpath')));
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');

% Try to load cached weights
if exist(weightsFile, 'file')
    fprintf('    Loading cached weights from %s\n', weightsFile);
    cached = load(weightsFile);
    pars.rgc.v1Weights = cached.v1Weights;
    fprintf('    Loaded weights: %dx%d matrix\n', size(pars.rgc.v1Weights, 1), size(pars.rgc.v1Weights, 2));
else
    % Fit new weights
    fprintf('    No cached weights found. Fitting new weights (this will be saved)...\n');
    rng(42); % deterministic
    dims = shGetDims(pars, 'v1Complex', [5 5 20]);
    stim = rand(dims);
    pars.rgc.v1Weights = shFitClassV1Weights(pars, {stim}); % cell array required

    % Save for next time
    v1Weights = pars.rgc.v1Weights; %#ok<NASGU>
    save(weightsFile, 'v1Weights', '-v7.3');
    fprintf('    Saved fitted weights to %s\n', weightsFile);
end
end

%% Figure generation functions

function generateFig9(pars, cfg, outDir)
% Figure 9: Direction tuning - V1 and MT responses to gratings vs plaids
fprintf('  Generating Figure 9 (direction tuning)...\n');

figure('Name', sprintf('Fig 9 - %s', cfg.description), 'Color', 'w', ...
    'Position', [100 100 800 800]);

[x, v1Sin] = shTuneGratingDirection(pars, [0 .35], 'v1Complex', 21);
[x2, v1Plaid] = shTunePlaidDirection(pars, [0 .35], 'v1Complex', 21);
[x3, mtSin] = shTuneGratingDirection(pars, [0 .35], 'mtPattern', 21);
[x4, mtPlaid] = shTunePlaidDirection(pars, [0 .35], 'mtPattern', 21);

% MT, grating
axisMax = 1.25*max(mtSin);
subplax([2 2], [1.15 1.15], [.7 .7], 1);
polar(0,axisMax); hold on; polar(x, mtSin, 'k.-'); hold off
title('MT, grating')

% MT, plaid
axisMax = 1.25*max(mtPlaid);
subplax([2 2], [1.15 2.15], [.7 .7], 1);
polar(0,axisMax); hold on; polar(x, mtPlaid, 'k.-'); hold off
title('MT, plaid')

% V1, grating
axisMax = 1.25*max(v1Sin);
subplax([2 2], [2.15 1.15], [.7 .7], 1);
polar(0, axisMax); hold on; polar(x, v1Sin, 'k.-'); hold off
title('V1, grating')

% V1, plaid
axisMax = 1.15*max(v1Plaid);
subplax([2 2], [2.15 2.15], [.7 .7], 1);
polar(0, axisMax); hold on; polar(x, v1Plaid, 'k.-'); hold off
title('V1, plaid')

sgtitle(sprintf('Figure 9: Direction Tuning (%s)', cfg.description));

saveas(gcf, fullfile(outDir, sprintf('fig9_%s.png', cfg.name)));
fprintf('    Saved fig9_%s.png\n', cfg.name);
end

function generateFig10(pars, cfg, outDir)
% Figure 10: Speed tuning curves for bandpass, lowpass, highpass MT neurons
fprintf('  Generating Figure 10 (speed tuning - this may take a while)...\n');

figure('Name', sprintf('Fig 10 - %s', cfg.description), 'Color', 'w', ...
    'Position', [150 100 500 900]);

dims = shGetDims(pars, 'mtPattern');

neurons = [0 1.5; 0 .125; 0 9];
speedMinMax = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
nDataPoints = 6;
xSpeed = zeros(3, nDataPoints);
yResponseToPreferred = zeros(3, nDataPoints);
yResponseToAntiPreferred = zeros(3, nDataPoints);
nullResponse = zeros(3, nDataPoints);

for iNeuron = 1:3
    fprintf('    Computing neuron %d/3...\n', iNeuron);
    [xSpeedTmp, yResponseToPreferredTmp] = shTuneBarSpeed(pars, neurons(iNeuron, :), ...
        'mtPattern', nDataPoints, speedMinMax(iNeuron, 1), ...
        speedMinMax(iNeuron, 2), neurons(iNeuron, 1), ...
        1, barEdgeWidth(iNeuron));
    [xSpeedTmp, yResponseToAntiPreferredTmp] = shTuneBarSpeed(pars, neurons(iNeuron, :), ...
        'mtPattern', nDataPoints, speedMinMax(iNeuron, 1), ...
        speedMinMax(iNeuron, 2), neurons(iNeuron, 1)+pi, ...
        1, barEdgeWidth(iNeuron));
    [pop, ind, nullResponseTmp] = shModel(zeros(dims), pars, 'mtPattern', neurons(iNeuron, :));
    nullResponseTmp = mean(shGetNeuron(nullResponseTmp, ind));
    nullResponseTmp = nullResponseTmp.*ones(1, nDataPoints);

    xSpeed(iNeuron, :) = xSpeedTmp;
    yResponseToPreferred(iNeuron, :) = yResponseToPreferredTmp;
    yResponseToAntiPreferred(iNeuron, :) = yResponseToAntiPreferredTmp;
    nullResponse(iNeuron, :) = nullResponseTmp;
end

% Plot bandpass
subplax([3 1], [3.1 1.1], [.7 .7], 1);
semilogx(xSpeed(1,:), yResponseToPreferred(1,:), 'b-', xSpeed(1,:), yResponseToPreferred(1,:), 'k.');
hold on
semilogx(xSpeed(1,:), yResponseToAntiPreferred(1,:), 'r-', xSpeed(1,:), yResponseToAntiPreferred(1,:), 'k.');
semilogx(xSpeed(1,:), nullResponse(1,:), 'k--');
hold off
title('"bandpass" speed tuning curve');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(1,1), xSpeed(1,end), 0, 1.2*max(yResponseToPreferred(1,:))]);

% Plot lowpass
subplax([3 1], [2.1 1.1], [.7 .7], 1);
semilogx(xSpeed(2,:), yResponseToPreferred(2,:), 'b-', xSpeed(2,:), yResponseToPreferred(2,:), 'k.');
hold on
semilogx(xSpeed(2,:), yResponseToAntiPreferred(2,:), 'r-', xSpeed(2,:), yResponseToAntiPreferred(2,:), 'k.');
semilogx(xSpeed(2,:), nullResponse(2,:), 'k--');
hold off
title('"lowpass" speed tuning curve');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(2,1), xSpeed(2,end), 0, 1.2*max(yResponseToPreferred(2,:))]);

% Plot highpass
subplax([3 1], [1.1 1.1], [.7 .7], 1);
semilogx(xSpeed(3,:), yResponseToPreferred(3,:), 'b-', xSpeed(3,:), yResponseToPreferred(3,:), 'k.');
hold on
semilogx(xSpeed(3,:), yResponseToAntiPreferred(3,:), 'r-', xSpeed(3,:), yResponseToAntiPreferred(3,:), 'k.');
semilogx(xSpeed(3,:), nullResponse(3,:), 'k--');
hold off
title('"highpass" speed tuning curve');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(3,1), xSpeed(3,end), 0, 1.2*max(yResponseToPreferred(3,:))]);

sgtitle(sprintf('Figure 10: Speed Tuning (%s)', cfg.description));

saveas(gcf, fullfile(outDir, sprintf('fig10_%s.png', cfg.name)));
fprintf('    Saved fig10_%s.png\n', cfg.name);
end

function generateFig11(pars, cfg, outDir)
% Figure 11: MT response to dot coherence
fprintf('  Generating Figure 11 (dot coherence)...\n');

figure('Name', sprintf('Fig 11 - %s', cfg.description), 'Color', 'w');

[x, yPref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71);
[x, yAntipref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71, pi);

plot(x, yPref, 'r-', x, yPref, 'k.');
hold on; plot(x, yAntipref, 'b-', x, yAntipref, 'k.'); hold off
xlabel('dot stimulus coherence'); ylabel('response');
title(sprintf('Figure 11: Dot Coherence (%s)', cfg.description));
legend('Preferred', 'Antipreferred', 'Location', 'best');

saveas(gcf, fullfile(outDir, sprintf('fig11_%s.png', cfg.name)));
fprintf('    Saved fig11_%s.png\n', cfg.name);
end

function generateFig12(pars, cfg, outDir)
% Figure 12: MT response to mixture of preferred and antipreferred dots
fprintf('  Generating Figure 12 (dot mixture)...\n');

figure('Name', sprintf('Fig 12 - %s', cfg.description), 'Color', 'w');

dims = shGetDims(pars, 'mtPattern', [1 1 71]);
neuron = [0 1];
pref = neuron;

nPref = [0, 8, 16, 64, 256];
nMask = [0, 16, 64, 256];
cols = 'rgbk';
h = zeros(1+length(nMask), 2);
yRes = zeros(size(nPref, 2), size(nMask, 2));
rfRad = 15.5;
rfArea = pi.*rfRad.^2;

[pop, ind, resNull] = shModel(zeros(dims), pars, 'mtPattern', neuron);
yNull = mean(shGetNeuron(resNull, ind));
yNull = yNull.*ones(1, size(yRes, 1));
w = mkWin(dims, 15, 2);

for j = 1:size(nMask, 2)
    for i = 1:size(nPref, 2)
        fprintf('.');
        dPref = nPref(i)./rfArea;
        dMask = nMask(j)./rfArea;

        sDots = mkDots(dims, pref(1), pref(2), dPref);
        sMask = mkDots(dims, pref(1)+pi, pref(2), dMask);
        sDotsWithMask = w .* min(sDots + sMask, 1);

        [pop, ind, res] = shModel(10.*sDotsWithMask, pars, 'mtPattern', neuron);
        yRes(i, j) = mean(shGetNeuron(res, ind));
    end
end
fprintf('\n');

x = nPref;
h(1,1) = plot([0 0],[1 1],'w');
hold on
for n = 1:length(nMask)
    h(n+1,:) = plot(x, yRes(:, n), sprintf('%c-',cols(n)), x, yRes(:, n), 'k.');
end
plot(x, yNull, 'k--');
axis([min(x) max(x) 0 1.2*max(yRes, [], 'all')]);
hold off

title(sprintf('Figure 12: Dot Mixture (%s)', cfg.description));
eval(['legend(h(:,1),''num antipref dots''',sprintf(',''%d''', nMask'), ')']);
xlabel('Number of dots in preferred direction'); ylabel('response');

saveas(gcf, fullfile(outDir, sprintf('fig12_%s.png', cfg.name)));
fprintf('    Saved fig12_%s.png\n', cfg.name);
end

function generateFig13(pars, cfg, outDir)
% Figure 13: MT response to preferred dots + mask at varying directions
fprintf('  Generating Figure 13 (mask direction)...\n');

figure('Name', sprintf('Fig 13 - %s', cfg.description), 'Color', 'w');

nFrames = 101;
[x, y] = shTuneDotMaskDirection(pars, [pi 1], 'mtPattern', 9, nFrames);
x = x.*180./pi;
x = [x, 360];
y = [y, y(1)];

h1 = plot(x, y, 'r-', x, y, 'k.');
hold on;
h2 = plot(x, max(y).*ones(size(y)), 'k--');
hold off
axis([0 360 0 1.2*max(y)]);

title(sprintf('Figure 13: Mask Direction (%s)', cfg.description));
xlabel('mask direction (degrees)'); ylabel('response');
legend([h1(1),h2(1)], 'preferred + mask', 'preferred alone');

saveas(gcf, fullfile(outDir, sprintf('fig13_%s.png', cfg.name)));
fprintf('    Saved fig13_%s.png\n', cfg.name);
end

function generateFig14(pars, cfg, outDir)
% Figure 14: MT direction tuning for dots with/without antipreferred mask
fprintf('  Generating Figure 14 (direction tuning with mask)...\n');

figure('Name', sprintf('Fig 14 - %s', cfg.description), 'Color', 'w');

dims = shGetDims(pars, 'mtPattern', [1 1 15]);
neuron = [0 1];
pref = neuron;

x = linspace(-pi, pi, 9);
yDots = zeros(size(x));
yDotsWithMask = zeros(size(x));

[pop, ind, resNull] = shModel(zeros(dims), pars, 'mtPattern', neuron);
yNull = mean(shGetNeuron(resNull, ind));
yNull = yNull.*ones(size(yDots));

for i = 1:length(x)
    fprintf('.');
    sDots = mkDots(dims, x(i), pref(2), .15);
    sMask = mkDots(dims, pref(1)+pi, pref(2), .15);
    sDotsWithMask = sDots + sMask;
    sDotsWithMask(sDotsWithMask > 1) = 1;

    [pop, ind, resDots] = shModel(sDots, pars, 'mtPattern', neuron);
    [pop, ind, resDotsWithMask] = shModel(sDotsWithMask, pars, 'mtPattern', neuron);
    yDots(i) = mean(shGetNeuron(resDots, ind));
    yDotsWithMask(i) = mean(shGetNeuron(resDotsWithMask, ind));
end
fprintf('\n');

h = zeros(3, 2);
h(1,:) = plot(180*x/pi, yDots, 'r-', 180*x/pi, yDots, 'k.');
hold on
h(2,:) = plot(180*x/pi, yDotsWithMask, 'b-', 180*x/pi, yDotsWithMask, 'k.');
h(3,:) = plot(180*x/pi, yNull, 'k--');
axis([-180 180 0 1.2*max([yNull, yDots, yDotsWithMask])]);
hold off

title(sprintf('Figure 14: Direction Tuning with Mask (%s)', cfg.description));
legend(h(:,1), 'single dot field', 'w/ antipreferred mask', 'spontaneous');
xlabel('Direction (degrees)'); ylabel('response');

saveas(gcf, fullfile(outDir, sprintf('fig14_%s.png', cfg.name)));
fprintf('    Saved fig14_%s.png\n', cfg.name);
end
