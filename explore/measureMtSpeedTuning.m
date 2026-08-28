% measureMtSpeedTuning  Measured MT speed tuning, in deg/sec, for the two ways
% to run the model (shPars and shPars('lagged')).
%
% For each probed MT neuron, sweeps dot speed with dots drifting in THAT
% neuron's preferred direction, records the mean mtPattern response, and locates
% the peak by parabolic refinement in log2 speed. Converts px/frame -> deg/sec
% with shModelUnits (5 deg/s per px/frame). Seeded per stimulus: unseeded dot
% fields confound a speed effect with dot-sample noise (AGENTS.md).
%
% RESULT (2026-08-25, and the reason this script exists). The population's
% NOMINAL speeds -- pars.mtPopulationVelocities(:,2), which are construction
% parameters for the MT pooling weights -- do NOT match the measured tuning at
% the high tier:
%
%   nominal 0 px/frame (1 neuron)   measured: low-pass, peak at or below 0.125
%   nominal 1 px/frame (6 neurons)  measured: 0.93 (derivative) / 1.03 (lagged)
%   nominal 6 px/frame (12 neurons) measured: 3.11 (derivative) / 3.67 (lagged)
%
% In deg/s at the current anchor (5 deg/s per px/frame) that is 4.7 / 5.2 for the
% 1 px/frame tier and 15.5 / 18.3 for the 6 px/frame tier. Recorded 2026-08-25
% under the old SH anchor, where the same measurements read 14.9 / 16.5 and
% 49.7 / 58.7 deg/s.
%
% The 1 px/frame tier lands on its nominal speed. The 6 px/frame tier peaks near
% HALF its nominal value, with a clean interior peak, consistent with 6 px/frame
% sitting past what the filter bank can represent (the V1 filters peak at 0.2148
% cyc/sample on both axes). Do not quote 6 px/frame as those neurons' preferred
% speed.
%
% Caveats: probes 7 of the 19 MT neurons (3 per moving tier, spanning
% directions; within-tier spread was under 0.5 px/frame, so the tiers do behave
% alike) and a 13-point speed grid, so peak locations carry roughly +/-5%.
%
% Writes explore/_figs/mtSpeedTuning.mat (gitignored; regenerable).
%
% See also: shModelUnits, shPars, explore/measurePreferredTfSf.m

repoRoot = fileparts(fileparts(mfilename('fullpath')));
OUTDIR   = fullfile(repoRoot, 'explore', '_figs');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end
PROG     = fullfile(OUTDIR, 'mtSpeedTuning_progress.txt');
u       = shModelUnits();
K       = u.degPerSecPerPixelPerFrame;      % 5 deg/s per px/frame
SPEEDS  = 2 .^ linspace(-3, 4, 13);         % px/frame: 0.125 .. 16
NF      = 71;

configs = {'derivative', shPars; 'lagged (both streams)', shPars('lagged')};

V = configs{1,2}.mtPopulationVelocities;
nomSpeeds = [0 1 6];
% Measure 3 neurons per moving group (spanning directions) to check that
% same-speed neurons really do share a speed tuning; 1 for the static group.
probe = [];
for nv = nomSpeeds
    g = find(abs(V(:,2) - nv) < 1e-9);
    if nv == 0, pick = g(1); else, pick = g(round(linspace(1, numel(g), 3))); end
    probe = [probe; pick(:)]; %#ok<AGROW>
end
probe = unique(probe, 'stable');

fid = fopen(PROG,'w'); fprintf(fid,'probing neurons %s\n', mat2str(probe')); fclose(fid);

out = struct();
for ci = 1:size(configs,1)
    name = configs{ci,1}; pars = configs{ci,2};
    dims = shGetDims(pars, 'mtPattern', [25 25 NF]);
    curves = nan(numel(probe), numel(SPEEDS));
    t0 = tic;
    for k = 1:numel(probe)
        n = probe(k);
        for si = 1:numel(SPEEDS)
            rng(1000*n + si);
            s = mkDots(dims, V(n,1), SPEEDS(si), 0.12, 1, 3, 'exact');
            pop = shModel(s, pars, 'mtPattern');
            curves(k, si) = mean(pop(:, n));
        end
        fid=fopen(PROG,'a'); fprintf(fid,'%s: neuron %d (%d/%d) %.0fs\n', name, n, k, numel(probe), toc(t0)); fclose(fid);
    end
    prefPx = nan(numel(probe),1);
    for k = 1:numel(probe)
        c = curves(k,:); [~, i0] = max(c);
        if i0 > 1 && i0 < numel(SPEEDS)
            x = log2(SPEEDS(i0-1:i0+1)); y = c(i0-1:i0+1);
            d = y(1) - 2*y(2) + y(3);
            if d ~= 0
                prefPx(k) = 2 ^ (x(2) + 0.5*(y(1)-y(3))/d * (x(2)-x(1)));
            else, prefPx(k) = SPEEDS(i0); end
        else, prefPx(k) = SPEEDS(i0); end
    end
    out(ci).name = name; out(ci).prefPx = prefPx; out(ci).curves = curves;
end

% ---------------- report ----------------
fprintf('\n1 px/frame = %g deg/s   (shModelUnits)\n\n', K);
fprintf('%-6s %-9s %-12s | %-16s | %-16s\n','neuron','dir(rad)','nominal','derivative','lagged (A+B)');
fprintf('%s\n', repmat('-',1,74));
for k = 1:numel(probe)
    n = probe(k);
    fprintf('%-6d %-9.3f %-4g px/fr %3.0f | %7.2f px/fr %6.1f | %7.2f px/fr %6.1f\n', ...
        n, V(n,1), V(n,2), V(n,2)*K, ...
        out(1).prefPx(k), out(1).prefPx(k)*K, out(2).prefPx(k), out(2).prefPx(k)*K);
end
fprintf('\nBy nominal speed group (deg/s):\n');
for nv = nomSpeeds
    sel = abs(V(probe,2) - nv) < 1e-9;
    fprintf('  nominal %3g deg/s : derivative %6.1f [%.1f-%.1f] | lagged %6.1f [%.1f-%.1f]\n', ...
        nv*K, median(out(1).prefPx(sel))*K, min(out(1).prefPx(sel))*K, max(out(1).prefPx(sel))*K, ...
              median(out(2).prefPx(sel))*K, min(out(2).prefPx(sel))*K, max(out(2).prefPx(sel))*K);
end
fprintf('\nSpeed grid (deg/s): %s\n', mat2str(round(SPEEDS*K,1)));
save(fullfile(OUTDIR,'mtSpeedTuning.mat'),'out','V','SPEEDS','K','probe');
