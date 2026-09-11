%[text] # Contrast response of V1 and MT at reduced RGC gain
%[text] Context for the constant in the normalization denominator (the semi-saturation constant). One V1 neuron and one MT neuron, both tuned to rightward motion at about 1 px/frame (5 deg/s), are driven by drifting gratings at their preferred spatial frequency and speed, at 16 contrasts, with the gain of every RGC class at 1, 0.5, 0.25 and 0.125. No internal noise.
%[text] In the lagged preset each RGC channel subtracts the frame mean, filters (linear), rectifies (which scales with its input), filters in time (linear) and then applies its gain. So contrast and gain enter only as their product: the response at gain k and contrast c equals the response at gain 1 and contrast k·c, whatever follows. Each lower-gain curve should therefore be the full-gain curve shifted right by log10(1/k); the script checks this. What matters is where the curve bends, and where the letter task sits on it: the task's own dots (a uniform rightward field at 5 deg/s, area-weighted dots, 50% coverage, 100 ms lifetime) are run through the same neurons at coherence 1, 0.5 and 0.25, and each is marked at the grating contrast that drives the neuron equally.

%%
%[text] ## Setup
repoRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(repoRoot));
figureDir = fullfile(repoRoot, "explore", "_figs");
if ~isfolder(figureDir)
    mkdir(figureDir);
end
pars = shPars("lagged");
units = shModelUnits();
nFrames = 80;
framesToAverage = 40;          % skip the onset of the long RGC temporal kernels
contrasts = logspace(-3, 0, 16);
gains = [1 0.5 0.25 0.125];
maxTemporalFrequency = 0.45;   % cycles/frame; avoid aliasing near 0.5
dotCoherences = [1 0.5 0.25];
dotSeed = 1;
directionTolerance = deg2rad(20);
speedTolerance = 1e-6;

v1Directions = pars.v1PopulationDirections;
isRightward = abs(angle(exp(1i*v1Directions(:, 1)))) < directionTolerance;
rightwardV1 = find(isRightward);
[~, pick] = min(abs(v1Directions(rightwardV1, 2)-1));
v1Unit = rightwardV1(pick);
mtVelocities = pars.mtPopulationVelocities;
mtUnit = find(abs(angle(exp(1i*mtVelocities(:, 1)))) < speedTolerance & ...
    abs(mtVelocities(:, 2)-1) < speedTolerance);
neurons = struct( ...
    "name", {"V1", "MT"}, ...
    "stage", {"v1Complex", "mtPattern"}, ...
    "unit", {v1Unit, mtUnit}, ...
    "direction", {v1Directions(v1Unit, 1), mtVelocities(mtUnit, 1)}, ...
    "speed", {v1Directions(v1Unit, 2), mtVelocities(mtUnit, 2)}, ...
    "sf", {NaN, NaN}, ...          % preferred grating, filled in below
    "tf", {NaN, NaN});

%%
%[text] ## Preferred grating
%[text] For each neuron, a search over spatial frequency and speed (a factor of 0.5 to 2 around the neuron's nominal speed) at full contrast and full gain. Temporal frequencies above 0.45 cycles/frame are skipped, as they would alias.
sfGrid = [0.08 0.12 0.16 0.2148 0.28 0.36];
speedFactors = [0.5 0.7 1 1.4 2];
for n = 1:numel(neurons)
    bestResponse = -Inf;
    for sf = sfGrid
        for factor = speedFactors
            tf = sf*neurons(n).speed*factor;
            if tf <= maxTemporalFrequency
                response = localGratingResponse(pars, neurons(n), sf, tf, 1, nFrames, framesToAverage);
                if response > bestResponse
                    bestResponse = response;
                    neurons(n).sf = sf;
                    neurons(n).tf = tf;
                end
            end
        end
    end
end
tuningTable = table(string({neurons.name}).', [neurons.unit].', rad2deg([neurons.direction]).', ...
    [neurons.speed].', [neurons.sf].', [neurons.tf].', ([neurons.tf]./[neurons.sf]).', ...
    VariableNames=["neuron", "unit", "directionDeg", "nominalSpeedPxPerFrame", ...
    "preferredSfCyclesPerPx", "preferredTfCyclesPerFrame", "gratingSpeedPxPerFrame"]);
tuningTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Contrast response at each RGC gain
nContrasts = numel(contrasts);
nGains = numel(gains);
response = zeros(numel(neurons), nGains, nContrasts);
for g = 1:nGains
    gainPars = pars;
    for c = 1:numel(gainPars.rgc.classes)
        gainPars.rgc.classes(c).gain = gains(g)*pars.rgc.classes(c).gain;
    end
    for n = 1:numel(neurons)
        for k = 1:nContrasts
            response(n, g, k) = localGratingResponse(gainPars, neurons(n), neurons(n).sf, ...
                neurons(n).tf, contrasts(k), nFrames, framesToAverage);
        end
    end
end

%%
%[text] ## Checks: the shift, and the semi-saturation contrast
%[text] shiftError: the largest difference between each lower-gain curve and the full-gain curve evaluated at contrast × gain, as a fraction of the full-gain maximum (interpolated on log contrast, where both are defined). It should be near zero. c50: the contrast at which the full-gain response is halfway between its values at the lowest and highest contrast.
logContrast = log10(contrasts);
shiftError = zeros(numel(neurons), nGains);
c50 = zeros(numel(neurons), 1);
for n = 1:numel(neurons)
    fullGain = squeeze(response(n, 1, :)).';
    for g = 2:nGains
        shifted = logContrast + log10(gains(g));
        defined = shifted >= logContrast(1);
        predicted = interp1(logContrast, fullGain, shifted(defined));
        shiftError(n, g) = max(abs(squeeze(response(n, g, defined)).'-predicted))/max(fullGain);
    end
    halfway = fullGain(1) + (fullGain(end)-fullGain(1))/2;
    c50(n) = 10^localFirstCrossing(fullGain, logContrast, halfway);
end
checkTable = table(string({neurons.name}).', c50, max(shiftError, [], 2), ...
    VariableNames=["neuron", "c50", "largestShiftError"]);
checkTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Where the letter task sits
%[text] A uniform field of the task's dots drifting rightward at 5 deg/s, at each coherence, through the same neurons (mean over space and the last 40 frames, full gain). The equivalent contrast is the grating contrast that gives the same response; NaN means the dots drive the neuron beyond the grating's full-contrast response. At gain k the task sits at k times its equivalent contrast.
dotOutSz = [24 24 nFrames];
equivalentContrast = nan(numel(neurons), numel(dotCoherences));
dotResponse = zeros(numel(neurons), numel(dotCoherences));
for n = 1:numel(neurons)
    fullGain = squeeze(response(n, 1, :)).';
    stimSz = shGetDims(pars, neurons(n).stage, dotOutSz);
    for d = 1:numel(dotCoherences)
        rng(dotSeed);
        stim = mkMotionLetter(stimSz, 'C', referenceDisplaySize=[], ...
            ppd=units.pixelsPerDegree, frameRate=units.framesPerSecond, ...
            dotSpeedPxPerFrame=1, letterMask=false(stimSz(1:2)), dotSize=0.4, ...
            dotRendering='area', fCovered=0.5, coherence=dotCoherences(d), ...
            dotLifetimeFrames=5, backgroundVelocityScale=1, motionAngleDeg=0);
        [pop, ind] = shModel(stim, pars, neurons(n).stage);
        subPop = shGetSubPop(pop, ind, neurons(n).unit);
        dotResponse(n, d) = mean(subPop(:, :, end-framesToAverage+1:end), "all");
        equivalentContrast(n, d) = 10^localFirstCrossing(fullGain, logContrast, dotResponse(n, d));
    end
end
operatingTable = array2table(equivalentContrast, RowNames=string({neurons.name}), ...
    VariableNames="coherence " + string(dotCoherences));
operatingTable %#ok<NOPTS> displayed on purpose (Live Script)

%%
%[text] ## Figure
%[text] Solid lines: contrast response at each RGC gain. Dashed vertical lines: the letter task's dots at each coherence, at full gain.
gainLabels = "RGC gain " + string(gains);
tiledlayout(1, numel(neurons), TileSpacing="compact");
for n = 1:numel(neurons)
    nexttile
    semilogx(contrasts, squeeze(response(n, :, :)).', "-o", LineWidth=1.4, MarkerSize=4)
    hold on
    for d = 1:numel(dotCoherences)
        if ~isnan(equivalentContrast(n, d))
            xline(equivalentContrast(n, d), "--", "dots, coh " + string(dotCoherences(d)), ...
                LabelVerticalAlignment="top")
        end
    end
    hold off
    xlabel("grating contrast")
    ylabel("response")
    title(sprintf("%s, %.0f deg, sf %.3g cyc/px, tf %.3g cyc/frame", neurons(n).name, ...
        rad2deg(neurons(n).direction), neurons(n).sf, neurons(n).tf))
    legend(gainLabels, Location="northwest")
    grid on
end
exportgraphics(gcf, fullfile(figureDir, "formFromMotionContrastResponse.png"), Resolution=150)

function response = localGratingResponse(pars, neuron, sf, tf, contrast, nFrames, framesToAverage)
% Time-averaged response of one neuron, at the centre of the field, to a
% full-field grating drifting in the neuron's preferred direction.
    stimSz = shGetDims(pars, neuron.stage, [1 1 nFrames]);
    stim = mkSin(stimSz, neuron.direction, sf, tf, contrast);
    [pop, ind] = shModel(stim, pars, neuron.stage);
    trace = shGetNeuron(pop, ind, neuron.unit);
    response = mean(trace(end-framesToAverage+1:end));
end

function crossing = localFirstCrossing(values, positions, target)
% Position at which values first reaches target, interpolated linearly
% between the two samples that bracket it. NaN if values never reaches it,
% or starts above it. Unlike interp1, this tolerates repeated values (for
% example a flat floor at low contrast).
    above = find(values >= target, 1);
    if isempty(above) || above == 1
        crossing = NaN;
    else
        fraction = (target-values(above-1))/(values(above)-values(above-1));
        crossing = positions(above-1) + fraction*(positions(above)-positions(above-1));
    end
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
