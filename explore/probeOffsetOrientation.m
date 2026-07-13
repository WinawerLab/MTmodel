% probeOffsetOrientation  Test whether the midgetParasol orientation bias is
% caused by the fixed HORIZONTAL ON/OFF spatial offset (readoutOffset along X).
%
% Compares the linear stimulus-referred V1 RF (peak-lag spatial map, INCLUDING
% the readoutOffset -- which shV1Rf omits) for four neurons, across:
%   * derivative preset (combine='steer') -- the exact analytic orientation reference
%   * midgetParasol, offset along X   ([0 +/-2])  = current preset
%   * midgetParasol, offset along Y   ([+/-2 0])
%   * midgetParasol, offset none      ([0 0])
%
% Prediction (if the offset AXIS causes the bias): rotating the offset X->Y
% rotates the orientation bias 90 deg; removing it should reduce oriented
% structure differences to whatever the fit alone produces.
%
% Headless MATLAB: figures are auto-closed by the MCP tool, so export PNG.
% Self-locating.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
outDir = tempdir;   % PNGs land here for the record; open them to view
rng(0);

pars = shPars;                                  % derivative, steer (reference)

% --- training set for the fits (same varied set as testClassPathBiological) ---
dims = shGetDims(pars, 'mtPattern', [1 1 18]);
p1 = v12sin([0 1.0]); p2 = v12sin([pi/3 1.6]); p3 = v12sin([pi 0.8]); p4 = v12sin([-pi/4 1.2]);
trainSet = { mkDots(dims,0,1.0,0.12,1), mkDots(dims,pi/2,0.7,0.12,0.7), ...
             mkSin(dims,0,p1(2),p1(3),1), mkSin(dims,pi/3,p2(2),p2(3),1), ...
             mkSin(dims,pi,p3(2),p3(3),1), mkSin(dims,-pi/4,p4(2),p4(3),1) };

% --- build the four variants ---
variants = struct('name', {}, 'pars', {});

variants(1).name = 'derivative (steer)';
variants(1).pars = pars;

offX = localMidgetParasolOffset(pars,  2, 'x');   % [0 +/-2]  current
offY = localMidgetParasolOffset(pars,  2, 'y');   % [+/-2 0]
off0 = localMidgetParasolOffset(pars,  0, 'x');   % [0 0]

for v = {offX 'mP offset X (current)'; offY 'mP offset Y'; off0 'mP offset none'}'
    p = v{1}; nm = v{2};
    p.rgc.v1Weights = shFitClassV1Weights(p, trainSet);
    variants(end+1).name = nm; %#ok<SAGROW>
    variants(end).pars = p;
end

neurons = [1 8 15 22];
nV = numel(variants); nN = numel(neurons);

% --- compute peak-lag offset-inclusive spatial RF for each (neuron, variant) ---
maps = cell(nN, nV);
oris = zeros(nN, nV);
for j = 1:nV
    for i = 1:nN
        [m, ori] = localOffsetInclusiveRF(variants(j).pars, neurons(i));
        maps{i, j} = m; oris(i, j) = ori;
    end
end

% --- plot grid: rows = neurons, cols = variants ---
cmap = [[linspace(0,1,128)' linspace(0,1,128)' ones(128,1)]; ...
        [ones(128,1) linspace(1,0,128)' linspace(1,0,128)']];
f = figure('Color','w','Position',[60 60 260*nV 240*nN]);
tl = tiledlayout(f, nN, nV, 'TileSpacing','compact','Padding','compact');
title(tl, 'Peak-lag linear V1 RF (offset-inclusive): does rotating the ON/OFF offset rotate orientation?', ...
      'FontWeight','bold');
for i = 1:nN
    for j = 1:nV
        nexttile;
        m = maps{i, j};
        cl = max(abs(m(:))); if cl==0, cl=1; end
        imagesc(m, [-cl cl]); axis image off; colormap(cmap);
        if i==1, title(variants(j).name, 'FontSize', 9, 'Interpreter','none'); end
        if j==1, ylabel(sprintf('neuron %d', neurons(i))); set(gca,'YLabel',get(gca,'YLabel')); end
        text(0.5, -0.5, sprintf('%.0f%s', oris(i,j), char(176)), 'Units','normalized', ...
             'HorizontalAlignment','center','FontSize',8,'Color',[0 0 0]);
    end
end

pngPath = fullfile(outDir, 'offsetOrientation_grid.png');
exportgraphics(f, pngPath, 'Resolution', 150);
fprintf('Wrote %s\n', pngPath);
fprintf('\nPreferred-orientation estimates (deg, peak spatial-freq angle):\n');
fprintf('%-22s', 'neuron'); for j=1:nV, fprintf('%-22s', variants(j).name); end; fprintf('\n');
for i=1:nN
    fprintf('%-22d', neurons(i));
    for j=1:nV, fprintf('%-22.0f', oris(i,j)); end
    fprintf('\n');
end

% =====================================================================
function p = localMidgetParasolOffset(pars, offset, axis)
% midgetParasol preset with the ON/OFF spatial offset set to a given magnitude
% and axis ('x' -> [0 +/-off], 'y' -> [+/-off 0]).
    p = pars;
    classes = shRgcClassesMidgetParasol(pars);   % parasolOn/Off, midgetOn/Off
    for c = 1:numel(classes)
        isOn = ~isempty(strfind(lower(classes(c).name), 'on'));
        s = (isOn) * 1 + (~isOn) * (-1);         % ON +, OFF -
        if strcmpi(axis,'x'), classes(c).readoutOffset = [0 s*offset];
        else,                 classes(c).readoutOffset = [s*offset 0]; end
    end
    p.rgc.classes = classes;
    p.rgc.combine = 'weights';
    p.rgc.classesMode = 'midgetParasol';
end

function [pkMap, oriDeg] = localOffsetInclusiveRF(p, neuronIdx)
% Linear stimulus-referred RF including the readoutOffset (circshift), which
% shV1Rf omits. Returns the peak-energy lag spatial map and its dominant
% spatial-frequency orientation (deg).
    [RFrgc, ~, info] = shV1Rf(p, neuronIdx);     % per-class weighted derivative combos
    classes = p.rgc.classes;
    fsz = size(RFrgc,1);
    nLag = 0; for c=1:numel(classes), nLag = max(nLag, numel(classes(c).temporalKernel)); end
    RFstim = zeros(fsz, fsz, nLag);
    for c = 1:numel(classes)
        sm = RFrgc(:,:,c);
        if ~isempty(classes(c).spatialRF)
            sm = localDoGSame(sm, classes(c).spatialRF);
        end
        off = classes(c).readoutOffset;
        if numel(off)==2 && any(off~=0)
            sm = circshift(sm, [off(1) off(2)]);  % the piece shV1Rf leaves out
        end
        tf = classes(c).temporalKernel;
        for tau = 1:numel(tf)
            RFstim(:,:,tau) = RFstim(:,:,tau) + sm * tf(tau);
        end
    end
    % peak-energy lag
    e = squeeze(sum(sum(RFstim.^2,1),2));
    [~, pk] = max(e);
    pkMap = RFstim(:,:,pk);
    oriDeg = localPeakOrientation(pkMap);
end

function oriDeg = localPeakOrientation(m)
% Continuous RF stripe orientation via the gradient structure tensor (robust on
% small maps). Stripe orientation = perpendicular to the dominant gradient.
    [gx, gy] = gradient(m);
    Jxx = sum(gx(:).^2); Jyy = sum(gy(:).^2); Jxy = sum(gx(:).*gy(:));
    gradDir = 0.5 * atan2(2*Jxy, Jxx - Jyy);      % dominant gradient orientation (rad)
    oriDeg = mod((gradDir + pi/2) * 180/pi, 180);  % stripe orientation
end

function out = localDoGSame(in, sp)
    cf = mkGaussianFilter(sp.centerSigma);
    sf = mkGaussianFilter(sp.surroundSigma);
    out = conv2(cf(:), cf(:)', in, 'same') - sp.surroundWeight .* conv2(sf(:), sf(:)', in, 'same');
end
