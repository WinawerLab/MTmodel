%[text] # Form-from-motion task: noise-free baseline
%[text] A first check of the motion-defined letter task in the MT model, with no internal noise. The only trial-to-trial variability is the dot sample itself. The design, the decisions and the departures from the booth study are in `docs/FORM_FROM_MOTION.md`.
%[text] Three questions:
%[text] - Can the decoder read the letter at a comfortable speed and full coherence?
%[text] - Does it fail when relative motion is removed (background drifting with the letter)? It must, or it is using some other cue.
%[text] - How does noise-free performance depend on speed and coherence? \

%%
%[text] ## Setup
%[text] The biological front-end with both MT streams, a 64 × 64 px (6.4 × 6.4 deg) MT output, and 50 frames (1 s). All trials are seeded inside `shRunLetterTrials`, so every condition sees the same letters, directions and dot samples.
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

%%
%[text] ## The templates on the MT output grid
%[text] Each Sloan letter's mask, cropped to the MT output grid. The letters are 29 px (2.9 deg) tall.
tiledlayout(2, 5, TileSpacing="compact");
for k = 1:numel(templates.letters)
    nexttile
    imagesc(templates.masks(:, :, k))
    axis image off
    title(templates.letters(k))
end
colormap(gray)

%%
%[text] ## One trial, looked at closely
%[text] 1 px/frame (5 deg/s), full coherence. Left: the rightward-minus-leftward MT map, with the true letter outlined. Right: the score for each of the 10 templates. The classifier picks the largest score in absolute size.
oneTrial = shRunLetterTrials(pars, 1, SpeedPxPerFrame=1, Templates=templates, KeepMaps=true);
tiledlayout(1, 2, TileSpacing="compact");
nexttile
imagesc(oneTrial.maps(:, :, 1))
axis image off
colorbar
hold on
contour(templates.masks(:, :, oneTrial.trueIndex(1)), [0.5 0.5], "w", LineWidth=1.2)
hold off
title(sprintf("Opponent map, letter %s, direction %d deg", ...
    templates.letters(oneTrial.trueIndex(1)), oneTrial.motionAngleDeg(1)))
nexttile
bar(categorical(cellstr(templates.letters.')), oneTrial.scores(1, :))
ylabel("template score (inside - outside)")
title(sprintf("Scores; the classifier chose %s", templates.letters(oneTrial.choice(1))))
exportgraphics(gcf, fullfile(figureDir, "formFromMotionBaseline_oneTrial.png"), Resolution=150)

%%
%[text] ## The motion control
%[text] Same speed and coherence, 20 trials each. In the control the background drifts WITH the letter, so there is no relative motion. Dot count, density and speed are unchanged. Performance must fall to chance (0.1).
nControlTrials = 20;
opposite = shRunLetterTrials(pars, nControlTrials, SpeedPxPerFrame=1, Templates=templates);
sameDrift = shRunLetterTrials(pars, nControlTrials, SpeedPxPerFrame=1, Templates=templates, ...
    BackgroundVelocityScale=1);
controlTable = table(["opposite drift"; "same drift (control)"], ...
    [opposite.proportionCorrect; sameDrift.proportionCorrect], ...
    [opposite.dprime; sameDrift.dprime], ...
    VariableNames=["condition", "proportionCorrect", "knownLetterDprime"]);
controlTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Speed × coherence, no internal noise
%[text] 8 speeds from 0.03 to 4 px/frame (0.15 to 20 deg/s) and the booth's 4 coherences, 20 trials per condition. MT's moving units are tuned to 1 px/frame (5 deg/s) and, as measured, about 3.7 px/frame (18 deg/s), so the useful speed range is set by the model's own tuning, not by the booth's 0.009–4 deg/s. At 20 trials a proportion correct has a standard error of up to 0.11, so read shapes, not single points.
speedsPxPerFrame = [0.03 0.06 0.125 0.25 0.5 1 2 4];
coherences = [1 0.75 0.5 0.25];
nGridTrials = 20;
proportionCorrect = zeros(numel(coherences), numel(speedsPxPerFrame));
dprimes = zeros(numel(coherences), numel(speedsPxPerFrame));
gridSeconds = 0;
for i = 1:numel(coherences)
    for j = 1:numel(speedsPxPerFrame)
        result = shRunLetterTrials(pars, nGridTrials, SpeedPxPerFrame=speedsPxPerFrame(j), ...
            Coherence=coherences(i), Templates=templates);
        proportionCorrect(i, j) = result.proportionCorrect;
        dprimes(i, j) = result.dprime;
        gridSeconds = gridSeconds + result.seconds;
    end
end
save(fullfile(figureDir, "formFromMotionBaseline.mat"), "speedsPxPerFrame", "coherences", ...
    "nGridTrials", "proportionCorrect", "dprimes");
gridMinutes = gridSeconds/60;
gridMinutes %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Results
%[text] Left: classifier proportion correct (chance 0.1). Right: known-letter d′.
speedsDegPerSec = speedsPxPerFrame*units.degPerSecPerPixelPerFrame;
chance = 1/numel(templates.letters);
legendLabels = "coherence " + string(coherences);
tiledlayout(1, 2, TileSpacing="compact");
nexttile
semilogx(speedsDegPerSec, proportionCorrect.', "o-", LineWidth=1.4)
yline(chance, "k:")
ylim([0 1])
xlabel("dot speed (deg/s)")
ylabel("proportion correct")
legend(legendLabels, Location="northwest")
title("Classifier, sign-free")
grid on
nexttile
semilogx(speedsDegPerSec, dprimes.', "o-", LineWidth=1.4)
xlabel("dot speed (deg/s)")
ylabel("d'")
title("Known letter")
grid on
exportgraphics(gcf, fullfile(figureDir, "formFromMotionBaseline_results.png"), Resolution=150)

%%
%[text] ## Results as a table
%[text] Classifier proportion correct. Rows are coherences, columns are dot speeds.
resultsTable = array2table(proportionCorrect, RowNames="coherence " + string(coherences), ...
    VariableNames=string(speedsDegPerSec) + " deg/s");
resultsTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## What to look for
%[text] - The control should sit near chance while the opposite-drift condition is well above it.
%[text] - Performance should rise with speed and fall with coherence. If the psychophysical pattern holds, lower coherence should shift the curves to faster speeds.
%[text] - Without internal noise the only variability is the dot sample, so the curves may be steep or saturate early. Internal noise (`pars.noise`) comes next. \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
