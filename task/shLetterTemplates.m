function templates = shLetterTemplates(pars, outSz, options)
% shLetterTemplates  Letter templates for the motion-defined letter task, on the MT output grid.
%
%   templates = shLetterTemplates(pars, outSz) returns one binary mask per
%   letter. Each mask is drawn by mkLetterMask -- the function mkMotionLetter
%   itself uses -- at the size of stimulus that shModel needs for an MT output
%   of outSz, and then cropped to the output grid with shCropToOutput. The MT
%   map is the centre of the stimulus grid, not a shrunken copy of it, so the
%   masks are cropped, never resized.
%
%   templates = shLetterTemplates(..., Letters=L, LetterSizePx=N, FontName=F)
%
%   templates = shLetterTemplates(..., BoothDisplay=booth) builds the letters
%   for trials drawn as on the booth display (mkBoothLetterMovie; booth from
%   boothDisplay). Each letter is drawn at booth resolution with the booth's
%   letter size and font, and a model pixel is in the letter if most of its
%   block of booth pixels is. outSz must then be the MT output for a stimulus
%   of booth.modelSize. LetterSizePx and FontName are ignored. shRunLetterTrials
%   draws booth trials whenever its templates were built this way.
%
%   Inputs:
%     pars          model parameters (shPars). Only the filter sizes are used,
%                   and they are the same for both presets.
%     outSz         MT output size [Y X T].
%     Letters       letters to build. Default "CDHKNORSVZ", the 10 Sloan
%                   letters of the experiment.
%     LetterSizePx  font size in pixels. Default 28, which draws a Sloan letter
%                   29 px tall (2.9 deg; the booth letter is 168 arcmin = 2.8 deg).
%     FontName      Default "Sloan".
%     BoothDisplay  from boothDisplay. Default: none.
%
%   Output fields:
%     letters, letterSizePx, fontName, stimSz, outSz, pad
%     stimMasks     [stimY stimX nLetters] logical. Pass one to mkMotionLetter as
%                   'letterMask', so the stimulus and the template are the same shape.
%     masks         [outY outX nLetters] logical. The templates for shTemplateScores.
%     boothMasks    [screenY screenX nLetters] logical, the letters at booth
%                   resolution for mkBoothLetterMovie; [] without BoothDisplay.
%     boothDisplay  the BoothDisplay struct; empty without it.
%
%   See also mkLetterMask, shCropToOutput, shTemplateScores, shRunLetterTrials,
%            boothDisplay, mkBoothLetterMovie

    arguments
        pars (1,1) struct
        outSz (1,3) double {mustBeInteger, mustBePositive}
        options.Letters (1,1) string = "CDHKNORSVZ"
        options.LetterSizePx (1,1) double {mustBePositive} = 28
        options.FontName (1,1) string = "Sloan"
        options.BoothDisplay struct = struct.empty
    end

    stimSz = shGetDims(pars, "mtPattern", outSz);
    letters = char(options.Letters);
    nLetters = numel(letters);
    booth = options.BoothDisplay;

    stimMasks = false([stimSz(1:2) nLetters]);
    if isempty(booth)
        boothMasks = [];
        letterSizePx = options.LetterSizePx;
        fontName = options.FontName;
        for k = 1:nLetters
            stimMasks(:, :, k) = mkLetterMask(stimSz(1:2), letters(k), letterSizePx, fontName);
        end
    else
        if ~isequal(stimSz, booth.modelSize)
            error("shLetterTemplates:boothSize", ...
                "outSz [%s] needs a stimulus of [%s], but a booth trial is [%s]. Use outSz = [%s].", ...
                num2str(outSz), num2str(stimSz), num2str(booth.modelSize), ...
                num2str(outSz + booth.modelSize - stimSz));
        end
        boothMasks = false([booth.screenSizePx nLetters]);
        letterSizePx = booth.letterSizePx/booth.pixelsPerModelPixel;
        fontName = booth.fontName;
        majority = 0.5;
        for k = 1:nLetters
            boothMasks(:, :, k) = mkLetterMask(booth.screenSizePx, letters(k), booth.letterSizePx, ...
                booth.fontName, booth.background);
            stimMasks(:, :, k) = localBlockMean(boothMasks(:, :, k), booth.pixelsPerModelPixel) >= majority;
        end
    end
    masks = shCropToOutput(stimMasks, outSz);

    lostPixels = squeeze(sum(stimMasks, [1 2]) - sum(masks, [1 2]));
    if any(lostPixels > 0)
        warning("shLetterTemplates:clipped", ...
            "Letters %s extend beyond the MT output grid. Enlarge outSz or reduce LetterSizePx.", ...
            letters(lostPixels > 0));
    end

    templates = struct( ...
        "letters", letters, ...
        "letterSizePx", letterSizePx, ...
        "fontName", fontName, ...
        "stimSz", stimSz, ...
        "outSz", outSz, ...
        "pad", (stimSz(1:2)-outSz(1:2))/2, ...
        "stimMasks", stimMasks, ...
        "masks", masks, ...
        "boothMasks", boothMasks, ...
        "boothDisplay", booth);
end

function blockMean = localBlockMean(image, blockSize)
% Mean of each blockSize x blockSize block of pixels.
    [imageY, imageX] = size(image);
    blocks = reshape(image, blockSize, imageY/blockSize, blockSize, imageX/blockSize);
    blockMean = reshape(sum(blocks, [1 3]), imageY/blockSize, imageX/blockSize)/blockSize^2;
end
