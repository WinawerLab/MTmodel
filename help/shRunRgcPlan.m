% runbook = shRunRgcPlan(maxIter, ampLevels, delayLevels, savePath)
%
% End-to-end runbook for the RGC front-end project.
% This function runs calibration, computes healthy-vs-legacy regression
% metrics, and performs simple optic neuritis impairment sweeps.
%
% Optional arguments:
% maxIter      fminsearch iterations for shCalibrateRgcLayer (default = 80)
% ampLevels    vector of attenuation fractions in [0,1] (default = [0.1 0.3 0.5])
% delayLevels  vector of integer frame delays (default = [1 2 3])
% savePath     optional .mat output path for report struct (default = '')
%
% Output:
% runbook      struct containing calibration, regression, and sweep results

function runbook = shRunRgcPlan(maxIter, ampLevels, delayLevels, savePath)

    if nargin < 1 || isempty(maxIter)
        maxIter = 80;
    end
    if nargin < 2 || isempty(ampLevels)
        ampLevels = [0.1 0.3 0.5];
    end
    if nargin < 3 || isempty(delayLevels)
        delayLevels = [1 2 3];
    end
    if nargin < 4
        savePath = '';
    end

    rng(1);

    fprintf('\n=== RGC Runbook: Calibration ===\n');
    calibration = shCalibrateRgcLayer(maxIter);

    parsBase = shPars;
    parsBase.rgc.enabled = 0;

    parsHealthy = shPars;
    parsHealthy.rgc.enabled = 1;
    parsHealthy.rgc.impairmentEnabled = 0;
    parsHealthy.rgc = localMergeRgcPars(parsHealthy.rgc, calibration.bestRgcPars);

    stimSet = localBuildStimulusSet(parsBase);
    healthyRegression = localEvaluatePair(stimSet, parsBase, parsHealthy);

    fprintf('=== RGC Runbook: Healthy-vs-Legacy ===\n');
    localPrintMetrics('healthy', healthyRegression);

    ampSweep = localRunAmplitudeSweep(stimSet, parsHealthy, ampLevels);
    delaySweep = localRunDelaySweep(stimSet, parsHealthy, delayLevels);
    combinedSweep = localRunCombinedSweep(stimSet, parsHealthy, ampLevels, delayLevels);

    runbook = struct;
    runbook.timestamp = datestr(now, 30);
    runbook.maxIter = maxIter;
    runbook.calibration = calibration;
    runbook.healthyRegression = healthyRegression;
    runbook.ampSweep = ampSweep;
    runbook.delaySweep = delaySweep;
    runbook.combinedSweep = combinedSweep;

    if ~isempty(savePath)
        save(savePath, 'runbook');
        fprintf('Saved runbook report to %s\n', savePath);
    end

    fprintf('=== RGC Runbook: Completed ===\n\n');

end

function stimSet = localBuildStimulusSet(pars)

    dims = shGetDims(pars, 'mtPattern', [1 1 18]);

    stimSet = cell(1, 4);
    stimSet{1} = mkDots(dims, 0, 1.0, 0.12, 1.0);
    stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);

    g1 = v12sin([0, 1.0]);
    g2 = v12sin([pi/3, 1.6]);
    stimSet{3} = mkSin(dims, 0, g1(2), g1(3), 1);
    stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);

end

function metrics = localEvaluatePair(stimSet, parsRef, parsCmp)

    v1RefVec = [];
    mtRefVec = [];
    v1CmpVec = [];
    mtCmpVec = [];

    for i = 1:length(stimSet)
        s = stimSet{i};

        [v1RefPop, v1RefInd] = shModel(s, parsRef, 'v1Complex');
        [mtRefPop, mtRefInd] = shModel(s, parsRef, 'mtPattern');

        [v1CmpPop, v1CmpInd] = shModel(s, parsCmp, 'v1Complex');
        [mtCmpPop, mtCmpInd] = shModel(s, parsCmp, 'mtPattern');

        v1Ref = shGetNeuron(v1RefPop, v1RefInd);
        mtRef = shGetNeuron(mtRefPop, mtRefInd);

        v1Cmp = shGetNeuron(v1CmpPop, v1CmpInd);
        mtCmp = shGetNeuron(mtCmpPop, mtCmpInd);

        v1RefVec = [v1RefVec; localFeatureVector(v1Ref)];
        mtRefVec = [mtRefVec; localFeatureVector(mtRef)];

        v1CmpVec = [v1CmpVec; localFeatureVector(v1Cmp)];
        mtCmpVec = [mtCmpVec; localFeatureVector(mtCmp)];
    end

    metrics = struct;
    metrics.v1Corr = localSafeCorr(v1RefVec, v1CmpVec);
    metrics.v1NRMSE = localNrmse(v1RefVec, v1CmpVec);
    metrics.v1GainRatio = localSafeGain(v1RefVec, v1CmpVec);

    metrics.mtCorr = localSafeCorr(mtRefVec, mtCmpVec);
    metrics.mtNRMSE = localNrmse(mtRefVec, mtCmpVec);
    metrics.mtGainRatio = localSafeGain(mtRefVec, mtCmpVec);

end

function f = localFeatureVector(resp)

    f = [mean(resp, 2); std(resp, 0, 2); mean(resp, 1)'];

end

function ampSweep = localRunAmplitudeSweep(stimSet, parsHealthy, ampLevels)

    fprintf('=== RGC Runbook: Amplitude Sweep ===\n');

    ampSweep = repmat(struct('attenuation', 0, 'metrics', []), length(ampLevels), 1);
    for i = 1:length(ampLevels)
        attenuation = ampLevels(i);

        pars = parsHealthy;
        pars.rgc.impairmentEnabled = 1;
        pars.rgc.impairmentAmplitudeMap = (1 - attenuation) .* ones(localFrameSize(stimSet));
        pars.rgc.impairmentDelayMap = zeros(localFrameSize(stimSet));

        m = localEvaluatePair(stimSet, parsHealthy, pars);
        ampSweep(i).attenuation = attenuation;
        ampSweep(i).metrics = m;

        localPrintMetrics(sprintf('amp=%.2f', attenuation), m);
    end

end

function delaySweep = localRunDelaySweep(stimSet, parsHealthy, delayLevels)

    fprintf('=== RGC Runbook: Delay Sweep ===\n');

    delaySweep = repmat(struct('delayFrames', 0, 'metrics', []), length(delayLevels), 1);
    for i = 1:length(delayLevels)
        delayFrames = round(delayLevels(i));

        pars = parsHealthy;
        pars.rgc.impairmentEnabled = 1;
        pars.rgc.impairmentAmplitudeMap = ones(localFrameSize(stimSet));
        pars.rgc.impairmentDelayMap = delayFrames .* ones(localFrameSize(stimSet));

        m = localEvaluatePair(stimSet, parsHealthy, pars);
        delaySweep(i).delayFrames = delayFrames;
        delaySweep(i).metrics = m;

        localPrintMetrics(sprintf('delay=%d', delayFrames), m);
    end

end

function combinedSweep = localRunCombinedSweep(stimSet, parsHealthy, ampLevels, delayLevels)

    fprintf('=== RGC Runbook: Combined Sweep ===\n');

    n = min(length(ampLevels), length(delayLevels));
    combinedSweep = repmat(struct('attenuation', 0, 'delayFrames', 0, 'metrics', []), n, 1);
    for i = 1:n
        attenuation = ampLevels(i);
        delayFrames = round(delayLevels(i));

        pars = parsHealthy;
        pars.rgc.impairmentEnabled = 1;
        pars.rgc.impairmentAmplitudeMap = (1 - attenuation) .* ones(localFrameSize(stimSet));
        pars.rgc.impairmentDelayMap = delayFrames .* ones(localFrameSize(stimSet));

        m = localEvaluatePair(stimSet, parsHealthy, pars);
        combinedSweep(i).attenuation = attenuation;
        combinedSweep(i).delayFrames = delayFrames;
        combinedSweep(i).metrics = m;

        localPrintMetrics(sprintf('combined amp=%.2f delay=%d', attenuation, delayFrames), m);
    end

end

function sz = localFrameSize(stimSet)

    s = stimSet{1};
    sz = [size(s, 1), size(s, 2)];

end

function rgcOut = localMergeRgcPars(rgcBase, rgcBest)

    rgcOut = rgcBase;
    fields = fieldnames(rgcBest);
    for i = 1:length(fields)
        rgcOut.(fields{i}) = rgcBest.(fields{i});
    end

end

function localPrintMetrics(label, m)

    fprintf('  %s | V1 corr %.4f nrmse %.4f gain %.4f | MT corr %.4f nrmse %.4f gain %.4f\n', ...
        label, m.v1Corr, m.v1NRMSE, m.v1GainRatio, m.mtCorr, m.mtNRMSE, m.mtGainRatio);

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

function g = localSafeGain(a, b)

    na = norm(a);
    if na == 0
        g = 0;
    else
        g = norm(b) ./ na;
    end

end
