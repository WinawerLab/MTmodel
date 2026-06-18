% movie = shModelRgcPopulation(stimulus, rgcPars, polarity, speed)
%
% Compute one RGC population movie from a luminance stimulus.
%
% Required arguments:
% stimulus   3D movie [Y X T]
% rgcPars    RGC parameter struct (from pars.rgc)
% polarity   'on' or 'off'
% speed      'fast' or 'slow'
%
% Output:
% movie      filtered population response [Y X T]

function movie = shModelRgcPopulation(stimulus, rgcPars, polarity, speed)

    spatialPars = localGetSpatialPars(rgcPars, speed, polarity);
    temporalPars = localGetTemporalPars(rgcPars, speed);

    signSplit = 'contrast';
    if isfield(rgcPars, 'onOffSignSplit')
        signSplit = rgcPars.onOffSignSplit;
    end

    switch lower(signSplit)
        case 'contrast'
            movie = localFilterContrastSplitPopulation(stimulus, spatialPars, polarity, rgcPars);
        case 'local'
            movie = localFilterSignSplitPopulation(stimulus, spatialPars, polarity, rgcPars);
        case 'bipolar'
            movie = localFilterBipolarPopulation(stimulus, spatialPars, polarity, rgcPars);
        otherwise
            error('pars.rgc.onOffSignSplit must be ''contrast'', ''local'', or ''bipolar''.');
    end

    movie = localApplyTemporalFilter(movie, temporalPars);

    if isfield(rgcPars, 'gain')
        movie = movie .* rgcPars.gain;
    end

end

function movie = localFilterContrastSplitPopulation(stimulus, spatialPars, polarity, rgcPars)

    frameMean = mean(mean(stimulus, 1), 2);
    contrastMovie = stimulus - repmat(frameMean, [size(stimulus, 1), size(stimulus, 2), 1]);

    % Apply the DoG to the full signed contrast image, then rectify.
    % ON takes the positive part (bright center); OFF takes the negative part
    % (dark center). Rectification here matches localFilterBipolarPopulation
    % but operates on mean-subtracted contrast rather than raw luminance.
    csResponse = localCenterSurroundDifference(contrastMovie, spatialPars);

    switch lower(polarity)
        case 'on'
            movie = max(0, csResponse);
        case 'off'
            offScale = 1;
            if isfield(rgcPars, 'onOffSymmetry')
                offScale = rgcPars.onOffSymmetry;
            end
            movie = max(0, -offScale .* csResponse);
        otherwise
            error('polarity must be ''on'' or ''off''.');
    end

end

function movie = localFilterSignSplitPopulation(stimulus, spatialPars, polarity, rgcPars)

    localMean = localSeparableSpatialSame(stimulus, mkGaussianFilter(spatialPars.surroundSigma));

    switch lower(polarity)
        case 'on'
            drive = max(0, stimulus - localMean);
        case 'off'
            offScale = 1;
            if isfield(rgcPars, 'onOffSymmetry')
                offScale = rgcPars.onOffSymmetry;
            end
            drive = offScale .* max(0, localMean - stimulus);
        otherwise
            error('polarity must be ''on'' or ''off''.');
    end

    movie = localApplyCenterSurround(drive, spatialPars);

end

function movie = localFilterBipolarPopulation(stimulus, spatialPars, polarity, rgcPars)

    centerSurround = localCenterSurroundDifference(stimulus, spatialPars);

    switch lower(polarity)
        case 'on'
            movie = max(0, centerSurround);
        case 'off'
            offScale = 1;
            if isfield(rgcPars, 'onOffSymmetry')
                offScale = rgcPars.onOffSymmetry;
            end
            movie = offScale .* max(0, -centerSurround);
        otherwise
            error('polarity must be ''on'' or ''off''.');
    end

end

function out = localApplyCenterSurround(in, spatialPars)

    out = max(0, localCenterSurroundDifference(in, spatialPars));

end

function out = localCenterSurroundDifference(in, spatialPars)

    center = mkGaussianFilter(spatialPars.centerSigma);
    surround = mkGaussianFilter(spatialPars.surroundSigma);

    outCenter = localSeparableSpatialSame(in, center);
    outSurround = localSeparableSpatialSame(in, surround);
    out = outCenter - spatialPars.surroundWeight .* outSurround;

end

function spatialPars = localGetSpatialPars(rgcPars, speed, polarity)

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

    % Scale RFs by channel type. fastRfScale makes fast (M-cell) channels
    % larger than slow (P-cell) channels; onRfScale makes ON channels larger
    % than OFF channels. Both center and surround scale together to preserve
    % the center-surround ratio.
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

function temporalPars = localGetTemporalPars(rgcPars, speed)

    temporalPars = struct;
    temporalPars.temporalSigma = 0;
    temporalPars.mode = 'causal';
    temporalPars.tau1 = 0;
    temporalPars.tau2 = 0;
    temporalPars.weight = 0;
    temporalPars.power = 2;
    temporalPars.length = [];

    if isfield(rgcPars, 'temporal')
        if isfield(rgcPars.temporal, 'mode')
            temporalPars.mode = rgcPars.temporal.mode;
        end
        if strcmpi(speed, 'fast') && isfield(rgcPars.temporal, 'fastSigma')
            temporalPars.temporalSigma = rgcPars.temporal.fastSigma;
        elseif strcmpi(speed, 'slow') && isfield(rgcPars.temporal, 'slowSigma')
            temporalPars.temporalSigma = rgcPars.temporal.slowSigma;
        end
        if strcmpi(speed, 'fast')
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'fastTau1', 'tau1');
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'fastTau2', 'tau2');
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'fastWeight', 'weight');
        elseif strcmpi(speed, 'slow')
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'slowTau1', 'tau1');
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'slowTau2', 'tau2');
            temporalPars = localCopyTemporalField(rgcPars.temporal, temporalPars, 'slowWeight', 'weight');
        end
        if isfield(rgcPars.temporal, 'power')
            temporalPars.power = rgcPars.temporal.power;
        end
        if isfield(rgcPars.temporal, 'kernelLength')
            temporalPars.length = rgcPars.temporal.kernelLength;
        end
    end

end

function temporalPars = localCopyTemporalField(src, temporalPars, srcField, dstField)

    if isfield(src, srcField)
        temporalPars.(dstField) = src.(srcField);
    end

end

function out = localApplyTemporalFilter(in, temporalPars)

    out = in;

    if strcmpi(temporalPars.mode, 'gaussian')
        if temporalPars.temporalSigma <= 0
            return;
        end

        tf = mkGaussianFilter(temporalPars.temporalSigma);
        out = convn(out, reshape(tf, [1 1 length(tf)]), 'same');
        return;
    end

    tf = localCausalTemporalKernel(temporalPars);
    if length(tf) <= 1
        return;
    end

    fullOut = convn(in, reshape(tf, [1 1 length(tf)]), 'full');
    out = fullOut(:, :, 1:size(in, 3));

end

function tf = localCausalTemporalKernel(temporalPars)

    tau1 = temporalPars.tau1;
    tau2 = temporalPars.tau2;
    weight = temporalPars.weight;

    if tau1 <= 0
        tau1 = max(0.25, temporalPars.temporalSigma);
    end
    if tau2 <= tau1
        tau2 = max(tau1 + 0.25, 2 * tau1);
    end
    if weight <= 0
        weight = 0.45;
    end

    if isempty(temporalPars.length)
        kernelLength = max(3, ceil(8 * tau2) + 1);
    else
        kernelLength = temporalPars.length;
    end

    t = 0:(kernelLength - 1);
    n = temporalPars.power;
    tf = (t ./ tau1) .^ n .* exp(-t ./ tau1) - ...
        weight .* (t ./ tau2) .^ n .* exp(-t ./ tau2);

    peak = max(abs(tf));
    if peak > 0
        tf = tf ./ peak;
    end

end

function out = localSeparableSpatialSame(in, filt)
    out = convn(in, reshape(filt, [length(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 length(filt) 1]), 'same');
end
