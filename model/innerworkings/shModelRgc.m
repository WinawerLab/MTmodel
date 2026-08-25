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
        otherwise
            % Class-based front-ends (pars.rgc.mode = 'custom', e.g.
            % shPars('lagged')) do not have a standalone channel view here --
            % their channels ARE pars.rgc.classes. Inspect them with
            % shClassV1Basis, which returns the per-class feature basis.
            error('shModelRgc:mode', ...
                  ['shModelRgc only inspects the ''derivative'' front-end; got ''%s''. ' ...
                   'For class-based presets use shClassV1Basis.'], mode);
    end

end
