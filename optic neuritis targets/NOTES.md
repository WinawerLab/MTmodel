# Optic neuritis targets

Quantitative targets from the clinical literature that the model is meant to
**reproduce**. These are the empirical targets for the driving question:

> Can damage at the level of retinal ganglion cells explain the optic-neuritis
> pattern of **(a) a slower visual evoked potential** and **(b) worse recognition
> of shapes defined only by motion, at slow speeds**?

This folder holds the *target data*. It is separate from `literature/`, which holds
the papers describing the **model and its mechanisms** (Simoncelli & Heeger, Nassi
& Callaway, Kling, Chariker, and so on).

## What lives here, and what does not

**The published figures are not committed.** They are copyrighted, and the repo
does not need them. What is committed is a **table of numbers derived from each
figure**, which is what the model is actually compared against. Keep the source
figure locally if you like — `.pptx`, `.pdf` and image files in this folder are
gitignored — but the table is the artifact.

| file | source | what it targets |
|---|---|---|
| [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md) | Raz et al., *Demyelination affects temporal aspects of perception: an optic neuritis study*, Ann Neurol 2012;71(4):531–538, [doi:10.1002/ana.22692](https://doi.org/10.1002/ana.22692) | deficit (b) — object-from-motion performance across dot speeds 0.05–2 °/s, at four time points, with a static control |
| *(no table yet)* | Brusa, Jones & Plant, *Long-term remyelination after optic neuritis: a 2-year visual evoked potential and psychophysical serial study*, Brain 2001;124(3):468–479, [doi:10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468) | deficit (a) — the **recovery trajectory**; see below |

## When you add a target

Write a table file like [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md),
and record in it:

- the **full citation and DOI**, and **which deficit it constrains**, (a) or (b);
- **how the numbers were obtained** — digitized by eye, read from a table in the
  paper, or supplied by the authors — and the resulting uncertainty. A digitized
  value is not a published value and must never be quoted as one;
- **what the error bars mean**, or an explicit statement that the source does not
  say;
- **what would count as reproducing it** — the model-side observable, and the
  comparison. Say plainly which features are testable now and which are not.

Then add a row to the table above.

`docs/TODO.md` §4 flags that the model-side observable is not yet settled for VEP
latency. Is it the time to peak of the population response to a transient? The
cross-correlation lag against the unlesioned response? Quoting a number in
milliseconds before settling that would be premature.

## Units

Model outputs are in pixels and frames. To compare against a clinical figure,
convert with `pars/shModelUnits.m`: **1 pixel = 0.1 deg**, **1 frame = 20 ms
(50 fps)**, **1 pixel/frame = 5 deg/sec**. This anchor was set on 2026-08-27 and
is **not** Simoncelli & Heeger's Appendix I convention, which would give 0.430
deg/pixel and 16 deg/sec; figures written before that date are 3.2x larger.

Three standing caveats before any quantitative claim:

- The model's midget receptive field centre is still 2–4x larger than a real one
  (0.08 deg against 0.02–0.05), and no choice of units fixes it
  (`docs/RGC_lagged_preset_summary.md` §7.1).
- MT is tuned to {0, 1, 6} px/frame = {0, 5, 30} deg/s. The clinically interesting
  low-speed band now straddles MT's slowest moving unit rather than sitting wholly
  below it, but MT is still weakly driven at the bottom of that band
  (`docs/TODO.md` §6).
- The **0.05 deg/sec** psychophysical speed threshold is out of the model's reach
  in any units (`docs/RGC_lagged_preset_summary.md` §7.2).

## Brusa, Jones & Plant (2001) — why this one is worth pulling

31 patients, with **serial** VEP and psychophysics over 24 months. It is the target
for the recovery-trajectory prediction in `docs/NOISE_AND_DEMYELINATION.md` §5.4,
and it is harder than the clean version of that prediction:

- VEP latency **does** shorten significantly — 6 to 7 ms between months 3 and 6,
  and about 4 ms more by 24 months. So latency recovery is partial, not absent.
- Contrast sensitivity improved through month 9 and then **declined**.
- The authors conclude that long-term remyelination may mostly protect axons from
  degenerating rather than restore function.

Two consequences for the model. The prediction that recovery separates latency from
discriminability has to be stated as a difference in **rate** — measures driven by
variability recovering faster and more completely than mean latency — not as an
absolute dissociation. And, important for the planned affected-eye versus
fellow-eye design, **they report the fellow eye deteriorating over the same
window**, so the fellow eye is not a clean within-subject control.

## Copyright

Any published figure kept in this folder is held locally for research reference
only, and is gitignored rather than committed. Do not redistribute one, and do not
reproduce one in a manuscript without permission — cite and redraw instead.

The derived tables are a different matter: measurements read off a figure are
facts, not the figure, and committing them is fine. Always cite the source
alongside them, which is why every table file carries the full citation and DOI.
