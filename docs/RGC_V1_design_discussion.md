# RGC → V1: Design Discussion (narrative)

Date: 2026-07-10. Participants: J. Winawer + Claude (Opus 4.8).

This is a **narrative record of the design conversation** — the questions asked,
the reasoning, the wrong turns and corrections, and the literature that shaped
the decisions. It complements `RGC_V1_unification_plan.md` (which is the terse
decisions-and-next-steps handoff). Read this if you want to understand *why* we
landed where we did.

---

## 1. Opening question: is 'derivative' vs 'fourPop' a false dichotomy?

**JW:** For the model to work with RGCs there will always be *multiple RGC
classes*, and the RGC→V1 weighting depends on RGC properties. So 'derivative' is
just a special case where the temporal functions happen to be the
Simoncelli–Heeger (SH) derivative kernels and the spatial RFs happen to be single
pixels. Having one flag that sets all this is useful, but duplicating functions
(`shV1RfDerivative` vs `shV1Rf4pop`, …) is bad. Cleaner: the difference between
the modes should live in **parameter values** (number of populations, kernels),
not in the parameterization, so the *same code* visualizes/forward-models either.
Also (separately): the SH code is early-2000s, compute-thrifty — is a broader
refactor/reimplementation worth it, or would it just create headaches?

**Claude:** Agreed, and the codebase is already ~80% there — **the `fourPop`
path IS the general machinery**: define N RGC classes → filter stimulus by each →
project each onto the 10 spatial-derivative read-outs → linear weights → V1.
`derivative` is the special case where the classes are (delta spatial, SH
temporal-derivative kernels) and the weights are available *analytically*
(`shSwts`) rather than fitted. The two differ in only two ways, one shallow (the
class definitions = parameters) and one deeper (analytic steering vs. numerical
fit) — and even the latter unifies if you frame `W` as "the least-squares
projection of the legacy V1 basis onto the RGC feature space," which is *exact*
(residual 0) for the derivative classes and approximate for fourPop.

Proposed unified shape: `pars.rgc.classes` (data), preset functions that populate
it, and one forward / one fit / one RF-viewer trio — no `*Derivative`/`*FourPop`
twins.

On the refactor: **refactor the RGC→V1 front-end only; do not reimplement the
model.** MT, normalization, complex cells, multi-scale all consume V1-linear
output and need no rewrite. Keep the legacy (RGC-off) path as a machine-precision
oracle.

**Proposed a cheap validating experiment:** push the derivative classes through
the *existing fourPop fit pipeline* and check the fit correlation jumps to ~1.0.

## 2. The validating experiment

**JW:** Yes, run it.

**Result** (`explore/unifyDerivativeVsFourPop.m`): same 40-feature projection +
ridge fit, swapping only the RGC classes, evaluated on held-out stimuli:

- derivative classes → corr **0.99991** (1.0 modulo the ridge λ), NRMSE 0.0015
- fourPop classes → corr **0.693**, NRMSE 0.079
- cross-check: the derivative 40-feature projection *contains the exact 10-column
  structured basis* as a sub-selection (err = 0).

**Conclusion:** the two "modes" are one implementation with different class
parameters. The unification is empirically justified.

## 3. A tangle over "basis functions" — and its resolution

**JW:** In derivative mode there are 4 RGC populations (orders 0–3) with 4, 3, 2,
1 basis functions. How are basis functions handled for fourPop — did we even
specify them?

**Claude:** fourPop applies the *same 10* spatial-derivative read-outs to *every*
channel (4×10 = 40 features), no triangular constraint; the 4/3/2/1 is
derivative-only. Proposed a per-class "allowed spatial read-out orders" field.

**JW:** Confused — if total order is always 3, there are only 4 combinations, not
10.

**Claude:** The constraint is **total** order `t+x+y = 3`, not spatial `x+y = 3`.
The 10 basis functions are the `(t,x,y)` triples summing to 3; spatial order
ranges 0–3; grouped by temporal order they are 4/3/2/1. Grid picture: fourPop
fills the whole 4×10 (class × spatial-read-out) grid; derivative uses only the
diagonal where `t + (x+y) = 3`.

**JW:** This is getting out of hand — 4 spatial × 4 temporal = 16 RGC classes
makes no sense.

**Claude (correction):** Right — I had conflated two levels. **There are 4 RGC
classes, period.** The spatial-derivative "orders" are **V1 read-out filters**
applied to each RGC image, not RGC classes. Two levels:
- RGC layer: 4 populations (each = one spatial RF + one temporal kernel);
- V1 read-out: spatial-derivative filters V1 applies to each RGC image.

The 4/3/2/1, 10, and 40 are all *read-out* counts, never class counts. The two
knobs per preset: (a) the class kernels, (b) how many spatial read-out orders V1
uses per class.

*(This exchange is preserved because the two-levels distinction is exactly the
thing that's easy to re-confuse; keep it straight.)*

## 4. The deeper question: how *should* V1 be built from RGCs?

**JW:** Two separate confusions — how the code works now, vs. how it *should*
work. Biologically there are 4 major RGC classes (On/Off × midget/parasol) with
distinct spatial (midget small, parasol large; Off smaller than On) and temporal
RFs. A clean idea: V1 RF = a **time-invariant spatial weighting** of RGC outputs,
temporal profile inherited from the retina — no temporal filters between RGC and
V1. But two problems: **biological** (V1 temporal tuning isn't purely inherited —
V1 has its own temporal dynamics, recurrence, feedback), and **computational**
(the 4 RGC temporal kernels aren't *that* different, so weighted sums may not
produce the expected spatiotemporal-frequency range in V1/MT). Yet applying 10
spatiotemporal-derivative combinations to each of 4 classes seems too large a
basis. Because the classes have different temporal kernels, **fewer read-outs per
class should be needed.** (Pointed to Adelson & Bergen 1985.)

**Claude (after reading Adelson–Bergen):**
- **The clean idea works**, with one amendment: the spatial weighting must be
  **class-specific**. Direction selectivity is a *cross-term* — an oriented
  space-time RF = (spatial phase A × temporal kernel 1) ± (spatial phase B ×
  temporal kernel 2). A&B: "a single separable filter can never be directionally
  selective; the minimum is a sum of two separable filters." So no temporal
  filter is needed between RGC and V1; the RGC classes supply temporal diversity,
  V1 supplies different spatial weights per class, DS emerges. The
  time-invariant-weight property is preserved.
- **Basis size:** minimal is 2 temporal × 2 spatial phases, *not* 10 per class.
  The fourPop 4×10 grid is over-complete. SH's 10 is the minimal *complete*
  order-3 steerable basis, and it uses the triangular 4/3/2/1 (complementary
  pairing), not 10/class — which is A&B's cross-product idea at higher order.
- **Biological hook:** SH's triangular pairing (low temporal order ↔ high spatial
  order; high temporal ↔ low spatial) qualitatively matches midget (sustained,
  fine) vs. parasol (transient, coarse).
- V1-intrinsic temporal processing is *sidestepped* by A&B/SH (temporal tuning
  attributed to weighted combination of temporally-diverse afferents); adding it
  later is an extra stage, not required for the basis.

## 5. The real concern was MT, not V1 DS

**JW:** Agreed you can get V1 DS from a small basis. But the worry was really
about **MT**, which isn't in A&B. SH define a V1 population spanning a *range* of
SF/TF (narrowband individually), combined in a specific way to make **speed
tuning** in MT. Without that range of V1 cells you can't get reasonable MT speed
tuning. Keep the analytic SH solution. Then compare the 4 On/Off midget/parasol
temporal kernels' TF range to SH's 4 derivative-of-Gaussians (added Kling 2020,
Fig. 4 human traces). Doubt SH's 4 map neatly onto the 4 biological classes.

**Claude (temporal comparison, `explore/compareTemporalKernels.m`):**
- Code has only **2 distinct** biological kernels (fast/slow difference-of-gamma),
  reused across ON/OFF.
- SH kernels are successive temporal derivatives: zero-crossings 0/1/2/3, peak TF
  marching 0 → 0.129 → 0.178 → 0.215 cyc/frame — they **tile** temporal
  frequency.
- Biological kernels peak at only 0.105 (fast) and 0.021 (slow) cyc/frame — they
  cover **only the lower half** of SH's range (≈ order 0–1).
- Kling Fig. 4A: all four human classes are monophasic-to-biphasic; ON/OFF are
  near mirror-images. So the four anatomical classes ≈ **2 temporal shapes × 2
  polarities**, and there's **no single-RGC counterpart** to SH's tri-/quad-
  phasic (order 2–3) high-TF channels.
- **Implication:** a purely biological front-end truncates the V1 TF range → the
  MT speed range. The high-TF channels must be *synthesized*. This is a concern
  distinct from DS.

## 6. Was there ever a 4-temporal-kernel implementation?

**JW:** I recall maybe an earlier 4-temporal-kernel implementation — or perhaps
it was only discussed.

**Claude (checked git history):** Never implemented. From the first RGC commit,
temporal kernels have keyed only on speed (fast/slow); no per-polarity temporal
params ever existed in any branch. "Four populations" always meant 2 kernels × 2
polarities. Lagged channels were added later as phase-shifted copies. The
4-kernel idea is on the roadmap (AGENTS.md Stage 2), not built.

## 7. Amending route (b): ON/OFF delay as the temporal phase (Chariker/Shapley)

**JW:** On/Off midgets have similar (not identical) temporal kernels; likewise
On/Off parasols. Shapley's group: DS in V1 comes from pooling ON and OFF cells
where ON lags OFF by ~10 ms. Their work covers the parasol/magno input layer, but
the same slight lag may apply to midgets. So do route (b) **without downstream
lags** — instead create the temporal phase from **ON-vs-OFF kernel differences**.
(Added Chariker 2021 theory, 2022 parameters.) If too cumbersome, hew closer to
Adelson–Bergen for cleanliness.

**Claude (after reading Chariker):**
- Mechanism: ON/OFF fed to **spatially offset** subregions + ON pathway **delayed
  ~9–11 ms** (they use 10 ms) → spatiotemporal inseparability → DS, **broadband
  in SF and TF**. Kernel: `t⁶`-power difference-of-gamma, τ₀=3.66 ms, τ₁=7.16 ms,
  crossover 36 ms, peak ≈ 10 Hz (magno/parasol).
- This is **Adelson–Bergen made biological**: the two temporal phases = OFF
  (early) & ON (late); the spatial phase = the ON/OFF subregion offset. Maps
  directly onto "class-specific spatial weighting of temporally-distinct
  channels."
- **Feasibility:** the ON delay is cheap (the model already has on/off × fast/slow
  channels). The **ON-vs-OFF spatial offset is the real design piece** — it lives
  in the V1 read-out and is *where DS is actually assembled*; a delay alone
  produces no DS.
- **MT caveat again:** Chariker is a theory of DS *origin*, not of tiling TF for
  speed. It gives DS within/across a band but not the range of preferred TFs MT
  needs; that still requires multiple time-scales, and the high-TF end remains
  synthesized.
- Fallback: a clean Adelson–Bergen skeleton (even/odd spatial × 2 temporal
  phases) if explicit ON/OFF-offset wiring gets cumbersome.

## 8. Decisions reached

**JW:** Adopt the ON/OFF delay as the temporal-phase source, applied for **two
class types — midgets and parasols** — for a bit more spatiotemporal-tuning
variety. Both next steps (prototype the ON/OFF-delay read-out; write the unified
schema) are good.

**Net decisions** (see the plan doc for the actionable version):
1. Keep the SH analytic derivative basis as the healthy-baseline path (exact;
   provides the SF/TF range MT needs).
2. Unify `derivative` and `fourPop` into one class-based implementation; modes
   become parameter presets.
3. Build DS from an ON/OFF temporal delay (~10 ms) for midget and parasol
   classes, not downstream lag copies.
4. The ON-vs-OFF spatial offset lives in the V1 read-out and is designed
   explicitly (that's where DS is assembled).
5. The MT/TF-range gap is separate from DS; high-TF channels remain synthesized.
6. Fall back to a clean Adelson–Bergen skeleton if the ON/OFF-offset wiring
   becomes cumbersome.

**Open TODO surfaced but not resolved:** confirm the model's intended **frame
rate**, needed to place Chariker's 10 ms / Kling's time-to-peak on the model's
frame axis.

---

# Session 2026-07-12: the reversion worry and the scope pivot

Date: 2026-07-12. Participants: J. Winawer + Claude (Opus 4.8). This session
started as a visualization pass (comparing derivative vs midget/parasol RFs) and
turned into a re-examination of *why* we are building a biological front-end at
all. It substantially revises the direction set in §8 above.

## 9. The orientation clue and a corrected diagnosis

**JW (observing the fitted midget/parasol V1 RFs):** neurons 8 and 22 are oblique
(~45°, ~135°) in the derivative preset but come out ~vertical in midget/parasol;
neurons 1 and 15 match better. What causes this?

**Claude (first, overconfident, answer):** the ON/OFF spatial offset is fixed
horizontal (`readoutOffset = [0 ±2]`, same for every neuron and never rotated), so
it can only manufacture one orientation of DS and biases oblique neurons toward
vertical.

**The control experiment (`explore/probeOffsetOrientation.m`) refuted the clean
version of that story.** Refitting with the offset along X, along Y, and removed
entirely, and measuring RF orientation (structure tensor) against the derivative
preset as ground truth:

| neuron | derivative (truth) | offset-X (current) | offset-Y | offset-none |
|---|---|---|---|---|
| 1  | 133° | 131° | 140° | 134° |
| 8  | 123° | 100° | 107° | 117° |
| 15 | 133° | 126° | 113° | 125° |
| 22 |  57° |  89° | 109° |  67° |
| **mean \|err\| vs truth** | — | **16°** | **24°** | **6°** |

Corrected reading: rotating the offset does **not** cleanly rotate orientation
(so "axis-locked to vertical" was wrong), but the fixed *translational* offset
**does distort** orientation, and **removing it recovers orientation best** (6° vs
16°/24°). The offset's job is DS, not orientation; it trades orientation fidelity
for a spatial phase, and — per the F&A quote JW raised — it does so with a
*translation* (linear-phase, frequency-dependent, orientation-distorting) instead
of a proper steerable *quadrature* (constant-phase). Lesson recorded so we don't
repeat the overclaim: **diagnose with the control before asserting the mechanism.**

## 10. JW's two doubts

**JW (1):** if we keep biologically-informed sizes (OFF smaller than ON), an
even/odd spatial quadrature is not *pure* — one lobe is blurrier than the other.
How much does that hurt?

**Claude:** it is the exact spatial analog of §2.7's pure-delay problem: a true
quadrature needs a shared amplitude spectrum (Hilbert only rotates phase);
different-sized DoGs mismatch the amplitude spectrum, so DS becomes
frequency-dependent / narrower. Clean fix: keep ON/OFF **size-matched within a
quadrature pair** (the current preset already does — `parasolOn/Off` share
`parasolRF`), and let the **midget-vs-parasol** size difference do the SF tiling.
Biological ON/OFF size asymmetry is then an optional, small knob, not a
foundation.

**JW (2), the important one:** "I have a sneaking suspicion that as we go down the
midget/parasol path we keep hitting problems like this and keep reverting closer
to SH, until we just have the same model twice. What are the desired properties of
a midget/parasol preset, and how do they differ from SH *without* breaking the
SF/TF tiling MT needs?"

## 11. The reversion ratchet, and its actual engine

The worry is correct, and the ratchet has a specific driver: **the
machine-precision healthy-equivalence constraint.** "Healthy must match legacy to
~1e-16" forces the basis toward the *pure* temporal-derivative channels, because
only those reconstruct SH exactly — and a pure derivative channel is exactly the
thing with no biology in it. So exactness and biological honesty are in direct
opposition:

- the derivative preset hits 1e-16 **by being SH** (biological names on orders
  0–3);
- the midget/parasol preset stays biologically honest (real difference-of-gamma
  kernels) but therefore caps at ~0.70.

JW's "same model twice" endpoint is precisely the fixed point the exactness
requirement pulls toward. Every local problem (impure quadrature, orientation
distortion, TF gap) is an instance of the same pull: fix it "properly" and you
step back toward the abstract SH channel.

## 12. The escape: value lives in the *perturbation axes*, not the healthy output

The reframe that dissolves the worry: **a biological front-end's value is not a
different healthy computation — it is a different *parameterization* of (nearly)
the same computation, along axes you can physically damage.** SH's order-0..3
channels have no biological identity, so you cannot express "delay the parasols by
10 ms." The biological layer supplies exactly that: identifiable populations
(midget/parasol × ON/OFF × timing) carrying lesionable parameters (kernel
time-to-peak, amplitude, RF size). Under this framing, **healthy midget/parasol
converging toward SH is success, not failure** — the payoff is entirely in what
happens when you perturb it.

Two commitments create the ratchet, and **neither is required by the actual goal
(model optic-neuritis deficits):**

1. **Exact healthy equivalence on the biological path.** Not needed. Keep the
   derivative preset as the machine-precision oracle (regression guard). Let the
   biological path be an *approximate* baseline. Optic neuritis is studied as a
   within-subject **delta** (affected vs fellow eye; pre vs post), so the signal
   is the lesion-induced *change*, not the absolute healthy match. A ~0.70
   baseline is fine if the delta is meaningful. Relaxing this removes the main
   engine of the ratchet.
2. **Reproducing DS via the biological ON/OFF offset/quadrature mechanism.** This
   is the sub-goal most prone to vacuous reversion, it is actively distorting
   orientation (§9), and it fights a battle SH wins for free via steering. Drop
   it; let DS come from the V1 read-out as in SH. JW's Point (1) — impure
   quadrature — then simply *evaporates*, because there is no spatial quadrature
   to keep pure.

**Why the result is then non-vacuous.** A real parasol kernel is a
difference-of-gammas — inherently a *mixture* of SH's derivative orders, not a
pure one. A conduction delay is a time-shift of that mixture, and a time-shift
mixes derivative orders (the shift operator is `exp(-τ d/dt) = Σ (-τ)ⁿ/n! dⁿ/dtⁿ`).
So "delay the parasols by 10 ms" traces a specific trajectory *across* SH's orders
that you would never natively write down in SH (whose only obvious lesion is
"scale order k"). The biology earns its keep in the *directions you can damage*,
not the healthy output — provided you do **not** force the biological channels to
become pure SH orders (which exact healthy-matching would).

## 13. The decisive, falsifiable test

Rather than argue, make the worry empirical: apply a biological lesion (a parasol
conduction delay) to the midget/parasol front-end, compute the V1/MT **delta**,
and test whether that delta is reproducible by *any* rescaling of SH's four
channels (the only lesion SH natively exposes, via `channelGain`). If the delta
has a large component orthogonal to the SH-rescaling space → the biological layer
is non-vacuous and the project is justified. If it is fully reproducible by
rescaling → JW's suspicion is confirmed and we should stop.

Script: `explore/lesionDeltaTest.m`. **Result (2026-07-12): non-vacuous.** The
test asks the sharp version — is a conduction *delay* reducible to an *amplitude*
rescale? — by projecting each lesion's V1 delta onto the front-end's own
amplitude-rescaling space (each biological channel's contribution).

- **Positive control:** a parasol *amplitude* lesion lands in that space with
  **R² = 1.000** (both stimulus classes) — an amplitude deficit *is* a rescale, so
  the method correctly reports "fully reproducible."
- **A parasol conduction delay is largely irreducible**, and — a real insight —
  *how* irreducible depends on stimulus bandwidth. A delay only phase-shifts a
  *narrowband* (grating) response, and a phase shift partially aliases into a
  rescale (a half-period delay = negation = ×−1); but for a *broadband/transient*
  (dot) stimulus a time-shift is genuinely not a rescale. At the smallest
  (most physiological) 1-frame delay, the fraction of the delay's V1 effect that
  **no** amplitude rescaling can reproduce is **~0.85 for dots vs ~0.71 for
  gratings**; the gap persists across delays. (Large delays alias back toward
  rescales, sharply so for gratings.)

**Conclusion (2026-07-12) — OVERSOLD; corrected in §16 (2026-07-13).** The
original claim was: "SH's native lesion vocabulary is amplitude-only
(`channelGain`), so it cannot express a conduction delay; the biological layer is
*not* 'SH twice' — its value is a timing lesion axis SH does not have." This
overreached. The 85% measures *delay ≠ amplitude* **within the biological model**
(projection onto the biological channels' own amplitude space); it does **not**
compare biology to SH. SH's basis regrouped into 4 temporal-order classes supports
the *same* delay lesion, and the test used the *no-lag* `shRgcClassesMidgetParasol`
preset — in the adopted *lagged* preset a delay is ≈ a reweighting of the lag
channels, so it is not even an independent axis from amplitude there. See §16.

## 14. Decisions reached this session (revise §8)

1. **Demote the biological DS mechanism (ON/OFF offset/quadrature) from a goal to
   an optional side-quest.** DS for the healthy baseline comes from the SH
   steerable read-out. This retires the orientation-distortion and
   quadrature-purity problems.
2. **Drop machine-precision healthy-equivalence as a requirement for the
   biological path.** Keep the derivative preset as the exact oracle; the
   biological path is an approximate baseline whose job is realistic lesion
   *deltas*, not absolute healthy match.
3. **The primary deliverable is lesion modeling (Goal A):** a biologically
   identifiable, lesionable channel set that (a) gives a good-enough healthy
   baseline and (b) still tiles SF/TF for MT. The §2.4 TF-coverage gap — real
   single RGC kernels only reach orders 0–1 — is the real remaining tension, to be
   met either by adding timing subtypes/lagged channels (synthesize high-TF) or by
   accepting a narrower TF range as a testable prediction (narrowed speed tuning
   in ON patients).
4. **Gate further midget/parasol investment on the §13 lesion-delta test.**
   *(2026-07-13: this gate is retracted — the §13 test does not establish
   non-vacuousness vs SH; see §16. The scope pivot (1–3) still stands, but on the
   narrower interpretive justification, not on §13's "timing axis SH lacks.")*

## 15. The TF-tiling tension is resolved: lags synthesize the high-TF orders

The §14.3 fork on the §2.4 TF-coverage gap — synthesize the high-TF (order 2–3)
channels from biological pieces, or accept a narrower range — is settled in favor
of **synthesis, and cheaply.** Script: `explore/temporalTilingFromLags.m`.

Idea: a difference of two *lagged* biphasic kernels approximates a temporal
derivative (`k(t) − k(t−D) ≈ D·dk/dt`), so a bank of mono/biphasic channels +
small lags should span the higher derivative orders — with **each channel staying
mono/biphasic** (Kling-plausible); the tri/quad-phasic structure lives in the
linear combination (the V1 read-out), not in any single cell. Reconstructing SH's
four temporal-derivative kernels from biological banks, R² by order [0 1 2 3]:

| bank | channels | R² order 0 | 1 | 2 | 3 |
|---|---|---|---|---|---|
| 2 kernels, **no lags** (current preset) | 2 | 0.80 | 0.16 | 0.29 | **0.005** |
| 2 timescales × lags 0–3 | 8 | 1.00 | 0.99 | **0.98** | **0.98** |
| 5 timescales × lags 0–4 | 25 | 1.00 | 1.00 | 1.00 | 0.99 |

Takeaways:

- **The gap is real without lags** (order-3 R² = 0.005 for the current 2-kernel
  preset — this *is* the §2.4 concern) but **closed by just 8 channels** (the two
  existing biphasic kernels × lags 0–3): all four SH orders reconstruct to
  R² ≥ 0.975. Not trivial spanning — 8 channels span only an 8-D subspace of the
  20-D space, and the SH basis genuinely lies within the *biological* lagged
  subspace.
- **Biologically grounded:** lags = lagged excitation/inhibition (Chariker's
  ON-lag; delayed retinal/LGN inhibition generally). No exotic cell needed.
- **Bonus — the healthy-equivalence ceiling was an artifact of the preset, not
  biology.** The ~0.70 midget/parasol ceiling came from using only 2 *unlagged*
  kernels; with lags the biological bank spans SH's temporal basis, so the healthy
  reconstruction can be driven far higher. (Consistent with §12: don't force exact
  match, but note it is *reachable* — biology is a genuinely different basis over
  the same space, not a barrier.)
- **The mechanism already exists in code:** `fourPop`'s `fastLag`/`slowLag` and
  `shRgcClassesFourPop`'s zero-padded lag classes are exactly this construction —
  so adding lagged classes to a midget/parasol preset is a small step.
- **Caveat (the standing frame-rate TODO):** the *specific* lags (0–3 frames) that
  reconstruct SH depend on SH's kernel timescale (9 taps); whether those map to
  plausible delays (a few ms vs tens of ms) needs the model's frame rate pinned
  down. The qualitative result — lags synthesize high-TF with few plausible
  channels — is robust to that.

**Decision:** meet the MT TF-tiling requirement by adding lagged biphasic classes
(option i), not by narrowing the range. This also gives the biological path a
route to high healthy fidelity if/when wanted, without abandoning biological
honesty.

**Confirmed in the real (nonlinear) model** — `pars/shRgcClassesMidgetParasolLagged.m`
(biological midget/parasol, DoG RFs, ON/OFF rectification; **no offset/quadrature**
per §14; lagged copies per §15) vs its no-lag version, held-out legacy-V1
correlation by temporal frequency (`explore/testLaggedBiologicalFidelity.m`):

| preset | mean corr | low TF (0.06) | high TF (0.20) |
|---|---|---|---|
| midgetParasol (offset+quadrature, original) | 0.68 | 0.59 | 0.84 |
| lagged preset, **no lags** [0] | 0.68 | 0.69 | **0.58** |
| lagged preset, **lags [0 1 2 3]** | **0.985** | 0.99 | 0.98 |

The kernel-reconstruction prediction holds end-to-end: adding lags lifts healthy
fidelity from ~0.68 to **~0.985, flat across TF**. The no-lag biological preset
*declines at high TF* (0.69 → 0.58) — the §2.4 gap, live in the full model — which
the lags remove. Two corollaries land as predicted: (a) the ~0.70 ceiling was a
preset artifact, not a biological wall; (b) dropping the DS offset/quadrature (§14)
did not cost fidelity — the offset-free lagged preset (0.985) far exceeds the
offset+quadrature one (0.68), so the pivot *helped*. `runAllTests` stays 14/14.

## 16. Correction (2026-07-13): the §13 lesion-delta result was oversold

JW pushed on the §13 conclusion and found a real hole. Two independent problems,
both of which retract the claim "the biological layer is non-vacuous *relative to
SH* — a timing lesion axis SH lacks." (The §13 number itself is fine; its
*interpretation* was wrong.)

**What the 85% actually measures.** The test freezes the fitted V1 wiring, applies
a parasol conduction delay (prepend D zero taps to the parasol temporal kernels),
and projects the resulting V1 change onto the span of the biological channels' own
amplitude-rescaling contributions. `1 − R² = 0.85` = the fraction of the delay's
V1-change energy orthogonal to any *gain rescaling of those channels*. So it is a
**delay-vs-amplitude** statement (two lesion *types*) computed **entirely within
the biological model** — it never involves SH.

**Problem 1 — SH supports the same delay lesion (JW's Q2).** Regroup SH's 10
basis functions by temporal order into 4 "classes," each sharing one temporal
kernel (the 0th–3rd derivative). Delaying one class's kernel is the *same*
operation as delaying a biological class, and — a time-shift not being a gain
change — is *equally* irreducible to amplitude rescaling. So the 85% does not
distinguish the two parameterizations; "SH's only native lesion is amplitude
(`channelGain`)" referred to the existing code hook, not a mathematical limit, and
was misleading. Mathematically, for delay and amplitude lesions the two lesion
spaces are essentially equivalent.

**Problem 2 — the result is specific to the NO-LAG preset.** The §13 test used
`shRgcClassesMidgetParasol` (offset+quadrature, no lags). A delay `k(t) → k(t−D)`
in a bank that *contains lagged copies* is ≈ "move weight to the more-lagged copy"
= a reweighting of channels already present. So in the **adopted lagged preset**
(§15), a conduction delay is largely an amplitude reweighting of the lag channels
— i.e. timing is not even an independent axis from amplitude there. The lags that
buy healthy fidelity also make delays ≈ rescalings. (Not yet measured; predicted
to substantially collapse the 85%. Worth a direct check: rerun `lesionDeltaTest`
with `shRgcClassesMidgetParasolLagged`.)

**The honest, narrower position.** The biological front-end does **not** offer a
mathematically richer lesion space than a regrouped SH. Its value is
**physical/interpretive**: it specifies *which* channels co-vary under a real
insult and *by how much*, with kernels constrained to measured physiology
(Kling) — a testable *lesion model*, not a bigger lesion space. You could delay
"SH temporal-order 2," but there is no cell it names, no principled delay value,
and no reason to group it so. This is close to JW's original "SH twice" suspicion:
the distinction is scientific, not mathematical.

**Where a genuine mathematical distinction might still live — untested.** The one
structural thing SH's linear derivative basis lacks is the **ON/OFF half-wave
rectification**. A lesion that acts *through* that nonlinearity — e.g. an ON-vs-OFF
*asymmetric* amplitude loss — could produce a V1 change no linear SH manipulation
(rescale or delay of any regrouping) can reproduce. That, not the delay, is the
right test for biological-vs-SH non-vacuousness. **TODO: run the ON/OFF-asymmetry
test; until then the pivot rests on the interpretive justification only.**
