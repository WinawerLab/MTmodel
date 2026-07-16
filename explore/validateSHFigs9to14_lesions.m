%% validateSHFigs9to14_lesions.m
% Phase 2: Lesion effects on Simoncelli & Heeger 1998 Figures 9-14
%
% Applies per-class amplitude and latency lesions to:
% - Derivative preset (control - exact model with lesioned input)
% - Lagged midget/parasol preset (biological lesion parameterization)
%
% Uses FIXED V1 weights (no refitting) - lesions only modify RGC layer.
% Regenerates Figs 9-14 under lesion conditions to visualize degradation.
%
% Self-locating script: adds MTmodel path automatically
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

% Where to save figures
outDir = fullfile(tempdir, 'MTmodel_lesion_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('Lesion validation figures will be saved to:\n  %s\n\n', outDir);

%% Define lesion types to test
% Universal lesions (apply to both presets)
universalLesions = struct(...
    'name', {'amplitude_uniform', 'delay_uniform'}, ...
    'description', {'Uniform 50%% amplitude', 'Uniform 2-frame delay'}, ...
    'applyFn', {@lesionAmplitudeUniform, @lesionDelayUniform});

% Biological lesions (only for lagged midget/parasol preset)
biologicalLesions = struct(...
    'name', {'amplitude_parasol', 'delay_ON_only'}, ...
    'description', {'Parasol-only 70%% amplitude', 'ON-only 1-frame delay'}, ...
    'applyFn', {@lesionAmplitudeParasol, @lesionDelayONOnly});

%% Define model presets to test (derivative and lagged midget/parasol)
presets = struct(...
    'name', {'derivative', 'lagged_midget_parasol'}, ...
    'description', {'Derivative preset', 'Lagged midget/parasol'}, ...
    'setup', {@setupDerivative, @setupLaggedBiological});

%% Loop over each preset and lesion type
for iPreset = 1:length(presets)
    preset = presets(iPreset);
    fprintf('\n========================================\n');
    fprintf('Preset: %s\n', preset.description);
    fprintf('========================================\n\n');

    % Setup base parameters for this preset
    parsBase = preset.setup();

    % Select appropriate lesions for this preset
    if strcmp(preset.name, 'derivative')
        lesions = universalLesions; % Only universal lesions for derivative
    else
        lesions = [universalLesions, biologicalLesions]; % All lesions for biological
    end

    for iLesion = 1:length(lesions)
        lesion = lesions(iLesion);
        fprintf('  Lesion: %s\n', lesion.description);

        % Apply lesion to get modified pars
        pars = lesion.applyFn(parsBase);

        % Generate Figures 9-14 with this lesion
        lesionLabel = sprintf('%s_%s', preset.name, lesion.name);
        generateFig9(pars, lesionLabel, lesion.description, outDir);
        generateFig10(pars, lesionLabel, lesion.description, outDir);
        generateFig11(pars, lesionLabel, lesion.description, outDir);
        generateFig12(pars, lesionLabel, lesion.description, outDir);
        generateFig13(pars, lesionLabel, lesion.description, outDir);
        generateFig14(pars, lesionLabel, lesion.description, outDir);

        fprintf('    Completed %s\n', lesion.name);
    end

    fprintf('\nCompleted all lesions for %s\n', preset.name);
end

fprintf('\n========================================\n');
fprintf('All lesion validations complete!\n');
fprintf('Figures saved to: %s\n', outDir);
fprintf('========================================\n');

%% Preset setup functions (same as Phase 1, but don't need legacy)

function pars = setupDerivative()
% Derivative preset: RGC enabled, mode='derivative' (exact)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'derivative';
end

function pars = setupLaggedBiological()
% Lagged biological preset: midget/parasol with lags
% Load cached weights (fitted in Phase 1)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'custom'; % prevent shModelV1Linear from rebuilding these classes
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';

% Load cached weights
repoRoot = fileparts(fileparts(mfilename('fullpath')));
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');

if ~exist(weightsFile, 'file')
    error('Cached weights not found. Run validateSHFigs9to14.m first (Phase 1).');
end

cached = load(weightsFile);
pars.rgc.v1Weights = cached.v1Weights;
fprintf('    Loaded cached weights (%dx%d)\n', size(pars.rgc.v1Weights, 1), size(pars.rgc.v1Weights, 2));
end

%% Lesion application functions

function pars = lesionAmplitudeUniform(parsBase)
% Uniform 50% amplitude deficit across all RGC classes
pars = parsBase;
nClasses = length(pars.rgc.classes);
for i = 1:nClasses
    pars.rgc.classes(i).gain = 0.5; % 50% reduction
end
end

function pars = lesionDelayUniform(parsBase)
% Uniform 2-frame conduction delay across all RGC classes
pars = parsBase;
nClasses = length(pars.rgc.classes);
delayFrames = 2;

for i = 1:nClasses
    % Prepend zeros to temporal kernel (causal delay)
    origKernel = pars.rgc.classes(i).temporalKernel;
    pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); origKernel];
end
end

function pars = lesionAmplitudeParasol(parsBase)
% Parasol-only 70% amplitude deficit (spare midgets)
pars = parsBase;
nClasses = length(pars.rgc.classes);

for i = 1:nClasses
    name = pars.rgc.classes(i).name;
    if contains(name, 'parasol', 'IgnoreCase', true)
        pars.rgc.classes(i).gain = 0.3; % 70% reduction
    end
end
end

function pars = lesionDelayONOnly(parsBase)
% ON pathway only: 1-frame conduction delay (OFF spared)
pars = parsBase;
nClasses = length(pars.rgc.classes);
delayFrames = 1;

for i = 1:nClasses
    rectify = pars.rgc.classes(i).rectify;
    if contains(rectify, 'on', 'IgnoreCase', true) % 'onHalf'
        % Prepend zeros to temporal kernel
        origKernel = pars.rgc.classes(i).temporalKernel;
        pars.rgc.classes(i).temporalKernel = [zeros(delayFrames, 1); origKernel];
    end
end
end

%% Figure generation functions (same as Phase 1)

function generateFig9(pars, label, description, outDir)
% Figure 9: Direction tuning - V1 and MT responses to gratings vs plaids
fprintf('    Generating Figure 9...\n');

figure('Name', sprintf('Fig 9 - %s', description), 'Color', 'w', ...
    'Position', [100 100 800 800], 'Visible', 'off');

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

sgtitle(sprintf('Figure 9: %s', description));

saveas(gcf, fullfile(outDir, sprintf('fig9_%s.png', label)));
close(gcf);
end

function generateFig10(pars, label, description, outDir)
% Figure 10: Speed tuning curves for bandpass, lowpass, highpass MT neurons
fprintf('    Generating Figure 10...\n');

figure('Name', sprintf('Fig 10 - %s', description), 'Color', 'w', ...
    'Position', [150 100 500 900], 'Visible', 'off');

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
title('"bandpass" speed tuning');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(1,1), xSpeed(1,end), 0, 1.2*max(yResponseToPreferred(1,:))]);

% Plot lowpass
subplax([3 1], [2.1 1.1], [.7 .7], 1);
semilogx(xSpeed(2,:), yResponseToPreferred(2,:), 'b-', xSpeed(2,:), yResponseToPreferred(2,:), 'k.');
hold on
semilogx(xSpeed(2,:), yResponseToAntiPreferred(2,:), 'r-', xSpeed(2,:), yResponseToAntiPreferred(2,:), 'k.');
semilogx(xSpeed(2,:), nullResponse(2,:), 'k--');
hold off
title('"lowpass" speed tuning');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(2,1), xSpeed(2,end), 0, 1.2*max(yResponseToPreferred(2,:))]);

% Plot highpass
subplax([3 1], [1.1 1.1], [.7 .7], 1);
semilogx(xSpeed(3,:), yResponseToPreferred(3,:), 'b-', xSpeed(3,:), yResponseToPreferred(3,:), 'k.');
hold on
semilogx(xSpeed(3,:), yResponseToAntiPreferred(3,:), 'r-', xSpeed(3,:), yResponseToAntiPreferred(3,:), 'k.');
semilogx(xSpeed(3,:), nullResponse(3,:), 'k--');
hold off
title('"highpass" speed tuning');
xlabel('speed (px/frame)'); ylabel('response');
axis([xSpeed(3,1), xSpeed(3,end), 0, 1.2*max(yResponseToPreferred(3,:))]);

sgtitle(sprintf('Figure 10: %s', description));

saveas(gcf, fullfile(outDir, sprintf('fig10_%s.png', label)));
close(gcf);
end

function generateFig11(pars, label, description, outDir)
% Figure 11: MT response to dot coherence
fprintf('    Generating Figure 11...\n');

figure('Name', sprintf('Fig 11 - %s', description), 'Color', 'w', 'Visible', 'off');

[x, yPref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71);
[x, yAntipref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71, pi);

plot(x, yPref, 'r-', x, yPref, 'k.');
hold on; plot(x, yAntipref, 'b-', x, yAntipref, 'k.'); hold off
xlabel('dot stimulus coherence'); ylabel('response');
title(sprintf('Figure 11: %s', description));
legend('Preferred', 'Antipreferred', 'Location', 'best');

saveas(gcf, fullfile(outDir, sprintf('fig11_%s.png', label)));
close(gcf);
end

function generateFig12(pars, label, description, outDir)
% Figure 12: MT response to mixture of preferred and antipreferred dots
fprintf('    Generating Figure 12...\n');

figure('Name', sprintf('Fig 12 - %s', description), 'Color', 'w', 'Visible', 'off');

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
        dPref = nPref(i)./rfArea;
        dMask = nMask(j)./rfArea;

        sDots = mkDots(dims, pref(1), pref(2), dPref);
        sMask = mkDots(dims, pref(1)+pi, pref(2), dMask);
        sDotsWithMask = w .* min(sDots + sMask, 1);

        [pop, ind, res] = shModel(10.*sDotsWithMask, pars, 'mtPattern', neuron);
        yRes(i, j) = mean(shGetNeuron(res, ind));
    end
end

x = nPref;
h(1,1) = plot([0 0],[1 1],'w');
hold on
for n = 1:length(nMask)
    h(n+1,:) = plot(x, yRes(:, n), sprintf('%c-',cols(n)), x, yRes(:, n), 'k.');
end
plot(x, yNull, 'k--');
axis([min(x) max(x) 0 1.2*max(yRes, [], 'all')]);
hold off

title(sprintf('Figure 12: %s', description));
eval(['legend(h(:,1),''num antipref dots''',sprintf(',''%d''', nMask'), ')']);
xlabel('Number of dots in preferred direction'); ylabel('response');

saveas(gcf, fullfile(outDir, sprintf('fig12_%s.png', label)));
close(gcf);
end

function generateFig13(pars, label, description, outDir)
% Figure 13: MT response to preferred dots + mask at varying directions
fprintf('    Generating Figure 13...\n');

figure('Name', sprintf('Fig 13 - %s', description), 'Color', 'w', 'Visible', 'off');

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

title(sprintf('Figure 13: %s', description));
xlabel('mask direction (degrees)'); ylabel('response');
legend([h1(1),h2(1)], 'preferred + mask', 'preferred alone');

saveas(gcf, fullfile(outDir, sprintf('fig13_%s.png', label)));
close(gcf);
end

function generateFig14(pars, label, description, outDir)
% Figure 14: MT direction tuning for dots with/without antipreferred mask
fprintf('    Generating Figure 14...\n');

figure('Name', sprintf('Fig 14 - %s', description), 'Color', 'w', 'Visible', 'off');

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
    sDots = mkDots(dims, x(i), pref(2), .15);
    sMask = mkDots(dims, pref(1)+pi, pref(2), .15);
    sDotsWithMask = sDots + sMask;
    sDotsWithMask(sDotsWithMask > 1) = 1;

    [pop, ind, resDots] = shModel(sDots, pars, 'mtPattern', neuron);
    [pop, ind, resDotsWithMask] = shModel(sDotsWithMask, pars, 'mtPattern', neuron);
    yDots(i) = mean(shGetNeuron(resDots, ind));
    yDotsWithMask(i) = mean(shGetNeuron(resDotsWithMask, ind));
end

h = zeros(3, 2);
h(1,:) = plot(180*x/pi, yDots, 'r-', 180*x/pi, yDots, 'k.');
hold on
h(2,:) = plot(180*x/pi, yDotsWithMask, 'b-', 180*x/pi, yDotsWithMask, 'k.');
h(3,:) = plot(180*x/pi, yNull, 'k--');
axis([-180 180 0 1.2*max([yNull, yDots, yDotsWithMask])]);
hold off

title(sprintf('Figure 14: %s', description));
legend(h(:,1), 'single dot field', 'w/ antipreferred mask', 'spontaneous');
xlabel('Direction (degrees)'); ylabel('response');

saveas(gcf, fullfile(outDir, sprintf('fig14_%s.png', label)));
close(gcf);
end
