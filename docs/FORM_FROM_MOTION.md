# The form-from-motion task in the model

**A design note.** Started 2026-09-11 on branch `form-from-motion`. It records
how the motion-defined letter task is simulated, the decisions behind it, and
every way the simulation departs from the experiment it is compared with.

Read `AGENTS.md` first. Units are in `UNITS_AND_SCALE.md`; noise is in
`NOISE_AND_DEMYELINATION.md`.

---

## 1. The question

Optic-neuritis patients recognise letters defined only by motion poorly, worst
at slow dot speeds (Raz et al. 2012). The account being tested: inflammation
lowers the signal-to-noise ratio of parasol retinal ganglion cells, which lowers
it in MT, and MT is where motion-defined form is read out. In healthy observers,
lowering dot **coherence** (external noise) reproduces the shape of the patient
deficit. The analysis is in
`~/repos/Research/Exploring/EXPLORING_Speed_Coherence_Psychometrics/analysis/out/SUMMARY.md`.

The model work has four steps:

1. Build the letter task: stimulus, MT read-out, decision.
2. Add internal noise to the model.
3. Measure performance against speed and coherence, and compare its **shape**
   with the control data.
4. Lower the amplitude of the parasol pathway and measure performance against
   speed at 100% coherence.

**The aim for now is a qualitative picture (JW, 2026-09-11).** Choices that
depart from the booth study are recorded in §4, not perfected. Once the pipeline
works, we can measure how stimulus properties such as dot size, dot density and
trial length change the results.

## 2. How the task is simulated

**Stimulus** — `stim/mkMotionLetter.m`. The same "window" design as the booth:
two dot populations each cover the whole field; letter dots are drawn only inside
the letter, background dots only outside it, and the two drift in opposite
directions. Options added for this task:

- `coherence`: each dot is labelled signal or noise when it is born, with
  probability equal to the coherence. A noise dot moves at the same speed in a
  random direction, which it keeps for its life.
- `dotLifetimeFrames`: a dot is replotted at a random place when its life ends,
  with a new label and, if noise, a new direction. Starting ages are staggered.
- `motionAngleDeg`: direction of the letter's dots (0 = right, 180 = left).
- `dotRendering = 'area'`: dots smaller than a pixel are drawn as their area,
  shared among the pixels around each dot's centre (§4, dot size).
- `letterMask`: a precomputed mask, so a trial need not render the letter.

With the defaults the movie is identical, dot for dot, to the one made before
these options existed (checked 2026-09-11).

These rules match Kristin's experiment code (`runSingleTrial.m`, current
version): the noise-dot rule, the staggered lifetime, replotting at a random
position, and the random left/right direction on each trial.

**Read-out** — `task/`.

- `shLetterTemplates`: one mask per Sloan letter, drawn with the same function
  (`mkLetterMask`) the stimulus uses, then **cropped** to the MT output grid
  with `shCropToOutput`. Every model stage trims its filters symmetrically, so a
  map is the centre of the stimulus grid, not a shrunken copy of it.
- `shOpponentMap`: at each position, the sum over moving MT units of each
  unit's response times the cosine of its preferred direction, averaged over
  time. This is the rightward-minus-leftward signal: the horizontal component
  of the MT population vector.
- `shTemplateScores`: for each letter, mean of the map inside the letter minus
  the mean outside it.

**Decision** — `task/shRunLetterTrials`.

- *Known letter.* The true letter's score, signed so it is positive when the
  letter is seen. Its mean over trials divided by its SD is a d′, turned into a
  predicted 10-choice proportion correct by `shMafcProportionCorrect`
  (optimistic, because the ten letters' scores are not independent).
- *Classifier.* The letter whose score is largest in absolute size. The
  direction is random and the decision does not use it (JW, 2026-09-11). Chance
  is 1/10.
- *Matched filter* (added 2026-09-11). The noise-free baseline showed that the
  inside-minus-outside score confuses letters that share most of their shape,
  so the classifier tops out near 85–95% (§5). The matched filter correlates
  the trial's map with each letter's **expected** MT map
  (`shMatchedFilterTemplates`, `shMatchedFilterScores`) and picks the largest
  correlation in absolute size. The expected maps are averages of noise-free
  maps at coherence 1 and 5 deg/s, built from dot samples separate from the
  test trials. One set is used for every speed and coherence (JW). A
  correlation ignores the map's overall strength, but the map's shape may
  change with speed and coherence; whether filters built in other conditions
  do better is an open check.

Every trial's full score vector is saved, so other decision rules can be tried
without re-running the model.

**Internal noise** — `pars.noise` (see `shPars`, and
`NOISE_AND_DEMYELINATION.md` §6). Additive Gaussian noise with fixed variance on
the output of each stage: RGC channels (after the gain, so a lower gain means a
lower signal-to-noise ratio), V1 (after normalization), MT. Off by default.

## 3. Decisions (JW, 2026-09-11)

| decision | choice |
|---|---|
| read-out | rightward-minus-leftward MT, inside vs outside the letter |
| decision rule | classifier over the 10 letters, sign-free; known-letter d′ reported too |
| matched filter | added after the baseline: expected MT map of each letter at coherence 1, 5 deg/s; one set for all conditions; per-condition filters are a later check |
| noise for steps 3 and 4 | RGC noise only, SD 0.05: the easiest condition (coherence 1, 5 deg/s) stays about 95% correct, as for the controls, and lower coherence and slower speeds are noise-limited. This replaces a first rule, "d′ ≈ 3", which left even the easiest condition at 45% correct (§5). V1 and MT noise are later checks |
| step-3 grid | 8 speeds (0.15–20 deg/s) × 4 coherences (1, 0.75, 0.5, 0.25) × 40 trials, run locally (`explore/formFromMotionSpeedCoherence.m`) |
| psychometric fit | speeds up to 10 deg/s only: beyond MT's fastest tuning performance falls again, which a rising psychometric function cannot describe |
| step-4 lesion | gain of the 8 parasol classes × 1, 0.8, 0.65, 0.5, 0.35; midget classes untouched; RGC noise fixed at SD 0.05, added after the gain; weights not refitted; the observer keeps the healthy model's matched filters. Coherence 1, the same 8 speeds, 40 trials (`explore/formFromMotionParasolGain.m`) |
| noise | additive, independent, fixed variance, at the OUTPUT of RGC, V1 and MT |
| V1 noise site | after normalization, like the other two (not in the numerator) |
| letter direction | random left/right on each trial, as in the booth |
| control data | only the 10 observer units run with the current experiment code: wlsubj114, 147, 178, 195, 208, both eyes |
| dots | area-weighted, at the booth's size and density |
| trial length | 1 s (the booth uses 4 s) |
| code style | JW's MATLAB rules (`~/repos/Agents/Coding/Matlab/`) for new files; existing files keep their style |
| new scripts | plain-text Live Scripts |

**Why only 10 control units.** The other five 100-ms units (KM100, wlsubj215 L/R,
wlsubj221 L/R) were run with an older version of the experiment code. Their files
carry `coherenceMode` and `jitterDeg` columns, which the current code does not
write, and they cannot tell us which noise-dot rule or direction rule was used.
On the censored fits — each unit refitted without any series stuck at chance,
as in `SUMMARY.md` and in the step-3 comparison — the two groups look alike
(medians, current code against older code): threshold at full coherence 0.19
and 0.17 deg/s, `b` −1.41 and −1.23, σ 0.27 and 0.22. An earlier version of
this note reported much shallower curves for the newer units (σ 0.46 against
0.25). Those numbers came from the fits to all series, which censored series
flatten, and four of the ten newer units have one.

## 4. Departures from the booth study

| property | booth | model | what it may change |
|---|---|---|---|
| pixel size | ~100.6 px/deg | 10 px/deg | everything spatial is coarser |
| dot size | 4 px = 2.4 arcmin, round, anti-aliased | 0.4 px, drawn as area into 6-arcmin pixels | pixel contrast about a third of that of 1-px dots (pixel SD 0.08 against 0.25) |
| dot overlap | overlapping white dots stay white | covered area summed per pixel, capped at 1 | approximate where dots crowd |
| dot density | 50% coverage, ~400 dots/deg² per population | the same | — |
| frame rate | 85 Hz | 50 frames/s | coarser motion sampling |
| trial length | 4 s | 1 s | less averaging of dot noise, so lower performance |
| dot lifetime | 100 ms | 5 frames = 100 ms | — |
| field | full screen, 12.7 × 9.5 deg | 10 × 10 deg stimulus, 6.4 × 6.4 deg MT output | less background around the letter |
| letter size | 168 arcmin | 28-px font, a 29-px (2.9 deg) letter | — |
| letter choice | random each trial | each letter equally often | — |
| speeds | staircase, 0.009–4 deg/s | fixed grid, chosen for the model's own MT tuning | absolute thresholds cannot be compared (`UNITS_AND_SCALE.md` §6) |
| observer | human, 10-AFC | template decoder that knows the 10 letters and where they are | an ideal read-out of MT, not a model of the whole observer |

**What the dots look like (2026-09-13).** One frame was drawn two ways from the
same dot positions (same seed and the same number of dots; a scratch render, not
in the repo): booth-like, 4-px round dots at 100 px/deg, and the model's 0.4-px
area dots at 10 px/deg. The booth-like frame shows distinct white dots covering
35% of the area (pixel SD 0.24). Averaged into 0.1° pixels, its SD is 0.068 and
it correlates 0.86 with the model's frame (SD 0.084). So the model's frame is
close to the booth image seen through 0.1° pixels: the dots vanish because each
model pixel is 2.5 dot diameters wide, not because of how they are drawn. The
model's frame is brighter on average (0.75 against 0.68) because it adds the
areas of overlapping dots, where the booth draws an overlap only once.

The last two rows mean the comparison with data is about **shape**: the
coherence exponent `b`, the slope σ, and the chance-corrected ratio curves — not
threshold values.

## 5. Status

Built and checked (2026-09-11):

- **Stimulus options.** Defaults reproduce the old movie exactly. The direction
  option moves letter and background dots the right way. Area-weighted dots
  give the booth's density (about 400 per deg² per population) and no static
  letter cue in the time-averaged image.
- **Read-out and decision** (`task/`). Four trials end to end through the
  two-stream model take about 2 s each at a 64 × 64 × 50 output on this machine.
- **Noise hooks.** With every SD at 0 the output is unchanged. Each site is
  reproducible from a seed. Lagged RGC classes share their cell type's noise
  with the right delay.
- **Psychometric fit** (`shFitSpeedCoherencePsychometric`,
  `shSpeedCoherencePsychometric`). The same joint model as the control fits.
  On simulated trials it recovers threshold, `b`, σ and lapse to within a few
  per cent.
- All 12 regression tests pass. Every new file passes the Code Analyzer.

### Noise-free baseline (2026-09-11)

`explore/formFromMotionBaseline.m`: lagged two-stream model, 64 × 64 × 50 MT
output, 20 trials per condition, no internal noise — the only trial-to-trial
variability is the dot sample. Classifier proportion correct (chance 0.1):

| coherence | 0.15 deg/s | 0.3 | 0.6 | 1.25 | 2.5 | 5 | 10 | 20 |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.25 | 0.60 | 0.65 | 0.80 | 0.90 | 0.85 | 0.90 | 0.85 |
| 0.75 | 0.35 | 0.55 | 0.60 | 0.75 | 0.85 | 0.90 | 0.85 | 0.80 |
| 0.5 | 0.30 | 0.55 | 0.60 | 0.70 | 0.80 | 0.95 | 0.90 | 0.65 |
| 0.25 | 0.25 | 0.25 | 0.50 | 0.45 | 0.65 | 0.80 | 0.80 | 0.35 |

At 1 px/frame (5 deg/s) and full coherence: opposite drift 0.85 correct
(known-letter d′ 20.8); same drift, the motion control, 0.05 (d′ −3.0).

What it shows:

1. **The qualitative pattern is there before any internal noise.** Performance
   rises with speed, and lower coherence moves the curves to faster speeds and
   lowers them. The known-letter d′ is ordered by coherence at every speed.
2. **Performance falls again at 20 deg/s**, beyond MT's fastest tuning, most at
   low coherence: the U-shaped drive of `NOISE_AND_DEMYELINATION.md` §5.5.
3. **The classifier tops out near 0.85–0.95**, even where d′ is about 20. Its
   errors are systematic confusions between letters that share most of their
   shape (C, O, D), made worse by MT's spatial blur. Humans approach 100%. This
   matters for the psychometric fit, which assumes performance reaches
   1 − lapse with lapse at most 0.06.
4. **The motion control is at chance for the classifier, but its known-letter
   d′ is −3**: a weak letter-shaped signal with no relative motion, probably
   from dots appearing and disappearing at the letter's edges (not checked).
   It is about 7 times smaller than the motion signal.
5. **At the slowest speed, performance is 0.25–0.35**, above chance.

With 20 trials per condition, a proportion correct has a standard error of up
to 0.11; read the shapes, not single points.

### Matched-filter check (2026-09-11)

Filters from 2 noise-free trials per letter; 10 test trials at 5 deg/s,
coherence 1, on separate dot samples:

| | inside minus outside | matched filter |
|---|---|---|
| no internal noise | 0.80 correct | **1.00** correct |
| RGC noise SD 0.05 | 0.80 | 0.90 |

The matched filter removes the ceiling, even though MT's blur makes the
expected maps of O and C almost identical (r = 0.98; median r between any two
letters 0.84).

### Choosing the RGC noise level (2026-09-11)

Matched-filter proportion correct at 5 deg/s, 20 trials per cell (filters from
2 noise-free trials per letter):

| RGC noise SD | 0 | 0.05 | 0.07 | 0.10 | 0.14 | 0.20 |
|---|---|---|---|---|---|---|
| coherence 1 | 1.00 | **0.95** | 0.75 | 0.45 | 0.25 | 0.15 |
| coherence 0.25 | 0.70 | **0.35** | 0.15 | 0.05 | 0.10 | 0.10 |
| d′, coherence 1 | 256 | 31 | 11 | 3.8 | 1.6 | 0.6 |

Performance collapses steeply between SD 0.05 and 0.2. The first rule, "d′ ≈ 3",
lands near SD 0.1, where even the easiest condition is 45% correct and coherence
0.25 is at chance. **SD 0.05 was chosen (JW):** the easiest condition stays near
ceiling, as for the controls, while low coherence clearly costs performance.

Done on the desktop: step 3, step 4 and the noise-level run (results below).
The branch travels as a private git bundle and is not pushed, because it
mentions unpublished pilot data.

### Step 3 results (2026-09-11, run on the desktop)

`explore/formFromMotionSpeedCoherence.m`, commit c8add29: RGC noise SD 0.05,
matched filters from 8 noise-free trials per letter, 40 trials per condition;
the grid took 18 minutes on the desktop. Matched-filter proportion correct:

| coherence | 0.15 deg/s | 0.3 | 0.6 | 1.25 | 2.5 | 5 | 10 | 20 |
|---|---|---|---|---|---|---|---|---|
| 1 | 0.15 | 0.20 | 0.43 | 0.65 | 0.88 | 0.90 | 0.83 | 0.30 |
| 0.75 | 0.08 | 0.13 | 0.28 | 0.53 | 0.68 | 0.83 | 0.80 | 0.15 |
| 0.5 | 0.08 | 0.13 | 0.18 | 0.35 | 0.53 | 0.68 | 0.55 | 0.10 |
| 0.25 | 0.08 | 0.10 | 0.08 | 0.23 | 0.35 | 0.35 | 0.35 | 0.10 |

Joint fits (speeds up to 10 deg/s; the controls are the 10 current-code units,
censored fits):

| fit | `b` | σ |
|---|---|---|
| model, all coherences | −1.88 | 0.61 |
| model, without 0.25 | −2.06 | 0.57 |
| model, without 0.25 and 0.5 | −2.18 | 0.49 |
| model, inside-minus-outside decoder | −1.85 | 0.68 |
| controls, median (range) | −1.41 (−1.96 to −1.13) | 0.27 (0.14 to 0.76) |

Fitted separately, the thresholds at coherence 1, 0.75, 0.5 and 0.25 are 0.83,
1.58, 3.87 and 19.0 deg/s (σ 0.43, 0.52, 0.75, 0.95).

What it shows:

1. **The qualitative pattern is reproduced.** Performance rises with speed, and
   lower coherence moves the curves to faster speeds and lowers them.
2. **~~Threshold rises more steeply with falling coherence than in the
   controls.~~ Wrong — see "Ceilings, refitted" below.** With the lapse rate
   capped at 0.06, the fitted thresholds scale as about c^−2.2. An earlier
   version of this note said this was not caused by the low-coherence plateau,
   because removing the low coherences made `b` steeper. That test was flawed:
   it kept the near-1 ceiling on the coherences that remained, and even
   coherence 0.75 levels off at 0.81. A fit forced to one common ceiling reads a
   lower plateau as a rightward shift.
3. **Each coherence has its own ceiling.** Peak proportion correct is 0.90,
   0.82, 0.68 and 0.35, and the lapse rate sits at its bound (0.06) in every
   fit. This is the partial ceiling of `SUMMARY.md` §5.1 (hypothesis 3, a
   coherence floor), with a mechanism: faster dots cannot make up for low
   coherence, because MT's drive falls again beyond about 5–10 deg/s. The joint
   model cannot express a ceiling that depends on coherence; the A(c) model of
   §5.1 could.
4. **The curves are shallower than the controls'**, and more so at low
   coherence, so the model's chance-corrected ratio curves rise more gradually
   with relative speed.
5. **Performance falls at 20 deg/s at every coherence**, beyond MT's fastest
   tuning.

### Ceilings, refitted (2026-09-11)

The step-3 trials refitted with a **free ceiling** for each coherence (lapse
rate up to 0.9), at speeds up to 10 deg/s. Threshold here is each curve's
midpoint, halfway between chance and its own ceiling. Figure:
`explore/_figs/formFromMotionCeilingFits.png` (made interactively; not yet a
script).

| coherence | ceiling | threshold (midpoint) | σ |
|---|---|---|---|
| 1 | 0.87 | 0.73 deg/s | 0.34 |
| 0.75 | 0.81 | 1.09 | 0.34 |
| 0.5 | 0.61 | 1.25 | 0.28 |
| 0.25 | 0.35 | 1.25 (poorly determined: the curve is nearly a step) | 0.03 |

Slope of log threshold on log coherence: **`b` = −0.33**. The joint model of
`SUMMARY.md` §5.1 — power-law threshold, shared σ, a ceiling per coherence —
gives **`b` = −0.59**, σ 0.31, ceilings 0.88, 0.79, 0.61 and 0.39.

1. **In the model, lower coherence mainly lowers the ceiling;** it moves the
   curve along speed only a little. The steep `b` of the capped-lapse fits was
   an artifact of forcing one common ceiling.
2. **This differs from the controls in degree, not entirely in kind.** Most
   control curves mainly shift along speed (`b` −1.2 to −1.4) and still reach
   ceiling, but some controls in some conditions also level off at low
   accuracy, as the model does at low coherence (JW): KM100 at coherence 0.10,
   wlsubj221_R and wlsubj178_L at 0.25 (the series censored in `SUMMARY.md`).
   In the model every coherence below 1 is capped, even 0.75 (at 0.81); in the
   controls only the lowest coherences are, in a few units. A likely reason, not
   tested: MT's drive in the model peaks near 5 deg/s, only about 6× above the
   full-coherence threshold, and falls beyond it, so faster dots cannot make up
   for a weaker signal. The controls were tested up to about 20× their threshold
   without running out of drive. That ratio does not depend on units, so this is
   a real structural difference between the model and the observers.
3. **A possible link to the patients (a suggestion only):** Raz's patients
   never regain 100% of control even at fast speeds, which pure coherence
   reduction in the psychometric model could not produce (`SUMMARY.md` §5,
   §8). In this model, lowering the signal-to-noise ratio does lower the
   ceiling.

### Full coherence: model against controls (2026-09-11)

`explore/formFromMotionFullCoherence.m`. The model's coherence-1 trials (step 3)
and each of the 10 control units' coherence-1 trials, fitted the same way: one
psychometric function of log speed, chance 0.1, lapse at most 0.06.

| | threshold | σ | proportion correct above 3× own threshold |
|---|---|---|---|
| model | 0.83 (model units) | 0.43 | 0.87 (120 trials) |
| controls, median | 0.18 deg/s | 0.13 | 0.95 (38 trials; 9 of 10 units at 100%) |
| controls, range | 0.10–0.56 | 0.01–0.62 | |

Proportion correct against speed relative to each observer's own threshold:

| speed ÷ own threshold | ≈0.75× | ≈1.4× | ≈2.4–3× | ≈4–6× | ≈12× |
|---|---|---|---|---|---|
| controls, trials pooled | 0.38 | 0.68 | 0.88 | 0.93 | 1.00 |
| model | 0.43 | 0.65 | 0.88 | 0.90 | 0.83 |

1. **Around threshold the model tracks the pooled controls closely**, from about
   0.7× to 6× threshold. The individual control fits look much steeper (median
   σ 0.13), but each rests on 50 staircase trials bunched near threshold, so
   those slopes are poorly determined; the pooled trials point to a slope
   nearer 0.25–0.3, like the joint fits, against the model's 0.43.
2. **The difference is at the top.** The controls reach 100% whenever the
   staircase took them well above threshold (only 1–4 trials per unit, apart
   from wlsubj114_R). The model peaks near 0.90 and falls again beyond about
   6× threshold, as MT's drive drops at high speed.
3. **Below threshold there are no control data** to compare with the model's
   lower tail.
4. The model's threshold is about 4.6 times the controls' in deg/s; the model's
   units make this a label, not a finding.

### Letter confusions, and MT receptive-field size (2026-09-11)

The question (JW) was whether a subset of letters reaches the model's own
ceiling when accuracy is high (high coherence, high speed). It does: six of the
ten are never missed. With the C, D and O templates correlating at 0.97–0.99,
very little noise is needed to push those three off ceiling.

**The model's shortfall from ceiling is mostly the round letters.** 200 trials
at coherence 1 and 5 deg/s (desktop filters; the first 40 trials reproduced
the desktop's exactly): 93.5% correct. Six letters (H, N, R, S, V, Z) were never
missed. Of the 13 errors, C–O 6, D–O 4, C–D 1 — **85% within {C, D, O}** — and
K–R 2. These are the letters whose expected MT maps are most alike (C–O
r = 0.987, C–D 0.969, D–O 0.964; median pair 0.847).

**The controls confuse them too, but they are a smaller share of their
errors.** The 10 current-code units at coherence 1: 206 errors in 500 trials,
mostly near threshold. D–O (7%) and C–O (6%) are the two most frequent pairs,
but only **15%** of errors fall within {C, D, O}; the rest spread thinly (K–N,
R–S, R–Z, …). O, D, C and also R are the humans' hardest letters. Caveat: most
human errors are near threshold, where observers partly guess, while the
model's are at 93.5% correct and systematic. A fair comparison needs
confusions at matched accuracy.

**MT receptive-field size.** The model's MT spatial extent combines the V1
filter (σ ≈ 1.3 px), the complex-cell blur (σ 1.6 px) and MT pooling (σ 3.0 px),
plus the parasol centre (σ 1.6 px) in the lagged model: σ ≈ 3.7–4 px, so
2σ ≈ 0.75–0.8 deg everywhere (the model is not foveated). In macaque, MT's
excitatory RF has 2σ ≈ eccentricity (JW). The C's opening is 0.5 deg high and
centred 1.45 deg from the letter's centre, where a macaque MT RF would have
2σ ≈ 1.45 deg: about twice the model's, and about three times the opening. So a
biologically sized MT would blur the gap more, not less. If human reading
depended only on single MT RFs at that size, the round letters should dominate
human errors even more than they do in the model; they do not. Two
possibilities, neither tested: a population read-out can resolve detail finer
than one RF when noise is low (the matched filter separates C from O perfectly
without noise, despite r = 0.987), and kinetic-boundary signals outside MT
(V2/V3) may carry the fine form.

### Internal noise against coherence: design (2026-09-11)

The premise of the approach is that lowering coherence (external noise) acts
like raising internal noise (JW). Before this run the model had several noise
levels at one speed (5 deg/s) and one noise level across speed (step 3), which
cannot test that. `explore/formFromMotionNoiseLevel.m` runs coherence 1 at RGC
noise SD 0.05, 0.06, 0.07, 0.085, 0.10 and 0.12, across step 3's 8 speeds, 40
trials each (SD 0.05 reproduces step 3's coherence-1 trials as a check). Every
curve, noise and coherence alike, is fitted with a psychometric function whose
ceiling is free (lapse up to 0.9), because each coherence has its own ceiling.
The test: do the noise points and the coherence points trace one path in
threshold, slope and ceiling? Both use the model's speed axis, so this does not
depend on units.

### Lower gain or more noise: how they relate in the model (2026-09-11)

JW did not mean to distinguish a lower gain at fixed noise (step 4) from more
noise at fixed gain (the noise-level run), and it is not known how the two
differ in optic neuritis: conduction block removes signal (like a gain loss),
while jitter and dispersion add noise.

In the model the two are nearly the same thing. RGC noise is added after the
gain, so a channel carries gain × signal + noise, and dividing by the gain k
shows that **gain k at noise SD s equals gain 1 at noise SD s/k**, provided
everything downstream scales with its input. It almost does: the V1 filters are
linear, the complex-cell stage squares, and divisive normalization divides by
pooled energy that scales the same way, so the factor cancels. The exception is
the constant in each normalization denominator (σ², the semi-saturation
constant), which becomes σ²/k². So a gain loss equals a noise increase **plus**
a contrast-like loss of drive against a fixed constant. Where the drive is well
above that constant the two are identical; where it is weak they diverge. The
compensation index (`MODEL_AND_LESIONS.md` §4.8) says that compensation is
substantial but incomplete, so the difference should be modest.

A second, smaller difference: step 4 lowers only the parasol gain, while the
noise run adds noise to every RGC class. MT takes 90% of its drive from the
parasol-only stream.

**Prediction:** at matched signal-to-noise ratio, a gain loss should cost most
where MT's drive is weakest — the slow speeds, where Raz's patients are worst.
**It did not hold:** at matched ratio the two gave the same proportion correct at
every speed, to within one binomial standard error (results below).

The two runs already pair up at matched ratio: parasol gain 0.5 ↔ noise SD
0.10 exactly; gains 0.8 and 0.65 ↔ SD ≈ 0.063 and 0.077, bracketed by the noise
run's 0.06, 0.07 and 0.085.

### Contrast response at the default gain (2026-09-11)

`explore/formFromMotionContrastResponse.m`, no internal noise. A calibration
(JW): one V1 unit (355 deg, 0.81 px/frame) and one MT unit (0 deg, 1 px/frame),
each driven by a drifting grating at its preferred spatial frequency and speed
(found by search: V1 0.16 cyc/px, 0.13 cyc/frame; MT 0.12 cyc/px, 0.12
cyc/frame), at 16 Michelson contrasts from 0.001 to 1, with every RGC class at
gain 1 (the default), 0.5, 0.25 and 0.125.

| | c50 at default gain | saturates by | letter dots, as grating contrast (coh 1 / 0.5 / 0.25) |
|---|---|---|---|
| V1 | 0.048 | about 0.3 | 0.026 / 0.022 / 0.020 |
| MT | 0.043 | about 0.3 | 0.044 / 0.026 / 0.019 |

1. **At the default gain the contrast response is sigmoidal over 0–1** (on log
   contrast) for both neurons, half-maximal near 4–5% contrast and saturating
   by about 30%.
2. **Lower gain shifts the curve along contrast, as it must:** each lower-gain
   curve matches the default curve at contrast × gain to within 1% of the
   maximum. Contrast and gain enter the model only as their product.
3. **The letter task is a low-contrast stimulus for these neurons.** A uniform
   field of the task's dots (5 deg/s, area-weighted, 50% coverage, 100 ms
   lifetime) drives them like a grating of only 2–4.5% contrast: at or below
   c50, on the steep part of the curve. Lower coherence lowers it further, as a
   contrast-like loss of drive for a direction-tuned neuron. So the task works
   where a loss of gain or contrast costs response quickly, not on the
   saturated plateau.

### Step 4 design (2026-09-11)

Lower the parasol gain with the RGC noise fixed, at coherence 1, across speed.
Reported: proportion correct; the mean and trial-to-trial SD of the true
letter's matched-filter score (normalization may hold the mean while the
variability grows); a psychometric fit per gain; the chance-corrected ratio to
the healthy model beside Raz et al.'s patient-to-control curves (shapes only —
Raz's axis lies below the model's speed range, and their values are not
chance-corrected). If step 3's results are on the same machine, each gain is
matched to the coherence whose ratio curve it resembles most: the
equivalent-noise account tested inside the model, on one speed axis.

### Step 4 and the noise-level run: results (2026-09-11, desktop)

Both ran on the desktop from commit 8200346 (22 and 26 minutes), and both
reproduced step 3's healthy trials exactly. Matched-filter proportion correct at
coherence 1:

| condition | 0.15 deg/s | 0.3 | 0.6 | 1.25 | 2.5 | 5 | 10 | 20 |
|---|---|---|---|---|---|---|---|---|
| healthy (gain 1, noise SD 0.05) | 0.15 | 0.20 | 0.43 | 0.65 | 0.88 | 0.90 | 0.83 | 0.30 |
| parasol gain 0.8 | 0.15 | 0.18 | 0.40 | 0.58 | 0.70 | 0.88 | 0.78 | 0.20 |
| parasol gain 0.65 | 0.15 | 0.18 | 0.20 | 0.48 | 0.63 | 0.73 | 0.60 | 0.13 |
| parasol gain 0.5 | 0.13 | 0.13 | 0.15 | 0.33 | 0.43 | 0.50 | 0.40 | 0.13 |
| parasol gain 0.35 | 0.10 | 0.10 | 0.10 | 0.20 | 0.23 | 0.28 | 0.23 | 0.13 |
| noise SD 0.06 | 0.13 | 0.18 | 0.40 | 0.58 | 0.73 | 0.88 | 0.78 | 0.23 |
| noise SD 0.07 | 0.15 | 0.18 | 0.23 | 0.53 | 0.68 | 0.78 | 0.70 | 0.18 |
| noise SD 0.085 | 0.15 | 0.15 | 0.18 | 0.38 | 0.63 | 0.58 | 0.53 | 0.10 |
| noise SD 0.10 | 0.13 | 0.13 | 0.15 | 0.25 | 0.43 | 0.50 | 0.38 | 0.13 |
| noise SD 0.12 | 0.10 | 0.10 | 0.13 | 0.18 | 0.33 | 0.33 | 0.25 | 0.13 |

Free-ceiling fits (speeds up to 10 deg/s; threshold = curve midpoint), for all
three manipulations (figure: `explore/_figs/formFromMotionThreeManipulations.png`,
made interactively):

| manipulation | levels | threshold (model deg/s) | ceiling |
|---|---|---|---|
| lower coherence | 1, 0.75, 0.5, 0.25 | 0.73, 1.09, 1.25, 1.25 | 0.87, 0.81, 0.61, 0.35 |
| more RGC noise | SD 0.05, 0.06, 0.07, 0.085, 0.10, 0.12 | 0.73, 0.82, 0.98, 1.05, 1.25, 1.29 | 0.87, 0.82, 0.74, 0.58, 0.44, 0.30 |
| lower parasol gain | 1, 0.8, 0.65, 0.5, 0.35 | 0.73, 0.83, 0.98, 1.05, 1.13 | 0.87, 0.82, 0.67, 0.45, 0.24 |

1. **More internal noise looks like lower coherence, qualitatively.** Both
   mainly lower the ceiling with a modest shift to faster speeds, and both keep
   the drop at 20 deg/s. At a matched ceiling, lower coherence shifts the
   threshold somewhat further (ceiling ≈ 0.81: coherence 0.75 at 1.09 deg/s,
   noise SD 0.06 at 0.82), and costs relatively more at slow-to-middle speeds.
   With 40 trials per point this difference is suggestive, not established.
2. **A lower gain and more noise are interchangeable at matched
   signal-to-noise ratio.** Mean absolute difference in proportion correct over
   the 8 speeds: gain 0.8 vs SD 0.06, 0.009 (largest 0.025); gain 0.65 vs SD
   0.077 (interpolated), 0.017 (0.042); gain 0.5 vs SD 0.10, 0.013 (0.075). The
   binomial standard error of one point is up to 0.079. Their fitted paths
   separate somewhat at large lesions, but the fits are loose where ceilings
   are low; the raw curves agree.
3. **A parasol-gain loss lowers performance at every speed, mostly by lowering
   the ceiling.** Above about 1 deg/s, where the healthy model is well above
   chance, the lesioned/healthy chance-corrected ratio rises with speed,
   qualitatively like Raz's patients. Below that the healthy model is near
   chance and the ratio — including the upturn at slow speeds in the step-4
   figure — is not meaningful. The step-4 script's equivalent-coherence table
   used capped-lapse fits and should not be relied on.
4. **The true letter's matched-filter score falls and grows more variable as
   the gain drops** (5 deg/s: mean 0.87 → 0.34, SD 0.035 → 0.16). This score is
   a correlation with the expected map, not the raw MT response, so it cannot
   show whether normalization holds up the mean response.

### Why lower coherence lowers the ceiling: headroom (2026-09-12)

JW's question: is the model's narrow range of speeds, from threshold to best
performance, what makes lower coherence show up as a lower ceiling rather than a
higher threshold? The step-3 numbers say yes. Fitting log d′ (matched filter,
true letter) over the rising part of the curves, 0.3–2.5 deg/s:

- **d′ ≈ coherence^1.1 × speed^1.06**, within about 12% (residual SD 0.17 in
  log2 units). Speed and coherence act on d′ separately, so on this stretch
  lowering coherence is the same as lowering speed. At fixed d′ the threshold
  moves as **coherence^−1.05**, close to the controls (mean b = −1.24 over the
  units in SUMMARY.md, range −0.92 to −1.65; median −1.41 for the 10
  current-code units' censored fits).
- **But d′ peaks at 5 deg/s** and falls after it. At noise SD 0.05, full
  coherence reaches its ceiling only at that peak; the noise level was chosen to
  make the *best* condition about 95% correct, and the best condition is at the
  peak. So there is no headroom: a lower-coherence curve reaches the peak before
  it gets high enough, and its ceiling drops.
- The noise-level run is separable in the same way: **d′ ∝ (noise SD)^−1.88 ×
  speed^1.0**.

**What would widen the range.** Not more MT units at higher speeds: the 6
px/frame tier already exists and peaks at about 18 deg/s, limited by V1 (§4.3 of
`MODEL_AND_LESIONS.md`). Not more V1 neurons at the same scale: the 28 V1 neurons
are exactly a 28-dimensional basis (`rank(shQwts(pars.v1PopulationDirections))`
= 28), so a new direction at this scale is a mix of the same filters. The limit
is the single spatial scale (peak 0.21 cycles/pixel, about 2 cycles/deg) with the
50 Hz frame rate capping temporal frequency at 25 Hz: about 2 px/frame (10 deg/s)
is the fastest well-represented speed. Faster channels need a coarser spatial
scale with the same temporal filters. The existing pyramid (`pars.nScales`,
`shBlurDn3`) shrinks time along with space, so each of its scales prefers the
same speed; it would need a space-only level, a check of the RGC-to-V1 weights at
that scale, and a decoder that combines scales. That only helps if the letter
signal keeps rising at faster speeds; coarse scales see a blurrier letter.

**The cheaper test: less internal noise.** Lowering the noise raises d′
everywhere, so full coherence reaches its ceiling at slower speeds and leaves
headroom. Extrapolating the noise exponent, at SD 0.02 full coherence should
reach about 0.88 correct near 0.7 deg/s and coherence 0.25 the same near 5 deg/s:
mostly a shift along speed. `explore/formFromMotionLowNoise.m` reruns step 3 at
SD 0.03 and 0.02 with the same seeds and filters (2,560 runs, sent to the
desktop). It drops the "easiest condition about 95%" rule for these runs.

### Lower internal noise: results (2026-09-13, desktop)

Ran from commit 4011534 (38 minutes). Free-ceiling fits per coherence (speeds up
to 10 deg/s), and the joint fit with the controls' rule (lapse at most 0.06):

| RGC noise SD | ceilings, c = 1 / 0.75 / 0.5 / 0.25 | thresholds (model deg/s) | joint b |
|---|---|---|---|
| 0.05 (step 3) | 0.87 / 0.81 / 0.61 / 0.35 | 0.73 / 1.09 / 1.25 / 1.25 | −1.88 |
| 0.03 | 0.98 / 0.95 / 0.83 / 0.56 | 0.49 / 0.63 / 0.82 / 1.21 | −1.71 |
| 0.02 | 0.99 / 0.93 / 0.91 / 0.74 | 0.37 / 0.44 / 0.63 / 1.09 | −1.27 |
| controls (10 current-code units, censored fits) | | | median −1.41, range −1.96 to −1.13 |

1. **Headroom helps, as predicted, down to coherence 0.5.** At SD 0.02 the
   ceilings for coherence 1–0.5 are 0.91–0.99, the thresholds spread along
   speed, and the joint b (−1.27) is inside the controls' range.
2. **Coherence 0.25 stays capped (ceiling 0.74).** The extrapolation failed
   there because lowering internal noise raises d′ much less at low coherence:
   at 5 deg/s, d′ rose 5.1× at coherence 1 (25.5 → 130) but only 2.3× at
   coherence 0.25 (3.2 → 7.3). At low coherence the limiting noise is the dots'
   own randomness, which internal noise does not touch. The earlier noise-free
   check agrees: at no internal noise, coherence 0.25 at 5 deg/s was 0.70
   correct (20 trials).
3. **The speed–coherence trade-off on the rising limb does not depend on the
   noise.** The fit of §"headroom" gives an implied exponent of −1.05, −1.06 and
   −1.07 at SD 0.05, 0.03 and 0.02, although both exponents grow (coherence 1.12
   → 1.45, speed 1.06 → 1.35) as the dots' noise takes a larger share.
4. **The drop at 20 deg/s remains** at every noise level, as expected.

So for the lowest coherence the ceiling is set by how much letter signal the dots
carry within the model's speed window. Only channels that keep responding at
faster speeds (a coarser spatial scale, §"headroom") could raise it. With 40
trials per point a proportion correct has a standard error up to 0.08, and the
single-coherence fit at 0.25 is loose.

### The booth stimulus (2026-09-13)

If the model cannot reach ceiling without internal noise, it cannot match the
controls. Before concluding that, the stimulus should match the experiment. The
earlier trials differed in trial length (1 s against 4 s), field (10 × 10° against
12.7 × 9.5°), and dot rendering: 0.4-px dots were drawn as area straight into
0.1° pixels, which sums overlapping dots where the booth draws an overlap once.

JW's point: a person in the booth sees the individual 2.4-arcmin dots, so human
RGCs resolve them. A foveal midget cell's centre is about one cone (~1 arcmin),
and parasol centres are several times larger. The model's midget centre σ is
0.08° (about 5 arcmin, already flagged in `MODEL_AND_LESIONS.md` as 2–4× too
large), on 0.1° pixels, so the model cannot resolve the dots. That is a limit of
the model, left for later (open checks). The run below keeps the model as it is
and matches the stimulus.

What was built:

- `stim/boothDisplay.m`: the booth's parameters from the experiment code
  (Parameters.m, setupDisplay.m, runSingleTrial.m): 1280 × 960 px at 100.66
  px/deg, 85 frames/s, 4-s trials, white 4-px anti-aliased dots on grey, 50%
  coverage per population (48,892 dots each), 100-ms lifetime, 282-px Sloan
  letter (168 arcmin).
- `stim/mkBoothLetterMovie.m`: draws every booth frame by runSingleTrial.m's
  rules (staggered lifetimes and replotting, noise dots with their own fixed
  headings, letter or background membership by rounded position), with
  anti-aliased disks resolved to 1/16 px and overlaps blended as Psychtoolbox
  blends them. Each frame is averaged into 10 × 10 blocks (one model pixel,
  0.0993°), and the frames shown during each 20-ms model frame are averaged in
  time. A trial is 96 × 128 model pixels × 200 frames; the MT output is 60 × 92 ×
  192.
- Checked: the letter is 283 booth px tall. At 1 model px/frame, frame-to-frame
  correlation peaks at +1 px inside the letter (0.80) and at −1 px in the
  background (0.80).
- `shLetterTemplates(..., BoothDisplay=booth)` draws the letters at booth
  resolution and averages them into model pixels (majority rule), and
  `shRunLetterTrials` draws booth trials whenever its templates were built this
  way. The earlier path is unchanged.
- Cost on the laptop: 7.7 s to draw a trial and 13.7 s for the model (5.9× a 1-s
  trial), with a peak of 4.4 GB per MATLAB process.

The run is `explore/formFromMotionBooth.m`: no internal noise, the step-3 grid (8
speeds × 4 coherences × 40 trials) with the booth stimulus, and the same grid
without noise on the step-3 stimulus for comparison.
`explore/runFormFromMotionBooth.sh` runs it on the desktop as one job for the
templates and matched filters, then five parallel MATLAB processes (one per
coherence, plus the comparison), then the analysis.

For this run the departures table's rows on dot size, overlap, trial length and
field no longer apply. What remains: the frame rate (the 85-Hz frames are
averaged into 50 frames/s), the 0.7% difference in pixel size, and the model's
own receptive fields.

### The booth stimulus without internal noise: results (2026-09-14, desktop)

Ran from commit 1c3af70 as parallel jobs: each booth coherence took about 91
minutes of computation, the 1-s comparison 60. Matched-filter proportion correct,
no internal noise:

| stimulus, coherence | 0.15 deg/s | 0.3 | 0.6 | 1.25 | 2.5 | 5 | 10 | 20 |
|---|---|---|---|---|---|---|---|---|
| booth, 1 | 0.38 | 0.75 | 0.98 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| booth, 0.75 | 0.30 | 0.60 | 0.93 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| booth, 0.5 | 0.25 | 0.43 | 0.85 | 0.95 | 1.00 | 1.00 | 0.98 | 0.98 |
| booth, 0.25 | 0.13 | 0.23 | 0.48 | 0.75 | 0.93 | 1.00 | 0.95 | 0.93 |
| 1 s, 1 | 0.25 | 0.50 | 0.93 | 0.95 | 0.98 | 0.98 | 1.00 | 0.90 |
| 1 s, 0.75 | 0.30 | 0.43 | 0.70 | 0.88 | 0.93 | 0.93 | 0.98 | 0.85 |
| 1 s, 0.5 | 0.20 | 0.30 | 0.50 | 0.83 | 0.95 | 0.93 | 0.98 | 0.60 |
| 1 s, 0.25 | 0.20 | 0.20 | 0.33 | 0.55 | 0.70 | 0.78 | 0.80 | 0.38 |

1. **With the booth stimulus, every coherence reaches ceiling without internal
   noise.** Coherence 0.25 reaches 1.00 at 5 deg/s (40 of 40; the 95% lower bound
   is about 0.93), and 0.93–0.95 from 2.5 to 20 deg/s. With the earlier stimulus
   it peaks at 0.80. The earlier cap came from the stimulus, not the model's
   architecture, so the model can reach the controls' ceilings.
2. **Lower coherence now moves the curve along speed.** Free-ceiling fits:
   thresholds 0.21, 0.26, 0.34 and 0.72 deg/s, ceilings 1.00, 1.00, 0.99 and
   0.97. The controls' joint fit gives b = −0.99 and σ = 0.31 (the controls'
   current-code units: b median −1.41, range −1.96 to −1.13; σ median 0.27). The
   model's b is just outside the controls' range, on the shallow side; its σ is
   typical.
3. **No drop at 20 deg/s** (0.93–1.00), although d′ still falls above 5 deg/s
   (coherence 1: 591 at 5 deg/s, 276 at 20).
4. **Where the gain comes from, roughly.** At 5 deg/s, d′ rose 1.9× at coherence
   1 (307 → 591) and 4.6× at coherence 0.25 (9.9 → 45.8). A trial 4× longer
   would give about 2× if the dots' noise averaged like independent samples. The
   larger gain at low coherence suggests the booth rendering (overlaps drawn
   once, anti-aliased dots) and the larger field also matter. The run does not
   separate them.

With internal noise added back on the booth stimulus, the premise (lower
coherence acts like more internal noise) and step 4 can now be retested. A
1,280-run booth grid is about 6 hours of computation, about 1.5 hours on the
desktop split into four parallel jobs.

### Open checks

- **Per-condition matched filters.** Do filters built at other speeds or
  coherences decode better than the single set built at coherence 1, 5 deg/s?
- **V1 and MT noise** instead of RGC noise.
- **The static control (Raz's feature 2).** Raz's patients kept 83–91% of normal
  performance on a static, luminance-defined object even when acute. A parasol
  lesion in the model should likewise spare a static read-out (for example from
  V1 or the midget-bearing stream). Not yet built.
- **Stimulus properties** (§4): dot size, density, trial length.
- **MT receptive-field size.** Scale the MT pooling filter so 2σ ≈ 1.5 deg
  (macaque MT at the C's opening) and see how performance and the C/D/O
  confusions change. The model is not foveated, so this is one size at one
  eccentricity, not a foveated MT.
- **Mean response against variability under a gain loss.** Measure the MT
  response amplitude itself (not the matched-filter correlation) with and
  without the lesion, to see whether normalization holds up the mean while
  the variability grows (`NOISE_AND_DEMYELINATION.md` §4.2).
- **Step 4's ratio and equivalent coherence with free-ceiling fits.** The
  script's versions use capped-lapse fits.
- **RGC receptive-field size and pixel size.** A person in the booth sees the
  2.4-arcmin dots; foveal midget centres are about a cone wide (~1 arcmin). The
  model's midget centre σ is 0.08° on 0.1° pixels and cannot resolve them. A
  finer grid with smaller RGC centres would also need V1 filters rescaled to it,
  at a much larger computational cost.
- **Confusions at matched accuracy.** Compare the model's and the controls'
  confusion matrices where both are at similar proportion correct (for the
  model, about 1.25 deg/s at coherence 1).

A bug found on the way, and fixed: `explore/runMotionLetterDemo.m` resized the
letter mask to the MT map instead of cropping it, and scored the V1 map with the
MT-sized mask. See `MODEL_AND_LESIONS.md` §4.6 for the corrected numbers.
