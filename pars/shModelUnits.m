% units = shModelUnits()
%
% The model's physical scale: what one pixel and one frame mean in degrees
% and seconds.
%
%   1 pixel = 0.1 deg      (10 pixels/deg)
%   1 frame = 20 ms        (50 frames/sec)
%   1 pixel/frame = 5 deg/sec
%
% Nothing in the model computes in degrees or seconds. Every filter is defined
% in samples: the RGC receptive fields in pixels, the RGC kernels in frames, the
% V1 filter bank as a fixed 9-tap set, the MT pooling filter as
% mkGaussianFilter(3). This function is a LABEL for that grid, not a parameter
% of it. Changing the numbers here changes no computation and invalidates no
% result. It changes only where in the visual system the whole cascade is taken
% to sit.
%
% Use this instead of a display's physical geometry whenever a stimulus
% parameter has to be expressed in the units the model's filters actually live
% in. The booth runs at about 100 px/deg and 75 Hz, so a stimulus has to be
% resampled onto this grid: about 10x in space (Nyquist 5 cyc/deg) and 1.5x in
% time (Nyquist 25 Hz).
%
% ---------------------------------------------------------------------------
% THIS DISAGREES WITH THE PUBLISHED PAPER. Read this before quoting a number.
% ---------------------------------------------------------------------------
%
% Simoncelli & Heeger (1998) Appendix I, p. 761 pins the scale differently:
% frequency units are fixed so the tiling annulus crosses the temporal-frequency
% axis at 8 cycles/sec and the spatial-frequency axes at 0.5 cycles/deg. In this
% codebase both the spatial and temporal 3rd-derivative filters peak at 0.2148
% cycles/sample, so SH's convention gives 2.33 pixels/deg (0.430 deg/pixel),
% 37.2 frames/sec (26.9 ms/frame), and 1 pixel/frame = 16 deg/sec. SH also
% describe their normalization pool as tuned to "moderate speeds (16 deg/sec)",
% which is consistent with that.
%
% This repo does NOT use SH's anchors, and has not since 2026-08-27. Under the
% anchors above the model's filters peak at 2.148 cyc/deg and 10.74 cyc/sec, and
% its preferred speed is 5 deg/sec, not 16. Consequences:
%
%   * Every deg/s, deg, and ms figure in this repo is 3.2x smaller than the same
%     figure computed under SH's convention (16/5 = 3.2 for speed; 4.3x for
%     length; 1.34x for time). Older material may still carry the SH labels.
%   * The model's RESPONSES are identical either way. All existing results stand
%     and no refit is needed; only their labels move.
%   * Do not cite SH's Appendix I as the source of these numbers. Cite this file.
%
% Why the departure: under SH's anchors every stage of the model sits 3-15x too
% coarse. The midget centre is 0.34 deg against a real 0.02-0.05, the MT
% receptive field is 6.4 deg, and MT's slowest moving unit is 16 deg/s, which is
% above the entire clinical low-speed band this project is about. At 10 px/deg
% the parasol centre (0.16 deg), the V1 preferred spatial frequency (2.15
% cyc/deg), and the MT receptive field (~1.5 deg) all land in range, and MT's
% slow unit sits at 5 deg/s inside the clinical band. The derivation and the
% stage-by-stage table are in docs/UNITS_AND_SCALE.md.
%
% What re-anchoring does NOT fix, so that it is not rediscovered later:
%
%   * The midget centre is still about 2-4x too large (0.08 deg against a real
%     0.02-0.05). The model's whole spatial ladder, from midget centre to MT
%     receptive field, spans about 4.6x where real cortex spans 25-35x. No single
%     anchor can put both ends right. Only a front-end running the retina on a
%     finer grid than V1 would.
%   * The 0.05 deg/s speed threshold measured psychophysically with
%     motion-defined letters is out of the model's reach IN ANY UNITS. See
%     docs/UNITS_AND_SCALE.md section 6.
%
% Output fields:
%   pixelsPerDegree, degPerPixel
%   framesPerSecond, msPerFrame
%   degPerSecPerPixelPerFrame   speed conversion factor (5 deg/s)
%   peakCyclesPerSample         where the 3rd-derivative filters peak, 0.2148
%   cyclesPerDegAtPeak          that peak in cycles/deg  (2.148)
%   cyclesPerSecAtPeak          that peak in cycles/sec  (10.74)
%
% See also: mt2sin, shPars, docs/UNITS_AND_SCALE.md

function units = shModelUnits()

    % The anchors. These two numbers are the whole of the model's physical
    % scale; everything else here is derived from them.
    pixelsPerDegree = 10;
    framesPerSecond = 50;

    % Peak of the 3rd-derivative filters, in cycles/sample (both axes). A
    % property of the filter bank in defaultParameters.mat, not a choice.
    peakCyclesPerSample = 0.2148;

    units.pixelsPerDegree = pixelsPerDegree;
    units.degPerPixel     = 1 / pixelsPerDegree;
    units.framesPerSecond = framesPerSecond;
    units.msPerFrame      = 1000 / framesPerSecond;
    units.degPerSecPerPixelPerFrame = units.degPerPixel * framesPerSecond;

    units.peakCyclesPerSample = peakCyclesPerSample;
    units.cyclesPerDegAtPeak  = peakCyclesPerSample * pixelsPerDegree;
    units.cyclesPerSecAtPeak  = peakCyclesPerSample * framesPerSecond;

end
