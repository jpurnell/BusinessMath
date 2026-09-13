# BusinessMath validation, schema, audit and forecasting tests: consolidated review

*September 2026. Covers 19 test files across four concerns: forecasting (10 files — Holt-Winters, ETS, moving averages, baselines, backtesting, intervals, conformance, forecastability, benchmark replication), validation (4 — model validator, validation rules, financial validation, anomaly detection), schema and migration (3), and audit trail (1). Companion to the distribution, simulation, statistics, time-series, Bayes, financial-ratio, scenario-analysis, operational-driver and financial-statement reviews.*

*All reference values recomputed in Python.*

## 1. Summary

`HoltWintersReferenceTests` is the best-reasoned file in the corpus, and it establishes a principle the other reference files in this repository do not state: **when the mathematics determines the answer, the mathematics is a better oracle than another implementation.**

It reached that by rejecting one. statsmodels, given the same data, the same smoothing parameters and the same initial state, disagrees with this recursion by about 0.5% — both self-consistent additive Holt-Winters, differing in how the initial state aligns with the first observation, a point on which the literature carries several conventions. The file's reasoning for rejecting it is exact: asserting against it would report a convention as a defect, and a 0.5% gap looks like a tolerance problem, which is worse than an obvious mismatch.

What it used instead needs no second implementation. Construct a series that additive Holt-Winters *must* reproduce exactly — constant level, linear trend, fixed seasonal, no noise — and every residual must be zero and every forecast must equal the continuation of the generating formula. Nothing is estimated that is not exactly present in the data, so no convention enters.

That found two real defects:

1. **A multiplicative fitted value in an additive model** — `(level + trend) * seasonal` where `+` belongs. Seasonals here are deviations about zero, so a level of 150 and a seasonal of −10 produced 150 × (−10) = −1500 instead of 140. On a noiseless series that fits perfectly, residuals still came back in the hundreds — and those residuals feed the mean squared error behind `predictWithConfidence`, so every interval rested on them.
2. **The forecast ignored where the training series ended**, indexing the seasonal array from zero. Correct only when the training length is a whole number of cycles — true of the type's own documented example and of every case in `HoltWintersTests`. Train on 17 points instead of 16 and the forecast came back phase-shifted, silently.

The second is why the fixture covers every residue of *n* mod *m* rather than one convenient length, and why `fixtureIsWellFormed` asserts at least three residues stay covered. A fixture using only tidy lengths would have agreed with the broken code.

**The rest of the batch is more mixed.** `FinancialValidationTests`' epsilon pair is the other standout — it pins an integer-truncation bug of exactly the family `IntegerTruncatedConstantTests` documents, and pairs the fix with a test proving the widened band still rejects a real imbalance. Against that, the moving-average, baseline and anomaly files check orderings and ranges where closed forms are available, and the audit and schema files lean on field-storage assertions.

The main findings:

1. **Three exactness conditions in Holt-Winters were found by measurement and are documented; nothing equivalent exists for ETS** (§2 item 1).
2. **The moving-average seeding convention is unpinned** (§2 item 2), which is the same class of gap as the day-count and percentile conventions in earlier reviews.
3. **`AnomalyDetectionTests` never pins which outlier rule is in force** (§2 item 3) — z-score, modified z-score and IQR give materially different answers on the same data.
4. **The backtest fold structure is asserted by count, not by content** (§3.2).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Any forecaster, or any recursive numerical model | HoltWintersReferenceTests |
| A regression test for a fixed numeric defect | FinancialValidationTests' epsilon pair |
| Protocol conformance across implementations | ForecasterConformanceTests |
| Published-benchmark replication | BenchmarkReplicationTests |

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **ETS has no exact-recovery oracle** | `HoltWintersReferenceTests` shows the technique and documents where exactness holds (no trend, whole number of cycles) and where convergence must be asserted instead. `ETSFittingTests` and `ETSSeasonalityTests` check that fitted values are finite, that parameters land in [0,1], and that seasonal indices roughly repeat. ETS is the same class of recursion and admits the same oracle: a series in the model's exact span must be reproduced exactly. | Build the ETS equivalent. If ETS shares the seasonal-indexing code path, defect 2 above may be present there too and no current test would find it. |
| 2 | **The moving-average seeding convention is unpinned** | For `[10,20,30,40,50]` with n=3 and α=0.5, an EMA seeded from the first value gives 10, 15, 22.5, 31.25, 40.625; seeded from the first SMA it gives 20, 30, 40 — a different series and a different length. `MovingAverageTests` asserts smoothing behaviour and monotone response, not the seed. | Pin the seed, the output length, and whether the leading window is nil or absent. `MovingAverageReferenceTests` is the natural home. |
| 3 | **`AnomalyDetectionTests` does not pin the outlier rule** | On `[10,12,11,13,12,50,11,12]` the three standard rules disagree sharply: z-score of the outlier is 2.47 (below the usual 3.0 threshold — *not* flagged); modified z-score is 25.6 (flagged decisively); IQR upper fence is 14.125 (flagged). A test asserting "the outlier is detected" passes under two rules and fails under the first. | Pin the rule and its threshold. The choice matters: a z-score rule using the contaminated mean and standard deviation is exactly the case where a single large outlier masks itself. |
| 4 | **`rejectsShortSeries` uses `(any Error).self`** | HoltWintersReferenceTests:334, the loosest error assertion, in an otherwise exemplary file. Same in `GStudyReferenceTests` and `LinearAlgebraReferenceTests`. | Assert the specific case. Files that set the standard elsewhere should not use the weakest form. |
| 5 | **A silent skip in the primary forecast test** | `guard forecast.count == entry.horizon else { continue }` (HoltWintersReferenceTests:167). The preceding `#expect` does report a mismatch, so nothing is lost today — but the shape is the one the silent-skip gate rule targets. | `try #require(forecast.count == entry.horizon)` states it in one line and stops the iteration cleanly. |
| 6 | **Empirical interval coverage is asserted, not measured** | `EmpiricalIntervalsTests` checks that an 80% interval is narrower than a 95% one and that both contain the point forecast. Neither is a coverage claim. The testable property is calibration: over many held-out points, an 80% interval should contain the truth about 80% of the time. | Add a coverage test over a seeded synthetic series, bounded by the binomial standard error at the sample size used. This is the interval analogue of the SE-honesty test recommended for the Monte Carlo engine. |

## 3. Patterns

### 3.1 What HoltWintersReferenceTests does that the others should

Five techniques worth naming, because each generalises:

**It states why it rejected the obvious oracle.** Every other reference file in the corpus explains what it compares against; this one explains what it *declined* to compare against and why. That is the more useful half when a future reader wonders why there is no statsmodels fixture here when there is one everywhere else.

**It found the exactness boundary by measurement rather than assumption.** Exact recovery holds only with no trend and a whole number of cycles, and the file gives the arithmetic for each. At n = 17 with m = 4, phase 0 holds five observations and the rest four, so the mean is pulled off `base` and the first residual comes out at exactly 0.588 — "arithmetic, not noise."

**It says why it did not assert exactness more broadly**: doing so "would have meant asserting something untrue of correct code — which is how a suite acquires tolerances that get quietly loosened later, until they assert nothing." That sentence is the clearest statement of the failure mode this whole review series has been documenting.

**It asserts convergence directly rather than assuming it.** `trendedSeriesConverge` walks n = 24, 48, 96, 200 and requires the error to fall at each step, ending below 1e-3. The header records the measured decay: 1.68 → 0.33 → 0.025 → 6.7e-05 → 0.0. So the long fixture cases rest on a tested claim rather than an assumed one.

**It gives each defect two independent detectors.** `residualsAreAdditive` catches the multiplicative-fitted-value bug by scaling: a 10× series scales additive residuals by 10 and multiplicative ones by 100. That works even on a series not fitted exactly, which the primary test cannot reach. `forecastPhaseIsCorrect` catches the phase bug by requiring four distinct forecasts from four series differing only in length — the broken code returned identical values for all four.

The last point is the one most worth copying. Most regression tests in the corpus have a single detector tuned to the exact case that failed.

### 3.2 Assertions that check structure rather than content

**Backtesting.** `RollingOriginBacktestTests` asserts fold counts, that each training window precedes its test window, and that error metrics are finite and positive. What it does not assert is that a specific fold contains the specific observations it should. With a fixed series and a stated window and step, every fold's index range is determined. One test pinning the first, middle and last fold's boundaries would catch an off-by-one that the count assertions cannot — the same gap `DSCR_EdgeCaseTests` closes for `diff(lag:)` by pinning which period goes missing.

**Baselines.** `BaselineForecasterTests` covers naive, seasonal-naive, mean and drift. Each is a closed form: naive is the last value repeated; seasonal-naive is the last full cycle repeated; drift is `last + h·(last − first)/(n − 1)`. Tests asserting that the forecast is finite and has the right length leave the formula unchecked. Drift in particular has a standard off-by-one in the denominator (n vs n − 1) that only an exact assertion finds.

**Error metrics.** For actuals `[100,110,120,130]` and forecasts `[105,108,125,128]`: MAE 3.5, RMSE 3.8078865529319543, MAPE 3.1308275058275057%, sMAPE 3.086232853942339%, MASE 0.35 against a naive MAE of 10. All exact; all worth pinning, especially MASE, whose denominator convention (in-sample naive MAE, and whether seasonal) varies between references.

**Audit trail.** `AuditTrailTests` largely asserts that entries recorded are entries returned — the field-storage pattern. The properties with content are ordering under concurrent appends, that entries are append-only (no mutation path), and that a timestamp is monotonic within a session. If the trail is meant to be tamper-evident, that is the property to test.

**Schema and migration.** `SchemaMigrationTests` checks that a migration runs and produces the target version. The stronger properties: migrating v1 → v3 directly equals v1 → v2 → v3; a migration is idempotent when reapplied; and an unknown or downgrade version is rejected. `DataSchemaTests` is mostly encode/decode round trips, which is right — one decode-from-literal-JSON test per version pins the wire format, and that is what a refactor breaks silently.

### 3.3 Validation

`ValidationRuleTests` and `ModelValidatorTests` cover rule composition and aggregation well. Three gaps:

- **Warning-versus-error semantics** are asserted once (`result.isValid` stays true with warnings present) and are worth a dedicated test, since that distinction drives whether a model runs.
- **Rule ordering and short-circuiting**: does the validator stop at the first error or collect all? `errors.count > 0` does not say.
- **Message content** is checked with `contains("do not equal")` and `contains("negative")`. Substring matching is fragile against rewording; matching the error case plus its structured fields would survive a message change.

`FinancialValidationTests` is stronger than the other three. Its tolerance-boundary pair — difference exactly at tolerance is valid, slightly above is not — is the right shape, and the epsilon tests pin a real bug with its pre-fix behaviour recorded.

## 4. Coverage gaps

**Forecasting.**
- ETS exact recovery (§2 item 1), and ETS phase handling if it shares the seasonal path.
- Holt-Winters with a multiplicative seasonal, if supported — the additive tests would not detect an error there.
- A forecaster trained on constant data: every seasonal is zero, trend is zero, and the forecast is the constant. A useful degenerate case for all of them.
- Horizon longer than the training series.
- `ForecastabilityTests`: the coefficient-of-variation and entropy measures have published definitions worth pinning at exact values.

**Validation.**
- A balance sheet with a NaN value: does validation report it, or does the comparison silently pass?
- Zero-scale statements, where the relative epsilon term vanishes.
- Empty statements and single-period statements.

**Anomaly detection.**
- Two adjacent outliers (masking).
- An outlier at the series boundary, where a rolling window has less context.
- A series with no outliers, asserting an empty result rather than merely a small one.

## 5. Recommended order of work

1. **Build the ETS exact-recovery oracle** (§2 item 1), and check whether the phase defect exists there too. This is the highest-value item because the technique is proven and the defect class is known.
2. **Pin the anomaly rule and threshold** (§2 item 3). The three standard rules disagree on the file's own data.
3. **Pin the moving-average seed and output length** (§2 item 2).
4. **Add exact assertions to the baselines and error metrics** (§3.2) — closed forms, mechanical to add.
5. **Pin fold boundaries in the backtest** (§3.2).
6. **Add interval calibration** (§2 item 6).
7. **Strengthen the migration properties** — path independence, idempotence, rejection of unknown versions.
8. **Replace substring message matching** with structured-field assertions, and the `(any Error).self` sites with specific cases.

## 6. Gate rules

No new rules. What this batch contributes is a positive pattern worth encoding in the fixture-coverage report proposed earlier: **a reference file should state its oracle's provenance, including oracles it rejected.** `HoltWintersReferenceTests` and `BesselFunctionsTests` (which records that SciPy is wrong at J₂₀₀(3000)) both do this, and in both cases the rejected oracle is the one a later contributor would otherwise reach for first.

Existing rules that apply here: the silent-skip rule (§2 item 5), the `(any Error).self` variant of the error-specificity rule (§2 item 4), the field-storage advisory (audit and schema files), and the string-content advisory (validation message matching).

## Appendix. Reference values

### A.1 Holt-Winters exact recovery

Generating formula `base + slope·i + pattern[i mod 4]` with base 50, slope 2, pattern [6, −2, −8, 4]. Continuation at n = 24, h = 1…4: **104.0, 98.0, 94.0, 108.0**.

Measured convergence of the largest forecast error as the series lengthens (quarterly, trended): 1.68 → 0.33 → 0.025 → 6.7e-05 → 0.0 at n = 24, 48, 96, 200, 400.

Exactness conditions: slope == 0 **and** n mod m == 0. Otherwise residuals decay and only the tail is zero. At n = 17, m = 4, the first residual is exactly 0.588.

### A.2 Moving averages

For `[10, 20, 30, 40, 50]`, window 3:

| Method | Values |
|---|---|
| SMA | 20, 30, 40 |
| WMA (weights 1,2,3) | 23.333333333333332, 33.333333333333336, 43.333333333333336 |
| EMA (α = 0.5, seeded from first value) | 10, 15, 22.5, 31.25, 40.625 |
| EMA (α = 0.5, seeded from first SMA) | 20, 30, 40 |

The last two rows are the convention question in §2 item 2.

### A.3 Error metrics

Actuals `[100, 110, 120, 130]`, forecasts `[105, 108, 125, 128]`:

| Metric | Value |
|---|---|
| MAE | 3.5 |
| RMSE | 3.8078865529319543 |
| MAPE | 3.1308275058275057% |
| sMAPE | 3.086232853942339% |
| Naive in-sample MAE | 10.0 |
| MASE | 0.35 |

### A.4 Anomaly rules

Series `[10, 12, 11, 13, 12, 50, 11, 12]`:

| Rule | Statistic for the value 50 | Flagged at the usual threshold? |
|---|---|---|
| z-score (mean 16.375, sd 13.6166) | 2.469 | **No** (threshold 3.0) |
| Modified z-score (median 12, MAD 1.0) | 25.631 | Yes (threshold 3.5) |
| IQR fence (Q1 11, Q3 12.25, IQR 1.25) | upper fence 14.125 | Yes |

The z-score row is the masking case: one large outlier inflates the standard deviation enough to hide itself.

### A.5 Interval quantiles

| Nominal coverage | Two-sided quantiles |
|---|---|
| 80% | 0.10, 0.90 |
| 90% | 0.05, 0.95 |
| 95% | 0.025, 0.975 |
