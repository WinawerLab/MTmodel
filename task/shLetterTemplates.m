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
%   Inputs:
%     pars          model parameters (shPars). Only the filter sizes are used,
%                   and they are the same for both presets.
%     outSz         MT output size [Y X T].
%     Letters       letters to build. Default "CDHKNORSVZ", the 10 Sloan
%                   letters of the experiment.
%     LetterSizePx  font size in pixels. Default 28, which draws a Sloan letter
%                   29 px tall (2.9 deg; the booth letter is 168 arcmin = 2.8 deg).
%     FontName      Default "Sloan".
%
%   Output fields:
%     letters, letterSizePx, fontName, stimSz, outSz, pad
%     stimMasks   [stimY stimX nLetters] logical. Pass one to mkMotionLetter as
%                 'letterMask', so the stimulus and the template are the same shape.
%     masks       [outY outX nLetters] logical. The templates for shTemplateScores.
%
%   See also mkLetterMask, shCropToOutput, shTemplateScores, shRunLetterTrials

    arguments
        pars (1,1) struct
        outSz (1,3) double {mustBeInteger, mustBePositive}
        options.Letters (1,1) string = "CDHKNORSVZ"
        options.LetterSizePx (1,1) double {mustBePositive} = 28
        options.FontName (1,1) string = "Sloan"
    end

    stimSz = shGetDims(pars, "mtPattern", outSz);
    letters = char(options.Letters);
    nLetters = numel(letters);

    stimMasks = false([stimSz(1:2) nLetters]);
    for k = 1:nLetters
        stimMasks(:, :, k) = mkLetterMask(stimSz(1:2), letters(k), ...
            options.LetterSizePx, char(options.FontName));
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
        "letterSizePx", options.LetterSizePx, ...
        "fontName", options.FontName, ...
        "stimSz", stimSz, ...
        "outSz", outSz, ...
        "pad", (stimSz(1:2)-outSz(1:2))/2, ...
        "stimMasks", stimMasks, ...
        "masks", masks);
end
