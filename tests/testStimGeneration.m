% testStimGeneration  Verify all stimulus generators produce correct output.

rng(1);
sz = [20 20 16];

% mkSin
s = mkSin(sz, 0, 0.1, 0.05);
shAssert(isequal(size(s), sz),        'mkSin: wrong size');
shAssert(all(isfinite(s(:))),         'mkSin: non-finite values');
shAssert(min(s(:)) >= 0,             'mkSin: values below 0');
shAssert(max(s(:)) <= 1,             'mkSin: values above 1');

% mkSin with explicit contrast 0 -> flat
s0 = mkSin(sz, 0, 0.1, 0.05, 0);
shAssertNear(s0, 0.5 * ones(sz), 1e-10, 'mkSin contrast=0 must be flat 0.5');

% mkDots
d = mkDots(sz, 0, 1.0, 0.12);
shAssert(isequal(size(d), sz),        'mkDots: wrong size');
shAssert(all(isfinite(d(:))),         'mkDots: non-finite values');
shAssert(min(d(:)) >= 0,             'mkDots: values below 0');
shAssert(max(d(:)) <= 1,             'mkDots: values above 1');

% mkBar
b = mkBar(sz, 0, 1.0, 4);
shAssert(isequal(size(b), sz),        'mkBar: wrong size');
shAssert(all(isfinite(b(:))),         'mkBar: non-finite values');

% mkPlaid (scalar sf/tf — these apply to both grating components)
p = mkPlaid(sz, pi/4, 0.1, 0.05);
shAssert(isequal(size(p), sz),        'mkPlaid: wrong size');
shAssert(all(isfinite(p(:))),         'mkPlaid: non-finite values');

% mkFract (vel=[y x], fract_dim, ampl)
f = mkFract(sz, [0 1], 1.0, 1.0);
shAssert(isequal(size(f), sz),        'mkFract: wrong size');
shAssert(all(isfinite(f(:))),         'mkFract: non-finite values');

% v12sin and mt2sin produce finite positive vectors
g = v12sin([0, 1]);
shAssert(numel(g) == 3,              'v12sin must return 3-element vector');
shAssert(all(isfinite(g)),            'v12sin must be finite');
shAssert(g(2) > 0 && g(3) > 0,      'v12sin sf and tf must be positive');

m = mt2sin([0, 1]);
shAssert(numel(m) == 3,              'mt2sin must return 3-element vector');
shAssert(all(isfinite(m)),            'mt2sin must be finite');

% mkMotionLetter (small, fast)
mlSz = [120 160 24];
[ml, mlInfo] = mkMotionLetter(mlSz, 'C', 'seed', 1, 'fCovered', 0.15, ...
    'letterSizePx', 80, 'dotSpeedPxPerFrame', 0.5, 'referenceDisplaySize', []);
shAssert(isequal(size(ml), mlSz),     'mkMotionLetter: wrong size');
shAssert(all(isfinite(ml(:))),         'mkMotionLetter: non-finite values');
shAssert(min(ml(:)) >= 0 && max(ml(:)) <= 1, 'mkMotionLetter: values outside [0,1]');
shAssert(mlInfo.pixelsPerLetter > 0,  'mkMotionLetter: letter mask must be non-empty');
shAssert(strcmp(mlInfo.letter, 'C'),   'mkMotionLetter: letter metadata wrong');
shAssert(abs(mlInfo.dotSpeedPxPerFrame - 0.5) < 1e-12, ...
    'mkMotionLetter: dotSpeedPxPerFrame must pass through unchanged');

% shModelUnits: the repo's anchored scale. NOT Simoncelli & Heeger's Appendix I
% convention, which would give 0.430 deg/px and 16 deg/s -- see shModelUnits.
u = shModelUnits();
shAssert(abs(u.degPerPixel - 0.1) < 1e-9,     'shModelUnits: 1 pixel must be 0.1 deg');
shAssert(abs(u.framesPerSecond - 50) < 1e-9,  'shModelUnits: must be 50 frames/sec');
shAssert(abs(u.degPerSecPerPixelPerFrame - 5) < 1e-9, ...
    'shModelUnits: 1 pixel/frame must be 5 deg/sec');

% mkMotionLetter must honour an explicit ppd (it was silently ignored before).
% A deg/s speed converted in model units must land on the expected px/frame.
[~, uInfo] = mkMotionLetter([64 64 4], 'C', 'seed', 1, 'referenceDisplaySize', [], ...
    'ppd', u.pixelsPerDegree, 'frameRate', u.framesPerSecond, ...
    'dotSpeedDegS', 5, 'letterSizePx', 40);
shAssert(abs(uInfo.ppd - u.pixelsPerDegree) < 1e-9, ...
    'mkMotionLetter: explicit ppd must be used, not display geometry');
shAssert(abs(uInfo.dotSpeedPxPerFrame - 5 / u.degPerSecPerPixelPerFrame) < 1e-9, ...
    'mkMotionLetter: deg/s must convert through ppd (5 deg/s -> 1 px/frame)');
shAssert(abs(uInfo.dotSpeedDegS - 5) < 1e-9, ...
    'mkMotionLetter: requested deg/s must be reported back unchanged');
shAssert(abs(uInfo.letterSizeDeg - 40 / u.pixelsPerDegree) < 1e-9, ...
    'mkMotionLetter: letterSizePx is in output-field pixels');

% Display geometry and model units are different conventions, and the gap grows
% with field size (it is ~10x at full booth resolution). Check the reference
% display's ppd is the booth's ~100 px/deg, not the model's 10 -- converting a
% deg/s speed through the wrong one is the trap the ppd option exists to avoid.
[~, bInfo] = mkMotionLetter([64 64 4], 'C', 'seed', 1, 'dotSpeedDegS', 5, 'letterSizePx', 40);
shAssert(abs(bInfo.ppdReference - 100.6) < 1, ...
    'mkMotionLetter: booth reference ppd should be ~100 px/deg at 175 cm');
shAssert(bInfo.ppdReference > 5 * u.pixelsPerDegree, ...
    'mkMotionLetter: booth ppd should be far finer than the model scale');
shAssert(abs(bInfo.ppd - bInfo.ppdReference * bInfo.fieldScale) < 1e-9, ...
    'mkMotionLetter: field ppd must be the reference ppd times fieldScale');
