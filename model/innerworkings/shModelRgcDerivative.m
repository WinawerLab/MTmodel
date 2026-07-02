% rgcOut = shModelRgcDerivative(stimulus, pars)
%
% Non-biological "exact reconstruction" RGC layer. Produces 4 channels, one
% per temporal-derivative order (0-3) of the same kernel family used by
% pars.v1TemporalFilters, each with a single-pixel (delta) spatial RF -- i.e.
% no spatial filtering happens at this stage. Downstream spatial derivative
% filtering (shModelV1LinearFromRgcDerivative) reconstructs the legacy V1
% linear responses essentially exactly, because each channel supplies the
% same temporal-derivative content the legacy V1 filters use, just applied
% causally instead of with a centered (acausal) window.
%
% Required arguments:
% stimulus  3D movie [Y X T]
% pars      model parameters structure from shPars
%
% Output:
% rgcOut    struct with fields:
%           .mode = 'derivative'
%           .channels.order0, .order1, .order2, .order3  [Y X T]

function rgcOut = shModelRgcDerivative(stimulus, pars)

    v1TemporalFilters = pars.v1TemporalFilters;

    channelGain = ones(1, 4);
    if isfield(pars.rgc, 'derivative') && isfield(pars.rgc.derivative, 'channelGain')
        channelGain = pars.rgc.derivative.channelGain;
    end

    channelNames = {'order0', 'order1', 'order2', 'order3'};

    rgcOut = struct;
    rgcOut.mode = 'derivative';
    rgcOut.channels = struct;

    for k = 0:3
        tf = v1TemporalFilters(:, k + 1);
        movie = localCausalTemporalFilter(stimulus, tf) .* channelGain(k + 1);
        rgcOut.channels.(channelNames{k + 1}) = movie;
    end

end

function out = localCausalTemporalFilter(in, tf)

    fsz = length(tf);
    fullOut = convn(in, reshape(tf, [1 1 fsz]), 'full');
    out = fullOut(:, :, 1:size(in, 3));

end
