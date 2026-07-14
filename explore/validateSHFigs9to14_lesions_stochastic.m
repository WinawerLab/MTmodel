%% validateSHFigs9to14_lesions_stochastic.m
% Phase 2b: Stochastic/heterogeneous lesion effects on SH Figures 9-14
%
% Tests spatially heterogeneous lesions where different regions get different
% deficits - more realistic for optic neuritis than uniform lesions.
%
% Uses FIXED V1 weights (no refitting) - lesions modify only RGC spatial maps.
%
% Self-locating script: adds MTmodel path automatically
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

% Where to save figures
outDir = fullfile(tempdir, 'MTmodel_stochastic_lesion_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('Stochastic lesion figures will be saved to:\n  %s\n\n', outDir);

%% Define stochastic lesion types
stochasticLesions = struct(...
    'name', {'amplitude_random', 'delay_random', 'amplitude_patchy', 'delay_patchy', 'coupled'}, ...
    'description', {...
    'Random amplitude (0.3-0.7)', ...
    'Random delay (0-3 frames)', ...
    'Patchy amplitude (correlated)', ...
    'Patchy delay (correlated)', ...
    'Coupled amp+delay (realistic)'}, ...
    'applyFn', {...
    @lesionAmplitudeStochastic, ...
    @lesionDelayStochastic, ...
    @lesionAmplitudePatchyCorrelated, ...
    @lesionDelayPatchyCorrelated, ...
    @lesionCoupledAmplitudeDelay});

%% Define model presets (same as uniform lesions)
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

    % Setup base parameters
    parsBase = preset.setup();

    for iLesion = 1:length(stochasticLesions)
        lesion = stochasticLesions(iLesion);
        fprintf('  Lesion: %s\n', lesion.description);

        % Apply stochastic lesion
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

    fprintf('\nCompleted all stochastic lesions for %s\n', preset.name);
end

fprintf('\n========================================\n');
fprintf('All stochastic lesion validations complete!\n');
fprintf('Figures saved to: %s\n', outDir);
fprintf('========================================\n');

%% Preset setup functions (identical to uniform lesion script)

function pars = setupDerivative()
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'derivative';
end

function pars = setupLaggedBiological()
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';

repoRoot = fileparts(fileparts(mfilename('fullpath')));
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');

if ~exist(weightsFile, 'file')
    error('Cached weights not found. Run validateSHFigs9to14.m first (Phase 1).');
end

cached = load(weightsFile);
pars.rgc.v1Weights = cached.v1Weights;
fprintf('    Loaded cached weights (%dx%d)\n', size(pars.rgc.v1Weights, 1), size(pars.rgc.v1Weights, 2));
end

%% Stochastic lesion functions

function pars = lesionAmplitudeStochastic(parsBase)
% Random uncorrelated amplitude: each location Uniform(0.3, 0.7)
pars = parsBase;
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

rng(42);
amplitudeMap = 0.3 + 0.4 * rand(Y, X);

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
end

function pars = lesionDelayStochastic(parsBase)
% Random uncorrelated delay: each location {0, 1, 2, 3} frames
pars = parsBase;
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

rng(43);
delayMap = randi([0 3], Y, X);

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayMap = delayMap;
end

function pars = lesionAmplitudePatchyCorrelated(parsBase)
% Spatially correlated (patchy) amplitude deficit
pars = parsBase;
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

rng(44);
rawMap = rand(Y, X);

% Smooth with Gaussian (creates patches)
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);

% Scale to [0.3, 0.7]
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));
amplitudeMap = 0.3 + 0.4 * smoothMap;

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
end

function pars = lesionDelayPatchyCorrelated(parsBase)
% Spatially correlated (patchy) delay deficit
pars = parsBase;
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

rng(45);
rawMap = rand(Y, X);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);

% Threshold into {0, 1, 2, 3}
thresholds = [0.25 0.5 0.75];
delayMap = zeros(Y, X);
for i = 1:length(thresholds)
    delayMap(smoothMap > thresholds(i)) = i;
end

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayMap = delayMap;
end

function pars = lesionCoupledAmplitudeDelay(parsBase)
% Coupled: worse amplitude → longer delay (realistic correlation)
pars = parsBase;
dims = shGetDims(pars, 'v1Complex', [1 1 1]);
Y = dims(1); X = dims(2);

rng(46);
rawMap = rand(Y, X);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));

% Amplitude: inversely related to damage
amplitudeMap = 0.3 + 0.4 * smoothMap; % [0.3, 0.7]

% Delay: inversely related to amplitude
delayMap = zeros(Y, X);
delayMap(amplitudeMap < 0.4) = 3;  % worst → 3 frames
delayMap(amplitudeMap >= 0.4 & amplitudeMap < 0.5) = 2;
delayMap(amplitudeMap >= 0.5 & amplitudeMap < 0.6) = 1;

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeMap = amplitudeMap;
pars.rgc.impairmentDelayMap = delayMap;
end

%% Figure generation functions (same as uniform lesion script)

function generateFig9(pars, label, description, outDir)
fprintf('    Generating Figure 9...\n');
figure('Name', sprintf('Fig 9 - %s', description), 'Color', 'w', ...
    'Position', [100 100 800 800], 'Visible', 'off');

[x, v1Sin] = shTuneGratingDirection(pars, [0 .35], 'v1Complex', 21);
[~, v1Plaid] = shTunePlaidDirection(pars, [0 .35], 'v1Complex', 21);
[~, mtSin] = shTuneGratingDirection(pars, [0 .35], 'mtPattern', 21);
[~, mtPlaid] = shTunePlaidDirection(pars, [0 .35], 'mtPattern', 21);

subplax([2 2], [1.15 1.15], [.7 .7], 1);
polar(0, 1.25*max(mtSin)); hold on; polar(x, mtSin, 'k.-'); hold off; title('MT, grating')

subplax([2 2], [1.15 2.15], [.7 .7], 1);
polar(0, 1.25*max(mtPlaid)); hold on; polar(x, mtPlaid, 'k.-'); hold off; title('MT, plaid')

subplax([2 2], [2.15 1.15], [.7 .7], 1);
polar(0, 1.25*max(v1Sin)); hold on; polar(x, v1Sin, 'k.-'); hold off; title('V1, grating')

subplax([2 2], [2.15 2.15], [.7 .7], 1);
polar(0, 1.15*max(v1Plaid)); hold on; polar(x, v1Plaid, 'k.-'); hold off; title('V1, plaid')

sgtitle(sprintf('Figure 9: %s', description));
saveas(gcf, fullfile(outDir, sprintf('fig9_%s.png', label))); close(gcf);
end

function generateFig10(pars, label, description, outDir)
fprintf('    Generating Figure 10...\n');
figure('Name', sprintf('Fig 10 - %s', description), 'Color', 'w', ...
    'Position', [150 100 500 900], 'Visible', 'off');

dims = shGetDims(pars, 'mtPattern');
neurons = [0 1.5; 0 .125; 0 9];
speedMinMax = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
nDataPoints = 6;
xSpeed = zeros(3, nDataPoints);
yPref = zeros(3, nDataPoints);
yAnti = zeros(3, nDataPoints);
yNull = zeros(3, nDataPoints);

for i = 1:3
    [xSpeed(i,:), yPref(i,:)] = shTuneBarSpeed(pars, neurons(i,:), 'mtPattern', ...
        nDataPoints, speedMinMax(i,1), speedMinMax(i,2), neurons(i,1), 1, barEdgeWidth(i));
    [~, yAnti(i,:)] = shTuneBarSpeed(pars, neurons(i,:), 'mtPattern', ...
        nDataPoints, speedMinMax(i,1), speedMinMax(i,2), neurons(i,1)+pi, 1, barEdgeWidth(i));
    [pop, ind, res] = shModel(zeros(dims), pars, 'mtPattern', neurons(i,:));
    yNull(i,:) = mean(shGetNeuron(res, ind)) * ones(1, nDataPoints);
end

for i = 1:3
    subplax([3 1], [4-i+0.1 1.1], [.7 .7], 1);
    semilogx(xSpeed(i,:), yPref(i,:), 'b-', xSpeed(i,:), yPref(i,:), 'k.');
    hold on; semilogx(xSpeed(i,:), yAnti(i,:), 'r-', xSpeed(i,:), yAnti(i,:), 'k.');
    semilogx(xSpeed(i,:), yNull(i,:), 'k--'); hold off
    xlabel('speed (px/frame)'); ylabel('response');
    axis([xSpeed(i,1), xSpeed(i,end), 0, 1.2*max(yPref(i,:))]);
end

sgtitle(sprintf('Figure 10: %s', description));
saveas(gcf, fullfile(outDir, sprintf('fig10_%s.png', label))); close(gcf);
end

function generateFig11(pars, label, description, outDir)
fprintf('    Generating Figure 11...\n');
figure('Name', sprintf('Fig 11 - %s', description), 'Color', 'w', 'Visible', 'off');

[x, yPref] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71);
[~, yAnti] = shTuneDotCoherence(pars, [0 1], 'mtPattern', 8, 71, pi);

plot(x, yPref, 'r-', x, yPref, 'k.'); hold on;
plot(x, yAnti, 'b-', x, yAnti, 'k.'); hold off
xlabel('coherence'); ylabel('response');
title(sprintf('Figure 11: %s', description));
legend('Preferred', 'Antipreferred');
saveas(gcf, fullfile(outDir, sprintf('fig11_%s.png', label))); close(gcf);
end

function generateFig12(pars, label, description, outDir)
fprintf('    Generating Figure 12...\n');
figure('Name', sprintf('Fig 12 - %s', description), 'Color', 'w', 'Visible', 'off');

dims = shGetDims(pars, 'mtPattern', [1 1 71]);
neuron = [0 1]; pref = neuron;
nPref = [0, 8, 16, 64, 256]; nMask = [0, 16, 64, 256];
cols = 'rgbk'; h = zeros(1+length(nMask), 2);
yRes = zeros(length(nPref), length(nMask));
rfRad = 15.5; rfArea = pi*rfRad^2;

[pop, ind, res] = shModel(zeros(dims), pars, 'mtPattern', neuron);
yNull = mean(shGetNeuron(res, ind)) * ones(1, length(nPref));
w = mkWin(dims, 15, 2);

for j = 1:length(nMask)
    for i = 1:length(nPref)
        sDots = mkDots(dims, pref(1), pref(2), nPref(i)/rfArea);
        sMask = mkDots(dims, pref(1)+pi, pref(2), nMask(j)/rfArea);
        [~, ~, res] = shModel(10*w.*min(sDots+sMask,1), pars, 'mtPattern', neuron);
        yRes(i,j) = mean(shGetNeuron(res, ind));
    end
end

h(1,1) = plot([0 0],[1 1],'w'); hold on
for n = 1:length(nMask)
    h(n+1,:) = plot(nPref, yRes(:,n), sprintf('%c-',cols(n)), nPref, yRes(:,n), 'k.');
end
plot(nPref, yNull, 'k--'); hold off
axis([min(nPref) max(nPref) 0 1.2*max(yRes(:))]);
title(sprintf('Figure 12: %s', description));
eval(['legend(h(:,1),''num antipref''',sprintf(',''%d''',nMask'),')']);
xlabel('Num preferred dots'); ylabel('response');
saveas(gcf, fullfile(outDir, sprintf('fig12_%s.png', label))); close(gcf);
end

function generateFig13(pars, label, description, outDir)
fprintf('    Generating Figure 13...\n');
figure('Name', sprintf('Fig 13 - %s', description), 'Color', 'w', 'Visible', 'off');

[x, y] = shTuneDotMaskDirection(pars, [pi 1], 'mtPattern', 9, 101);
x = [x*180/pi, 360]; y = [y, y(1)];

h1 = plot(x, y, 'r-', x, y, 'k.'); hold on;
h2 = plot(x, max(y)*ones(size(y)), 'k--'); hold off
axis([0 360 0 1.2*max(y)]);
title(sprintf('Figure 13: %s', description));
xlabel('mask direction (deg)'); ylabel('response');
legend([h1(1),h2(1)], 'pref+mask', 'pref alone');
saveas(gcf, fullfile(outDir, sprintf('fig13_%s.png', label))); close(gcf);
end

function generateFig14(pars, label, description, outDir)
fprintf('    Generating Figure 14...\n');
figure('Name', sprintf('Fig 14 - %s', description), 'Color', 'w', 'Visible', 'off');

dims = shGetDims(pars, 'mtPattern', [1 1 15]);
neuron = [0 1]; pref = neuron;
x = linspace(-pi, pi, 9);
yDots = zeros(size(x)); yMasked = zeros(size(x));

[pop, ind, res] = shModel(zeros(dims), pars, 'mtPattern', neuron);
yNull = mean(shGetNeuron(res, ind)) * ones(size(yDots));

for i = 1:length(x)
    sDots = mkDots(dims, x(i), pref(2), .15);
    sMask = mkDots(dims, pref(1)+pi, pref(2), .15);
    [~, ~, res1] = shModel(sDots, pars, 'mtPattern', neuron);
    [~, ~, res2] = shModel(min(sDots+sMask,1), pars, 'mtPattern', neuron);
    yDots(i) = mean(shGetNeuron(res1, ind));
    yMasked(i) = mean(shGetNeuron(res2, ind));
end

h = zeros(3,2);
h(1,:) = plot(180*x/pi, yDots, 'r-', 180*x/pi, yDots, 'k.'); hold on
h(2,:) = plot(180*x/pi, yMasked, 'b-', 180*x/pi, yMasked, 'k.');
h(3,:) = plot(180*x/pi, yNull, 'k--'); hold off
axis([-180 180 0 1.2*max([yNull,yDots,yMasked])]);
title(sprintf('Figure 14: %s', description));
legend(h(:,1), 'single', 'w/ mask', 'spontaneous');
xlabel('Direction (deg)'); ylabel('response');
saveas(gcf, fullfile(outDir, sprintf('fig14_%s.png', label))); close(gcf);
end
