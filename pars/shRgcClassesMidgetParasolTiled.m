% classes = shRgcClassesMidgetParasolTiled(pars, temporalOffsets)
%
% Deprecated alias for shRgcClassesMidgetParasolLagged. Use the lagged name in
% new code; this entry point is kept for backward compatibility only.
%
% See also: shRgcClassesMidgetParasolLagged

function classes = shRgcClassesMidgetParasolTiled(pars, temporalOffsets)

    if nargin < 2 || isempty(temporalOffsets)
        temporalOffsets = [0 1 2 3];
    end
    classes = shRgcClassesMidgetParasolLagged(pars, temporalOffsets);

end
