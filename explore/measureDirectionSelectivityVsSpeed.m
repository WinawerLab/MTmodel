% measureDirectionSelectivityVsSpeed
%
% How much direction signal does V1 carry at the speeds the optic-neuritis
% literature actually uses? Sweeps stimulus speed and measures, for every V1
% neuron, the direction-selectivity index
%
%   DSI = (Rpref - Rnull) / (Rpref + Rnull)
%
% at the v1Complex stage, where Rpref/Rnull are the responses to a grating
% drifting in the neuron's preferred direction and in the opposite direction at
% the same speed.
%
% WHY THIS EXISTS. It is easy to look at the front end -- the parasol kernel has
% DC = +0.234, the parasol DoG passes 0.75 of DC, and the lagged preset never
% applies pars.v1TemporalFilters at all (shClassV1Basis uses v1SpatialFilters for
% the SPATIAL read-out only; temporal filtering is each class's own causal
% kernel plus its frame lag) -- and conclude that nothing blocks low temporal
% frequencies, so there is no lower limit on the speeds the model can see.
%
% The front end is described correctly there. The conclusion does not follow.
% Responding to a slow stimulus and telling its direction are different
% quantities, and only the second is what the object-from-motion task needs:
%
%   * At exactly zero speed the preferred-direction and null-direction stimuli
%     are the SAME movie, so Rpref = Rnull and DSI = 0 identically. This holds
%     for any system whatever -- no assumption about DC, filter shape, or
%     linearity.
%   * Just above zero, Rpref and Rnull are both smooth in speed s and equal at
%     s = 0, so their difference is 2R'(0)s + O(s^3) while their sum tends to
%     2R(0). DSI therefore grows LINEARLY from zero.
%
% So the slow-speed limit is a collapse of direction CONTRAST onto a large
% direction-blind pedestal, not a low-frequency cutoff in responsiveness. It is
% graded, not a wall: at the slow end the model still responds, and still has a
% little direction signal, but nothing like enough to segment an object whose
% only cue is the direction difference across its boundary.
%
% Units come from shModelUnits (docs/UNITS_AND_SCALE.md):
% 1 pixel = 0.1 deg, 1 frame = 20 ms, so 1 px/frame = 5 deg/sec.
%
% SEE ALSO: docs/UNITS_AND_SCALE.md section 6, optic neuritis targets/NOTES.md

clear; clc;
thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));

U          = shModelUnits();
DEG_PER_S  = U.degPerPixel * U.framesPerSecond;      % deg/sec per (px/frame)

% The speeds the targets are stated at, plus two the model is comfortable with.
% Raz et al. (2012) ran 0.05-2 deg/s; Regan et al. (1991) topped out at 0.9 deg/s
% relative. See "optic neuritis targets/".
SPEEDS_DEG = [0 0.05 0.10 0.25 0.50 1 2 5 10];

pars = shPars('lagged');
V    = pars.v1PopulationDirections;
P    = v12sin(V);                                    % [dir, sf c/px, tf c/fr]
nN   = size(V, 1);
sz   = shGetDims(pars, 'v1Complex', [1 1 31]);

dsi = nan(nN, numel(SPEEDS_DEG));
tot = nan(nN, numel(SPEEDS_DEG));

tAll = tic;
for k = 1:numel(SPEEDS_DEG)
    sPx = SPEEDS_DEG(k) / DEG_PER_S;                 % px/frame
    for i = 1:nN
        sf = P(i, 2);                                % hold sf at the neuron's preferred
        tf = sPx * sf;                               % speed = tf/sf
        sPref = mkSin(sz, V(i, 1),          sf, tf, 1);
        sNull = mkSin(sz, V(i, 1) + pi,     sf, tf, 1);
        [popP, ind] = shModel(sPref, pars, 'v1Complex');
        popN        = shModel(sNull, pars, 'v1Complex');
        rP = mean(shGetNeuron(popP, ind, i));
        rN = mean(shGetNeuron(popN, ind, i));
        dsi(i, k) = (rP - rN) / (rP + rN);
        tot(i, k) = rP + rN;
    end
    fprintf('%5.2f deg/s done (%.0fs)\n', SPEEDS_DEG(k), toc(tAll));
end

% ---------------------------------------------------------------- output
outDir = fullfile(repoRoot, 'explore', '_figs');
if ~exist(outDir, 'dir'), mkdir(outDir); end
outTxt = fullfile(outDir, 'directionSelectivityVsSpeed.txt');
fid = fopen(outTxt, 'w');
for out = [1 fid]
    fprintf(out, 'Direction selectivity vs stimulus speed, lagged preset, v1Complex\n');
    fprintf(out, '1 px/frame = %.1f deg/sec (shModelUnits)\n', DEG_PER_S);
    fprintf(out, 'DSI = (Rpref - Rnull)/(Rpref + Rnull), each neuron at its own preferred sf.\n\n');
    fprintf(out, '%12s %10s | %9s %9s %9s | %12s\n', ...
            'speed deg/s', 'px/frame', 'median', 'max', 'frac of', 'total resp');
    fprintf(out, '%12s %10s | %9s %9s %9s | %12s\n', '', '', '|DSI|', '|DSI|', 'max DSI', 'Rpref+Rnull');
    fprintf(out, '%s\n', repmat('-', 1, 72));
    refMed = median(abs(dsi(:, end - 2)));           % the 2 deg/s column
    for k = 1:numel(SPEEDS_DEG)
        a = abs(dsi(:, k));
        fprintf(out, '%12.2f %10.4f | %9.4f %9.4f %9.3f | %12.5g\n', ...
                SPEEDS_DEG(k), SPEEDS_DEG(k) / DEG_PER_S, ...
                median(a), max(a), median(a) / refMed, median(tot(:, k)));
    end
    fprintf(out, '\nThe zero-speed row must be exactly 0 -- it is the same movie twice.\n');
    fprintf(out, 'A nonzero value there is a bug in this script, not a model result.\n');
end
fclose(fid);
fprintf('\nwrote %s\n', outTxt);
