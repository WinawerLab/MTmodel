# `docs/_archive` — superseded documentation

Everything here describes a **model setup that is no longer viable**, or a work
phase that is finished. It is kept so the reasoning and the numbers stay
recoverable, and because the live docs cite it as the record of *why* the design
is what it is. **Do not treat anything here as current.**

The live documentation set is small and deliberately so:

| file | what it is |
|---|---|
| `AGENTS.md` (repo root) | orientation: what this is, how to run it, where to read next |
| `docs/MODEL_AND_LESIONS.md` | **the report** — design logic, validation, lesion results, and what each result is still good for |
| `docs/NOISE_AND_DEMYELINATION.md` | demyelination pathophysiology → lesion parameters, the noise sites, and the predictions |
| `docs/RGC_lagged_preset_summary.md` | plain-language description of the live RGC preset |
| `docs/TODO.md` | the open work plan, ordered by bearing on the clinical question |
| `literature/NOTES.md` | the papers and what each one constrains |
| `optic neuritis targets/NOTES.md` | the clinical figures the model must eventually reproduce |

---

## What is in here, and why it was retired

### `RGC_V1_design_discussion.md` (2026-07-10 → 07-13)

Narrative record of the design conversation. §1–13 work out a **biological
direction-selectivity front-end** — ON/OFF spatial read-out offset plus an ON
quadrature kernel — which was **retired on 2026-07-12**: the offset distorts V1
orientation tuning and fights the SH steerable read-out, which already yields
direction selectivity for free. §14–15 record the pivot itself and §16 corrects
the earlier "conduction delay is a lesion axis SH cannot express" claim as
oversold.

The pivot's conclusions are carried forward in `docs/MODEL_AND_LESIONS.md` §2.
Read this file only for the full argument behind them.

### `RGC_V1_unification_plan.md` (2026-07-12, increments logged to 07-16)

The refactor handoff: unify `derivative` and `fourPop` onto one class-based path.
**That refactor is complete** (increments 1–4, all verified), so this is a
finished-work log rather than a plan. Its decisions 3, 4 and 6 were superseded by
the §3.5 scope pivot before they were ever built. Its "next steps" have either
been done or moved to `docs/TODO.md`.

Still-useful residue: §5 (environment notes for a new machine) and §6
(literature list) — both now duplicated in the live docs.

### `VALIDATION_SUMMARY.md` (2026-07-13 → 07-16)

The Simoncelli & Heeger Figs. 9–14 validation and lesion campaign: 114 figures
plus quantitative metrics over 19 conditions. Two reasons it is archived rather
than live:

1. **The MT stage it measured is superseded.** Every number in it was read out of
   an MT that pooled the single mixed RGC→V1 weight matrix — the configuration
   that gets magno/parvo *backwards* relative to Maunsell et al. (1990). The
   two-stream MT mixture (`pars.rgc.mtMix`) landed 2026-08-14 and changes the MT
   read-out. Its **cell-type-specific** results (the parasol-only and ON-only
   lesions) are therefore not interpretable as biology; its class-agnostic results
   (uniform vs. stochastic amplitude and delay) remain informative about the RGC
   front-end but have not been re-measured through the current MT.
2. **Its file-location table is stale.** The 114 figures and 4 analysis files it
   points to under `explore/_figs/` no longer exist (that directory is gitignored
   and has since been cleared). The scripts that generate them are still live in
   `explore/`.

The findings that survive, with their validity stated, are in
`docs/MODEL_AND_LESIONS.md` §4.

### `SESSION_PROGRESS_2026-07-13.md`

A single session's working log. Everything it lists as "ready to run" or "next
steps" was completed by 2026-07-16, and its `/tmp/` output paths are long gone.
Superseded entirely by `VALIDATION_SUMMARY.md`, itself now archived.

---

See also `explore/_archive/`, which holds the **code** for the retired
offset+quadrature preset and the experiments that motivated retiring it.
