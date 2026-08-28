# `literature/` — what is here, and why

The papers behind the RGC → V1 → MT modelling work. This file records what each
one establishes and how it bears on decisions in this repo.

> **The driving question** (stated 2026-08-13). Can damage at the level of retinal
> ganglion cells explain the optic-neuritis pattern of **(a) a slower visual evoked
> potential** and **(b) worse recognition of shapes defined only by motion, at slow
> speeds**?

The notes below are oriented to that question. See `docs/TODO.md` for the resulting
work plan, and `docs/MODEL_AND_LESIONS.md` for what has been measured.

---

## Is MT driven by the magnocellular pathway?

### Maunsell, Nealey & DePriest (1990), *J Neurosci* 10:3323–3334

"Magnocellular and parvocellular contributions to responses in the middle temporal
visual area (MT) of the macaque monkey."
DOI [10.1523/JNEUROSCI.10-10-03323.1990](https://doi.org/10.1523/JNEUROSCI.10-10-03323.1990) ·
PMID 2213142 · PMC6570195 *(PDF not in folder — the publisher blocks automated
download)*

The direct test. They recorded MT responses while **selectively and reversibly
blocking the magnocellular or the parvocellular layers of the LGN**. From the
abstract:

- **Magnocellular block:** MT responses "consistently reduced", and the reduction
  was "almost always pronounced and often complete."
- **Parvocellular block:** "rarely produced striking changes", and "typically had
  very little effect."
- **But not zero:** "unequivocal parvocellular contributions could be demonstrated
  for a **minority** of MT responses."
- **Both blocked:** responses "essentially eliminated."

So the textbook claim survives the direct test — MT is predominantly magnocellular
— while the minority parvocellular contribution is real. Their own conclusion
favours largely segregated M and P signals running through to high-level cortex.

**This is the calibration target for `pars.rgc.mtMix`.** All four rows above are
reproduced by the two-stream MT at `alpha = 0.10`; see `docs/MODEL_AND_LESIONS.md`
§4.4 for the table.

### Sincich & Horton (2005), *Annu Rev Neurosci* 28:303–326

"The circuitry of V1 and V2: integration of color, form, and motion."
DOI [10.1146/annurev.neuro.28.061604.135731](https://doi.org/10.1146/annurev.neuro.28.061604.135731) ·
PMID 16022598 · **PDF in folder**

The counterweight. This review argues that the tidy picture of three parallel
streams oversimplifies what V1 actually forwards. The patch and interpatch
projections to V2 do not cleanly divide colour, form and motion, and M and P
signals **mix substantially** beyond the input layers.

**How to hold the two papers together.** They answer different questions and are
not really in conflict. Segregation is strongest at the **input layers** (M to 4Cα,
P to 4Cβ) and breaks down progressively downstream, which is Sincich & Horton's
point. Maunsell et al. measured the **functional dependence** of MT, which can stay
magnocellular even if individual V1 neurons downstream of layer 4 receive mixed
input — a mixed neuron can still be driven mainly by its magnocellular component.

The practical reading for this repo: **mixed V1 input is anatomically fine** (this
model has no input layer to segregate anyway), **but MT's functional dependence
should still come out magnocellular.**

### Nassi & Callaway (2006, 2007)

These two turned "make the M/P labels mean something" from an open-ended fitting
problem into a bounded change: one new fit and one new scalar.

- **Nassi & Callaway (2006)**, Fig 7A: after an injection into MT, the two-synapse
  label in layer 4C is **96–97% in M-dominated 4Cα** and about 3% in P-dominated
  4Cβ. (V3 is 98/1.) V2 is the mixed one, at about 70% 4Cα and 29% 4Cβ for
  blob-unbiased injections.
- **Nassi & Callaway (2006)**, at 6-day survival: MT *does* receive substantial P
  input, but by a **detour of 3 to 5 synapses** — 4Cβ to layer 4B pyramidal cells
  to V2 thick stripes to MT — bypassing the 4B stellate cells entirely.
- **Nassi & Callaway (2007)**: layer 4B cells that project to MT are **76% spiny
  stellate**, which receive input only from 4Cα. They have more than twice the soma
  area (329 against 146 µm²), more total dendrite (6908 against 4163 µm), about 20%
  of their dendritic length in 4Cα, and sit deeper in 4B. The 4B cells projecting
  to V2 are **83% pyramidal** and integrate mixed M and P. Their Fig 5: about 20%
  of layer 4B projects to MT and is M-dominated; about 80% projects to V2 and is
  mixed.

Their conclusion: MT-projecting cells are specialised for **fast transmission of
magnocellular signals**, while V2-projecting cells do slower computations on mixed
input.

**The structural point that shaped the design: biology puts the M/P selectivity in
two distinct populations, not in one graded weighting.** Before 2026-08-14 this
model had one population, and it was the mixed one. See
`docs/MODEL_AND_LESIONS.md` §2.3.

---

## The model being implemented

### Simoncelli & Heeger (1998), *Vision Research* 38:743–761

The model this repo implements. Two points that are easy to miss:

- **Units (Appendix I, p. 761).** Frequency units are fixed so the tiling annulus
  crosses ω_t = 8 cycles/sec and ω_x = 0.5 cycles/deg. With this codebase's filters
  that would make **1 pixel = 0.430 deg** and **1 frame = 26.9 ms (37.2 fps)**, so
  1 pixel/frame = 16 deg/sec. **This repo does not use SH's anchors.** Since
  2026-08-27 `pars/shModelUnits.m` sets 0.1 deg/pixel and 20 ms/frame, i.e. 5
  deg/sec per pixel/frame, because SH's scale puts every stage of the model 3–15x
  too coarse. The model's responses are the same either way. Derivation and
  consequences in `docs/RGC_lagged_preset_summary.md` §7.1.
- **Static normalization (p. 758).** SH flag as "one notable deficiency" that their
  outputs correspond to **steady-state firing rates**. Note the scope of that
  carefully. The feedforward temporal filtering *is* causal, so response latency is
  measurable. What is missing is the **dynamics of normalization** in cortex (see
  ORGaNICs, and delayed-normalization accounts of temporal dynamics in visual
  cortex). An earlier draft overstated this as "cannot predict latency at all",
  which is wrong. See `docs/TODO.md` §3.

SH also note (p. 754) that parvocellular neurons make up about 90% of the LGN while
the majority of MT afferents appear to be magnocellular, citing Tootell et al.
(1988) and Maunsell et al. (1990).

### Adelson & Bergen (1985); Priebe (2012); De Valois (2000)

Background on motion energy, the direction-selectivity computation, and the
space–time structure of V1 receptive fields.

### Chariker & Shapley (2021, 2022); Freeman (2021)

The biological direction-selectivity mechanism — ON quadrature plus a spatial
offset — that was explored and then **retired** in the 2026-07-12 change of scope.
Kept for provenance; see `explore/_archive/README.md` and
`docs/MODEL_AND_LESIONS.md` §6.1.

### Kling et al. (2020)

The functional organisation of midget and parasol ganglion cells. This is the
intended calibration target for the filter time courses, and it is now actionable
because the frame rate is anchored: at 50 fps the preset's midget filter peaks at
about 80 ms and its parasol filter at about 20 ms, both of which now fall inside
the measured ranges. What is still off is the tail — a 280 ms sign reversal and a
480 ms filter length. `docs/TODO.md` §6.

---

## Demyelination biophysics — the source for the noise model

### Naud & Longtin (2019), *J Math Neurosci* 9:3

"Linking demyelination to compound action potential dispersion with a
spike-diffuse-spike approach."
DOI [10.1186/s13408-019-0071-6](https://doi.org/10.1186/s13408-019-0071-6)
*(PDF not in folder; free preprint at
[biorxiv 10.1101/501379](https://www.biorxiv.org/content/10.1101/501379))*

A **stochastic** model: random excitability at the nodes plus a linear filtering
operation for propagation between them. It shows how **weak and sporadic** damage
to an axon produces both delay *and* **dispersion** of the compound action
potential — that is, it derives the two together from one insult rather than
imposing them as separate parameters.

That is the right level of description to import for
`docs/NOISE_AND_DEMYELINATION.md`. It gives a principled form for trial-to-trial
jitter and stochastic conduction block, neither of which the current lesion
parameterization can express at all.

**Read the corrected version.** Two corrections are published, one concerning the
direction of the changes in transverse resistance and capacitance under
demyelination
([10.1186/s13408-019-0076-1](https://doi.org/10.1186/s13408-019-0076-1),
[10.1186/s13408-020-00083-y](https://doi.org/10.1186/s13408-020-00083-y)).

**Not a source for:** g-ratio or internode length after remyelination in the CNS,
or the claim that remyelination suppresses jitter. Those are still ungrounded — see
the provenance warning in `docs/NOISE_AND_DEMYELINATION.md` §2.
