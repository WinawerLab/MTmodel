% measurePreferredTfSf
%
% Tabulate the preferred spatial and temporal frequency of all 28 V1 neurons, for
% both fitted populations of docs/MODEL_AND_LESIONS.md 2.3:
%
%   population B  "-> V2 -> MT"  : the mixed fit (all 160 feature columns)
%   population A  "4B -> MT"     : the parasol-masked fit (80 columns)
%
% NOMINAL preferences are identical for the two populations by construction. Both
% are fit against the same pars.v1PopulationDirections, and v12sin places the
% preferred (sf, tf) on a fixed-radius annulus (k = 0.2173) parameterized purely
% by the neuron's tf/sf ratio. Only the weights differ, never the tiling -- that
% is exactly the invariant item 1 depends on (shMtWts needs the full direction
% tiling, so we mask features, never subset neurons).
%
% So the interesting quantity is the MEASURED preference: given that the
% parasol-only basis reconstructs slow neurons poorly (check 1: r ~0.55 at low
% tf/sf vs ~0.82 at high), does population A actually still prefer what it was fit
% to prefer, or has the fast parasol kernel (tau 0.6/1.2) dragged its preferences
% upward?
%
% Method: for each neuron, at its own preferred direction, sweep tf on a common
% log grid (sf held at nominal) and sf on a common log grid (tf held at nominal),
% and take the argmax of that neuron's v1Complex response. A common grid is used
% for every neuron so the columns are directly comparable; preferences are
% therefore quantized to the grid.
%
% Units use the frame rate pinned in docs/RGC_lagged_preset_summary.md 7.1:
% 1 pixel = 0.430 deg, 1 frame = 26.9 ms (37.2 fps).

clear; clc;
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

DEG_PER_PX   = 0.430;
MS_PER_FRAME = 26.9;
FPS          = 1000 / MS_PER_FRAME;
NPTS         = 15;
SF_GRID      = logspace(log10(0.02), log10(0.45), NPTS);   % cycles/pixel
TF_GRID      = logspace(log10(0.01), log10(0.45), NPTS);   % cycles/frame

pars = shPars;
pars.rgc.enabled     = 1;
pars.rgc.mode        = 'custom';
pars.rgc.classes     = shRgcClassesMidgetParasolLagged(pars, [0 1 2 3]);
pars.rgc.combine     = 'weights';
pars.rgc.classesMode = 'custom';

WB = getfield(load(fullfile(repoRoot, 'pars', ...
     'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat')), 'v1Weights');
WA = getfield(load(fullfile(repoRoot, 'pars', ...
     'shRgcClassesMidgetParasolLagged_v1WeightsMagnoA_lag0123.mat')), 'v1WeightsMagnoA');

V = pars.v1PopulationDirections;
P = v12sin(V);
nN = size(V, 1);
sz = shGetDims(pars, 'v1Complex', [1 1 31]);

Wset  = {WB, WA};
Wname = {'B_mixed', 'A_parasol'};
sfPref = nan(nN, 2); tfPref = nan(nN, 2); peakResp = nan(nN, 2);

tAll = tic;
for w = 1:2
    p = pars; p.rgc.v1Weights = Wset{w};
    for i = 1:nN
        dir = V(i, 1);

        % --- TF sweep at the neuron's nominal preferred sf ---
        rTf = zeros(1, NPTS);
        for k = 1:NPTS
            s = mkSin(sz, dir, P(i, 2), TF_GRID(k), 1);
            [pop, ind] = shModel(s, p, 'v1Complex');
            rTf(k) = mean(shGetNeuron(pop, ind, i));
        end
        [~, kt] = max(rTf);
        tfPref(i, w) = TF_GRID(kt);

        % --- SF sweep at the neuron's nominal preferred tf ---
        rSf = zeros(1, NPTS);
        for k = 1:NPTS
            s = mkSin(sz, dir, SF_GRID(k), P(i, 3), 1);
            [pop, ind] = shModel(s, p, 'v1Complex');
            rSf(k) = mean(shGetNeuron(pop, ind, i));
        end
        [~, ks] = max(rSf);
        sfPref(i, w) = SF_GRID(ks);
        peakResp(i, w) = max([rTf, rSf]);
    end
    fprintf('%s done (%.0fs)\n', Wname{w}, toc(tAll));
end

% ---------------------------------------------------------------- output
outTxt = fullfile(repoRoot, 'explore', '_figs', 'preferredTfSf.txt');
fid = fopen(outTxt, 'w');
for out = [1 fid]
    fprintf(out, 'Preferred SF/TF of the 28 V1 neurons, both populations\n');
    fprintf(out, '1 px = %.3f deg, 1 frame = %.1f ms (%.1f fps)\n', DEG_PER_PX, MS_PER_FRAME, FPS);
    fprintf(out, 'NOMINAL is shared by both populations (same v1PopulationDirections).\n');
    fprintf(out, 'MEASURED is argmax over a common log grid (%d pts): sf %.3f-%.3f c/px, tf %.3f-%.3f c/fr\n\n', ...
            NPTS, SF_GRID(1), SF_GRID(end), TF_GRID(1), TF_GRID(end));
    fprintf(out, '%3s %7s %7s | %8s %8s %7s %6s | %8s %8s | %8s %8s\n', ...
            'n', 'dir', 'tf/sf', 'sf c/px', 'tf c/fr', 'c/deg', 'Hz', ...
            'B sf', 'B tf', 'A sf', 'A tf');
    fprintf(out, '%s\n', repmat('-', 1, 96));
    for i = 1:nN
        fprintf(out, '%3d %7.1f %7.3f | %8.4f %8.4f %7.3f %6.2f | %8.4f %8.4f | %8.4f %8.4f\n', ...
                i, 180*V(i,1)/pi, V(i,2), P(i,2), P(i,3), P(i,2)/DEG_PER_PX, P(i,3)*FPS, ...
                sfPref(i,1), tfPref(i,1), sfPref(i,2), tfPref(i,2));
    end
    fprintf(out, '\nMeasured/nominal ratio (median over neurons):\n');
    fprintf(out, '  population B: sf x%.2f, tf x%.2f\n', ...
            median(sfPref(:,1)./P(:,2)), median(tfPref(:,1)./P(:,3)));
    fprintf(out, '  population A: sf x%.2f, tf x%.2f\n', ...
            median(sfPref(:,2)./P(:,2)), median(tfPref(:,2)./P(:,3)));
    slow = V(:,2) < 0.5; fast = V(:,2) > 1.0;
    fprintf(out, '\nBy tf/sf band, measured tf (median, cycles/frame):\n');
    fprintf(out, '  %-16s nominal %.4f | B %.4f | A %.4f\n', 'slow (tf/sf<0.5)', ...
            median(P(slow,3)), median(tfPref(slow,1)), median(tfPref(slow,2)));
    fprintf(out, '  %-16s nominal %.4f | B %.4f | A %.4f\n', 'fast (tf/sf>1.0)', ...
            median(P(fast,3)), median(tfPref(fast,1)), median(tfPref(fast,2)));
    fprintf(out, '\nPeak response, median: B %.4f | A %.4f (A/B = %.2f)\n', ...
            median(peakResp(:,1)), median(peakResp(:,2)), ...
            median(peakResp(:,2))/median(peakResp(:,1)));
end
fclose(fid);

save(fullfile(repoRoot, 'explore', '_figs', 'preferredTfSf.mat'), ...
     'V', 'P', 'sfPref', 'tfPref', 'peakResp', 'SF_GRID', 'TF_GRID', 'Wname');
