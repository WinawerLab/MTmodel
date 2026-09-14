function booth = boothDisplay()
% boothDisplay  Display and dot parameters of the booth form-from-motion experiment.
%
%   booth = boothDisplay() returns the parameters of the speed-by-coherence
%   experiment as it runs in the CRT room (Parameters.m, setupDisplay.m and
%   runSingleTrial.m of the Coherence Experiment code, checked 2026-09-13),
%   and how one booth frame maps onto the model's pixels and frames.
%   mkBoothLetterMovie draws a trial with these parameters.
%
%   Fields:
%     screenSizePx         [960 1280], [height width]
%     screenWidthCm        39
%     viewDistCm           175
%     pixelsPerDegree      100.66, from the screen width and viewing distance,
%                          computed as in setupDisplay.m
%     frameRate            85 frames/s (the code moves the dots by the measured
%                          flip interval; here every frame lasts 1/85 s)
%     durationSec          4
%     dotDiameterPx        4: white disks, anti-aliased (DrawDots mode 2)
%     fractionCovered      0.5: each population (letter, background) has enough
%                          dots to cover half the screen
%     lifetimeSec          0.1
%     letterSizeArcmin     168
%     letterSizePx         282: font size of the letter, round(168/60*ppd)
%     fontName             "Sloan"
%     background           0.5 grey
%     dotValue             1, white
%     pixelsPerModelPixel  10: a model pixel is a 10 x 10 block of booth pixels
%     modelFrameRate       50 frames/s (shModelUnits)
%     modelSize            [96 128 200]: model pixels and frames of one trial
%
%   A model pixel is then 10/100.66 = 0.0993 deg, against the 0.1 deg of
%   shModelUnits. The 0.7% difference is ignored.
%
%   See also mkBoothLetterMovie, shModelUnits

    screenSizePx = [960 1280];
    screenWidthCm = 39;
    viewDistCm = 175;
    screenWidthDeg = 2*atand(screenWidthCm/(2*viewDistCm));
    pixelsPerDegree = screenSizePx(2)/screenWidthDeg;
    letterSizeArcmin = 168;
    arcminPerDegree = 60;
    frameRate = 85;
    durationSec = 4;
    pixelsPerModelPixel = 10;
    units = shModelUnits();
    modelFrameRate = units.framesPerSecond;

    booth = struct( ...
        "screenSizePx", screenSizePx, ...
        "screenWidthCm", screenWidthCm, ...
        "viewDistCm", viewDistCm, ...
        "pixelsPerDegree", pixelsPerDegree, ...
        "frameRate", frameRate, ...
        "durationSec", durationSec, ...
        "dotDiameterPx", 4, ...
        "fractionCovered", 0.5, ...
        "lifetimeSec", 0.1, ...
        "letterSizeArcmin", letterSizeArcmin, ...
        "letterSizePx", round(letterSizeArcmin/arcminPerDegree*pixelsPerDegree), ...
        "fontName", "Sloan", ...
        "background", 0.5, ...
        "dotValue", 1, ...
        "pixelsPerModelPixel", pixelsPerModelPixel, ...
        "modelFrameRate", modelFrameRate, ...
        "modelSize", [screenSizePx/pixelsPerModelPixel, round(durationSec*modelFrameRate)]);
end
