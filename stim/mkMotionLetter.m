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
% MODEL's own scale is ~2.33 px/deg and 37.2 frames/sec (shModelUnits), i.e.
% about 43x coarser, so a speed converted with booth geometry lands far below
% the speeds the MT population is tuned to. To work in the model's units:
%
%   u = shModelUnits();
%   stim = mkMotionLetter(sz, 'C', 'referenceDisplaySize', [], ...
%       'ppd', u.pixelsPerDegree, 'frameRate', u.framesPerSecond, ...
%       'dotSpeedDegS', 5);          % -> 0.3125 px/frame, as intended
%
% Passing ppd overrides the display geometry entirely. letterSizePx, when
% given, is in output-field pixels.
%
% NOTE: two calls with the same seed but different stimSz do NOT produce the
% same dot sample — the field area sets the dot count, so the random draws
% differ in length. Build once and resize if you need matched samples.
%
% See also: shModelUnits, explore/showMotionLetter.m, playStimMovie, playStimMovieCompare

function [stim, info] = mkMotionLetter(stimSz, letter, varargin)

    p = inputParser;
    p.addParameter('dotSpeedDegS', 0.45);
    p.addParameter('dotSpeedPxPerFrame', []);
    p.addParameter('letterSizeArcmin', 168);
    p.addParameter('letterSizePx', []);
    p.addParameter('dotContrast', 1.0);
    p.addParameter('dotSize', 4);
    p.addParameter('dotShape', 'square');
    p.addParameter('referenceDisplaySize', [960 1280]);
    p.addParameter('fCovered', 0.5);
    p.addParameter('drawBackgroundDots', true);
    % Background velocity as a multiple of the letter's. -1 = opposite drift
    % (the Regan stimulus); +1 = SAME drift, which removes all relative motion
    % and so should make the letter unrecoverable -- the control condition that
    % shows a model is segregating from motion and not from some other cue;
    % 0 = static background.
    p.addParameter('backgroundVelocityScale', -1);
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
    % (shModelUnits: 2.33 px/deg) rather than a booth's (~100 px/deg).
    if ~isempty(opts.ppd)
        ppdField = opts.ppd;
    else
        ppdField = ppdRef * fieldScale;
    end
    if ppdField <= 0
        error('mkMotionLetter:ppd', 'Effective pixels-per-degree must be positive.');
    end

    dotSizePx = max(1, round(opts.dotSize * fieldScale));

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

    [binaryMask, fontUsed] = localLetterMask(genY, genX, letter, ...
        letterSizePx, opts.fontName, grey);

    [stim, buildInfo] = localBuildMovie(genY, genX, numFrames, ...
        binaryMask, dotSizePx, opts.dotShape, opts.fCovered, ...
        grey, dotValue, speedPxPerSec, opts.frameRate, opts.drawBackgroundDots, ...
        opts.backgroundVelocityScale);

    info = buildInfo;
    info.letter = letter;
    info.letterSizePx = letterSizePx;
    info.letterSizeBoothPx = letterSizeBooth;
    info.letterSizeArcmin = opts.letterSizeArcmin;
    info.dotSpeedDegS = dotSpeedDegS;
    info.dotSpeedPxPerSec = speedPxPerSec;
    info.dotSpeedPxPerFrame = speedPxPerFrame;
    info.dotContrast = opts.dotContrast;
    info.dotSize = dotSizePx;
    info.dotSizeNominal = opts.dotSize;
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
function [stim, info] = localBuildMovie(genY, genX, numFrames, binaryMask, ...
        dotSizePx, dotShape, fCovered, grey, dotValue, speedPxPerSec, ...
        frameRate, drawBackgroundDots, bgVelocityScale)

    screenArea = genX * genY;
    dotArea = pi * (dotSizePx / 2)^2;
    numDots = max(1, round(fCovered * screenArea / dotArea));

    offX = (genX - size(binaryMask, 2)) / 2;
    offY = (genY - size(binaryMask, 1)) / 2;

    initialLtX = rand(1, numDots) * genX;
    initialLtY = rand(1, numDots) * genY;
    initialBgX = rand(1, numDots) * genX;
    initialBgY = rand(1, numDots) * genY;

    dotTpl = localDotTemplate(dotSizePx, dotShape);

    stim = repmat(grey, [genY, genX, numFrames]);
    letterContrastFrame = zeros(1, numFrames);
    N_letterPixels = sum(binaryMask(:));
    pixelsPerDot = pi * (dotSizePx / 2)^2;

    for t = 1:numFrames
        elapsed = (t - 1) / frameRate;
        ltX = mod(initialLtX + speedPxPerSec * elapsed, genX);
        ltY = initialLtY;
        bgX = mod(initialBgX + bgVelocityScale * speedPxPerSec * elapsed, genX);
        bgY = initialBgY;

        frame = repmat(grey, genY, genX);

        if drawBackgroundDots
            outside = localDotsOutsideLetter(bgX, bgY, binaryMask, offX, offY);
            frame = localStampDots(frame, bgX(outside), bgY(outside), dotTpl, dotValue, genX, genY);
        end

        inside = localDotsInsideLetter(ltX, ltY, binaryMask, offX, offY);
        frame = localStampDots(frame, ltX(inside), ltY(inside), dotTpl, dotValue, genX, genY);

        if N_letterPixels > 0
            nDotsInLetter = sum(inside);
            letterContrastFrame(t) = min(nDotsInLetter * pixelsPerDot / N_letterPixels, 1);
        end

        stim(:, :, t) = min(frame, 1);
    end

    info = struct();
    info.numDots = numDots;
    info.letterContrast = mean(letterContrastFrame);
    info.letterContrastFrame = letterContrastFrame;

end

function ppd = localPpd(screenWidthPx, screenWidthCm, viewDistCm)
    ppd = pi * screenWidthPx / (atan(screenWidthCm / (2 * viewDistCm)) * 360);
end

function [mask, fontUsed] = localLetterMask(screenY, screenX, letter, letterSizePx, fontName, grey)
    % MATLAB silently substitutes a default face for an unavailable font, so a
    % missing font still renders a letter and cannot be detected from the
    % rendered pixels. Check availability up front instead -- otherwise a run
    % that never used Sloan is reported as though it had.
    if ~localFontAvailable(fontName)
        warning('mkMotionLetter:fontFallback', ...
            ['Font ''%s'' is not installed (MATLAB would silently substitute ' ...
             'another face); falling back to Arial. Optotype letterforms will ' ...
             'differ from the booth stimulus.'], fontName);
        fontName = 'Arial';
    end

    [img, fontUsed] = localRenderLetter(screenY, screenX, letter, letterSizePx, fontName, grey);
    thresh = grey * 255 + 10;
    if ~any(img(:, :, 1) > thresh)
        error('mkMotionLetter:emptyMask', ...
            ['Letter ''%s'' rendered no pixels above threshold at %d px in font ' ...
             '''%s''. Check letterSizePx and the field size.'], ...
            letter, letterSizePx, fontName);
    end
    mask = img(:, :, 1) > thresh;
end

function tf = localFontAvailable(fontName)
    persistent installed
    if isempty(installed)
        installed = listfonts;
    end
    tf = any(strcmpi(installed, fontName));
end

function [img, fontUsed] = localRenderLetter(screenY, screenX, letter, letterSizePx, fontName, grey)
    fig = figure('Visible', 'off', 'Units', 'pixels', ...
        'Position', [100 100 screenX screenY], ...
        'Color', [grey grey grey], 'MenuBar', 'none', 'ToolBar', 'none', ...
        'NumberTitle', 'off');
    cax = axes('Parent', fig, 'Units', 'pixels', 'Position', [1 1 screenX screenY], ...
        'Visible', 'off');
    axis(cax, [0 screenX 0 screenY]);
    set(cax, 'YDir', 'reverse');
    hText = text(cax, screenX / 2, screenY / 2, letter, ...
        'FontUnits', 'pixels', 'FontSize', letterSizePx, ...
        'FontName', fontName, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Color', [1 1 1]);
    drawnow;
    fontUsed = hText.FontName;
    img = getframe(fig).cdata;
    close(fig);
    if size(img, 1) ~= screenY || size(img, 2) ~= screenX
        img = imresize(img, [screenY screenX]);
    end
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

function frame = localStampDots(frame, xs, ys, tpl, dotValue, screenX, screenY)
    mask = tpl.mask;
    offsets = tpl.offsets;
    [dy, dx] = ndgrid(offsets, offsets);

    for k = 1:numel(xs)
        cx = localWrapIndex(round(xs(k)), screenX);
        cy = localWrapIndex(round(ys(k)), screenY);
        cols = cx + dx;
        rows = cy + dy;
        valid = cols >= 1 & cols <= screenX & rows >= 1 & rows <= screenY;
        subMask = mask & valid;
        if ~any(subMask(:)), continue; end
        frame(sub2ind(size(frame), rows(subMask), cols(subMask))) = dotValue;
    end
end

function idx = localWrapIndex(idx, n)
    if idx < 1 || idx > n
        idx = mod(idx - 1, n) + 1;
    end
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
