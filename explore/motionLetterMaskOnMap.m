function mask = motionLetterMaskOnMap(fullMask, outY, outX)
% motionLetterMaskOnMap  Map a stimulus letter mask onto a V1/MT response grid.
%
% The model uses valid (edge-dropping) convolution, so an [outY x outX] map is
% the central crop of the stimulus, not a resized copy of the whole field.
% Shrinking the mask with imresize makes the letter too small on the map
% (the white overlay you see sitting inside the response blob).
%
% Inputs
%   fullMask  stimulus-resolution letter mask (from mkMotionLetter)
%   outY, outX  spatial size of the model map
%
% Output
%   mask  logical [outY x outX], 1 inside the letter

if nargin == 2
    outX = outY(2);
    outY = outY(1);
end

fullMask = double(fullMask) > 0.5;
[inY, inX] = size(fullMask);
if inY < outY || inX < outX
    error('motionLetterMaskOnMap:maskTooSmall', ...
        'Stimulus mask [%d %d] is smaller than the map [%d %d].', ...
        inY, inX, outY, outX);
end
offY = floor((inY - outY) / 2);
offX = floor((inX - outX) / 2);
mask = fullMask(offY+1:offY+outY, offX+1:offX+outX);
end
