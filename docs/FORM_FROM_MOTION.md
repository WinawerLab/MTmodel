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

Next: step 3, `explore/formFromMotionSpeedCoherence.m`, run on the desktop
from a private git bundle (not pushed: the branch mentions unpublished pilot
data); then step 4, `explore/formFromMotionParasolGain.m`.

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

### Open checks

- **Per-condition matched filters.** Do filters built at other speeds or
  coherences decode better than the single set built at coherence 1, 5 deg/s?
- **V1 and MT noise** instead of RGC noise.
- **The static control (Raz's feature 2).** Raz's patients kept 83–91% of normal
  performance on a static, luminance-defined object even when acute. A parasol
  lesion in the model should likewise spare a static read-out (for example from
  V1 or the midget-bearing stream). Not yet built.
- **Stimulus properties** (§4): dot size, density, trial length.

A bug found on the way, and fixed: `explore/runMotionLetterDemo.m` resized the
letter mask to the MT map instead of cropping it, and scored the V1 map with the
MT-sized mask. See `MODEL_AND_LESIONS.md` §4.6 for the corrected numbers.
