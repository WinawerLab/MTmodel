"""Reduced 1-D check of direction selectivity vs speed, lagged preset.

Companion to measureDirectionSelectivityVsSpeed.m, which does the same
measurement through the full MATLAB pipeline. This version exists so the
numbers in docs/RGC_lagged_preset_summary.md 7.2 can be regenerated without
MATLAB, and so the two can be cross-checked.

THE REDUCTION. The stimulus is constant in y. localDoG is separable, so a
y-constant input passes the y stage at unit gain, and every yorder >= 1 spatial
read-out is identically zero. Only the four yorder == 0 columns per class carry
anything, so dropping y is exact rather than approximate. Within each class's
10-column block (shClassV1Basis orders them s = 0..3, xorder = 0..s), the
yorder == 0 columns are at 0-based offsets 0, 2, 5, 9.

Everything else follows localClassChannel: frame-mean subtraction -> DoG ->
half-wave rectification by polarity -> causal class kernel (bigamma, zero-padded
by the class lag) -> causal trim -> spatial derivative read-out -> fitted
v1Weights -> full-wave (squaring) rectification.

Run:  python3 explore/measureDirectionSelectivityVsSpeed_reduced.py
Needs numpy, scipy, h5py. Run from the repository root.
"""
import numpy as np, scipy.io as sio, h5py, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SF = np.array(sio.loadmat(os.path.join(ROOT, 'pars', 'defaultParameters.mat'))['v1SpatialFilters'])
with h5py.File(os.path.join(ROOT, 'pars',
        'shRgcClassesMidgetParasolLagged_v1Weights_lag0123.mat'), 'r') as h:
    W = np.array(h['v1Weights']).T                      # [28 neurons x 160 features]

DEG_PER_S = 5.0                                          # shModelUnits: 1 px/frame = 5 deg/s
FSZ = SF.shape[0]
YZERO = {0: 0, 1: 2, 2: 5, 3: 9}                          # xorder -> offset in the 10-col block


def bigamma(tau1, tau2, w, n=2, L=24):
    t = np.arange(L)
    k = (t / tau1) ** n * np.exp(-t / tau1) - w * (t / tau2) ** n * np.exp(-t / tau2)
    return k / np.abs(k).max()


def gauss(sigma):
    fs = int(np.ceil(3 * sigma))
    x = np.arange(-fs, fs + 1)
    g = np.exp(-x ** 2 / (2 * sigma ** 2))
    return g / g.sum()


# class order in shRgcClassesMidgetParasolLagged: {parasol,midget} x {On,Off} x lag{0..3}
CLASSES = []
for kern, rf in [(bigamma(0.6, 1.2, 0.45), (1.6, 4.0, 0.25)),
                 (bigamma(2.0, 4.0, 0.15), (0.8, 2.0, 0.25))]:
    for pol in ('On', 'Off'):
        for lag in (0, 1, 2, 3):
            CLASSES.append((np.concatenate([np.zeros(lag), kern]), pol, rf))
assert len(CLASSES) == 16


def _conv_axis(a, f, axis):
    return np.apply_along_axis(lambda v: np.convolve(v, f, 'same'), axis, a)


def features(stim):
    """stim [X, T] -> feature maps [160, X', T']"""
    T = stim.shape[1]
    out = None
    for ci, (kern, pol, (sc, ss, sw)) in enumerate(CLASSES):
        m = stim - stim.mean(axis=0, keepdims=True)          # frame-mean subtraction
        cs = _conv_axis(m, gauss(sc), 0) - sw * _conv_axis(m, gauss(ss), 0)
        ch = np.maximum(0, cs) if pol == 'On' else np.maximum(0, -cs)
        ch = np.apply_along_axis(lambda v: np.convolve(v, kern, 'full'), 1, ch)[:, :T]
        ch = ch[:, FSZ - 1:]                                  # causal trim
        for xo in range(4):
            r = np.stack([np.correlate(ch[:, t], SF[:, xo], 'valid')
                          for t in range(ch.shape[1])], axis=1)
            if out is None:
                out = np.zeros((160,) + r.shape)
            out[ci * 10 + YZERO[xo]] = r
    return out


def grating(speed_px, fx=0.2148, X=96, T=64):
    x = np.arange(X)[:, None]
    t = np.arange(T)[None, :]
    return np.cos(2 * np.pi * fx * (x - speed_px * t))


def energy(speed_px, fx=0.2148):
    R = np.tensordot(W, features(grating(speed_px, fx)), axes=(1, 0))   # [28, X', T']
    return (R ** 2).mean(axis=(1, 2))                                   # full-wave, pooled


if __name__ == '__main__':
    speeds = [0, 0.05, 0.10, 0.25, 0.50, 1, 2, 5, 10]
    rows = [(s, energy(s / DEG_PER_S), energy(-s / DEG_PER_S)) for s in speeds]
    dsi = {s: np.abs((p - n) / (p + n + 1e-300)) for s, p, n in rows}
    ref = np.median(dsi[2])

    print('Direction selectivity vs stimulus speed, lagged preset (reduced 1-D)')
    print('1 px/frame = %.1f deg/sec\n' % DEG_PER_S)
    print(' %-12s %-10s  %-10s %-10s %-12s' %
          ('speed deg/s', 'px/frame', 'median|DSI|', 'max|DSI|', 'frac of 2deg/s'))
    for s in speeds:
        a = dsi[s]
        print(' %-12.2f %-10.4f  %-10.4f %-10.4f %-12.3f' %
              (s, s / DEG_PER_S, np.median(a), a.max(), np.median(a) / ref))
    assert dsi[0].max() < 1e-12, 'zero-speed DSI must be identically zero'
    print('\nzero-speed row is exactly 0, as it must be (same movie twice).')
