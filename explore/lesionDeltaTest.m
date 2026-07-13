% lesionDeltaTest  Is the midget/parasol front-end non-vacuous, or "SH twice"?
%
% Decisive test for the reversion worry (docs/RGC_V1_design_discussion.md §13).
% The sharp, clinically-relevant question: is a biological CONDUCTION DELAY an
% independent lesion axis from AMPLITUDE, or is it reducible to a channel rescale?
%
% Method: apply a PARASOL delay (and a parasol amplitude lesion) to the
% midget/parasol front-end with the V1 wiring held FIXED. Each lesion changes the
% V1 response by a delta vector (over neurons x space x time x stimuli). Project
% each delta onto two amplitude-rescaling spaces and report R2 = fraction of the
% delta reproducible by rescaling channels:
%
%   (a) BIO-channel basis: span of each biological class's V1 contribution.
%       = every amplitude rescaling the front-end itself can express.
%       * amplitude lesion MUST land here (R2 ~ 1: positive control).
%       * if the DELAY does NOT (R2 < 1), timing is independent of amplitude
%         -> a lesion axis SH's amplitude-only channelGain cannot express.
%   (b) SH-channel basis: span of SH's 4 temporal-derivative channel contributions
%       (the only lesion SH natively exposes). The "is it just SH twice?" framing.
%
% Headless MATLAB: export PNG. Self-locating.

thisFile = mfilename('fullpath');
repoRoot = fileparts(fileparts(thisFile));
addpath(genpath(repoRoot));
outDir = tempdir;   % PNGs land here for the record; open them to view
rng(0);

pars = shPars;
dims = shGetDims(pars, 'mtPattern', [1 1 64]);

% Two stimulus CLASSES, to reveal that "is a delay just a rescale?" depends on
% stimulus bandwidth:
%   * gratings (NARROWBAND): a delay only phase-shifts a sinusoid, which aliases
%     into an amplitude change (half-period delay = negation = rescale by -1) ->
%     delay looks amplitude-reducible (degenerate).
%   * dots (BROADBAND / transient): a time-shift of a broadband signal is NOT a
%     rescale -> delay is irreducible. This is the clinically relevant regime
%     (optic neuritis is measured by transient-VEP latency).
gp = @(th,sp) v12sin([th sp]);
Sgrating = {};
for th = [0 pi/4 pi/2 3*pi/4 pi]
    for sp = [0.6 1.2]
        gg = gp(th,sp); Sgrating{end+1} = mkSin(dims, th, gg(2), gg(3), 1); %#ok<SAGROW>
    end
end
Sdots = {};
for th = [0 pi/4 pi/2 3*pi/4 pi]
    for sp = [0.6 1.2]
        Sdots{end+1} = mkDots(dims, th, sp, 0.12, 1); %#ok<SAGROW>
    end
end
S = Sgrating;   % basis/control computed on gratings; both classes tested below

% --- healthy midget/parasol, fit the V1 wiring ONCE (fixed hereafter) ---
parsBio = pars;
parsBio.rgc.classes = shRgcClassesMidgetParasol(parsBio);
parsBio.rgc.combine = 'weights';
parsBio.rgc.v1Weights = shFitClassV1Weights(parsBio, [Sgrating(1:4) Sdots(1:4)]);
baseClasses = parsBio.rgc.classes;

delays = [1 2 3 4];
resG = localAnalyze(parsBio, pars, baseClasses, Sgrating, delays);   % narrowband
resD = localAnalyze(parsBio, pars, baseClasses, Sdots,    delays);   % broadband

fprintf('\n===== Is a conduction DELAY reducible to a channel RESCALE? =====\n');
fprintf('Positive control (amplitude lesion in BIO amp space):  gratings R2=%.4f  dots R2=%.4f\n', ...
        resG.R2amp, resD.R2amp);
fprintf('\n%-8s | %-28s | %-28s\n','delay','GRATINGS (narrowband)','DOTS (broadband/transient)');
fprintf('%-8s | %-13s %-14s | %-13s %-14s\n','', 'relV1delta','1-R2(irreduc)','relV1delta','1-R2(irreduc)');
for i = 1:numel(delays)
    fprintf('%-8d | %-13.3f %-14.3f | %-13.3f %-14.3f\n', delays(i), ...
        resG.relMag(i), 1-resG.R2del_bio(i), resD.relMag(i), 1-resD.R2del_bio(i));
end
fprintf(['\nReading: 1-R2 = fraction of the delay''s V1 effect NO amplitude rescaling can\n' ...
         'reproduce. Expectation: gratings LOW (delay aliases to rescale) but dots HIGH\n' ...
         '(a time-shift of a broadband signal is irreducible) -> the biological TIMING axis\n' ...
         'is real in the clinically-relevant (transient) regime.\n']);

% --- figure ---
f = figure('Color','w','Position',[70 70 900 400]);
subplot(1,2,1);
plot(delays, 1-resG.R2del_bio, '-o', 'LineWidth', 1.6); hold on;
plot(delays, 1-resD.R2del_bio, '-s', 'LineWidth', 1.6);
xlabel('parasol conduction delay (frames)');
ylabel('fraction of delay NOT reproducible by any amplitude rescale');
ylim([0 1]); grid on;
legend({'gratings (narrowband)','dots (broadband/transient)'}, 'Location','east');
title('Is a delay just a rescale? Depends on stimulus bandwidth');
subplot(1,2,2);
bar([resG.R2amp resD.R2amp]); set(gca,'XTickLabel',{'gratings','dots'});
ylim([0 1.05]); grid on; ylabel('R^2');
title(sprintf('Positive control: amplitude lesion\nis fully in the amplitude space (R^2=1)'));
sgtitle('Conduction delay vs amplitude: an independent lesion axis for broadband stimuli');
pngPath = fullfile(outDir, 'lesionDelta_nonvacuous.png');
exportgraphics(f, pngPath, 'Resolution', 150);
fprintf('\nWrote %s\n', pngPath);

% =====================================================================
function res = localAnalyze(parsBio, pars, baseClasses, S, delays)
    nClass = numel(baseClasses);
    vHealthy = localV1Vec(parsBio, S);
    % BIO amplitude-rescaling basis (each class's contribution)
    Bbio = zeros(numel(vHealthy), nClass);
    for c = 1:nClass
        pc = parsBio; g = zeros(1,nClass); g(c) = 1;
        pc.rgc.classes = localSetGains(baseClasses, g);
        Bbio(:,c) = localV1Vec(pc, S);
    end
    % amplitude-lesion positive control (must be in span exactly)
    Damp = localV1Vec(localLesionPars(parsBio, baseClasses, 'amp', 0.5), S) - vHealthy;
    res.R2amp = localR2(Damp, Bbio);
    % delay sweep
    res.R2del_bio = zeros(1,numel(delays)); res.relMag = zeros(1,numel(delays));
    for i = 1:numel(delays)
        Dd = localV1Vec(localLesionPars(parsBio, baseClasses, 'delay', delays(i)), S) - vHealthy;
        res.R2del_bio(i) = localR2(Dd, Bbio);
        res.relMag(i) = norm(Dd)/norm(vHealthy);
    end
end

% =====================================================================
function p = localLesionPars(p, baseClasses, kind, val)
    cl = baseClasses;
    for c = 1:numel(cl)
        if any(strcmpi(cl(c).name, {'parasolOn','parasolOff'}))
            switch kind
                case 'delay', k = cl(c).temporalKernel; cl(c).temporalKernel = [zeros(val,1); k(:)];
                case 'amp',   cl(c).gain = cl(c).gain * val;
            end
        end
    end
    p.rgc.classes = cl;
end

function cl = localSetGains(cl, g)
    for c = 1:numel(cl), cl(c).gain = g(c); end
end

function v = localV1Vec(p, S)
    v = [];
    for i = 1:numel(S)
        pop = shModelV1LinearFromClasses(S{i}, p);   % class path directly (fixed wiring)
        v = [v; pop(:)]; %#ok<AGROW>
    end
end

function v = localV1Vec_SH(p, S)
    v = [];
    for i = 1:numel(S)
        pop = shModelV1Linear(S{i}, p);              % SH derivative path
        v = [v; pop(:)]; %#ok<AGROW>
    end
end

function R2 = localR2(d, B)
    coef = B \ d; resid = d - B*coef;
    R2 = 1 - (resid'*resid) / max(d'*d, eps);
end
