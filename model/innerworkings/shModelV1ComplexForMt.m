% [pop, ind] = shModelV1ComplexForMt(stimulus, pars)
%
% Produce the V1 complex-cell population response that the MT stages pool over.
%
% By default this is exactly the standard block used by every MT stage of
% shModel (linear -> full-wave rectify -> blur -> normalization), and the output
% is bit-identical to the previous inline code.
%
% If pars.rgc.mtMix is set, MT instead pools a TWO-STREAM mixture, after
% Nassi & Callaway (2006, 2007) -- see docs/MODEL_AND_LESIONS.md 2.3:
%
%   popMT = (1 - alpha)*popA + alpha*delay(popB, d)
%
%   popA  "4B -> MT": the fast, magnocellular stream. Driven by a parasol-masked
%         weight matrix (shFitClassV1Weights with a shClassFeatureMask), so it is
%         magno by construction. This is the dominant drive.
%   popB  "-> V2 -> MT": the slow minority stream, relayed via V2 thick stripes
%         over 3-5 synapses. Carries MIXED M and P (Nassi 2006 Fig 7A: V2's
%         disynaptic 4C label is ~70% 4Ca / ~29% 4Cb), which is exactly what the
%         existing pars.rgc.v1Weights already is -- so no second fit is needed.
%
% The mixture is formed AFTER V1 normalization, so the two streams do not share
% a normalization pool. That is the faithful choice for two anatomically
% separate populations converging on MT. Because shModelMtLinear is linear in
% pop, this is exactly (1-alpha)*MT(popA) + alpha*MT(popB delayed).
%
% The midget drive is IMPOSED at fixed amplitude, never fit: handing midget
% columns back to the ridge regression in shFitClassV1Weights would let the
% reconstruction objective re-inflate them, which is the original problem.
%
% pars.rgc.mtMix fields:
%   weightsA   [nNeurons x nFeatures] parasol-masked weight matrix (required)
%   alpha      scalar mixing weight on the slow midget-bearing stream. Calibrate
%              against Maunsell et al. (1990): P block should be small for most
%              MT units, detectable for a minority. [0.1]
%   delay      integer frame delay d applied to stream B. [0] -- the 2-3 extra
%              synapses are ~5-10 ms, well under one 26.9 ms frame, so the
%              latency separation is already carried by the slow midget kernel
%              (~107 ms peak vs parasol ~27 ms). Use 1 only to represent the V2
%              detour explicitly; it already overstates it.
%
% Setting alpha = 0 skips stream B entirely (one pass, pure magno) -- the
% comparison called for in docs/MODEL_AND_LESIONS.md 4.5.

function [pop, ind] = shModelV1ComplexForMt(stimulus, pars)

    mix = [];
    if isfield(pars, 'rgc') && isfield(pars.rgc, 'mtMix') && ~isempty(pars.rgc.mtMix)
        mix = pars.rgc.mtMix;
    end

    if isempty(mix)
        [pop, ind] = localV1Complex(stimulus, pars);
        return;
    end

    if ~isfield(mix, 'weightsA') || isempty(mix.weightsA)
        error('shModelV1ComplexForMt:noWeightsA', ...
              'pars.rgc.mtMix requires weightsA (the parasol-masked fit).');
    end
    alpha = 0.1;
    if isfield(mix, 'alpha') && ~isempty(mix.alpha), alpha = mix.alpha; end
    d = 0;
    if isfield(mix, 'delay') && ~isempty(mix.delay), d = mix.delay; end

    if alpha < 0 || alpha > 1
        error('shModelV1ComplexForMt:alphaRange', 'mtMix.alpha must be in [0 1], got %g.', alpha);
    end
    if d < 0 || d ~= round(d)
        error('shModelV1ComplexForMt:delayValue', 'mtMix.delay must be a non-negative integer.');
    end

    % --- stream A: fast magnocellular drive (parasol-masked weights) ---
    parsA = pars;
    parsA.rgc.v1Weights = mix.weightsA;
    parsA.rgc.combine   = 'weights';
    [popA, ind] = localV1Complex(stimulus, parsA);

    if alpha == 0
        pop = popA;
        return;
    end

    % --- stream B: slow minority drive, mixed M+P, via V2 (existing weights) ---
    [popB, indB] = localV1Complex(stimulus, pars);
    if ~isequal(ind, indB)
        error('shModelV1ComplexForMt:indMismatch', ...
              'The two streams produced different index matrices.');
    end
    popB = localDelayFrames(popB, ind, d);

    pop = (1 - alpha) .* popA + alpha .* popB;

end

% =====================================================================
% The standard V1 complex block, exactly as the MT stages of shModel ran it.
function [pop, ind] = localV1Complex(stimulus, pars)
    [pop, ind] = shModelV1Linear(stimulus, pars);
    [pop, ind] = shModelFullWaveRectification(pop, ind, pars);
    [pop, ind] = shModelV1Blur(pop, ind, pars);
    [pop, ind] = shModelV1Normalization(pop, ind, pars);
end

% Causal delay of d frames, applied per scale and per neuron. Each column of pop
% holds, for one neuron, a vectorized [Y X T] block per scale (see
% shClassV1Basis / shGetSubPop); the raw reshape is used here rather than
% shGetSubPop, which interpolates for scale > 1.
function pop = localDelayFrames(pop, ind, d)
    if d == 0
        return;
    end
    nScales = size(ind, 1) - 1;
    for s = 1:nScales
        rows = ind(s, 1) + 1 : ind(s + 1, 1);
        sz   = [ind(s + 1, 2), ind(s + 1, 3), ind(s + 1, 4)];
        nT   = sz(3);
        dd   = min(d, nT);
        for n = 1:size(pop, 2)
            blk = reshape(pop(rows, n), sz);
            blk = cat(3, zeros(sz(1), sz(2), dd), blk(:, :, 1:nT - dd));
            pop(rows, n) = blk(:);
        end
    end
end
