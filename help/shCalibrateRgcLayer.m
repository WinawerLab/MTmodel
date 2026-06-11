% report = shCalibrateRgcLayer(maxIter)
%
% First-pass calibration protocol for the optional RGC layer.
% The goal is to fit healthy RGC parameters so V1 and MT responses remain
% close to the legacy model (RGC disabled).
%
% Required arguments:
% none
%
% Optional arguments:
% maxIter  maximum number of fminsearch iterations (default = 60)
%
% Output:
% report   struct containing fitted parameters and fit quality metrics.

function report = shCalibrateRgcLayer(maxIter)

    if nargin < 1
        maxIter = 60;
    end

    rng(1);

    % Baseline model (legacy path).
    parsBase = shPars;
    parsBase.rgc.enabled = 0;

    % Candidate model (RGC enabled).
    parsRgc = shPars;
    parsRgc.rgc.enabled = 1;
    parsRgc.rgc.impairmentEnabled = 0;

    stimSet = localBuildStimulusSet(parsBase);
    baseVec = localCollectResponseVector(stimSet, parsBase);

    % Initial guess maps close to identity behavior.
    x0 = [log(0.8); log(1.2); -8; -8; 0];
    opts = optimset('Display', 'iter', 'MaxIter', maxIter, 'TolX', 1e-3, 'TolFun', 1e-4);

    objFun = @(x) localObjective(x, parsRgc, stimSet, baseVec);
    [xBest, fBest] = fminsearch(objFun, x0, opts);

    parsFit = localAssignRgcPars(parsRgc, xBest);
    fitVec = localCollectResponseVector(stimSet, parsFit);

    beforePars = localAssignRgcPars(parsRgc, x0);
    beforeVec = localCollectResponseVector(stimSet, beforePars);

    report = struct;
    report.bestObjective = fBest;
    report.beforeCorrelation = localSafeCorr(baseVec, beforeVec);
    report.afterCorrelation = localSafeCorr(baseVec, fitVec);
    report.beforeNRMSE = localNrmse(baseVec, beforeVec);
    report.afterNRMSE = localNrmse(baseVec, fitVec);
    report.bestRgcPars = parsFit.rgc;

    fprintf('\nRGC calibration summary\n');
    fprintf('  correlation before: %.4f\n', report.beforeCorrelation);
    fprintf('  correlation after : %.4f\n', report.afterCorrelation);
    fprintf('  nrmse before      : %.4f\n', report.beforeNRMSE);
    fprintf('  nrmse after       : %.4f\n', report.afterNRMSE);
    fprintf('  best objective    : %.4f\n\n', report.bestObjective);

end

function stimSet = localBuildStimulusSet(pars)

    dims = shGetDims(pars, 'mtPattern', [1 1 18]);

    % Dot motion examples.
    stimSet{1} = mkDots(dims, 0, 1.0, 0.12, 1);
    stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);

    % Drifting gratings with different motion directions/speeds.
    g1 = v12sin([0, 1.0]);
    g2 = v12sin([pi/3, 1.6]);
    stimSet{3} = mkSin(dims, 0, g1(2), g1(3), 1);
    stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);

end

function vec = localCollectResponseVector(stimSet, pars)

    vec = [];
    for i = 1:length(stimSet)
        s = stimSet{i};

        [v1Pop, v1Ind] = shModel(s, pars, 'v1Complex');
        [mtPop, mtInd] = shModel(s, pars, 'mtPattern');

        v1Center = shGetNeuron(v1Pop, v1Ind);
        mtCenter = shGetNeuron(mtPop, mtInd);

        % Summary features retain both tuning and temporal structure.
        v1Feat = [mean(v1Center, 2); std(v1Center, 0, 2); mean(v1Center, 1)'];
        mtFeat = [mean(mtCenter, 2); std(mtCenter, 0, 2); mean(mtCenter, 1)'];

        vec = [vec; v1Feat; mtFeat];
    end

end

function loss = localObjective(x, parsTemplate, stimSet, baseVec)

    pars = localAssignRgcPars(parsTemplate, x);
    fitVec = localCollectResponseVector(stimSet, pars);

    corrTerm = 1 - localSafeCorr(baseVec, fitVec);
    errTerm = localNrmse(baseVec, fitVec);

    loss = corrTerm + errTerm;

end

function pars = localAssignRgcPars(pars, x)

    pars.rgc.centerSigma = exp(x(1));
    pars.rgc.surroundSigma = pars.rgc.centerSigma + exp(x(2));
    pars.rgc.surroundWeight = 0.5 ./ (1 + exp(-x(3)));
    pars.rgc.temporalSigma = max(0, exp(x(4)) - 1);
    pars.rgc.gain = exp(x(5));

end

function c = localSafeCorr(a, b)

    if std(a) == 0 || std(b) == 0
        c = 0;
        return;
    end

    r = corrcoef(a, b);
    c = r(1, 2);

end

function e = localNrmse(a, b)

    d = a - b;
    den = max(norm(a), eps);
    e = norm(d) ./ den;

end
