function pars = motionLetterModelPars(preset, useMtMix)
% motionLetterModelPars  shPars wrapper for motion-letter scripts.
%
% Most scripts should call motionLetterPars instead (stimulus + model together).
% Use this when you only need the model struct, e.g. looping over RGC presets
% on one fixed stimulus.
%
%   pars = motionLetterModelPars('derivative')
%   pars = motionLetterModelPars('lagged')
%   pars = motionLetterModelPars('lagged', false)   % single-stream MT (pre-mtMix)
%
% Aliases: 'midgetParasolLagged', 'midgetParasolTiled' -> 'lagged'.

if nargin < 1 || isempty(preset)
    preset = 'lagged';
end
if nargin < 2 || isempty(useMtMix)
    useMtMix = true;
end

key = lower(strrep(preset, ' ', ''));
switch key
    case 'derivative'
        pars = shPars('derivative');
    case {'lagged', 'midgetparasollagged', 'midgetparasoltiled'}
        pars = shPars('lagged');
        if ~useMtMix && isfield(pars.rgc, 'mtMix')
            pars.rgc = rmfield(pars.rgc, 'mtMix');
        end
    otherwise
        error('motionLetterModelPars:badPreset', ...
            'preset must be ''derivative'' or ''lagged'', got ''%s''.', preset);
end
end
