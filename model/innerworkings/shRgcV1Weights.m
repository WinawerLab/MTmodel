% W = shRgcV1Weights(v1Directions, customWeights)
%
% Compute V1 population weights over four RGC channels:
%   [onFast, offFast, onSlow, offSlow]
%
% Weights are signed functions of each neuron's preferred direction in 3D
% Fourier space, so space-time orientation emerges from ON/OFF spatial
% antagonism and fast/slow temporal tuning.
%
% Required arguments:
% v1Directions   Nx2 or Nx3 matrix in standard SH format
%
% Optional arguments:
% customWeights  if provided, returned unchanged (pass-through hook)
%
% Output:
% W              Nx4 weight matrix

function W = shRgcV1Weights(v1Directions, customWeights)

    if nargin > 1 && ~isempty(customWeights)
        W = customWeights;
        return;
    end

    dirs = v1Directions;
    dirs(:, 2) = atan3(dirs(:, 2), ones(size(dirs, 1), 1));
    dirs = sphere2rec(dirs);

    nd = sqrt(sum(dirs.^2, 2));
    dirs = dirs ./ max(nd, eps);

    dy = dirs(:, 1);
    dx = dirs(:, 2);
    dt = dirs(:, 3);

    spatial = dy + dx;

    W = zeros(size(dirs, 1), 4);
    W(:, 1) = spatial + dt;
    W(:, 2) = -spatial + dt;
    W(:, 3) = spatial - dt;
    W(:, 4) = -spatial - dt;

    rowNorm = sum(abs(W), 2);
    W = W ./ max(rowNorm, eps);

end
