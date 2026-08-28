# Noise implementation — locked decisions, trial API, and results

**Status:** Step 0 locked. Step 1 harness done. Step 2 **Phase A locked**
(2026-08-28): V1 numerator, independent, **σ = 0.05**, N = 50. Coherence × speed
drive map done. **Next:** Phase B (spatial correlation). MT Site-2 is its own
later arm.

This document is the contract for the noise work described in
[`NOISE_AND_DEMYELINATION.md`](NOISE_AND_DEMYELINATION.md) §6 and [`TODO.md`](TODO.md) §3.
Stimulus and lesion defaults live in [`pars/motionLetterPars.m`](../pars/motionLetterPars.m)
and [`pars/lesionPars.m`](../pars/lesionPars.m).

---

## 1. Step 0 — locked decisions

These are **defaults plus falsifiers**, not final biology. Change them only when a
benchmark test fails or new data force it — and update this file when you do.

### 1.1 Noise variance: fixed at Site 2 first

| Choice | **Fixed variance** (additive on `N` before normalization division) |
|--------|---------------------------------------------------------------------|
| **Not first** | Poisson / proportional-to-response (reserved for Site 1 RGC work) |

**Why.** Step 2 targets Site 2 — local cortical noise entering the normalization
pool (`shModelV1Normalization_Tuned.m`, `shModelMtNormalization_Tuned.m`). The JW
mechanism (NOISE §4.2): lesion lowers drive → effective gain rises → **the same
noise amplitude is multiplied more**. Fixed input noise is the correct first model
for circuit noise that does not shrink when the lesion shrinks the signal.

**Evidence already in repo.** `explore/compensationIndex.m` / report §4.8: at
1–2 deg/s MT drive is weakest and compensation index **C ≈ 0.89** (gain headroom
largest). Speeds here use the current anchor (`shModelUnits`: 1 deg/s = 0.2 px/frame).

**Reserved for later.** Site 1 (RGC channels): implement **proportional** variance
when adding RGC noise — spike-count analogy (NOISE §4.1).

**Parameter (Step 2).** `pars.noise.site2.mode = 'fixed'`, `pars.noise.site2.sigma`
(**0.05**, locked 2026-08-28 after a 0.03 / 0.05 / 0.08 sweep). Independent,
V1 numerator only.

**Falsifier.** If lesion + noise at 1 deg/s does **not** raise trial SD while mean
d′ and tuning stay near healthy, check injection site and σ before revisiting fixed
vs proportional.

---

### 1.2 Spatial correlation: independent first, correlated before patchy claims

| Phase | Correlation | Purpose |
|-------|-------------|---------|
| **A (first code)** | Independent at each location | Debug; verify sign of predictions |
| **B (before manuscript)** | Gaussian, σ_corr ≈ normalization pool width | Survival check on conclusions |

**Why.** Independent noise is easy and **wrong** for cortex (NOISE §6), but Phase A
only needs: *lesion + noise → d′ down, trial SD up, mean tuning still flat*.

Phase B is **required** before interpreting **uniform vs patchy amplitude** (NOISE
§5.1): those lesions should **diverge** only with Site-2 noise and spatial
structure in the damage relative to pool width.

**σ_corr starting guess.** Order of V1/MT normalization blur (~few px; see
`pars.v1Blur` / pool filters in `shPars.m`). Exact value tuned in Phase B.

**Falsifier.** If Phase A works but Phase B reverses the lesion ordering, correlation
length is doing real work — do not publish Phase A numbers as final.

---

### 1.3 Primary observables (every noise/lesion run)

Report **all three**; mean-only read-outs repeat the §4.7 blind spot.

| Metric | Definition | Role |
|--------|------------|------|
| **d′** | Letter vs background on time-averaged MT opponent map (`motionLetterMetrics.m`) | Deficit (b); same as report §4.6 |
| **SD(d′)** | Std of d′ across trials | Trial-to-trial discriminability |
| **SD(center opponent)** | Std of scalar `mean(mtOpp(mask))` across trials | Variability the normalization story predicts |

**Also report (diagnostic, not primary):**

- **Mean d′**, **mean center opponent** — show “mean looks fine” while SD/d′ worsen.
- **Mean MT opponent map** (optional) — visual check only; maps can look noisy at low speed while d′ ≈ 1.3 (report §4.6).

**Spatial vs trial variance.** Current d′ uses **spatial** variance inside vs outside
the letter on **one** trial. Step 1 adds **trial-to-trial** variance (new noise draw
each repeat, **same dot movie**).

**Falsifier.** If SD(d′) does not move under lesion + noise while mean d′ does, the
scalar read-out may be too coarse — add SD of full-map norm or letter-minus-bg
difference of spatial means.

---

### 1.4 Benchmark condition (unit test for noise branch)

Every new noise feature must pass this before expanding the matrix.

| Field | Value |
|-------|-------|
| Stimulus | `motionLetterPars` defaults overridden: **`speedDegS = 1`** (0.2 px/frame), letter **`C`**, `mtMix = true` |
| Model | `shPars('lagged')` via `motionLetterModelPars('lagged', true)` |
| Lesion | `lesionApply(pars, 'amplitude_uniform')` — gain 0.5 all classes |
| Noise | Site 2 only, **fixed σ**, independent (Phase A) |
| Trials | **N = 50** |
| Seeds | Dot seed fixed (see §2); noise seed varies per trial |

**Success criteria (deterministic → noisy) — all passed 2026-08-28:**

1. **Healthy, no noise:** MT d′ ≳ +1.0. Measured **+4.510** (letter C, 1 deg/s,
   128², seed 7, lagged + mtMix). High d′ with a small center opponent (0.109)
   means spatial scatter is tiny, not that MT is strongly driven. Script:
   `explore/runMotionLetterDeterministicBaseline.m`.
2. **Lesion, no noise:** d′ **+4.423** (delta **−0.087**). Modest, as
   normalization predicts. Center opponent 0.109 → 0.089 (−18%).
3. **Lesion + noise (σ = 0.05, N = 50):** d′ **3.814 ± 0.083** vs lesion-off
   4.423 and vs healthy+noise **4.388 ± 0.033**. SD(d′) **2.5×** healthy+noise.
   Mean letter map is visibly weaker, not only more variable.

Do **not** overwrite `explore/_figs/site2_phaseA/` (σ = 0.03, N = 20 first look).
The lock lives in `explore/_figs/site2_phaseA_sigma005_n50/`.

**Control arm (optional):** `mtMix = false` — same benchmark, documents stream
contribution; not the biological default.

---

### 1.5 Explicitly deferred (not Step 0 / Step 1)

| Topic | When |
|-------|------|
| Full lesion matrix re-run through mtMix | Step 6 (after harness + Site-2 noise) |
| VEP latency observable | `TODO.md` §2 — parallel track for deficit (a) |
| Letter size in degrees / RF scale | `TODO.md` §5 — blocks quantitative clinical claims |
| Jitter, Bernoulli dropout | Step 5 — not Gaussian approximations |
| Site 1 + Site 3 noise combined | Step 4 — separate first (NOISE §6) |
| Exact σ | **Locked: 0.05** (sweep 0.03 / 0.05 / 0.08). σ_corr still open (Phase B). |

---

## 2. Step 1 — trial-loop API (implementation spec)

Goal: one reusable harness so Step 2 (noise in normalization) only adds a draw
inside `shModel`, not new explore scripts.

### 2.1 New files (planned)

| File | Role |
|------|------|
| [`pars/noisePars.m`](../pars/noisePars.m) | Noise defaults (Step 2 fills in; Step 1 stubs `enabled = false`) |
| [`explore/motionLetterTrials.m`](../explore/motionLetterTrials.m) | **Main entry:** N-trial loop + aggregation |
| [`explore/motionLetterTrialMetrics.m`](../explore/motionLetterTrialMetrics.m) | One trial: extend `motionLetterMetrics` with scalars |
| [`explore/motionLetterSummarizeTrials.m`](../explore/motionLetterSummarizeTrials.m) | Aggregate `trials(1:N)` → summary struct |

Step 1 can ship **`motionLetterTrials.m`** with summarize inlined; split when Step 2
adds noise branches.

---

### 2.2 Seed contract

Three separate RNG streams — **never** conflate them.

```
DOT_SEED      = cfg.seed from motionLetterPars
                → mkMotionLetter(..., 'seed', DOT_SEED) once per condition
                → identical dot movie for all trials and lesion comparisons

NOISE_SEED0   = cfg.noiseSeed (default 9000 in noisePars; independent of dot seed)
                → trial tr: rng(NOISE_SEED0 + tr) before shModel
                → Step 1: no-op until noise enabled; API still increments

LESION_SEED   = lesionPars stochastic seeds (amplitude_random, delay_random, …)
                → set inside lesionApply; not per-trial unless lesion is trial-random
```

**Comparison rule.** When comparing healthy vs lesioned vs lesioned+noise:

- **Same** `stim`, `stimInfo` (one `mkMotionLetter` with `DOT_SEED`).
- **Same** `NOISE_SEED0` and trial count (paired noise draws across conditions only
  if explicitly designing a paired test — default is **independent** draws per
  condition, same seed *sequence* starting at `NOISE_SEED0`).

Pattern copied from `explore/compareLesionsToBaseline.m` (dot seed 42, identical
dots across conditions) and `explore/compensationIndex.m` (dot seed 4242 across
gains).

---

### 2.3 Function signatures

#### `cfg = noisePars(varargin)`

Defaults block (Step 1 — noise off):

```matlab
cfg.enabled = false;
cfg.site2.enabled = false;
cfg.site2.mode = 'fixed';       % locked Step 0
cfg.site2.sigma = 0.05;         % locked 2026-08-28 after σ sweep
cfg.spatialCorrelation = 'none'; % 'none' | 'gaussian' (Phase B — not implemented)
cfg.spatialCorrSigmaPx = 3;     % Phase B
cfg.noiseSeed = 9000;
cfg.nTrials = 50;
```

Overrides: `noisePars('nTrials', 100, 'site2.sigma', 0.05)`.

---

#### `[stim, stimInfo] = motionLetterMakeStim(cfg)` *(optional helper)*

Thin wrapper if not already built:

```matlab
[~, ~, stimSz, stimArgs] = motionLetterPars(...);  % or accept pre-built cfg
rng(cfg.seed);
[stim, stimInfo] = mkMotionLetter(stimSz, cfg.letter, stimArgs{:});
```

Scripts may inline this; the trial loop accepts pre-built `stim`.

---

#### `m = motionLetterTrialMetrics(popMt, indMt, popV1, indV1, pars, stimInfo)`

Wraps `motionLetterMetrics` and adds scalars for trial SD:

```matlab
m = motionLetterMetrics(...);   % existing fields: dMt, dV1, mtOpp, mask, ...
m.centerOppMt = mean(m.mtOpp(m.mask));           % letter-region mean opponent
m.centerOppBg = mean(m.mtOpp(~m.mask));          % background mean (diagnostic)
m.letterMinusBg = m.centerOppMt - m.centerOppBg; % redundant with d′ numerator
```

V1 fields mirrored if `popV1` provided.

---

#### `R = motionLetterTrials(stim, stimInfo, pars, cfgMl, cfgNoise)`

**Primary Step 1 API.**

| Arg | Type | Meaning |
|-----|------|---------|
| `stim` | `[Y×X×T]` | Fixed movie (built once outside) |
| `stimInfo` | struct | From `mkMotionLetter` |
| `pars` | struct | Model (+ lesion already applied) |
| `cfgMl` | struct | From `motionLetterPars` (needs `.seed`, `.letter`, …) |
| `cfgNoise` | struct | From `noisePars` (`.nTrials`, `.noiseSeed`, …) |

**Loop (pseudocode):**

```matlab
nT = cfgNoise.nTrials;
trials = repmat(struct(), nT, 1);
for tr = 1:nT
    rng(cfgNoise.noiseSeed + tr);   % Step 2: noise draw uses this state
    [popMt, indMt] = shModel(stim, pars, 'mtPattern');
    [popV1, indV1] = shModel(stim, pars, 'v1Complex');
    trials(tr) = motionLetterTrialMetrics(popMt, indMt, popV1, indV1, pars, stimInfo);
end
R = motionLetterSummarizeTrials(trials, cfgMl, cfgNoise, pars);
```

**`R` summary fields:**

```matlab
R.nTrials
R.conditionLabel    % char, optional, set by caller
R.dMt_mean, R.dMt_std
R.dV1_mean, R.dV1_std
R.centerOppMt_mean, R.centerOppMt_std
R.trials            % 1×N struct array (full per-trial metrics)
R.cfgMl, R.cfgNoise % copies for reproducibility
R.mtNote            % from trials(1) — opponent pair description
```

---

#### `S = motionLetterSummarizeTrials(trials, cfgMl, cfgNoise, pars)`

Pure aggregation (no `shModel`):

```matlab
S.dMt_mean = mean([trials.dMt]);
S.dMt_std  = std([trials.dMt], 0);
% ... same for dV1, centerOppMt ...
S.trials = trials;
```

---

#### `R = motionLetterBenchmarkTrials(varargin)` *(optional convenience)*

Runs the §1.4 benchmark (healthy, lesion, lesion+noise when Step 2 ready):

```matlab
[cfgMl, parsH, stimSz, stimArgs] = motionLetterPars('speedDegS', 1, varargin{:});
cfgNoise = noisePars();
rng(cfgMl.seed);
[stim, info] = mkMotionLetter(stimSz, cfgMl.letter, stimArgs{:});
parsL = lesionApply(parsH, 'amplitude_uniform');
R = struct();
R.healthy = motionLetterTrials(stim, info, parsH, cfgMl, cfgNoise);
R.lesion  = motionLetterTrials(stim, info, parsL, cfgMl, cfgNoise);
% R.lesionNoise = ... after Step 2
```

---

### 2.4 Step 1 deliverable checklist

- [x] `noisePars.m` — defaults, noise **disabled**
- [x] `motionLetterTrialMetrics.m` — scalar fields added
- [x] `motionLetterTrials.m` — loop + seed discipline (`runV1` optional, default off)
- [x] `motionLetterSummarizeTrials.m` — aggregation
- [x] `explore/runMotionLetterDeterministicBaseline.m` — **2 full-field MT
      forwards** (healthy + gain-0.5), same movie; run this before Step 2
- [x] `explore/runMotionLetterTrialsDemo.m` — small-field smoke test @ 1 deg/s;
      confirms **deterministic** N trials match single-trial d′ when noise is off
- [ ] Wire optional call from `runMotionLetterLesionPhase2.m` behind a flag
      (`RUN_TRIALS = false` default) — not required for Step 1 completion

**Step 1 done when:** demo shows `std(dMt) ≈ 0` with noise off; API ready for
Step 2 to hook `rng(noiseSeed+tr)` into Site-2 draw without changing explore scripts.

---

### 2.5 Step 2 hook — implemented (V1 only)

`shApplySite2Noise` adds `sigma * randn(size(N))` to the V1 numerator (`nume`)
in `shModelV1Normalization_Tuned.m` **before** the division. Gated on
`pars.noise.enabled` and `pars.noise.site2.enabled` (both false by default, so
existing tests are unchanged; `tests/runAllTests.m` still 12/12). MT
normalization is **not** noised yet — that is a later, separate arm.

`shSite2LastND` records mean `N` and `D` on noisy trials. Phase B spatial
correlation still errors if requested.

Scripts:

- `explore/runMotionLetterSite2PhaseA.m` — locked σ = 0.05, N = 50
- `explore/runMotionLetterSite2SigmaSweep.m` — already run (0.03 / 0.05 / 0.08)

---

## 3. Results recorded 2026-08-28

Geometry unless noted: letter **C**, **1 deg/s** (0.2 px/frame), lagged + `mtMix`,
output **128×128×120**, **dot seed 7**, **noise seed 9000**, `amplitude_uniform`
gain **0.5**. Units: `shModelUnits` (10 px/deg, 50 fps).

### 3.1 Infra (not a science step)

Central `pars/motionLetterPars.m` and `pars/lesionPars.m` / `lesionApply.m` so
scripts stop duplicating defaults. `Kristin` merged `origin/main` including the
2026-08-27 unit re-anchor.

### 3.2 Coherence × speed drive map (TODO §1 step 1)

Script: `explore/compensationIndex.m`. Output:
`explore/_figs/compensationIndex_speedCoherence/`.

Grid: 7 speeds × 6 coherences × 5 gains, both presets. **Why:** if C is a function
of unlesioned drive rather than of speed, JW's operating-point account wins
(NOISE §5.5).

| Preset | R²(C ~ log10 drive) | R²(+ log speed) | C (drive below 0.25) | C (drive above 0.75) |
|--------|---------------------|-----------------|----------------------|----------------------|
| derivative | 0.966 | 0.981 | 0.91 | 0.68 |
| laggedMagno | **0.984** | 0.984 | 0.86 | 0.65 |

JW check (speed ≥ 5 deg/s, coherence ≤ 0.25): 9 cells, lagged mean drive 0.231,
mean C **0.85**, mean R(0.5)/R(1) **0.90**. Low coherence at high speed behaves
like low speed.

Speed-only slice (coherence = 1) still matches report §4.8 (lagged C = 0.89 at
0.31 deg/s, 0.64 at 3.1 deg/s). k² check with normalization off: slope = 2.000.

**Reading:** the deterministic mean is organized by drive, not by the speed label.
This does not yet speak to trial SD — that needed Site-2.

### 3.3 Step 1 harness

Files: `pars/noisePars.m`, `explore/motionLetterTrials.m` (MT-only by default),
`motionLetterTrialMetrics.m`, `motionLetterSummarizeTrials.m`.

Smoke test (`runMotionLetterTrialsDemo.m`, 48², 3 trials, noise off): **std(d′) =
0**, exact match to a single forward. API ready for Site-2.

### 3.4 Deterministic two-forward baseline

`explore/runMotionLetterDeterministicBaseline.m`. Same geometry as the noise
benchmark. **Why two forwards, not N = 50:** with noise off every trial is
identical.

| | MT d′ | Center opponent |
|--|-------|-----------------|
| Healthy | **+4.5104** | **+0.1090** |
| Lesion (gain 0.5) | **+4.4230** | **+0.0891** |
| Delta | −0.0874 (−2%) | −0.0199 (−18%) |

d′ ≫ +1 because spatial scatter is tiny, not because the letter-region signal is
large (center opponent is only 0.11). Report §4.6's +1.32 was a **different**
stimulus (0.3125 px/frame, 1.6 deg/s). Do not treat +4.51 as a contradiction of
that number.

### 3.5 Site-2 Phase A

Injection: `nume = nume + σ·randn(size(nume))` in
`shModelV1Normalization_Tuned`, before the division. Independent in space.
`tests/runAllTests.m` 12/12 with noise off.

**First look** (σ = 0.03, N = 20): `explore/_figs/site2_phaseA/`. Sign of all
predictions already correct (lesion+noise d′ 4.12 ± 0.045 vs healthy+noise
4.44 ± 0.019). Kept; not the lock.

**σ sweep** (N = 15): `explore/_figs/site2_sigmaSweep/`. **Why sweep before
N = 50:** cheaper than 50 copies at the wrong σ.

| σ | Healthy d′ | Lesion d′ | Gap | SD(d′) h / L | SD ratio |
|---|------------|-----------|-----|----------------|----------|
| 0.03 | 4.44 | 4.11 | −0.33 | 0.018 / 0.048 | 2.73 |
| **0.05** | 4.37 | 3.78 | **−0.59** | 0.026 / 0.076 | **2.91** |
| 0.08 | 4.26 | 3.22 | −1.05 | 0.039 / 0.104 | 2.63 |

All three keep rankSD and rankDrop. **Locked σ = 0.05:** highest lesion/healthy
SD ratio, mean gap almost 2× σ = 0.03, healthy still ~4.37. σ = 0.08 is harsher
than needed (SD ratio falls because healthy variability catches up).

**Locked benchmark** (σ = 0.05, N = 50):
`explore/_figs/site2_phaseA_sigma005_n50/` (25.6 min).

| Condition | Mean d′ | SD(d′) | Center opp mean | Center opp SD |
|-----------|---------|--------|-----------------|---------------|
| Healthy, noise off | 4.510 | 0 | 0.109 | 0 |
| Lesion, noise off | 4.423 | 0 | 0.089 | 0 |
| Healthy + noise | 4.388 | 0.033 | 0.093 | 0.0015 |
| Lesion + noise | **3.814** | **0.083** | **0.052** | **0.0034** |

Mean N / D (healthy+noise vs lesion+noise): **0.115 / 0.117** vs **0.029 / 0.029**
(≈ k² = 0.25). Same σ is a much larger fraction of a smaller signal; raised gain
from smaller D amplifies it after the division.

Figures: `dprime_hist.png` (distributions do not overlap), `mean_maps.png` (mean
C is visibly weaker under lesion+noise at this σ, unlike the milder 0.03 look).

**What this does not mean:** d′ is still ~3.8 — the letter is still easy. Phase A
asked for the **sign** of the JW interaction, not a clinical match. Independent
noise is still wrong for cortex (Phase B).

### 3.6 Next (do not skip ahead)

1. Phase B: spatially correlated Site-2, same σ = 0.05; ranking must survive.
2. N = 50 is already locked; do not re-run it for its own sake.
3. More lesions with noise only after Phase B if the claim is about spatial
   structure of damage.
4. MT Site-2 last, as its own arm (V1 already feeds MT).

---

## 4. Related repo pointers

| Item | Location |
|------|----------|
| Compensation / gain headroom | `explore/compensationIndex.m`, report §4.8 |
| Motion-letter d′ definition | `explore/motionLetterMetrics.m` |
| Seeded lesion vs baseline | `explore/compareLesionsToBaseline.m` |
| Phase 2 lesions | `pars/lesionPars.m`, `pars/lesionCatalog.m` |
| Noise theory | `docs/NOISE_AND_DEMYELINATION.md` |
| Open work order | `docs/TODO.md` §3 |

---

## 5. Change log

| Date | Change |
|------|--------|
| 2026-08-28 | Step 0 locked; Step 1 API sketched |
| 2026-08-28 | Step 2: Site-2 hook; Phase A first look, σ sweep, N=50 lock at σ=0.05 |
| 2026-08-28 | Coherence × speed map; this file records tables |
