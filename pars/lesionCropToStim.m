function parsOut = lesionCropToStim(pars, Y, X)
% lesionCropToStim  Center-crop full-field impairment maps to stimulus [Y X].
%
% Stochastic lesions store pars.rgc.impairment*FieldFull; call this once you
% know the padded stimulus size (e.g. from shGetDims) before shModel.
%
%   pars = lesionApply(pars, 'delay_random', 'fieldSize', fieldSize);
%   pars = lesionCropToStim(pars, stimSz(1), stimSz(2));
%
% See also: lesionCropForCall, lesionApply.

parsOut = pars;
if ~isfield(pars.rgc, 'impairmentEnabled') || pars.rgc.impairmentEnabled ~= 1
    return;
end
if isfield(pars.rgc, 'impairmentAmplitudeFieldFull') && ~isempty(pars.rgc.impairmentAmplitudeFieldFull)
    parsOut.rgc.impairmentAmplitudeMap = localCenterCrop( ...
        pars.rgc.impairmentAmplitudeFieldFull, Y, X);
end
if isfield(pars.rgc, 'impairmentDelayFieldFull') && ~isempty(pars.rgc.impairmentDelayFieldFull)
    parsOut.rgc.impairmentDelayMap = localCenterCrop( ...
        pars.rgc.impairmentDelayFieldFull, Y, X);
end
end

function out = localCenterCrop(F, Y, X)
if size(F, 1) < Y || size(F, 2) < X
    error('lesionCropToStim:fieldTooSmall', ...
        'Lesion field [%d %d] smaller than stimulus [%d %d]. Increase fieldSize.', ...
        size(F, 1), size(F, 2), Y, X);
end
offY = floor((size(F, 1) - Y) / 2);
offX = floor((size(F, 2) - X) / 2);
out = F(offY+1:offY+Y, offX+1:offX+X);
end
