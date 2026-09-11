function [mask, fontUsed] = mkLetterMask(fieldSz, letter, letterSizePx, fontName, background)
% mkLetterMask  Binary mask of one letter, centred in a field.
%
%   mask = mkLetterMask(fieldSz, letter, letterSizePx) draws letter, centred,
%   in a field of fieldSz = [Y X] pixels, and returns true where the letter is.
%   This is the mask mkMotionLetter uses to decide which dots belong to the
%   letter. It is a function of its own so that a decoder can build its
%   templates from exactly the same letterforms (see shLetterTemplates).
%
%   [mask, fontUsed] = mkLetterMask(fieldSz, letter, letterSizePx, fontName, background)
%
%   The letter is rendered directly at the field size. It is never drawn at
%   another resolution and then resized, because resizing blurs Sloan
%   letterforms. MATLAB silently substitutes a default face for a font that
%   is not installed, so availability is checked first; a missing font falls
%   back to Arial with a warning.
%
%   Inputs:
%     fieldSz       [Y X] in pixels
%     letter        one character
%     letterSizePx  font size in pixels. For Sloan it is also, to within a
%                   pixel, the letter's height: 28 px gives a letter 29 px
%                   tall, 2.9 deg at the model's 10 px/deg.
%     fontName      Default "Sloan".
%     background    grey level of the render, 0-1. Only sets the threshold.
%                   Default 0.5.
%
%   Outputs:
%     mask          [Y X] logical
%     fontUsed      the font MATLAB actually used
%
%   See also mkMotionLetter, shLetterTemplates

    arguments
        fieldSz (1,2) double {mustBeInteger, mustBePositive}
        letter (1,1) string
        letterSizePx (1,1) double {mustBePositive}
        fontName (1,1) string = "Sloan"
        background (1,1) double {mustBeBetween(background, 0, 1)} = 0.5
    end

    if strlength(letter) ~= 1
        error("mkLetterMask:letter", "letter must be one character, got ""%s"".", letter);
    end
    if ~localIsFontInstalled(fontName)
        warning("mkLetterMask:fontFallback", ...
            "Font ""%s"" is not installed, so MATLAB would silently substitute another face. " + ...
            "Falling back to Arial; the letterforms will differ from the booth stimulus.", fontName);
        fontName = "Arial";
    end

    maxPixelValue = 255;
    thresholdMargin = 10;
    [image, fontUsed] = localRenderLetter(fieldSz, char(letter), letterSizePx, char(fontName), background);
    threshold = background*maxPixelValue + thresholdMargin;
    mask = image(:, :, 1) > threshold;
    if ~any(mask(:))
        error("mkLetterMask:emptyMask", ...
            "Letter ""%s"" rendered no pixels at %g px in font ""%s"". " + ...
            "Increase letterSizePx or the field size.", letter, letterSizePx, fontName);
    end
end

function isInstalled = localIsFontInstalled(fontName)
    % Cache the font list: listfonts is slow and fonts do not change mid-session.
    persistent installedFonts
    if isempty(installedFonts)
        installedFonts = listfonts();
    end
    isInstalled = any(strcmpi(installedFonts, fontName));
end

function [image, fontUsed] = localRenderLetter(fieldSz, letter, letterSizePx, fontName, grey)
    screenY = fieldSz(1);
    screenX = fieldSz(2);
    figureHandle = figure(Visible="off", Units="pixels", Position=[100 100 screenX screenY], ...
        Color=[grey grey grey], MenuBar="none", ToolBar="none", NumberTitle="off");
    cleanup = onCleanup(@() close(figureHandle));
    axesHandle = axes(Parent=figureHandle, Units="pixels", Position=[1 1 screenX screenY], ...
        Visible="off");
    axis(axesHandle, [0 screenX 0 screenY]);
    axesHandle.YDir = "reverse";
    textHandle = text(axesHandle, screenX/2, screenY/2, letter, FontUnits="pixels", ...
        FontSize=letterSizePx, FontName=fontName, HorizontalAlignment="center", ...
        VerticalAlignment="middle", Color=[1 1 1]);
    drawnow();
    fontUsed = textHandle.FontName;
    image = getframe(figureHandle).cdata;
    if size(image, 1) ~= screenY || size(image, 2) ~= screenX
        image = imresize(image, [screenY screenX]);
    end
end
