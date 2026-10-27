%[text] # Form-from-motion task: does dot lifetime limit the noise-free model at slow speeds?
%[text] Without internal noise, at coherence 1, the booth stimulus gives only about 0.37 correct at 0.15 model deg/s and about 0.75 at 0.3 deg/s. The model is then deterministic, so the limit comes from the stimulus. The leading guess is the 100-ms dot lifetime: at 0.15 deg/s a dot moves 0.015 deg in its life, about 1/7 of a model pixel, while every dot is replotted somewhere else every 100 ms. The alternative is the model's coarse resolution and weak slow-speed channels, whatever the lifetime.
%[text] The test: the same condition with longer lifetimes, 1 s and Inf (no replotting during the 4-s trial). Everything else is as in the no-noise booth run: RGC noise SD 0, the two slowest speeds, 40 trials, the same per-trial seeds (so each trial is paired with its 0.1-s baseline), and the same templates and matched filters.
%[text] Each lifetime is one job, "job1" and "job2"; "analysis" combines them with the 0.1-s baseline. Set the variable `jobs` before running the script to choose; without it everything runs in order. Set `coherence` to run at another coherence (the optional second stage, coherence 0.5); its baseline is then the no-noise run at that coherence. `explore/runFormFromMotionJobs.sh explore/formFromMotionBoothLifetime.m 2 <resultsFolder>` runs the jobs as parallel MATLAB processes (with `SETUP="coherence = 0.5;"` for the second stage). Needs `explore/_figs/formFromMotionBooth_filters.mat` and the no-noise run's results. Results go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
if ~exist("coherence", "var")
    coherence = 1;
end
boothCoherences = [1 0.75 0.5 0.25];    % the no-noise run's conditions, in file order
baselineIndex = find(boothCoherences == coherence);
if isempty(baselineIndex)
    error("formFromMotionBoothLifetime:coherence", "Coherence %g has no no-noise baseline. Choose from: %s.", ...
        coherence, join(string(boothCoherences), ", "));
end
lifetimesSec = [1 Inf];
baselineLifetimeSec = 0.1;
nJobs = numel(lifetimesSec);
jobNames = "job" + (1:nJobs);
allJobs = [jobNames, "analysis"];
if ~exist("jobs", "var")
    jobs = allJobs;
end
jobs = string(jobs);
unknownJobs = setdiff(jobs, allJobs);
if ~isempty(unknownJobs)
    error("formFromMotionBoothLifetime:jobs", "Unknown jobs: %s. Choose from: %s.", ...
        join(unknownJobs, ", "), join(allJobs, ", "));
end
if ~exist("nTrialsPerCondition", "var")
    nTrialsPerCondition = 40;    % set fewer before running the script for a timing test
end
pars = shPars("lagged");    % internal noise is off by default
units = shModelUnits();
allSpeedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];    % the no-noise run's speeds
speedsPxPerFrame = [0.03 0.06];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
nSpeeds = numel(speedsPxPerFrame);
chance = 0.1;
coherenceTag = "";
if coherence ~= 1
    coherenceTag = "_coherence" + string(coherence);
end
filtersFile = fullfile(figureDir, "formFromMotionBooth_filters.mat");
baselineFile = fullfile(figureDir, "formFromMotionBooth_coherence" + baselineIndex + ".mat");
jobFiles = fullfile(figureDir, "formFromMotionBoothLifetime" + coherenceTag + "_" + jobNames + ".mat");
jobTable = table(jobNames.', lifetimesSec.', VariableNames=["job", "lifetimeSec"]);
jobTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Jobs "job1" and "job2": one lifetime each
if any(ismember(jobNames, jobs))
    if ~isfile(filtersFile)
        error("formFromMotionBoothLifetime:noFilters", ...
            "The booth templates and filters were not found in %s. Run the ""filters"" job of " + ...
            "explore/formFromMotionBooth.m first.", filtersFile);
    end
    saved = load(filtersFile);
end
for k = find(ismember(jobNames, jobs))
    lifetimeSec = lifetimesSec(k);
    fprintf("Lifetime %g s, coherence %g: %d speeds x %d trials\n", lifetimeSec, coherence, nSpeeds, ...
        nTrialsPerCondition);
    boothGrid = localRunGrid(pars, saved.boothTemplates, saved.boothFilters, speedsPxPerFrame, ...
        coherence, nTrialsPerCondition, lifetimeSec);
    save(jobFiles(k), "boothGrid", "lifetimeSec", "coherence", "speedsPxPerFrame");
    jobMinutes = boothGrid.seconds/60 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Job "analysis": combine the jobs with the 0.1-s baseline
doAnalysis = any(jobs == "analysis");
if doAnalysis
    missingFiles = [baselineFile, jobFiles];
    missingFiles = missingFiles(~isfile(missingFiles));
    if ~isempty(missingFiles)
        error("formFromMotionBoothLifetime:missingJobs", "These results are missing: %s. Run their jobs first.", ...
            join(missingFiles, ", "));
    end
    conditionLifetime = [baselineLifetimeSec, lifetimesSec];
    nConditions = numel(conditionLifetime);
    proportion = zeros(nConditions, nSpeeds);
    correct = false(nConditions, nSpeeds, nTrialsPerCondition);
    baselineGrid = load(baselineFile).boothGrid;
    [~, baselineSpeeds] = ismember(speedsPxPerFrame, allSpeedsPxPerFrame);
    proportion(1, :) = baselineGrid.proportionMatched(baselineSpeeds);
    correct(1, :, :) = baselineGrid.correctMatched(baselineSpeeds, :);
    for k = 1:nJobs
        boothGrid = load(jobFiles(k)).boothGrid;
        proportion(k + 1, :) = boothGrid.proportionMatched;
        correct(k + 1, :, :) = boothGrid.correctMatched;
    end
    nCorrect = sum(correct, 3);
    standardError = sqrt(proportion.*(1 - proportion)/nTrialsPerCondition);
    save(fullfile(figureDir, "formFromMotionBoothLifetime" + coherenceTag + ".mat"), "speedsPxPerFrame", ...
        "speedsDegPerSec", "coherence", "conditionLifetime", "nTrialsPerCondition", "proportion", "correct");
end

%%
%[text] ## Proportion correct
%[text] Matched filter, coherence as set, RGC noise SD 0. Rows: dot lifetime. Columns: dot speed. Each cell is out of 40 trials (standard error about 0.08 near 0.5).
if doAnalysis
    lifetimeNames = "lifetime " + string(conditionLifetime) + " s";
    resultsTable = array2table(proportion, RowNames=lifetimeNames, ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    resultsTable %#ok<NOPTS> displayed on purpose (Live Script)
    countTable = array2table(nCorrect, RowNames=lifetimeNames, ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    countTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Paired comparison with the 0.1-s baseline
%[text] The trials share seeds, so each longer-lifetime trial has a baseline twin. Counted per speed: trials that only the longer lifetime gets right, and trials that only the baseline gets right.
if doAnalysis
    onlyLonger = zeros(nJobs, nSpeeds);
    onlyBaseline = zeros(nJobs, nSpeeds);
    for k = 1:nJobs
        onlyLonger(k, :) = sum(correct(k + 1, :, :) & ~correct(1, :, :), 3);
        onlyBaseline(k, :) = sum(~correct(k + 1, :, :) & correct(1, :, :), 3);
    end
    pairedTable = table(repelem(lifetimesSec.', nSpeeds), repmat(speedsDegPerSec.', nJobs, 1), ...
        reshape(onlyLonger.', [], 1), reshape(onlyBaseline.', [], 1), ...
        VariableNames=["lifetimeSec", "speedDegPerSec", "onlyLongerCorrect", "onlyBaselineCorrect"]);
    pairedTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## The curves
if doAnalysis
    figure(Position=[100 100 480 380]);
    errorbar(repmat(speedsDegPerSec, nConditions, 1).', proportion.', standardError.', "o-", LineWidth=1.4)
    set(gca, XScale="log")
    xlim(speedsDegPerSec([1 end]).*[0.8 1.25])
    yline(chance, "k:", "chance")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    ylabel("proportion correct")
    legend(lifetimeNames, Location="northwest", AutoUpdate="off")
    title("Dot lifetime, coherence " + coherence + ", RGC noise SD 0")
    grid on
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBoothLifetime" + coherenceTag + "_curves.png"), ...
        Resolution=150)
end

%%
%[text] ## What to look for
%[text] If Inf lifetime lifts 0.15 deg/s well above 0.37, the lifetime is the limit. If not, the limit is the model's resolution and slow-speed tuning.

function coherenceGrid = localRunGrid(pars, templates, filters, speedsPxPerFrame, coherence, nTrials, lifetimeSec)
% One coherence and lifetime at every speed, read out with the matched
% filters. Prints progress after every trial.
    nSpeeds = numel(speedsPxPerFrame);
    coherenceGrid = struct( ...
        "proportionMatched", zeros(1, nSpeeds), ...
        "dprimeMatched", zeros(1, nSpeeds), ...
        "correctMatched", false(nSpeeds, nTrials), ...
        "seconds", 0);
    nTotal = nSpeeds*nTrials;
    timer = tic;
    for j = 1:nSpeeds
        trialsBefore = (j - 1)*nTrials;
        progress = @(n) localReportProgress(trialsBefore + n, nTotal, toc(timer));
        trialRun = shRunLetterTrials(pars, nTrials, SpeedPxPerFrame=speedsPxPerFrame(j), ...
            Coherence=coherence, Templates=templates, MatchedFilters=filters, ...
            BoothLifetimeSec=lifetimeSec, ProgressFcn=progress);
        coherenceGrid.proportionMatched(j) = trialRun.proportionCorrectMatched;
        coherenceGrid.dprimeMatched(j) = trialRun.dprimeMatched;
        coherenceGrid.correctMatched(j, :) = trialRun.choiceMatched == trialRun.trueIndex;
        coherenceGrid.seconds = coherenceGrid.seconds + trialRun.seconds;
        fprintf("Speed %g px/frame: proportion correct %.3f\n", speedsPxPerFrame(j), ...
            trialRun.proportionCorrectMatched);
    end
end

function localReportProgress(nDone, nTotal, elapsedSec)
    remainingSec = elapsedSec/nDone*(nTotal - nDone);
    fprintf("%s  trial %d/%d (%.0f%%), elapsed %.1f min, about %.1f min left\n", ...
        string(datetime("now", Format="HH:mm:ss")), nDone, nTotal, 100*nDone/nTotal, elapsedSec/60, ...
        remainingSec/60);
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
