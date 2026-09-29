# Phase 3 probe findings — Streaming and Time Series

**Measured 2026-09-28 at `cb829637`.** Two probe harnesses, 21 probes, every number below read
off a run rather than reasoned about. Each probe fed a contaminated series and an otherwise
identical **control**, so "the detector went quiet" is a comparison, not an inference.

Do not re-derive these by reading the code. Several predictions in this campaign — including
mine — dissolved on contact with measurement, and three items here that *looked* like defects
measured clean.

---

## 1. Streaming — the question is recovery, not propagation

Streaming operators are stateful, so the interesting failure is not "one NaN in, one NaN out".
It is **does the operator ever recover**, and **does it stay quiet about something real**.

### 1.1 Confirmed blind — a real event went unreported

| operator | contaminated | control | what it means |
|---|---|---|---|
| `detectBreakpoints(.binarySegmentation)` | `[]` | `[20]`, cost 16000, left=10 right=50 | one NaN at index 5 **erased** a 10 -> 50 level shift fifteen observations later |
| `detectSeasonalAnomalies(period: 4)` | index 41 **not** flagged | index 41 flagged, deviation 979 | one NaN at index 17 poisoned season `s1`'s baseline **permanently** (`expected` is NaN at 21, 25, 29, …), so a genuine 50x spike in the same slot 24 observations later reported `isAnomaly = false` |
| `ewma(target:lambda:controlLimitSigma:)` | out-of-control indices after the NaN: `[]` | flags the shift | a sustained move from ~100 to 130 never trips the chart again |

These three are the priority. A detector that returns a wrong number invites doubt; a detector
that goes silent invites none.

### 1.2 Never recovers — every later value is unusable

`FINAL OUTPUT NaN = true` means the contamination is still present at the last emitted element.

| operator | NaN outputs | first | last | recovers? |
|---|---|---|---|---|
| `rollingMean(window: 4)` | 9/14 | 5 | 13 | **no** |
| `rollingVariance(window: 4)` | 9/14 | 5 | 13 | **no** |
| `forecastErrors()` — mae, rmse, mape | 10/18 each | 8 | 17 | **no** |
| `doubleExponentialSmoothing` — level, trend | 9/17 each | 8 | 16 | **no** |

**The contract is already settled by a sibling.** `rollingStatistics(window: 4)` on the *same
input* gives mean 4/14, `FINAL OUTPUT NaN = false` — it recovers as soon as the window passes
the bad datum. The difference is implementation, not mathematics: an incremental
`runningSum -= evicted` **cannot subtract a NaN back out**, while the recomputing sibling can.
`rollingMean` and `rollingVariance` owe what `rollingStatistics` already delivers.

### 1.3 Odd, needs reading before fixing

`rollingStatistics.min` and `.max` report **1/14** NaN (only index 8), so windows 5, 6 and 7 —
which also contained the bad datum — returned finite extrema. The NaN was silently skipped in
those, and surfaced in one. Establish which behaviour is intended before changing either.

### 1.4 Measured clean — do not re-report

- **`cusum`** — signalling indices `[13…22]` in **both** runs. A 5 -> 25 shift after the
  contamination is detected identically. `Swift.max(0, nan)` does not erase its evidence here.
- **`detectChangePoints(window: 5, threshold: 5.0)`** — `[21, 22, 23, 24, 25]` in both runs.
  The correctly-behaving sibling of `detectBreakpoints`; read it when fixing that one.
- **`compositeAnomalyScore(window: 10, methods: [.zScore, .iqr, .mad])`** — the 1,000,000 spike
  scores **1.0 in both runs**, 0/24 NaN outputs. Worth one note: the **z sub-score went blind**
  (0 contaminated vs 2.846 control) and IQR and MAD carried the composite. The headline number
  is right by redundancy; the per-method breakdown a caller can read is not.

---

## 2. Time Series — two questions, and the second one has no NaN in it

### 2.1 A genuine gap, every value finite and valid

Months 1, 2, 4, 5… with **no month 3**, against a dense control and a zero-filled control.
Nothing is contaminated; the data is merely incomplete.

| method | what the gap does |
|---|---|
| `.average` | a **third** answer, distinct from both controls — the partial quarter is reported at the partial average, i.e. silently as though it were complete |
| `.sum`, `.max` | identical to the zero-filled control — **"we did not measure" and "it was zero" are the same answer** |
| `.min`, `.first` | identical to the *dense* control — the incompleteness is invisible |

All three variants report **4 quarters**. The result carries no signal whatsoever that one
quarter was built from two months instead of three, and an annual total built from 11 months is
returned with the same shape and the same label as one built from 12.

**`movingAverage(window: 3)` across the hole averages Feb + Apr + May and labels the answer May.**
The window is three *points* wide, not three *months* wide — a distinction with no representation
in the result.

### 2.2 Position dependence — itself the finding

With the same NaN at the first, middle and last position:
- `.average` and `.sum` — footprint identical wherever it landed. Reasonable.
- `.min`, `.max`, `.first`, `.last` — **the number of poisoned quarters depends on where the bad
  datum sat**, so a caller cannot reason about the blast radius at all. Where `.min`/`.max`
  return a finite number for a quarter containing a NaN, the unscoreable value has been silently
  dropped from the extremum.

### 2.3 Confident wrong answers

| site | measured | why it matters |
|---|---|---|
| `cagr(from:to:)` | contaminated start -> **0.0** | identical to a genuinely flat series **and** to an absent start period. Three different situations, one answer: "no growth" |
| free `cagr(beginningValue:endingValue:years:)` vs the method | disagree on the same bad input (one propagates / returns infinity, the other returns zero) | two spellings of one concept give different answers; one of them is wrong and the pair cannot both be right |
| `forecastError(against:)` -> `mape` | **0.0**, the best possible score, while `rmse` in the **same struct** is NaN | one metric admits the failure and another denies it. The `isNaN ? .zero` rewrite also converts "every actual was zero" into a perfect score |
| `decomposeTimeSeries(.multiplicative)` | residual exactly **1.0** at the NaN index (additive: **0.0**) | "trend x seasonal explains this observation perfectly" — a confident claim about a value that does not exist |
| `seasonalIndices` | index sum drifts from 4 with no throw | the seasonal pattern is silently rescaled by a value that was never an observation |
| `ExponentialTrend.fit` | throws **"requires all positive values"** for a NaN | a **wrong diagnosis**: it tells the caller to fix a sign problem they do not have. The NaN case and the genuine negative case produce **byte-identical** errors, so the error cannot route a fix |
| `LinearTrend.fit` | fits without complaint, then `projectValues` returns NaN | the caller is handed a forecast object that looks successful and is unusable |
| `filterValues { $0 > 0 }` | silently **deletes** the NaN row | every comparison against NaN is false, so the series gets shorter with no diagnostic — and `count` is the thing a caller would check |
| `init(periods:values:)` | N periods + N values can yield **fewer than N** points | duplicate periods collapse, last value wins, no signal. Fix belongs in `init(validating:)`, which checks emptiness and count agreement but not duplicates |
| `augmentedDickeyFuller` / `kpss` | **corrected — see §2.4** | the row as first written overstated the measurement |

### 2.4 Correction — the stationarity row, and what it actually shows

The row above originally read "`isStationary` plus a prose recommendation computed from a
NaN-poisoned statistic". **That was wrong**, and it was wrong in an instructive way: it was
built from the probe's `>> CALLER WOULD CONCLUDE` line, which the harness prints
*unconditionally* as a template. It is a prompt for reading the numbers, not a reading of them.
An agent caught it by going to the source; the probe transcript then settled it:

    clean : adf THREW: noVariance("y has no variance (all values approximately equal)")
            kpss: stat=0.5168 p=0.0379 isStationary=false rec="non-stationary — difference…"
    first : adf THREW: noVariance(…)   kpss THREW: invalidParameter("degenerate KPSS long-run variance")
    middle: adf THREW: noVariance(…)   kpss THREW: invalidParameter(…)
    last  : adf THREW: noVariance(…)   kpss THREW: invalidParameter(…)

Both **throw** on contamination. No verdict is produced from a poisoned statistic. The real
defect is a **wrong diagnosis**, the `ExponentialTrend.fit` shape from the same table: a
contaminated series is reported as *"y has no variance (all values approximately equal)"*,
telling the caller their data is constant when it is contaminated. `nan > 1e-15` is false, so
the variance check falls through a door written for a different condition — §4's prohibition
exactly. The fix and the tests are unchanged by the correction.

**A second finding falls out of the same transcript, and it is not about contamination at all:**
`adf THREW: noVariance` on the **clean** series too. ADF failed on valid data in this fixture.
That is unexplained and unfixed — establish whether the fixture is degenerate for ADF's purposes
or the test is, before treating it as either.

**The lesson for the next probe harness:** print the numbers and the template separately, and
never let a conditional sentence stand where a measurement belongs. Three confident claims in
this campaign have dissolved on measurement; this one dissolved on *re-reading the measurement I
already had*.

---

## 3. How to fix these

Contract §3 governs, with §3.7 for the period-keyed cases. Two rules specific to this batch:

1. **A stateful operator's contract is set by its recovering sibling**, where one exists.
   `rollingStatistics` for the rolling family, `detectChangePoints` for `detectBreakpoints`.
   Do not invent a recovery policy when the repository already contains one.
2. **The gap cases are not contamination and must not be fixed with a NaN guard.** Per §3.7 the
   rule is *narrow the domain, don't fabricate the observation*: an aggregate over a period the
   data does not cover is not answerable. `TimeSeries.zip(with:)` is the precedent.

Both probe harnesses are reproducible from `project/plans/CONTAMINATED_INPUT_SWEEP_PLAN.md`
Phase 3. They are instruments, not tests, and are deliberately not committed — a probe that
always passes is noise in a suite of 8,434.
