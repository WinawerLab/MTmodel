# `docs/_archive` — superseded documentation

Everything here describes either a version of the model that is **no longer
viable**, or a phase of work that is finished. It is kept so the reasoning and the
numbers stay recoverable, and because the live documents cite it as the record of
*why* the design is what it is.

**Do not treat anything in here as current.** The live set is listed in `AGENTS.md`.

**Everything here also predates the 2026-08-27 re-anchor of physical units**, so
every figure in degrees, degrees/second or milliseconds carries the old labels and
is 1.3–4.3x larger than the same quantity computed today. Nothing the model
computes changed; only the labels did. See `docs/UNITS_AND_SCALE.md`.

---

## What is here, and why it was retired

### `RGC_V1_design_discussion.md` (2026-07-10 to 07-13)

A narrative record of the design conversation. Sections 1–13 work out a
**biological direction-selectivity front-end** — an ON/OFF spatial offset in the
read-out plus an ON quadrature filter. That was **retired on 2026-07-12**, because
the offset distorts V1 orientation tuning and fights the SH steerable read-out,
which already produces direction selectivity for free. Sections 14–15 record the
change of scope. Section 16 corrects the earlier claim that "conduction delay is a
lesion axis SH cannot express" as oversold.

The conclusions are carried forward in `docs/MODEL_AND_LESIONS.md` §6. Read this
file only for the full argument behind them.

### `RGC_V1_unification_plan.md` (2026-07-12, with increments logged to 07-16)

The handoff document for the refactor that unified the `derivative` and `fourPop`
paths onto one class-based path. **That refactor is complete** (increments 1–4, all
verified), so this is a log of finished work rather than a plan. Its decisions 3, 4
and 6 were superseded by the §3.5 change of scope before they were ever built. Its
"next steps" have either been done or moved to `docs/TODO.md`. The `fourPop` preset
it describes was deleted on 2026-08-25.

Still useful: §5 (notes on setting up a new machine) and §6 (the literature list),
both of which are now duplicated in the live documents.

### `VALIDATION_SUMMARY.md` (2026-07-13 to 07-16)

The Simoncelli & Heeger Figs 9–14 validation and lesion campaign: 114 figures plus
quantitative metrics over 19 conditions. Archived rather than live for two reasons.

1. **The MT stage it measured is superseded.** Every number in it was read out of
   an MT that pooled the single mixed RGC→V1 weight matrix — the configuration that
   gets magnocellular and parvocellular contributions *backwards* relative to
   Maunsell et al. (1990). The two-stream mixture (`pars.rgc.mtMix`) landed on
   2026-08-14 and changes the MT read-out. So its **cell-type-specific** results,
   the parasol-only and ON-only lesions, cannot be read as biology. Its
   class-agnostic results, the uniform and patchy amplitude and delay lesions,
   remain informative about the front-end but have not been re-measured through the
   current MT.
2. **Its table of file locations is stale.** The 114 figures and 4 analysis files
   it points to under `explore/_figs/` no longer exist; that directory is gitignored
   and has since been cleared. The scripts that generate them are still live in
   `explore/`.

The findings that survive, with their validity stated, are in
`docs/MODEL_AND_LESIONS.md` §4.7 and §5.

### `SESSION_PROGRESS_2026-07-13.md`

One session's working log. Everything it lists as "ready to run" or as a next step
was completed by 2026-07-16, and its `/tmp/` output paths are long gone. Superseded
entirely by `VALIDATION_SUMMARY.md`, which is itself now archived.

---

See also `explore/_archive/`, which holds the **code** for the retired
offset-plus-quadrature preset and the experiments that motivated retiring it.
