% shShowV1Rf(pars, neuronIdx)
% [RFrgc, RFstim, info] = shShowV1Rf(pars, neuronIdx)
%
% Visualize one V1 neuron's linear receptive field two ways, from the unified
% class-based front-end (pars.rgc.classes). Class-agnostic wrapper around shV1Rf.
%
% Figure 1 (RGC-referred): the neuron's spatial weighting of each RGC class (top
%   row) and each class's temporal kernel (bottom row).
% Figure 2 (stimulus-referred): the linear space-time RF -- a montage over lag,
%   plus X-T and Y-T slices through the RF center.
%
% Required arguments:
% pars       parameters with pars.rgc.classes set (e.g. from shPars)
% neuronIdx  index into pars.v1PopulationDirections
%
% See shV1Rf for the returned arrays. For biological presets RFstim is the linear
% kernel only (rectification is nonlinear).

function [RFrgc, RFstim, info] = shShowV1Rf(pars, neuronIdx)

    [RFrgc, RFstim, info] = shV1Rf(pars, neuronIdx);
    classes = pars.rgc.classes;
    nClass = numel(classes);
    fsz = size(RFrgc, 1);
    nLag = size(RFstim, 3);
    lag = 0:(nLag - 1);

    cmap = localDivergingMap(256);

    % ---------- Figure 1: RGC-referred ----------
    f1 = figure('Name', 'V1 RF - RGC-referred (per class)', 'Color', 'w', ...
                'Position', [80 480 max(900, 240 * nClass) 520]);
    tl = tiledlayout(f1, 2, nClass, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, sprintf('V1 neuron %d  RGC-referred RF   dir=[%.2f %.2f]   (%s)', ...
        neuronIdx, info.direction(1), info.direction(2), info.combine), 'FontWeight', 'bold');

    clim = max(abs(RFrgc(:)));
    if clim == 0, clim = 1; end
    for c = 1:nClass
        nexttile(c);
        imagesc(RFrgc(:, :, c), [-clim clim]); axis image off; colormap(cmap);
        title(strrep(info.classNames{c}, '_', '\_'));
    end
    cb = colorbar; cb.Layout.Tile = 'east';

    for c = 1:nClass
        nexttile(nClass + c);
        tf = classes(c).temporalKernel;
        plot(0:numel(tf) - 1, tf, '-o', 'LineWidth', 1.4, 'MarkerSize', 3);
        yline(0, 'k:'); xlim([0 numel(tf) - 1]);
        xlabel('lag (frames)'); if c == 1, ylabel('temporal kernel'); end
        title(sprintf('%s tf', strrep(info.classNames{c}, '_', '\_')), 'FontSize', 8);
    end

    % ---------- Figure 2: stimulus-referred ----------
    f2 = figure('Name', 'V1 RF - stimulus-referred (space-time)', 'Color', 'w', ...
                'Position', [80 40 max(900, 120 * nLag) 620]);
    tl2 = tiledlayout(f2, 3, nLag, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl2, sprintf('V1 neuron %d  stimulus-referred RF (linear)  [%d x %d x %d]', ...
        neuronIdx, fsz, fsz, nLag), 'FontWeight', 'bold');

    sclim = max(abs(RFstim(:)));
    if sclim == 0, sclim = 1; end
    cy = ceil(fsz / 2); cx = ceil(fsz / 2);
    for tau = 1:nLag
        nexttile(tau);
        imagesc(RFstim(:, :, tau), [-sclim sclim]); axis image off; colormap(cmap);
        title(sprintf('lag %d', tau - 1), 'FontSize', 7);
    end
    nexttile(nLag + 1, [1 nLag]);
    imagesc(lag, 1:fsz, squeeze(RFstim(cy, :, :)), [-sclim sclim]); colormap(cmap);
    xlabel('lag (frames)'); ylabel('X'); title(sprintf('X-T slice at center Y (row %d)', cy));
    nexttile(2 * nLag + 1, [1 nLag]);
    imagesc(lag, 1:fsz, squeeze(RFstim(:, cx, :)), [-sclim sclim]); colormap(cmap);
    xlabel('lag (frames)'); ylabel('Y'); title(sprintf('Y-T slice at center X (col %d)', cx));

    drawnow;

end

function cmap = localDivergingMap(m)
    g = linspace(0, 1, m / 2)';
    cmap = [[g g ones(m / 2, 1)]; [ones(m / 2, 1) flipud(g) flipud(g)]];
end
