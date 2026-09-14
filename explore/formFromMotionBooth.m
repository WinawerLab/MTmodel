%[text] # Form-from-motion task: the booth stimulus, without internal noise
%[text] With 1-s trials drawn straight into 0.1-deg pixels, coherence 0.25 stayed near 0.7 correct even without internal noise, limited by the dots' own randomness. If the model cannot reach ceiling without internal noise, it cannot match the controls. This script draws every trial the way the booth draws it (mkBoothLetterMovie: the full 1280 × 960 screen at 85 frames/s, 4-px anti-aliased dots, 100-ms lifetimes, 4-s trials) and averages it into the model's 0.1-deg pixels and 20-ms frames. It then runs the speed × coherence grid with NO internal noise. If coherence 0.25 still cannot reach ceiling, the limit lies in the model's architecture.
%[text] For comparison, the same grid is also run without noise on the earlier stimulus (step 3's: 1-s trials, dots drawn as area into 0.1-deg pixels, 10 × 10 deg).
%[text] The work is split into jobs so that it can run as parallel MATLAB processes (`explore/runFormFromMotionBooth.sh`): "filters" builds the templates and matched filters; "coherence1" to "coherence4" each run one coherence of the booth grid; "model1s" runs the earlier stimulus; "analysis" combines them. Set the variable `jobs` before running the script to choose; without it, everything runs in order (many hours). Results go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
if ~isfolder(figureDir)
    mkdir(figureDir);
end
coherences = [1 0.75 0.5 0.25];
nCoherences = numel(coherences);
coherenceJobNames = "coherence" + (1:nCoherences);
allJobs = ["filters", coherenceJobNames, "model1s", "analysis"];
if ~exist("jobs", "var")
    jobs = allJobs;
end
jobs = string(jobs);
unknownJobs = setdiff(jobs, allJobs);
if ~isempty(unknownJobs)
    error("formFromMotionBooth:jobs", "Unknown jobs: %s. Choose from: %s.", ...
        join(unknownJobs, ", "), join(allJobs, ", "));
end
pars = shPars("lagged");    % internal noise is off by default
units = shModelUnits();
booth = boothDisplay();
margin = shGetDims(pars, "mtPattern", [1 1 1]) - 1;
boothOutSz = booth.modelSize - margin;
modelOutSz = [64 64 50];
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
nSpeeds = numel(speedsPxPerFrame);
nTrialsPerCondition = 40;
chance = 0.1;
maxFitSpeedDegPerSec = 10;
freeCeilingMaxLapse = 0.9;
filtersFile = fullfile(figureDir, "formFromMotionBooth_filters.mat");
coherenceFiles = fullfile(figureDir, "formFromMotionBooth_" + coherenceJobNames + ".mat");
model1sFile = fullfile(figureDir, "formFromMotionBooth_model1s.mat");
step3File = fullfile(figureDir, "formFromMotionSpeedCoherence.mat");
controlFitsFile = fullfile(getenv("HOME"), "repos", "Research", "Exploring", ...
    "EXPLORING_Speed_Coherence_Psychometrics", "analysis", "out", "fits.mat");
controlUnitNames = ["wlsubj114", "wlsubj147", "wlsubj178", "wlsubj195", "wlsubj208"];

%%
%[text] ## Job "filters": booth templates and matched filters
%[text] The letters are drawn at booth resolution (282-px Sloan font, 283 px tall) and averaged into model pixels. The matched filters are built as in step 3: the expected MT map of each letter, from 8 noise-free trials per letter at coherence 1 and 5 deg/s, now with the booth stimulus. Both are saved for the coherence jobs.
if any(jobs == "filters")
    filterTimer = tic;
    boothTemplates = shLetterTemplates(pars, boothOutSz, BoothDisplay=booth);
    boothFilters = shMatchedFilterTemplates(pars, boothTemplates, NumPerLetter=8);
    save(filtersFile, "boothTemplates", "boothFilters");
    filterMinutes = toc(filterTimer)/60 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Jobs "coherence1" to "coherence4": the booth grid
%[text] Each job runs one coherence: 8 speeds × 40 trials, no internal noise, with the same seeds as step 3.
coherenceJobs = find(ismember(coherenceJobNames, jobs));
if ~isempty(coherenceJobs)
    if ~isfile(filtersFile)
        error("formFromMotionBooth:noFilters", ...
            "The booth templates and filters were not found in %s. Run the ""filters"" job first.", ...
            filtersFile);
    end
    saved = load(filtersFile);
    for i = coherenceJobs
        boothGrid = localRunGrid(pars, saved.boothTemplates, saved.boothFilters, speedsPxPerFrame, ...
            coherences(i), nTrialsPerCondition);
        save(coherenceFiles(i), "boothGrid");
        boothMinutes = boothGrid.seconds/60 %#ok<NOPTS> displayed on purpose (Live Script)
    end
end

%%
%[text] ## Job "model1s": the earlier stimulus, without internal noise
%[text] Step 3's stimulus and step 3's matched filters, which were also built without noise (rebuilt if step 3's results are not on this machine).
if any(jobs == "model1s")
    modelTemplates = shLetterTemplates(pars, modelOutSz);
    if isfile(step3File)
        modelFilters = load(step3File).filters;
    else
        modelFilters = shMatchedFilterTemplates(pars, modelTemplates, NumPerLetter=8);
    end
    model1s = struct( ...
        "proportionMatched", zeros(nCoherences, nSpeeds), ...
        "dprimeMatched", zeros(nCoherences, nSpeeds), ...
        "correctMatched", false(nCoherences, nSpeeds, nTrialsPerCondition), ...
        "seconds", 0);
    for i = 1:nCoherences
        modelGrid = localRunGrid(pars, modelTemplates, modelFilters, speedsPxPerFrame, ...
            coherences(i), nTrialsPerCondition);
        model1s.proportionMatched(i, :) = modelGrid.proportionMatched;
        model1s.dprimeMatched(i, :) = modelGrid.dprimeMatched;
        model1s.correctMatched(i, :, :) = modelGrid.correctMatched;
        model1s.seconds = model1s.seconds + modelGrid.seconds;
    end
    save(model1sFile, "model1s");
    model1sMinutes = model1s.seconds/60 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Job "analysis": combine the jobs
doAnalysis = any(jobs == "analysis");
if doAnalysis
    neededFiles = [coherenceFiles, model1sFile];
    missingFiles = neededFiles(~isfile(neededFiles));
    if ~isempty(missingFiles)
        error("formFromMotionBooth:missingJobs", "These results are missing: %s. Run their jobs first.", ...
            join(missingFiles, ", "));
    end
    boothProportion = zeros(nCoherences, nSpeeds);
    boothDprime = zeros(nCoherences, nSpeeds);
    boothCorrect = false(nCoherences, nSpeeds, nTrialsPerCondition);
    boothSeconds = 0;
    for i = 1:nCoherences
        boothGrid = load(coherenceFiles(i)).boothGrid;
        boothProportion(i, :) = boothGrid.proportionMatched;
        boothDprime(i, :) = boothGrid.dprimeMatched;
        boothCorrect(i, :, :) = boothGrid.correctMatched;
        boothSeconds = boothSeconds + boothGrid.seconds;
    end
    model1s = load(model1sFile).model1s;
    save(fullfile(figureDir, "formFromMotionBooth.mat"), "speedsPxPerFrame", "speedsDegPerSec", ...
        "coherences", "nTrialsPerCondition", "boothProportion", "boothDprime", "boothCorrect", "model1s");
    boothHours = boothSeconds/3600 %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Proportion correct
%[text] Matched filter, no internal noise. Rows: stimulus and coherence. Columns: dot speed.
if doAnalysis
    rowNames = ["booth, coherence " + string(coherences), "1 s, coherence " + string(coherences)];
    resultsTable = array2table([boothProportion; model1s.proportionMatched], RowNames=rowNames, ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    resultsTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Does every coherence reach ceiling somewhere?
%[text] The best proportion correct over speeds, for each coherence and stimulus. With 40 trials, 0.95 has a standard error of about 0.035.
if doAnalysis
    [boothBest, boothBestIndex] = max(boothProportion, [], 2);
    [model1sBest, model1sBestIndex] = max(model1s.proportionMatched, [], 2);
    bestTable = table(coherences.', boothBest, speedsDegPerSec(boothBestIndex).', model1sBest, ...
        speedsDegPerSec(model1sBestIndex).', VariableNames=["coherence", "boothBest", ...
        "boothBestSpeed", "oneSecondBest", "oneSecondBestSpeed"]);
    bestTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
if doAnalysis
    tiledlayout(1, 2, TileSpacing="compact");
    nexttile
    semilogx(speedsDegPerSec, model1s.proportionMatched.', "o-", LineWidth=1.4)
    legend("coherence " + string(coherences), Location="northwest", AutoUpdate="off")
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    ylabel("proportion correct")
    title("Earlier stimulus (1 s, area dots), no noise")
    grid on
    nexttile
    semilogx(speedsDegPerSec, boothProportion.', "o-", LineWidth=1.4)
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    title("Booth stimulus (4 s, booth dots), no noise")
    grid on
    exportgraphics(gcf, fullfile(figureDir, "formFromMotionBooth_curves.png"), Resolution=150)
end

%%
%[text] ## d′ of the true letter
%[text] Booth stimulus above, earlier stimulus below. Without internal noise all the variability comes from the dots.
if doAnalysis
    dprimeTable = array2table(round([boothDprime; model1s.dprimeMatched], 2), RowNames=rowNames, ...
        VariableNames=string(speedsDegPerSec) + " deg/s");
    dprimeTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Threshold and ceiling, with a free ceiling
%[text] Each coherence curve fitted on its own at speeds up to 10 deg/s, with a free ceiling (lapse up to 0.9), as in the noise-level run.
if doAnalysis
    inFitSpeed = speedsDegPerSec <= maxFitSpeedDegPerSec;
    fitSpeed = repmat(speedsDegPerSec(inFitSpeed).', 1, nTrialsPerCondition);
    stimulusCorrect = {boothCorrect, model1s.correctMatched};
    stimulusNames = ["booth", "1 s"];
    freeThreshold = zeros(nCoherences, 2);
    freeCeiling = zeros(nCoherences, 2);
    for s = 1:2
        for i = 1:nCoherences
            correctHere = squeeze(stimulusCorrect{s}(i, inFitSpeed, :));
            ceilingFit = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), ...
                correctHere(:), MaxLapse=freeCeilingMaxLapse);
            freeThreshold(i, s) = ceilingFit.thresholdAtCoherence1;
            freeCeiling(i, s) = 1 - ceilingFit.lambda;
        end
    end
    freeTable = table(coherences.', freeThreshold(:, 1), freeCeiling(:, 1), freeThreshold(:, 2), ...
        freeCeiling(:, 2), VariableNames=["coherence", "boothThreshold", "boothCeiling", ...
        "oneSecondThreshold", "oneSecondCeiling"]);
    freeTable %#ok<NOPTS> displayed on purpose (Live Script)
end

%%
%[text] ## Joint fit, compared with the controls
%[text] The controls' joint model and fitting rule (lapse at most 0.06), at speeds up to 10 deg/s. The controls are the 10 units run with the current experiment code, using their censored fits.
if doAnalysis
    [trialCoherence, trialSpeed] = ndgrid(coherences, speedsDegPerSec, 1:nTrialsPerCondition);
    inFit = trialSpeed <= maxFitSpeedDegPerSec;
    for s = 2:-1:1    % filled from the end, so the array is allocated once
        jointFits(s) = shFitSpeedCoherencePsychometric(trialSpeed(inFit), trialCoherence(inFit), ...
            stimulusCorrect{s}(inFit));
    end
    observer = "model, no noise, " + stimulusNames.';
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
%[text] - The best-speed table: does coherence 0.25 reach ceiling (about 0.95 or more) at some speed with the booth stimulus? If it does, internal noise can be added back and calibrated. If it does not, the limit is the model's own architecture (receptive-field sizes, speed range), not the stimulus.
%[text] - The two stimuli side by side: how much do the booth rendering, the 4-s trials and the full screen raise performance without noise?
%[text] - d′: without internal noise it measures how much letter information survives the model, given the dots' own randomness. \

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
