%% compensationIndex.m
% How much of a uniform RGC amplitude lesion does divisive normalization absorb,
% and does the absorption depend on stimulus speed?
%
% WHY. Both cortical stages compute R = s*N / (strength*D + sigma^2), with the
% normalization pool D driven by the LESIONED input. So scaling the RGC drive by
% k lowers D and RAISES the effective gain 1/(strength*D + sigma^2). Two regimes:
%
%   high drive (strength*k^2*D >> sigma^2):  R ~ independent of k   -> compensated
%   low  drive (strength*k^2*D << sigma^2):  R ~ k^2                -> not compensated
%
% This decides two things at once:
%
%   1. How much of docs/MODEL_AND_LESIONS.md 4.7.2's null result ("50% gain cut
%      barely moves direction tuning") is normalization absorbing the lesion.
%   2. JW's signal-starvation hypothesis (docs/NOISE_AND_DEMYELINATION.md 5.5):
%      the clinical low-speed deficit may not need low-speed-selective damage.
%      MT is tuned to {0,1,6} px/frame = {0,16,96} deg/s, so the clinical band
%      (1-10 deg/s) sits BELOW MT's slowest moving unit and MT is weakly driven
%      there. If low speed also sits in the uncompensated regime, an amplitude
%      lesion costs the full k^2 on an already-small signal - a deficit that is
%      about the operating point, not about which cells were damaged.
%
% MEASURES. Reported separately, because "MT response" is ambiguous at low speed:
%   mtMove   best response over the 18 MOVING MT units (speed 1 and 6 px/frame)
%   mtSpd1   best over the 6 units tuned to 1 px/frame (16 deg/s)
%   mtSpd6   best over the 12 units tuned to 6 px/frame (96 deg/s)
%   mtStatic the single unit tuned to 0 px/frame - not a motion signal
%   v1Max    best over the 28 V1 neurons
%
% The compensation index is C = 1 - slope/2, where slope = dlogR/dlogk fitted
% over GAINS. C = 0 is no compensation (R ~ k^2, the numerator exponent), C = 1
% is full compensation (R flat in k). The k^2 reference is checked empirically
% at the end by re-running V1 with normalization off.
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

SPEEDS_PXF = [0.0625 0.125 0.3125 0.625 1 3 6];   % px/frame
GAINS      = [1 0.7 0.5 0.3 0.1];                  % remaining RGC amplitude
DOT_SEED   = 4242;                                 % same dots for every gain
DOT_DENS   = 0.1;

U = shModelUnits;
SPEEDS_DEG = SPEEDS_PXF * U.degPerSecPerPixelPerFrame;

outDir = fullfile(repoRoot, 'explore', '_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('=== Compensation index: normalization vs. uniform RGC amplitude lesion ===\n');
fprintf('units: 1 px/frame = %.3g deg/s, 1 frame = %.3g ms\n\n', ...
        U.degPerSecPerPixelPerFrame, U.msPerFrame*1);

presets = {'derivative', 'laggedMagno'};
S = struct();

for ip = 1:numel(presets)
    presetName = presets{ip};
    parsBase = localSetup(presetName, repoRoot);
    stimSz = shGetDims(parsBase, 'mtPattern', [1 1 31]);
    [iMove, iSpd1, iSpd6, iStatic] = localMtGroups(parsBase);

    fprintf('--- preset: %s   (stim %dx%dx%d, %d MT units: %d static, %d @1, %d @6)\n', ...
        presetName, stimSz(1), stimSz(2), stimSz(3), ...
        size(parsBase.mtPopulationVelocities,1), numel(iStatic), numel(iSpd1), numel(iSpd6));

    nS = numel(SPEEDS_PXF); nG = numel(GAINS);
    R = struct('mtMove', zeros(nS,nG), 'mtSpd1', zeros(nS,nG), 'mtSpd6', zeros(nS,nG), ...
               'mtStatic', zeros(nS,nG), 'v1Max', zeros(nS,nG));

    tAll = tic;
    for is = 1:nS
        rng(DOT_SEED);                                  % identical dots across gains
        stim = mkDots(stimSz, 0, SPEEDS_PXF(is), DOT_DENS, 1);
        for ig = 1:nG
            pars = localLesion(parsBase, GAINS(ig), stimSz);

            [pop, ind] = shModel(stim, pars, 'mtPattern');
            rMT = mean(shGetNeuron(pop, ind), 2);
            R.mtMove(is,ig)   = max(rMT(iMove));
            R.mtSpd1(is,ig)   = max(rMT(iSpd1));
            R.mtSpd6(is,ig)   = max(rMT(iSpd6));
            R.mtStatic(is,ig) = max(rMT(iStatic));

            [pv, iv] = shModel(stim, pars, 'v1Complex');
            R.v1Max(is,ig) = max(mean(shGetNeuron(pv, iv), 2));
        end
        fprintf('  speed %6.2f deg/s done\n', SPEEDS_DEG(is));
    end
    fprintf('  (%.1f s)\n\n', toc(tAll));

    S.(presetName) = R;
    localReport(presetName, R, SPEEDS_DEG, SPEEDS_PXF, GAINS);
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

save(fullfile(outDir, 'compensationIndex.mat'), 'S', 'SPEEDS_PXF', 'SPEEDS_DEG', 'GAINS');
fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.mat'));

localPlot(S, SPEEDS_DEG, GAINS, outDir);

% ======================================================================
function pars = localSetup(name, repoRoot)
    pars = shPars;
    pars.rgc.enabled = 1;
    switch name
        case 'derivative'
            pars.rgc.mode = 'derivative';
        case 'laggedMagno'
            pars.rgc.mode        = 'custom';   % else shModelV1Linear rebuilds the classes
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
        return;
    end
    pars.rgc.impairmentEnabled = 1;
    pars.rgc.impairmentAmplitudeMap = gainRemaining * ones(stimSz(1), stimSz(2));
end

function [iMove, iSpd1, iSpd6, iStatic] = localMtGroups(pars)
    v = pars.mtPopulationVelocities(:, 2);
    iStatic = find(v == 0);
    iSpd1   = find(v == 1);
    iSpd6   = find(v == 6);
    iMove   = find(v > 0);
end

function localReport(name, R, spdDeg, spdPxf, gains)
    flds = {'mtMove', 'mtSpd1', 'mtSpd6', 'mtStatic', 'v1Max'};
    for f = 1:numel(flds)
        fld = flds{f};
        fprintf('  %s / %s\n', name, fld);
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

function localPlot(S, spdDeg, gains, outDir)
    presets = fieldnames(S);
    figure('Position', [80 80 1150 460]);
    for ip = 1:numel(presets)
        R = S.(presets{ip});

        subplot(numel(presets), 2, (ip-1)*2 + 1);
        semilogx(spdDeg, R.mtMove(:,1), 'o-', 'LineWidth', 1.6); hold on;
        semilogx(spdDeg, R.mtSpd1(:,1), 's--');
        semilogx(spdDeg, R.mtSpd6(:,1), 'd--');
        semilogx(spdDeg, R.v1Max(:,1),  '^-');
        xlabel('stimulus speed (deg/s)'); ylabel('unlesioned response');
        title(sprintf('%s: baseline drive', presets{ip}), 'Interpreter', 'none');
        legend({'MT moving','MT @16 deg/s','MT @96 deg/s','V1'}, 'Location', 'northwest');
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
        title(sprintf('%s: 0 = no rescue, 1 = full', presets{ip}), 'Interpreter', 'none');
        legend({'MT moving','V1'}, 'Location', 'southeast'); grid on;
    end
    saveas(gcf, fullfile(outDir, 'compensationIndex.png'));
    fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.png'));
end
