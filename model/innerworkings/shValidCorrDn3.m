function res = shValidCorrDn3(im, filt, step)
% RES = shValidCorrDn3(IM, FILT, STEP)
% Native MATLAB 3D valid correlation with optional subsampling.

if nargin < 3
    step = [1 1 1];
end

% Correlation is convolution with the filter reversed in every dimension.
filtFlipped = filt(end:-1:1, end:-1:1, end:-1:1);
res = convn(im, filtFlipped, 'valid');

if any(step ~= 1)
    res = res(1:step(1):end, 1:step(2):end, 1:step(3):end);
end
