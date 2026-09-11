function sd = shNoiseSd(pars, site)
% shNoiseSd  Standard deviation of the internal noise at one site, or 0 if it is not set.
%
%   sd = shNoiseSd(pars, site) returns pars.noise.(site), or 0 when pars has
%   no noise field, no such site, or an empty value. site is "rgcSd", "v1Sd"
%   or "mtSd" (see pars.noise in shPars).
%
%   Every noise hook asks this first and skips all random-number draws when it
%   returns 0, so a model run with noise off is bit-identical to one made
%   before the hooks existed.
%
%   See also shPars

    arguments
        pars (1,1) struct
        site (1,1) string {mustBeMember(site, ["rgcSd", "v1Sd", "mtSd"])}
    end

    sd = 0;
    if isfield(pars, "noise") && isfield(pars.noise, site) && ~isempty(pars.noise.(site))
        sd = pars.noise.(site);
    end
    if ~isscalar(sd) || ~isreal(sd) || sd < 0
        error("shNoiseSd:value", ...
            "pars.noise.%s must be a non-negative scalar. Set it to 0 to turn this noise off.", site);
    end
end
