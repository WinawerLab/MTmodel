% testONOFFAsymmetryNonvacuousness  Does ON-only latency produce SH-inexpressible deltas?
%
% Tests the §16 prediction: an asymmetric ON-vs-OFF timing perturbation acts through
% the half-wave rectification nonlinearity (separate ON/OFF pathways that rectify
% before combining), which SH's purely linear basis lacks. The test:
%   1. Apply an ON-only latency lesion (delay ON channels, keep OFF unchanged) in the
%      biological model with the lagged preset
%   2. Compute the V1lin delta from this lesion
%   3. Try to reproduce this delta via ANY rescaling/delay of SH's temporal-order basis
%   4. If irreducible (low R²), the asymmetric latency is genuinely SH-inexpressible
%
% Controls:
%   - Uniform latency (all classes delayed equally): should be mostly reproducible by
%     SH temporal-order delays (positive control showing the projection works)
%   - OFF-only latency: should also be irreducible (symmetric test)
%
% Uses broadband stimulus (dots) since narrowband gratings alias delays into amplitude.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
outDir = tempdir;
rng(0);

pars = shPars;
dims = shGetDims(pars, 'mtPattern', [1 1 64]);

% --- training set for weight fitting ---
trainSet = {};
for th = [0 pi/2 pi 3*pi/2]
    for sp = [0.4 0.9 1.5]
        gg = v12sin([th sp]);
        trainSet{end+1} = mkSin(dims, th, gg(2), gg(3), 1); %#ok<SAGROW>
    end
end
trainSet{end+1} = mkDots(dims, 0, 1.0, 0.12, 1);
trainSet{end+1} = mkDots(dims, pi/2, 0.8, 0.12, 1);

% --- biological preset: lagged (the adopted preset) ---
parsBio = pars;
parsBio.rgc.classes = shRgcClassesMidgetParasolLagged(parsBio, [0 1 2 3]);
parsBio.rgc.combine = 'weights';
parsBio.rgc.classesMode = 'custom';
parsBio.rgc.v1Weights = shFitClassV1Weights(parsBio, trainSet);
fprintf('Bio lagged preset fitted (%d classes -> %d V1 features)\n', ...
    numel(parsBio.rgc.classes), size(parsBio.rgc.v1Weights, 2));

% --- test stimulus: broadband (dots avoid delay→amplitude aliasing) ---
testStim = mkDots(dims, pi/4, 1.2, 0.12, 1); % held-out direction

% --- bio healthy ---
V1bioHealthy = shModelV1LinearFromClasses(testStim, parsBio);

% --- lesion 1: ON-only latency (delay ON by 1 frame) ---
parsBioON = parsBio;
for i = 1:numel(parsBioON.rgc.classes)
    if contains(parsBioON.rgc.classes(i).name, 'On', 'IgnoreCase', false)
        % prepend 1 zero to kernel (1-frame delay)
        parsBioON.rgc.classes(i).temporalKernel = [0; parsBioON.rgc.classes(i).temporalKernel(:)];
    end
end
V1bioON = shModelV1LinearFromClasses(testStim, parsBioON);
deltaON = V1bioON(:) - V1bioHealthy(:);

% --- lesion 2: OFF-only latency (symmetric control) ---
parsBioOFF = parsBio;
for i = 1:numel(parsBioOFF.rgc.classes)
    if contains(parsBioOFF.rgc.classes(i).name, 'Off', 'IgnoreCase', false)
        parsBioOFF.rgc.classes(i).temporalKernel = [0; parsBioOFF.rgc.classes(i).temporalKernel(:)];
    end
end
V1bioOFF = shModelV1LinearFromClasses(testStim, parsBioOFF);
deltaOFF = V1bioOFF(:) - V1bioHealthy(:);

% --- lesion 3: uniform latency (all classes delayed; should be SH-reproducible) ---
parsBioUni = parsBio;
for i = 1:numel(parsBioUni.rgc.classes)
    parsBioUni.rgc.classes(i).temporalKernel = [0; parsBioUni.rgc.classes(i).temporalKernel(:)];
end
V1bioUni = shModelV1LinearFromClasses(testStim, parsBioUni);
deltaUni = V1bioUni(:) - V1bioHealthy(:);

fprintf('\nBio lesions (1-frame delay):\n');
fprintf('  ON-only:  |delta|=%.3f (%.1f%% of |healthy|=%.3f)\n', ...
    norm(deltaON), 100*norm(deltaON)/norm(V1bioHealthy(:)), norm(V1bioHealthy(:)));
fprintf('  OFF-only: |delta|=%.3f (%.1f%%)\n', norm(deltaOFF), 100*norm(deltaOFF)/norm(V1bioHealthy(:)));
fprintf('  Uniform:  |delta|=%.3f (%.1f%%)\n', norm(deltaUni), 100*norm(deltaUni)/norm(V1bioHealthy(:)));

% --- SH-equivalent basis: use derivative preset (bit-exact to SH) ---
parsSH = pars;
parsSH.rgc.enabled = 1;
parsSH.rgc.mode = 'derivative';
parsSH.rgc.derivative.channelGain = ones(1, 4); % all enabled
V1shHealthy = shModelV1Linear(testStim, parsSH);

% Build SH rescaling-delta basis: 4 temporal orders, amplitude only
Bsh = zeros(numel(deltaON), 4);
for ord = 0:3
    parsSHrescale = parsSH;
    parsSHrescale.rgc.derivative.channelGain = ones(1, 4);
    parsSHrescale.rgc.derivative.channelGain(ord+1) = 0.5;
    V1shRescale = shModelV1Linear(testStim, parsSHrescale);
    Bsh(:, ord+1) = V1shRescale(:) - V1shHealthy(:);
end

% --- project bio deltas onto SH basis ---
[R2_ON, irr_ON] = localR2(Bsh, deltaON);
[R2_OFF, irr_OFF] = localR2(Bsh, deltaOFF);
[R2_Uni, irr_Uni] = localR2(Bsh, deltaUni);

fprintf('\nProjection onto SH amplitude-rescaling basis (4 temporal orders):\n');
fprintf('                     R²        irreducible (1-R²)\n');
fprintf('  ON-only latency:   %.3f     %.3f\n', R2_ON, irr_ON);
fprintf('  OFF-only latency:  %.3f     %.3f\n', R2_OFF, irr_OFF);
fprintf('  Uniform latency:   %.3f     %.3f\n', R2_Uni, irr_Uni);

fprintf('\nInterpretation:\n');
fprintf('  If ON-only and OFF-only are highly irreducible (>>uniform), the asymmetric\n');
fprintf('  latency acts through the rectification nonlinearity SH lacks.\n');
fprintf('  Uniform should be mostly reproducible (low irreducible) as a sanity check.\n');

% =========================================================================
function [R2, irr] = localR2(B, d)
coef = B \ d;
resid = d - B * coef;
R2 = 1 - (resid'*resid) / max(d'*d, eps);
irr = 1 - R2;
end
