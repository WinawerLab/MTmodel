function N = shApplySite2Noise(N, pars, ind)
% shApplySite2Noise  Additive Site-2 noise on the normalization numerator.
%
% Called from shModelV1Normalization_Tuned after rectified N (nume) is formed
% and before the division. No-op unless pars.noise.enabled and
% pars.noise.site2.enabled. Noise off must not change any existing result.
%
% Phase A: spatialCorrelation = 'none' — independent at each voxel.
% Phase B: spatialCorrelation = 'gaussian' — blur the same white field in Y
% and X (not T) with σ = pars.noise.spatialCorrSigmaPx, then rescale so the
% marginal variance stays sigma^2. IND is required for Phase B (packed
% Y×X×T layout).
%
% See also: noisePars, docs/NOISE_TRIAL_DESIGN.md.

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
