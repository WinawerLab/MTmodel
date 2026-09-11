% [S, ind, nCols] = shClassV1Basis(M, pars)
%
% Build the class-based V1 linear feature matrix from pars.rgc.classes. Each
% class is filtered by its spatiotemporal RF and rectification (localClassChannel),
% causal-timing-trimmed, optionally shifted by its ON/OFF readout offset, then
% projected onto the V1 spatial-derivative read-outs it declares. Shared by the
% forward (shModelV1LinearFromClasses) and the fitter (shFitClassV1Weights).
%
% See docs/_archive/RGC_V1_unification_plan.md.

function [S, ind, nCols] = shClassV1Basis(M, pars)

    classes = pars.rgc.classes;
    SF = pars.v1SpatialFilters;
    fsz = size(SF, 1);
    nScales = pars.nScales;

    mSz = [size(M, 1), size(M, 2), size(M, 3)];
    if any(mSz < shGetDims(pars, 'v1lin'))
        error('Stimulus is too small for computation of V1lin stage.');
    end

    % --- per-class channels, causal trim, then ON/OFF readout offset ---
    nClass = numel(classes);
    rgcSd = shNoiseSd(pars, 'rgcSd');
    if rgcSd > 0
        rgcNoise = localRgcNoise(mSz, classes, rgcSd, pars);
    end
    chTrim = cell(1, nClass);
    for c = 1:nClass
        ch = localClassChannel(M, classes(c));
        ch = shApplyRgcImpairment(ch, pars.rgc);   % optic-neuritis deficit (no-op unless enabled)
        if rgcSd > 0
            % Site-1 noise, after gain and impairment: a weaker cell has a
            % worse signal-to-noise ratio (docs/NOISE_AND_DEMYELINATION.md 4.1).
            ch = ch + rgcNoise{c};
        end
        ch = ch(:, :, fsz:end);
        off = classes(c).readoutOffset;
        if numel(off) == 2 && any(off ~= 0)
            ch = circshift(ch, [off(1), off(2), 0]);   % V1 reads this class from an offset location
        end
        chTrim{c} = ch;
    end

    nCols = 0;
    for c = 1:nClass
        nCols = nCols + sum(classes(c).readoutOrders + 1);
    end

    % --- build S (mirrors shModelV1LinearFromRgcDerivative's scale/row layout) ---
    ind = zeros(nScales + 1, 4);
    S = [];
    for scale = 1:nScales
        n = 1;
        for c = 1:nClass
            m = shBlurDn3(chTrim{c}, scale);
            for s = classes(c).readoutOrders
                for xorder = 0:s
                    yorder = s - xorder;
                    xfilt = reshape(SF(:, xorder + 1), [1 fsz 1]);
                    yfilt = reshape(flipud(SF(:, yorder + 1)), [fsz 1 1]);
                    tmp = shValidCorrDn3(shValidCorrDn3(m, yfilt), xfilt);

                    ind(scale + 1, 2:4) = [size(tmp, 1), size(tmp, 2), size(tmp, 3)];
                    tmp = tmp(:);
                    ind(scale + 1, 1) = ind(scale, 1) + size(tmp, 1);
                    if isempty(S)
                        S = zeros(size(tmp, 1), nCols);
                    end
                    if size(S, 1) ~= ind(scale + 1, 1)
                        S = [S; zeros(size(tmp, 1), nCols)]; %#ok<AGROW>
                    end
                    S(ind(scale, 1) + 1:ind(scale + 1, 1), n) = tmp;
                    n = n + 1;
                end
            end
        end
    end

end

% =====================================================================
% One noise movie per RGC, not per class. The lagged classes of a preset
% (names ending _lagN) are delayed copies of one cell type, so they share that
% cell's noise, delayed by N frames: noise_N(t) = noise_0(t - N). Drawing it
% independently for each lag would average the noise down four-fold in the
% read-out. Classes without a lag suffix each get their own noise.
%
% With pars.noise.seed set, the noise comes from a private stream, so that the
% two MT streams -- which each rebuild this basis -- see the same retina.
function noise = localRgcNoise(mSz, classes, sd, pars)
    seed = [];
    if isfield(pars.noise, 'seed')
        seed = pars.noise.seed;
    end
    if isempty(seed)
        stream = RandStream.getGlobalStream;
    else
        stream = RandStream('mt19937ar', 'Seed', seed);
    end

    nClass = numel(classes);
    base = cell(1, nClass);
    lags = zeros(1, nClass);
    for c = 1:nClass
        base{c} = classes(c).name;
        tok = regexp(classes(c).name, '^(.*)_lag(\d+)$', 'tokens', 'once');
        if ~isempty(tok)
            base{c} = tok{1};
            lags(c) = str2double(tok{2});
        end
    end
    [~, ~, group] = unique(base, 'stable');

    maxLag = max(lags);
    nT = mSz(3);
    noise = cell(1, nClass);
    for g = 1:max(group)
        src = sd * randn(stream, mSz(1), mSz(2), nT + maxLag);
        for c = find(group(:)' == g)
            first = maxLag - lags(c) + 1;
            noise{c} = src(:, :, first:first + nT - 1);
        end
    end
end

function ch = localClassChannel(M, class)
% One class channel [Y X T]: spatial RF -> rectify -> causal temporal filter ->
% per-class gain. spatialRF = [] means a delta (single-pixel) RF, i.e. no spatial
% filtering (derivative preset). Otherwise spatialRF is a DoG struct with fields
% centerSigma, surroundSigma, surroundWeight (biological presets).

    if ~isempty(class.spatialRF)
        % biological: mean-subtracted contrast -> DoG -> polarity rectification
        frameMean = mean(mean(M, 1), 2);
        cs = localDoG(M - frameMean, class.spatialRF);
        switch lower(class.rectify)
            case 'onhalf',  m = max(0,  cs);
            case 'offhalf', m = max(0, -cs);
            case 'none',    m = cs;
            otherwise, error('shClassV1Basis:rectify', 'unknown rectify ''%s''.', class.rectify);
        end
    else
        % delta spatial RF (derivative preset by default; optional rectification)
        switch lower(class.rectify)
            case 'none',    m = M;
            case 'onhalf',  m = max(0,  M);
            case 'offhalf', m = max(0, -M);
            otherwise, error('shClassV1Basis:rectify', 'unknown rectify ''%s''.', class.rectify);
        end
    end

    tf = class.temporalKernel;
    fullOut = convn(m, reshape(tf, [1 1 numel(tf)]), 'full');
    ch = fullOut(:, :, 1:size(m, 3));

    if isfield(class, 'gain') && ~isempty(class.gain)
        ch = ch .* class.gain;
    end

end

function out = localDoG(in, sp)
    center   = mkGaussianFilter(sp.centerSigma);
    surround = mkGaussianFilter(sp.surroundSigma);
    out = localSeparable(in, center) - sp.surroundWeight .* localSeparable(in, surround);
end

function out = localSeparable(in, filt)
    out = convn(in, reshape(filt, [numel(filt) 1 1]), 'same');
    out = convn(out, reshape(filt, [1 numel(filt) 1]), 'same');
end
