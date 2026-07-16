%% validateSHFigs9to14_lesions_stochastic.m
% Phase 2b: Stochastic/heterogeneous lesion effects on SH Figures 9-14
%
% Tests spatially heterogeneous lesions where different regions get different
% deficits - more realistic for optic neuritis than uniform lesions.
%
% Uses FIXED V1 weights (no refitting) - lesions modify only RGC spatial maps.
%
% --- Stimulus-size handling ---
% Each tuning call (shTuneGratingDirection, shTuneBarSpeed, etc.) builds its own
% stimulus, and pars.rgc.impairmentAmplitudeMap/impairmentDelayMap must match that
% stimulus's X-Y exactly (shApplyRgcImpairment errors otherwise - it compares
% size(map) to size(rgcChannel(:,:,1)), and the RGC channel inherits the raw
% stimulus's X-Y unchanged). Different panels need different sizes:
%   v1Complex stage                -> 19x19
%   mtPattern stage (most panels)  -> 37x37
%   mtPattern stage, shTuneBarSpeed -> 51x51 (it requests a larger [15 15 T] window)
% (Confirmed empirically; constant across nFrames and across the two presets here.)
%
% Rather than resample stimuli to one size (which changes results ~20% for the
% dot stimuli in Figs 11-14, though it's exact for the gratings in Fig 9 - verified
% separately), each lesion defines ONE 51x51 damage field (the max size needed).
% Every call center-crops that same field down to whatever X-Y its own stimulus
% needs, via cropLesionForCall() below. This keeps a single physical lesion
% consistent across every panel while leaving every stimulus exactly as-is.
%
% Self-locating script: adds MTmodel path automatically
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

% Where to save figures
outDir = fullfile(tempdir, 'MTmodel_stochastic_lesion_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('Stochastic lesion figures will be saved to:\n  %s\n\n', outDir);

FIELD_SIZE = 51;  % max X-Y needed across all Fig 9-14 panels (see header note)

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
    @(p) lesionAmplitudeStochastic(p, FIELD_SIZE), ...
    @(p) lesionDelayStochastic(p, FIELD_SIZE), ...
    @(p) lesionAmplitudePatchyCorrelated(p, FIELD_SIZE), ...
    @(p) lesionDelayPatchyCorrelated(p, FIELD_SIZE), ...
    @(p) lesionCoupledAmplitudeDelay(p, FIELD_SIZE)});

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

        % Apply stochastic lesion (stores a FIELD_SIZE x FIELD_SIZE damage field;
        % individual calls crop it to their own stimulus size, see generateFigX)
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
pars.rgc.mode = 'custom'; % prevent shModelV1Linear from rebuilding these classes
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
% Each stores a FIELD_SIZE x FIELD_SIZE damage field on pars.rgc.impairment*FieldFull.
% cropLesionForCall() crops it to the exact X-Y each stimulus needs, per call.

function pars = lesionAmplitudeStochastic(parsBase, fieldSize)
% Random uncorrelated amplitude: spatial heterogeneity Uniform(0.3, 0.7)
pars = parsBase;
rng(42);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = 0.3 + 0.4 * rand(fieldSize, fieldSize);
end

function pars = lesionDelayStochastic(parsBase, fieldSize)
% Random uncorrelated delay: spatial heterogeneity {0, 1, 2, 3} frames
pars = parsBase;
rng(43);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = randi([0 3], fieldSize, fieldSize);
end

function pars = lesionAmplitudePatchyCorrelated(parsBase, fieldSize)
% Spatially correlated (patchy) amplitude deficit - realistic for ON
pars = parsBase;
rng(44);
rawMap = rand(fieldSize, fieldSize);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = 0.3 + 0.4 * smoothMap;
end

function pars = lesionDelayPatchyCorrelated(parsBase, fieldSize)
% Spatially correlated (patchy) delay deficit
pars = parsBase;
rng(45);
rawMap = rand(fieldSize, fieldSize);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);

thresholds = [0.25 0.5 0.75];
delayField = zeros(fieldSize, fieldSize);
for i = 1:length(thresholds)
    delayField(smoothMap > thresholds(i)) = i;
end

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = delayField;
end

function pars = lesionCoupledAmplitudeDelay(parsBase, fieldSize)
% Coupled: worse amplitude -> longer delay (realistic damage correlation)
pars = parsBase;
rng(46);
rawMap = rand(fieldSize, fieldSize);
sigma = 3.0;
smoothMap = imgaussfilt(rawMap, sigma);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));

amplitudeField = 0.3 + 0.4 * smoothMap; % [0.3, 0.7]

delayField = zeros(fieldSize, fieldSize);
delayField(amplitudeField < 0.4) = 3;
delayField(amplitudeField >= 0.4 & amplitudeField < 0.5) = 2;
delayField(amplitudeField >= 0.5 & amplitudeField < 0.6) = 1;

pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = amplitudeField;
pars.rgc.impairmentDelayFieldFull = delayField;
end

%% Crop helper: match the lesion field to whatever X-Y a given call needs
%
% stageName/outputDims must mirror the outputDims the target tuning function
% passes to its OWN internal shGetDims call, so the cropped map lines up with
% the stimulus that function actually builds. Only the spatial part of
% outputDims matters (X-Y is independent of frame count T; verified).

function parsOut = cropLesionForCall(pars, stageName, outputDims)
parsOut = pars;
if ~isfield(pars.rgc, 'impairmentEnabled') || pars.rgc.impairmentEnabled ~= 1
    return;
end

d = shGetDims(pars, stageName, outputDims);
Y = d(1); X = d(2);

if isfield(pars.rgc, 'impairmentAmplitudeFieldFull') && ~isempty(pars.rgc.impairmentAmplitudeFieldFull)
    parsOut.rgc.impairmentAmplitudeMap = localCenterCrop(pars.rgc.impairmentAmplitudeFieldFull, Y, X);
end
if isfield(pars.rgc, 'impairmentDelayFieldFull') && ~isempty(pars.rgc.impairmentDelayFieldFull)
    parsOut.rgc.impairmentDelayMap = localCenterCrop(pars.rgc.impairmentDelayFieldFull, Y, X);
end
end

function out = localCenterCrop(F, Y, X)
if size(F,1) < Y || size(F,2) < X
    error('cropLesionForCall:fieldTooSmall', ...
        'Lesion field [%d %d] is smaller than required stimulus size [%d %d]. Increase FIELD_SIZE.', ...
        size(F,1), size(F,2), Y, X);
end
offY = floor((size(F,1) - Y) / 2);
offX = floor((size(F,2) - X) / 2);
out = F(offY+1:offY+Y, offX+1:offX+X);
end

%% Figure generation functions
% Each model-invoking call is preceded by cropLesionForCall(pars, stage, outputDims)
% using the SAME outputDims the target tuning function passes internally to
% shGetDims, so the cropped map always matches that call's actual stimulus.

function generateFig9(pars, label, description, outDir)
fprintf('    Generating Figure 9...\n');
figure('Name', sprintf('Fig 9 - %s', description), 'Color', 'w', ...
    'Position', [100 100 800 800], 'Visible', 'off');

parsV1 = cropLesionForCall(pars, 'v1Complex', [1 1 31]);
parsMT = cropLesionForCall(pars, 'mtPattern', [1 1 31]);

[x, v1Sin] = shTuneGratingDirection(parsV1, [0 .35], 'v1Complex', 21);
[~, v1Plaid] = shTunePlaidDirection(parsV1, [0 .35], 'v1Complex', 21);
[~, mtSin] = shTuneGratingDirection(parsMT, [0 .35], 'mtPattern', 21);
[~, mtPlaid] = shTunePlaidDirection(parsMT, [0 .35], 'mtPattern', 21);

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

% shTuneBarSpeed requests a [15 15 71]-derived window internally (-> 51x51)
parsBar = cropLesionForCall(pars, 'mtPattern', [15 15 71]);
% the null-response probe below uses zeros(dims) with default outputDims (-> 37x37)
parsNull = cropLesionForCall(pars, 'mtPattern', [1 1 1]);
dims = shGetDims(parsNull, 'mtPattern');

neurons = [0 1.5; 0 .125; 0 9];
speedMinMax = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
nDataPoints = 6;
xSpeed = zeros(3, nDataPoints);
yPref = zeros(3, nDataPoints);
yAnti = zeros(3, nDataPoints);
yNull = zeros(3, nDataPoints);

for i = 1:3
    [xSpeed(i,:), yPref(i,:)] = shTuneBarSpeed(parsBar, neurons(i,:), 'mtPattern', ...
        nDataPoints, speedMinMax(i,1), speedMinMax(i,2), neurons(i,1), 1, barEdgeWidth(i));
    [~, yAnti(i,:)] = shTuneBarSpeed(parsBar, neurons(i,:), 'mtPattern', ...
        nDataPoints, speedMinMax(i,1), speedMinMax(i,2), neurons(i,1)+pi, 1, barEdgeWidth(i));
    [pop, ind, res] = shModel(zeros(dims), parsNull, 'mtPattern', neurons(i,:));
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

parsMT = cropLesionForCall(pars, 'mtPattern', [1 1 71]);
[x, yPref] = shTuneDotCoherence(parsMT, [0 1], 'mtPattern', 8, 71);
[~, yAnti] = shTuneDotCoherence(parsMT, [0 1], 'mtPattern', 8, 71, pi);

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

parsMT = cropLesionForCall(pars, 'mtPattern', [1 1 71]);
dims = shGetDims(parsMT, 'mtPattern', [1 1 71]);
neuron = [0 1]; pref = neuron;
nPref = [0, 8, 16, 64, 256]; nMask = [0, 16, 64, 256];
cols = 'rgbk'; h = zeros(1+length(nMask), 2);
yRes = zeros(length(nPref), length(nMask));
rfRad = 15.5; rfArea = pi*rfRad^2;

[pop, ind, res] = shModel(zeros(dims), parsMT, 'mtPattern', neuron);
yNull = mean(shGetNeuron(res, ind)) * ones(1, length(nPref));
w = mkWin(dims, 15, 2);

for j = 1:length(nMask)
    for i = 1:length(nPref)
        sDots = mkDots(dims, pref(1), pref(2), nPref(i)/rfArea);
        sMask = mkDots(dims, pref(1)+pi, pref(2), nMask(j)/rfArea);
        [~, ~, res] = shModel(10*w.*min(sDots+sMask,1), parsMT, 'mtPattern', neuron);
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

parsMT = cropLesionForCall(pars, 'mtPattern', [1 1 101]);
[x, y] = shTuneDotMaskDirection(parsMT, [pi 1], 'mtPattern', 9, 101);
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

parsMT = cropLesionForCall(pars, 'mtPattern', [1 1 15]);
dims = shGetDims(parsMT, 'mtPattern', [1 1 15]);
neuron = [0 1]; pref = neuron;
x = linspace(-pi, pi, 9);
yDots = zeros(size(x)); yMasked = zeros(size(x));

[pop, ind, res] = shModel(zeros(dims), parsMT, 'mtPattern', neuron);
yNull = mean(shGetNeuron(res, ind)) * ones(size(yDots));

for i = 1:length(x)
    sDots = mkDots(dims, x(i), pref(2), .15);
    sMask = mkDots(dims, pref(1)+pi, pref(2), .15);
    [~, ~, res1] = shModel(sDots, parsMT, 'mtPattern', neuron);
    [~, ~, res2] = shModel(min(sDots+sMask,1), parsMT, 'mtPattern', neuron);
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
