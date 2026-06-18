addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));
rng(1);

pars = shPars;
dims = shGetDims(pars, 'v1Complex', [1 1 24]);
stim = mkDots(dims, 0, 1.0, 0.12, 1.0);

parsNo = pars; parsNo.rgc.enabled = 0;
parsFour = pars; parsFour.rgc.enabled = 1;

[v1n, ~] = shModel(stim, parsNo, 'v1Complex');
[v1a, ~] = shModel(stim, parsFour, 'v1Complex');
fprintf('analytical channel weights: %.4f\n', localCorr(v1a(:), v1n(:)));

stimSet = localBuildStimSet(stim);
parsFour.rgc.v1Weights = shFitRgcV1Weights(parsFour, stimSet);
[v1f, ~] = shModel(stim, parsFour, 'v1Complex');
fprintf('fitted 16-basis spatial weights: %.4f\n', localCorr(v1f(:), v1n(:)));

cal = shCalibrateRgcLayer(40, parsFour);
parsFour.rgc = cal.bestRgcPars;
parsFour.rgc.enabled = 1;
[v1c, ~] = shModel(stim, parsFour, 'v1Complex');
fprintf('full calibration: %.4f (report corr %.4f)\n', localCorr(v1c(:), v1n(:)), cal.afterCorrelation);

function stimSet = localBuildStimSet(stimulus)
    dims = size(stimulus);
    stimSet = cell(1, 4);
    stimSet{1} = stimulus;
    stimSet{2} = mkDots(dims, pi/2, 0.7, 0.12, 0.7);
    g1 = v12sin([0, 1.0]);
    g2 = v12sin([pi/3, 1.6]);
    stimSet{3} = mkSin(dims, 0, g1(2), g1(3), 1);
    stimSet{4} = mkSin(dims, pi/3, g2(2), g2(3), 1);
end

function c = localCorr(a, b)
    r = corrcoef(a, b);
    c = r(1, 2);
end
