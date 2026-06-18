% rgcOut = shModelRgc(stimulus, pars)
%
% Optional retinal ganglion cell (RGC) preprocessing layer.
%
% Required arguments:
% stimulus  3D movie [Y X T]
% pars      model parameters structure from shPars
%
% Output:
% RGC disabled:
%   rgcOut    original stimulus [Y X T]
% RGC enabled:
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

    rgcOut = localComputeFourPopulations(stimulus, pars.rgc);

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

    % Lagged copies of fast and slow channels.  A delay of D frames shifts
    % the response by D frames, introducing a temporal phase offset that
    % lets the weight-fitting stage approximate the odd-symmetric (temporal
    % derivative) components of the V1 temporal filter basis.
    fastLag = 0;
    slowLag = 0;
    if isfield(rgcPars, 'temporal')
        if isfield(rgcPars.temporal, 'fastLag'), fastLag = rgcPars.temporal.fastLag; end
        if isfield(rgcPars.temporal, 'slowLag'), slowLag = rgcPars.temporal.slowLag; end
    end
    if fastLag > 0
        rgcOut.channels.onFastLag  = localShiftFrames(rgcOut.channels.onFast,  fastLag);
        rgcOut.channels.offFastLag = localShiftFrames(rgcOut.channels.offFast, fastLag);
    end
    if slowLag > 0
        rgcOut.channels.onSlowLag  = localShiftFrames(rgcOut.channels.onSlow,  slowLag);
        rgcOut.channels.offSlowLag = localShiftFrames(rgcOut.channels.offSlow, slowLag);
    end

    allNames = fieldnames(rgcOut.channels);
    rgcOut.combined = zeros(size(stimulus));
    for i = 1:length(allNames)
        rgcOut.combined = rgcOut.combined + rgcOut.channels.(allNames{i});
    end

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
