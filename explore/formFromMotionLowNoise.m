%[text] # Form-from-motion task: speed × coherence at lower internal noise
%[text] Step 3 found that lowering coherence mostly lowers the model's ceiling, while in the controls it mostly moves the threshold to faster speeds. One account of the difference is headroom. On the rising part of the curves, d′ is close to coherence^1.1 × speed^1.06, so lowering coherence is the same as lowering speed, and the threshold should move by about coherence^−1.05 (controls: −1.24). But d′ peaks at 5 deg/s, and at RGC noise SD 0.05 the full-coherence curve only reaches its ceiling at that peak. A lower-coherence curve reaches the peak before it gets high enough, so its ceiling drops.
%[text] This script tests that account by rerunning step 3 at lower RGC noise, which raises d′ in every condition and so gives the full-coherence curve room above its ceiling. The noise-level run found d′ ∝ (noise SD)^−1.88. Extrapolating, at SD 0.02 full coherence should reach about 0.88 correct near 0.7 deg/s, and coherence 0.25 should reach the same near 5 deg/s: the coherence curves should become mostly shifts along speed, like the controls'.
%[text] About 2,560 model runs (roughly 40 minutes on the desktop). Needs step 3's results in `explore/_figs/`; it reuses step 3's matched filters, speeds, coherences and trial seeds, so conditions are compared trial for trial. Results and figures go to `explore/_figs/` (gitignored).

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
step3File = fullfile(figureDir, "formFromMotionSpeedCoherence.mat");
if ~isfile(step3File)
    error("formFromMotionLowNoise:noStep3", ...
        "Step 3's results were not found in %s. Run explore/formFromMotionSpeedCoherence.m first.", figureDir);
end
step3 = load(step3File);
pars = shPars("lagged");
outSz = [64 64 50];
templates = shLetterTemplates(pars, outSz);
chance = 1/numel(templates.letters);
filters = step3.filters;
speedsPxPerFrame = step3.speedsPxPerFrame;
speedsDegPerSec = step3.speedsDegPerSec;
coherences = step3.coherences;
nTrialsPerCondition = step3.nTrialsPerCondition;
noiseSds = [0.03 0.02];
noiseRunExponent = -1.88;   % d' against RGC noise SD, measured in the noise-level run
maxFitSpeedDegPerSec = 10;
freeCeilingMaxLapse = 0.9;
controlFitsFile = fullfile(getenv("HOME"), "repos", "Research", "Exploring", ...
    "EXPLORING_Speed_Coherence_Psychometrics", "analysis", "out", "fits.mat");
controlUnitNames = ["wlsubj114", "wlsubj147", "wlsubj178", "wlsubj195", "wlsubj208"];

%%
%[text] ## Speed × coherence at RGC noise SD 0.03 and 0.02
%[text] 2 noise levels × 4 coherences × 8 speeds × 40 trials, with the same seeds as step 3.
nNoise = numel(noiseSds);
nCoherences = numel(coherences);
nSpeeds = numel(speedsPxPerFrame);
proportionMatched = zeros(nNoise, nCoherences, nSpeeds);
dprimeMatched = zeros(nNoise, nCoherences, nSpeeds);
correctMatched = false(nNoise, nCoherences, nSpeeds, nTrialsPerCondition);
gridSeconds = 0;
for m = 1:nNoise
    noisyPars = pars;
    noisyPars.noise.rgcSd = noiseSds(m);
    for i = 1:nCoherences
        for j = 1:nSpeeds
            gridRun = shRunLetterTrials(noisyPars, nTrialsPerCondition, ...
                SpeedPxPerFrame=speedsPxPerFrame(j), Coherence=coherences(i), ...
                Templates=templates, MatchedFilters=filters);
            proportionMatched(m, i, j) = gridRun.proportionCorrectMatched;
            dprimeMatched(m, i, j) = gridRun.dprimeMatched;
            correctMatched(m, i, j, :) = gridRun.choiceMatched == gridRun.trueIndex;
            gridSeconds = gridSeconds + gridRun.seconds;
        end
    end
end
save(fullfile(figureDir, "formFromMotionLowNoise.mat"), "speedsPxPerFrame", "speedsDegPerSec", ...
    "coherences", "noiseSds", "nTrialsPerCondition", "proportionMatched", "dprimeMatched", "correctMatched");
gridMinutes = gridSeconds/60;
gridMinutes %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Results as a table
%[text] Matched-filter proportion correct, with step 3 (SD 0.05) on top for comparison. Columns are dot speeds.
allSds = [step3.rgcSd, noiseSds];
nAll = numel(allSds);
allProportion = cat(1, reshape(step3.proportionMatched, [1 nCoherences nSpeeds]), proportionMatched);
allCorrect = cat(1, reshape(step3.correctMatched, [1 nCoherences nSpeeds nTrialsPerCondition]), correctMatched);
[coherenceGrid, sdGrid] = ndgrid(coherences, allSds);
rowNames = "SD " + string(sdGrid(:)) + ", coherence " + string(coherenceGrid(:));
resultsTable = array2table(reshape(permute(allProportion, [2 1 3]), [], nSpeeds), RowNames=rowNames, ...
    VariableNames=string(speedsDegPerSec) + " deg/s");
resultsTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## The coherence curves at each noise level
%[text] If the headroom account is right, the curves should spread out along speed as the noise falls, instead of stacking at different heights.
tiledlayout(1, nAll, TileSpacing="compact");
for m = 1:nAll
    nexttile
    semilogx(speedsDegPerSec, squeeze(allProportion(m, :, :)).', "o-", LineWidth=1.4)
    if m == 1
        ylabel("proportion correct")
        legend("coherence " + string(coherences), Location="northwest", AutoUpdate="off")
    end
    yline(chance, "k:")
    ylim([0 1])
    xlabel("dot speed (model deg/s)")
    title("RGC noise SD " + allSds(m))
    grid on
end
exportgraphics(gcf, fullfile(figureDir, "formFromMotionLowNoise_curves.png"), Resolution=150)

%%
%[text] ## Did d′ grow as predicted?
%[text] The prediction above assumed d′ ∝ (noise SD)^−1.88, measured between SD 0.05 and 0.12. Here the exponent is measured again between SD 0.05 and each lower SD: the median, over conditions up to 10 deg/s, of log(d′ ratio)/log(SD ratio). A value near −1.88 means the extrapolation held.
inFitSpeed = speedsDegPerSec <= maxFitSpeedDegPerSec;
measuredExponent = zeros(nNoise, 1);
for m = 1:nNoise
    dprimeRatio = squeeze(dprimeMatched(m, :, inFitSpeed))./step3.dprimeMatched(:, inFitSpeed);
    measuredExponent(m) = median(log(dprimeRatio(:)))/log(noiseSds(m)/step3.rgcSd);
end
exponentTable = table(noiseSds.', measuredExponent, repmat(noiseRunExponent, nNoise, 1), ...
    VariableNames=["noiseSd", "measuredExponent", "noiseRunExponent"]);
exponentTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Joint fits, compared with the controls
%[text] The same joint model and fitting rule as the controls (lapse at most 0.06), fitted to single trials at speeds up to 10 deg/s. The controls are the 10 units run with the current experiment code, using their censored fits. The coherence exponent b is the number to watch: if lower noise gives the model headroom, b should move from the steep value of step 3 toward the controls' range.
[trialCoherence, trialSpeed] = ndgrid(coherences, speedsDegPerSec, 1:nTrialsPerCondition);
inFit = trialSpeed <= maxFitSpeedDegPerSec;
for m = nAll:-1:1    % filled from the end, so the array is allocated once
    correctHere = squeeze(allCorrect(m, :, :, :));
    jointFits(m) = shFitSpeedCoherencePsychometric(trialSpeed(inFit), trialCoherence(inFit), ...
        correctHere(inFit));
end
observer = "model, RGC noise SD " + string(allSds.');
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

%%
%[text] ## Threshold against ceiling, with a free ceiling
%[text] Each coherence curve is fitted on its own, at speeds up to 10 deg/s, with a free ceiling (lapse rate up to 0.9), as in the noise-level run. Threshold is the midpoint between chance and that curve's own ceiling. The headroom account predicts that at lower noise the ceilings stay high and the thresholds spread apart.
speedInFit = speedsDegPerSec(inFitSpeed);
fitSpeed = repmat(speedInFit.', 1, nTrialsPerCondition);
freeThreshold = zeros(nAll, nCoherences);
freeCeiling = zeros(nAll, nCoherences);
freeSigma = zeros(nAll, nCoherences);
for m = 1:nAll
    for i = 1:nCoherences
        correctHere = squeeze(allCorrect(m, i, inFitSpeed, :));
        ceilingFit = shFitSpeedCoherencePsychometric(fitSpeed(:), ones(numel(fitSpeed), 1), ...
            correctHere(:), MaxLapse=freeCeilingMaxLapse);
        freeThreshold(m, i) = ceilingFit.thresholdAtCoherence1;
        freeCeiling(m, i) = 1 - ceilingFit.lambda;
        freeSigma(m, i) = ceilingFit.sigma;
    end
end
pathTable = table(sdGrid(:), coherenceGrid(:), reshape(freeThreshold.', [], 1), ...
    reshape(freeCeiling.', [], 1), reshape(freeSigma.', [], 1), ...
    VariableNames=["noiseSd", "coherence", "threshold", "ceiling", "sigma"]);
pathTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Summary: threshold shift against ceiling loss
%[text] For each noise level: how far the threshold moves from coherence 1 to coherence 0.25 (as a ratio of speeds), and how much the ceiling falls. The controls' exponent b ≈ −1.24 would move the threshold by a factor of about 0.25^−1.24 ≈ 5.6.
isFull = coherences == max(coherences);
isLowest = coherences == min(coherences);
thresholdRatio = freeThreshold(:, isLowest)./freeThreshold(:, isFull);
ceilingLoss = freeCeiling(:, isFull) - freeCeiling(:, isLowest);
shiftTable = table(allSds.', thresholdRatio, ceilingLoss, ...
    VariableNames=["noiseSd", "thresholdRatioLowestToFull", "ceilingLossLowestToFull"]);
shiftTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
tiledlayout(1, 2, TileSpacing="compact");
nexttile
semilogx(freeThreshold.', freeCeiling.', "o-", LineWidth=1.4)
xlabel("threshold (model deg/s)")
ylabel("fitted ceiling")
ylim([0 1])
legend("RGC noise SD " + string(allSds), Location="southwest")
title("Ceiling against threshold, across coherence")
grid on
nexttile
loglog(coherences, freeThreshold.', "o-", LineWidth=1.4)
xlabel("coherence")
ylabel("threshold (model deg/s)")
title("Threshold against coherence")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionLowNoise_path.png"), Resolution=150)

%%
%[text] ## What to look for
%[text] - Curves: as the noise falls, do the coherence curves spread out along speed and keep high ceilings, instead of stacking at different heights?
%[text] - The exponent table: did d′ grow as the noise-level run predicted? If not, the prediction for SD 0.02 in the introduction does not apply.
%[text] - Joint fits: does b move toward the controls' range (median about −1.24)?
%[text] - Summary table: does the threshold ratio grow toward about 5 while the ceiling loss shrinks? The drop above 10 deg/s will remain at every noise level, because d′ itself falls there; widening the model's speed range would need a coarser spatial scale. \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
