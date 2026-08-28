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
| [`raz-2012-OFM-performance.md`](raz-2012-OFM-performance.md) | Raz et al., *Demyelination affects temporal aspects of perception: an optic neuritis study*, Ann Neurol 2012;71(4):531–538, [doi:10.1002/ana.22692](https://doi.org/10.1002/ana.22692) — Figure 1 | deficit (b) — object-from-motion performance across dot speeds 0.05–2 °/s, at four time points, with a static control |
| [`raz-2012-VEP-and-dissociation.md`](raz-2012-VEP-and-dissociation.md) | *ibid.* — Figures 2 and 3 | deficits (a) and (b) — the 12-month VEP latency trajectory, and the split showing that **latency alone, with VEP amplitude intact, costs motion but not acuity or contrast** |
| [`regan-1991-MD-vs-CD-letters.md`](regan-1991-MD-vs-CD-letters.md) | Regan, Kothe & Sharpe, *Recognition of motion-defined shapes in patients with multiple sclerosis and optic neuritis*, Brain 1991;114(3):1129–1155, [doi:10.1093/brain/114.3.1129](https://doi.org/10.1093/brain/114.3.1129) — Figure 4 | deficit (b) — motion-defined vs contrast-defined letter reading on **stimuli identical but for how the form is defined** |
| *(no table yet)* | Brusa, Jones & Plant, *Long-term remyelination after optic neuritis: a 2-year visual evoked potential and psychophysical serial study*, Brain 2001;124(3):468–479, [doi:10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468) | deficit (a) — the **recovery trajectory**; see below |

## Where the three tables stand

Read together, the three files converge on one claim and one obstacle.

**The claim.** Every target is a *dissociation*, not a level. Raz Figure 3 splits
optic-neuritis eyes whose VEP amplitude has recovered by conduction latency and
finds acuity and contrast unchanged (98 vs 99, 98 vs 94) while object-from-motion
falls 68 → 42. Regan Figure 4 compares motion-defined and contrast-defined letters
that are identical in size, dottiness and task, and finds 14 eyes failing the
motion version with normal contrast sensitivity against only 2 the other way.
Raz Figure 1 shows the motion deficit graded by speed and worst at the slowest,
with a static control at 83–91% of normal throughout. So the thing the model has to
produce is **a timing-like insult with a motion-specific consequence**, not a
general loss of gain or sensitivity — which is exactly the driving question above.

**The obstacle, unchanged.** All three sit below the model's speed range. Regan's
figure lies entirely below it; Raz's analysed band (0.05–0.25 °/s) does too, and
only his unanalysed 1 and 2 °/s conditions reach the bottom of V1's tuning. Nothing
here can be compared to model output condition by condition today. What can be
compared is the *shape* — whether a motion read-out degrades while a static one is
spared, over whatever range the model does represent.

**One thing to settle first.** Both papers move dots inside and outside the object
in opposite directions, so *relative* speed is twice the quoted dot speed. Regan's
caption does not say which of the two his ordinate uses; the evidence in that file
favours relative. Any claim that turns on the factor of 2 has to say which reading
it assumes.

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
