% rgcOut = shModelRgc(stimulus, pars)
%
% Optional retinal ganglion cell (RGC) preprocessing layer.
%
% Required arguments:
% stimulus  3D movie [Y X T]
% pars      model parameters structure from shPars
%
% Output:
% legacy mode (populationMode = 'legacy'):
%   rgcOut    filtered RGC movie [Y X T]
% fourPop mode (populationMode = 'fourPop'):
%   rgcOut    struct with fields:
%             .mode = 'fourPop'
%             .channels.onFast, .offFast, .onSlow, .offSlow  [Y X T]
%             .combined  weighted sum of channels for inspection

function rgcOut = shModelRgc(stimulus, pars)

    rgcOut = stimulus;

    if ~isfield(pars, 'rgc')
        return;
    end

    if ~isfield(pars.rgc, 'enabled') || pars.rgc.enabled == 0
        return;
    end

    if localIsFourPopMode(pars.rgc)
        rgcOut = localComputeFourPopulations(stimulus, pars.rgc);
        return;
    end

    rgcOut = localApplyLegacyFilter(stimulus, pars.rgc);

end

function tf = localIsFourPopMode(rgcPars)

    tf = isfield(rgcPars, 'populationMode') && strcmpi(rgcPars.populationMode, 'fourPop');

end

function rgcOut = localComputeFourPopulations(stimulus, rgcPars)

    channelNames = {'onFast', 'offFast', 'onSlow', 'offSlow'};
    polarities = {'on', 'off', 'on', 'off'};
    speeds = {'fast', 'fast', 'slow', 'slow'};

    rgcOut = struct;
    rgcOut.mode = 'fourPop';
    rgcOut.channels = struct;

    for i = 1:length(channelNames)
        movie = shModelRgcPopulation(stimulus, rgcPars, polarities{i}, speeds{i});
        if isfield(rgcPars, 'impairmentEnabled') && rgcPars.impairmentEnabled == 1
            movie = localApplyImpairment(movie, rgcPars);
        end
        rgcOut.channels.(channelNames{i}) = movie;
    end

    rgcOut.combined = rgcOut.channels.onFast + rgcOut.channels.offFast + ...
        rgcOut.channels.onSlow + rgcOut.channels.offSlow;

end

function out = localApplyLegacyFilter(stimulus, rgcPars)

    out = localApplySpatialFilter(stimulus, rgcPars);
    out = localApplyTemporalFilter(out, rgcPars);

    if isfield(rgcPars, 'gain')
        out = out .* rgcPars.gain;
    end

    if isfield(rgcPars, 'impairmentEnabled') && rgcPars.impairmentEnabled == 1
        out = localApplyImpairment(out, rgcPars);
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
