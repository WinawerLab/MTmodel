%[text] # Form-from-motion task: lower parasol gain at full coherence
%[text] Step 4 of `docs/FORM_FROM_MOTION.md`. The account being tested: optic neuritis lowers the signal-to-noise ratio of parasol retinal ganglion cells. Here the gain of the parasol classes is scaled down while the RGC noise stays fixed (SD 0.05, added after the gain), so the parasol signal-to-noise ratio falls with the gain. The midget classes are untouched, the V1 and MT weights are not refitted, and the observer keeps the matched filters of the healthy model. Coherence is 1 throughout; dot speed varies.
%[text] Reported for each gain: proportion correct against speed; the mean and the trial-to-trial SD of the true letter's matched-filter score (normalization may hold the mean steady while the variability grows, `docs/NOISE_AND_DEMYELINATION.md` §4.2); a psychometric fit; and the chance-corrected ratio to the healthy model, next to Raz et al.'s patient-to-control curves. If the step-3 results are on this machine, each gain is also matched to the coherence whose ratio curve it resembles most.
%[text] About 1,680 model runs. Results and figures go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
if ~isfolder(figureDir)
    mkdir(figureDir);
end
pars = shPars("lagged");
pars.noise.rgcSd = 0.05;
outSz = [64 64 50];
units = shModelUnits();
templates = shLetterTemplates(pars, outSz);
nLetters = numel(templates.letters);
chance = 1/nLetters;
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
parasolGains = [1 0.8 0.65 0.5 0.35];
nTrialsPerCondition = 40;
isParasol = startsWith(string({pars.rgc.classes.name}), "parasol");
step3File = fullfile(figureDir, "formFromMotionSpeedCoherence.mat");

%%
%[text] ## Matched filters, from the healthy model
%[text] Built exactly as in step 3 (same seeds, no noise, full parasol gain), so both steps use the same observer.
filters = shMatchedFilterTemplates(pars, templates, NumPerLetter=8);

%%
%[text] ## Parasol gain × speed
%[text] 5 gains × 8 speeds × 40 trials at coherence 1. Every condition uses the same seeds, so conditions are compared trial for trial.
nGains = numel(parasolGains);
nSpeeds = numel(speedsPxPerFrame);
proportionMatched = zeros(nGains, nSpeeds);
proportionTemplate = zeros(nGains, nSpeeds);
matchedMean = zeros(nGains, nSpeeds);
matchedSd = zeros(nGains, nSpeeds);
correctMatched = false(nGains, nSpeeds, nTrialsPerCondition);
gridSeconds = 0;
for g = 1:nGains
    lesionedPars = pars;
    for c = find(isParasol)
        lesionedPars.rgc.classes(c).gain = parasolGains(g)*pars.rgc.classes(c).gain;
    end
    for j = 1:nSpeeds
        gridRun = shRunLetterTrials(lesionedPars, nTrialsPerCondition, ...
            SpeedPxPerFrame=speedsPxPerFrame(j), Coherence=1, ...
            Templates=templates, MatchedFilters=filters);
        proportionMatched(g, j) = gridRun.proportionCorrectMatched;
        proportionTemplate(g, j) = gridRun.proportionCorrect;
        trueEntry = sub2ind(size(gridRun.matchedScores), (1:nTrialsPerCondition).', gridRun.trueIndex);
        trueScore = gridRun.matchedScores(trueEntry).*cosd(gridRun.motionAngleDeg);
        matchedMean(g, j) = mean(trueScore);
        matchedSd(g, j) = std(trueScore);
        correctMatched(g, j, :) = gridRun.choiceMatched == gridRun.trueIndex;
        gridSeconds = gridSeconds + gridRun.seconds;
    end
end
save(fullfile(figureDir, "formFromMotionParasolGain.mat"), "speedsPxPerFrame", ...
    "speedsDegPerSec", "parasolGains", "nTrialsPerCondition", "proportionMatched", ...
    "proportionTemplate", "matchedMean", "matchedSd", "correctMatched", "filters");
gridMinutes = gridSeconds/60;
gridMinutes %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Results
%[text] Left: matched-filter proportion correct (chance 0.1). Middle and right: the true letter's matched-filter score, its mean and its SD across trials. If normalization compensates for the lost parasol drive, the mean should hold up better than the proportion correct, and the SD should grow.
legendLabels = "parasol gain " + string(parasolGains);
tiledlayout(1, 3, TileSpacing="compact");
nexttile
semilogx(speedsDegPerSec, proportionMatched.', "o-", LineWidth=1.4)
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (model deg/s)")
ylabel("proportion correct")
legend(legendLabels, Location="northwest")
title("Matched filter")
grid on
nexttile
semilogx(speedsDegPerSec, matchedMean.', "o-", LineWidth=1.4)
xlabel("dot speed (model deg/s)")
ylabel("mean score of the true letter")
title("Mean")
grid on
nexttile
semilogx(speedsDegPerSec, matchedSd.', "o-", LineWidth=1.4)
xlabel("dot speed (model deg/s)")
ylabel("SD across trials")
title("Trial-to-trial variability")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionParasolGain_results.png"), Resolution=150)

%%
%[text] ## Results as a table
%[text] Matched-filter proportion correct. Rows are parasol gains, columns are dot speeds.
resultsTable = array2table(proportionMatched, RowNames=legendLabels, ...
    VariableNames=string(speedsDegPerSec) + " deg/s");
resultsTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Psychometric fit for each gain
%[text] One psychometric function of speed per gain, fitted to single trials at speeds up to 10 deg/s, as in step 3. Coherence is fixed, so b is not estimated. Thresholds are in model deg/s.
maxFitSpeedDegPerSec = 10;
inFit = speedsDegPerSec <= maxFitSpeedDegPerSec;
fitSpeed = repmat(speedsDegPerSec(inFit).', 1, nTrialsPerCondition);
for g = nGains:-1:1    % filled from the end, so the array is allocated once
    correctHere = squeeze(correctMatched(g, inFit, :));
    gainFits(g) = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), correctHere(:));
end
thresholds = [gainFits.thresholdAtCoherence1].';
fitTable = table(parasolGains.', thresholds, thresholds/thresholds(1), [gainFits.sigma].', ...
    [gainFits.lambda].', VariableNames=["parasolGain", "threshold", "thresholdRelativeToHealthy", ...
    "sigma", "lambda"]);
fitTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Ratio to the healthy model, next to Raz et al. (2012)
%[text] Left: the model's chance-corrected ratio R(s) = (P_gain(s) − γ) / (P_healthy(s) − γ), from the fitted curves, over the speeds where the healthy model is clearly above chance. Right: Raz et al.'s optic-neuritis eyes as a fraction of the control mean (digitized from their Figure 1; `optic neuritis targets/raz-2012-OFM-performance.md`). Raz's values are NOT chance-corrected, and the speed axes are NOT comparable: the model's speeds are in its own units, and all of Raz's axis lies below the model's range. Compare shapes only.
minimumAboveChance = 0.02;
speedGrid = logspace(log10(min(speedsDegPerSec)), log10(maxFitSpeedDegPerSec), 200);
healthy = shSpeedCoherencePsychometric(gainFits(1), speedGrid, 1);
usable = healthy-chance > minimumAboveChance;
gainRatio = nan(nGains, numel(speedGrid));
for g = 1:nGains
    lesioned = shSpeedCoherencePsychometric(gainFits(g), speedGrid(usable), 1);
    gainRatio(g, usable) = (lesioned-chance)./(healthy(usable)-chance);
end
tiledlayout(1, 2, TileSpacing="compact");
nexttile
semilogx(speedGrid, gainRatio(2:end, :).', LineWidth=1.5)
ylim([0 1.05])
xlabel("dot speed (model deg/s)")
ylabel("chance-corrected ratio to healthy")
legend(legendLabels(2:end), Location="southeast")
title("Model: lower parasol gain")
grid on
nexttile
razSpeedsDegPerSec = [0.05 0.1 0.25 0.5 1 2];
razPercentOfControl = [11 12 17 24 36 45; 24 35 43 58 74 77; 39 39 56 65 71 74; 54 62 71 66 77 76];
semilogx(razSpeedsDegPerSec, razPercentOfControl.'/100, "o-", LineWidth=1.5)
ylim([0 1.05])
xlabel("dot speed (deg/s)")
ylabel("fraction of control")
legend(["acute", "1 month", "4 months", "12 months"], Location="southeast")
title("Raz et al. 2012, optic neuritis")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionParasolGain_ratio.png"), Resolution=150)

%%
%[text] ## Does parasol damage look like reduced coherence?
%[text] Only if the step-3 results are on this machine. The joint speed-by-coherence model is fitted to them, and for each parasol gain the coherence whose chance-corrected ratio curve lies closest (least squares, same speeds as above) is found. Model and model share one speed axis, so this comparison, unlike the one with the humans, is exact. A close match across gains is the model's version of the equivalent-noise account. The first line checks that step 3's full-coherence row and this step's full-gain row, which use the same model, seeds and filters, gave the same trials.
hasStep3 = isfile(step3File);
if hasStep3
    step3 = load(step3File);
    sameHealthyTrials = isequal(squeeze(step3.correctMatched(1, :, :)), squeeze(correctMatched(1, :, :)));
    inStep3Fit = step3.trialSpeed <= maxFitSpeedDegPerSec;
    coherenceFit = shFitSpeedCoherencePsychometric(step3.trialSpeed(inStep3Fit), ...
        step3.trialCoherence(inStep3Fit), step3.correctMatched(inStep3Fit));
    fullCoherence = shSpeedCoherencePsychometric(coherenceFit, speedGrid, 1);
    % Compare only where both healthy curves are clearly above chance, so
    % neither ratio divides by a number near zero.
    comparable = usable & (fullCoherence-chance > minimumAboveChance);
    if any(comparable)
        candidateCoherences = logspace(log10(0.05), 0, 200);
        candidateRatio = zeros(numel(candidateCoherences), nnz(comparable));
        for k = 1:numel(candidateCoherences)
            reduced = shSpeedCoherencePsychometric(coherenceFit, speedGrid(comparable), candidateCoherences(k));
            candidateRatio(k, :) = (reduced-chance)./(fullCoherence(comparable)-chance);
        end
        equivalentCoherence = nan(nGains, 1);
        rmsMismatch = nan(nGains, 1);
        for g = 2:nGains
            squaredError = mean((candidateRatio-gainRatio(g, comparable)).^2, 2);
            [bestError, best] = min(squaredError);
            equivalentCoherence(g) = candidateCoherences(best);
            rmsMismatch(g) = sqrt(bestError);
        end
        equivalenceTable = table(parasolGains.', equivalentCoherence, rmsMismatch, ...
            VariableNames=["parasolGain", "equivalentCoherence", "rmsMismatch"]);
    else
        equivalenceTable = "The healthy model is not clearly above chance at any fitted speed; " + ...
            "comparison skipped.";
    end
else
    sameHealthyTrials = NaN;
    equivalenceTable = "Step-3 results not found at " + step3File + "; comparison skipped.";
end
sameHealthyTrials %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] For each gain, the coherence whose ratio curve matches best, and how far apart the two curves are (root-mean-square difference in ratio units):
equivalenceTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## What to look for
%[text] - Does lowering the parasol gain hurt slow speeds more than fast ones, as in Raz's patients?
%[text] - Mean against variability: does the mean score hold up while the SD grows (normalization hiding the lesion from the mean)?
%[text] - Equivalent coherence: does each gain match a single coherence closely, across the whole speed range? If so, in this model parasol damage acts like reduced coherence.
%[text] - Not tested here: Raz's static, luminance-defined letters were nearly spared (83–91% of normal). A parasol lesion should spare a static read-out too; that is an open check. \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
