% [S, ind] = shModelV1SeparableBasis(movie, pars)
%
% Compute the 10 separable third-order derivative responses for a movie.
% Used internally by the four-population RGC V1 path.

function [S, ind] = shModelV1SeparableBasis(movie, pars)

    v1SpatialFilters = pars.v1SpatialFilters;
    v1TemporalFilters = pars.v1TemporalFilters;
    nScales = pars.nScales;

    order = 3;
    fsz = size(v1SpatialFilters, 1);
    ind = zeros(nScales + 1, 4);

    for scale = 1:nScales
        m = shBlurDn3(movie, scale);
        n = 1;
        for torder = 0:order
            tfilt = reshape(flipud(v1TemporalFilters(:, torder + 1)), [1 1 fsz]);
            tmp1 = shValidCorrDn3(m, reshape(tfilt, [1 1 fsz]));
            for xorder = 0:(order - torder)
                yorder = order - torder - xorder;
                xfilt = reshape(v1SpatialFilters(:, xorder + 1), [1 fsz 1]);
                yfilt = reshape(flipud(v1SpatialFilters(:, yorder + 1)), [fsz 1 1]);
                tmp2 = shValidCorrDn3(shValidCorrDn3(tmp1, yfilt), xfilt);

                ind(scale + 1, 2:4) = [size(tmp2, 1), size(tmp2, 2), size(tmp2, 3)];
                tmp2 = tmp2(:);
                ind(scale + 1, 1) = ind(scale, 1) + size(tmp2, 1);
                if ~exist('S', 'var')
                    S = zeros(size(tmp2, 1), 10);
                end
                if size(S, 1) ~= ind(scale + 1, 1)
                    S = [S; zeros(size(tmp2, 1) - size(S, 1), 10)];
                end
                S(ind(scale, 1) + 1:ind(scale + 1, 1), n) = tmp2;
                n = n + 1;
            end
        end
    end

end
