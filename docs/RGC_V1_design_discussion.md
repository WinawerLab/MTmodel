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
