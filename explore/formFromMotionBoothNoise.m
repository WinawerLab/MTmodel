%[text] # Form-from-motion task: the booth stimulus with internal noise
%[text] Without internal noise, the booth stimulus lets every coherence reach ceiling, and lower coherence moves the curve to faster speeds, as in the controls (`docs/FORM_FROM_MOTION.md`). This script adds RGC noise back and asks two things. First, up to what noise level does the model still reach ceiling at every coherence, as the controls do? Second, the premise of the project: does more internal noise at full coherence act like lower coherence?
%[text] Conditions, each 8 speeds × 40 trials with the booth stimulus and the no-noise run's seeds and matched filters:
%[text] - coherence families at RGC noise SD 0.01 and 0.02: all four coherences
%[text] - a noise family at coherence 1: SD 0.035, 0.05, 0.07 and 0.1, which with SD 0, 0.01 and 0.02 makes seven levels \
%[text] Extrapolating from the 1-s runs, SD 0.01–0.02 should leave coherence 0.25 near ceiling at its best speed, and SD 0.05 should pull it well below.
%[text] Each (noise SD, coherence) pair is one job, "job1" to "job12"; "analysis" combines them with the no-noise run (SD 0). Set the variable `jobs` before running the script to choose; without it everything runs in order (about 18 hours). `explore/runFormFromMotionBoothNoise.sh` runs the jobs as parallel MATLAB processes. Needs the no-noise run's results in `explore/_figs/`: `formFromMotionBooth_filters.mat` and `formFromMotionBooth_coherence1.mat` to `4.mat`. Results go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
coherences = [1 0.75 0.5 0.25];
nCoherences = numel(coherences);
familySds = [0.01 0.02];
noiseFamilySds = [0.035 0.05 0.07 0.1];
jobSd = [repelem(familySds, nCoherences), noiseFamilySds];
jobCoherence = [repmat(coherences, 1, numel(familySds)), ones(1, numel(noiseFamilySds))];
nJobs = numel(jobSd);
jobNames = "job" + (1:nJobs);
allJobs = [jobNames, "analysis"];
if ~exist("jobs", "var")
    jobs = allJobs;
end
jobs = string(jobs);
unknownJobs = setdiff(jobs, allJobs);
if ~isempty(unknownJobs)
    error("formFromMotionBoothNoise:jobs", "Unknown jobs: %s. Choose from: %s.", ...
        join(unknownJobs, ", "), join(allJobs, ", "));
end
pars = shPars("lagged");
units = shModelUnits();
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
nSpeeds = numel(speedsPxPerFrame);
nTrialsPerCondition = 40;
chance = 0.1;
maxFitSpeedDegPerSec = 10;
freeCeilingMaxLapse = 0.9;
filtersFile = fullfile(figureDir, "formFromMotionBooth_filters.mat");
noNoiseFiles = fullfile(figureDir, "formFromMotionBooth_coherence" + (1:nCoherences) + ".mat");
jobFiles = fullfile(figureDir, "formFromMotionBoothNoise_" + jobNames + ".mat");
controlFitsFile = fullfile(getenv("HOME"), "repos", "Research", "Exploring", ...
    "EXPLORING_Speed_Coherence_Psychometrics", "analysis", "out", "fits.mat");
controlUnitNames = ["wlsubj114", "wlsubj147", "wlsubj178", "wlsubj195", "wlsubj208"];
jobTable = table(jobNames.', jobSd.', jobCoherence.', VariableNames=["job", "rgcSd", "coherence"]);
jobTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Jobs "job1" to "job12": one noise level and coherence each
if any(ismember(jobNames, jobs))
    if ~isfile(filtersFile)
        error("formFromMotionBoothNoise:noFilters", ...
            "The booth templates and filters were not found in %s. Run the ""filters"" job of " + ...
            "explore/formFromMotionBooth.m first.", filtersFile);
    end
    saved = load(filtersFile);
end
for k = find(ismember(jobNames, jobs))
    noisyPars = pars;
    noisyPars.noise.rgcSd = jobSd(k);
    boothGrid = localRunGrid(noisyPars, saved.boothTemplates, saved.boothFilters, speedsPxPerFrame, ...
        jobCoherence(k), nTrialsPerCondition);
    rgcSd = jobSd(k);
    coherence = jobCoherence(k);
    save(jobFiles(k), "boothGrid", "rgcSd", "coherence");
    jobMinutes = boothGrid.seconds/60 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Job "analysis": combine the jobs with the no-noise run
doAnalysis = any(jobs == "analysis");
if doAnalysis
    conditionFiles = [noNoiseFiles, jobFiles];
    missingFiles = conditionFiles(~isfile(conditionFiles));
    if ~isempty(missingFiles)
        error("formFromMotionBoothNoise:missingJobs", "These results are missing: %s. Run their jobs first.", ...
            join(missingFiles, ", "));
    end
    conditionSd = [zeros(1, nCoherences), jobSd];
    conditionCoherence = [coherences, jobCoherence];
    nConditions = numel(conditionFiles);
    proportion = zeros(nConditions, nSpeeds);
    dprime = zeros(nConditions, nSpeeds);
    correct = false(nConditions, nSpeeds, nTrialsPerCondition);
    totalSeconds = 0;
    for k = 1:nConditions
        boothGrid = load(conditionFiles(k)).boothGrid;
        proportion(k, :) = boothGrid.proportionMatched;
        dprime(k, :) = boothGrid.dprimeMatched;
        correct(k, :, :) = boothGrid.correctMatched;
        totalSeconds = totalSeconds + boothGrid.seconds;
    end
    conditionNames = "SD " + string(conditionSd) + ", coherence " + string(conditionCoherence);
    familyLevels = [0 familySds];
    isNoiseFamily = conditionCoherence == 1;
    [~, noiseOrder] = sort(conditionSd(isNoiseFamily));
    noiseFamilyIndex = find(isNoiseFamily);
    noiseFamilyIndex = noiseFamilyIndex(noiseOrder);
    save(fullfile(figureDir, "formFromMotionBoothNoise.mat"), "speedsPxPerFrame", "speedsDegPerSec", ...
        "conditionSd", "conditionCoherence", "nTrialsPerCondition", "proportion", "dprime", "correct");
    computeHours = totalSeconds/3600 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Proportion correct
%[text] Matched filter. Rows: RGC noise SD and coherence (SD 0 is the no-noise run). Columns: dot speed.
if doAnalysis
    resultsTable = array2table(proportion, RowNames=conditionNames, ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    resultsTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Best proportion correct over speeds
%[text] Does every coherence still reach ceiling? With 40 trials, 0.95 has a standard error of about 0.035.
if doAnalysis
    [bestProportion, bestIndex] = max(proportion, [], 2);
    bestTable = table(conditionSd.', conditionCoherence.', bestProportion, speedsDegPerSec(bestIndex).', ...
        VariableNames=["rgcSd", "coherence", "best", "bestSpeed"]);
    bestTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## The curves
%[text] First three panels: lower coherence at a fixed noise level. Last panel: more internal noise at coherence 1.
if doAnalysis
    tiledlayout(2, 2, TileSpacing="compact");
    for f = 1:numel(familyLevels)
        nexttile
        rows = conditionSd == familyLevels(f);
        semilogx(speedsDegPerSec, proportion(rows, :).', "o-", LineWidth=1.4)
        if f == 1
            ylabel("proportion correct")
            legend("coherence " + string(conditionCoherence(rows)), Location="northwest", AutoUpdate="off")
        end
        yline(chance, "k:")
        ylim([0 1])
        xlabel("dot speed (model deg/s)")
        title("Lower coherence, RGC noise SD " + familyLevels(f))
        grid on
    end
    nexttile
    semilogx(speedsDegPerSec, proportion(noiseFamilyIndex, :).', "o-", LineWidth=1.4)
    legend("SD " + string(conditionSd(noiseFamilyIndex)), Location="northwest", AutoUpdate="off")
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    title("More internal noise, coherence 1")
    grid on
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothNoise_curves.png"), Resolution=150)
end

%%
%[text] ## Threshold and ceiling of every curve
%[text] Each curve fitted on its own at speeds up to 10 deg/s with a free ceiling (lapse up to 0.9), as in the noise-level run. Threshold is the midpoint between chance and the curve's own ceiling.
if doAnalysis
    inFitSpeed = speedsDegPerSec <= maxFitSpeedDegPerSec;
    fitSpeed = repmat(speedsDegPerSec(inFitSpeed).', 1, nTrialsPerCondition);
    freeThreshold = zeros(nConditions, 1);
    freeCeiling = zeros(nConditions, 1);
    freeSigma = zeros(nConditions, 1);
    for k = 1:nConditions
        correctHere = squeeze(correct(k, inFitSpeed, :));
        ceilingFit = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), ...
            correctHere(:), MaxLapse=freeCeilingMaxLapse);
        freeThreshold(k) = ceilingFit.thresholdAtCoherence1;
        freeCeiling(k) = 1 - ceilingFit.lambda;
        freeSigma(k) = ceilingFit.sigma;
    end
    pathTable = table(conditionSd.', conditionCoherence.', freeThreshold, freeCeiling, freeSigma, ...
        VariableNames=["rgcSd", "coherence", "threshold", "ceiling", "sigma"]);
    pathTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Does more internal noise act like lower coherence?
%[text] Each line joins the curves of one family: lower coherence at a fixed noise level (solid), or more noise at coherence 1 (dashed, circles). If internal noise acts like lower coherence, the dashed line should run along the solid ones, in both panels.
if doAnalysis
    tiledlayout(1, 2, TileSpacing="compact");
    familyLabels = "lower coherence, SD " + string(familyLevels);
    for panel = 1:2
        nexttile
        hold on
        for f = 1:numel(familyLevels)
            rows = find(conditionSd == familyLevels(f));
            if panel == 1
                plot(freeThreshold(rows), freeCeiling(rows), "s-", LineWidth=1.4)
            else
                plot(freeThreshold(rows), freeSigma(rows), "s-", LineWidth=1.4)
            end
        end
        if panel == 1
            plot(freeThreshold(noiseFamilyIndex), freeCeiling(noiseFamilyIndex), "ko--", LineWidth=1.4)
            ylabel("fitted ceiling")
            ylim([0 1.05])
            legend([familyLabels, "more noise, coherence 1"], Location="southwest")
            title("Ceiling against threshold")
        else
            plot(freeThreshold(noiseFamilyIndex), freeSigma(noiseFamilyIndex), "ko--", LineWidth=1.4)
            ylabel("fitted slope \sigma (log_{10} speed)")
            title("Slope against threshold")
        end
        hold off
        set(gca, XScale="log")
        xlabel("threshold (model deg/s)")
        grid on
    end
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothNoise_path.png"), Resolution=150)
end

%%
%[text] ## Joint fits of the coherence families, compared with the controls
%[text] The controls' joint model and fitting rule (lapse at most 0.06), at speeds up to 10 deg/s. The controls are the 10 units run with the current experiment code, using their censored fits.
if doAnalysis
    [trialCoherence, trialSpeed] = ndgrid(coherences, speedsDegPerSec, 1:nTrialsPerCondition);
    inFit = trialSpeed <= maxFitSpeedDegPerSec;
    for f = numel(familyLevels):-1:1    % filled from the end, so the array is allocated once
        rows = conditionSd == familyLevels(f);
        familyCorrect = correct(rows, :, :);
        jointFits(f) = shFitSpeedCoherencePsychometric(trialSpeed(inFit), trialCoherence(inFit), ...
            familyCorrect(inFit));
    end
    observer = "model, RGC noise SD " + string(familyLevels.');
    b = [jointFits.b].';
    sigma = [jointFits.sigma].';
    thresholdAtCoherence1 = [jointFits.thresholdAtCoherence1].';
    if isfile(controlFitsFile)
        controls = load(controlFitsFile);
        isCurrentCode = startsWith(string({controls.S.name}), controlUnitNames) & ...
            [controls.S.durationMs] == 100;
        controlJointFits = [controls.S(isCurrentCode).joint];
        censoredFits = [controlJointFits.excl];
        controlB = [censoredFits.b];
        controlSigma = [censoredFits.sigma];
        controlThreshold = 10.^[censoredFits.mu0];
        observer = [observer; "controls, median"; "controls, minimum"; "controls, maximum"];
        b = [b; median(controlB); min(controlB); max(controlB)];
        sigma = [sigma; median(controlSigma); min(controlSigma); max(controlSigma)];
        thresholdAtCoherence1 = [thresholdAtCoherence1; median(controlThreshold); ...
            min(controlThreshold); max(controlThreshold)];
    end
    jointTable = table(observer, b, sigma, thresholdAtCoherence1);
    jointTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## What to look for
%[text] - Best-speed table: the largest noise SD at which coherence 0.25 still reaches about 0.95. That is the model's human-like operating point.
%[text] - Path figure: does the more-noise line (dashed) run along the lower-coherence lines? If so, the model supports the premise that lower coherence mimics internal noise. If more noise lowers the ceiling where lower coherence moves the threshold, the two differ.
%[text] - Joint fits: do b and σ stay in the controls' range as noise is added? \

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
