% RES = validCorrDn3(IM, FILT, STEP);
%
% Correlate 3D FILT with 3D IM.  FILT must be smaller than IM.  The 
% result dimensions [size(IM)-size(FILT)+1].
% STEP is an optional 3-vector that specifies subsampling factors.

% EPS, 7/96.
% Pure-MATLAB fallback (replaces MEX file). Uses convn with flipped filter
% to implement correlation. Equivalent to the C MEX implementation.

function res = validCorrDn3(im, filt, step)

if nargin < 3
    step = [1 1 1];
end

% Correlation = convolution with the filter flipped in all dimensions.
filt_flipped = filt(end:-1:1, end:-1:1, end:-1:1);
res = convn(im, filt_flipped, 'valid');

% Subsample according to step vector.
if any(step ~= 1)
    res = res(1:step(1):end, 1:step(2):end, 1:step(3):end);
end