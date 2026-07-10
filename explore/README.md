# explore/

Validated exploratory scripts from the RGC→V1 unification work
(2026-07-10). Rough but self-contained: each adds the repo to the path from
its own location and shows figures directly. See
`../docs/RGC_V1_unification_plan.md` for the full narrative and next steps.

- **showV1RfDerivative.m** — visualize one V1 neuron's RF two ways
  (RGC-referred `Y×X×class`, stimulus-referred `Y×X×lag`); verifies the analytic
  RF against the real model (max err ~1e-16).
- **unifyDerivativeVsFourPop.m** — demonstrates that `derivative` and `fourPop`
  are the same 40-feature projection + fit with different RGC classes
  (derivative → ~0.9999, fourPop → ~0.69; cross-check err = 0).
- **compareTemporalKernels.m** — SH temporal-derivative basis vs biological
  fast/slow kernels, in time and as amplitude spectra (temporal-frequency
  coverage).

These are exploration, not part of the model. The plan is to formalize the RF
viewer into `shV1Rf` / `shShowV1Rf` and the class model into `pars.rgc.classes`
(see the plan doc).
