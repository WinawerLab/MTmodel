% class = shRgcClass(name, temporalKernel, ...)
%
% Construct one RGC-class specification for the unified class-based RGC->V1
% front-end (see docs/RGC_V1_unification_plan.md). A "class" is one RGC
% population: a spatiotemporal filter (spatial RF x temporal kernel) plus a
% polarity/rectification rule, and a declaration of which V1 spatial-derivative
% read-out orders it feeds. Presets (shRgcClassesDerivative, ...) return arrays
% of these.
%
% Required arguments:
% name            char label, e.g. 'order0' or 'onParasol'
% temporalKernel  column vector, causal temporal kernel applied to the stimulus
%
% Optional name/value arguments (defaults in brackets):
% 'spatialRF'      [] = delta (single-pixel, i.e. no spatial filtering). Otherwise
%                  a struct describing a spatial RF (reserved for biological
%                  presets; not yet consumed by the forward). [ [] ]
% 'rectify'        'none' (linear, signed) | 'onHalf' | 'offHalf'. ['none']
% 'readoutOrders'  vector of V1 spatial-derivative TOTAL orders (x+y) this class
%                  feeds. Derivative preset: the singleton 3-k. fourPop/biological:
%                  [0 1 2 3]. [ [0 1 2 3] ]
% 'readoutOffset'  [dy dx] spatial offset (pixels) applied to this class in the V1
%                  read-out; the ON/OFF offset that assembles DS. [ [0 0] ]
% 'gain'           scalar per-class gain (lesioning hook). [1]
%
% Output:
% class            struct with the fields above (all present, defaulted).

function class = shRgcClass(name, temporalKernel, varargin)

    p = struct('spatialRF', [], 'rectify', 'none', 'readoutOrders', [0 1 2 3], ...
               'readoutOffset', [0 0], 'gain', 1);
    for i = 1:2:numel(varargin)
        key = varargin{i};
        if ~isfield(p, key)
            error('shRgcClass:unknownOption', 'Unknown option ''%s''.', key);
        end
        p.(key) = varargin{i + 1};
    end

    class = struct( ...
        'name', name, ...
        'temporalKernel', temporalKernel(:), ...
        'spatialRF', p.spatialRF, ...
        'rectify', p.rectify, ...
        'readoutOrders', p.readoutOrders(:)', ...
        'readoutOffset', p.readoutOffset(:)', ...
        'gain', p.gain);

end
