%% compensationIndex.m
% Is the controlling variable for an RGC amplitude lesion the STIMULUS SPEED, or
% the SIZE OF THE DRIVE reaching the read-out?
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
%      MT is tuned to {0,1,6} px/frame = {0,5,30} deg/s, so the bottom of the
%      clinical band (0.2-3 deg/s) sits below MT's slowest moving unit and MT is
%      weakly driven there. If low speed also sits in the uncompensated regime, an
%      amplitude lesion costs the full k^2 on an already-small signal - a deficit
%      that is about the operating point, not about which cells were damaged.
%
% THE COHERENCE AXIS, AND WHAT IT IS FOR (docs/TODO.md 1, step 1). Speed is only
% one way to starve the read-out. LOWERING COHERENCE LOWERS THE DRIVE AT ANY
% SPEED, so it separates "drive" from "speed", which the speed axis alone cannot
% do. The discriminating test, stated in NOISE_AND_DEMYELINATION.md 5.5:
%
%   Plot the deficit against UNLESIONED DRIVE rather than against speed. If the
%   low-speed, high-speed and low-coherence conditions all collapse onto one
%   curve, the operating-point account wins outright. If the deficit still
%   depends on speed at MATCHED DRIVE, something speed-specific - cell type - is
%   also at work.
%
% localCollapse below runs exactly that test: it fits the deficit against log
% drive alone, then re-fits with log speed added, and reports what the speed term
% buys. A speed term that buys nothing is the operating-point account winning.
%
% MEASURES. Reported separately, because "MT response" is ambiguous at low speed
% and ambiguous again at low coherence:
%   mtOpp    OPPONENT signal: the unit tuned to the stimulus direction minus the
%            unit tuned to the opposite direction, within one speed shell. THIS
%            IS THE MEASURE TO READ ON THE COHERENCE AXIS. The measures below are
%            best-over-units, and at low coherence some unit always responds to
%            the randomly-directed dots, so they conflate signal with response.
%            The opponent difference cancels that: it is what a direction
%            read-out would actually have to work with. Free to compute - the
%            whole population comes out of the same run.
%   mtOpp1   opponent signal within the 1 px/frame shell (5 deg/s)
%   mtOpp6   opponent signal within the 6 px/frame shell (30 deg/s)
%   mtMove   best response over the 18 MOVING MT units (speed 1 and 6 px/frame)
%   mtSpd1   best over the 6 units tuned to 1 px/frame (5 deg/s)
%   mtSpd6   best over the 12 units tuned to 6 px/frame (30 deg/s)
%   mtStatic the single unit tuned to 0 px/frame - not a motion signal
%   v1Max    best over the 28 V1 neurons. The control: starvation is claimed to
%            be specific to MT, so V1 is what shows it is not a front-end effect.
%
% mtOpp uses whichever of the two speed shells carries the larger opponent signal
% UNLESIONED, and then holds that shell fixed across gains, so the measure cannot
% change its mind about which neuron it is reading halfway down a lesion series.
%
% The compensation index is C = 1 - slope/2, where slope = dlogR/dlogk fitted
% over GAINS. C = 0 is no compensation (R ~ k^2, the numerator exponent), C = 1
% is full compensation (R flat in k). The k^2 reference is checked empirically
% at the end by re-running V1 with normalization off. C is NaN wherever a measure
% is non-positive at some gain, which the opponent measure can be at low
% coherence; a NaN there is a real result, not a failure.
%
% THE OPPONENT MEASURE CAN GO NEGATIVE, and that is a result rather than a fault.
% At 6 px/frame the derivative preset's 6 px/frame shell is past its own peak
% (it peaks near 3.1 - report 4.3), so the anti-preferred unit can out-respond the
% preferred one. Such a condition drops out of the log fits and out of the
% collapse test; localCollapse prints how many conditions it actually used, and
% that count is worth reading before the R^2 beside it.
%
% Deterministic - no noise anywhere. This measures the gain headroom that noise
% would later act on.
%
% NOT YET RUN IN MATLAB. Written 2026-08-28. The code path was exercised
% end-to-end under Octave on a reduced grid - tables, collapse test and the k^2
% reference check (which returned exactly 2.000) all ran - but Octave is not this
% repo's reference interpreter and no number from it is recorded anywhere. Run it
% in MATLAB before quoting anything.
%
% COST. The grid is speeds x coherences x gains, two model calls per cell, two
% presets. With the defaults below that is 7 x 4 x 5 x 2 x 2 = 560 model runs,
% about four times the speed-only version of this script. Trim COHERENCES first
% if that is too slow; the coherence = 1 row reproduces the earlier results.
%
% Usage:
%   run('explore/compensationIndex.m')

clear; clc;
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

SPEEDS_PXF = [0.0625 0.125 0.3125 0.625 1 3 6];   % px/frame
COHERENCES = [1 0.5 0.25 0.125];                   % fraction of dots moving coherently
GAINS      = [1 0.7 0.5 0.3 0.1];                  % remaining RGC amplitude
K_REF      = 0.5;                                  % gain the reported deficit is quoted at
DOT_SEED   = 4242;                                 % same dots for every gain
DOT_DENS   = 0.1;
STIM_DIR   = 0;                                    % rightward, in radians

assert(any(abs(GAINS - K_REF) < eps), 'K_REF must be one of GAINS.');
assert(GAINS(1) == 1, 'GAINS(1) must be 1 - the unlesioned drive is read from it.');

U = shModelUnits;
SPEEDS_DEG = SPEEDS_PXF * U.degPerSecPerPixelPerFrame;

outDir = fullfile(repoRoot, 'explore', '_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end

fprintf('=== Compensation index: normalization vs. uniform RGC amplitude lesion ===\n');
fprintf('units: 1 px/frame = %.3g deg/s, 1 frame = %.3g ms\n', ...
        U.degPerSecPerPixelPerFrame, U.msPerFrame*1);
fprintf('grid: %d speeds x %d coherences x %d gains, deficit quoted at k = %.2g\n\n', ...
        numel(SPEEDS_PXF), numel(COHERENCES), numel(GAINS), K_REF);

presets = {'derivative', 'laggedMagno'};
MEASURES = {'mtOpp', 'mtOpp1', 'mtOpp6', 'mtMove', 'mtSpd1', 'mtSpd6', 'mtStatic', 'v1Max'};
S = struct();

for ip = 1:numel(presets)
    presetName = presets{ip};
    parsBase = localSetup(presetName, repoRoot);
    stimSz = shGetDims(parsBase, 'mtPattern', [1 1 31]);
    [iMove, iSpd1, iSpd6, iStatic] = localMtGroups(parsBase);
    [iPos1, iNeg1] = localShellPair(parsBase.mtPopulationVelocities, 1, STIM_DIR);
    [iPos6, iNeg6] = localShellPair(parsBase.mtPopulationVelocities, 6, STIM_DIR);

    fprintf('--- preset: %s   (stim %dx%dx%d, %d MT units: %d static, %d @1, %d @6)\n', ...
        presetName, stimSz(1), stimSz(2), stimSz(3), ...
        size(parsBase.mtPopulationVelocities,1), numel(iStatic), numel(iSpd1), numel(iSpd6));

    nS = numel(SPEEDS_PXF); nC = numel(COHERENCES); nG = numel(GAINS);
    R = struct();
    for m = 1:numel(MEASURES), R.(MEASURES{m}) = zeros(nS, nC, nG); end
    R.oppShell = zeros(nS, nC);   % which shell mtOpp read, in px/frame

    tAll = tic;
    for is = 1:nS
        for ic = 1:nC
            rng(DOT_SEED);            % identical dots across gains, per condition
            stim = mkDots(stimSz, STIM_DIR, SPEEDS_PXF(is), DOT_DENS, COHERENCES(ic));

            for ig = 1:nG
                pars = localLesion(parsBase, GAINS(ig), stimSz);

                [pop, ind] = shModel(stim, pars, 'mtPattern');
                rMT = mean(shGetNeuron(pop, ind), 2);
                R.mtMove(is,ic,ig)   = max(rMT(iMove));
                R.mtSpd1(is,ic,ig)   = max(rMT(iSpd1));
                R.mtSpd6(is,ic,ig)   = max(rMT(iSpd6));
                R.mtStatic(is,ic,ig) = max(rMT(iStatic));
                R.mtOpp1(is,ic,ig)   = rMT(iPos1) - rMT(iNeg1);
                R.mtOpp6(is,ic,ig)   = rMT(iPos6) - rMT(iNeg6);

                [pv, iv] = shModel(stim, pars, 'v1Complex');
                R.v1Max(is,ic,ig) = max(mean(shGetNeuron(pv, iv), 2));
            end

            % Pick the opponent shell UNLESIONED, then hold it across gains.
            if R.mtOpp1(is,ic,1) >= R.mtOpp6(is,ic,1)
                R.mtOpp(is,ic,:)  = R.mtOpp1(is,ic,:);
                R.oppShell(is,ic) = 1;
            else
                R.mtOpp(is,ic,:)  = R.mtOpp6(is,ic,:);
                R.oppShell(is,ic) = 6;
            end
        end
        fprintf('  speed %6.2f deg/s done (%d coherences)\n', SPEEDS_DEG(is), nC);
    end
    fprintf('  (%.1f s)\n\n', toc(tAll));

    S.(presetName) = R;
    localReport(presetName, R, SPEEDS_DEG, SPEEDS_PXF, COHERENCES, GAINS, MEASURES, K_REF);
    localCollapse(presetName, R, SPEEDS_PXF, COHERENCES, GAINS, K_REF);
end

%% Empirical check on the k^2 reference: V1 with normalization off
fprintf('--- reference check: V1 numerator exponent with normalization off\n');
try
    p0 = localSetup('derivative', repoRoot);
    p0.v1NormalizationType = 'off';
    stimSz = shGetDims(p0, 'v1Complex', [1 1 31]);
    rng(DOT_SEED);
    stim = mkDots(stimSz, STIM_DIR, 0.3125, DOT_DENS, 1);
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
     'S', 'SPEEDS_PXF', 'SPEEDS_DEG', 'COHERENCES', 'GAINS', 'K_REF');
fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.mat'));

localPlot(S, SPEEDS_DEG, COHERENCES, GAINS, K_REF, outDir);

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

% The unit tuned to stimDir and the unit tuned to stimDir + pi, both taken from
% ONE speed shell so the difference is direction opponency and not a speed
% confound. Matching within a shell is exact - the shell's directions are evenly
% spaced and include both 0 and pi - so this needs none of the Fourier-geometry
% machinery that localOpponentPair in showMotionLetterModel.m needs for matching
% ACROSS shells.
function [iPos, iNeg] = localShellPair(vels, shellSpeed, stimDir)
    shell = find(abs(vels(:,2) - shellSpeed) < 1e-6);
    if isempty(shell)
        error('localShellPair:noShell', 'No MT units at speed %g px/frame.', shellSpeed);
    end
    d = mod(vels(shell,1) - stimDir, 2*pi);
    [~, a] = min(min(d, 2*pi - d));         % closest to the stimulus direction
    [~, b] = min(abs(d - pi));              % closest to its opposite
    iPos = shell(a);
    iNeg = shell(b);
end

% Log-log slope of a measure over gains, and the compensation index derived from
% it. NaN when any value is non-positive: the opponent measure can be, at low
% coherence, and a fitted slope through a sign change would be meaningless.
function [slope, C] = localSlope(r, gains)
    r = r(:).';
    if any(~isfinite(r)) || any(r <= 0)
        slope = NaN; C = NaN; return;
    end
    b = polyfit(log(gains), log(r), 1);
    slope = b(1);
    C = 1 - slope/2;
end

function localReport(name, R, spdDeg, spdPxf, cohs, gains, measures, kRef)
    [~, iRef] = min(abs(gains - kRef));   % nearest, so editing GAINS cannot break this
    iLow = numel(gains);                  % harshest lesion on the list
    hRef = sprintf('R%.2g/R1', gains(iRef));
    hLow = sprintf('R%.2g/R1', gains(iLow));
    for f = 1:numel(measures)
        fld = measures{f};
        fprintf('  %s / %s\n', name, fld);
        for ic = 1:numel(cohs)
            fprintf('   coherence %.3g\n', cohs(ic));
            fprintf('    %8s %8s | %9s | %8s %8s | %6s %6s\n', ...
                    'deg/s', 'px/fr', 'R(k=1)', hRef, hLow, 'slope', 'C');
            for is = 1:numel(spdDeg)
                r = squeeze(R.(fld)(is, ic, :)).';
                [slope, C] = localSlope(r, gains);
                fprintf('    %8.2f %8.4f | %9.4g | %8.3f %8.3f | %6.2f %6.2f\n', ...
                        spdDeg(is), spdPxf(is), r(1), r(iRef)/r(1), r(iLow)/r(1), slope, C);
            end
        end
        fprintf('\n');
    end
end

% THE DISCRIMINATING TEST (NOISE_AND_DEMYELINATION.md 5.5).
%
% Deficit is log10 of the fraction of the unlesioned response retained at K_REF,
% so 0 is untouched and more negative is worse. Fit it against log10 unlesioned
% drive, then re-fit with log10 speed added, and report what the speed term buys.
%
%   speed term buys ~nothing   -> drive is the controlling variable; the
%                                 operating-point account wins outright
%   speed term buys a lot      -> at matched drive the deficit still depends on
%                                 speed, so something speed-specific - cell type -
%                                 is also at work
%
% Every point is one (speed, coherence) cell, and the coherence conditions are
% what make the two predictors separable at all: without them, drive and speed
% are one axis and no fit can tell them apart.
function localCollapse(name, R, spdPxf, cohs, gains, kRef)
    [~, iRef] = min(abs(gains - kRef));
    flds = {'mtOpp', 'mtMove', 'v1Max'};

    fprintf('  === %s: does drive alone explain the deficit? ===\n', name);
    for f = 1:numel(flds)
        fld = flds{f};
        drive = []; deficit = []; spd = []; coh = [];
        for is = 1:numel(spdPxf)
            for ic = 1:numel(cohs)
                d0 = R.(fld)(is, ic, 1);
                dk = R.(fld)(is, ic, iRef);
                if ~isfinite(d0) || ~isfinite(dk) || d0 <= 0 || dk <= 0
                    continue;   % excluded, and counted below
                end
                drive(end+1)   = d0;              %#ok<AGROW>
                deficit(end+1) = log10(dk / d0);  %#ok<AGROW>
                spd(end+1)     = spdPxf(is);      %#ok<AGROW>
                coh(end+1)     = cohs(ic);        %#ok<AGROW>
            end
        end

        nTot = numel(spdPxf) * numel(cohs);
        fprintf('   %s: %d of %d conditions usable\n', fld, numel(drive), nTot);
        if numel(drive) < 6
            fprintf('     too few to fit\n\n');
            continue;
        end

        x1 = log10(drive(:)); x2 = log10(spd(:)); y = deficit(:);
        [r2drive, res] = localFitR2([ones(size(x1)) x1], y);
        r2both         = localFitR2([ones(size(x1)) x1 x2], y);
        r2speed        = localFitR2([ones(size(x1)) x2], y);

        fprintf('     R^2, drive only            %.3f\n', r2drive);
        fprintf('     R^2, speed only            %.3f\n', r2speed);
        fprintf('     R^2, drive + speed         %.3f   (speed adds %.3f)\n', ...
                r2both, r2both - r2drive);

        % Residual dependence on speed after drive is accounted for. If the
        % conditions collapse onto one curve this is flat and small.
        bRes = [ones(size(x2)) x2] \ res;
        fprintf('     residual slope on log10 speed  %+.3f  (max |residual| %.3f log10 units)\n', ...
                bRes(2), max(abs(res)));

        % The crispest evidence there is: conditions matched in drive but reached
        % by different routes. Same drive, different speed -> same deficit?
        localMatchedPairs(drive, deficit, spd, coh);
        fprintf('\n');
    end
end

function [r2, res] = localFitR2(X, y)
    b   = X \ y;
    res = y - X*b;
    ssTot = sum((y - mean(y)).^2);
    if ssTot <= 0
        r2 = NaN;
    else
        r2 = 1 - sum(res.^2) / ssTot;
    end
end

% Pairs of conditions whose unlesioned drive agrees to within TOL_LOG10 but whose
% speeds differ by at least a factor of MIN_SPEED_RATIO. Under the
% operating-point account the two deficits should agree.
function localMatchedPairs(drive, deficit, spd, coh)
    TOL_LOG10 = 0.05;         % ~12% in drive
    MIN_SPEED_RATIO = 2;
    ld = log10(drive(:));
    n = numel(ld);
    rows = {};
    gaps = [];
    for i = 1:n
        for j = i+1:n
            if abs(ld(i) - ld(j)) > TOL_LOG10, continue; end
            ratio = max(spd(i), spd(j)) / min(spd(i), spd(j));
            if ratio < MIN_SPEED_RATIO, continue; end
            rows{end+1} = sprintf(...
                '       drive %8.4g | %5.3g px/fr coh %5.3g -> %+.3f | %5.3g px/fr coh %5.3g -> %+.3f | gap %.3f', ...
                drive(i), spd(i), coh(i), deficit(i), spd(j), coh(j), deficit(j), ...
                abs(deficit(i) - deficit(j)));  %#ok<AGROW>
            gaps(end+1) = abs(deficit(i) - deficit(j));  %#ok<AGROW>
        end
    end
    if isempty(rows)
        fprintf('     no drive-matched pairs at this tolerance\n');
        return;
    end
    fprintf('     drive-matched pairs, speeds >= %gx apart (deficit in log10 units):\n', ...
            MIN_SPEED_RATIO);
    for i = 1:min(numel(rows), 8)
        fprintf('%s\n', rows{i});
    end
    if numel(rows) > 8
        fprintf('       ... %d more\n', numel(rows) - 8);
    end
    fprintf('     median gap %.3f, worst %.3f log10 units over %d pairs\n', ...
            median(gaps), max(gaps), numel(gaps));
end

function localPlot(S, spdDeg, cohs, gains, kRef, outDir)
    presets = fieldnames(S);
    [~, iRef] = min(abs(gains - kRef));
    figure('Position', [60 60 1400 460*numel(presets)]);
    nCol = 4;

    for ip = 1:numel(presets)
        R = S.(presets{ip});
        row = (ip-1)*nCol;

        % 1. baseline drive against speed, one line per coherence
        subplot(numel(presets), nCol, row + 1);
        for ic = 1:numel(cohs)
            semilogx(spdDeg, R.mtOpp(:,ic,1), 'o-', 'LineWidth', 1.4); hold on;
        end
        semilogx(spdDeg, R.v1Max(:,1,1), 'k^--');
        xlabel('stimulus speed (deg/s)'); ylabel('unlesioned drive');
        title(sprintf('%s: MT opponent drive', presets{ip}), 'Interpreter', 'none');
        legend([arrayfun(@(c) sprintf('coh %.3g', c), cohs, 'UniformOutput', false), ...
                {'V1 (coh 1)'}], 'Location', 'northwest');
        grid on;

        % 2. compensation index against speed, one line per coherence
        subplot(numel(presets), nCol, row + 2);
        for ic = 1:numel(cohs)
            C = zeros(numel(spdDeg), 1);
            for is = 1:numel(spdDeg)
                [~, C(is)] = localSlope(squeeze(R.mtOpp(is,ic,:)), gains);
            end
            semilogx(spdDeg, C, 'o-', 'LineWidth', 1.4); hold on;
        end
        yline(0, 'k:'); yline(1, 'k:'); ylim([-0.1 1.1]);
        xlabel('stimulus speed (deg/s)'); ylabel('compensation index C');
        title('0 = no rescue, 1 = full');
        grid on;

        % 3. THE TEST: deficit against unlesioned drive, all conditions together
        subplot(numel(presets), nCol, row + 3);
        mk = {'o', 's', 'd', '^', 'v', 'p'};
        for ic = 1:numel(cohs)
            d0 = squeeze(R.mtOpp(:,ic,1));
            dk = squeeze(R.mtOpp(:,ic,iRef));
            ok = d0 > 0 & dk > 0;
            if ~any(ok), continue; end
            loglog(d0(ok), dk(ok) ./ d0(ok), [mk{min(ic,numel(mk))} '-'], ...
                   'LineWidth', 1.2, 'MarkerSize', 7); hold on;
        end
        yline(1, 'k:');
        xlabel('unlesioned drive'); ylabel(sprintf('fraction retained at k = %.2g', kRef));
        title('collapse onto one curve = drive controls');
        legend(arrayfun(@(c) sprintf('coh %.3g', c), cohs, 'UniformOutput', false), ...
               'Location', 'southeast');
        grid on;

        % 4. the same deficit against speed, for contrast. If panel 3 collapses
        %    and this one does not, speed was never the controlling variable.
        subplot(numel(presets), nCol, row + 4);
        for ic = 1:numel(cohs)
            d0 = squeeze(R.mtOpp(:,ic,1));
            dk = squeeze(R.mtOpp(:,ic,iRef));
            ok = d0 > 0 & dk > 0;
            if ~any(ok), continue; end
            semilogx(spdDeg(ok), dk(ok) ./ d0(ok), [mk{min(ic,numel(mk))} '-'], ...
                     'LineWidth', 1.2, 'MarkerSize', 7); hold on;
        end
        yline(1, 'k:');
        xlabel('stimulus speed (deg/s)'); ylabel(sprintf('fraction retained at k = %.2g', kRef));
        title('the same points against speed');
        grid on;
    end
    saveas(gcf, fullfile(outDir, 'compensationIndex.png'));
    fprintf('Saved %s\n', fullfile(outDir, 'compensationIndex.png'));
end
