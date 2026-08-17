% units = shModelUnits()
%
% The model's pinned physical scale, derived from Simoncelli & Heeger (1998)
% Appendix I (p. 761): frequency units are fixed so the tiling annulus crosses
% the temporal-frequency axis at 8 cycles/sec and the spatial-frequency axes at
% 0.5 cycles/deg. In this codebase the 3rd-derivative spatial and temporal
% filters have the same shape and both peak at 0.2148 cycles/sample, so both
% axes are determined:
%
%   0.2148 cyc/pixel <-> 0.5 cyc/deg   =>  2.33 pixels/deg (0.430 deg/pixel)
%   0.2148 cyc/frame <-> 8   cyc/sec   =>  37.2 frames/sec (26.9 ms/frame)
%   => 1 pixel/frame = 16 deg/sec
%
% Use this instead of a display's physical geometry whenever a stimulus
% parameter has to be expressed in the units the model's filters actually live
% in. A booth's pixels-per-degree (~100 ppd at 175 cm) is roughly 43x finer than
% the model's, so a speed converted with booth geometry lands far below the
% speeds the MT population is tuned to.
%
% CAVEAT (docs/RGC_lagged_preset_summary.md 7.1): this is the scale implied by
% SH's own frequency convention, but it makes the model's RGC receptive fields
% about an order of magnitude larger than real midget/parasol cells. The honest
% reading is that SH operates at a coarse spatial scale, so its "RGCs" are
% coarse-scale channels rather than individual ganglion cells. Angular sizes
% converted through this function inherit that caveat.
%
% Output fields:
%   pixelsPerDegree, degPerPixel
%   framesPerSecond, msPerFrame
%   degPerSecPerPixelPerFrame   speed conversion factor (16 deg/s)
%   peakCyclesPerSample         the 0.2148 constant the rest is derived from
%
% See also: mt2sin, shPars, docs/RGC_lagged_preset_summary.md

function units = shModelUnits()

    % Peak of the 3rd-derivative filters, in cycles/sample (both axes).
    peakCyclesPerSample = 0.2148;

    % SH Appendix I anchors.
    anchorCyclesPerDeg = 0.5;
    anchorCyclesPerSec = 8;

    units.peakCyclesPerSample = peakCyclesPerSample;
    % (cycles/pixel) / (cycles/deg) = deg/pixel
    units.degPerPixel     = peakCyclesPerSample / anchorCyclesPerDeg;
    units.pixelsPerDegree = 1 / units.degPerPixel;
    units.framesPerSecond = anchorCyclesPerSec / peakCyclesPerSample;
    units.msPerFrame      = 1000 / units.framesPerSecond;
    units.degPerSecPerPixelPerFrame = units.degPerPixel * units.framesPerSecond;

end
