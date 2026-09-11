%[text] # Form-from-motion task: internal noise against coherence
%[text] The premise of the whole approach is that lowering dot coherence (external noise) acts like raising internal noise. This script tests that inside the model. It runs the letter task at coherence 1 with several levels of RGC noise, across the same speeds as step 3, and compares the resulting curves with step 3's coherence curves (RGC noise SD 0.05). Both use the model's own speed axis, so the comparison does not depend on units.
%[text] Each curve, from either manipulation, is described by a psychometric function with a FREE ceiling: step 3 showed that each coherence has its own ceiling, which the standard fit (lapse at most 0.06) cannot express. If internal noise acts like reduced coherence, the noise curves and the coherence curves should trace one path through threshold, slope and ceiling.
%[text] About 2,000 model runs. Needs step 3's results in `explore/_figs/` for the comparison. Results and figures go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
if ~isfolder(figureDir)
    mkdir(figureDir);
end
pars = shPars("lagged");
outSz = [64 64 50];
units = shModelUnits();
templates = shLetterTemplates(pars, outSz);
chance = 1/numel(templates.letters);
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
noiseSds = [0.05 0.06 0.07 0.085 0.1 0.12];
nTrialsPerCondition = 40;
maxFitSpeedDegPerSec = 10;
freeCeilingMaxLapse = 0.9;
step3File = fullfile(figureDir, "formFromMotionSpeedCoherence.mat");

%%
%[text] ## Matched filters
%[text] Built exactly as in steps 3 and 4 (same seeds, no noise), so all three use the same observer.
filters = shMatchedFilterTemplates(pars, templates, NumPerLetter=8);

%%
%[text] ## Noise level × speed, at coherence 1
%[text] 6 noise levels × 8 speeds × 40 trials. Every condition uses the same seeds, so conditions are compared trial for trial. SD 0.05 is step 3's coherence-1 condition.
nLevels = numel(noiseSds);
nSpeeds = numel(speedsPxPerFrame);
proportionMatched = zeros(nLevels, nSpeeds);
dprimeMatched = zeros(nLevels, nSpeeds);
correctMatched = false(nLevels, nSpeeds, nTrialsPerCondition);
gridSeconds = 0;
for i = 1:nLevels
    noisyPars = pars;
    noisyPars.noise.rgcSd = noiseSds(i);
    for j = 1:nSpeeds
        gridRun = shRunLetterTrials(noisyPars, nTrialsPerCondition, ...
            SpeedPxPerFrame=speedsPxPerFrame(j), Coherence=1, ...
            Templates=templates, MatchedFilters=filters);
        proportionMatched(i, j) = gridRun.proportionCorrectMatched;
        dprimeMatched(i, j) = gridRun.dprimeMatched;
        correctMatched(i, j, :) = gridRun.choiceMatched == gridRun.trueIndex;
        gridSeconds = gridSeconds + gridRun.seconds;
    end
end
save(fullfile(figureDir, "formFromMotionNoiseLevel.mat"), "speedsPxPerFrame", "speedsDegPerSec", ...
    "noiseSds", "nTrialsPerCondition", "proportionMatched", "dprimeMatched", "correctMatched", "filters");
gridMinutes = gridSeconds/60;
gridMinutes %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Results as a table
%[text] Matched-filter proportion correct at coherence 1. Rows are RGC noise SDs, columns are dot speeds.
resultsTable = array2table(proportionMatched, RowNames="noise SD " + string(noiseSds), ...
    VariableNames=string(speedsDegPerSec) + " deg/s");
resultsTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## The two manipulations side by side
%[text] Left: step 3, lower coherence at RGC noise SD 0.05. Right: this run, more RGC noise at coherence 1. Same axes. The first line below checks that the SD 0.05 row here reproduced step 3's coherence-1 trials.
hasStep3 = isfile(step3File);
if hasStep3
    step3 = load(step3File);
    sameAsStep3 = isequal(squeeze(step3.correctMatched(1, :, :)), squeeze(correctMatched(1, :, :)));
else
    sameAsStep3 = NaN;
end
sameAsStep3 %#ok<NOPTS> displayed on purpose (Live Script)

%%
tiledlayout(1, 2, TileSpacing="compact");
nexttile
if hasStep3
    semilogx(step3.speedsDegPerSec, step3.proportionMatched.', "o-", LineWidth=1.4)
    legend("coherence " + string(step3.coherences), Location="northwest", AutoUpdate="off")
end
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (model deg/s)")
ylabel("proportion correct")
title("Lower coherence (noise SD 0.05)")
grid on
nexttile
semilogx(speedsDegPerSec, proportionMatched.', "o-", LineWidth=1.4)
legend("noise SD " + string(noiseSds), Location="northwest", AutoUpdate="off")
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (model deg/s)")
title("More internal noise (coherence 1)")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionNoiseLevel_curves.png"), Resolution=150)

%%
%[text] ## Do they trace one path?
%[text] Each curve is fitted, at speeds up to 10 deg/s, with a psychometric function whose ceiling is free (lapse rate up to 0.9). Threshold is the speed at the curve's midpoint, halfway between chance and the ceiling. If internal noise acts like reduced coherence, the noise points (circles) and the coherence points (squares) should lie along one path in both panels.
inFit = speedsDegPerSec <= maxFitSpeedDegPerSec;
fitSpeed = repmat(speedsDegPerSec(inFit).', 1, nTrialsPerCondition);
for i = nLevels:-1:1    % filled from the end, so the array is allocated once
    correctHere = squeeze(correctMatched(i, inFit, :));
    noiseFits(i) = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), ...
        correctHere(:), MaxLapse=freeCeilingMaxLapse);
end
manipulation = repmat("RGC noise SD", nLevels, 1);
level = noiseSds.';
threshold = [noiseFits.thresholdAtCoherence1].';
sigma = [noiseFits.sigma].';
ceiling = 1 - [noiseFits.lambda].';
peakObserved = max(proportionMatched, [], 2);
if hasStep3
    nCoherences = numel(step3.coherences);
    step3InFit = step3.speedsDegPerSec <= maxFitSpeedDegPerSec;
    step3FitSpeed = repmat(step3.speedsDegPerSec(step3InFit).', 1, step3.nTrialsPerCondition);
    for c = nCoherences:-1:1
        correctHere = squeeze(step3.correctMatched(c, step3InFit, :));
        coherenceFits(c) = shFitSpeedCoherencePsychometric(step3FitSpeed(:), ...
            ones(numel(step3FitSpeed), 1), correctHere(:), MaxLapse=freeCeilingMaxLapse);
    end
    manipulation = [manipulation; repmat("coherence", nCoherences, 1)];
    level = [level; step3.coherences.'];
    threshold = [threshold; [coherenceFits.thresholdAtCoherence1].'];
    sigma = [sigma; [coherenceFits.sigma].'];
    ceiling = [ceiling; 1 - [coherenceFits.lambda].'];
    peakObserved = [peakObserved; max(step3.proportionMatched, [], 2)];
end
pathTable = table(manipulation, level, threshold, sigma, ceiling, peakObserved);
pathTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
isNoise = pathTable.manipulation == "RGC noise SD";
tiledlayout(1, 2, TileSpacing="compact");
nexttile
semilogx(pathTable.threshold(isNoise), pathTable.ceiling(isNoise), "o-", LineWidth=1.4)
hold on
semilogx(pathTable.threshold(~isNoise), pathTable.ceiling(~isNoise), "s--", LineWidth=1.4)
hold off
xlabel("threshold (model deg/s)")
ylabel("fitted ceiling")
ylim([0 1])
legend(["more RGC noise", "lower coherence"], Location="southwest")
title("Ceiling against threshold")
grid on
nexttile
semilogx(pathTable.threshold(isNoise), pathTable.sigma(isNoise), "o-", LineWidth=1.4)
hold on
semilogx(pathTable.threshold(~isNoise), pathTable.sigma(~isNoise), "s--", LineWidth=1.4)
hold off
xlabel("threshold (model deg/s)")
ylabel("fitted slope \sigma (log_{10} speed)")
title("Slope against threshold")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionNoiseLevel_path.png"), Resolution=150)

%%
%[text] ## What to look for
%[text] - Curves: does more noise, like lower coherence, move the curve to faster speeds AND lower its ceiling, with the drop at 20 deg/s?
%[text] - Path: do the noise points and the coherence points lie on one path in threshold, ceiling and slope? If they do, the model supports the premise that lower coherence mimics internal noise. If, say, noise lowers the ceiling without moving the threshold as far, the two differ in a way the equivalent-noise account would have to explain.
%[text] - The fits have a free ceiling, so their thresholds are midpoints between chance and each curve's own ceiling; they are not the 55%-correct thresholds of the other scripts. \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
