% runMotionLetterDemo  Motion-defined letter through the model, both RGC presets.
%
% Runs one seeded mkMotionLetter trial at a clinically relevant speed and asks
% the question the stimulus exists to ask: does the model segregate a letter
% that is defined by NOTHING BUT relative motion? Every frame is a uniform dot
% field -- the letter is invisible in any single frame, so any structure in the
% response maps had to be computed from motion.
%
% Compares the legacy-exact 'derivative' preset against the biological
% 'midgetParasolLagged' preset, at V1 and MT.
%
% Figures are written to explore/_figs/ (gitignored; regenerate by re-running).

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

%% CONFIG
LETTER      = 'C';
SPEED_DEG_S = 2;              % lab supra-threshold default (-> 0.125 px/frame)
OUT_SZ      = [128 128 120];  % model output [Y X T]
SEED        = 7;
FIGDIR      = fullfile(repoRoot, 'explore', '_figs');

if ~exist(FIGDIR, 'dir'), mkdir(FIGDIR); end
u = shModelUnits();

fprintf('=== Motion-defined letter demo ===\n');
fprintf('letter %s   %.1f deg/s   out %s   seed %d\n', ...
    LETTER, SPEED_DEG_S, mat2str(OUT_SZ), SEED);
fprintf('model units: %.2f px/deg, %.1f fps, 1 px/frame = %.0f deg/s\n\n', ...
    u.pixelsPerDegree, u.framesPerSecond, u.degPerSecPerPixelPerFrame);

presets = {'derivative', 'midgetParasolLagged'};
results = struct('name', {}, 'mtOpp', {}, 'v1Opp', {}, 'mtTrace', {}, ...
                 'dMt', {}, 'dV1', {}, 'mtPair', {}, 'v1Pair', {});

for pIdx = 1:numel(presets)
    presetName = presets{pIdx};
    pars = localPreset(presetName, repoRoot);

    stimSz = shGetDims(pars, 'mtPattern', OUT_SZ);
    letterPx = round(0.62 * min(stimSz(1:2)));
    [stim, info] = mkMotionLetter(stimSz, LETTER, 'seed', SEED, ...
        'referenceDisplaySize', [], 'ppd', u.pixelsPerDegree, ...
        'frameRate', u.framesPerSecond, 'dotSpeedDegS', SPEED_DEG_S, ...
        'letterSizePx', letterPx, 'dotSize', 3, 'fCovered', 0.3);
    speedPx = info.dotSpeedPxPerFrame;

    if pIdx == 1
        fprintf('stimulus: %d dots, dot %d px, letter %d px (%.1f deg), %.4f px/frame, %.2f s, font %s\n', ...
            info.numDots, info.dotSize, info.letterSizePx, info.letterSizeDeg, ...
            speedPx, stimSz(3) / u.framesPerSecond, info.fontName);
        stimKeep = stim; infoKeep = info;
    end

    fprintf('\n[%s]\n', presetName);
    tic; [popMt, indMt] = shModel(stim, pars, 'mtPattern');
    [popV1, indV1] = shModel(stim, pars, 'v1Complex');
    fprintf('  ran V1+MT in %.1f s\n', toc);

    mtVels = pars.mtPopulationVelocities;
    v1Dirs = pars.v1PopulationDirections;
    [iR, iL] = localOpponentPair(mtVels, speedPx);
    [jR, jL] = localOpponentPair(v1Dirs, speedPx);

    mtOpp = mean(squeeze(shGetSubPop(popMt, indMt, iR)) - ...
                 squeeze(shGetSubPop(popMt, indMt, iL)), 3);
    v1Opp = mean(squeeze(shGetSubPop(popV1, indV1, jR)) - ...
                 squeeze(shGetSubPop(popV1, indV1, jL)), 3);

    mask = motionLetterMaskOnMap(info.binaryMask, size(mtOpp, 1), size(mtOpp, 2));
    dMt = localDprime(mtOpp, mask);
    dV1 = localDprime(v1Opp, mask);

    fprintf('  MT pair: %5.1f deg @ %.3f  vs %5.1f deg @ %.3f px/frame\n', ...
        rad2deg(mtVels(iR,1)), mtVels(iR,2), rad2deg(mtVels(iL,1)), mtVels(iL,2));
    fprintf('  V1 pair: %5.1f deg @ %.3f  vs %5.1f deg @ %.3f px/frame\n', ...
        rad2deg(v1Dirs(jR,1)), v1Dirs(jR,2), rad2deg(v1Dirs(jL,1)), v1Dirs(jL,2));
    fprintf('  letter vs background  d'' :  MT %+.3f   V1 %+.3f\n', dMt, dV1);

    r = numel(results) + 1;
    results(r).name = presetName;
    results(r).mtOpp = mtOpp;
    results(r).v1Opp = v1Opp;
    results(r).mtTrace = shGetNeuron(popMt, indMt);
    results(r).dMt = dMt;
    results(r).dV1 = dV1;
    results(r).mtPair = mtVels([iR iL], :);
    results(r).v1Pair = v1Dirs([jR jL], :);
    results(r).mask = mask;
end

%% ---- Figure: stimulus and single-frame invisibility of the letter -------
fig1 = figure('Color', 'w', 'Position', [60 400 1200 340]);
tiledlayout(1, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

midT = round(size(stimKeep, 3) / 2);
nexttile;
imagesc(stimKeep(:, :, midT), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Single frame (t=%d)\nletter is invisible', midT));

nexttile;
imagesc(mean(stimKeep, 3), [0 1]); axis image off; colormap(gca, gray);
title(sprintf('Mean over all frames\n(still no letter)'));

nexttile;
dm = mean(abs(diff(stimKeep, 1, 3)), 3);
imagesc(dm); axis image off; colormap(gca, gray); colorbar;
title('Mean |frame difference|');

nexttile;
imagesc(infoKeep.binaryMask); axis image off; colormap(gca, gray);
title(sprintf('Ground-truth mask (''%s'')', LETTER));
sgtitle(sprintf('Motion-defined letter: %.1f deg/s (%.4f px/frame), %d dots', ...
    SPEED_DEG_S, infoKeep.dotSpeedPxPerFrame, infoKeep.numDots));
exportgraphics(fig1, fullfile(FIGDIR, 'motionLetter_stimulus.png'), 'Resolution', 130);

%% ---- Figure: opponent maps, both presets, V1 and MT --------------------
fig2 = figure('Color', 'w', 'Position', [60 60 1180 720]);
tiledlayout(2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

for r = 1:numel(results)
    nexttile;
    localShowMap(results(r).v1Opp, results(r).mask);
    title(sprintf('V1 opponent — %s\nd'' = %.2f', results(r).name, results(r).dV1));

    nexttile;
    localShowMap(results(r).mtOpp, results(r).mask);
    title(sprintf('MT opponent — %s\nd'' = %.2f', results(r).name, results(r).dMt));

    nexttile;
    inVals = results(r).mtOpp(results(r).mask);
    outVals = results(r).mtOpp(~results(r).mask);
    histogram(outVals, 40, 'Normalization', 'pdf', 'FaceAlpha', 0.55); hold on;
    histogram(inVals, 40, 'Normalization', 'pdf', 'FaceAlpha', 0.55); hold off;
    grid on; legend({'background', 'letter'}, 'Location', 'best', 'FontSize', 8);
    xlabel('MT opponent response'); ylabel('pdf');
    title(sprintf('MT letter vs background\n%s', results(r).name));
end
sgtitle(sprintf(['Right-minus-left opponent maps, %.1f deg/s. ' ...
    'White contour = true letter.'], SPEED_DEG_S));
exportgraphics(fig2, fullfile(FIGDIR, 'motionLetter_opponentMaps.png'), 'Resolution', 130);

%% ---- Figure: the control that shows this is really motion ---------------
% Same-direction background removes relative motion while preserving dot
% count, density, contrast and speed. If the letter still appeared, the model
% would be using something other than motion.
fprintf('\n=== Motion control ===\n');
pars = localPreset('derivative', repoRoot);
stimSz = shGetDims(pars, 'mtPattern', OUT_SZ);
letterPx = round(0.62 * min(stimSz(1:2)));
ctlScales = [-1 0 1];
ctlNames = {'opposite drift (Regan)', 'static background', 'same drift (control)'};
ctlMaps = cell(1, 3); ctlD = zeros(1, 3);

for k = 1:3
    [s, inf_] = mkMotionLetter(stimSz, LETTER, 'seed', SEED, ...
        'referenceDisplaySize', [], 'ppd', u.pixelsPerDegree, ...
        'frameRate', u.framesPerSecond, 'dotSpeedDegS', SPEED_DEG_S, ...
        'letterSizePx', letterPx, 'dotSize', 3, 'fCovered', 0.3, ...
        'backgroundVelocityScale', ctlScales(k));
    [pM, iM] = shModel(s, pars, 'mtPattern');
    [iR, iL] = localOpponentPair(pars.mtPopulationVelocities, inf_.dotSpeedPxPerFrame);
    ctlMaps{k} = mean(squeeze(shGetSubPop(pM,iM,iR)) - squeeze(shGetSubPop(pM,iM,iL)), 3);
    mk = motionLetterMaskOnMap(inf_.binaryMask, size(ctlMaps{k}, 1), size(ctlMaps{k}, 2));
    ctlD(k) = localDprime(ctlMaps{k}, mk);
    staticCue = localDprime(mean(s, 3), inf_.binaryMask);
    fprintf('  %-24s  MT d'' = %+.3f   (static-luminance d'' = %+.4f)\n', ...
        ctlNames{k}, ctlD(k), staticCue);
    ctlMask = mk;
end

fig3 = figure('Color', 'w', 'Position', [60 60 1150 380]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
for k = 1:3
    nexttile;
    localShowMap(ctlMaps{k}, ctlMask);
    title(sprintf('%s\nd'' = %.2f', ctlNames{k}, ctlD(k)));
end
sgtitle('Motion control: the letter survives only when there is relative motion');
exportgraphics(fig3, fullfile(FIGDIR, 'motionLetter_control.png'), 'Resolution', 130);

fprintf('\nWrote:\n  %s\n  %s\n  %s\n', ...
    fullfile(FIGDIR, 'motionLetter_stimulus.png'), ...
    fullfile(FIGDIR, 'motionLetter_opponentMaps.png'), ...
    fullfile(FIGDIR, 'motionLetter_control.png'));

%% ---- helpers ----
function pars = localPreset(name, repoRoot)
    pars = shPars;
    if strcmpi(name, 'derivative'), return; end
    pars.rgc.enabled = 1;
    pars.rgc.mode = 'custom';
    pars.rgc.classes = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
    pars.rgc.combine = 'weights';
    pars.rgc.classesMode = 'custom';
    wf = fullfile(repoRoot, 'pars', ...
        'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
    cached = load(wf);
    pars.rgc.v1Weights = cached.v1Weights;
end

function localShowMap(map, mask)
    imagesc(map); axis image off; colormap(gca, parula); colorbar;
    hold on; contour(mask, [0.5 0.5], 'w', 'LineWidth', 1.1); hold off;
end

function d = localDprime(map, mask)
    a = map(mask); b = map(~mask);
    d = (mean(a) - mean(b)) / sqrt(0.5 * (var(a) + var(b)));
end

% See explore/showMotionLetterModel.m for the rationale: match in the model's
% 3-D Fourier geometry, then speed-match the opponent to the chosen unit.
function [iPos, iNeg] = localOpponentPair(tuning, speedPx)
    moving = find(tuning(:, 2) > 0);
    U = localUnitVec(tuning(moving, :));
    [~, a] = max(U * localUnitVec([0, speedPx])');
    iPos = moving(a);
    [~, b] = max(U * localUnitVec([pi, tuning(iPos, 2)])');
    iNeg = moving(b);
end

function v = localUnitVec(tuning)
    el = atan3(tuning(:, 2), ones(size(tuning, 1), 1));
    v = sphere2rec([tuning(:, 1), el]);
    v = v ./ sqrt(sum(v.^2, 2));
end
