# Noise, demyelination, and what the lesion model cannot yet express

**A design note.** Written 2026-08-19, rewritten 2026-08-25. Why the model needs
internal noise, what pathophysiology the noise is meant to capture, and what it
should predict once it exists.

Almost nothing here is built. The one part that has been measured — how much of an
amplitude lesion divisive normalization absorbs — lives in
[`MODEL_AND_LESIONS.md`](MODEL_AND_LESIONS.md) §4.8, and this document interprets
it rather than repeating the numbers. The work-plan entry is `TODO.md` §1.

The framing in §4 and §5.5 below is JW's. The pathophysiology in §2 arrived as an
AI-search summary — read the provenance warning there before relying on any of it.

---

## 1. Why this is not just a refinement

Every lesion result on record comes from a **deterministic** model. In a
deterministic model, reducing amplitude is close to changing the units. That is why
the report's §4.7.2 finds a 50% gain cut leaving direction tuning, direction
selectivity and tuning width essentially intact, and why the current picture makes
patchy *delay* look like the only lesion with real bite.

The stronger reason is §3 below. **Three of the ways demyelination actually
degrades a visual signal cannot be written down at all in the current lesion
parameterization.** They are irreducibly random, or they depend on frequency.
Adding noise is not a refinement of the existing lesion axes. It is the only way to
express half the pathophysiology.

---

## 2. The pathophysiology, and a provenance warning

**Provenance.** The summary this section rests on was produced by an AI web search.
It does not meet this repo's citation standard (`optic neuritis targets/NOTES.md`:
"A figure with no citation is not usable as a target"). Its sources included a
YouTube video and a clinic FAQ for core biophysics claims. Two citations were
checked directly:

- **Verified, and genuinely relevant.** Naud & Longtin (2019), "Linking
  demyelination to compound action potential dispersion with a spike-diffuse-spike
  approach," *J Math Neurosci* 9:3,
  [doi:10.1186/s13408-019-0071-6](https://doi.org/10.1186/s13408-019-0071-6).
  A stochastic model: random nodal excitability plus linear filtering between
  nodes, showing how **weak and sporadic** damage to an axon produces both delay
  and **spreading** of the compound action potential. This is the right level of
  description to import. **It has two published corrections**, one about the
  direction of the changes in transverse resistance and capacitance
  ([10.1186/s13408-019-0076-1](https://doi.org/10.1186/s13408-019-0076-1),
  [10.1186/s13408-020-00083-y](https://doi.org/10.1186/s13408-020-00083-y)) — read
  the corrected version. Free preprint:
  [biorxiv 10.1101/501379](https://www.biorxiv.org/content/10.1101/501379).
- **Mis-attributed.** PMID 12108932 is *Physiological Research* (2002), "Model of
  spike propagation reliability along the myelinated axon corrupted by axonal
  intrinsic noise sources." It concerns intrinsic axonal noise and the preservation
  of interspike intervals in *myelinated* axons. It was cited for changes in
  g-ratio after remyelination *and* for remyelination suppressing jitter, and it
  supports neither. **Do not cite it for those claims.**

The rest of the summary is standard textbook neurophysiology and is very probably
correct, but nothing here sources it. Treat §2.1 as **a list of hypotheses to
ground**, not as established fact, and pull real references before any of it
appears in a manuscript.

### 2.1 The mechanisms, as claimed

**In the demyelinated state.** Losing the myelin sheath forces conduction to switch
from jumping between nodes to travelling continuously, which slows it down and so
lengthens VEP latency. Because inflammatory damage varies along and across the
nerve, different fibres end up conducting at different speeds. That is **temporal
dispersion**: it scrambles the synchronised arrival times the cortex depends on.
Demyelinated segments also fail at high firing rates (**high-frequency failure**)
and can stop conducting altogether (**conduction block**). At the membrane, the
exposed axon sits closer to threshold, and the impedance mismatch at the edges of a
lesion makes conduction probabilistic. That gives **trial-to-trial jitter** in spike
timing, and blocks that happen on some trials but not others.

**In the remyelinated state.** New sheaths are structurally different — shorter
internodes, thinner myelin, so a higher g-ratio. Conduction speed recovers
substantially but not fully, leaving a **residual latency**. Restoring the
insulating envelope restores the safety factor for conduction, which suppresses
jitter and stochastic block. The claimed net effect is that **variability in timing
recovers before, and more completely than, mean latency does.**

That last asymmetry is the interesting one, and §5.4 turns it into a test.

---

## 3. What the model can and cannot express

| pathophysiology | how the model would express it | status |
|---|---|---|
| conduction slowing | uniform delay on the RGC filters | **exists** — `impairmentDelayMap`; measured, and it does nothing to steady-state tuning (report §4.7.3) |
| temporal dispersion, fixed across fibres | delay map that varies across space | **exists** — `delay_random`, the largest measured effect (report §4.7.5) |
| permanent conduction block | amplitude → 0 at some locations | **exists**, approximately — but as a graded gain, not all-or-none per fibre |
| loss of amplitude or SNR in the axon | uniform or patchy gain reduction | **exists** — measured (report §4.7.2, §4.7.4) |
| residual latency after remyelination | small uniform delay | **exists** |
| **trial-to-trial spike jitter** | a random delay drawn per trial | **missing** — needs noise |
| **stochastic conduction block** | Bernoulli dropout per trial | **missing** — needs noise |
| **failure at high firing rates** | attenuation that depends on frequency | **missing** — not a gain and not a delay, but a change in the *shape* of the filter |

The deterministic lesion axes capture the **average** effects. The three missing
rows are the ones that carry the *variability*, and variability is what a
discriminability measure responds to.

### 3.1 High-frequency failure is a change in filter shape, and it reads as parasol damage

This one is worth separating out, because it needs no noise at all. It needs a
different *kind* of lesion. A lesion that preferentially fails at high temporal
frequency is a low-pass filter applied to the RGC channels. It is not a scalar
gain, and it is not a whole-frame shift. It can be written in the class
parameterization by editing `pars.rgc.classes(i).temporalKernel`, and it has never
been tried.

**Functionally it is a parasol-selective lesion.** The high-temporal-frequency
content in this model lives in the fast parasol filters (τ = 0.6/1.2, peak about
20 ms) and in the lag structure that builds SH's high temporal orders (report
§2.2). Attenuating high temporal frequencies therefore removes magnocellular drive
preferentially — and with the two-stream MT, magnocellular drive is nearly all of
MT's input. **Prediction: a high-frequency-failure lesion should hit MT far harder
than a class-agnostic amplitude lesion of the same average size.**

Two cautions. First, this is a statement about which *model channels* carry high
temporal frequencies. It is not a claim that large magnocellular axons are
preferentially demyelinated in real patients; that is a separate empirical question
and it has not been checked. Second, it pushes the deficit toward **high** speeds,
which is the wrong end of the clinical axis (§5.5).

---

## 4. Where noise would enter, and the gain-compensation mechanism

### 4.1 Three sites

**Site 1 — the optic nerve itself.** Demyelinated fibres are intrinsically noisier,
or carry a worse signal-to-noise ratio. This noise sits *upstream of the lesion's
own loss of amplitude*, so it is attenuated along with the signal: a pure gain
reduction leaves this ratio unchanged. It only does any work if the noise itself
increases, which is exactly what §2.1 claims happens.

**Site 2 — local cortical noise, upstream of the normalization gain.** Noise
generated in cortex, downstream of the lesion. The arriving signal has been
attenuated by a factor *k*; this noise has not. So the signal-to-noise ratio falls
by *k* directly. **This is the site that makes amplitude lesions bite.**

**Site 3 — late, or decision, noise.** A reduced response against a fixed noise
floor. Note that gain compensation *helps* here: to the extent normalization
restores the mean response, late noise does relatively less harm.

### 4.2 The mechanism to take most seriously (JW)

> When the input drive to cortical neurons is reduced, those neurons likely
> increase their gain, and so inadvertently amplify local cortical noise.

In this model that needs **no new architecture**. Both cortical stages already
compute

```
R = s · N / (strength · D + sigma^2)          sigma = v1C50 = mtC50 = 0.1
```

(`shModelV1Normalization_Tuned.m`, `shModelMtNormalization_Tuned.m`), where `N` is
the rectified linear response and `D` is a version of it pooled over space and
time. **`D` is computed from the lesioned input.** So scaling the drive by *k*
lowers `D`, and the effective gain `1/(strength·D + sigma^2)` **rises
automatically**. The only thing missing is a noise term in `N`.

A uniform RGC amplitude lesion is, to a first approximation, a reduction in
contrast, and the expression above is the model's contrast-response nonlinearity.
Above the semi-saturation point the numerator and denominator largely cancel and
the mean response is preserved; below it they do not. For these stimuli the model
sits in a mixed regime: direction peak and direction selectivity are essentially
fully compensated, while speed-tuning peaks still fall 35–49%. How much is absorbed
has now been measured — report §4.8.

**Three consequences follow, and only one of them is a change in signal-to-noise
ratio.** They are worth separating, because the loose version of this argument gets
it wrong:

- **Absolute output noise rises.** Site-2 noise entering `N` gets multiplied by a
  gain that grows as the lesion deepens. Response variability genuinely increases.
- **The mean response is restored toward normal.** The deficit becomes *invisible
  to any measure of the mean* — direction tuning, direction selectivity, tuning
  width — which is exactly the set that report §4.7.2 finds unchanged.
- **The signal-to-noise ratio falls by *k***, from the loss of signal against
  undiminished local noise. The shared gain cancels in the ratio, so the gain
  increase is not itself the source of the loss. What it does is **hide the loss
  from the mean and re-express it as variability.**

The net picture fits the clinic: **near-normal tuning curves, substantially
degraded discriminability.** A tuning-curve experiment would call this eye normal.
A psychophysical one would not.

### 4.3 The dynamic version, which this model cannot express

If cortical gain control amplifies its *own* circuit noise, or loses stability at
low drive, the effect would exceed the static account above. That needs
normalization **dynamics** (ORGaNICs and relatives) — the same gap `TODO.md` §3
flags for VEP latency, where static normalization is why latency effects arising in
cortex are out of reach. The static analysis here is a **lower bound** on the
mechanism, not the whole of it. If §5 finds the static version already sufficient,
dynamics is a refinement. If the static version underpredicts, dynamics is the next
thing to build.

### 4.4 Fixed dispersion and trial-to-trial jitter are different things

This distinction is currently collapsed, and it should not be. §2.1 describes two
separate temporal pathologies:

- **Fixed dispersion across fibres** — fibre A is always slower than fibre B. This
  is a *frozen* delay pattern, identical on every trial. It is what `delay_random`
  models, and it is the largest effect on record (report §4.7.5).
- **Trial-to-trial jitter within a fibre** — the same fibre's arrival time varies
  from one repeat of the stimulus to the next. This is **noise**, and nothing in
  the model expresses it.

They predict differently. A frozen delay map is a *systematic* distortion: the
response is wrong but repeatable, and in principle a later stage could compensate
for it. Jitter that varies by trial cannot be undone. It destroys exactly the
temporal precision that computing motion energy depends on. Since the model is
already far more sensitive to delay being *decorrelated* than to delay being
*large*, **jitter should be the single most damaging manipulation available**, and
it has never been run.

Naud & Longtin's model is the natural source for the form of both, since it derives
dispersion and delay together from sporadic damage rather than imposing them
separately.

---

## 5. Predictions

### 5.1 Uniform and patchy amplitude lesions should stop matching

This follows straight from §4.2. The normalization pool is **blurred across
space**, so it mixes damaged and intact locations together:

- Under a *uniform* lesion, `D` falls everywhere by the same factor, so every
  location gets the same rescue in gain.
- Under a *patchy* one, a badly damaged location sits in a pool partly supported by
  intact neighbours. Its `D` stays higher than a uniform lesion of the same local
  severity would give, so it gets **less** gain compensation and is suppressed
  more. The reverse holds too: intact locations sit in a pool lowered by damaged
  neighbours, get **more** gain, and amplify their local noise more.

Report §4.7.4 currently finds uniform and patchy amplitude lesions
interchangeable, around a 9–18% coherence drop either way. **With site-2 noise
present they should diverge**, and the divergence should scale with the spatial
correlation length of the damage relative to the width of the normalization pool.
This is a clean test of whether the gain-compensation account does real work, and
it uses lesions that already exist.

### 5.2 Trial jitter should outrank every deterministic lesion

Per §4.4. The model is already more sensitive to delay being decorrelated than to
delay being large, and jitter is decorrelation that cannot be compensated for.
Expect motion-letter d′ to fall further under jitter than under a frozen
`delay_random` map of the same variance.

### 5.3 High-frequency failure should be selective for MT

Per §3.1. A low-pass lesion of the RGC filters removes parasol drive
preferentially, and parasol drive is nearly all of MT's input under the two-stream
architecture. So it should cost MT far more than a class-agnostic amplitude lesion
of matched average size. Needs no noise. Runnable now.

### 5.4 Recovery should separate latency from discriminability

§2.1 claims that remyelination suppresses jitter and stochastic block while leaving
a residual uniform latency. In model terms, recovery is **noise terms shrinking
while a small uniform delay persists**. Since a uniform delay is invisible to
steady-state tuning (report §4.7.3), the model predicts **motion-form
discrimination recovering while VEP latency stays prolonged.**

**The real data are harder than that clean story.** The target is Brusa, Jones &
Plant (2001), 31 patients with serial VEP and psychophysics over 24 months. What it
reports, and its full citation, are in
[`optic neuritis targets/NOTES.md`](../optic%20neuritis%20targets/NOTES.md).

Two things follow for the model. First, the prediction has to be stated as a
difference in *rate* — measures driven by variability recovering faster and more
completely than latency — not as an absolute dissociation, because latency recovery
in the real data is partial rather than absent. Second, their fellow eye
deteriorates over the same window, so **the fellow eye is not a clean
within-subject control** for the planned affected-versus-fellow design.

### 5.5 The low-speed deficit is probably about the operating point (JW)

The tempting account is that the clinical low-speed deficit means the low-speed
machinery was selectively damaged. The model even offers a candidate, since the
effect of a midget knockout is graded 10 to 30 times from slow to fast preferred
speed (report §4.5). **JW's account is different, and better.**

> Patients fail at letter recognition in motion-defined stimuli at very slow speeds
> NOT because of exacerbated damage to neurons tuned to very low temporal
> frequencies, but rather because at very low speeds, MT is signal starved, and any
> hit to SNR will most impact any responses with low signal.

On this account the deficit needs **no speed-selective damage at all**. The
controlling variable is the size of the signal at the read-out, and speed is merely
one of several ways to lower it. It has a sharp falsifiable consequence, also JW's:
**thresholds on a coherence staircase at high speed should be elevated too**,
because low coherence starves the signal just as low speed does.

Report §4.8 measured the premise and it holds, by two routes rather than one. MT's
motion signal across 0.0625–0.3125 px/frame is 4 to 5 times smaller than at
0.625–1 px/frame while V1 is flat, so the starvation is real and specific to MT.
And compensation is *strongest* where the drive is weakest (C = 0.89 at 0.0625
px/frame against 0.64 at 0.625), which was the opposite of what was predicted. High compensation means the
lesion drives a *large* increase in gain, and that increase is precisely what
amplifies site-2 cortical noise. So at low speeds the signal is smallest and the
gain increase is largest. Both point the same way.

**The sharper version of the prediction.** If the controlling variable really is
drive rather than speed, then every way of lowering drive should expose the same
deficit:

- Drive is **U-shaped in speed**, collapsing at 0.0625–0.125 px/frame and again at
  6 px/frame, and peaking at 1 px/frame. So the model predicts impairment at
  **both** ends, not a deficit that only grows as speed falls.
- Lowering coherence lowers drive at any speed, so a coherence staircase at high
  speed should be elevated too.
- **Plot the deficit against unlesioned MT response, not against speed.** If the
  low-speed, high-speed and low-coherence conditions all collapse onto one curve,
  the operating-point account wins outright. If the deficit still depends on speed
  at matched drive, something speed-specific — cell type — is also at work. That is
  a clean discriminating experiment, and it is the one to run.

---

## 6. What to build, in order

1. ~~**Compensation index.**~~ **Done** — report §4.8.
2. **A map of drive over coherence × speed, still deterministic.** Extend
   `compensationIndex.m` with a coherence axis and re-express everything against
   unlesioned drive rather than speed (§5.5). Tests JW's prediction directly, and
   needs no noise code.
3. **High-frequency failure** as a change in filter shape (§5.3). Also no noise.
4. **Noise, one site at a time.** Site 2 first — added into `N` in
   `shModelV1Normalization_Tuned`, before the division — since it carries the
   mechanism. Site 1 goes into the class channels in `shClassV1Basis`; site 3 into
   the read-out. Run them separately before combining. They have different
   signatures, and combining first makes the result uninterpretable.
5. **Temporal noise** — jitter per trial and Bernoulli dropout (§4.4). These are
   the ones with no deterministic counterpart at all.

### Decisions that have to be made first

- **Does the noise scale with the response, or have fixed variance?**
  Poisson-like noise that scales with the response partly cancels a gain reduction.
  Fixed-variance noise does not. This changes the *sign* of several predictions
  above. It is not a detail.
- **How is the noise correlated?** Independent at every location is the easy
  default and it is wrong. Cortical noise is correlated across space, and it is
  correlated noise along the read-out direction that actually limits
  discriminability. At a minimum, check whether the conclusions survive spatially
  correlated noise.
- **Dropout is not Gaussian.** Stochastic conduction block is multiplicative,
  all-or-none, and correlated in time — a block persists for a burst. Do not
  approximate it as additive noise.
- **Which observables?** Motion-letter d′ (report §4.6) is the natural one and
  connects to deficit (b) directly. Report it **alongside a measure of
  trial-to-trial variability** in the MT response, since §4.2 predicts that the
  mean and the variability move in opposite directions. Reporting only the mean
  would reproduce the current blind spot with extra steps.
- **The observable for deficit (a) still does not exist.** A noisy analogue of VEP
  latency has to be defined at all — see `TODO.md` §3.

---

## 7. References

**Verified, and in scope**

- Naud & Longtin (2019), *J Math Neurosci* 9:3,
  [10.1186/s13408-019-0071-6](https://doi.org/10.1186/s13408-019-0071-6). A
  stochastic spike-diffuse-spike model: sporadic damage to an axon produces both
  delay and dispersion of the compound action potential. **Read the corrected
  version.** Preprint at
  [biorxiv 10.1101/501379](https://www.biorxiv.org/content/10.1101/501379). Not yet
  in `literature/`.
- Brusa, Jones & Plant (2001), *Brain* 124(3):468–479,
  [10.1093/brain/124.3.468](https://doi.org/10.1093/brain/124.3.468). Two-year
  serial VEP and psychophysics after optic neuritis. A **target**, not a mechanism
  paper. It belongs in `optic neuritis targets/`.

**Do not cite for the claims it was attached to**

- PMID 12108932, *Physiol Res* (2002). Intrinsic axonal noise and the preservation
  of interspike intervals in myelinated axons. It does not establish changes in
  g-ratio after remyelination, nor that remyelination suppresses jitter.

**Still to ground** — everything in §2.1 not covered above: conduction velocities
for continuous versus saltatory conduction in demyelinated CNS axons; failure at
high firing rates; internode length and g-ratio after remyelination in the CNS; and
the claim that variability in timing recovers ahead of mean latency. That last one
carries §5.4 and should be sourced before it is used.
