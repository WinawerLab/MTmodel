% testLaggedBiologicalFidelity  Do lags lift healthy fidelity in the REAL model?
%
% Validates the §15 prediction (explore/temporalTilingFromLags.m, a pure kernel-
% reconstruction argument) inside the actual nonlinear V1 pipeline: adding lagged
% biological channels should raise the biological front-end's reconstruction of
% legacy V1 -- especially at HIGH temporal frequency, where a single mono/biphasic
% RGC kernel falls short (§2.4).
%
% Compares held-out legacy-V1 correlation, broken down by stimulus TF, for:
%   * midgetParasol (offset+quadrature)      -- the original ~0.70-ceiling preset
%   * midgetParasolLagged, lags=[0]          -- biological, NO lags, no offset
%   * midgetParasolLagged, lags=[0 1 2 3]    -- + lagged copies
%
% If the lagged preset climbs above the no-lag one (most at high TF), lags close
% the temporal gap in the real model. Self-locating; PNG to tempdir.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
outDir = tempdir;
rng(0);

pars = shPars;
parsLeg = pars; parsLeg.rgc.enabled = 0;              % legacy oracle
dims = shGetDims(pars, 'mtPattern', [1 1 40]);

% --- training set: varied directions x TFs + dots ---
trainSet = {};
for th = [0 pi/2 pi 3*pi/2]
    for sp = [0.4 0.9 1.5]
        gg = v12sin([th sp]); trainSet{end+1} = mkSin(dims, th, gg(2), gg(3), 1); %#ok<SAGROW>
    end
end
trainSet{end+1} = mkDots(dims, 0, 1.0, 0.12, 1);
trainSet{end+1} = mkDots(dims, pi/2, 0.8, 0.12, 1);

% --- held-out test set: gratings across a TF sweep (several directions each) ---
speeds = [0.3 0.6 0.9 1.3 1.8 2.4];       % TF proxy (higher speed -> higher TF)
testDirs = [pi/4 3*pi/4 5*pi/4];          % held out from training directions
tfProxy = zeros(1, numel(speeds));

% --- define the three presets ---
mk = @(cls) localSetPreset(pars, cls);
presets = { ...
    'midgetParasol (offset+quad)',      mk(shRgcClassesMidgetParasol(pars)); ...
    'lagged, no lags [0]',              mk(shRgcClassesMidgetParasolLagged(pars, 0)); ...
    'lagged [0 1 2 3]',                 mk(shRgcClassesMidgetParasolLagged(pars, [0 1 2 3])) };

% --- fit each preset once ---
for i = 1:size(presets,1)
    presets{i,2}.rgc.v1Weights = shFitClassV1Weights(presets{i,2}, trainSet);
    fprintf('%-30s fitted (%d features)\n', presets{i,1}, size(presets{i,2}.rgc.v1Weights,2));
end

% --- correlation to legacy V1lin, per TF, per preset ---
corrTF = zeros(numel(speeds), size(presets,1));
for s = 1:numel(speeds)
    Pleg = []; Pbio = cell(1,size(presets,1));
    for d = testDirs
        gg = v12sin([d speeds(s)]); tfProxy(s) = gg(3);
        stim = mkSin(dims, d, gg(2), gg(3), 1);
        Pleg = [Pleg; reshape(shModelV1Linear(stim, parsLeg), [], 1)]; %#ok<AGROW>
        for i = 1:size(presets,1)
            v = reshape(shModelV1LinearFromClasses(stim, presets{i,2}), [], 1);
            Pbio{i} = [Pbio{i}; v]; %#ok<AGROW>
        end
    end
    for i = 1:size(presets,1)
        c = corrcoef(Pleg, Pbio{i}); corrTF(s,i) = c(1,2);
    end
end

fprintf('\nHeld-out legacy-V1 correlation by temporal frequency (cyc/frame):\n');
fprintf('%-10s', 'TF'); for i=1:size(presets,1), fprintf('%-26s', presets{i,1}); end; fprintf('\n');
for s = 1:numel(speeds)
    fprintf('%-10.3f', tfProxy(s));
    for i=1:size(presets,1), fprintf('%-26.3f', corrTF(s,i)); end
    fprintf('\n');
end
fprintf('%-10s', 'MEAN');
for i=1:size(presets,1), fprintf('%-26.3f', mean(corrTF(:,i))); end
fprintf('\n');

% --- figure ---
f = figure('Color','w','Position',[70 90 760 460]);
plot(tfProxy, corrTF, '-o', 'LineWidth', 1.7); grid on;
xlabel('stimulus temporal frequency (cyc/frame)');
ylabel('held-out correlation to legacy V1'); ylim([0 1]);
legend(presets(:,1), 'Location','southwest', 'Interpreter','none');
title({'Do lagged biological channels lift healthy fidelity?', ...
       'Lags should help most at high TF (the §2.4 gap)'});
exportgraphics(f, fullfile(outDir,'laggedBiological_fidelity.png'), 'Resolution',150);
fprintf('\nWrote %s\n', fullfile(outDir,'laggedBiological_fidelity.png'));

% =====================================================================
function p = localSetPreset(pars, classes)
    p = pars;
    p.rgc.classes = classes;
    p.rgc.combine = 'weights';
    p.rgc.classesMode = 'custom';
end
