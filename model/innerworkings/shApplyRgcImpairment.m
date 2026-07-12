% movie = shApplyRgcImpairment(movie, rgcPars)
%
% Apply an optic-neuritis impairment (spatial amplitude deficit + integer-frame
% timing delay) to an RGC channel movie [Y X T]. No-op unless
% rgcPars.impairmentEnabled == 1. Shared by the fourPop path (shModelRgc) and the
% unified class path (shClassV1Basis) so the two stay consistent.
%
% rgcPars fields used:
%   impairmentEnabled     0/1
%   impairmentAmplitudeMap  YxX multiplicative amplitude map (optional)
%   impairmentDelayMap      YxX integer per-pixel frame delays (optional)

function movie = shApplyRgcImpairment(movie, rgcPars)

    if ~isfield(rgcPars, 'impairmentEnabled') || rgcPars.impairmentEnabled ~= 1
        return;
    end

    if isfield(rgcPars, 'impairmentAmplitudeMap') && ~isempty(rgcPars.impairmentAmplitudeMap)
        ampMap = rgcPars.impairmentAmplitudeMap;
        if any(size(ampMap) ~= size(movie(:, :, 1)))
            error('shApplyRgcImpairment:ampSize', ...
                  'pars.rgc.impairmentAmplitudeMap must be YxX to match the stimulus frame size.');
        end
        movie = movie .* repmat(ampMap, [1 1 size(movie, 3)]);
    end

    if isfield(rgcPars, 'impairmentDelayMap') && ~isempty(rgcPars.impairmentDelayMap)
        delayMap = rgcPars.impairmentDelayMap;
        if any(size(delayMap) ~= size(movie(:, :, 1)))
            error('shApplyRgcImpairment:delaySize', ...
                  'pars.rgc.impairmentDelayMap must be YxX to match the stimulus frame size.');
        end
        if any(delayMap(:) ~= round(delayMap(:)))
            error('shApplyRgcImpairment:delayInteger', ...
                  'pars.rgc.impairmentDelayMap must contain integer frame delays.');
        end
        movie = localApplyDelayMap(movie, delayMap);
    end

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
        if delayFrames >= numFrames, return; end
        out(:, :, delayFrames + 1:end) = in(:, :, 1:end - delayFrames);
    else
        d = abs(delayFrames);
        if d >= numFrames, return; end
        out(:, :, 1:end - d) = in(:, :, d + 1:end);
    end
end
