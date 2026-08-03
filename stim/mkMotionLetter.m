% [stim, info] = mkMotionLetter(stimSz, letter, ...)
%
% Motion-defined letter stimulus (Regan-style): two dot fields drift horizontally
% in opposite directions. Letter dots move right; background dots move left.
% Letter dots are visible only where they fall inside a Sloan-letter mask;
% background dots are visible only outside the mask (optional, as in the
% contrast staircase block).
%
% Port of the dot/mask logic in runSingleTrial.m (Psychtoolbox experiment).
% Output is a [Y X T] movie in [0, 1] suitable for shModel.
%
% Required arguments:
%   stimSz   [Y X T] stimulus size (frames = stimSz(3))
%   letter   single character (e.g. 'C')
%
% Optional name/value pairs (experiment defaults in brackets):
%   'dotSpeedDegS'        dot speed in deg/s [0.45]  (used if dotSpeedPxPerFrame unset)
%   'dotSpeedPxPerFrame'  override speed in pixels/frame (model-native units)
%   'letterSizeArcmin'    letter size in arcmin [168]
%   'letterSizePx'        letter TextSize in pixels (overrides arcmin)
%   'dotContrast'         dot contrast 0–1; alpha-blended on grey [1]
%   'dotSize'             dot diameter in pixels [4]
%   'dotShape'            'square' (pixel-aligned block) or 'disk' [square]
%   'fCovered'            fraction of screen area covered by dots [0.5]
%   'drawBackgroundDots'  draw background dots outside letter [true]
%   'fontName'            letter font ['Sloan']
%   'background'          grey level [0.5]
%   'frameRate'           frames/s for deg/s conversion [60]
%   'ppd'                 pixels/deg (if unset, computed from screenWidthCm/viewDistCm)
%   'screenWidthCm'       for ppd [39]
%   'viewDistCm'          for ppd [175]
%   'seed'                RNG seed (omit = don't reset RNG)
%
% Outputs:
%   stim     [Y X T] double in [0, 1]
%   info     struct with parameters, binaryMask, letterContrast, etc.
%
% Example (experiment-like, 1280×960 px field, 4 s @ 60 Hz):
%   stim = mkMotionLetter([960 1280 240], 'C', 'dotSpeedDegS', 0.45, ...
%       'letterSizeArcmin', 168, 'dotContrast', 1, 'ppd', 32);
%
% See also: explore/showMotionLetter.m, flipBook

function [stim, info] = mkMotionLetter(stimSz, letter, varargin)

    p = inputParser;
    p.addParameter('dotSpeedDegS', 0.45);
    p.addParameter('dotSpeedPxPerFrame', []);
    p.addParameter('letterSizeArcmin', 168);
    p.addParameter('letterSizePx', []);
    p.addParameter('dotContrast', 1.0);
    p.addParameter('dotSize', 4);
    p.addParameter('dotShape', 'square');
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
    if ~ischar(letter) && ~(isstring(letter) && isscalar(letter))
        error('mkMotionLetter:letter', 'letter must be a single character.');
    end
    letter = char(letter);
    if numel(letter) ~= 1
        error('mkMotionLetter:letter', 'letter must be a single character.');
    end

    screenY = stimSz(1);
    screenX = stimSz(2);
    numFrames = stimSz(3);

    if ~isempty(opts.seed)
        rng(opts.seed);
    end

    ppd = opts.ppd;
    if isempty(ppd)
        ppd = localPpd(screenX, opts.screenWidthCm, opts.viewDistCm);
    end

    if ~isempty(opts.letterSizePx)
        letterSizePx = round(opts.letterSizePx);
    else
        letterSizePx = round((opts.letterSizeArcmin / 60) * ppd);
    end
    letterSizePx = max(letterSizePx, 8);

    if ~isempty(opts.dotSpeedPxPerFrame)
        speedPxPerFrame = opts.dotSpeedPxPerFrame;
        speedPxPerSec = speedPxPerFrame * opts.frameRate;
        dotSpeedDegS = speedPxPerSec / ppd;
    else
        dotSpeedDegS = opts.dotSpeedDegS;
        speedPxPerSec = dotSpeedDegS * ppd;
        speedPxPerFrame = speedPxPerSec / opts.frameRate;
    end

    grey = opts.background;
    white = 1.0;
    dotValue = grey + opts.dotContrast * (white - grey);

    screenArea = screenX * screenY;
    dotArea = pi * (opts.dotSize / 2)^2;
    numDots = max(1, round(opts.fCovered * screenArea / dotArea));

    [binaryMask, fontUsed] = localLetterMask(screenY, screenX, letter, ...
        letterSizePx, opts.fontName, grey);

    offX = (screenX - size(binaryMask, 2)) / 2;
    offY = (screenY - size(binaryMask, 1)) / 2;

    initialLtX = rand(1, numDots) * screenX;
    initialLtY = rand(1, numDots) * screenY;
    initialBgX = rand(1, numDots) * screenX;
    initialBgY = rand(1, numDots) * screenY;

    dotTpl = localDotTemplate(opts.dotSize, opts.dotShape);

    stim = repmat(grey, [screenY, screenX, numFrames]);
    letterContrastFrame = zeros(1, numFrames);
    N_letterPixels = sum(binaryMask(:));
    pixelsPerDot = pi * (opts.dotSize / 2)^2;

    for t = 1:numFrames
        elapsed = (t - 1) / opts.frameRate;
        ltX = mod(initialLtX + speedPxPerSec * elapsed, screenX);
        ltY = initialLtY;
        bgX = mod(initialBgX - speedPxPerSec * elapsed, screenX);
        bgY = initialBgY;

        frame = repmat(grey, screenY, screenX);

        if opts.drawBackgroundDots
            outside = localDotsOutsideLetter(bgX, bgY, binaryMask, offX, offY);
            frame = localStampDots(frame, bgX(outside), bgY(outside), dotTpl, dotValue, screenX, screenY);
        end

        inside = localDotsInsideLetter(ltX, ltY, binaryMask, offX, offY);
        frame = localStampDots(frame, ltX(inside), ltY(inside), dotTpl, dotValue, screenX, screenY);

        if N_letterPixels > 0
            nDotsInLetter = sum(inside);
            letterContrastFrame(t) = min(nDotsInLetter * pixelsPerDot / N_letterPixels, 1);
        end

        stim(:, :, t) = min(frame, 1);
    end

    info = struct();
    info.letter = letter;
    info.numDots = numDots;
    info.letterSizePx = letterSizePx;
    info.letterSizeArcmin = opts.letterSizeArcmin;
    info.dotSpeedDegS = dotSpeedDegS;
    info.dotSpeedPxPerSec = speedPxPerSec;
    info.dotSpeedPxPerFrame = speedPxPerFrame;
    info.dotContrast = opts.dotContrast;
    info.dotSize = opts.dotSize;
    info.dotShape = opts.dotShape;
    info.fCovered = opts.fCovered;
    info.drawBackgroundDots = opts.drawBackgroundDots;
    info.frameRate = opts.frameRate;
    info.ppd = ppd;
    info.fontName = fontUsed;
    info.background = grey;
    info.dotValue = dotValue;
    info.binaryMask = binaryMask;
    info.pixelsPerLetter = N_letterPixels;
    info.letterContrast = mean(letterContrastFrame);
    info.letterContrastFrame = letterContrastFrame;

end

% -------------------------------------------------------------------------
function ppd = localPpd(screenWidthPx, screenWidthCm, viewDistCm)
    ppd = pi * screenWidthPx / (atan(screenWidthCm / (2 * viewDistCm)) * 360);
end

function [mask, fontUsed] = localLetterMask(screenY, screenX, letter, letterSizePx, fontName, grey)
    fontUsed = fontName;
    img = localRenderLetter(screenY, screenX, letter, letterSizePx, fontUsed, grey);
    if ~any(img(:) > grey + 0.05)
        fontUsed = 'Arial';
        img = localRenderLetter(screenY, screenX, letter, letterSizePx, fontUsed, grey);
    end
    greyLevel = grey * 255;
    mask = img(:,:,1) > greyLevel + 10;
end

function img = localRenderLetter(screenY, screenX, letter, letterSizePx, fontName, grey)
    fig = figure('Visible', 'off', 'Units', 'pixels', ...
        'Position', [100 100 screenX screenY], ...
        'Color', [grey grey grey], 'MenuBar', 'none', 'ToolBar', 'none', ...
        'NumberTitle', 'off');
    cax = axes('Parent', fig, 'Units', 'pixels', 'Position', [1 1 screenX screenY], ...
        'Visible', 'off');
    axis(cax, [0 screenX 0 screenY]);
    set(cax, 'YDir', 'reverse');
    hold(cax, 'on');
    text(cax, screenX / 2, screenY / 2, letter, ...
        'FontUnits', 'pixels', 'FontSize', letterSizePx, ...
        'FontName', fontName, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Color', [1 1 1]);
    drawnow;
    fr = getframe(fig);
    img = fr.cdata;
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
    if idx < 1
        idx = mod(idx - 1, n) + 1;
    elseif idx > n
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
