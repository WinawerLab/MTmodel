%[text] # Form-from-motion task: full coherence, model against controls
%[text] Compares the model's psychometric function at coherence 1 (step 3, matched-filter decoder, RGC noise SD 0.05) with the 10 control units run with the current experiment code, also at coherence 1. Both are fitted the same way: one psychometric function of log speed, from the coherence-1 trials only, chance 0.1, lapse rate at most 0.06 (`shFitSpeedCoherencePsychometric` with a single coherence). The model's speeds are in its own units (`docs/UNITS_AND_SCALE.md` §6), so its threshold is reported but not compared as a number; the slope, the ceiling and the shape are compared on speed relative to each observer's own threshold.
%[text] Needs the step-3 results in `explore/_figs/` and the control fits from the EXPLORING_Speed_Coherence_Psychometrics project.

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
step3File = fullfile(figureDir, "formFromMotionSpeedCoherence.mat");
controlFitsFile = fullfile(getenv("HOME"), "repos", "Research", "Exploring", ...
    "EXPLORING_Speed_Coherence_Psychometrics", "analysis", "out", "fits.mat");
controlUnitNames = ["wlsubj114", "wlsubj147", "wlsubj178", "wlsubj195", "wlsubj208"];
maxFitSpeedDegPerSec = 10;
fastFactor = 3;
coherenceTolerance = 1e-9;
model = load(step3File);
controls = load(controlFitsFile);
isCurrentCode = startsWith(string({controls.S.name}), controlUnitNames) & ...
    [controls.S.durationMs] == 100;
units = controls.S(isCurrentCode);
nUnits = numel(units);

%%
%[text] ## Fits at coherence 1
%[text] The model's fit uses speeds up to 10 deg/s, as in step 3; its 20 deg/s point, past MT's fastest tuning, is shown but not fitted. The controls' staircases never went faster than 4 deg/s.
isModelFull = abs(model.trialCoherence-1) < coherenceTolerance;
modelTrials = isModelFull & model.trialSpeed <= maxFitSpeedDegPerSec;
modelFit = shFitSpeedCoherencePsychometric(model.trialSpeed(modelTrials), ...
    model.trialCoherence(modelTrials), model.correctMatched(modelTrials));
modelFast = modelTrials & model.trialSpeed >= fastFactor*modelFit.thresholdAtCoherence1;

relativeSpeedByUnit = cell(nUnits, 1);
correctByUnit = cell(nUnits, 1);
unitFast = zeros(nUnits, 1);
unitFastCount = zeros(nUnits, 1);
for k = nUnits:-1:1    % filled from the end, so the struct array is allocated once
    atFull = abs(units(k).coh(:)-1) < coherenceTolerance;
    speed = units(k).speed(:);
    correct = logical(units(k).correct(:));
    controlFits(k) = shFitSpeedCoherencePsychometric(speed(atFull), ones(nnz(atFull), 1), correct(atFull));
    relativeSpeedByUnit{k} = speed(atFull)/controlFits(k).thresholdAtCoherence1;
    correctByUnit{k} = correct(atFull);
    isFast = atFull & speed >= fastFactor*controlFits(k).thresholdAtCoherence1;
    unitFast(k) = mean(correct(isFast));
    unitFastCount(k) = nnz(isFast);
end

controlThreshold = [controlFits.thresholdAtCoherence1].';
controlSigma = [controlFits.sigma].';
controlLambda = [controlFits.lambda].';
observer = ["model"; string({units.name}).'; "controls, median"];
threshold = [modelFit.thresholdAtCoherence1; controlThreshold; median(controlThreshold)];
sigma = [modelFit.sigma; controlSigma; median(controlSigma)];
lambda = [modelFit.lambda; controlLambda; median(controlLambda)];
proportionCorrectAbove3x = [mean(model.correctMatched(modelFast)); unitFast; ...
    sum(unitFast.*unitFastCount, "omitnan")/sum(unitFastCount)];
trialsAbove3x = [nnz(modelFast); unitFastCount; sum(unitFastCount)];
comparisonTable = table(observer, threshold, sigma, lambda, proportionCorrectAbove3x, trialsAbove3x);
comparisonTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## The curves
%[text] Left: proportion correct against speed relative to each observer's own threshold at coherence 1. Black squares: the controls' trials pooled into bins of 0.25 log units (bins with at least 5 trials). Grey lines: each control's fitted curve. Blue: the model's points (the open circle, 20 deg/s, was not fitted) and fitted curve. Right: the same fitted curves against absolute speed; the model's speeds are in model units and are not comparable with the controls'.
controlRelative = vertcat(relativeSpeedByUnit{:});
controlCorrect = vertcat(correctByUnit{:});
binEdges = -1.5:0.25:1.5;
binCentres = binEdges(1:end-1) + diff(binEdges)/2;
[~, ~, bin] = histcounts(log10(controlRelative), binEdges);
inBin = bin > 0;
binCount = accumarray(bin(inBin), 1, [numel(binCentres) 1]);
binCorrect = accumarray(bin(inBin), controlCorrect(inBin), [numel(binCentres) 1]);
minimumBinCount = 5;
shown = binCount >= minimumBinCount;
relativeGrid = logspace(-1.5, 1.5, 200);
modelRelativeSpeed = model.speedsDegPerSec/modelFit.thresholdAtCoherence1;
isFitted = model.speedsDegPerSec <= maxFitSpeedDegPerSec;
modelColor = [0 0.447 0.741];
controlColor = [0.6 0.6 0.6];

tiledlayout(1, 2, TileSpacing="compact");
nexttile
hold on
for k = 1:nUnits
    plot(relativeGrid, shSpeedCoherencePsychometric(controlFits(k), ...
        relativeGrid*controlFits(k).thresholdAtCoherence1, 1), Color=controlColor)
end
plot(10.^binCentres(shown), binCorrect(shown)./binCount(shown), "ks", MarkerFaceColor="k")
plot(relativeGrid, shSpeedCoherencePsychometric(modelFit, ...
    relativeGrid*modelFit.thresholdAtCoherence1, 1), Color=modelColor, LineWidth=2)
plot(modelRelativeSpeed(isFitted), model.proportionMatched(1, isFitted), "o", ...
    Color=modelColor, MarkerFaceColor=modelColor)
plot(modelRelativeSpeed(~isFitted), model.proportionMatched(1, ~isFitted), "o", Color=modelColor)
hold off
relativeAxes = gca;
relativeAxes.XScale = "log";
yline(0.1, "k:")
ylim([0 1])
xlabel("speed / own threshold at coherence 1")
ylabel("proportion correct")
title("Coherence 1: shape")
grid on

nexttile
hold on
for k = 1:nUnits
    speedRange = logspace(log10(0.01), log10(4), 200);
    plot(speedRange, shSpeedCoherencePsychometric(controlFits(k), speedRange, 1), Color=controlColor)
end
modelRange = logspace(log10(min(model.speedsDegPerSec)), log10(max(model.speedsDegPerSec)), 200);
plot(modelRange, shSpeedCoherencePsychometric(modelFit, modelRange, 1), Color=modelColor, LineWidth=2)
plot(model.speedsDegPerSec, model.proportionMatched(1, :), "o", Color=modelColor, MarkerFaceColor=modelColor)
hold off
absoluteAxes = gca;
absoluteAxes.XScale = "log";
yline(0.1, "k:")
ylim([0 1])
xlabel("dot speed (deg/s; model in model units)")
title("Coherence 1: absolute speed")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionFullCoherence.png"), Resolution=150)

%%
%[text] ## What to look for
%[text] - Slope: the model's σ against the controls' spread.
%[text] - Ceiling: how close each observer gets to 100% correct well above threshold (3× their own threshold, up to the fastest speed tested).
%[text] - Shape: whether the model's points and curve lie within the band of control curves on the relative-speed axis. \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
