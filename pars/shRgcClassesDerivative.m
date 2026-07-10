% classes = shRgcClassesDerivative(pars)
%
% Build the DERIVATIVE-preset RGC class array for the unified class-based
% front-end. This is the exact Simoncelli-Heeger reconstruction expressed as
% RGC classes: 4 classes, one per temporal-derivative order 0..3, each with a
% delta (single-pixel) spatial RF, no rectification, and feeding V1 spatial-
% derivative TOTAL order 3-k (the SH "diagonal" of the class x read-out grid).
%
% With pars.rgc.combine = 'steer', shModelV1LinearFromClasses reproduces
% shModelV1Linear (legacy) essentially exactly at pars.nScales = 1.
%
% See docs/RGC_V1_unification_plan.md.

function classes = shRgcClassesDerivative(pars)

    TF = pars.v1TemporalFilters;   % [fsz x 4], orders 0..3

    classes = shRgcClass('order0', TF(:, 1), 'readoutOrders', 3);
    for k = 1:3
        classes(k + 1) = shRgcClass(sprintf('order%d', k), TF(:, k + 1), ...
                                    'readoutOrders', 3 - k); %#ok<AGROW>
    end

end
