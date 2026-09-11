% [stim, info] = mkMotionLetter(stimSz, letter, ...)
%
% Motion-defined letter stimulus (Regan-style): letter dots drift right,
% background dots drift left; each is visible only inside/outside the letter mask.
%
% When referenceDisplaySize is set (default [960 1280], matching Experiment.m),
% dot size, letter size, and speed are scaled to stimSz so proportions match
% the booth display. The letter mask is rendered at the output field size with
% a proportionally scaled Sloan (or fallback) font — the mask is never
% imresize'd from booth resolution (that blurs Sloan letterforms).
% Pass referenceDisplaySize = [] to build directly at stimSz with no scaling.
%
% UNITS — read this before setting a speed. Angular parameters (dotSpeedDegS,
% letterSizeArcmin) convert through info.ppd, the pixels-per-degree of the
% OUTPUT field. By default that comes from the display geometry
% (screenWidthCm / viewDistCm), giving ~100 px/deg at booth resolution. The
% MODEL's own scale is 10 px/deg and 50 frames/sec (shModelUnits), i.e. about
% 10x coarser, so a speed converted with booth geometry lands far below the
% speeds the MT population is tuned to. To work in the model's units:
%
%   u = shModelUnits();
%   stim = mkMotionLetter(sz, 'C', 'referenceDisplaySize', [], ...
%       'ppd', u.pixelsPerDegree, 'frameRate', u.framesPerSecond, ...
%       'dotSpeedDegS', 5);          % -> 1 px/frame, as intended
%
% Passing ppd overrides the display geometry entirely. letterSizePx, when
% given, is in output-field pixels.
%
% COHERENCE AND DOT LIFETIME. By default every dot moves with its population
% (letter dots one way, background dots the other) for the whole movie. Two
% options degrade that, as in the speed-by-coherence experiment:
%
%   'coherence'          fraction of dots that are SIGNAL dots. DEFAULT = 1.
%                        Each dot is labelled signal or noise when it is born,
%                        independently, with probability 'coherence'. A noise
%                        dot moves at the same speed in a direction drawn
%                        uniformly from 0-360 deg, and keeps that direction for
%                        its life. Signal and noise dots look the same, and
%                        each stays in its own region (letter or background)
%                        exactly as before.
%   'dotLifetimeFrames'  frames a dot lives before it is replotted at a random
%                        position, with a fresh signal/noise label and, if it
%                        is a noise dot, a fresh direction. DEFAULT = Inf.
%                        Starting ages are staggered, so dots are not all
%                        replotted on the same frame. The experiment's 100 ms
%                        is 5 frames at the model's 50 frames/sec.
%
% These rules match the current experiment code (runSingleTrial.m, checked
% 2026-09-11; see docs/FORM_FROM_MOTION.md).
%
% DIRECTION AND DOT RENDERING.
%
%   'motionAngleDeg'     direction of the letter's signal dots, in degrees:
%                        0 = right, 90 = down, 180 = left. DEFAULT = 0. The
%                        background moves at backgroundVelocityScale times the
%                        letter's velocity. The booth picks 0 or 180 at random
%                        on each trial.
%   'dotRendering'       'pixel' (DEFAULT) stamps each dot as whole pixels of
%                        dotSize x dotSize, as before. 'area' draws each dot as
%                        its area, pi*(dotSize/2)^2, shared among the four
%                        pixels around its centre, and the covered fraction of
%                        each pixel (capped at 1) sets its brightness. dotSize
%                        is then NOT rounded, so it can be under a pixel. This
%                        is the booth stimulus averaged onto the model's grid:
%                        the booth dot, 2.4 arcmin, is 0.4 model pixels. Meant
%                        for dots up to about a pixel; dots wrap at the edges.
%
% With coherence = 1, dotLifetimeFrames = Inf, motionAngleDeg = 0 and
% dotRendering = 'pixel', the movie is identical, dot for dot, to the one made
% before these options existed.
%
% 'letterMask' supplies a precomputed [Y X] mask (mkLetterMask at this field
% size) and skips rendering the letter, which dominates the cost of short
% movies. letterSizePx is then only reported back, not used.
%
% NOTE: two calls with the same seed but different stimSz do NOT produce the
% same dot sample — the field area sets the dot count, so the random draws
% differ in length. Build once and resize if you need matched samples.
%
% See also: shModelUnits, mkLetterMask, explore/showMotionLetter.m,
%           playStimMovie, playStimMovieCompare

function [stim, info] = mkMotionLetter(stimSz, letter, varargin)

    p = inputParser;
    p.addParameter('dotSpeedDegS', 0.45);
    p.addParameter('dotSpeedPxPerFrame', []);
    p.addParameter('letterSizeArcmin', 168);
    p.addParameter('letterSizePx', []);
    p.addParameter('dotContrast', 1.0);
    p.addParameter('dotSize', 4);
    p.addParameter('dotShape', 'square');
    p.addParameter('dotRendering', 'pixel');
    p.addParameter('referenceDisplaySize', [960 1280]);
    p.addParameter('fCovered', 0.5);
    p.addParameter('drawBackgroundDots', true);
    % Background velocity as a multiple of the letter's. -1 = opposite drift
    % (the Regan stimulus); +1 = SAME drift, which removes all relative motion
    % and so should make the letter unrecoverable -- the control condition that
    % shows a model is segregating from motion and not from some other cue;
    % 0 = static background.
    p.addParameter('backgroundVelocityScale', -1);
    p.addParameter('motionAngleDeg', 0);
    p.addParameter('coherence', 1);
    p.addParameter('dotLifetimeFrames', Inf);
    p.addParameter('letterMask', []);
    p.addParameter('fontName', 'Sloan');
    p.addParameter('background', 0.5);
    p.addParameter('frameRate', 60);
    p.addParameter('ppd', []);
    p.addParameter('screenWidthCm', 39);
    p.addParameter('viewDistCm', 175);
    p.addParameter('seed', []);
    p.parse(varargin{:});
    opts = p.Results;

    if numel(stimSz) ~= 3
        error('mkMotionLetter:stimSz', 'stimSz must be [Y X T].');
    end
    letter = char(letter);
    if numel(letter) ~= 1
        error('mkMotionLetter:letter', 'letter must be a single character.');
    end
    if ~isscalar(opts.coherence) || opts.coherence < 0 || opts.coherence > 1
        error('mkMotionLetter:coherence', 'coherence must be a scalar in [0 1].');
    end
    lifetime = opts.dotLifetimeFrames;
    if ~isscalar(lifetime) || ~(isinf(lifetime) || (lifetime >= 1 && lifetime == round(lifetime)))
        error('mkMotionLetter:dotLifetimeFrames', ...
            'dotLifetimeFrames must be a positive integer or Inf.');
    end
    if ~isscalar(opts.motionAngleDeg) || ~isfinite(opts.motionAngleDeg)
        error('mkMotionLetter:motionAngleDeg', 'motionAngleDeg must be a finite scalar, in degrees.');
    end
    dotRendering = lower(char(opts.dotRendering));
    if ~any(strcmp(dotRendering, {'pixel', 'area'}))
        error('mkMotionLetter:dotRendering', ...
            'dotRendering must be ''pixel'' or ''area'', got ''%s''.', dotRendering);
    end

    genY = stimSz(1);
    genX = stimSz(2);
    numFrames = stimSz(3);

    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    refSize = opts.referenceDisplaySize;
    if isempty(refSize)
        fieldScale = 1;
        ppdRef = localPpd(genX, opts.screenWidthCm, opts.viewDistCm);
    else
        if numel(refSize) ~= 2
            error('mkMotionLetter:referenceDisplaySize', 'referenceDisplaySize must be [Y X].');
        end
        fieldScale = min(genY / refSize(1), genX / refSize(2));
        ppdRef = localPpd(refSize(2), opts.screenWidthCm, opts.viewDistCm);
    end

    % Pixels-per-degree of the OUTPUT field, which is what every angular
    % quantity below must convert through. Supplying ppd overrides the display
    % geometry entirely -- that is how a caller asks for the model's own scale
    % (shModelUnits: 10 px/deg) rather than a booth's (~100 px/deg).
    if ~isempty(opts.ppd)
        ppdField = opts.ppd;
    else
        ppdField = ppdRef * fieldScale;
    end
    if ppdField <= 0
        error('mkMotionLetter:ppd', 'Effective pixels-per-degree must be positive.');
    end

    if strcmp(dotRendering, 'area')
        dotSizePx = opts.dotSize * fieldScale;      % may be under a pixel
        if dotSizePx <= 0
            error('mkMotionLetter:dotSize', 'dotSize must be positive.');
        end
        if dotSizePx > 1.5
            warning('mkMotionLetter:areaDotSize', ...
                ['dotRendering ''area'' shares each dot among 4 pixels, which suits ' ...
                 'dots up to about a pixel; this dot is %.2f px.'], dotSizePx);
        end
    else
        dotSizePx = max(1, round(opts.dotSize * fieldScale));
    end

    if ~isempty(opts.dotSpeedPxPerFrame)
        speedPxPerFrame = opts.dotSpeedPxPerFrame;
        speedPxPerSec = speedPxPerFrame * opts.frameRate;
        dotSpeedDegS = speedPxPerSec / ppdField;
    else
        dotSpeedDegS = opts.dotSpeedDegS;
        speedPxPerSec = dotSpeedDegS * ppdField;
        speedPxPerFrame = speedPxPerSec / opts.frameRate;
    end

    grey = opts.background;
    dotValue = grey + opts.dotContrast * (1 - grey);

    % letterSizePx, when given, is in OUTPUT FIELD pixels (as its name says);
    % otherwise the angular size converts through the same ppdField as speed.
    if ~isempty(opts.letterSizePx)
        letterSizePx = round(opts.letterSizePx);
    else
        letterSizePx = round((opts.letterSizeArcmin / 60) * ppdField);
    end
    letterSizePx = max(8, letterSizePx);
    letterSizeBooth = round(letterSizePx / max(fieldScale, eps));

    if isempty(opts.letterMask)
        [binaryMask, fontUsed] = mkLetterMask([genY genX], letter, ...
            letterSizePx, opts.fontName, grey);
    else
        binaryMask = logical(opts.letterMask);
        if ~isequal(size(binaryMask), [genY genX])
            error('mkMotionLetter:letterMask', ...
                'letterMask must be [%d %d] to match the field, got %s.', ...
                genY, genX, mat2str(size(binaryMask)));
        end
        fontUsed = 'precomputed';
    end

    motion = struct('speedPxPerSec', speedPxPerSec, 'angleDeg', opts.motionAngleDeg, ...
        'bgVelocityScale', opts.backgroundVelocityScale, 'coherence', opts.coherence, ...
        'lifetimeFrames', lifetime);
    [stim, buildInfo] = localBuildMovie(genY, genX, numFrames, binaryMask, ...
        dotSizePx, opts.dotShape, dotRendering, opts.fCovered, grey, dotValue, ...
        opts.frameRate, opts.drawBackgroundDots, motion);

    info = buildInfo;
    info.letter = letter;
    info.letterSizePx = letterSizePx;
    info.letterSizeBoothPx = letterSizeBooth;
    info.letterSizeArcmin = opts.letterSizeArcmin;
    info.dotSpeedDegS = dotSpeedDegS;
    info.dotSpeedPxPerSec = speedPxPerSec;
    info.dotSpeedPxPerFrame = speedPxPerFrame;
    info.motionAngleDeg = opts.motionAngleDeg;
    info.coherence = opts.coherence;
    info.dotLifetimeFrames = lifetime;
    info.dotContrast = opts.dotContrast;
    info.dotSize = dotSizePx;
    info.dotSizeNominal = opts.dotSize;
    info.dotRendering = dotRendering;
    info.fieldScale = fieldScale;
    info.referenceDisplaySize = refSize;
    info.dotShape = opts.dotShape;
    info.fCovered = opts.fCovered;
    info.drawBackgroundDots = opts.drawBackgroundDots;
    info.frameRate = opts.frameRate;
    info.ppd = ppdField;            % pixels/deg of the OUTPUT field
    info.ppdReference = ppdRef;     % pixels/deg of the reference display
    info.letterSizeDeg = letterSizePx / ppdField;
    info.fontName = fontUsed;
    info.fontRequested = opts.fontName;
    info.background = grey;
    info.dotValue = dotValue;
    info.binaryMask = binaryMask;
    info.pixelsPerLetter = sum(binaryMask(:));
    info.outputSize = [genY genX numFrames];

end

% -------------------------------------------------------------------------
% motion: speedPxPerSec, angleDeg, bgVelocityScale, coherence, lifetimeFrames
function [stim, info] = localBuildMovie(genY, genX, numFrames, binaryMask, ...
        dotSizePx, dotShape, dotRendering, fCovered, grey, dotValue, ...
        frameRate, drawBackgroundDots, motion)

    screenArea = genX * genY;
    dotArea = pi * (dotSizePx / 2)^2;
    numDots = max(1, round(fCovered * screenArea / dotArea));

    offX = (genX - size(binaryMask, 2)) / 2;
    offY = (genY - size(binaryMask, 1)) / 2;

    % The order of these four draws fixes the dot sample for a given seed.
    % Keep it, so that default movies stay reproducible.
    initialLtX = rand(1, numDots) * genX;
    initialLtY = rand(1, numDots) * genY;
    initialBgX = rand(1, numDots) * genX;
    initialBgY = rand(1, numDots) * genY;

    % Signal velocity of each population, px/sec. cosd and sind are exact at
    % multiples of 90 deg, so the default (0 deg) reproduces the old
    % rightward-only movie bit for bit.
    direction = [cosd(motion.angleDeg), sind(motion.angleDeg)];
    ltVelocity = motion.speedPxPerSec * direction;
    bgVelocity = (motion.bgVelocityScale * motion.speedPxPerSec) * direction;
    lt = localInitDots(initialLtX, initialLtY, ltVelocity, motion.coherence, motion.lifetimeFrames);
    bg = localInitDots(initialBgX, initialBgY, bgVelocity, motion.coherence, motion.lifetimeFrames);

    areaDots = strcmp(dotRendering, 'area');
    if ~areaDots
        dotTpl = localDotTemplate(dotSizePx, dotShape);
    end

    stim = repmat(grey, [genY, genX, numFrames]);
    letterContrastFrame = zeros(1, numFrames);
    N_letterPixels = sum(binaryMask(:));
    pixelsPerDot = pi * (dotSizePx / 2)^2;

    for t = 1:numFrames
        elapsed = (t - 1) / frameRate;
        lt = localRebirth(lt, elapsed, motion.lifetimeFrames, motion.coherence, genX, genY);
        bg = localRebirth(bg, elapsed, motion.lifetimeFrames, motion.coherence, genX, genY);
        [ltX, ltY] = localDotPositions(lt, elapsed, genX, genY);
        [bgX, bgY] = localDotPositions(bg, elapsed, genX, genY);

        inside = localDotsInsideLetter(ltX, ltY, binaryMask, offX, offY);
        if drawBackgroundDots
            outside = localDotsOutsideLetter(bgX, bgY, binaryMask, offX, offY);
        else
            outside = false(size(bgX));
        end

        if areaDots
            coverage = localDepositDots(zeros(genY, genX), ...
                [bgX(outside), ltX(inside)], [bgY(outside), ltY(inside)], dotArea);
            frame = grey + (dotValue - grey) * min(coverage, 1);
        else
            frame = repmat(grey, genY, genX);
            frame = localStampDots(frame, bgX(outside), bgY(outside), dotTpl, dotValue, genX, genY);
            frame = localStampDots(frame, ltX(inside), ltY(inside), dotTpl, dotValue, genX, genY);
        end

        if N_letterPixels > 0
            nDotsInLetter = sum(inside);
            letterContrastFrame(t) = min(nDotsInLetter * pixelsPerDot / N_letterPixels, 1);
        end

        stim(:, :, t) = min(frame, 1);

        lt.age = lt.age + 1;
        bg.age = bg.age + 1;
    end

    info = struct();
    info.numDots = numDots;
    info.letterContrast = mean(letterContrastFrame);
    info.letterContrastFrame = letterContrastFrame;

end

% One population of dots. Each dot moves in a straight line from where and
% when it was born: position = birth position + velocity * (time since birth),
% wrapped. With coherence 1 and infinite lifetime this reduces, bit for bit, to
% the old rule position = initial + signalVelocity * elapsed.
function d = localInitDots(x0, y0, signalVelocity, coherence, lifetimeFrames)
    n = numel(x0);
    d.x0 = x0;
    d.y0 = y0;
    d.tBirth = zeros(1, n);
    d.signalVx = signalVelocity(1);
    d.signalVy = signalVelocity(2);
    d.speed = hypot(signalVelocity(1), signalVelocity(2));
    d.vx = repmat(d.signalVx, 1, n);
    d.vy = repmat(d.signalVy, 1, n);
    if coherence < 1
        d = localAssignNoise(d, 1:n, coherence);
    end
    if isfinite(lifetimeFrames)
        d.age = floor(rand(1, n) * lifetimeFrames);   % staggered, 0 .. L-1
    else
        d.age = zeros(1, n);
    end
end

% Label dots idx signal (probability = coherence) or noise; noise dots get a
% random direction at the population's speed.
function d = localAssignNoise(d, idx, coherence)
    isNoise = rand(1, numel(idx)) >= coherence;
    theta = 2 * pi * rand(1, numel(idx));
    d.vx(idx) = d.signalVx;
    d.vy(idx) = d.signalVy;
    d.vx(idx(isNoise)) = d.speed * cos(theta(isNoise));
    d.vy(idx(isNoise)) = d.speed * sin(theta(isNoise));
end

% Replot every dot that has reached the end of its life.
function d = localRebirth(d, elapsed, lifetimeFrames, coherence, genX, genY)
    if ~isfinite(lifetimeFrames)
        return;
    end
    idx = find(d.age >= lifetimeFrames);
    if isempty(idx)
        return;
    end
    d.x0(idx) = rand(1, numel(idx)) * genX;
    d.y0(idx) = rand(1, numel(idx)) * genY;
    d.tBirth(idx) = elapsed;
    d.age(idx) = 0;
    if coherence < 1
        d = localAssignNoise(d, idx, coherence);
    end
end

function [x, y] = localDotPositions(d, elapsed, genX, genY)
    dt = elapsed - d.tBirth;
    x = mod(d.x0 + d.vx .* dt, genX);
    y = mod(d.y0 + d.vy .* dt, genY);
end

function ppd = localPpd(screenWidthPx, screenWidthCm, viewDistCm)
    ppd = pi * screenWidthPx / (atan(screenWidthCm / (2 * viewDistCm)) * 360);
end

function tpl = localDotTemplate(dotSize, dotShape)
    dotSize = max(1, round(dotSize));
    rad = floor(dotSize / 2);
    offsets = (-rad):(dotSize - rad - 1);
    [dy, dx] = ndgrid(offsets, offsets);
    switch lower(dotShape)
        case 'square'
            tpl.mask = true(size(dx));
        case 'disk'
            tpl.mask = (dx.^2 + dy.^2) <= (dotSize / 2)^2;
        otherwise
            error('mkMotionLetter:dotShape', 'dotShape must be ''square'' or ''disk''.');
    end
    tpl.offsets = offsets;
end

% Stamp every dot at once: one column per template pixel, one row per dot.
% Every stamped pixel gets the same value, so the result does not depend on
% the order in which dots are drawn.
function frame = localStampDots(frame, xs, ys, tpl, dotValue, screenX, screenY)
    if isempty(xs)
        return;
    end
    [dy, dx] = ndgrid(tpl.offsets, tpl.offsets);
    dx = dx(tpl.mask);
    dy = dy(tpl.mask);
    cx = localWrapIndex(round(xs(:)), screenX);
    cy = localWrapIndex(round(ys(:)), screenY);
    cols = cx + dx.';
    rows = cy + dy.';
    valid = cols >= 1 & cols <= screenX & rows >= 1 & rows <= screenY;
    frame(sub2ind(size(frame), rows(valid), cols(valid))) = dotValue;
end

% Area-weighted dots. Each dot's area is shared among the four pixels around
% its centre, bilinearly: the nearer a pixel, the larger its share. Pixel k is
% centred on position k, the convention round() uses in localStampDots, and
% positions wrap at the edges.
function coverage = localDepositDots(coverage, xs, ys, dotArea)
    if isempty(xs)
        return;
    end
    [screenY, screenX] = size(coverage);
    x0 = floor(xs(:));
    y0 = floor(ys(:));
    fx = xs(:) - x0;
    fy = ys(:) - y0;
    cols = mod([x0, x0 + 1, x0, x0 + 1] - 1, screenX) + 1;
    rows = mod([y0, y0, y0 + 1, y0 + 1] - 1, screenY) + 1;
    weights = dotArea * [(1 - fx) .* (1 - fy), fx .* (1 - fy), (1 - fx) .* fy, fx .* fy];
    coverage = coverage + accumarray([rows(:), cols(:)], weights(:), [screenY, screenX]);
end

function idx = localWrapIndex(idx, n)
    idx = mod(idx - 1, n) + 1;
end

function inside = localDotsInsideLetter(xs, ys, binaryMask, offX, offY)
    maskH = size(binaryMask, 1);
    maskW = size(binaryMask, 2);
    inside = false(size(xs));
    ltX = round(xs - offX);
    ltY = round(ys - offY);
    valid = ltX >= 1 & ltX <= maskW & ltY >= 1 & ltY <= maskH;
    if any(valid)
        idx = sub2ind(size(binaryMask), ltY(valid), ltX(valid));
        inside(valid) = binaryMask(idx);
    end
end

function outside = localDotsOutsideLetter(xs, ys, binaryMask, offX, offY)
    maskH = size(binaryMask, 1);
    maskW = size(binaryMask, 2);
    outside = true(size(xs));
    bgX = round(xs - offX);
    bgY = round(ys - offY);
    valid = bgX >= 1 & bgX <= maskW & bgY >= 1 & bgY <= maskH;
    if any(valid)
        idx = sub2ind(size(binaryMask), bgY(valid), bgX(valid));
        outside(valid) = ~binaryMask(idx);
    end
end
