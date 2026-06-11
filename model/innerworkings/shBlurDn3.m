function res = shBlurDn3(m, lev, filt)
% RES = shBlurDn3(M, LEV, FILT)
% Native MATLAB blur + dyadic downsampling for 3D data.

if nargin < 2 || isempty(lev)
    lev = 2;
end
if nargin < 3 || isempty(filt)
    filt = [0.0884, 0.3536, 0.5303, 0.3536, 0.0884]';
end

if lev == 1
    res = m;
    return
end

fsz = length(filt);

res = shValidCorrDn3(m, reshape(filt, [1 1 fsz]));
res = shValidCorrDn3(res, reshape(filt, [1 fsz 1]));
res = shValidCorrDn3(res, reshape(filt, [fsz 1 1]));
res = res(1:2:end, 1:2:end, 1:2:end);

if lev > 2
    res = shBlurDn3(res, lev-1, filt);
end
