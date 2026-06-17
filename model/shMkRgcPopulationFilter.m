% kernel = shMkRgcPopulationFilter(pars, polarity, speed, kernelSize)
%
% Empirical spatiotemporal kernel for one four-population RGC channel.
% A brief luminance impulse is passed through shModelRgcPopulation.
%
% Required arguments:
% pars         model parameters (pars.rgc used)
% polarity     'on' or 'off'
% speed        'fast' or 'slow'
%
% Optional arguments:
% kernelSize   [Y X T] size of impulse movie (default = [31 31 31])
%
% Output:
% kernel       3D impulse response [Y X T]

function kernel = shMkRgcPopulationFilter(pars, polarity, speed, kernelSize)

    if nargin < 4 || isempty(kernelSize)
        kernelSize = [31 31 31];
    end

    impulse = zeros(kernelSize);
    cy = ceil(kernelSize(1) / 2);
    cx = ceil(kernelSize(2) / 2);
    ct = ceil(kernelSize(3) / 2);
    impulse(cy, cx, ct) = 1;

    kernel = shModelRgcPopulation(impulse, pars.rgc, polarity, speed);

end
