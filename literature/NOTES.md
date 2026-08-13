# `literature/` — what's here and why

Papers backing the RGC→V1→MT modelling work. This file records what each one
establishes and, where relevant, how it bears on decisions in this repo.

The driving clinical question (stated 2026-08-13): **can an RGC-level lesion
explain the optic-neuritis pattern of (a) increased VEP latency and (b) reduced
recognition of motion-defined form at low speeds?** Notes below are oriented to
that question. See `docs/TODO.md` for the resulting work plan.

---

## Magno/parvo segregation, and whether MT is magno-driven

### Maunsell, Nealey & DePriest (1990), *J Neurosci* 10:3323–3334
"Magnocellular and parvocellular contributions to responses in the middle
temporal visual area (MT) of the macaque monkey."
DOI [10.1523/JNEUROSCI.10-10-03323.1990](https://doi.org/10.1523/JNEUROSCI.10-10-03323.1990) ·
PMID 2213142 · PMC6570195 *(PDF not in folder — publisher blocks automated download)*

The direct test. They recorded MT responses while **selectively and reversibly
blocking the magnocellular or parvocellular layers of the LGN**. Findings, from
the abstract:

- **Magnocellular block**: MT responses "consistently reduced"; the reduction was
  "almost always pronounced and often complete."
- **Parvocellular block**: "rarely produced striking changes" and "typically had
  very little effect."
- **But not zero**: "unequivocal parvocellular contributions could be demonstrated
  for a **minority** of MT responses."
- **Combined block**: responses "essentially eliminated."

So the textbook claim survives the direct test — MT is predominantly
magnocellular — while the minority parvocellular contribution is real. Their
own conclusion favours *largely segregated* M and P signals through to high-level
cortex.

### Sincich & Horton (2005), *Annu Rev Neurosci* 28:303–326
"The circuitry of V1 and V2: integration of color, form, and motion."
DOI [10.1146/annurev.neuro.28.061604.135731](https://doi.org/10.1146/annurev.neuro.28.061604.135731) ·
PMID 16022598 · **PDF in folder**

The counterweight. Reviews V1/V2 circuitry and argues the tidy three-parallel-
streams picture oversimplifies what V1 actually forwards: the patch/interpatch
projections to V2 do not cleanly partition colour, form, and motion, and M/P
signals **intermingle substantially** beyond the input layers.

**How to hold the two together.** They are answering different questions and are
not really in conflict:

- Segregation is strongest at the **input layers** (M → 4Cα, P → 4Cβ) and
  progressively breaks down downstream, which is Sincich & Horton's point.
- Maunsell et al. measured **functional dependence** of MT, which can remain
  magno-dominated even if individual V1 neurons downstream of layer 4 receive
  mixed input — a mixed neuron can still be driven mainly by its magno component.

The practical reading for this repo: **mixed V1 input is anatomically fine**
(this model has no input layer to segregate anyway), **but MT's functional
dependence should still come out magno-dominated.**

### Bearing on this model — a measured discrepancy

Simoncelli & Heeger themselves note (p. 754) that parvocellular neurons are ~90%
of the LGN while the majority of MT afferents appear magnocellular, citing Tootell
et al. (1988) and Maunsell et al. (1990). The lagged biological front-end built on
top of their model does **not** reproduce that. Measured 2026-08-13 from the fitted
28×160 weight matrix and by full class knockout:

| measurement | result |
|---|---|
| parasol share of \|weight\|, per V1 neuron | 0.249–0.377 (median 0.316) — every neuron mixed, none segregated |
| MT with **parasol** classes at gain 0 | direction peak *rises* 1.033 → 1.291; coherence 1.363 → 0.346 |
| MT with **midget** classes at gain 0 | direction tuning collapses (~0); coherence 1.363 → 0.052 |

The model's MT is **midget-dominated** — the opposite of Maunsich/Maunsell's
result. The cause is mundane: the weight matrix is fit to reproduce SH's V1
output, which has no M/P distinction, so nothing in the objective encodes
magno-dominance. The midget/parasol labels are currently **decorative with
respect to the fit**.

This matters for the clinical question: any cell-type-specific lesion result from
the current preset reflects an arbitrary fitting outcome, not biology. Parked as
TODO item 1 in `docs/TODO.md`.

---

## The model being implemented

### Simoncelli & Heeger (1998), *Vision Research* 38:743–761
The model this repo implements. Two points recovered from it that are easy to miss:

- **Units (Appendix I, p. 761).** Frequency units are fixed so the tiling annulus
  crosses ω_t = 8 cycles/sec and ω_x = 0.5 cycles/deg. With this codebase's
  filters that makes **1 pixel = 0.430 deg** and **1 frame = 26.9 ms (37.2 fps)**,
  so 1 pixel/frame = 16 deg/sec. Derivation and consequences in
  `docs/RGC_lagged_preset_summary.md` §7.1.
- **Static normalization (p. 758).** SH flag as "one notable deficiency" that
  outputs correspond to **steady-state firing rates**. Note the scope of this
  carefully: the *feedforward temporal filtering is causal*, so response latency
  is measurable; what is missing is the **dynamics of normalization** in cortex
  (cf. ORGaNICs; delayed-normalization models of visual-cortex temporal dynamics).
  See `docs/TODO.md` item 2 — an earlier draft overstated this as "cannot predict
  latency at all," which is wrong.

### Adelson & Bergen (1985); Priebe (2012); De Valois (2000)
Background on motion energy, the direction-selectivity computation, and V1
spatiotemporal RF structure. Used in the §2.5–2.7 design reasoning.

### Chariker & Shapley (2021, 2022); Freeman (2021)
The biological direction-selectivity mechanism (ON/OFF quadrature + spatial
offset) explored and then **retired** in the 2026-07-12 scope pivot. Retained for
provenance; see `explore/_archive/README.md`.

### Kling et al. (2020)
Functional organization of midget and parasol RGCs — the intended calibration
target for kernel time courses. Now actionable, since the frame rate is pinned
(above): the preset's midget kernel peaks at ~107 ms and its parasol at ~27 ms,
which can finally be checked against measured time courses.
