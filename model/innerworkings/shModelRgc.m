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
% RGC enabled, pars.rgc.mode = 'derivative' (default):
%   rgcOut    struct with fields:
%             .mode = 'derivative'
%             .channels.order0, .order1, .order2, .order3  [Y X T]
% RGC enabled, pars.rgc.mode = 'fourPop':
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

    mode = 'derivative';
    if isfield(pars.rgc, 'mode') && ~isempty(pars.rgc.mode)
        mode = pars.rgc.mode;
    end

    switch lower(mode)
        case 'derivative'
            rgcOut = shModelRgcDerivative(stimulus, pars);
        case 'fourpop'
            rgcOut = localComputeFourPopulations(stimulus, pars.rgc);
        otherwise
            error('pars.rgc.mode must be ''derivative'' or ''fourPop''.');
    end

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
        movie = shApplyRgcImpairment(movie, rgcPars);   % shared with the class path
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

function out = localSeparableSpatialSame(in, filt)
    out = convn(in, reshape(filt, [length(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 length(filt) 1]), 'same');
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
