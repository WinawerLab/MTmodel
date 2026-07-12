% classes = shRgcClassesFourPop(pars)
%
% Biological RGC-class preset that reproduces the legacy 'fourPop' path
% (shModelRgc / shModelRgcPopulation) exactly on the unified class-based
% front-end: ON/OFF x fast/slow (4 classes; +4 lag classes if
% pars.rgc.temporal.fastLag/slowLag > 0). Each class has a center-surround
% (DoG) spatial RF and a causal difference-of-gamma temporal kernel, built
% from pars.rgc.spatial / pars.rgc.temporal exactly as shModelRgcPopulation
% would (same defaulting rules), so that shClassV1Basis(shRgcClassesFourPop(pars), ...)
% reproduces shModelRgc(..., pars) with pars.rgc.mode = 'fourPop' to
% machine precision (see tests/testClassPathFourPop.m).
%
% Only pars.rgc.onOffSignSplit = 'contrast' and pars.rgc.temporal.mode =
% 'causal' are supported (the only settings exercised elsewhere in the
% codebase); other settings error rather than silently diverge.
%
% Each class feeds all V1 spatial-derivative read-out orders (0..3 -> 10
% combos) with no ON/OFF readout offset, matching legacy fourPop. Use
% pars.rgc.combine = 'weights' (fitted; see shFitClassV1Weights).

function classes = shRgcClassesFourPop(pars)

    rgcPars = pars.rgc;

    signSplit = 'contrast';
    if isfield(rgcPars, 'onOffSignSplit'), signSplit = rgcPars.onOffSignSplit; end
    if ~strcmpi(signSplit, 'contrast')
        error('shRgcClassesFourPop:signSplit', ...
              'shRgcClassesFourPop only supports pars.rgc.onOffSignSplit = ''contrast''.');
    end
    if isfield(rgcPars, 'temporal') && isfield(rgcPars.temporal, 'mode') ...
            && ~strcmpi(rgcPars.temporal.mode, 'causal')
        error('shRgcClassesFourPop:temporalMode', ...
              'shRgcClassesFourPop only supports pars.rgc.temporal.mode = ''causal''.');
    end

    onFastRF  = localSpatialPars(rgcPars, 'fast', 'on');
    offFastRF = localSpatialPars(rgcPars, 'fast', 'off');
    onSlowRF  = localSpatialPars(rgcPars, 'slow', 'on');
    offSlowRF = localSpatialPars(rgcPars, 'slow', 'off');

    fastK = localTemporalKernel(rgcPars, 'fast');
    slowK = localTemporalKernel(rgcPars, 'slow');

    gain = 1;
    if isfield(rgcPars, 'gain'), gain = rgcPars.gain; end
    offScale = 1;
    if isfield(rgcPars, 'onOffSymmetry'), offScale = rgcPars.onOffSymmetry; end

    classes = [ ...
        shRgcClass('onFast',  fastK, 'spatialRF', onFastRF,  'rectify', 'onHalf',  'gain', gain), ...
        shRgcClass('offFast', fastK, 'spatialRF', offFastRF, 'rectify', 'offHalf', 'gain', gain * offScale), ...
        shRgcClass('onSlow',  slowK, 'spatialRF', onSlowRF,  'rectify', 'onHalf',  'gain', gain), ...
        shRgcClass('offSlow', slowK, 'spatialRF', offSlowRF, 'rectify', 'offHalf', 'gain', gain * offScale) ];

    % Lagged copies of fast/slow channels: a D-frame post-hoc delay of a
    % causally-filtered channel equals convolving with the same kernel
    % preceded by D zero taps, so a lag channel is just another class.
    fastLag = 0;
    slowLag = 0;
    if isfield(rgcPars, 'temporal')
        if isfield(rgcPars.temporal, 'fastLag'), fastLag = rgcPars.temporal.fastLag; end
        if isfield(rgcPars.temporal, 'slowLag'), slowLag = rgcPars.temporal.slowLag; end
    end

    if fastLag > 0
        fastKLag = [zeros(fastLag, 1); fastK(:)];
        classes = [classes, ...
            shRgcClass('onFastLag',  fastKLag, 'spatialRF', onFastRF,  'rectify', 'onHalf',  'gain', gain), ...
            shRgcClass('offFastLag', fastKLag, 'spatialRF', offFastRF, 'rectify', 'offHalf', 'gain', gain * offScale)];
    end
    if slowLag > 0
        slowKLag = [zeros(slowLag, 1); slowK(:)];
        classes = [classes, ...
            shRgcClass('onSlowLag',  slowKLag, 'spatialRF', onSlowRF,  'rectify', 'onHalf',  'gain', gain), ...
            shRgcClass('offSlowLag', slowKLag, 'spatialRF', offSlowRF, 'rectify', 'offHalf', 'gain', gain * offScale)];
    end

end

% =====================================================================
function spatialPars = localSpatialPars(rgcPars, speed, polarity)
% Mirrors shModelRgcPopulation's localGetSpatialPars exactly.

    spatialPars = struct;
    spatialPars.centerSigma = 0.8;
    spatialPars.surroundSigma = 2.0;
    spatialPars.surroundWeight = 0.25;

    if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'centerSigma')
        spatialPars.centerSigma = rgcPars.spatial.centerSigma;
    end
    if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'surroundSigma')
        spatialPars.surroundSigma = rgcPars.spatial.surroundSigma;
    end
    if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'surroundWeight')
        spatialPars.surroundWeight = rgcPars.spatial.surroundWeight;
    end

    rfScale = 1.0;
    if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'fastRfScale')
        if strcmpi(speed, 'fast')
            rfScale = rfScale * rgcPars.spatial.fastRfScale;
        end
    end
    if isfield(rgcPars, 'spatial') && isfield(rgcPars.spatial, 'onRfScale')
        if strcmpi(polarity, 'on')
            rfScale = rfScale * rgcPars.spatial.onRfScale;
        end
    end
    spatialPars.centerSigma = spatialPars.centerSigma * rfScale;
    spatialPars.surroundSigma = spatialPars.surroundSigma * rfScale;

    if spatialPars.surroundSigma <= spatialPars.centerSigma
        spatialPars.surroundSigma = spatialPars.centerSigma + 0.5;
    end

end

function tf = localTemporalKernel(rgcPars, speed)
% Mirrors shModelRgcPopulation's localGetTemporalPars + localCausalTemporalKernel
% exactly (defaulting rules included).

    temporalSigma = 0;
    tau1 = 0;
    tau2 = 0;
    weight = 0;
    power = 2;
    kernelLength = [];

    if isfield(rgcPars, 'temporal')
        if strcmpi(speed, 'fast') && isfield(rgcPars.temporal, 'fastSigma')
            temporalSigma = rgcPars.temporal.fastSigma;
        elseif strcmpi(speed, 'slow') && isfield(rgcPars.temporal, 'slowSigma')
            temporalSigma = rgcPars.temporal.slowSigma;
        end
        if strcmpi(speed, 'fast')
            if isfield(rgcPars.temporal, 'fastTau1'), tau1 = rgcPars.temporal.fastTau1; end
            if isfield(rgcPars.temporal, 'fastTau2'), tau2 = rgcPars.temporal.fastTau2; end
            if isfield(rgcPars.temporal, 'fastWeight'), weight = rgcPars.temporal.fastWeight; end
        elseif strcmpi(speed, 'slow')
            if isfield(rgcPars.temporal, 'slowTau1'), tau1 = rgcPars.temporal.slowTau1; end
            if isfield(rgcPars.temporal, 'slowTau2'), tau2 = rgcPars.temporal.slowTau2; end
            if isfield(rgcPars.temporal, 'slowWeight'), weight = rgcPars.temporal.slowWeight; end
        end
        if isfield(rgcPars.temporal, 'power'), power = rgcPars.temporal.power; end
        if isfield(rgcPars.temporal, 'kernelLength'), kernelLength = rgcPars.temporal.kernelLength; end
    end

    if tau1 <= 0
        tau1 = max(0.25, temporalSigma);
    end
    if tau2 <= tau1
        tau2 = max(tau1 + 0.25, 2 * tau1);
    end
    if weight <= 0
        weight = 0.45;
    end

    if isempty(kernelLength)
        kernelLength = max(3, ceil(8 * tau2) + 1);
    end

    t = 0:(kernelLength - 1);
    tf = (t ./ tau1) .^ power .* exp(-t ./ tau1) - ...
        weight .* (t ./ tau2) .^ power .* exp(-t ./ tau2);

    peak = max(abs(tf));
    if peak > 0
        tf = tf ./ peak;
    end
    tf = tf(:);

end
