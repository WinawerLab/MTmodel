# Optic neuritis targets

Figures from the clinical literature that the model is meant to **reproduce** —
the empirical targets for the driving question in `docs/TODO.md`:

> Can an RGC-level lesion explain the optic-neuritis pattern of
> **(a) increased VEP latency** and **(b) reduced recognition of motion-defined
> form at low speeds**?

This folder is for the *target data*. It is distinct from `literature/`, which
holds the papers describing the **model and its mechanisms** (Simoncelli &
Heeger, Nassi & Callaway, Kling, Chariker, …).

## Contents

| file | source | what it targets |
|---|---|---|
| `10.1002-ana.22692Figurefig1.pptx` | Raz et al., *Demyelination affects temporal aspects of perception: An optic neuritis study*, Ann Neurol 2012;71(4):531–538, doi:10.1002/ana.22692 | deficit (a) — temporal/timing aspects of perception after ON |
| *(not yet in folder)* | Brusa, Jones & Plant, *Long-term remyelination after optic neuritis: a 2-year visual evoked potential and psychophysical serial study*, Brain 2001;124(3):468–479, [doi:10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468) | deficit (a) — the **recovery trajectory**; see below |

## When adding a figure

Record, in the table above: the **full citation and DOI**, and **which deficit
(a or b) it constrains**. A figure with no citation is not usable as a target.

Note what would count as reproducing it — the model-side observable and the
comparison. `docs/TODO.md` §2 flags that this is not yet pinned down for VEP
latency (time-to-peak of the population transient? cross-correlation lag against
the unlesioned response?), and that quoting a number in milliseconds before
settling it would be premature.

## Units

Model outputs are in pixels and frames. To compare against a clinical figure,
convert with `pars/shModelUnits.m`: **1 pixel = 0.430 deg**, **1 frame = 26.9 ms
(37.2 fps)**, **1 pixel/frame = 16 deg/sec**. Two standing caveats before any
quantitative claim:

- The model's RGC receptive fields are ~an order of magnitude larger than real
  midget/parasol cells at this scale (`docs/RGC_lagged_preset_summary.md` §7.1).
- MT is tuned to {0, 1, 6} px/frame = {0, 16, 96} deg/s, so the clinically
  interesting low-speed band sits **below** MT's slowest non-zero tuned speed
  (`docs/TODO.md` §3).

## Copyright

These are published figures kept for research reference, as with the PDFs in
`literature/`. Do not redistribute them or reproduce them in a manuscript
without permission — cite and redraw instead.


## Brusa, Jones & Plant (2001) — why this one is worth pulling

31 patients, **serial** VEP and psychophysics over 24 months. It is the target for
the recovery-trajectory prediction in `docs/NOISE_AND_DEMYELINATION.md` §5.4,
and it is harder than the clean version of that prediction:

- VEP latency **does** shorten significantly — 6–7 ms between months 3 and 6, a
  further ~4 ms by 24 months. So latency recovery is partial, not absent.
- Contrast sensitivity improved through month 9 and then **declined**.
- The authors conclude long-term remyelination may mostly protect axons from
  degeneration rather than restore function.

Two consequences for the model. The dissociation prediction must be stated as a
**rate** difference (variability-driven measures recovering faster and more
completely than mean latency), not an absolute one. And — important for the
planned affected-vs-fellow-eye design — **they report the fellow eye
deteriorating over the same window**, so the fellow eye is not a clean
within-subject control.
