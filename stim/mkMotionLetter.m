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
% See also: explore/showMotionLetter.m, playStimMovie, playStimMovieCompare

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

    ppd = opts.ppd;
    if isempty(ppd)
        ppd = ppdRef;
    end

    if ~isempty(opts.letterSizePx)
        letterSizeBooth = round(opts.letterSizePx);
    else
        letterSizeBooth = round((opts.letterSizeArcmin / 60) * ppdRef);
    end
    letterSizeBooth = max(letterSizeBooth, 8);

    dotSizePx = max(1, round(opts.dotSize * fieldScale));

    if ~isempty(opts.dotSpeedPxPerFrame)
        speedPxPerSec = opts.dotSpeedPxPerFrame * opts.frameRate;
        dotSpeedDegS = speedPxPerSec / (ppdRef * max(fieldScale, eps));
    else
        dotSpeedDegS = opts.dotSpeedDegS;
        speedPxPerSec = dotSpeedDegS * ppdRef * fieldScale;
    end
    speedPxPerFrame = speedPxPerSec / opts.frameRate;

    grey = opts.background;
    dotValue = grey + opts.dotContrast * (1 - grey);

    letterSizePx = max(8, round(letterSizeBooth * fieldScale));
    [binaryMask, fontUsed] = localLetterMask(genY, genX, letter, ...
        letterSizePx, opts.fontName, grey);

    [stim, buildInfo] = localBuildMovie(genY, genX, numFrames, ...
        binaryMask, dotSizePx, opts.dotShape, opts.fCovered, ...
        grey, dotValue, speedPxPerSec, opts.frameRate, opts.drawBackgroundDots);

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
    info.ppd = ppdRef;
    info.fontName = fontUsed;
    info.background = grey;
    info.dotValue = dotValue;
    info.binaryMask = binaryMask;
    info.pixelsPerLetter = sum(binaryMask(:));
    info.outputSize = [genY genX numFrames];

end

% -------------------------------------------------------------------------
function [stim, info] = localBuildMovie(genY, genX, numFrames, binaryMask, ...
        dotSizePx, dotShape, fCovered, grey, dotValue, speedPxPerSec, ...
        frameRate, drawBackgroundDots)

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
        bgX = mod(initialBgX - speedPxPerSec * elapsed, genX);
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
    [img, fontUsed] = localRenderLetter(screenY, screenX, letter, letterSizePx, fontName, grey);
    thresh = grey * 255 + 10;
    if ~any(img(:, :, 1) > thresh)
        warning('mkMotionLetter:fontFallback', ...
            'Font ''%s'' did not render; falling back to Arial.', fontName);
        [img, fontUsed] = localRenderLetter(screenY, screenX, letter, letterSizePx, 'Arial', grey);
    end
    mask = img(:, :, 1) > thresh;
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
