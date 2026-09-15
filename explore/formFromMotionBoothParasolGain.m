%[text] # Form-from-motion task: lower parasol gain, with the booth stimulus
%[text] Step 4 on the booth stimulus. The account being tested: optic neuritis lowers the signal-to-noise ratio of parasol retinal ganglion cells. The gain of the parasol classes is scaled down while the RGC noise stays at SD 0.02, the largest level at which every coherence still reaches ceiling (JW, 2026-09-15; `docs/FORM_FROM_MOTION.md`). The noise is added after the gain, so the parasol signal-to-noise ratio falls with the gain. The midget classes, the V1 and MT weights and the observer's matched filters are unchanged. Coherence is 1; dot speed varies.
%[text] Gain 1 is the noise run's condition at SD 0.02 and coherence 1, so only gains 0.8, 0.65, 0.5 and 0.35 are run: one job each, "job1" to "job4", 8 speeds × 40 trials with the same seeds. "analysis" compares them with the healthy model, with more RGC noise (on the 1-s stimulus a gain k acted like noise SD 0.02/k), and with lower coherence. Set the variable `jobs` before running the script to choose; without it everything runs in order. `explore/runFormFromMotionJobs.sh` runs the jobs as parallel MATLAB processes. Needs the booth runs' results in `explore/_figs/`: `formFromMotionBooth_filters.mat` and `formFromMotionBoothNoise.mat`. Results go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
parasolGains = [0.8 0.65 0.5 0.35];
nJobs = numel(parasolGains);
jobNames = "job" + (1:nJobs);
allJobs = [jobNames, "analysis"];
if ~exist("jobs", "var")
    jobs = allJobs;
end
jobs = string(jobs);
unknownJobs = setdiff(jobs, allJobs);
if ~isempty(unknownJobs)
    error("formFromMotionBoothParasolGain:jobs", "Unknown jobs: %s. Choose from: %s.", ...
        join(unknownJobs, ", "), join(allJobs, ", "));
end
rgcSd = 0.02;
coherence = 1;
pars = shPars("lagged");
pars.noise.rgcSd = rgcSd;
isParasol = startsWith(string({pars.rgc.classes.name}), "parasol");
units = shModelUnits();
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
nSpeeds = numel(speedsPxPerFrame);
nTrialsPerCondition = 40;
chance = 0.1;
maxFitSpeedDegPerSec = 10;
freeCeilingMaxLapse = 0.9;
tolerance = 1e-9;
filtersFile = fullfile(figureDir, "formFromMotionBooth_filters.mat");
noiseRunFile = fullfile(figureDir, "formFromMotionBoothNoise.mat");
jobFiles = fullfile(figureDir, "formFromMotionBoothParasolGain_" + jobNames + ".mat");
jobTable = table(jobNames.', parasolGains.', VariableNames=["job", "parasolGain"]);
jobTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Jobs "job1" to "job4": one parasol gain each
if any(ismember(jobNames, jobs))
    if ~isfile(filtersFile)
        error("formFromMotionBoothParasolGain:noFilters", ...
            "The booth templates and filters were not found in %s. Run the ""filters"" job of " + ...
            "explore/formFromMotionBooth.m first.", filtersFile);
    end
    saved = load(filtersFile);
end
for k = find(ismember(jobNames, jobs))
    lesionedPars = pars;
    for c = find(isParasol)
        lesionedPars.rgc.classes(c).gain = parasolGains(k)*pars.rgc.classes(c).gain;
    end
    boothGrid = localRunGrid(lesionedPars, saved.boothTemplates, saved.boothFilters, speedsPxPerFrame, ...
        coherence, nTrialsPerCondition);
    parasolGain = parasolGains(k);
    save(jobFiles(k), "boothGrid", "parasolGain", "rgcSd");
    jobMinutes = boothGrid.seconds/60 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Job "analysis": combine the jobs with the healthy model and the noise run
doAnalysis = any(jobs == "analysis");
if doAnalysis
    neededFiles = [jobFiles, noiseRunFile];
    missingFiles = neededFiles(~isfile(neededFiles));
    if ~isempty(missingFiles)
        error("formFromMotionBoothParasolGain:missingJobs", ...
            "These results are missing: %s. Run their jobs (or explore/formFromMotionBoothNoise.m) first.", ...
            join(missingFiles, ", "));
    end
    noiseRun = load(noiseRunFile);
    isFullCoherence = abs(noiseRun.conditionCoherence - coherence) < tolerance;
    isHealthy = isFullCoherence & abs(noiseRun.conditionSd - rgcSd) < tolerance;
    allGains = [1 parasolGains];
    nGains = numel(allGains);
    proportion = zeros(nGains, nSpeeds);
    dprime = zeros(nGains, nSpeeds);
    correct = false(nGains, nSpeeds, nTrialsPerCondition);
    proportion(1, :) = noiseRun.proportion(isHealthy, :);
    dprime(1, :) = noiseRun.dprime(isHealthy, :);
    correct(1, :, :) = noiseRun.correct(isHealthy, :, :);
    for k = 1:nJobs
        boothGrid = load(jobFiles(k)).boothGrid;
        proportion(k + 1, :) = boothGrid.proportionMatched;
        dprime(k + 1, :) = boothGrid.dprimeMatched;
        correct(k + 1, :, :) = boothGrid.correctMatched;
    end
    isNoiseFamily = isFullCoherence & noiseRun.conditionSd > rgcSd - tolerance;
    [noiseFamilySd, noiseOrder] = sort(noiseRun.conditionSd(isNoiseFamily));
    noiseFamilyRows = find(isNoiseFamily);
    noiseFamilyRows = noiseFamilyRows(noiseOrder);
    save(fullfile(figureDir, "formFromMotionBoothParasolGain.mat"), "speedsPxPerFrame", "speedsDegPerSec", ...
        "allGains", "rgcSd", "nTrialsPerCondition", "proportion", "dprime", "correct");
end

%%
%[text] ## Proportion correct
%[text] Matched filter, RGC noise SD 0.02, coherence 1. Rows: parasol gain (gain 1 is the noise run's condition). Columns: dot speed.
if doAnalysis
    resultsTable = array2table(proportion, RowNames="parasol gain " + string(allGains), ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    resultsTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## d′ of the true letter
if doAnalysis
    dprimeTable = array2table(round(dprime, 2), RowNames="parasol gain " + string(allGains), ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    dprimeTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Is a lower parasol gain the same as more noise?
%[text] With the noise added after the gain, gain k at noise SD 0.02 should act like gain 1 at SD 0.02/k (apart from the constant in the normalization, and apart from the midget classes, whose gain is unchanged). The prediction for each gain is the noise run's coherence-1 curves, interpolated in log SD to 0.02/k. The table gives the mean and largest absolute difference over the 8 speeds; with 40 trials, one proportion correct has a standard error of up to 0.079.
if doAnalysis
    equivalentSd = rgcSd./allGains;
    predicted = interp1(log(noiseFamilySd), noiseRun.proportion(noiseFamilyRows, :), log(equivalentSd));
    difference = abs(proportion - predicted);
    equivalenceTable = table(allGains.', equivalentSd.', mean(difference, 2), max(difference, [], 2), ...
        VariableNames=["parasolGain", "equivalentSd", "meanDifference", "largestDifference"]);
    equivalenceTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] Left: proportion correct for each parasol gain (solid) and the prediction from more noise (dashed, same colour). Right: the noise run's coherence-1 curves.
if doAnalysis
    tiledlayout(1, 2, TileSpacing="compact");
    nexttile
    colors = lines(nGains);
    hold on
    for g = 1:nGains
        plot(speedsDegPerSec, proportion(g, :), "o-", Color=colors(g, :), LineWidth=1.4)
    end
    for g = 1:nGains
        plot(speedsDegPerSec, predicted(g, :), "--", Color=colors(g, :), LineWidth=1.2)
    end
    hold off
    set(gca, XScale="log")
    legend("parasol gain " + string(allGains), Location="northwest", AutoUpdate="off")
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    ylabel("proportion correct")
    title("Lower parasol gain (dashed: more noise)")
    grid on
    nexttile
    semilogx(speedsDegPerSec, noiseRun.proportion(noiseFamilyRows, :).', "o-", LineWidth=1.4)
    legend("noise SD " + string(noiseFamilySd), Location="northwest", AutoUpdate="off")
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    title("More RGC noise, coherence 1")
    grid on
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothParasolGain_curves.png"), Resolution=150)
end

%%
%[text] ## Threshold, ceiling and slope of every curve
%[text] Each curve fitted on its own at speeds up to 10 deg/s with a free ceiling (lapse up to 0.9), as in the noise run: the parasol gains, the noise run's coherence-1 curves (more noise), and its coherence family at SD 0.02 (lower coherence).
if doAnalysis
    inFitSpeed = speedsDegPerSec <= maxFitSpeedDegPerSec;
    isCoherenceFamily = abs(noiseRun.conditionSd - rgcSd) < tolerance;
    familyCorrect = {correct, noiseRun.correct(noiseFamilyRows, :, :), noiseRun.correct(isCoherenceFamily, :, :)};
    familyNames = ["lower parasol gain", "more noise, coherence 1", "lower coherence, SD 0.02"];
    familyLevels = {allGains, noiseFamilySd, noiseRun.conditionCoherence(isCoherenceFamily)};
    familyFits = cell(1, numel(familyCorrect));
    for f = 1:numel(familyCorrect)
        familyFits{f} = localFreeCeilingFits(familyCorrect{f}, speedsDegPerSec, inFitSpeed, freeCeilingMaxLapse);
    end
    pathTable = table(repelem(familyNames.', cellfun(@numel, familyLevels)), [familyLevels{:}].', ...
        cell2mat(cellfun(@(fits) [fits.threshold], familyFits, UniformOutput=false)).', ...
        cell2mat(cellfun(@(fits) [fits.ceiling], familyFits, UniformOutput=false)).', ...
        cell2mat(cellfun(@(fits) [fits.sigma], familyFits, UniformOutput=false)).', ...
        VariableNames=["manipulation", "level", "threshold", "ceiling", "sigma"]);
    pathTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
if doAnalysis
    markers = ["^-", "ko--", "s-"];
    tiledlayout(1, 2, TileSpacing="compact");
    for panel = 1:2
        nexttile
        hold on
        for f = 1:numel(familyFits)
            fits = familyFits{f};
            if panel == 1
                plot([fits.threshold], [fits.ceiling], markers(f), LineWidth=1.4)
            else
                plot([fits.threshold], [fits.sigma], markers(f), LineWidth=1.4)
            end
        end
        hold off
        set(gca, XScale="log")
        xlabel("threshold (model deg/s)")
        if panel == 1
            ylabel("fitted ceiling")
            ylim([0 1.05])
            legend(familyNames, Location="southwest")
            title("Ceiling against threshold")
        else
            ylabel("fitted slope \sigma (log_{10} speed)")
            title("Slope against threshold")
        end
        grid on
    end
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothParasolGain_path.png"), Resolution=150)
end

%%
%[text] ## Lesioned over healthy, chance-corrected
%[text] R(s) = (P_gain(s) − γ)/(P_healthy(s) − γ), from the free-ceiling fits, at speeds where the healthy curve is at least 0.2 above chance. This is the model's version of Raz et al.'s patient-to-control ratio; the speed axes are not comparable, so compare shapes only.
if doAnalysis
    speedGrid = logspace(log10(min(speedsDegPerSec)), log10(maxFitSpeedDegPerSec), 200);
    gainFits = familyFits{1};
    healthyCurve = shSpeedCoherencePsychometric(gainFits(1).params, speedGrid, coherence);
    usable = healthyCurve - chance >= 0.2;
    ratio = nan(nGains - 1, numel(speedGrid));
    for g = 2:nGains
        lesionedCurve = shSpeedCoherencePsychometric(gainFits(g).params, speedGrid, coherence);
        ratio(g - 1, usable) = (lesionedCurve(usable) - chance)./(healthyCurve(usable) - chance);
    end
    tiledlayout(1, 1);
    nexttile
    semilogx(speedGrid, ratio.', LineWidth=1.5)
    legend("parasol gain " + string(parasolGains), Location="southeast")
    ylim([0 1.05])
    xlabel("dot speed (model deg/s)")
    ylabel("chance-corrected ratio to healthy")
    title("Lower parasol gain, coherence 1, RGC noise SD 0.02")
    grid on
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothParasolGain_ratio.png"), Resolution=150)
end

%%
%[text] ## What to look for
%[text] - Equivalence table: does each parasol gain k match more noise at SD 0.02/k, as it did on the 1-s stimulus?
%[text] - Path figure: does lower parasol gain follow the same threshold–ceiling path as more noise and as lower coherence? Its slope: does it stay steep like more noise, or flatten like lower coherence?
%[text] - Ratio: does the lesioned/healthy ratio rise with speed, as in Raz et al.'s patients? \

function fits = localFreeCeilingFits(correct, speedsDegPerSec, inFitSpeed, maxLapse)
% One free-ceiling psychometric fit per row of correct [nCurves nSpeeds nTrials].
    nTrials = size(correct, 3);
    fitSpeed = repmat(speedsDegPerSec(inFitSpeed).', 1, nTrials);
    nCurves = size(correct, 1);
    fits = struct("params", cell(1, nCurves), "threshold", 0, "ceiling", 0, "sigma", 0);
    for k = 1:nCurves
        correctHere = squeeze(correct(k, inFitSpeed, :));
        params = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), correctHere(:), ...
            MaxLapse=maxLapse);
        fits(k).params = params;
        fits(k).threshold = params.thresholdAtCoherence1;
        fits(k).ceiling = 1 - params.lambda;
        fits(k).sigma = params.sigma;
    end
end

function coherenceGrid = localRunGrid(pars, templates, filters, speedsPxPerFrame, coherence, nTrials)
% One coherence at every speed, read out with the matched filters.
    nSpeeds = numel(speedsPxPerFrame);
    coherenceGrid = struct( ...
        "proportionMatched", zeros(1, nSpeeds), ...
        "dprimeMatched", zeros(1, nSpeeds), ...
        "correctMatched", false(nSpeeds, nTrials), ...
        "seconds", 0);
    for j = 1:nSpeeds
        trialRun = shRunLetterTrials(pars, nTrials, SpeedPxPerFrame=speedsPxPerFrame(j), ...
            Coherence=coherence, Templates=templates, MatchedFilters=filters);
        coherenceGrid.proportionMatched(j) = trialRun.proportionCorrectMatched;
        coherenceGrid.dprimeMatched(j) = trialRun.dprimeMatched;
        coherenceGrid.correctMatched(j, :) = trialRun.choiceMatched == trialRun.trueIndex;
        coherenceGrid.seconds = coherenceGrid.seconds + trialRun.seconds;
    end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
