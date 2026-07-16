%% quantitativeAnalysisFigs9to14.m
% Quantitative analysis of SH Figs 9-14 tuning curves across:
%   - Phase 1: three baseline model paths (legacy, derivative, lagged)
%   - Phase 2: uniform per-class lesions (amplitude/delay, +biological variants
%     for the lagged preset: parasol-only amplitude, ON-only delay)
%   - Phase 2b: stochastic/patchy lesions via pars.rgc.impairment*Map (random
%     amplitude, random delay, patchy amplitude, patchy delay, coupled amp+delay)
%
% Metrics computed per condition (mtPattern stage only - MT is the population of
% interest for direction/speed/coherence biases):
%   dir_peak, dir_dsi, dir_fwhm_deg   - Fig 9 direction tuning (grating)
%   speed_{bandpass,lowpass,highpass}_{peak,prefspeed} - Fig 10 speed tuning
%   coh_peak, coh_slope               - Fig 11 dot coherence tuning
%
% Phase 2/2b lesions modify RGC parameters only; V1 weights stay fixed (loaded
% from the cached fit). Phase 2b lesions use a single physical FIELD_SIZE x
% FIELD_SIZE damage field, center-cropped per call to match whatever stimulus
% size that tuning function needs (see cropLesionForCall below) - identical
% approach to validateSHFigs9to14_lesions_stochastic.m so the same physical
% lesion is being measured here as was visualized there.
%
% Output: explore/quantitativeAnalysisFigs9to14.m results ->
%   /tmp/MTmodel_quantitative_analysis/
%     all_conditions_metrics.csv          - raw metrics, one row per condition
%     pct_change_vs_baseline.csv          - % change (or octave shift) vs matched preset baseline
%     uniform_vs_stochastic_comparison.csv - amplitude-type and delay-type lesions side by side
%     lesion_comparison_bars.png          - grouped bar summary

% Self-locating script
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

outDir = fullfile(tempdir, 'MTmodel_quantitative_analysis');
if ~exist(outDir, 'dir'), mkdir(outDir); end
fprintf('Quantitative analysis results will be saved to:\n  %s\n\n', outDir);

FIELD_SIZE = 51;

%% Load cached V1 weights (required for the lagged preset)
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
if ~exist(weightsFile, 'file')
    error('Cached weights not found. Run validateSHFigs9to14.m first (Phase 1).');
end
cached = load(weightsFile);
v1Weights = cached.v1Weights;
fprintf('Loaded cached V1 weights (%dx%d)\n\n', size(v1Weights, 1), size(v1Weights, 2));

%% Build the full list of conditions to analyze
configList = {};

configList{end+1} = struct('group', 'phase1', 'preset', 'legacy', 'lesion', 'baseline', ...
    'description', 'Legacy SH (no RGC)', 'setupFn', @() setupLegacy());
configList{end+1} = struct('group', 'phase1', 'preset', 'derivative', 'lesion', 'baseline', ...
    'description', 'Derivative preset', 'setupFn', @() setupDerivative());
configList{end+1} = struct('group', 'phase1', 'preset', 'lagged', 'lesion', 'baseline', ...
    'description', 'Lagged midget/parasol', 'setupFn', @() setupLaggedBiological(v1Weights));

configList{end+1} = struct('group', 'phase2_uniform', 'preset', 'derivative', 'lesion', 'amplitude_uniform', ...
    'description', 'Derivative + uniform 50% amplitude', 'setupFn', @() lesionAmplitudeUniform(setupDerivative()));
configList{end+1} = struct('group', 'phase2_uniform', 'preset', 'derivative', 'lesion', 'delay_uniform', ...
    'description', 'Derivative + uniform 2-frame delay', 'setupFn', @() lesionDelayUniform(setupDerivative()));
configList{end+1} = struct('group', 'phase2_uniform', 'preset', 'lagged', 'lesion', 'amplitude_uniform', ...
    'description', 'Lagged + uniform 50% amplitude', 'setupFn', @() lesionAmplitudeUniform(setupLaggedBiological(v1Weights)));
configList{end+1} = struct('group', 'phase2_uniform', 'preset', 'lagged', 'lesion', 'delay_uniform', ...
    'description', 'Lagged + uniform 2-frame delay', 'setupFn', @() lesionDelayUniform(setupLaggedBiological(v1Weights)));
configList{end+1} = struct('group', 'phase2_biological', 'preset', 'lagged', 'lesion', 'amplitude_parasol', ...
    'description', 'Lagged + parasol-only 70% amplitude', 'setupFn', @() lesionAmplitudeParasol(setupLaggedBiological(v1Weights)));
configList{end+1} = struct('group', 'phase2_biological', 'preset', 'lagged', 'lesion', 'delay_ON_only', ...
    'description', 'Lagged + ON-only 1-frame delay', 'setupFn', @() lesionDelayONOnly(setupLaggedBiological(v1Weights)));

stochLesions = struct(...
    'name', {'amplitude_random', 'delay_random', 'amplitude_patchy', 'delay_patchy', 'coupled'}, ...
    'description', {'random amplitude', 'random delay', 'patchy amplitude', 'patchy delay', 'coupled amp+delay'}, ...
    'fn', {@lesionAmplitudeStochastic, @lesionDelayStochastic, @lesionAmplitudePatchyCorrelated, ...
           @lesionDelayPatchyCorrelated, @lesionCoupledAmplitudeDelay});
presetSetups = struct('name', {'derivative', 'lagged'}, ...
    'fn', {@() setupDerivative(), @() setupLaggedBiological(v1Weights)});

for iPreset = 1:numel(presetSetups)
    for iLesion = 1:numel(stochLesions)
        presetFn = presetSetups(iPreset).fn;
        lesionFn = stochLesions(iLesion).fn;
        configList{end+1} = struct(...
            'group', 'phase2b_stochastic', ...
            'preset', presetSetups(iPreset).name, ...
            'lesion', stochLesions(iLesion).name, ...
            'description', sprintf('%s + %s', presetSetups(iPreset).name, stochLesions(iLesion).description), ...
            'setupFn', @() lesionFn(presetFn(), FIELD_SIZE)); %#ok<AGROW>
    end
end

fprintf('Analyzing %d conditions...\n\n', numel(configList));

%% Compute metrics for every condition
resultsTable = table();
t0 = tic;
for i = 1:numel(configList)
    cfg = configList{i};
    fprintf('[%2d/%2d] %-14s %-10s %-22s ', i, numel(configList), cfg.group, cfg.preset, cfg.lesion);
    tCond = tic;

    pars = cfg.setupFn();
    m = computeMetrics(pars);

    row = table({cfg.group}, {cfg.preset}, {cfg.lesion}, {cfg.description}, ...
        'VariableNames', {'group', 'preset', 'lesion', 'description'});
    row = [row, struct2table(m)]; %#ok<AGROW>
    resultsTable = [resultsTable; row]; %#ok<AGROW>

    fprintf('(%.1fs)\n', toc(tCond));
end
fprintf('\nAll conditions analyzed in %.1f minutes.\n\n', toc(t0)/60);

writetable(resultsTable, fullfile(outDir, 'all_conditions_metrics.csv'));
fprintf('Saved: all_conditions_metrics.csv\n');

%% Percent change (or octave shift for preferred-speed metrics) vs matched-preset baseline
baselineRows = resultsTable(strcmp(resultsTable.group, 'phase1'), :);
lesionRows = resultsTable(~strcmp(resultsTable.group, 'phase1'), :);

metricNames = {'dir_peak', 'dir_dsi', 'dir_fwhm_deg', 'coh_peak', 'coh_slope', ...
    'speed_bandpass_peak', 'speed_bandpass_prefspeed', ...
    'speed_lowpass_peak', 'speed_lowpass_prefspeed', ...
    'speed_highpass_peak', 'speed_highpass_prefspeed'};

pctChange = table();
for i = 1:height(lesionRows)
    row = lesionRows(i, :);
    baseIdx = strcmp(baselineRows.preset, row.preset{1});
    if ~any(baseIdx), continue; end
    baseRow = baselineRows(baseIdx, :);

    newRow = table(row.group, row.preset, row.lesion, row.description, ...
        'VariableNames', {'group', 'preset', 'lesion', 'description'});
    for k = 1:numel(metricNames)
        mn = metricNames{k};
        if endsWith(mn, 'prefspeed')
            colName = ['oct_' mn];
            newRow.(colName) = log2(row.(mn) / baseRow.(mn));
        else
            colName = ['pct_' mn];
            newRow.(colName) = 100 * (row.(mn) - baseRow.(mn)) / (abs(baseRow.(mn)) + eps);
        end
    end
    pctChange = [pctChange; newRow]; %#ok<AGROW>
end
writetable(pctChange, fullfile(outDir, 'pct_change_vs_baseline.csv'));
fprintf('Saved: pct_change_vs_baseline.csv\n');

%% Focused uniform-vs-stochastic comparison (per plan doc: "compare uniform vs stochastic disruption")
ampLesionNames = {'amplitude_uniform', 'amplitude_random', 'amplitude_patchy', 'coupled'};
delayLesionNames = {'delay_uniform', 'delay_random', 'delay_patchy', 'coupled'};
comparisonMask = ismember(pctChange.lesion, [ampLesionNames, delayLesionNames]);
uniformVsStochastic = pctChange(comparisonMask, ...
    {'preset', 'lesion', 'pct_dir_peak', 'pct_dir_dsi', 'pct_dir_fwhm_deg', 'pct_coh_peak'});
writetable(uniformVsStochastic, fullfile(outDir, 'uniform_vs_stochastic_comparison.csv'));
fprintf('Saved: uniform_vs_stochastic_comparison.csv\n\n');

fprintf('=== Uniform vs. stochastic disruption (mean |%% change| across metrics, by preset) ===\n');
for presetName = {'derivative', 'lagged'}
    pn = presetName{1};
    uMask = strcmp(pctChange.preset, pn) & ismember(pctChange.lesion, {'amplitude_uniform', 'delay_uniform'});
    sMask = strcmp(pctChange.preset, pn) & ismember(pctChange.lesion, ...
        {'amplitude_random', 'delay_random', 'amplitude_patchy', 'delay_patchy', 'coupled'});
    if any(uMask)
        uAvg = mean(abs([pctChange.pct_dir_peak(uMask); pctChange.pct_dir_dsi(uMask); pctChange.pct_coh_peak(uMask)]));
        fprintf('  %-12s uniform lesions:    mean |change| = %.1f%%\n', pn, uAvg);
    end
    if any(sMask)
        sAvg = mean(abs([pctChange.pct_dir_peak(sMask); pctChange.pct_dir_dsi(sMask); pctChange.pct_coh_peak(sMask)]));
        fprintf('  %-12s stochastic lesions: mean |change| = %.1f%%\n', pn, sAvg);
    end
end
fprintf('\n');

%% Summary bar plot
plotLesionComparison(pctChange, outDir);

fprintf('========================================\n');
fprintf('Results saved to: %s\n', outDir);
fprintf('========================================\n');

%% Preset setup functions

function pars = setupLegacy()
pars = shPars;
pars.rgc.enabled = 0;
end

function pars = setupDerivative()
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'derivative';
end

function pars = setupLaggedBiological(v1Weights)
pars = shPars;
pars.rgc.enabled = 1;
pars.rgc.mode = 'custom';
pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine = 'weights';
pars.rgc.classesMode = 'custom';
pars.rgc.v1Weights = v1Weights;
end

%% Phase 2: uniform / biological lesion functions (mirrors validateSHFigs9to14_lesions.m)

function pars = lesionAmplitudeUniform(pars)
for i = 1:length(pars.rgc.classes)
    pars.rgc.classes(i).gain = 0.5;
end
end

function pars = lesionDelayUniform(pars)
for i = 1:length(pars.rgc.classes)
    origKernel = pars.rgc.classes(i).temporalKernel;
    pars.rgc.classes(i).temporalKernel = [zeros(2, 1); origKernel];
end
end

function pars = lesionAmplitudeParasol(pars)
for i = 1:length(pars.rgc.classes)
    if contains(pars.rgc.classes(i).name, 'parasol', 'IgnoreCase', true)
        pars.rgc.classes(i).gain = 0.3;
    end
end
end

function pars = lesionDelayONOnly(pars)
for i = 1:length(pars.rgc.classes)
    if contains(pars.rgc.classes(i).rectify, 'on', 'IgnoreCase', true)
        origKernel = pars.rgc.classes(i).temporalKernel;
        pars.rgc.classes(i).temporalKernel = [zeros(1, 1); origKernel];
    end
end
end

%% Phase 2b: stochastic lesion functions (identical to validateSHFigs9to14_lesions_stochastic.m)

function pars = lesionAmplitudeStochastic(parsBase, fieldSize)
pars = parsBase;
rng(42);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = 0.3 + 0.4 * rand(fieldSize, fieldSize);
end

function pars = lesionDelayStochastic(parsBase, fieldSize)
pars = parsBase;
rng(43);
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = randi([0 3], fieldSize, fieldSize);
end

function pars = lesionAmplitudePatchyCorrelated(parsBase, fieldSize)
pars = parsBase;
rng(44);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, 3.0);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = 0.3 + 0.4 * smoothMap;
end

function pars = lesionDelayPatchyCorrelated(parsBase, fieldSize)
pars = parsBase;
rng(45);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, 3.0);
thresholds = [0.25 0.5 0.75];
delayField = zeros(fieldSize, fieldSize);
for i = 1:length(thresholds)
    delayField(smoothMap > thresholds(i)) = i;
end
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentDelayFieldFull = delayField;
end

function pars = lesionCoupledAmplitudeDelay(parsBase, fieldSize)
pars = parsBase;
rng(46);
rawMap = rand(fieldSize, fieldSize);
smoothMap = imgaussfilt(rawMap, 3.0);
smoothMap = (smoothMap - min(smoothMap(:))) / (max(smoothMap(:)) - min(smoothMap(:)));
amplitudeField = 0.3 + 0.4 * smoothMap;
delayField = zeros(fieldSize, fieldSize);
delayField(amplitudeField < 0.4) = 3;
delayField(amplitudeField >= 0.4 & amplitudeField < 0.5) = 2;
delayField(amplitudeField >= 0.5 & amplitudeField < 0.6) = 1;
pars.rgc.impairmentEnabled = 1;
pars.rgc.impairmentAmplitudeFieldFull = amplitudeField;
pars.rgc.impairmentDelayFieldFull = delayField;
end

%% Crop helper: match the lesion field to whatever X-Y a given call needs
% (identical logic to validateSHFigs9to14_lesions_stochastic.m; no-op for
% conditions that don't set pars.rgc.impairmentEnabled)

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
        'Lesion field [%d %d] is smaller than required stimulus size [%d %d].', ...
        size(F,1), size(F,2), Y, X);
end
offY = floor((size(F,1) - Y) / 2);
offX = floor((size(F,2) - X) / 2);
out = F(offY+1:offY+Y, offX+1:offX+X);
end

%% Metric computation

function m = computeMetrics(pars)

% --- Fig 9: direction tuning (grating, mtPattern) ---
parsFig9 = cropLesionForCall(pars, 'mtPattern', [1 1 31]);
[~, yDir] = shTuneGratingDirection(parsFig9, [0 .35], 'mtPattern', 21);
yDir = yDir(1:end-1); % drop duplicate 360deg==0deg sample

[prefResp, prefIdx] = max(yDir);
n = length(yDir);
antiIdx = mod(prefIdx - 1 + round(n/2), n) + 1;
antiResp = yDir(antiIdx);

m.dir_peak = prefResp;
m.dir_dsi = abs(prefResp - antiResp) / (prefResp + antiResp + eps);
m.dir_fwhm_deg = circularFWHM(yDir);

% --- Fig 10: speed tuning (bandpass/lowpass/highpass MT neurons) ---
parsFig10 = cropLesionForCall(pars, 'mtPattern', [15 15 71]);
neurons = [0 1.5; 0 .125; 0 9];
speedMinMax = [.3125 5; .0375 .6; 1 10];
barEdgeWidth = [2 1 11];
labels = {'bandpass', 'lowpass', 'highpass'};
for k = 1:3
    [xSp, ySp] = shTuneBarSpeed(parsFig10, neurons(k,:), 'mtPattern', 6, ...
        speedMinMax(k,1), speedMinMax(k,2), neurons(k,1), 1, barEdgeWidth(k));
    [peakResp, peakIdx] = max(ySp);
    m.(sprintf('speed_%s_peak', labels{k})) = peakResp;
    m.(sprintf('speed_%s_prefspeed', labels{k})) = xSp(peakIdx);
end

% --- Fig 11: dot coherence tuning (preferred direction) ---
parsFig11 = cropLesionForCall(pars, 'mtPattern', [1 1 71]);
[xCoh, yCoh] = shTuneDotCoherence(parsFig11, [0 1], 'mtPattern', 8, 71);
m.coh_peak = max(yCoh);
p = polyfit(xCoh, yCoh, 1);
m.coh_slope = p(1);

end

function fwhmDeg = circularFWHM(y)
% y: response sampled at n equally-spaced directions spanning the full circle
% (no duplicate endpoint). Returns full-width-at-half-max in degrees, measured
% around the peak; if the curve never drops to half-max within a full
% revolution (i.e. lesion has flattened tuning to non-selective), returns 360.
n = length(y);
dTheta = 360 / n;
[peakVal, peakIdx] = max(y);
minVal = min(y);
halfLevel = minVal + (peakVal - minVal) / 2;

y3 = [y, y, y];
mid = peakIdx + n;

i = mid;
steps = 0;
while y3(i) >= halfLevel && steps < n
    i = i - 1;
    steps = steps + 1;
end
if steps >= n
    fwhmDeg = 360;
    return;
end
fracL = (halfLevel - y3(i)) / (y3(i+1) - y3(i) + eps);
leftCross = i + fracL;

j = mid;
steps = 0;
while y3(j) >= halfLevel && steps < n
    j = j + 1;
    steps = steps + 1;
end
if steps >= n
    fwhmDeg = 360;
    return;
end
fracR = (halfLevel - y3(j-1)) / (y3(j) - y3(j-1) + eps);
rightCross = (j-1) + fracR;

fwhmDeg = (rightCross - leftCross) * dTheta;
end

%% Summary plot

function plotLesionComparison(pctChange, outDir)
presetNames = {'derivative', 'lagged'};
metricCols = {'pct_dir_peak', 'pct_dir_dsi', 'pct_dir_fwhm_deg', 'pct_coh_peak'};
metricTitles = {'Direction peak response', 'Direction DSI', 'Direction FWHM (width)', 'Coherence peak response'};

figure('Name', 'Lesion comparison', 'Color', 'w', 'Position', [100 100 1100 800], 'Visible', 'off');
for iMetric = 1:numel(metricCols)
    subplot(2, 2, iMetric);
    hold on;
    offset = 0;
    xticks_ = []; xticklabels_ = {};
    colors = lines(3);
    for iPreset = 1:numel(presetNames)
        pn = presetNames{iPreset};
        rows = pctChange(strcmp(pctChange.preset, pn), :);
        if isempty(rows), continue; end
        for r = 1:height(rows)
            groupColor = colors(1,:);
            if strcmp(rows.group{r}, 'phase2_biological'), groupColor = colors(2,:); end
            if strcmp(rows.group{r}, 'phase2b_stochastic'), groupColor = colors(3,:); end
            bar(offset, rows.(metricCols{iMetric})(r), 'FaceColor', groupColor);
            xticks_(end+1) = offset; %#ok<AGROW>
            xticklabels_{end+1} = sprintf('%s:%s', pn(1:4), rows.lesion{r}); %#ok<AGROW>
            offset = offset + 1;
        end
        offset = offset + 1; % gap between presets
    end
    hold off;
    set(gca, 'XTick', xticks_, 'XTickLabel', xticklabels_, 'XTickLabelRotation', 60, 'FontSize', 7);
    ylabel('% change vs baseline');
    title(metricTitles{iMetric});
    grid on;
end
sgtitle('Phase 2 / 2b lesion effects vs. matched-preset baseline (blue=uniform, orange=biological, yellow=stochastic)');
saveas(gcf, fullfile(outDir, 'lesion_comparison_bars.png'));
close(gcf);
fprintf('Saved: lesion_comparison_bars.png\n');
end
