function N = shApplySite2Noise(N, pars)
% shApplySite2Noise  Additive Site-2 noise on the normalization numerator.
%
% Called from shModelV1Normalization_Tuned after rectified N (nume) is formed
% and before the division. No-op unless pars.noise.enabled and
% pars.noise.site2.enabled. Noise off must not change any existing result.
%
% Phase A: independent, fixed variance (Step 0). Phase B (gaussian spatial
% correlation) is not implemented yet.
%
% See also: noisePars, docs/NOISE_TRIAL_DESIGN.md §2.5.

if ~localActive(pars)
    return
end

site2 = pars.noise.site2;
if ~isfield(site2, 'mode') || ~strcmp(site2.mode, 'fixed')
    error('shApplySite2Noise:mode', ...
        'Only site2.mode = ''fixed'' is implemented (Step 0).');
end
if ~isfield(site2, 'sigma') || ~(isscalar(site2.sigma) && isfinite(site2.sigma) && site2.sigma >= 0)
    error('shApplySite2Noise:sigma', 'pars.noise.site2.sigma must be a non-negative scalar.');
end

if isfield(pars.noise, 'spatialCorrelation') ...
        && ~isempty(pars.noise.spatialCorrelation) ...
        && ~strcmp(pars.noise.spatialCorrelation, 'none')
    error('shApplySite2Noise:corr', ...
        ['Spatial correlation ''%s'' is Phase B and is not implemented. ', ...
         'Use spatialCorrelation = ''none''.'], pars.noise.spatialCorrelation);
end

if site2.sigma == 0
    return
end

N = N + site2.sigma * randn(size(N));

end

function tf = localActive(pars)
tf = false;
if ~isstruct(pars) || ~isfield(pars, 'noise') || ~isstruct(pars.noise)
    return
end
n = pars.noise;
if ~isfield(n, 'enabled') || ~n.enabled
    return
end
if ~isfield(n, 'site2') || ~isstruct(n.site2)
    return
end
if ~isfield(n.site2, 'enabled') || ~n.site2.enabled
    return
end
tf = true;
end
