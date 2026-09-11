%[text] # Form-from-motion task: speed × coherence with RGC noise
%[text] Step 3 of `docs/FORM_FROM_MOTION.md`. The motion-defined letter task runs through the two-stream model with additive Gaussian noise on the RGC outputs, and is decoded with matched filters. Performance is measured across dot speed and coherence, fitted with the same joint psychometric model as the control observers, and compared with them in shape: the coherence exponent b, the slope σ, and the chance-corrected ratio curves. Absolute speeds are not comparable (`docs/UNITS_AND_SCALE.md` §6).
%[text] About 1,360 model runs: from under an hour to a few hours on an 8 GB laptop, depending on load. Results and figures go to `explore/_figs/` (gitignored). The comparison with the controls reads their fits from the EXPLORING_Speed_Coherence_Psychometrics project, and is skipped if that file is not on this machine.

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
nLetters = numel(templates.letters);
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
coherences = [1 0.75 0.5 0.25];
nTrialsPerCondition = 40;
controlFitsFile = fullfile(getenv("HOME"), "repos", "Research", "Exploring", ...
    "EXPLORING_Speed_Coherence_Psychometrics", "analysis", "out", "fits.mat");
controlUnitNames = ["wlsubj114", "wlsubj147", "wlsubj178", "wlsubj195", "wlsubj208"];

%%
%[text] ## Matched filters
%[text] The expected MT map of each letter: the average of 8 noise-free maps per letter at coherence 1 and 5 deg/s, flipped to a common sign. One set is used for every condition.
filters = shMatchedFilterTemplates(pars, templates, NumPerLetter=8);
tiledlayout(2, 5, TileSpacing="compact");
for k = 1:nLetters
    nexttile
    imagesc(filters.maps(:, :, k))
    axis image off
    title(templates.letters(k))
end
colormap(gray)
exportgraphics(gcf, fullfile(figureDir, "formFromMotionSpeedCoherence_filters.png"), Resolution=150)

%%
%[text] ## The RGC noise level
%[text] The RGC noise SD is fixed at 0.05. In a calibration check at 5 deg/s (20 trials per cell), this SD gave a matched-filter proportion correct of 0.95 at coherence 1 and 0.35 at coherence 0.25: the easiest condition stays near ceiling, as for the control observers, while lower coherence and slower speeds are limited by internal noise. At SD 0.1 the easiest condition fell to 0.45. The full table is in `docs/FORM_FROM_MOTION.md`.
rgcSd = 0.05;

%%
%[text] ## Speed × coherence
%[text] 8 speeds × 4 coherences × 40 trials. Every condition uses the same seeds, so conditions are compared trial for trial.
gridPars = pars;
gridPars.noise.rgcSd = rgcSd;
nSpeeds = numel(speedsPxPerFrame);
nCoherences = numel(coherences);
proportionMatched = zeros(nCoherences, nSpeeds);
proportionTemplate = zeros(nCoherences, nSpeeds);
dprimeMatched = zeros(nCoherences, nSpeeds);
correctMatched = false(nCoherences, nSpeeds, nTrialsPerCondition);
correctTemplate = false(nCoherences, nSpeeds, nTrialsPerCondition);
gridSeconds = 0;
for i = 1:nCoherences
    for j = 1:nSpeeds
        gridRun = shRunLetterTrials(gridPars, nTrialsPerCondition, ...
            SpeedPxPerFrame=speedsPxPerFrame(j), Coherence=coherences(i), ...
            Templates=templates, MatchedFilters=filters);
        proportionMatched(i, j) = gridRun.proportionCorrectMatched;
        proportionTemplate(i, j) = gridRun.proportionCorrect;
        dprimeMatched(i, j) = gridRun.dprimeMatched;
        correctMatched(i, j, :) = gridRun.choiceMatched == gridRun.trueIndex;
        correctTemplate(i, j, :) = gridRun.correct;
        gridSeconds = gridSeconds + gridRun.seconds;
    end
end
[trialCoherence, trialSpeed] = ndgrid(coherences, speedsDegPerSec, 1:nTrialsPerCondition);
save(fullfile(figureDir, "formFromMotionSpeedCoherence.mat"), "speedsPxPerFrame", ...
    "speedsDegPerSec", "coherences", "nTrialsPerCondition", "rgcSd", ...
    "proportionMatched", "proportionTemplate", "dprimeMatched", ...
    "correctMatched", "correctTemplate", "trialSpeed", "trialCoherence", "filters");
gridMinutes = gridSeconds/60;
gridMinutes %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Results
%[text] Left: matched-filter proportion correct. Middle: the inside-minus-outside classifier. Right: matched-filter d′. Chance is 0.1.
chance = 1/nLetters;
legendLabels = "coherence " + string(coherences);
tiledlayout(1, 3, TileSpacing="compact");
nexttile
semilogx(speedsDegPerSec, proportionMatched.', "o-", LineWidth=1.4)
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (deg/s)")
ylabel("proportion correct")
legend(legendLabels, Location="northwest")
title("Matched filter")
grid on
nexttile
semilogx(speedsDegPerSec, proportionTemplate.', "o-", LineWidth=1.4)
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (deg/s)")
title("Inside minus outside")
grid on
nexttile
semilogx(speedsDegPerSec, dprimeMatched.', "o-", LineWidth=1.4)
xlabel("dot speed (deg/s)")
ylabel("d'")
title("Matched filter, known letter")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionSpeedCoherence_results.png"), Resolution=150)

%%
%[text] ## Results as a table
%[text] Matched-filter proportion correct. Rows are coherences, columns are dot speeds.
resultsTable = array2table(proportionMatched, RowNames="coherence " + string(coherences), ...
    VariableNames=string(speedsDegPerSec) + " deg/s");
resultsTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Psychometric fits, and the comparison with the controls
%[text] The joint model of the control fits, fitted to single trials, with speed in model deg/s. Speeds above 10 deg/s are left out: past MT's fastest tuning, performance falls again, which a rising psychometric function cannot describe. The controls are the 10 units run with the current experiment code, using their censored fits; for them, each column gives its own median, minimum and maximum. Thresholds are in each observer's own deg/s and are not comparable between model and humans.
maxFitSpeedDegPerSec = 10;
inFit = trialSpeed <= maxFitSpeedDegPerSec;
fitMatched = shFitSpeedCoherencePsychometric(trialSpeed(inFit), trialCoherence(inFit), ...
    correctMatched(inFit));
fitTemplate = shFitSpeedCoherencePsychometric(trialSpeed(inFit), trialCoherence(inFit), ...
    correctTemplate(inFit));
observer = ["model, matched filter"; "model, inside minus outside"];
b = [fitMatched.b; fitTemplate.b];
sigma = [fitMatched.sigma; fitTemplate.sigma];
thresholdAtCoherence1 = [fitMatched.thresholdAtCoherence1; fitTemplate.thresholdAtCoherence1];
hasControls = isfile(controlFitsFile);
if hasControls
    controls = load(controlFitsFile);
    isCurrentCode = startsWith(string({controls.S.name}), controlUnitNames) & ...
        [controls.S.durationMs] == 100;
    jointFits = [controls.S(isCurrentCode).joint];
    censoredFits = [jointFits.excl];
    controlB = [censoredFits.b];
    controlSigma = [censoredFits.sigma];
    controlThreshold = 10.^[censoredFits.mu0];
    observer = [observer; "controls, median"; "controls, minimum"; "controls, maximum"];
    b = [b; median(controlB); min(controlB); max(controlB)];
    sigma = [sigma; median(controlSigma); min(controlSigma); max(controlSigma)];
    thresholdAtCoherence1 = [thresholdAtCoherence1; median(controlThreshold); ...
        min(controlThreshold); max(controlThreshold)];
end
comparisonTable = table(observer, b, sigma, thresholdAtCoherence1);
comparisonTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Chance-corrected ratio against relative speed
%[text] R(s, c) = (P(s, c) − γ) / (P(s, 1) − γ): the share of the above-chance performance at full coherence that remains at coherence c (SUMMARY.md §5). Speed is divided by each observer's own threshold at coherence 1, so the model and the humans share an axis despite their different absolute speeds. Solid: model (matched filter). Dashed: the mean of the controls' own ratio curves.
relativeSpeed = logspace(-1, 2, 200);
ratioCoherences = [0.75 0.5 0.25];
modelRatio = localRatio(fitMatched, relativeSpeed, ratioCoherences);
colors = lines(numel(ratioCoherences));
ratioLabels = "model, coherence " + string(ratioCoherences);
tiledlayout(1, 1);
nexttile
hold on
for k = 1:numel(ratioCoherences)
    plot(relativeSpeed, modelRatio(k, :), Color=colors(k, :), LineWidth=1.6)
end
if hasControls
    controlRatio = zeros(numel(ratioCoherences), numel(relativeSpeed));
    for k = 1:numel(censoredFits)
        params = struct("mu0", censoredFits(k).mu0, "b", censoredFits(k).b, ...
            "sigma", censoredFits(k).sigma, "lambda", censoredFits(k).lambda, ...
            "gamma", controls.gamma);
        controlRatio = controlRatio + localRatio(params, relativeSpeed, ratioCoherences)/numel(censoredFits);
    end
    for k = 1:numel(ratioCoherences)
        plot(relativeSpeed, controlRatio(k, :), "--", Color=colors(k, :), LineWidth=1.2)
    end
    ratioLabels = [ratioLabels, "controls, coherence " + string(ratioCoherences)];
end
hold off
ratioAxes = gca;
ratioAxes.XScale = "log";
ylim([0 1.05])
xlabel("speed / threshold at coherence 1")
ylabel("chance-corrected ratio R")
legend(ratioLabels, Location="southeast")
title("Reduced / full coherence, chance-corrected")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionSpeedCoherence_ratio.png"), Resolution=150)

%%
%[text] ## What to look for
%[text] - b and σ: do the model's values fall within the range of the 10 control units?
%[text] - The ratio curves: do they rise with relative speed and stay ordered by coherence, and do model and control curves lie close together on the relative axis?
%[text] - The two decoders: does the matched filter remove the ceiling the inside-minus-outside classifier showed without noise? \

function ratio = localRatio(params, relativeSpeed, coherenceLevels)
% Chance-corrected ratio R(s, c), at speeds given relative to the threshold
% at coherence 1.
    speed = relativeSpeed*10^params.mu0;
    fullCoherence = shSpeedCoherencePsychometric(params, speed, 1);
    ratio = zeros(numel(coherenceLevels), numel(relativeSpeed));
    for k = 1:numel(coherenceLevels)
        reduced = shSpeedCoherencePsychometric(params, speed, coherenceLevels(k));
        ratio(k, :) = (reduced-params.gamma)./(fullCoherence-params.gamma);
    end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
