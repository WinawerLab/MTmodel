% showV1RfDerivative  Visualize one V1 neuron's receptive field two ways.
%
%   RGC-referred : Y x X x nClass  (spatial weighting of each RGC temporal
%                  class, plus each class's temporal kernel)
%   Stimulus-ref : Y x X x lag      (space-time RF, RF_stim = sum_k RF_rgc*tf_k)
%
% Also verifies the analytic RF against the real model on a 9x9x9 stimulus
% (single output location) -> max error ~1e-16. See docs/RGC_V1_unification_plan.md.
%
% Self-locating: adds the repo to the path from this file's location.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));      % explore/ -> repo root
addpath(genpath(repoRoot));
set(0, 'DefaultFigureVisible', 'on');           % ensure windows show (headless MCP)

jn = 5;                                          % example neuron index (1..28)

pars = shPars;
SF = pars.v1SpatialFilters;                      % 9 x 4 (orders 0..3)
TF = pars.v1TemporalFilters;                     % 9 x 4 (orders 0..3)
fsz = size(SF, 1);
W  = shSwts(pars.v1PopulationDirections);        % 28 x 10
w  = W(jn, :);
dir = pars.v1PopulationDirections(jn, :);

% basis column order used by shModelV1LinearFromRgcDerivative
% (torder outer, xorder inner, yorder = 3 - torder - xorder)
tC = zeros(1,10); xC = zeros(1,10); yC = zeros(1,10);
n = 0;
for torder = 0:3
    for xorder = 0:(3-torder)
        n = n+1; tC(n)=torder; xC(n)=xorder; yC(n)=3-torder-xorder;
    end
end

% RGC-referred RF: 9 x 9 x 4
RFrgc = zeros(fsz, fsz, 4);
for n = 1:10
    sy = flipud(SF(:, yC(n)+1));                 % Y filter (flipud, as in code)
    sx = SF(:, xC(n)+1);                         % X filter
    RFrgc(:,:,tC(n)+1) = RFrgc(:,:,tC(n)+1) + w(n) * (sy * sx.');
end

% Stimulus-referred RF: 9 x 9 x 9 (lag index 1 = lag 0)
RFstim = zeros(fsz, fsz, fsz);
for k = 0:3
    for tau = 1:fsz
        RFstim(:,:,tau) = RFstim(:,:,tau) + RFrgc(:,:,k+1) * TF(tau, k+1);
    end
end

% ---- verify analytic RF reproduces the model (all 28 neurons) ----
rng(1); M = randn(fsz, fsz, fsz);
pop = shModelV1Linear(M, pars);                  % 1 x 28
pred = zeros(1, size(W,1));
for jj = 1:size(W,1)
    wj = W(jj,:);
    RFr = zeros(fsz,fsz,4);
    for n = 1:10
        RFr(:,:,tC(n)+1) = RFr(:,:,tC(n)+1) + wj(n) * (flipud(SF(:,yC(n)+1)) * SF(:,xC(n)+1).');
    end
    Kabs = zeros(fsz,fsz,fsz);
    for k = 0:3, for t = 1:fsz, Kabs(:,:,t) = Kabs(:,:,t) + RFr(:,:,k+1)*TF(fsz+1-t,k+1); end, end
    pred(jj) = pars.scaleFactors.v1Linear * sum(Kabs(:).*M(:));
end
fprintf('analytic RF vs model: max abs error = %.3e (expect ~1e-16)\n', max(abs(pred(:)-pop(:))));

% ---- plotting ----
m = 256; g = linspace(0,1,m/2)';
cmap = [ [g g ones(m/2,1)]; [ones(m/2,1) flipud(g) flipud(g)] ];   % blue-white-red
lag = 0:fsz-1;
outdir = tempdir;

f1 = figure('Name','V1 RF - RGC-referred (YxXxclass)','Color','w','Position',[80 480 1000 520]);
tl = tiledlayout(f1,2,4,'TileSpacing','compact','Padding','compact');
title(tl, sprintf('V1 neuron %d  RGC-referred RF   dir=[%.2f %.2f]', jn, dir(1), dir(2)), 'FontWeight','bold');
clim = max(abs(RFrgc(:)));
for k=1:4
    nexttile(k); imagesc(RFrgc(:,:,k), [-clim clim]); axis image off; colormap(cmap);
    title(sprintf('class %d  (\\partial^%d/\\partial t^%d)', k-1, k-1, k-1));
end
cb = colorbar; cb.Layout.Tile = 'east';
tclim = max(abs(TF(:)));
for k=1:4
    nexttile(4+k); plot(lag, TF(:,k), '-o','LineWidth',1.5,'MarkerSize',3);
    yline(0,'k:'); ylim([-tclim tclim]); xlim([0 fsz-1]);
    xlabel('lag (frames)'); if k==1, ylabel('temporal kernel'); end
    title(sprintf('tf_%d(\\tau)', k-1));
end
exportgraphics(f1, fullfile(outdir,'v1rf_rgc_referred.png'), 'Resolution',150);

f2 = figure('Name','V1 RF - stimulus-referred (YxXxlag)','Color','w','Position',[80 40 1100 620]);
tl2 = tiledlayout(f2,3,fsz,'TileSpacing','compact','Padding','compact');
title(tl2, sprintf('V1 neuron %d  stimulus-referred RF  (Y x X x lag)', jn), 'FontWeight','bold');
sclim = max(abs(RFstim(:))); cy = ceil(fsz/2); cx = ceil(fsz/2);
for tau=1:fsz
    nexttile(tau); imagesc(RFstim(:,:,tau), [-sclim sclim]); axis image off; colormap(cmap);
    title(sprintf('lag %d', tau-1),'FontSize',8);
end
nexttile(fsz+1,[1 fsz]); imagesc(lag,1:fsz,squeeze(RFstim(cy,:,:)),[-sclim sclim]); colormap(cmap);
xlabel('lag (frames)'); ylabel('X'); title(sprintf('X-T slice at center Y (row %d)',cy));
nexttile(2*fsz+1,[1 fsz]); imagesc(lag,1:fsz,squeeze(RFstim(:,cx,:)),[-sclim sclim]); colormap(cmap);
xlabel('lag (frames)'); ylabel('Y'); title(sprintf('Y-T slice at center X (col %d)',cx));
exportgraphics(f2, fullfile(outdir,'v1rf_stimulus_referred.png'), 'Resolution',150);

fprintf('figures shown; PNGs also written to %s\n', outdir);
