% [pop, ind, S, res] = shModelV1LinearFromRgcDerivative(stimulus, pars, resdirs)
%
% Compute linear V1 responses from the 4-channel derivative-basis RGC layer
% (shModelRgcDerivative). Each of the 10 (torder, xorder, yorder) combos with
% torder+xorder+yorder=3 is built exactly as in the legacy shModelV1Linear:
% the torder component comes from the matching RGC channel (already
% temporally filtered with pars.v1TemporalFilters(:,torder+1), causally)
% instead of being filtered inline; xorder/yorder are applied the same way,
% with the same v1SpatialFilters. The population combination reuses shSwts
% directly -- no fitted weight matrix is involved, because the basis is
% constructed to match the legacy basis column-for-column.
%
% Required arguments:
% stimulus   raw 3D movie [Y X T]
% pars       model parameters with pars.rgc.enabled = 1, pars.rgc.mode = 'derivative'
%
% Optional arguments:
% resdirs    additional neuron directions (same format as shModelV1Linear)
%
% Outputs match shModelV1Linear.

function varargout = shModelV1LinearFromRgcDerivative(varargin)

    M = varargin{1};
    pars = varargin{2};
    v1PopulationDirections = pars.v1PopulationDirections;
    if nargin > 2
        resdirs = varargin{3};
    end

    mSz = [size(M, 1), size(M, 2), size(M, 3)];
    if any(mSz < shGetDims(pars, 'v1lin'))
        error('Stimulus is too small for computation of V1lin stage.');
    end

    if nargout > 3 && nargin < 3
        error('You must specify which neuronal responses you want.');
    end

    rgcOut = shModelRgcDerivative(M, pars);

    v1SpatialFilters = pars.v1SpatialFilters;
    nScales = pars.nScales;
    order = 3;
    fsz = size(v1SpatialFilters, 1);
    ind = zeros(nScales + 1, 4);
    channelNames = {'order0', 'order1', 'order2', 'order3'};

    % Trim the leading fsz-1 frames so each causally-filtered channel aligns
    % with legacy's valid-convolution timing (the trimmed causal channel is
    % numerically identical to legacy's temporally-filtered movie -- see
    % shModelRgcDerivative.m).
    trimmedChannels = struct;
    for torder = 0:order
        ch = rgcOut.channels.(channelNames{torder + 1});
        trimmedChannels.(channelNames{torder + 1}) = ch(:, :, fsz:end);
    end

    for scale = 1:nScales
        n = 1;
        for torder = 0:order
            m = shBlurDn3(trimmedChannels.(channelNames{torder + 1}), scale);
            for xorder = 0:(order - torder)
                yorder = order - torder - xorder;
                xfilt = reshape(v1SpatialFilters(:, xorder + 1), [1 fsz 1]);
                yfilt = reshape(flipud(v1SpatialFilters(:, yorder + 1)), [fsz 1 1]);
                tmp2 = shValidCorrDn3(shValidCorrDn3(m, yfilt), xfilt);

                ind(scale + 1, 2:4) = [size(tmp2, 1), size(tmp2, 2), size(tmp2, 3)];
                tmp2 = tmp2(:);
                ind(scale + 1, 1) = ind(scale, 1) + size(tmp2, 1);
                if ~exist('S', 'var')
                    S = zeros(size(tmp2, 1), 10);
                end
                if size(S, 1) ~= ind(scale + 1, 1)
                    S = [S; zeros(size(tmp2, 1), 10)]; %#ok<AGROW>
                end
                S(ind(scale, 1) + 1:ind(scale + 1, 1), n) = tmp2;
                n = n + 1;
            end
        end
    end

    pop = S * shSwts(v1PopulationDirections)';
    pop = pop * pars.scaleFactors.v1Linear;

    varargout{1} = pop;
    varargout{2} = ind;
    varargout{3} = S;

    if nargout > 3
        res = S * shSwts(resdirs)';
        res = res * pars.scaleFactors.v1Linear;
        varargout{4} = res;
    end

end
