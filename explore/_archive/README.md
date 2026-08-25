# `explore/_archive` — retired and superseded scripts

Most of this belongs to the **retired** biological direction-selectivity
approach: `shRgcClassesMidgetParasol`, the ON/OFF spatial-offset + ON-quadrature
preset. It was superseded on 2026-07-12 by the scope pivot recorded in
`docs/_archive/RGC_V1_unification_plan.md` §3.5 and `docs/_archive/RGC_V1_design_discussion.md`
§14–15.

**Do not use this preset for new work.** The live biological preset is
`pars/shRgcClassesMidgetParasolLagged.m`. This material is kept only because the
design docs cite it as the evidence *for* the pivot, and those results should stay
reproducible.

Why it was retired, in one line each:

- The fixed ON/OFF translational offset **distorts V1 orientation tuning** and does
  not rotate with a neuron's preferred direction (`probeOffsetOrientation.m`).
- It capped out near **0.68** legacy-V1 correlation; the lagged preset reaches
  **~0.985**, flat across temporal frequency (`testLaggedBiologicalFidelity.m`) —
  so the "~0.70 biological ceiling" was an artifact of using two unlagged kernels,
  not a biological wall.

Contents:

| file | what it was for |
|---|---|
| `shRgcClassesMidgetParasol.m` | the retired preset itself (4 classes, offset + quadrature) |
| `probeOffsetOrientation.m` | showed the offset distorts orientation — the main reason for the pivot |
| `testLaggedBiologicalFidelity.m` | the 0.68 vs 0.985 comparison table (needs the retired preset as its baseline) |
| `lesionDeltaTest.m` | the §13 lesion-delta test, whose conclusion was later corrected in design-discussion §16 |
| `showMidgetParasolV1Weights.m` | visualization of the fitted 28x40 weight matrix |
| `verifyClassPathBiological.m` | ad-hoc end-to-end check, superseded by `tests/testClassPathBiological.m` |
| `prototypeOnOffDelayDS.m` | the ON/OFF delay-vs-quadrature DS prototype — the experiment the retired approach was built on |
| `verifyClassPathDerivative.m` | ad-hoc check, superseded by `tests/testClassPathDerivative.m` |
| `verifyClassPathFourPop.m` | ad-hoc check, superseded by `tests/testClassPathFourPop.m` |
| `showV1RfDerivative.m` | two-view RF visualization, superseded by `help/shV1Rf.m` + `show/shShowV1Rf.m` |

The last four rows are not part of that retirement — they are ad-hoc checks and
visualizations that live code (`tests/`, `help/shV1Rf.m`) now covers properly.

`tests/runAllTests.m` does `addpath(genpath(repoRoot))`, so these files are still
on the MATLAB path and will run — the folder name is the signal that they are
historical, not current.
