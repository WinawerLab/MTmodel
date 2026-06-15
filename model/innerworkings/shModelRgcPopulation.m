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

    spatialPars = localGetSpatialPars(rgcPars);
    temporalPars = localGetTemporalPars(rgcPars, speed);

    signSplit = 'local';
    if isfield(rgcPars, 'onOffSignSplit')
        signSplit = rgcPars.onOffSignSplit;
    end

    switch lower(signSplit)
        case 'local'
            movie = localFilterSignSplitPopulation(stimulus, spatialPars, polarity, rgcPars);
        case 'bipolar'
            movie = localFilterBipolarPopulation(stimulus, spatialPars, polarity, rgcPars);
        otherwise
            error('pars.rgc.onOffSignSplit must be ''local'' or ''bipolar''.');
    end

    movie = localApplyTemporalFilter(movie, temporalPars.temporalSigma);

    if isfield(rgcPars, 'gain')
        movie = movie .* rgcPars.gain;
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

function spatialPars = localGetSpatialPars(rgcPars)

    spatialPars = struct;
    spatialPars.centerSigma = 0.8;
    spatialPars.surroundSigma = 2.0;
    spatialPars.surroundWeight = 0.25;

    if isfield(rgcPars, 'spatial')
        if isfield(rgcPars.spatial, 'centerSigma')
            spatialPars.centerSigma = rgcPars.spatial.centerSigma;
        end
        if isfield(rgcPars.spatial, 'surroundSigma')
            spatialPars.surroundSigma = rgcPars.spatial.surroundSigma;
        end
        if isfield(rgcPars.spatial, 'surroundWeight')
            spatialPars.surroundWeight = rgcPars.spatial.surroundWeight;
        end
    else
        if isfield(rgcPars, 'centerSigma')
            spatialPars.centerSigma = rgcPars.centerSigma;
        end
        if isfield(rgcPars, 'surroundSigma')
            spatialPars.surroundSigma = rgcPars.surroundSigma;
        end
        if isfield(rgcPars, 'surroundWeight')
            spatialPars.surroundWeight = rgcPars.surroundWeight;
        end
    end

    if spatialPars.surroundSigma <= spatialPars.centerSigma
        spatialPars.surroundSigma = spatialPars.centerSigma + 0.5;
    end

end

function temporalPars = localGetTemporalPars(rgcPars, speed)

    temporalPars = struct;
    temporalPars.temporalSigma = 0;

    if isfield(rgcPars, 'temporal')
        if strcmpi(speed, 'fast') && isfield(rgcPars.temporal, 'fastSigma')
            temporalPars.temporalSigma = rgcPars.temporal.fastSigma;
        elseif strcmpi(speed, 'slow') && isfield(rgcPars.temporal, 'slowSigma')
            temporalPars.temporalSigma = rgcPars.temporal.slowSigma;
        end
    end

    if temporalPars.temporalSigma == 0
        if strcmpi(speed, 'fast') && isfield(rgcPars, 'temporalSigma')
            temporalPars.temporalSigma = rgcPars.temporalSigma;
        end
    end

end

function out = localApplyTemporalFilter(in, temporalSigma)

    out = in;
    if temporalSigma <= 0
        return;
    end

    tf = mkGaussianFilter(temporalSigma);
    out = convn(out, reshape(tf, [1 1 length(tf)]), 'same');

end

function out = localSeparableSpatialSame(in, filt)
    out = convn(in, reshape(filt, [length(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 length(filt) 1]), 'same');
end
