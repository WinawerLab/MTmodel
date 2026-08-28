%% compensationIndex.m
% How much of a uniform RGC amplitude lesion does divisive normalization absorb,
% and does the absorption depend on stimulus drive (speed × coherence)?
%
% WHY. Both cortical stages compute R = s*N / (strength*D + sigma^2), with the
% normalization pool D driven by the LESIONED input. So scaling the RGC drive by
% k lowers D and RAISES the effective gain 1/(strength*D + sigma^2). Two regimes:
%
%   high drive (strength*k^2*D >> sigma^2):  R ~ independent of k   -> compensated
%   low  drive (strength*k^2*D << sigma^2):  R ~ k^2                -> not compensated
%
% Phase 1 (speed only, coherence = 1) quantifies §4.8. Phase 2 adds a coherence
% axis and re-expresses the lesion signature against unlesioned MT drive rather
% than speed (NOISE §5.5, TODO §1 step 1): if low-speed, high-speed and
% low-coherence conditions collapse onto one curve in drive space, the
% operating-point account wins; residual speed dependence at matched drive
% implicates something speed-specific.
%
% MEASURES. Reported separately, because "MT response" is ambiguous at low speed:
%   mtMove   best response over the 18 MOVING MT units (speed 1 and 6 px/frame)
%   mtSpd1   best over the 6 units tuned to 1 px/frame (5 deg/s)
%   mtSpd6   best over the 12 units tuned to 6 px/frame (30 deg/s)
%   mtStatic the single unit tuned to 0 px/frame - not a motion signal
%   v1Max    best over the 28 V1 neurons
%
% The compensation index is C = 1 - slope/2, where slope = dlogR/dlogk fitted
% over GAINS. C = 0 is no compensation (R ~ k^2), C = 1 is full compensation.
%
% Deterministic - no noise anywhere. This measures the gain headroom that noise
% would later act on.
%
% Usage:
%   run('explore/compensationIndex.m')

clear; clc;
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

SPEEDS_PXF  = [0.0625 0.125 0.3125 0.625 1 3 6];          % px/frame
COHERENCES  = [0.05 0.125 0.25 0.5 0.75 1];                % dot motion coherence
GAINS       = [1 0.7 0.5 0.3 0.1];                         % remaining RGC amplitude
DOT_SEED    = 4242;                                        % same dots per condition
DOT_DENS    = 0.1;

U = shModelUnits;
SPEEDS_DEG = SPEEDS_PXF * U.degPerSecPerPixelPerFrame;

outDir = fullfile(repoRoot, 'explore', '_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('=== Compensation index: normalization vs. uniform RGC amplitude lesion ===\n');
fprintf('units: 1 px/frame = %.3g deg/s, 1 frame = %.3g ms\n', ...
        U.degPerSecPerPixelPerFrame, U.msPerFrame);
fprintf('grid: %d speeds x %d coherences x %d gains\n\n', ...
        numel(SPEEDS_PXF), numel(COHERENCES), numel(GAINS));

presets = {'derivative', 'laggedMagno'};
S = struct();
G = struct();

for ip = 1:numel(presets)
    presetName = presets{ip};
    parsBase = localSetup(presetName, repoRoot);
    stimSz = shGetDims(parsBase, 'mtPattern', [1 1 31]);
    mtGroups = localMtGroups(parsBase);

    fprintf('--- preset: %s   (stim %dx%dx%d, %d MT units)\n', ...
        presetName, stimSz(1), stimSz(2), stimSz(3), ...
        size(parsBase.mtPopulationVelocities, 1));

    tAll = tic;
    G.(presetName) = localMeasureGrid(parsBase, stimSz, mtGroups, ...
        SPEEDS_PXF, COHERENCES, GAINS, DOT_SEED, DOT_DENS);
    fprintf('  grid done (%.1f s)\n\n', toc(tAll));

    % Speed-only slice (coherence = 1) for backward-compatible §4.8 tables
    iCoh1 = find(COHERENCES == 1, 1);
    S.(presetName) = localSliceAtCoherence(G.(presetName), iCoh1);

    localReport(presetName, S.(presetName), SPEEDS_DEG, SPEEDS_PXF, GAINS);
    localDriveReport(presetName, G.(presetName), SPEEDS_DEG, COHERENCES);
end

%% Empirical check on the k^2 reference: V1 with normalization off
fprintf('--- reference check: V1 numerator exponent with normalization off\n');
try
    p0 = localSetup('derivative', repoRoot);
    p0.v1NormalizationType = 'off';
    stimSz = shGetDims(p0, 'v1Complex', [1 1 31]);
    rng(DOT_SEED);
    stim = mkDots(stimSz, 0, 0.3125, DOT_DENS, 1);
    r0 = zeros(1, numel(GAINS));
    for ig = 1:numel(GAINS)
        p = localLesion(p0, GAINS(ig), stimSz);
        [pv, iv] = shModel(stim, p, 'v1Complex');
        r0(ig) = max(mean(shGetNeuron(pv, iv), 2));
    end
    b = polyfit(log(GAINS), log(r0), 1);
    fprintf('  slope with normalization OFF = %.3f  (expect ~2 if the numerator is k^2)\n\n', b(1));
catch ME
    fprintf('  skipped (%s)\n\n', ME.message);
end

save(fullfile(outDir, 'compensationIndex.mat'), ...
    'S', 'G', 'SPEEDS_PXF', 'SPEEDS_DEG', 'COHERENCES', 'GAINS');
fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.mat'));

localPlotSpeed(S, SPEEDS_DEG, GAINS, outDir);
localPlotDrive(G, SPEEDS_DEG, COHERENCES, GAINS, outDir);

% ======================================================================
function meas = localMeasureGrid(parsBase, stimSz, mtGroups, ...
        speedsPxf, coherences, gains, dotSeed, dotDens)

    nS = numel(speedsPxf);
    nC = numel(coherences);
    nG = numel(gains);

    meas = struct();
    meas.driveMt   = zeros(nS, nC);
    meas.driveV1   = zeros(nS, nC);
    meas.Cmt       = zeros(nS, nC);
    meas.Cv1       = zeros(nS, nC);
    meas.ratioMt   = zeros(nS, nC);
    meas.ratioV1   = zeros(nS, nC);
    meas.RmtMove   = zeros(nS, nC, nG);
    meas.Rv1Max    = zeros(nS, nC, nG);

    iMove = mtGroups.iMove;

    for ic = 1:nC
        coh = coherences(ic);
        for is = 1:nS
            spd = speedsPxf(is);
            rng(dotSeed);
            stim = mkDots(stimSz, 0, spd, dotDens, coh);

            rMove = zeros(1, nG);
            rV1   = zeros(1, nG);
            for ig = 1:nG
                pars = localLesion(parsBase, gains(ig), stimSz);
                [pop, ind] = shModel(stim, pars, 'mtPattern');
                rMT = mean(shGetNeuron(pop, ind), 2);
                rMove(ig) = max(rMT(iMove));

                [pv, iv] = shModel(stim, pars, 'v1Complex');
                rV1(ig) = max(mean(shGetNeuron(pv, iv), 2));
            end

            meas.RmtMove(is, ic, :) = rMove;
            meas.Rv1Max(is, ic, :)  = rV1;
            meas.driveMt(is, ic) = rMove(1);
            meas.driveV1(is, ic) = rV1(1);

            bMt = polyfit(log(gains), log(max(rMove, realmin)), 1);
            bV1 = polyfit(log(gains), log(max(rV1, realmin)), 1);
            meas.Cmt(is, ic) = 1 - bMt(1) / 2;
            meas.Cv1(is, ic) = 1 - bV1(1) / 2;

            iHalf = find(gains == 0.5, 1);
            meas.ratioMt(is, ic) = rMove(iHalf) / rMove(1);
            meas.ratioV1(is, ic) = rV1(iHalf) / rV1(1);
        end
        fprintf('  coherence %.3g done\n', coh);
    end
end

function R = localSliceAtCoherence(meas, iCoh)
    R = struct();
    R.mtMove = squeeze(meas.RmtMove(:, iCoh, :));
    R.v1Max  = squeeze(meas.Rv1Max(:, iCoh, :));
end

function pars = localSetup(name, repoRoot)
    pars = shPars;
    pars.rgc.enabled = 1;
    switch name
        case 'derivative'
            pars.rgc.mode = 'derivative';
        case 'laggedMagno'
            pars.rgc.mode        = 'custom';
            pars.rgc.classes     = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
            pars.rgc.combine     = 'weights';
            pars.rgc.classesMode = 'custom';
            WB = getfield(load(fullfile(repoRoot, 'pars', ...
                 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat')), 'v1Weights');
            WA = getfield(load(fullfile(repoRoot, 'pars', ...
                 'shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat')), 'v1WeightsMagnoA');
            pars.rgc.v1Weights = WB;
            pars.rgc.mtMix = struct('weightsA', WA, 'alpha', 0.10, 'delay', 0);
        otherwise
            error('unknown preset %s', name);
    end
end

function pars = localLesion(pars, gainRemaining, stimSz)
    if gainRemaining == 1
        pars.rgc.impairmentEnabled = 0;
        pars.rgc.impairmentAmplitudeMap = [];
        return;
    end
    pars = lesionApply(pars, 'amplitude_uniform_map', 'stimSize', stimSz(1:2), ...
        'uniformGain', gainRemaining);
end

function g = localMtGroups(pars)
    v = pars.mtPopulationVelocities(:, 2);
    g.iStatic = find(v == 0);
    g.iSpd1   = find(v == 1);
    g.iSpd6   = find(v == 6);
    g.iMove   = find(v > 0);
end

function localReport(name, R, spdDeg, spdPxf, gains)
    flds = {'mtMove', 'v1Max'};
    for f = 1:numel(flds)
        fld = flds{f};
        fprintf('  %s / %s  (coherence = 1)\n', name, fld);
        fprintf('    %8s %8s | %9s | %8s %8s | %6s %6s\n', ...
                'deg/s', 'px/fr', 'R(k=1)', 'R.5/R1', 'R.1/R1', 'slope', 'C');
        for is = 1:size(R.(fld), 1)
            r = R.(fld)(is, :);
            b = polyfit(log(gains), log(max(r, realmin)), 1);
            C = 1 - b(1)/2;
            i5 = find(gains == 0.5, 1); i1 = find(gains == 0.1, 1);
            fprintf('    %8.2f %8.4f | %9.4g | %8.3f %8.3f | %6.2f %6.2f\n', ...
                    spdDeg(is), spdPxf(is), r(1), r(i5)/r(1), r(i1)/r(1), b(1), C);
        end
        fprintf('\n');
    end
end

function localDriveReport(name, meas, spdDeg, coherences)
    nS = numel(spdDeg);
    nC = numel(coherences);
    drive = meas.driveMt(:);
    C = meas.Cmt(:);
    spdRep = repmat(spdDeg(:), nC, 1);
    cohRep = kron(coherences(:), ones(nS, 1));

    valid = drive > 0 & isfinite(C);
    x = log10(drive(valid));
    y = C(valid);
    spdV = spdRep(valid);
    cohV = cohRep(valid);

    bDrive = polyfit(x, y, 1);
    yHat = polyval(bDrive, x);
    ssRes = sum((y - yHat).^2);
    ssTot = sum((y - mean(y)).^2);
    r2Drive = 1 - ssRes / max(ssTot, eps);

    X = [ones(numel(x), 1), x, log10(spdV)];
    bFull = X \ y;
    yFull = X * bFull;
    ssResFull = sum((y - yFull).^2);
    r2DriveSpeed = 1 - ssResFull / max(ssTot, eps);

    fprintf('  %s / collapse test (MT moving, all speed x coherence)\n', name);
    fprintf('    R^2(C ~ log10 drive)             = %.3f\n', r2Drive);
    fprintf('    R^2(C ~ log10 drive + log speed) = %.3f\n', r2DriveSpeed);
    fprintf('    mean C at drive < 0.25: %.2f   at drive > 0.75: %.2f\n', ...
        mean(C(valid & drive < 0.25)), mean(C(valid & drive > 0.75)));
    fprintf('    JW check: high speed (>=5 deg/s) + low coherence (<=0.25):\n');
    hiSpdLoCoh = valid & spdRep >= 5 & cohRep <= 0.25;
    if any(hiSpdLoCoh)
        fprintf('      n=%d  mean drive=%.3f  mean C=%.2f  mean R(0.5)/R(1)=%.3f\n', ...
            sum(hiSpdLoCoh), mean(drive(hiSpdLoCoh)), mean(C(hiSpdLoCoh)), ...
            mean(meas.ratioMt(hiSpdLoCoh)));
    else
        fprintf('      (no grid points in this bin)\n');
    end
    fprintf('\n');
end

function localPlotSpeed(S, spdDeg, gains, outDir)
    presets = fieldnames(S);
    figure('Position', [80 80 1150 460]);
    for ip = 1:numel(presets)
        R = S.(presets{ip});

        subplot(numel(presets), 2, (ip-1)*2 + 1);
        semilogx(spdDeg, R.mtMove(:,1), 'o-', 'LineWidth', 1.6); hold on;
        semilogx(spdDeg, R.v1Max(:,1),  '^-');
        xlabel('stimulus speed (deg/s)'); ylabel('unlesioned response');
        title(sprintf('%s: baseline drive (coh=1)', presets{ip}), 'Interpreter', 'none');
        legend({'MT moving', 'V1'}, 'Location', 'northwest');
        grid on;

        subplot(numel(presets), 2, (ip-1)*2 + 2);
        C = zeros(numel(spdDeg), 2);
        for is = 1:numel(spdDeg)
            b = polyfit(log(gains), log(max(R.mtMove(is,:), realmin)), 1); C(is,1) = 1 - b(1)/2;
            b = polyfit(log(gains), log(max(R.v1Max(is,:),  realmin)), 1); C(is,2) = 1 - b(1)/2;
        end
        semilogx(spdDeg, C(:,1), 'o-', 'LineWidth', 1.6); hold on;
        semilogx(spdDeg, C(:,2), '^-');
        yline(0, 'k:'); yline(1, 'k:');
        ylim([-0.1 1.1]);
        xlabel('stimulus speed (deg/s)'); ylabel('compensation index C');
        title(sprintf('%s: C vs speed (coh=1)', presets{ip}), 'Interpreter', 'none');
        legend({'MT moving', 'V1'}, 'Location', 'southeast'); grid on;
    end
    saveas(gcf, fullfile(outDir, 'compensationIndex.png'));
    fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.png'));
end

function localPlotDrive(G, spdDeg, coherences, gains, outDir)
    presets = fieldnames(G);
    nC = numel(coherences);

    figure('Position', [60 60 1280 820]);
    for ip = 1:numel(presets)
        meas = G.(presets{ip});
        row = ip - 1;

        subplot(numel(presets), 3, row*3 + 1);
        imagesc(coherences, spdDeg, meas.driveMt);
        set(gca, 'YDir', 'normal');
        colorbar;
        xlabel('coherence'); ylabel('speed (deg/s)');
        title(sprintf('%s: unlesioned MT drive', presets{ip}), 'Interpreter', 'none');

        % C vs drive — collapse test (color = speed)
        subplot(numel(presets), 3, row*3 + 2);
        drive = meas.driveMt(:);
        C = meas.Cmt(:);
        spdRep = repmat(spdDeg(:), nC, 1);
        scatter(drive, C, 36, spdRep, 'filled'); hold on;
        colormap(gca, parula); colorbar;
        yline(0, 'k:'); yline(1, 'k:');
        xlabel('unlesioned MT drive (moving units)'); ylabel('compensation index C');
        title(sprintf('%s: C vs drive (colour = speed)', presets{ip}), 'Interpreter', 'none');
        grid on;

        % Lesion ratio R(0.5)/R(1) vs drive — deficit in response space
        subplot(numel(presets), 3, row*3 + 3);
        ratio = meas.ratioMt(:);
        scatter(drive, ratio, 36, spdRep, 'filled'); hold on;
        colormap(gca, parula); colorbar;
        xlabel('unlesioned MT drive'); ylabel('R(k=0.5) / R(k=1)');
        title(sprintf('%s: 50%% lesion vs drive', presets{ip}), 'Interpreter', 'none');
        grid on;
    end
    saveas(gcf, fullfile(outDir, 'compensationIndex_driveCoherence.png'));
    fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex_driveCoherence.png'));
end
