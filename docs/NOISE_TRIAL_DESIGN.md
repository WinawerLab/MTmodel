# Noise implementation — locked decisions (Step 0) and trial-loop API (Step 1)

**Status:** Step 0 locked 2026-08-28. Step 1 specified but not implemented.

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
(start ~0.02–0.05 in units of rectified `N`; tune against benchmark).

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

**Success criteria (deterministic → noisy):**

1. **Healthy, no noise:** MT d′ ≳ +1.0 (report: ~+1.3 at 1 deg/s).
2. **Lesion, no noise:** d′ may drop modestly; tuning curves still near flat (§4.7.2).
3. **Lesion + noise:** d′ **drops further** vs (2); **SD(d′)** and **SD(center opponent)**
   **rise** vs healthy; mean opponent map still relatively flat vs lesion-only.

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
| Exact σ, σ_corr | Tuned against benchmark, not philosophical choices |

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
cfg.site2.sigma = 0.03;         % tune in Step 2
cfg.spatialCorrelation = 'none'; % 'none' | 'gaussian' (Phase B)
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
- [x] `explore/runMotionLetterTrialsDemo.m` — small-field smoke test @ 1 deg/s;
      confirms **deterministic** N trials match single-trial d′ when noise is off
- [ ] Wire optional call from `runMotionLetterLesionPhase2.m` behind a flag
      (`RUN_TRIALS = false` default) — not required for Step 1 completion

**Step 1 done when:** demo shows `std(dMt) ≈ 0` with noise off; API ready for
Step 2 to hook `rng(noiseSeed+tr)` into Site-2 draw without changing explore scripts.

---

### 2.5 Step 2 hook (for implementer — not Step 1)

In `shModelV1Normalization_Tuned.m` (and MT analogue if needed):

```matlab
% After rectified N computed, before division:
if isfield(pars, 'noise') && pars.noise.site2.enabled
    N = N + localDrawSite2Noise(size(N), pars.noise.site2, rngState);
end
```

`localDrawSite2Noise`: if `mode=='fixed'`, `sigma * randn(size(N))`; Phase B adds
spatial smoothing when `spatialCorrelation=='gaussian'`.

Instrument **`D`** and **`N`** (report §4.8) in the same edit.

---

## 3. Related repo pointers

| Item | Location |
|------|----------|
| Compensation / gain headroom | `explore/compensationIndex.m`, report §4.8 |
| Motion-letter d′ definition | `explore/motionLetterMetrics.m` |
| Seeded lesion vs baseline | `explore/compareLesionsToBaseline.m` |
| Phase 2 lesions | `pars/lesionPars.m`, `pars/lesionCatalog.m` |
| Noise theory | `docs/NOISE_AND_DEMYELINATION.md` |
| Open work order | `docs/TODO.md` §3 |

---

## 4. Change log

| Date | Change |
|------|--------|
| 2026-08-28 | Step 0 locked; Step 1 API sketched |
| 2026-08-28 | Step 1 harness implemented (`noisePars`, trial loop, smoke-test demo) |
