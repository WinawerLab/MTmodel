# Noise, demyelination, and what the current lesion model cannot express

**Design note, 2026-08-19.** The argument for adding internal noise, the
pathophysiology it is meant to express, and the predictions that follow.
**§6 is measured** (`explore/compensationIndex.m`); everything else is design.
The measured state of the rest of the model is in
[`MODEL_AND_LESIONS.md`](MODEL_AND_LESIONS.md); the work-plan entry is
`TODO.md` §6.

The framing in §4 and §5.5 is JW's (2026-08-19). The pathophysiology in §2 came
in as an AI-search summary — see the provenance warning there before relying on
any of it.

---

## 0. Summary

**The argument.** In a deterministic model an amplitude lesion is close to a
change of units, so the existing results (report §4.2: a 50% gain cut barely
moves direction tuning) understate it. Worse, three of the mechanisms by which
demyelination actually degrades a visual signal — **trial-to-trial spike jitter,
stochastic conduction block, and high-frequency conduction failure** — cannot be
written down at all in the current lesion parameterization (§3). Adding noise is
not a refinement; it is the only way to express half the pathophysiology.

**The mechanism (JW).** Reduced input drive makes cortical neurons raise their
gain, amplifying local cortical noise. This needs **no new architecture** — both
cortical stages compute `R = s·N/(strength·D + σ²)` with the pool `D` driven by
the *lesioned* input, so the gain rise is automatic. Consequence: absolute output
noise rises and the mean response is restored toward normal, so the deficit is
**invisible to tuning-curve measures and visible only in discriminability**
(§4.2). Near-normal tuning curves, degraded psychophysics.

**What was measured** (`explore/compensationIndex.m`, §6):

- Normalization absorbs most of a uniform amplitude lesion at every speed
  (C = 0.64–0.92): **a 50% gain cut costs 12–25% of the MT response, not 75%.**
  The k² reference is verified — slope 2.000 with normalization off.
- **MT's motion signal across the clinical band (1–5 deg/s) is 4–5× smaller than
  at 10–16 deg/s**, while V1 is flat. JW's signal-starvation premise holds.
- **Compensation is strongest where drive is weakest** (C = 0.89 at 1 deg/s vs
  0.64 at 10 deg/s) — the opposite of what was predicted. This *strengthens* the
  starvation account: the lesion-driven gain increase, which is what amplifies
  cortical noise, is largest exactly where there is least signal.
- Drive is **U-shaped** in speed, so the model predicts impairment at high speeds
  too, with best performance near 16 deg/s.

**The open claim.** The low-speed deficit needs no low-speed-selective damage; it
falls out of the operating point. Strong test: plot deficit against unlesioned MT
drive rather than speed — if low-speed, high-speed and low-coherence conditions
collapse onto one curve, the operating-point account wins outright (§6.4).

**Provenance caution.** The pathophysiology in §2 arrived as an AI-search summary.
One of its citations was verified and is genuinely useful (Naud & Longtin 2019);
one was **mis-attributed** (PMID 12108932); the rest are unsourced. §2 is a
hypothesis list to ground, not established fact.

---

## 1. Why this matters more than a refinement

Every lesion result on record comes from a **deterministic** model, and in a
deterministic model an amplitude reduction is close to a change of units. That is
why `MODEL_AND_LESIONS.md` §4.2 finds a 50% gain cut leaving direction tuning,
DSI and tuning width essentially intact, and why the current picture makes
heterogeneous *delay* look like the only lesion with real bite.

The stronger reason is §3 below: **three of the mechanisms by which demyelination
actually degrades a visual signal cannot be written down at all in the current
lesion parameterization.** They are irreducibly stochastic or frequency-dependent.
Adding noise is not a refinement of the existing lesion axes — it is the only way
to express half the pathophysiology.

---

## 2. The pathophysiology — and a provenance warning

**Provenance.** The summary this section is based on was produced by an AI web
search, and it does not meet this repo's citation standard (`optic neuritis
targets/NOTES.md`: "A figure with no citation is not usable as a target"). Its
sources included a YouTube video and a clinic FAQ for core biophysics claims.
Two citations were checked directly:

- **Verified and genuinely relevant.** Naud & Longtin (2019), "Linking
  demyelination to compound action potential dispersion with a spike-diffuse-spike
  approach," *J Math Neurosci* 9:3, [doi:10.1186/s13408-019-0071-6](https://doi.org/10.1186/s13408-019-0071-6).
  A stochastic spike-diffuse-spike model: stochastic integrate-and-fire nodal
  excitability plus linear internodal filtering, showing how **weak and sporadic**
  axonal damage produces both delay and **dispersion** of the compound action
  potential. This is the right level of description for what we want to import.
  **Note it has two published corrections**, one concerning the direction of the
  changes in transverse resistance and capacitance under demyelination
  ([10.1186/s13408-019-0076-1](https://doi.org/10.1186/s13408-019-0076-1),
  [10.1186/s13408-020-00083-y](https://doi.org/10.1186/s13408-020-00083-y)) —
  read the corrected version. Free preprint: [biorxiv 10.1101/501379](https://www.biorxiv.org/content/10.1101/501379).
- **Mis-attributed.** PMID 12108932 is Physiological Research (2002), "Model of
  spike propagation reliability along the myelinated axon corrupted by axonal
  intrinsic noise sources." It concerns intrinsic axonal noise and interspike
  interval preservation in *myelinated* axons. It was cited in the summary for
  g-ratio changes after remyelination *and* for remyelination suppressing jitter,
  and it supports neither. **Do not cite it for those claims.**

The rest of the summary is standard textbook neurophysiology and is very probably
correct, but it is unsourced here. Treat §2.1 as a **hypothesis list to be
grounded**, not as established fact, and pull real references before any of it
appears in a manuscript.

### 2.1 Mechanisms, as claimed

**Demyelinated state.** Loss of the sheath forces the transition from saltatory
to continuous conduction, which slows propagation (→ prolonged VEP latency).
Because inflammatory damage is heterogeneous along and across the nerve, fibres
end up conducting at disparate velocities — **temporal dispersion**, scrambling
the synchronised arrival times the cortex needs. Demyelinated segments also fail
at high firing rates (**high-frequency failure**) and can show outright
**conduction block**. At the membrane level, the exposed axon sits closer to
threshold and the impedance mismatch at lesion boundaries makes propagation
probabilistic: **trial-to-trial spike jitter**, and blocks that occur on some
trials and not others.

**Remyelinated state.** New sheaths are structurally distinct — shorter
internodes, thinner myelin (higher g-ratio) — so conduction velocity recovers
substantially but not fully, leaving a **residual latency**. Restoring the
insulating envelope re-establishes the conduction safety factor, which suppresses
jitter and stochastic block. The claimed net effect is that **timing variability
recovers before, and more completely than, mean latency does.**

That last asymmetry is the interesting one, and §5.4 turns it into a test.

---

## 3. Mapping onto the model, and the three gaps

| pathophysiology | model expression | status |
|---|---|---|
| conduction slowing | uniform delay on RGC kernels | **exists** — `impairmentDelayMap`, measured (report §4.3: does nothing to steady-state tuning) |
| temporal dispersion, static across fibres | spatially heterogeneous delay map | **exists** — `delay_random`, the largest measured effect (report §4.5) |
| conduction block, permanent | amplitude → 0 on a subset of locations | **exists**, approximately — but as graded gain, not all-or-none per fibre |
| axonal amplitude / SNR loss | uniform or heterogeneous gain reduction | **exists** — measured (report §4.2, §4.4) |
| residual latency after remyelination | small uniform delay | **exists** |
| **trial-to-trial spike jitter** | per-trial random delay | **MISSING** — needs noise |
| **stochastic conduction block** | per-trial Bernoulli dropout | **MISSING** — needs noise |
| **high-frequency failure** | frequency-dependent attenuation | **MISSING** — not a gain and not a delay; a change of *kernel shape* |

The deterministic lesion axes capture the **mean** effects. The three missing rows
are the ones that carry the *variability*, and variability is what a
discriminability measure responds to.

### 3.1 High-frequency failure is a kernel-shape lesion, and it has a cell-type reading

This one is worth separating out because it needs no noise at all — it needs a
different *kind* of lesion. A lesion that preferentially fails at high temporal
frequency is a low-pass filter applied to the RGC channels, not a scalar gain and
not an integer shift. It is expressible in the class parameterization (edit
`pars.rgc.classes(i).temporalKernel`), and it has not been tried.

**Functionally it is a parasol-selective lesion.** The high-TF content in this
model lives in the fast parasol kernels (τ = 0.6/1.2, peak ~27 ms) and in the
lag-channel structure that synthesizes SH's high temporal orders
(`MODEL_AND_LESIONS.md` §2.4). Attenuating high temporal frequencies therefore
removes preferentially magnocellular drive — and with the two-stream MT
(report §2.5), magno drive is nearly all of MT's input. Prediction: **a
high-frequency-failure lesion should hit MT far harder than a class-agnostic
amplitude lesion of the same average magnitude.**

Two cautions. First, this is a statement about which *model channels* carry high
temporal frequencies, not a claim that large-diameter magno axons are
preferentially demyelinated — that is a real and separate empirical question and
I have not checked it. Second, it pushes the deficit toward **high** speeds,
which is the wrong end of the clinical axis (§5.5).

---

## 4. Where noise enters, and the gain-compensation mechanism

### 4.1 Three sites

**Site 1 — the optic nerve itself.** Demyelinated fibres intrinsically noisier, or
carrying a worse SNR. This noise is *upstream of the lesion's own amplitude loss*,
so it is attenuated along with the signal: a pure gain reduction leaves this SNR
unchanged. It needs an explicit noise increase to do any work, which is exactly
what §2.1 claims happens.

**Site 2 — local cortical noise, upstream of the normalization gain.** Independent
noise generated in cortex, downstream of the lesion. Signal arriving is attenuated
by *k*; this noise is not. SNR degrades by *k* directly. **This is the site that
makes amplitude lesions bite.**

**Site 3 — late / decision noise.** Reduced response against a fixed noise floor.
Note that gain compensation *helps* here: to the extent normalization restores the
mean, late noise is relatively less harmful than it otherwise would be.

### 4.2 The mechanism to take most seriously (JW)

> When the input drive to cortical neurons is reduced, those neurons likely
> increase their gain and thus inadvertently amplify local (cortical) noise.

In this model that requires **no new architecture.** Both cortical stages already
compute

```
R = s · N / (strength · D + sigma^2)          sigma = v1C50 = mtC50 = 0.1
```

(`shModelV1Normalization_Tuned.m`, `shModelMtNormalization_Tuned.m`), where `N` is
the rectified linear response and `D` is its spatially and temporally pooled
version. **`D` is computed from the lesioned input**, so scaling the drive by *k*
lowers `D` and the effective gain `1/(strength·D + sigma^2)` **rises
automatically**. The only thing missing is a noise term in `N`.

A uniform RGC amplitude lesion is, to first order, a **contrast reduction**, and
the expression above is the model's contrast-response nonlinearity. Above the
semi-saturation point numerator and denominator largely cancel and the mean
response is preserved; below it they do not. The model sits in a mixed regime for
these stimuli — direction peak and DSI are essentially fully compensated, while
speed-tuning peaks still fall 35–49%.

**Three consequences, and only one is a change in SNR.** Worth separating, because
the loose version of the argument gets this wrong:

- **Absolute output noise rises.** Site-2 noise entering `N` is multiplied by a
  gain that grows as the lesion deepens. Response variability genuinely increases.
- **The mean response is restored toward normal.** The deficit becomes *invisible
  to mean-response measures* — direction tuning, DSI, tuning width — which is
  precisely the set report §4.2 finds unchanged.
- **SNR falls by *k***, from signal loss against undiminished local noise. The
  shared gain cancels in the ratio, so the gain increase is not itself the source
  of the SNR loss. What it does is **hide the loss from the mean and re-express it
  as variability.**

Net picture, and it fits the clinic: **near-normal tuning curves, substantially
degraded discriminability.** A tuning-curve experiment would call this eye normal;
a psychophysical one would not.

This also reframes the model's most-quoted null result. The correct reading of "a
50% gain cut barely moves direction tuning" is not *amplitude lesions don't
matter*; it is **normalization hid it, and the hiding is the damage.**

### 4.3 The dynamic variant, which this model cannot express

If cortical gain control amplifies its *own* circuit noise, or loses stability at
low drive, the effect exceeds the static account above. That needs normalization
**dynamics** (ORGaNICs and relatives) — the same gap `TODO.md` §2 flags for VEP
latency, where the static normalization is why cortical latency effects are out of
reach. The static analysis here is a **lower bound** on the mechanism, not the
whole of it. If §5 finds the static version already sufficient, dynamics is a
refinement; if the static version underpredicts, dynamics is the next thing to
build.

### 4.4 Static dispersion and trial jitter are different things, and `delay_random` is only the first

This distinction is currently collapsed and should not be. §2.1 describes two
separate temporal pathologies:

- **Static dispersion across fibres** — fibre A is always slower than fibre B.
  This is a *frozen* delay pattern, identical on every trial. It is what
  `delay_random` models, and it is the largest effect on record (report §4.5).
- **Trial-to-trial jitter within a fibre** — the same fibre's arrival time varies
  across repeats of the same stimulus. This is **noise**, and nothing in the model
  expresses it.

They predict differently. A frozen delay map is a *systematic* distortion: the
response is wrong but repeatable, and in principle a downstream stage could
compensate it. Trial-varying jitter is irreducible — it destroys exactly the
temporal precision that motion energy computation depends on, and no downstream
stage can undo it. Since report §4.5 already shows the model is far more sensitive to
delay *decorrelation* than to delay magnitude, **jitter should be the single most
damaging manipulation available**, and it has never been run.

Naud & Longtin's stochastic spike-diffuse-spike model is the natural source for
the form of both, since it derives dispersion and delay together from sporadic
damage rather than imposing them separately.

---

## 5. Predictions

### 5.1 Uniform and heterogeneous amplitude lesions should stop matching

Falls straight out of §4.2 above. The normalization pool is **spatially blurred**, so it
mixes damaged and intact locations:

- Under a *uniform* lesion, `D` falls everywhere by the same factor, so every
  location gets the same gain rescue.
- Under a *heterogeneous* one, a badly damaged location sits in a pool partly
  supported by intact neighbours. Its `D` stays higher than a uniform lesion of
  the same local severity would give, so it gets **less** gain compensation and is
  suppressed more. Symmetrically, intact locations sit in a pool lowered by
  damaged neighbours, get **more** gain, and amplify their local noise more.

The report §4.4 currently finds uniform and heterogeneous amplitude lesions
interchangeable (~9–18% coherence drop either way). **With site-2 noise present
they should diverge**, and the divergence should scale with the spatial
correlation length of the damage relative to the normalization pool width. Clean
test of whether the gain-compensation account does real work, using lesions that
already exist.

### 5.2 Trial jitter should outrank every deterministic lesion

Per report §4.4: the model is already more sensitive to delay decorrelation than to delay
magnitude, and jitter is decorrelation that cannot be compensated. Expect
motion-letter d′ to fall further under jitter than under a frozen `delay_random`
map of the same variance.

### 5.3 High-frequency failure should be MT-selective

Per §3.1. A low-pass lesion of the RGC kernels removes preferentially parasol
drive, which is nearly all of MT's input under the two-stream architecture, so it
should cost MT far more than a class-agnostic amplitude lesion of matched mean.
Needs no noise — runnable now.

### 5.4 The recovery trajectory dissociates latency from discriminability

§2.1 claims remyelination suppresses jitter and stochastic block while leaving a
residual uniform latency. In model terms, recovery is **noise terms shrinking
while a small uniform delay persists**. Since §4.3 of the report shows a uniform
delay is invisible to steady-state tuning, the model predicts **motion-form
discrimination recovering while VEP latency stays prolonged.**

**The real data are harder than that clean story, and the target already exists.**
Brusa, Jones & Plant (2001), "Long-term remyelination after optic neuritis: a
2-year visual evoked potential and psychophysical serial study," *Brain*
124(3):468–479, [doi:10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468)
— 31 patients, serial VEP and psychophysics over 24 months. They find VEP latency
*does* shorten significantly (6–7 ms between months 3–6, ~4 ms more by 24 months),
i.e. partial rather than absent recovery; contrast sensitivity improved for nine
months and then **declined**; and they conclude long-term remyelination may mostly
protect axons from degeneration rather than restore function.

Two things follow. First, the prediction must be stated as a *rate* dissociation
(variability-driven measures recovering faster and more completely than latency),
not an absolute one. Second — and this matters for the repo's planned
affected-vs-fellow-eye design — **Brusa et al. report the fellow eye deteriorating
over the same window**, so the fellow eye is not a clean within-subject control.
This paper belongs in `optic neuritis targets/`.

### 5.5 The low-speed deficit is probably about the operating point, not about which cells were damaged (JW)

The tempting account is that the clinical low-speed deficit means low-speed
machinery was selectively damaged — and the model offers a candidate, since
midget-knockout effect is graded 10–30× from slow to fast preferred speed
(report §2.5). **JW's account is different, and better.**

> Patients fail at letter recognition in motion-defined stimuli at very slow
> speeds NOT because of exacerbated damage to neurons tuned to very low temporal
> frequencies, but rather because at very low speeds, MT is signal starved, and
> any hit to SNR will most impact any responses with low signal.

On this account the deficit needs **no speed-selective damage at all**. The
controlling variable is the *signal magnitude at the read-out*, and speed is
merely one of several ways to lower it. It has a sharp falsifiable consequence,
also JW's: **staircase coherence at high speed and thresholds should be elevated
too** — because low coherence starves the signal just as low speed does.

This is now partly measured — see §6. The starvation premise holds, and a second
mechanism supports it that neither of us anticipated.

---

## 6. First measurement: the compensation index *(run 2026-08-19)*

`explore/compensationIndex.m`. Uniform RGC amplitude lesion (gain *k* remaining,
`impairmentAmplitudeMap`) crossed with stimulus speed, on seeded drifting dots;
both the derivative preset and the lagged preset with the two-stream MT.
Deterministic — no noise. Figure: `explore/_figs/compensationIndex.png`.

Compensation index **C = 1 − slope/2**, slope = d log R / d log k. C = 0 is no
compensation, C = 1 is full. **The k² reference is verified, not assumed:** with
`v1NormalizationType = 'off'` the measured slope is **2.000**.

### 6.1 Normalization absorbs most of a uniform amplitude lesion, at every speed

C = 0.64–0.92 for the best-driven moving MT unit; 0.64–0.84 for V1. In response
terms, **a 50% RGC gain cut costs only 12–25% of the MT response**, where without
normalization it would cost 75%. Both presets agree, so this is a property of the
normalization, not of the front end.

**This quantitatively explains report §4.2's null result.** The reason a 50% gain
cut barely moves direction tuning is not that the model is insensitive to
amplitude — it is that divisive normalization is absorbing roughly three quarters
of it.

### 6.2 The starvation premise is confirmed, and it is a U

Unlesioned best moving-MT response (lagged + two-stream MT), by stimulus speed:

| stimulus speed | 1 | 2 | 5 | 10 | 16 | 48 | 96 deg/s |
|---|---|---|---|---|---|---|---|
| MT moving | 0.18 | 0.19 | 0.40 | 0.79 | **0.97** | 0.89 | 0.30 |
| V1 best | 0.46 | 0.47 | 0.34 | 0.47 | 0.48 | 0.40 | 0.24 |

**MT's motion signal across the clinical band (1–5 deg/s) is 4–5× smaller than at
10–16 deg/s**, while V1 is essentially flat across the same range. The starvation
is specific to MT, exactly as JW's account requires — MT is tuned to
{0, 1, 6} px/frame = {0, 16, 96} deg/s, so the clinical band sits below its
slowest moving unit. At 1 deg/s in the derivative preset the *static* MT unit
responds 1.60 against the best moving unit's 0.22: the population is dominated by
a non-motion signal.

It is a **U**, not a ramp — drive collapses again at 96 deg/s. See §6.4.

### 6.3 The correction: compensation is strongest where signal is weakest

I predicted the opposite — that low drive would put the model in the
σ²-dominated regime where normalization cannot rescue, so a lesion would cost the
full k². **That is wrong.** C is *highest* where drive is lowest:

| stimulus speed | 1 | 2 | 5 | 10 | 16 | 48 | 96 deg/s |
|---|---|---|---|---|---|---|---|
| C, MT moving | **0.89** | 0.88 | 0.74 | 0.64 | 0.66 | 0.65 | **0.81** |

C tracks inverse drive: ~0.65 in the well-driven middle, ~0.9 at the starved ends.

The likely mechanism, and it should be confirmed by instrumenting `D` directly
rather than inferred: at low stimulus speed the moving units are weakly driven
*and* heavily normalized by a pool dominated by static and low-speed energy. That
large pool is what makes their response small to begin with — and it also keeps
`strength·k²·D >> σ²` down to small *k*, i.e. keeps them in the compensated
regime.

**This does not weaken JW's account — it strengthens it, by a route neither of us
predicted.** High C means the *gain increase under lesion is large*, and the gain
increase is precisely what amplifies site-2 cortical noise (§4.2). So at 1–5 deg/s
two things hold at once:

- the motion signal is **4–5× smaller** than at 10–16 deg/s, and
- the lesion-driven gain increase is **largest** (C = 0.89 vs 0.64).

Both point the same way. The low-speed deficit needs no low-speed-selective
damage: it falls out of a small signal being carried by a stage whose gain rises
most, amplifying local noise most, exactly where there is least signal to protect.

### 6.4 A sharper version of JW's coherence prediction

If the controlling variable is drive rather than speed, then every way of
lowering drive should expose the same deficit. The measurement supports this and
makes it more specific than "high speed plus low coherence":

- Drive is **U-shaped in speed**, collapsing at both 1–2 and 96 deg/s and peaking
  at 16 deg/s. So the model predicts impairment at **both** ends, with best
  performance near 16 deg/s — not a monotone low-speed deficit.
- Lowering coherence lowers drive at any speed, so a coherence staircase at
  high speed should be elevated too — JW's prediction, and the model's.
- The strong form: **plot deficit against unlesioned MT response, not against
  speed.** If low-speed, high-speed and low-coherence conditions collapse onto one
  curve, the operating-point account wins outright. If deficit still depends on
  speed at matched drive, something speed-specific (cell type) is also at work.
  That is a clean discriminating experiment, and it is the one to run.

### 6.5 Caveats

- **C is a statement about the mean response only.** It measures the gain headroom
  that noise would act on; it does not by itself say anything about d′. This sets
  the noise experiment up, it does not settle it.
- **The starvation magnitude is model-specific.** MT tiles only three speeds here
  ({0, 1, 6} px/frame). A real MT with denser speed tuning would be less starved
  at 5 deg/s, so the 4–5× figure is not a quantitative clinical prediction.
- **Off-peak units near the numerical floor behave erratically** and should not be
  read. Units far from their preferred speed show C > 1 (response *rises* under
  lesion) because the lesion cuts their normalization pool more than their
  numerator. Real normalization behaviour — the same disinhibition that produced
  the +25% parasol-knockout artifact in report §2.5 — but at responses of order
  1e-3 it is noise-floor bookkeeping, not a finding.
- The pool `D` was inferred, not measured. Instrumenting it is a one-line change
  to a copy of `shModelV1Normalization_Tuned` and would settle §6.3's mechanism.

---

## 7. What to build, in order

1. ~~**Compensation index.**~~ **Done** — §6.
2. **Coherence × speed drive map, still deterministic.** Extend
   `compensationIndex.m` with a coherence axis and re-express everything against
   unlesioned drive rather than speed (§6.4). Directly tests JW's prediction and
   needs no noise code.
3. **High-frequency failure** as a kernel-shape lesion (§5.3). Also no noise.
4. **Noise, one site at a time.** Site 2 first (additive into `N` in
   `shModelV1Normalization_Tuned`, before the division), since it carries the
   mechanism. Site 1 into the class channels in `shClassV1Basis`; site 3 into the
   read-out. Run separately before combining — different signatures, and combining
   first makes the result uninterpretable.
5. **Temporal noise** — per-trial jitter and Bernoulli dropout (§4.4), the ones
   with no deterministic counterpart at all.

### Decisions that must be made first

- **Response-scaled vs. fixed-variance noise.** Poisson-like noise scaling with
  response partly cancels a gain reduction; fixed-variance noise does not. This
  changes the *sign* of several predictions above and is not a detail.
- **Noise correlation structure.** Independent per location is the easy default
  and is wrong: cortical noise is spatially correlated, and correlated noise along
  the read-out direction is what actually limits discriminability. At minimum,
  check whether the conclusions survive spatially correlated noise.
- **Dropout is not Gaussian.** Stochastic conduction block is multiplicative,
  all-or-none, and temporally correlated (a block persists for a burst). Do not
  approximate it as additive noise.
- **The observables.** Motion-letter d′ (report §2.6) is the natural one and
  connects to deficit (b) directly. Report it **alongside a trial-to-trial
  variability measure** of the MT response, since §4.2 predicts the mean and the
  variability move in opposite directions — reporting only the mean would
  reproduce the current blind spot with extra steps.
- **The deficit-(a) observable still does not exist.** A noisy analogue of VEP
  latency needs defining at all (`TODO.md` §2).

---

## 8. References

**Verified, and in scope:**

- Naud & Longtin (2019), *J Math Neurosci* 9:3, [10.1186/s13408-019-0071-6](https://doi.org/10.1186/s13408-019-0071-6)
  — stochastic spike-diffuse-spike; sporadic axonal damage → CAP delay *and*
  dispersion. **Read the corrected version.** Preprint at
  [biorxiv 10.1101/501379](https://www.biorxiv.org/content/10.1101/501379).
  Not yet in `literature/`.
- Brusa, Jones & Plant (2001), *Brain* 124(3):468–479, [10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468)
  — 2-year serial VEP + psychophysics after optic neuritis. A **target**, not a
  mechanism paper; belongs in `optic neuritis targets/`.

**Do not cite for the claims it was attached to:**

- PMID 12108932, *Physiol Res* (2002) — intrinsic axonal noise and interspike
  interval preservation in myelinated axons. Does not establish g-ratio changes
  after remyelination, nor that remyelination suppresses jitter.

**Still to ground** — everything in §2.1 not covered above: continuous vs.
saltatory conduction velocities in demyelinated CNS axons, high-frequency
conduction failure, internode length and g-ratio after CNS remyelination, and the
claim that timing variability recovers ahead of mean latency. That last one is
load-bearing for §5.4 and should be sourced before it is used.
