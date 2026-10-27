function [movie, info] = mkBoothLetterMovie(letterMask, booth, options)
% mkBoothLetterMovie  Motion-defined letter drawn as on the booth display, averaged into model pixels and frames.
%
%   movie = mkBoothLetterMovie(letterMask, booth) draws one trial of the
%   motion-defined letter task the way the experiment code draws it
%   (runSingleTrial.m of the Coherence Experiment, checked 2026-09-13), frame
%   by frame at the booth's resolution and frame rate. Each booth frame is
%   then averaged into the model's pixels, and the frames shown during each
%   model frame are averaged in time. The model therefore sees the booth
%   image through its own pixels and frames.
%
%   How the booth draws a trial, and so how this function draws it:
%     - Two populations of dots, letter and background. Each has enough dots
%       to cover booth.fractionCovered of the screen.
%     - Each dot is a signal dot with probability Coherence. Signal dots move
%       in the trial's direction (letter) or at BackgroundVelocityScale times
%       it (background); a noise dot moves at the same speed in its own
%       random direction. Dots wrap around the screen.
%     - Limited lifetime: each dot starts with a random remaining life
%       between 0 and booth.lifetimeSec. When its life runs out it is replotted
%       at a random position, with a new signal/noise label and a new noise
%       direction. Dots do not move, and are not replotted, on the first frame.
%     - A letter dot is drawn only if its rounded position is inside the letter
%       mask, a background dot only if it is outside.
%     - Dots are white disks of diameter booth.dotDiameterPx on grey,
%       anti-aliased: a pixel's opacity is the fraction of it the disk covers
%       (disk positions are resolved to 1/16 pixel). Overlapping dots are
%       blended over each other, as Psychtoolbox blends them, so a pixel that
%       two dots cover fully is white, not whiter.
%
%   [movie, info] = mkBoothLetterMovie(..., Name=Value)
%
%   Inputs:
%     letterMask               [screenY screenX] logical, the letter at booth
%                              resolution (mkLetterMask(booth.screenSizePx, ...))
%     booth                    from boothDisplay
%     SpeedPxPerSec            dot speed in booth pixels per second [0]
%     Coherence                fraction of signal dots [1]
%     MotionAngleDeg           direction of the letter's signal dots:
%                              0 = right, 90 = down [0]
%     BackgroundVelocityScale  background signal velocity as a multiple of the
%                              letter's [-1], as in the booth
%     LifetimeSec              dot lifetime in seconds [booth.lifetimeSec]. Inf:
%                              dots are never replotted during the trial
%
%   Outputs:
%     movie   [booth.modelSize], grey background booth.background, dots up to
%             booth.dotValue
%     info    numDots (per population), numBoothFrames, speedPxPerSec,
%             coherence, motionAngleDeg, backgroundVelocityScale, lifetimeSec
%
%   See also boothDisplay, mkLetterMask, mkMotionLetter, shRunLetterTrials

    arguments
        letterMask (:, :) logical
        booth (1,1) struct
        options.SpeedPxPerSec (1,1) double {mustBeNonnegative} = 0
        options.Coherence (1,1) double {mustBeBetween(options.Coherence, 0, 1)} = 1
        options.MotionAngleDeg (1,1) double = 0
        options.BackgroundVelocityScale (1,1) double = -1
        options.LifetimeSec (1,1) double {mustBePositive} = booth.lifetimeSec
    end

    screenY = booth.screenSizePx(1);
    screenX = booth.screenSizePx(2);
    if ~isequal(size(letterMask), [screenY screenX])
        error("mkBoothLetterMovie:maskSize", ...
            "letterMask is %d x %d but the booth screen is %d x %d. Build it with " + ...
            "mkLetterMask(booth.screenSizePx, ...).", size(letterMask, 1), size(letterMask, 2), ...
            screenY, screenX);
    end

    subpixelSteps = 16;
    dotTemplates = localDiskTemplates(booth.dotDiameterPx/2, subpixelSteps);
    dotArea = pi*(booth.dotDiameterPx/2)^2;
    numDots = round(booth.fractionCovered*screenX*screenY/dotArea);
    numBoothFrames = round(booth.durationSec*booth.frameRate);
    frameWeights = localFrameWeights(numBoothFrames, booth.frameRate, booth.modelSize(3), ...
        booth.modelFrameRate);
    coherence = options.Coherence;
    lifetimeSec = options.LifetimeSec;
    direction = [cosd(options.MotionAngleDeg), sind(options.MotionAngleDeg)];

    % The draws are made in the same order as in runSingleTrial.m.
    letterX = rand(1, numDots)*screenX;
    letterY = rand(1, numDots)*screenY;
    backgroundX = rand(1, numDots)*screenX;
    backgroundY = rand(1, numDots)*screenY;
    letterIsSignal = rand(1, numDots) < coherence;
    backgroundIsSignal = rand(1, numDots) < coherence;
    letterNoiseAngle = rand(1, numDots)*360;
    backgroundNoiseAngle = rand(1, numDots)*360;
    letterLifeSec = rand(1, numDots)*lifetimeSec;
    backgroundLifeSec = rand(1, numDots)*lifetimeSec;
    letterDots = struct("x", letterX, "y", letterY, "isSignal", letterIsSignal, ...
        "noiseAngle", letterNoiseAngle, "lifeSec", letterLifeSec, "signalScale", 1);
    backgroundDots = struct("x", backgroundX, "y", backgroundY, "isSignal", backgroundIsSignal, ...
        "noiseAngle", backgroundNoiseAngle, "lifeSec", backgroundLifeSec, ...
        "signalScale", options.BackgroundVelocityScale);

    movie = zeros(booth.modelSize);
    dt = 1/booth.frameRate;
    step = options.SpeedPxPerSec*dt;
    for n = 1:numBoothFrames
        if n > 1
            letterDots = localMove(letterDots, direction, step, screenX, screenY);
            backgroundDots = localMove(backgroundDots, direction, step, screenX, screenY);
            if step > 0
                letterDots = localReplot(letterDots, dt, lifetimeSec, coherence, screenX, screenY);
                backgroundDots = localReplot(backgroundDots, dt, lifetimeSec, coherence, screenX, screenY);
            end
        end
        isInside = localInsideMask(letterDots.x, letterDots.y, letterMask, false);
        isOutside = ~localInsideMask(backgroundDots.x, backgroundDots.y, letterMask, true);
        frame = localDrawDots([backgroundDots.x(isOutside), letterDots.x(isInside)], ...
            [backgroundDots.y(isOutside), letterDots.y(isInside)], dotTemplates, screenY, screenX, ...
            booth.background, booth.dotValue);
        blockMean = localBlockMean(frame, booth.pixelsPerModelPixel);
        modelFrames = find(frameWeights(:, n)).';
        for m = modelFrames
            movie(:, :, m) = movie(:, :, m) + frameWeights(m, n)*blockMean;
        end
    end

    info = struct( ...
        "numDots", numDots, ...
        "numBoothFrames", numBoothFrames, ...
        "speedPxPerSec", options.SpeedPxPerSec, ...
        "coherence", coherence, ...
        "motionAngleDeg", options.MotionAngleDeg, ...
        "backgroundVelocityScale", options.BackgroundVelocityScale, ...
        "lifetimeSec", lifetimeSec);
end

function dots = localMove(dots, direction, step, screenX, screenY)
% Signal dots move along direction (scaled by the population's signalScale);
% noise dots move the same distance along their own direction.
    distance = abs(dots.signalScale)*step;
    dx = cosd(dots.noiseAngle)*distance;
    dy = sind(dots.noiseAngle)*distance;
    dx(dots.isSignal) = dots.signalScale*direction(1)*step;
    dy(dots.isSignal) = dots.signalScale*direction(2)*step;
    dots.x = mod(dots.x + dx, screenX);
    dots.y = mod(dots.y + dy, screenY);
end

function dots = localReplot(dots, dt, lifetimeSec, coherence, screenX, screenY)
% Dots whose life has run out are replotted, as in respawnLimitedLifetimeDots.
% With lifetimeSec = Inf every life starts at rand*Inf = Inf and never runs out.
    dots.lifeSec = dots.lifeSec - dt;
    isDead = dots.lifeSec <= 0;
    nDead = nnz(isDead);
    if nDead > 0
        dots.x(isDead) = rand(1, nDead)*screenX;
        dots.y(isDead) = rand(1, nDead)*screenY;
        dots.isSignal(isDead) = rand(1, nDead) < coherence;
        dots.lifeSec(isDead) = lifetimeSec;
        dots.noiseAngle(isDead) = rand(1, nDead)*360;
    end
end

function isInside = localInsideMask(x, y, mask, offScreenValue)
% True where the rounded position is inside the mask, as in runSingleTrial.m.
% Positions that round to 0 fall off the mask and get offScreenValue.
    [maskY, maskX] = size(mask);
    col = round(x);
    row = round(y);
    isValid = col >= 1 & col <= maskX & row >= 1 & row <= maskY;
    isInside = repmat(offScreenValue, size(x));
    isInside(isValid) = mask(sub2ind([maskY maskX], row(isValid), col(isValid)));
end

function dotTemplates = localDiskTemplates(radius, subpixelSteps)
% Anti-aliased disk footprints. Pixel k spans [k-1, k), the Psychtoolbox
% convention. For a disk centred at x, pixel floor(x) + offset is covered for
% the offsets listed; the fractional part of x is resolved to 1/subpixelSteps.
    offsets = (1 - ceil(radius)):(ceil(radius) + 1);
    samplesPerPixel = 16;
    within = ((1:samplesPerPixel) - 0.5)/samplesPerPixel;
    fractions = ((1:subpixelSteps) - 0.5)/subpixelSteps;
    nOffsets = numel(offsets);
    alpha = zeros(nOffsets, nOffsets, subpixelSteps, subpixelSteps);
    for qy = 1:subpixelSteps
        for qx = 1:subpixelSteps
            % Sample points of every covered pixel, relative to the disk centre.
            sampleX = reshape(offsets - 1 + within.' - fractions(qx), 1, []);
            sampleY = reshape(offsets - 1 + within.' - fractions(qy), [], 1);
            isCovered = (sampleX.^2 + sampleY.^2) <= radius^2;
            covered = reshape(isCovered, samplesPerPixel, nOffsets, samplesPerPixel, nOffsets);
            alpha(:, :, qy, qx) = reshape(mean(covered, [1 3]), nOffsets, nOffsets);
        end
    end
    [rowOffsets, colOffsets] = ndgrid(offsets, offsets);
    dotTemplates = struct( ...
        "alpha", reshape(alpha, nOffsets^2, subpixelSteps^2), ...
        "rowOffsets", rowOffsets(:), ...
        "colOffsets", colOffsets(:), ...
        "subpixelSteps", subpixelSteps);
end

function frame = localDrawDots(x, y, dotTemplates, screenY, screenX, background, dotValue)
% Blend every dot over the background at once. With opacities a_i over a
% pixel, "over" blending gives dotValue - (dotValue - background)*prod(1 - a_i),
% which is summed in logs so that all dots can be accumulated together.
    steps = dotTemplates.subpixelSteps;
    baseX = floor(x);
    baseY = floor(y);
    qx = min(floor((x - baseX)*steps), steps - 1) + 1;
    qy = min(floor((y - baseY)*steps), steps - 1) + 1;
    alpha = dotTemplates.alpha(:, qy + (qx - 1)*steps);
    cols = baseX + dotTemplates.colOffsets;
    rows = baseY + dotTemplates.rowOffsets;
    isDrawn = alpha > 0 & cols >= 1 & cols <= screenX & rows >= 1 & rows <= screenY;
    logTransmission = accumarray(rows(isDrawn) + (cols(isDrawn) - 1)*screenY, ...
        log1p(-alpha(isDrawn)), [screenY*screenX 1]);
    frame = reshape(dotValue - (dotValue - background)*exp(logTransmission), screenY, screenX);
end

function blockMean = localBlockMean(frame, blockSize)
% Mean of each blockSize x blockSize block of pixels.
    [screenY, screenX] = size(frame);
    blocks = reshape(frame, blockSize, screenY/blockSize, blockSize, screenX/blockSize);
    blockMean = reshape(sum(blocks, [1 3]), screenY/blockSize, screenX/blockSize)/blockSize^2;
end

function weights = localFrameWeights(numBoothFrames, boothRate, numModelFrames, modelRate)
% weights(m, n): the fraction of model frame m during which booth frame n is
% on the screen. Each row sums to 1.
    boothStart = (0:numBoothFrames - 1)/boothRate;
    boothEnd = (1:numBoothFrames)/boothRate;
    modelStart = (0:numModelFrames - 1).'/modelRate;
    modelEnd = (1:numModelFrames).'/modelRate;
    overlap = max(0, min(boothEnd, modelEnd) - max(boothStart, modelStart));
    weights = overlap*modelRate;
end
