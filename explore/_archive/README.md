# `explore/_archive` — retired and superseded scripts

Most of this belongs to the **retired** approach of building direction selectivity
in the retina: `shRgcClassesMidgetParasol`, the preset with an ON/OFF spatial
offset and an ON quadrature filter. It was superseded on 2026-07-12 by the change
of scope recorded in `docs/_archive/RGC_V1_unification_plan.md` §3.5 and
`docs/_archive/RGC_V1_design_discussion.md` §14–15.

**Do not use that preset for new work.** The live biological front-end is
`pars/shRgcClassesMidgetParasolLagged.m`. This material is kept only because the
design documents cite it as the evidence *for* the change of scope, and those
results should stay reproducible.

Why it was retired, in one line each:

- The fixed ON/OFF spatial offset **distorts V1 orientation tuning**, and it does
  not rotate with a neuron's preferred direction (`probeOffsetOrientation.m`).
- It capped out near **0.68** correlation with the legacy V1, where the lagged
  preset reaches about 0.98, flat across temporal frequency
  (`testLaggedBiologicalFidelity.m`). So the apparent "0.70 biological ceiling" was
  an artifact of using two unlagged filters, not a biological wall.

Contents:

| file | what it was for |
|---|---|
| `shRgcClassesMidgetParasol.m` | the retired preset itself: 4 classes, offset plus quadrature |
| `probeOffsetOrientation.m` | showed that the offset distorts orientation — the main reason for the change of scope |
| `testLaggedBiologicalFidelity.m` | the 0.68 against 0.98 comparison (needs the retired preset as its baseline) |
| `lesionDeltaTest.m` | the §13 lesion-delta test, whose conclusion was later corrected in design-discussion §16 |
| `showMidgetParasolV1Weights.m` | visualization of the fitted 28×40 weight matrix |
| `verifyClassPathBiological.m` | ad-hoc end-to-end check, superseded by `tests/testClassPathBiological.m` |
| `prototypeOnOffDelayDS.m` | the ON/OFF delay-against-quadrature prototype — the experiment the retired approach was built on |
| `verifyClassPathDerivative.m` | ad-hoc check, superseded by `tests/testClassPathDerivative.m` |
| `verifyClassPathFourPop.m` | ad-hoc check for the `fourPop` preset, which was deleted on 2026-08-25 |
| `showV1RfDerivative.m` | two-view receptive field visualization, superseded by `help/shV1Rf.m` and `show/shShowV1Rf.m` |

The last four rows are not part of that retirement. They are ad-hoc checks and
visualizations that live code — `tests/` and `help/shV1Rf.m` — now covers properly.

`tests/runAllTests.m` runs `addpath(genpath(repoRoot))`, so these files are still on
the MATLAB path and will run. The folder name is the signal that they are
historical, not current.
