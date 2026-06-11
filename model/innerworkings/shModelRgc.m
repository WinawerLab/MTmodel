% rgcStimulus = shModelRgc(stimulus, pars)
%
% Optional retinal ganglion cell (RGC) preprocessing layer. This is a
% conservative first-pass implementation intended to preserve legacy model
% behavior when disabled.
%
% Required arguments:
% stimulus  3D movie [Y X T]
% pars      model parameters structure from shPars
%
% Output:
% rgcStimulus  filtered and optionally impaired RGC movie [Y X T]

function rgcStimulus = shModelRgc(stimulus, pars)

    rgcStimulus = stimulus;

    if ~isfield(pars, 'rgc')
        return;
    end

    if ~isfield(pars.rgc, 'enabled') || pars.rgc.enabled == 0
        return;
    end

    rgcStimulus = localApplySpatialFilter(rgcStimulus, pars.rgc);
    rgcStimulus = localApplyTemporalFilter(rgcStimulus, pars.rgc);

    if isfield(pars.rgc, 'gain')
        rgcStimulus = rgcStimulus .* pars.rgc.gain;
    end

    if isfield(pars.rgc, 'impairmentEnabled') && pars.rgc.impairmentEnabled == 1
        rgcStimulus = localApplyImpairment(rgcStimulus, pars.rgc);
    end

end

function out = localApplySpatialFilter(in, rgcPars)
    if ~isfield(rgcPars, 'centerSigma')
        rgcPars.centerSigma = 0.8;
    end
    if ~isfield(rgcPars, 'surroundSigma')
        rgcPars.surroundSigma = 2.0;
    end
    if ~isfield(rgcPars, 'surroundWeight')
        rgcPars.surroundWeight = 0;
    end

    center = mkGaussianFilter(rgcPars.centerSigma);
    surround = mkGaussianFilter(rgcPars.surroundSigma);

    outCenter = localSeparableSpatialSame(in, center);
    outSurround = localSeparableSpatialSame(in, surround);
    out = outCenter - rgcPars.surroundWeight .* outSurround;
end

function out = localApplyTemporalFilter(in, rgcPars)
    out = in;

    if ~isfield(rgcPars, 'temporalSigma')
        rgcPars.temporalSigma = 0;
    end

    if rgcPars.temporalSigma <= 0
        return;
    end

    tf = mkGaussianFilter(rgcPars.temporalSigma);
    out = convn(out, reshape(tf, [1 1 length(tf)]), 'same');
end

function out = localApplyImpairment(in, rgcPars)
    out = in;

    if isfield(rgcPars, 'impairmentAmplitudeMap') && ~isempty(rgcPars.impairmentAmplitudeMap)
        ampMap = rgcPars.impairmentAmplitudeMap;
        if any(size(ampMap) ~= size(in(:,:,1)))
            error('pars.rgc.impairmentAmplitudeMap must be YxX to match stimulus frame size.');
        end
        out = out .* repmat(ampMap, [1 1 size(out, 3)]);
    end

    if isfield(rgcPars, 'impairmentDelayMap') && ~isempty(rgcPars.impairmentDelayMap)
        delayMap = rgcPars.impairmentDelayMap;
        if any(size(delayMap) ~= size(in(:,:,1)))
            error('pars.rgc.impairmentDelayMap must be YxX to match stimulus frame size.');
        end
        if any(delayMap(:) ~= round(delayMap(:)))
            error('pars.rgc.impairmentDelayMap must contain integer frame delays.');
        end
        out = localApplyDelayMap(out, delayMap);
    end
end

function out = localSeparableSpatialSame(in, filt)
    out = convn(in, reshape(filt, [length(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 length(filt) 1]), 'same');
end

function out = localApplyDelayMap(in, delayMap)
    out = zeros(size(in));
    uniqueDelays = unique(delayMap(:));

    for i = 1:length(uniqueDelays)
        d = uniqueDelays(i);
        shifted = localShiftFrames(in, d);
        mask = repmat(delayMap == d, [1 1 size(in, 3)]);
        out(mask) = shifted(mask);
    end
end

function out = localShiftFrames(in, delayFrames)
    out = zeros(size(in));
    numFrames = size(in, 3);

    if delayFrames == 0
        out = in;
        return;
    end

    if delayFrames > 0
        if delayFrames >= numFrames
            return;
        end
        out(:,:,delayFrames+1:end) = in(:,:,1:end-delayFrames);
    else
        d = abs(delayFrames);
        if d >= numFrames
            return;
        end
        out(:,:,1:end-d) = in(:,:,d+1:end);
    end
end
