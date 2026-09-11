function out = shCropToOutput(stimImage, outSize)
% shCropToOutput  Crop an image on the stimulus grid to the grid of a model output.
%
%   out = shCropToOutput(stimImage, outSize) crops stimImage -- a letter mask,
%   say -- to the grid of a model output whose spatial size is outSize.
%
%   Every stage of the model trims its filter support symmetrically (all its
%   spatial filters have odd length), so a stage's output is the CENTRE of the
%   stimulus grid, not a shrunken copy of it. Output pixel (i, j) sits over
%   stimulus pixel (i + pad(1), j + pad(2)), with pad = (stimulus size - output
%   size)/2. For "mtPattern" that is 18 pixels per side.
%
%   Do not resize a stimulus-grid mask to the output size instead. That
%   shrinks the letter and misaligns it: on one test trial the resized mask
%   gave letter-versus-background d' = 1.8, and the cropped mask 4.5. Nor
%   apply a mask made for one stage's map to another's: V1 and MT maps from
%   the same stimulus are different sizes.
%
%   Inputs:
%     stimImage   [Y X] or [Y X N] array on the stimulus grid
%     outSize     size of the output map, usually size(map). Only the first
%                 two elements are used.
%
%   Output:
%     out         [outSize(1) outSize(2) N]
%
%   See also shGetDims, shLetterTemplates

    arguments
        stimImage
        outSize (1,:) double {mustBeInteger, mustBeNonnegative}
    end

    if numel(outSize) < 2
        error("shCropToOutput:outSize", "outSize must have at least two elements, [Y X].");
    end
    outSize = outSize(1:2);
    stimSize = [size(stimImage, 1) size(stimImage, 2)];
    margin = stimSize - outSize;
    if any(margin < 0) || any(mod(margin, 2) ~= 0)
        error("shCropToOutput:size", ...
            "Cannot centre a [%d %d] output in a [%d %d] stimulus grid: the difference must be " + ...
            "non-negative and even. Check that the map was computed from this stimulus.", ...
            outSize, stimSize);
    end
    pad = margin/2;
    out = stimImage(pad(1)+(1:outSize(1)), pad(2)+(1:outSize(2)), :);
end
