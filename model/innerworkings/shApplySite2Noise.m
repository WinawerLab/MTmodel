function N = shApplySite2Noise(N, pars, ind, stage)
% shApplySite2Noise  Additive Site-2 noise on the normalization numerator.
%
%   N = shApplySite2Noise(N, pars, ind)           % V1 (site2)
%   N = shApplySite2Noise(N, pars, ind, 'mt')     % MT (mtSite2)
%
% V1: shModelV1Normalization_Tuned, gated on pars.noise.site2.enabled.
% MT: shModelMtNormalization_Tuned, gated on pars.noise.mtSite2.enabled.
% Do not enable both. Noise off must not change any existing result.
%
% spatialCorrelation = 'none' | 'gaussian' (same draw-then-blur as Phase B).
%
% See also: noisePars, docs/NOISE_TRIAL_DESIGN.md.

if nargin < 4 || isempty(stage)
    stage = 'v1';
end

if ~localActive(pars, stage)
    return
end

localAssertOneSite(pars);

if strcmp(stage, 'mt')
    site2 = pars.noise.mtSite2;
else
    site2 = pars.noise.site2;
end
if ~isfield(site2, 'mode') || ~strcmp(site2.mode, 'fixed')
    error('shApplySite2Noise:mode', ...
        'Only site2.mode = ''fixed'' is implemented (Step 0).');
end
if ~isfield(site2, 'sigma') || ~(isscalar(site2.sigma) && isfinite(site2.sigma) && site2.sigma >= 0)
    error('shApplySite2Noise:sigma', 'pars.noise.site2.sigma must be a non-negative scalar.');
end

if site2.sigma == 0
    return
end

corrMode = 'none';
if isfield(pars.noise, 'spatialCorrelation') && ~isempty(pars.noise.spatialCorrelation)
    corrMode = pars.noise.spatialCorrelation;
end

draw = randn(size(N));
switch corrMode
    case 'none'
        % Phase A
    case 'gaussian'
        if nargin < 3 || isempty(ind)
            error('shApplySite2Noise:needInd', ...
                'Phase B gaussian correlation needs the population index matrix.');
        end
        sigCorr = 3;
        if isfield(pars.noise, 'spatialCorrSigmaPx') && ~isempty(pars.noise.spatialCorrSigmaPx)
            sigCorr = pars.noise.spatialCorrSigmaPx;
        end
        draw = localBlurSpatialUnitVar(draw, ind, sigCorr);
    otherwise
        error('shApplySite2Noise:corr', ...
            'Unknown spatialCorrelation ''%s''. Use ''none'' or ''gaussian''.', corrMode);
end

N = N + site2.sigma * draw;

end

function tf = localActive(pars, stage)
tf = false;
if ~isstruct(pars) || ~isfield(pars, 'noise') || ~isstruct(pars.noise)
    return
end
n = pars.noise;
if ~isfield(n, 'enabled') || ~n.enabled
    return
end
if strcmp(stage, 'mt')
    fld = 'mtSite2';
else
    fld = 'site2';
end
if ~isfield(n, fld) || ~isstruct(n.(fld))
    return
end
if ~isfield(n.(fld), 'enabled') || ~n.(fld).enabled
    return
end
tf = true;
end

function localAssertOneSite(pars)
v1on = isfield(pars.noise, 'site2') && isstruct(pars.noise.site2) ...
    && isfield(pars.noise.site2, 'enabled') && pars.noise.site2.enabled;
mton = isfield(pars.noise, 'mtSite2') && isstruct(pars.noise.mtSite2) ...
    && isfield(pars.noise.mtSite2, 'enabled') && pars.noise.mtSite2.enabled;
if v1on && mton
    error('shApplySite2Noise:mixedSites', ...
        'Do not enable site2 and mtSite2 together. Run MT as its own arm.');
end
end

function draw = localBlurSpatialUnitVar(draw, ind, sigmaPx)
% Blur each neuron's Y×X map at every time (circular pad). Rescale so
% Var(blur(white)) = 1, matching Phase A marginal variance.
if ~(isscalar(sigmaPx) && isfinite(sigmaPx) && sigmaPx > 0)
    error('shApplySite2Noise:corrSigma', ...
        'spatialCorrSigmaPx must be a positive scalar.');
end
g = mkGaussianFilter(sigmaPx);
k2d = g(:) * g(:)';
scale = 1 / sqrt(sum(k2d(:).^2));

nScales = size(ind, 1) - 1;
nNeur = size(draw, 2);
for s = 1:nScales
    ny = ind(s + 1, 2);
    nx = ind(s + 1, 3);
    nt = ind(s + 1, 4);
    i0 = ind(s, 1) + 1;
    i1 = ind(s + 1, 1);
    for n = 1:nNeur
        vol = reshape(draw(i0:i1, n), [ny, nx, nt]);
        for t = 1:nt
            vol(:, :, t) = scale * localConv2Circ(vol(:, :, t), g);
        end
        draw(i0:i1, n) = vol(:);
    end
end
end

function y = localConv2Circ(a, g)
pad = (numel(g) - 1) / 2;
if pad == 0
    y = a;
    return
end
if pad ~= floor(pad)
    error('shApplySite2Noise:oddKernel', ...
        'Correlation kernel length must be odd (got %d).', numel(g));
end
ny = size(a, 1);
nx = size(a, 2);
if pad >= ny || pad >= nx
    error('shApplySite2Noise:fieldTooSmall', ...
        'Spatial field (%d x %d) is smaller than the correlation pad (%d).', ...
        ny, nx, pad);
end
rows = [a(end-pad+1:end, :); a; a(1:pad, :)];
a2 = [rows(:, end-pad+1:end), rows, rows(:, 1:pad)];
a2 = conv2(a2, g(:), 'valid');
a2 = conv2(a2, g(:)', 'valid');
y = a2;
end
