% makeLaggedPresetDocFigures  Generate the figures for
% docs/RGC_lagged_preset_summary.md.
%
% Produces four PNGs in docs/figures/:
%   fig1_rgc_spatial_rfs.png   parasol vs midget DoG spatial RFs (2D + profile)
%   fig2_rgc_temporal.png      temporal kernels, and the lagged copies
%   fig3_v1_lagged_rfs.png     V1 stimulus-referred space-time RFs (lagged preset)
%   fig4_v1_lagged_vs_deriv.png  same neurons, lagged vs derivative preset
%
% Figures 3-4 use shV1Rf, which returns the LINEAR stimulus-referred kernel; for
% the biological preset that ignores ON/OFF rectification (see shV1Rf header).
% The comparison in fig 4 is therefore illustrative, not a quantitative claim.
%
% Usage:  run('explore/makeLaggedPresetDocFigures.m')

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(repoRoot));
outDir = fullfile(repoRoot, 'docs', 'figures');
if ~exist(outDir, 'dir'), mkdir(outDir); end
rng(0);

parasolRF = struct('centerSigma', 1.6, 'surroundSigma', 4.0, 'surroundWeight', 0.25);
midgetRF  = struct('centerSigma', 0.8, 'surroundSigma', 2.0, 'surroundWeight', 0.25);

% ---------------------------------------------------------------- figure 1
% Spatial RFs: the ACTUAL impulse response of the DoG the model applies, i.e.
% localDoG in shClassV1Basis -- separable convolution with mkGaussianFilter
% (sum-normalized, truncated at 3*sigma), minus surroundWeight * the surround.
% Do not substitute an analytic 1/(2*pi*sigma^2) DoG here; it has a visibly
% different centre/surround balance from what the model computes.
sz = 31; c = (sz + 1) / 2;
delta = zeros(sz); delta(c, c) = 1;
sepconv = @(in, f) convn(convn(in, reshape(f, [numel(f) 1]), 'same'), ...
                              reshape(f, [1 numel(f)]), 'same');
dogImpulse = @(rf) sepconv(delta, mkGaussianFilter(rf.centerSigma)) ...
                 - rf.surroundWeight * sepconv(delta, mkGaussianFilter(rf.surroundSigma));
Dp = dogImpulse(parasolRF); Dm = dogImpulse(midgetRF);

f1 = figure('Position', [100 100 1050 340], 'Color', 'w');
for k = 1:2
    if k == 1, D = Dm; nm = 'midget'; rf = midgetRF; else, D = Dp; nm = 'parasol'; rf = parasolRF; end
    subplot(1,3,k);
    lim = max(abs(D(:)));
    imagesc((1:sz)-c, (1:sz)-c, D, [-lim lim]); axis image;
    title(sprintf('%s DoG (\\sigma_c=%.1f, \\sigma_s=%.1f)', nm, rf.centerSigma, rf.surroundSigma));
    xlabel('x (pixels)'); if k==1, ylabel('y (pixels)'); end
    colorbar;
end
colormap(localDivergingMap());
subplot(1,3,3); hold on;
plot((1:sz)-c, Dm(c,:) / max(Dm(c,:)), 'LineWidth', 2);
plot((1:sz)-c, Dp(c,:) / max(Dp(c,:)), 'LineWidth', 2);
yline(0, 'k:'); xlabel('x (pixels)'); ylabel('normalized sensitivity');
legend({'midget','parasol'}, 'Location','northeast');
title('horizontal cross-section (peak-normalized)');
xlim([-12 12]); box off; grid on;
exportgraphics(f1, fullfile(outDir, 'fig1_rgc_spatial_rfs.png'), 'Resolution', 150);

% ---------------------------------------------------------------- figure 2
% Temporal kernels + lagged copies (the defining feature of this preset).
lags = [0 1 2 3];
classes = shRgcClassesMidgetParasolLagged(shPars, lags);
parasolK = localBiGamma(0.6, 1.2, 0.45, 2, 24);
midgetK  = localBiGamma(2.0, 4.0, 0.15, 2, 24);

f2 = figure('Position', [100 100 1000 640], 'Color', 'w');
subplot(2,2,1); hold on;
plot(0:23, midgetK, 'LineWidth', 2); plot(0:23, parasolK, 'LineWidth', 2);
yline(0,'k:'); xlabel('time (frames)'); ylabel('normalized response');
legend({'midget (slow)','parasol (fast)'}); title('base temporal kernels'); box off; grid on;

subplot(2,2,2); hold on;
for d = lags
    plot((0:(23 + d)), [zeros(1,d) parasolK], 'LineWidth', 1.6);
end
yline(0,'k:'); xlabel('time (frames)'); ylabel('normalized response');
legend(arrayfun(@(d) sprintf('lag %d', d), lags, 'UniformOutput', false));
title('parasol kernel, lagged copies'); box off; grid on;

subplot(2,2,3); hold on;
for d = lags
    plot((0:(23 + d)), [zeros(1,d) midgetK], 'LineWidth', 1.6);
end
yline(0,'k:'); xlabel('time (frames)'); ylabel('normalized response');
legend(arrayfun(@(d) sprintf('lag %d', d), lags, 'UniformOutput', false));
title('midget kernel, lagged copies'); box off; grid on;

% all 16 class kernels as an image, to show the bank at a glance
L = max(arrayfun(@(k) numel(k.temporalKernel), classes));
K = zeros(numel(classes), L);
for i = 1:numel(classes)
    k = classes(i).temporalKernel(:)'; K(i, 1:numel(k)) = k;
end
subplot(2,2,4);
imagesc(0:(L-1), 1:numel(classes), K); colormap(gca, parula); colorbar;
set(gca, 'YTick', 1:numel(classes), 'YTickLabel', {classes.name}, 'FontSize', 7);
xlabel('time (frames)'); title(sprintf('all %d class kernels', numel(classes)));
exportgraphics(f2, fullfile(outDir, 'fig2_rgc_temporal.png'), 'Resolution', 150);

% ---------------------------------------------------------------- figures 3-4
% V1 stimulus-referred space-time RFs. Lagged preset needs fitted weights;
% reuse the cached fit if present (same file the validation scripts use).
parsLag = shPars;
parsLag.rgc.classes = shRgcClassesMidgetParasolLagged(parsLag, lags);
parsLag.rgc.combine = 'weights';
weightsFile = fullfile(repoRoot, 'pars', 'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat');
if exist(weightsFile, 'file')
    cached = load(weightsFile);
    parsLag.rgc.v1Weights = cached.v1Weights;
else
    dims = shGetDims(parsLag, 'v1Complex', [5 5 20]);
    parsLag.rgc.v1Weights = shFitClassV1Weights(parsLag, {rand(dims)});
end
parsDer = shPars;   % derivative preset, combine = 'steer'

% pick neurons spanning preferred direction
dirs = parsLag.v1PopulationDirections;
show = [1 5 9 13];

% Symmetric colour limits about zero on every panel, so light/dark read as
% excitatory/inhibitory and panels are comparable to each other.
symlim = @(A) max(abs(A(:))) + eps;

f3 = figure('Position', [100 100 1100 620], 'Color', 'w');
for i = 1:numel(show)
    [~, RFstim, info] = shV1Rf(parsLag, show(i));
    fsz = size(RFstim, 1); cy = ceil(fsz/2); nTime = size(RFstim, 3);
    xt = squeeze(RFstim(cy, :, :))';           % [time x X] space-time slice
    subplot(2, numel(show), i);
    imagesc(1:fsz, 0:(nTime-1), xt, symlim(xt)*[-1 1]); axis xy;
    title(sprintf('neuron %d  (%.0f\\circ)', show(i), rad2deg(info.direction(1))));
    xlabel('x (pixels)'); if i==1, ylabel('time (frames)'); end
    % spatial slice at the time carrying most energy, not an arbitrary one
    e = squeeze(sum(sum(RFstim.^2, 1), 2)); [~, kPeak] = max(e);
    sl = RFstim(:,:,kPeak);
    subplot(2, numel(show), numel(show) + i);
    imagesc(1:fsz, 1:fsz, sl, symlim(sl)*[-1 1]); axis image xy;
    xlabel('x'); if i==1, ylabel('y'); end
    title(sprintf('spatial @ peak time %d', kPeak-1));
end
colormap(localDivergingMap());
sgtitle('V1 stimulus-referred RFs - lagged biological preset (linear kernel only)');
exportgraphics(f3, fullfile(outDir, 'fig3_v1_lagged_rfs.png'), 'Resolution', 150);

f4 = figure('Position', [100 100 1150 640], 'Color', 'w');
for i = 1:numel(show)
    [~, RFl, infoL] = shV1Rf(parsLag, show(i));
    [~, RFd]        = shV1Rf(parsDer, show(i));
    fsz = size(RFl,1); cy = ceil(fsz/2);
    xl = squeeze(RFl(cy,:,:))'; xd = squeeze(RFd(cy,:,:))';
    subplot(2, numel(show), i);
    imagesc(1:fsz, 0:(size(xl,1)-1), xl, symlim(xl)*[-1 1]); axis xy;
    % mark the derivative preset's 9-frame span, for scale
    yline(size(xd,1)-1, 'k--', 'LineWidth', 1);
    title(sprintf('lagged  n=%d (%.0f\\circ)', show(i), rad2deg(infoL.direction(1))));
    xlabel('x'); if i==1, ylabel('time (frames)'); end
    subplot(2, numel(show), numel(show)+i);
    imagesc(1:fsz, 0:(size(xd,1)-1), xd, symlim(xd)*[-1 1]); axis xy;
    title(sprintf('derivative  n=%d', show(i)));
    xlabel('x'); if i==1, ylabel('time (frames)'); end
end
colormap(localDivergingMap());
sgtitle({'Space-time RFs: lagged biological vs derivative preset (illustrative)', ...
         'note the different time extents - dashed line marks the derivative span'});
exportgraphics(f4, fullfile(outDir, 'fig4_v1_lagged_vs_deriv.png'), 'Resolution', 150);

fprintf('Wrote 4 figures to %s\n', outDir);

function k = localBiGamma(tau1, tau2, w, n, L)
    t = 0:(L - 1);
    k = (t ./ tau1) .^ n .* exp(-t ./ tau1) - w .* (t ./ tau2) .^ n .* exp(-t ./ tau2);
    k = k ./ max(abs(k));
end

% blue-white-red diverging map, so the DoG surround (negative) is visible
function cm = localDivergingMap()
    n = 128; t = linspace(0, 1, n)';
    lo = [t, t, ones(n,1)];                       % blue  -> white
    hi = [ones(n,1), flipud(t), flipud(t)];       % white -> red
    cm = [lo; hi];
end
