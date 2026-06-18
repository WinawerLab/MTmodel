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
