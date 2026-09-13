# Test review roadmap

**Started 2026-09-13.** A living checklist across every incoming test-suite review. Reviews arrive
faster than they can be worked, and they repeat each other — this is where the repetition becomes a
plan instead of eight separate documents.

**Last updated:** 2026-09-13, after intake of five reviews (operational driver, scenario analysis,
financial ratio, Bayes, time series).

---

## 0. How this works

### The protocol every review goes through

1. **Intake.** Recorded in §1 with its scope and date.
2. **Validation.** Every falsifiable claim checked *against the code*, not against a previous
   review. This is not ceremony: of the three reviews validated before this file existed, all three
   were accurate and all three contained corrections worth keeping, and the simulation review
   escalated a test-quality item into a library bug. The rule that produced that:
   **reviews carry stale claims to each other — check the code.**
3. **Decision.** Open questions answered, or recorded here as owed.
4. **Work.** Phased, in the order §5 sets.

### Status vocabulary

| | |
|---|---|
| **CONFIRMED** | checked against the code and true as stated |
| **CORRECTED** | true in substance, wrong in a detail that changes the fix |
| **RESOLVED** | the review left a branch open; validation settled it |
| **REFUTED** | not true of the current code |
| **NEW** | found during validation, not in any review |
| **OPEN** | needs Justin, or needs a decision before work can start |
| **UNVALIDATED** | received, not yet checked |

### Where the documents live

Incoming reviews land in `project/plans/reviews/`. A review that has been validated moves to
`project/plans/proposals/REVIEW_<domain>_tests.md` with its corrections folded in, matching the
three already there.

---

## 1. Intake log

| Review | Files covered | Received | Validated | Worked |
|---|---|---|---|---|
| Distribution tests | — | earlier | ✅ | ✅ 11 of 11 defects fixed |
| Simulation tests | 14 suites | 2026-09-12 | ✅ 6 corrections, 1 escalation | ✅ Phase 1 complete; Phase 2 partial |
| Statistics tests | — | 2026-09-12 | ✅ 3 corrections, 8 conventions decided | ⬜ not started |
| **Operational driver** | 6 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Scenario analysis** | 7 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Financial ratio** | 6 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Bayes** | 1 file | 2026-09-13 | ✅ | ⬜ |
| **Time series** | 33 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Optimization** | 78 files | 2026-09-13 | 🟡 partial — 4 corrections, all upward | ⬜ |
| **Validation / forecasting** | 19 files | 2026-09-13 | 🟡 partial — 1 refuted, 1 reframed | ⬜ |

**Ten reviews, 182 test files, and Justin has more.** The per-domain detail is §4; the reason this
file is organised around §3 instead is that the same handful of findings account for most of the
volume.

**A note on intake.** The 2026-09-13 second batch listed five documents, three of which
(operational driver, scenario analysis, financial ratio) were byte-identical to copies already
archived. Only optimization and validation/forecasting were new. Worth a `diff` against
`reviews/` before re-validating anything.

---

## 2. Library defects — these come first

A test defect costs coverage. A library defect ships. Everything here is the second kind, or a
question about whether it is.

| # | Defect | Status | Notes |
|---|---|---|---|
| L1 | **`bayes` divides by an unguarded denominator.** `pT = s·p + f·(1−p)`; at `(0, s, 0)` and `(1, 0, f)` it is exactly zero and the result is NaN by accident rather than by contract. | **CONFIRMED** | `Sources/BusinessMath/Bayes/Bayes.swift:30`. No validation of any of the three probabilities either. Same open-contract shape the statistics review decided for the free-function/checked pair. |
| L2 | **`bayes` is `Double`-only.** | **NEW** | Not generic over `T: Real`, against the project's own rule in CLAUDE.md ("Use `<T: Real>` generics for numeric functions"). The review asked whether it was generic; it is not. Fixing L1 is the moment to fix this. |
| L3 | **`runFinancialSimulation` takes no `seed:`.** | **CONFIRMED** | `FinancialSimulation.swift:498`. ~15 tests draw fresh values per run as a result. This is the coverage ceiling for the whole scenario suite, and the same defect the simulation review recorded for `ScenarioAnalysis` and `SensitivityAnalysis` (its Phase 3, breaking). |
| L4 | **`debtToAssets` and `debtToEquity` use different debt definitions.** | **CORRECTED — not a bug** | Real asymmetry: `debtToEquity = interestBearingDebt / totalEquity`, `debtToAssets = totalLiabilities / totalAssets`. But the review's diagnosis is wrong twice: the numerator is **all interest-bearing debt** (accounts with `balanceSheetRole.isDebt`), not long-term debt, so the proposed rename to `longTermDebtToEquity` would be *less* accurate; and `BalanceSheet.swift:354` already documents the choice. It matched the LTD hypothesis only because LTD is the fixture's sole debt account. **Work: document it on `debtToAssets` too, and pin both values.** |
| L5 | **`ConstrainedDriver` clamping distorts the distribution, unmeasured.** | UNVALIDATED | Claimed: Normal(1000,100) clamped to ±1σ has sd ≈ 60.6 and ~31.7% boundary mass. Arithmetic is right; whether the implementation clamps or truncates is unchecked. |
| L6 | **`Period` arithmetic may add fixed second counts.** | **RESOLVED — it does not** | Read the source. `Period.endDate` and every `PeriodArithmetic` operation go through `calendar.date(byAdding:)` and `dateComponents`. No 86,400-second additions anywhere. The feared defect does not exist. DST still moves results, but by the mechanism in L7, not this one. |
| L7 | **`Period`/`FiscalCalendar` read `Calendar.current` internally.** | **RESOLVED — CONFIRMED, and already known in-repo** | `Period.swift:17` and `PeriodArithmetic.swift:56` are both `private let cachedCalendar = Calendar.current`; `FiscalCalendar.swift:154,236` read it directly, as do `TimeSeriesOperations` (3), `TimeSeriesAnalytics` (1), `BondPricing` (2), `CreditSpreadModel` (4), `LeaseAccounting` (1), `DebtInstrument` (1). **~15 executable sites** (the other ~70 matches are doc comments). A module-level global captured once — not a parameter anyone can override, so **no test-side fixed calendar can reach it**. Demonstrated live: a `Period` for 2024-Q1 stores `2024-01-01 05:00:00 +0000`, i.e. midnight in `America/New_York`. |
| L7a | **The fix already exists in the package, unapplied.** | **NEW** | `DayCountConvention.swift:49` defines `gregorianUTC` — Gregorian, fixed to UTC, `internal` so it is already shareable — with the doctrine written out above it, including: *"It is deliberately not named `cachedCalendar`, which is the name `Period` arithmetic uses for a cached `Calendar.current` — the opposite of this one."* and *"This reasoning was written here and applied here, while `Calendar.current` stayed in every other file that walks a schedule of dates … and the coupon grid drifted a day for exactly the reason set out above."* **This is a known, documented, unfixed defect with its own remedy sitting beside it.** |
| L12 | **The only outlier rule the library has is the one that masks.** | **NEW — reframed from the review** | `AnomalyDetection.detect(in:threshold:)` computes a z-score against the series' own mean and standard deviation, and takes the threshold as a parameter. There is no modified z-score and no IQR fence. The review files this as "the test does not pin which rule is in force"; there is no choice to pin — but the consequence is sharper than that. On its own example `[10,12,11,13,12,50,11,12]`, verified: z = **2.4694** (sample sd) or **2.6399** (population), both **below the conventional 3.0**, so the obvious outlier is **not flagged**. Modified z is 25.631 and the IQR fence is 14.125; both flag it decisively. A single large outlier inflates the standard deviation enough to hide itself, and the library offers no alternative. **This is a capability gap, not a test gap.** |
| L11 | **DSO / DIO / DPO are wrong on any non-annual statement.** | **NEW — measured, live defect** | `daysInventoryOutstanding` is `365 / inventoryTurnover`, and `inventoryTurnover` is `COGS / averageInventory` over the **period**, un-annualised. On the quarterly documentation fixture, measured: turnover 4.0 turns *per quarter*, DIO **91.25** days where the answer is 91/4 = **22.75** — **4.01× too large**. DSO returns 73.0 where it should be 18.2. The financial-ratio review presents "90-day quarter or 365-day year" as an open convention; it is neither. It is a dimensional error: an annual day count divided by a quarterly turn rate. **And 91.25 is within a quarter-day of the 91 days in the quarter, so a reader sanity-checking "is DIO about one quarter?" sees agreement.** The fix is `DayCountConvention.days(in: period)`, which already exists and returned the correct 91.0 in the same probe. |
| L8 | **`MonthDay` accepts February 30.** | UNVALIDATED | A 1–31 day range admits impossible dates. Also: what does a February 29 fiscal year-end mean in a non-leap year? Currently undefined. |
| L9 | **`npvExcel` discounts the first element by one period.** | UNVALIDATED (behaviour), **CONFIRMED** (design) | Implementation is `flow / (1+r)^(index+1)` — correct Excel semantics. Passing an array that *begins with the initial outlay* silently misprices. Documentation, not a code change. |
| L10 | **Mixed period types unsupported, recorded only in a commented-out test.** | UNVALIDATED | "Trigger a Strideable issue when Swift's stdlib tries to optimize." A capability recorded in a comment will be rediscovered by a user. |

---

## 3. Cross-cutting threads — where the volume actually is

Six shapes account for most of the findings across all eight reviews. Working them by *shape* rather
than by domain is what turns 900 lines of review into a finite amount of work.

### T1. Assertions that cannot fail — the largest single category

| Shape | Count | Where |
|---|---|---|
| `?? 0` inside an assertion, turning a missing lookup into a pass | **103** (review said 93) | Time Series tests |
| Field-storage tests: assert the initialiser's arguments come back out | ~30 + 5 | Time series (FiscalCalendar, TimeSeries), scenario (FinancialProjection) |
| Finiteness / sign / ordering only | ~45 + ~20 + ~12 | Time series financials, scenario, operational driver percentiles |
| Encoding asserted by `data.count > 0` | 2 | Period, FiscalCalendar |
| Guarded assertions that never execute (`if abs(npv) < 10.0`) | ≥1 | `profitabilityIndexBreakEven` |
| `#expect(true) // TEST-QUALITY: checker workaround` | ≥3 | Ratio, seasonality — **gate scope bug, not a test defect** |
| **`.rounded()` inside a relational operator** | **7** (review said 2) | `StochasticOptimizationTests` 3, `RobustOptimizationTests` 3, `ScenarioOptimizationTests` 1 |
| **Always-true disjunctions on convergence** | **4** (review said 1) | Newton-Raphson, LBFGS, performance ×2 |

**The `?? 0` fix is mechanical and the highest-volume single item in the corpus.** `try #require`
is the replacement, and the same files already use it in places.

**The two optimization rows are the sharpest instances of the category**, because the assertion
looks like a real bound:

- `#expect(weight.rounded() >= 0.0)` — a weight of −0.4 rounds to −0.0 and passes. Any violation
  below 0.5 is invisible. `optimalProduction.rounded() <= 200.0` admits 200.49.
- `RobustOptimizationTests:335` is `weight.rounded() >= -1e-6` — a rounding **and** a tolerance,
  where the rounding makes the tolerance meaningless. Someone reached for precision and the
  `.rounded()` ate it.
- `#expect(result.converged || result.iterations > 50)` passes for an optimizer that ran 51
  iterations and diverged. Two sibling sites use `|| result.iterations == 200`, which passes
  precisely when the optimizer **exhausted its budget without converging** — the worst outcome
  satisfying the assertion. A third uses `|| result.iterations < 20`, passing when it gave up early.

### T2. Bands where an exact value is one division away

Roughly **150 assertions** across the batch. The reviews supply verified reference values for
nearly all of them (financial ratio §3, time series Appendix A, Bayes §3). This is transcription,
not derivation — but it is bulk.

Three sub-cases worth separating:
- **Exact in binary** → `identical`, not a tolerance. (`workingCapital` 850,000; `marketCap`
  50,000,000; `priceToSales` 50.0; `evToSales` 50.5; `inventoryTurnover` 2.0; `npvZeroRate` 200.)
- **Exact rational, not binary-representable** → tight relative bound (~1e-15), e.g. `bayes` = 1/3.
- **Statistical** → derive from the standard error, as `sampleMeanAndStdDev` already does. The
  scenario suite has bounds at 10, 12.6 and **32 standard errors**.

### T3. Unseeded randomness

L3 above is the library half. The test half is ~15 scenario tests plus the driver sampling paths.
**Blocked on L3** — no point tightening bounds that must be re-tuned after seeding.

The gate rule the simulation review proposed (compute transitively which functions reach unseeded
randomness, flag test calls into them) catches all of these; the scenario suite is the second
independent motivation for the transitive form.

### T4. Ambient time and locale

| | Count |
|---|---|
| `Calendar.current` in Time Series tests | **75** (review said 73) |
| `Date()` in Time Series tests | **18** (review said 16) |

**No longer blocked — and the answer changes the work.** L7 is confirmed: the library reads
`Calendar.current` at ~15 executable sites, so **a fixed test calendar cannot fix this**. The
source order is now:

1. Replace `cachedCalendar` with `gregorianUTC` at the ~15 source sites (L7/L7a). The constant and
   the doctrine already exist; this is applying a rule the package already wrote down.
2. *Then* the test-side `testCalendar` helper, which becomes a consistency measure rather than the
   fix, and still removes ~200 lines of `DateComponents` boilerplate.

L6 is resolved in the good direction: the arithmetic is component-based, so there is no
fixed-seconds DST defect. DST reaches these through the ambient **time zone** moving a date across
midnight — the mechanism `DayCountConvention`'s own note describes.

### T5. Convention pins that are owed

Eight decisions (the day count was a ninth until it turned out to be L11, a 4.01× error rather
than a convention). Several are the *same* decision reached from different directions:

| Convention | Reached from | Status |
|---|---|---|
| **Percentile interpolation (R-7)** | statistics (`weightedPercentile`), operational driver (`ProjectionResults`), scenario | **DECIDED R-7** in the statistics review. Now needs applying, plus a delegation test that every percentile path uses one implementation. The reviews count "three or four percentile conventions in the library". |
| ~~Day count for DSO/DIO/DPO~~ | financial ratio | **NOT A CONVENTION — see L11.** Measured as a live 4.01× error. The day count must come from the period, via `DayCountConvention.days(in:)`. No ISDA convention applies: ISDA day-count *fractions* govern interest accrual, not activity ratios. |
| Rounding rule for integer drivers | operational driver | **OPEN** — `.toNearestOrAwayFromZero` vs `.toNearestOrEven`. 1025 users / 50 = 20.5 is reachable, and a headcount that rounds differently in two places is a payroll discrepancy. |
| Gross margin with no COGS: 1.0 or nil | financial ratio | **OPEN** |
| `TimeVaryingDriver` outside its schedule | operational driver | **OPEN** — nil, nearest, extrapolate, or throw |
| P/E when earnings are negative | financial ratio | **OPEN** — conventionally nil/NA, not a negative number |
| Zero denominator in `bayes` | Bayes | **OPEN** — NaN or throw (L1) |
| `profitabilityIndex` with no outlay | time series | **OPEN** — infinity or throw |
| Single-iteration `stdDev`: 0 or NaN | operational driver | **OPEN** — the ddof question |

### T6. Error assertions by type only

~20 in time series, plus `(any Error).self` in `ScenarioRunnerTests:497` — the loosest possible
form, in a file whose sibling tests pin `.invalidDriver` with its error code. The formula-engine
tests are the model: they distinguish parse errors from evaluation errors.

### T7. Disabled tests — bigger than any single review saw

**10 `.disabled` tests corpus-wide. Zero carry a `.bug(...)` trait.** The reviews report 2 (scenario)
and 2 (GPU); the corpus total is 10, across GPU integration, VectorSpace, streaming composition,
operational drivers and the fluent API. Six `withKnownIssue` uses exist, so the vocabulary is
established.

Every one either runs nowhere or documents nothing about what would re-enable it.

**And a second population: 30 commented-out `@Test` declarations corpus-wide**, seven of them in
`VectorSpaceTests` alone — including matrix-vector multiplication, a core operation with no
coverage at all. A commented-out test is worse than a disabled one: it does not appear in any
count, no trait records why, and nothing distinguishes "temporarily broken" from "abandoned".

---

## 4. Per-domain checklists

Shapes covered by §3 are not repeated here; this is what is *specific* to each domain.

### 4.1 Bayes — **validated, ready to work, smallest**

Five tests → eight. The whole file is one 5-line function.

- [ ] **L1/L2 first**: decide NaN-or-throw, make it generic over `T: Real`.
- [ ] `degenerateDenominator` — the four rows (two NaN, two exact).
- [ ] `posteriorOddsIdentity` — **the missing property.** Nothing in the file can detect a
      transposed sensitivity/FPR: `symmetricCase` is *invariant* under the swap (prior 0.5,
      s = 0.8, f = 0.2 gives 0.8 either way). The odds form is asymmetric and catches it.
- [ ] `uninformativeTestReturnsPrior` — `s == f` returns the prior exactly, for any prior.
- [ ] Monotonicity in the prior when `s > f`.
- [ ] Tighten the five existing: 1/3 at ~1e-15, 36/37, 0.018664047151277015, `identical(0.8)`,
      `identical(1.0)`.
- [ ] Rename `perfectTestAccuracy` — it describes a degenerate case its body never reaches.
- [ ] Remove the unused `import Numerics`.

### 4.2 Financial ratio

- [ ] **L4** — document the debt asymmetry on both properties; pin both values.
- [ ] Day-count convention (T5).
- [ ] Gross margin without COGS (T5).
- [ ] **Deduplicate `createTestFinancialStatements`** — defined twice in one file, lines 27 and 577,
      ~115 lines each, about a quarter of the file. **CONFIRMED.** Move to one place with the §3
      value table beside it.
- [ ] Convert **20** `guard let … else { Issue.record(); return }` → `try #require`. **CONFIRMED
      exactly 20.** Removes ~60 lines.
- [ ] Band → exact for ~30 metrics (T2); the review's table is complete.
- [ ] Zero/negative denominators; negative equity; loss-making period.
- [ ] Piotroski components individually (only the 0–9 bound and the alias are tested).
- [ ] `testProfitabilityTrends` is vacuous — both margins are exactly 0.6 by construction, so the
      ratio is exactly 1.0 and any uniformly-wrong implementation passes.

**Keep as models:** `DSCR_EdgeCaseTests` (the 12.0× quarter with no principal payment is the
discriminating one), `testValuationRatiosExactValues`, and the second suite generally.

### 4.3 Operational driver

- [ ] Rounding rule (T5) — smallest, and a correctness property of any headcount driver.
- [ ] **The three composition identities** (review §3) — highest value. The seeding contract already
      makes them cheap, and they catch a composite that re-draws its operands, which every current
      band assertion would pass.
- [ ] **L5** — measure clamping distortion; decide clamp vs truncate.
- [ ] `TimeVaryingDriver` out-of-schedule (T5).
- [ ] Percentile interpolation + delegation test (T5).
- [ ] Degenerate cases: zero-variance driver, single iteration, all-identical values, invalid
      constraints (lower > upper, NaN bounds), empty schedule, nested composites.
- [ ] `AnyDriver` type-erasure identity — the existential-dispatch trap the distribution review
      already found once.
- [ ] Whole-projection reproducibility.

**Keep as model:** `SeededDriverSamplingTests` — it is the foundation the rest can be made exact on.

### 4.4 Scenario analysis

- [ ] **L3 first.** Everything statistical is downstream.
- [ ] Resolve the two `.disabled` tests (T7) — both contain substantial assertions running nowhere.
- [ ] Bounds → standard-error multiples (T2), following `sampleMeanAndStdDev`.
- [ ] **Check whether VaR and the confidence interval are computed independently of the percentiles
      they are compared against.** If not, both tests are tautologies. *This is the same shape as
      the antithetic-SE tautology already fixed in `88af88d7`.*
- [ ] Pin the tornado impacts exactly — the analytic model gives Price 40,000, Cost 24,000,
      Volume 16,000, Tax Rate 0. `tornadoRanksInputsCorrectly` currently accepts
      `topInput == "Volume" || topInput == "Price"` where Price dominates by 2.5×.
- [ ] Replace five field-storage tests in `FinancialProjectionTests` with invariants in the style of
      its own last three.
- [ ] `(any Error).self` → the specific error (T6).
- [ ] Name-based assertions (`model.revenue.name.contains("×")`) → value relationships.
- [ ] `profitUncertainty` — write the CV comparison its comment describes, or delete the comment.
- [ ] Scenario isolation: unaffected accounts identical across scenarios.
- [ ] Two-way sensitivity grid orientation — `results[i][j]` vs its transpose is never pinned.

**Keep as models:** the six driver-name validation tests, especially the `BuilderRan` sentinel that
proves validation happens *before* any projection runs. `taxRateNoImpactOnPreTax`. These are the
best error tests in the corpus.

### 4.6 Optimization — largest by file count, 78 files

The review's central contribution is a **three-way rule for choosing an oracle**, and it is the
clearest statement of the question this whole series has circled:

| The answer is… | Use | Because |
|---|---|---|
| **Verifiable but not unique** (LP vertices, DEA reference sets) | a **certificate** | a fixture imports another implementation's tie-breaking as if it were correctness |
| **Unique and externally published** (Cooper et al.) | a **fixture** | it pins the *scale*, which no self-consistency check can |
| **Determined by the mathematics** (a noiseless series) | **exact recovery** | nothing is estimated that is not already present, so no convention enters |

That is worth lifting out of this review and into the project's testing doctrine — it generalises
past optimization, and the third row is the Holt-Winters technique arrived at independently.

- [ ] **Apply the gradient certificate** to L-BFGS, gradient descent, Newton-Raphson, multi-start.
      Replaces ~40 distance-to-known-minimum assertions with `‖∇f(x*)‖ < tol` — the condition that
      *defines* a minimum, and which extends to problems with no known answer. **Highest value.**
- [ ] Fix the 7 `.rounded()` comparisons and 4 always-true disjunctions (T1).
- [ ] Retire solution-vector assertions in `SimplexSolverTests` for objective values — the
      certificate file argues explicitly that a fixture must not pin a tie-break.
- [ ] Units invariance for SBM and super-efficiency (CCR and BCC have it). Cheapest high-value
      addition in the domain: a scaling error breaks it while leaving every score plausible.
- [ ] KKT for the constrained optimizers — they currently check primal feasibility, one of four.
- [ ] K-means fixed-point conditions; async-vs-sync `identical`; Gomory cut validity.
- [ ] **`memorySizeComparison` never compares.** CONFIRMED: it runs m = 3, 5, 10, 20, `print`s the
      four results, then asserts `val < 1.0` for each. The comparison its name promises is
      discarded. (The review calls it `compareMemorySizes`; the actual name differs.)
- [ ] Restore or delete 7 commented-out tests here, 30 corpus-wide (T7).

**Keep as models:** `LinearProgrammingCertificateTests` and `DEACertificateTests`. Two details
worth copying package-wide: **the oracle must not share code with the subject** (its Gaussian
elimination is written out in the test file, "because an oracle that shared the package's linear
algebra could agree with the simplex through a fault they both inherit"), and **skipping an
inapplicable check is honest where loosening a tolerance is not** (degenerate problems carry
`dualsAreDetermined: false` and are excluded from the finite-difference check only).

### 4.7 Validation, schema, audit and forecasting — 19 files

`HoltWintersReferenceTests` is the model, and its two defects are **already fixed** — the
multiplicative fitted value in an additive model and the zero-indexed seasonal phase, both landed
at `64a7f64b`. The review describes them as context, not as open work.

- [ ] **ETS exact-recovery oracle.** **The review's stated worry is refuted:** it asks whether ETS
      shares the seasonal path and might carry the phase defect too. It shares it completely —
      `ETSFit.model` *is* a `HoltWintersModel`, and both the fit and the parameter search construct
      one — so ETS **inherits the fix** and cannot diverge. **The recommendation survives for a
      different reason:** ETS adds a parameter *search* on top, and whether the search recovers a
      noiseless series exactly is untested.
- [ ] **L12** — the anomaly capability gap, above. Pin the threshold behaviour; decide whether a
      modified-z or IQR rule is wanted.
- [ ] Pin the moving-average seed and output length. For `[10,20,30,40,50]`, α = 0.5: seeded from
      the first value gives 10, 15, 22.5, 31.25, 40.625; seeded from the first SMA gives 20, 30, 40
      — a different series **and a different length**.
- [ ] Exact assertions for baselines and error metrics — all closed forms. MAE 3.5, RMSE
      3.8078865529319543, MAPE 3.1308275058275057%, sMAPE 3.086232853942339%, MASE 0.35. Drift has
      a standard off-by-one in its denominator (n vs n−1) that only an exact assertion finds.
- [ ] Pin backtest fold *boundaries*, not counts.
- [ ] **Interval calibration.** `EmpiricalIntervalsTests` asserts an 80% interval is narrower than
      a 95% one and that both contain the point forecast. Neither is a coverage claim. *This is the
      same shape as the antithetic-SE honesty defect fixed in `88af88d7`* — a reported uncertainty
      nothing measures against realised spread.
- [ ] `(any Error).self` at `HoltWintersReferenceTests:334` and the `guard … else { continue }` at
      :167 — both CONFIRMED, both in the corpus's best file.
- [ ] Migration properties: path independence (v1→v3 equals v1→v2→v3), idempotence, rejection of
      unknown or downgrade versions.

**Worth adopting as doctrine:** the review's §6 observation that **a reference file should state
its oracle's provenance, including oracles it rejected.** `HoltWintersReferenceTests` rejects
statsmodels (0.5% disagreement traced to an initial-state convention, not a defect) and
`BesselFunctionsTests` records that SciPy is wrong at J₂₀₀(3000). In both cases the rejected oracle
is the one a later contributor reaches for first.

### 4.5 Time series — largest, 33 files

- [ ] **The `npvExcel` expectation is wrong. RESOLVED: the test is wrong, not the library.**
      `npvExcel(0.08, [8000, 9200, 10000])` = 23233.246964385507; the test expects 23234.62 and the
      ±2.0 tolerance hides a **1.373** gap. The comment's own second term is the source: it says
      7888.89 where the value is 7887.517146776406. Two sibling comments carry the same error
      (`npvExcelComparison` 1306.00 → 1307.287753568743; `npvExcelMultiYear` 11306.00 →
      11307.287753568744). **Implementation verified correct** — `flow / (1+r)^(index+1)`,
      matching Excel.
- [ ] **L6/L7** — answer both before the calendar work.
- [ ] 103 `?? 0` → `try #require` (T1).
- [ ] Fixed `testCalendar` in TestSupport; convert 93 ambient sites (T4).
- [ ] Rebuild the two decomposition fixtures — neither matches its own stated trend; the
      multiplicative one implies a 40-point jump between years, which is why its tolerance had to be
      relaxed to 1.0. Then assert the *recovered components*, not just reconstruction.
- [ ] Skip-on-NaN loops: assert which indices are NaN and `#require` the iteration count.
- [ ] Closed forms → exact (T2); Appendix A has ~60 values.
- [ ] Coverage: `irr` with multiple sign changes, with none (should throw), all-positive flows;
      `payment` at rate 0 and n 0; `xnpv`/`xirr` unsorted/duplicate dates; `cagr` from zero.
- [ ] Consolidate four overlapping `Period` suites into the semiannual file's shape.

**Keep as models:** the formula engine (names the defect each test guards),
`PeriodSemiannualAndCustomTests`, `AutocorrelationTests` (pins the divisor convention),
`TrendModelConfidenceIntervalTests` (derives its interval from the t distribution).

---

## 5. Sequencing

**Re-prioritised 2026-09-13** after the optimization and validation/forecasting intake. The
previous ordering predated them and had no place for the gradient certificate, L12, the eleven
vacuous optimizer assertions or the thirty commented-out tests.

Two ordering principles, and the second is the one that changed this revision:

1. **Library defects, then unblockers, then bulk.** Bulk work done before an unblocker is redone.
2. **Cheap high-information moves go early, even when they are "only" test changes.** An assertion
   that cannot fail is not merely weak coverage — it is an *unknown*. Converting one costs a line
   and either passes (costing nothing) or turns the suite red on a live defect. That asymmetry beats
   almost anything else per unit of effort, and it is why Wave 0 now contains test edits.

---

### Wave 0 — ships wrong, or tells us cheaply whether it does

**0.1 — L11: DSO / DIO / DPO, 4.01× on any non-annual statement.**
Measured, not argued: DIO returns 91.25 where the answer is 22.75. Route the day count through
`DayCountConvention.days(in: period)`, which already exists and already returns the right 91.0.
Small, contained, correct values in hand.

**0.2 — L7 / L7a: `Calendar.current` at ~15 source sites.**
`gregorianUTC`, the doctrine and the precedent all exist in `DayCountConvention.swift`; this applies
a rule the package wrote down for itself and then did not follow. **Must precede any test-side
calendar work** — a fixed test calendar cannot reach a module-level global.

**0.3 — The eleven assertions that cannot fail in the optimizers.**
Promoted into Wave 0 on principle 2, not on volume. Seven `.rounded()` comparisons and four
always-true convergence disjunctions currently mean **nobody knows whether the stochastic and
robust optimizers respect their own constraints**. `#expect(weight.rounded() >= 0.0)` passes for a
weight of −0.4.

Each is a one-line edit with two possible outcomes, and both are valuable:

| Outcome | What it means |
|---|---|
| Still green | The constraint handling was fine; ~11 unknowns become evidence, for an hour's work |
| Turns red | A live solver defect that has been invisible for the life of these tests |

Do these **before** the gradient certificate: if a constraint is being violated, that changes what
the certificate work is even looking at.

---

### Wave 1 — decisions and unblockers

1. **L3** — seed `runFinancialSimulation` and `ScenarioRunner` sampling. Gates ~15 tests and all of
   T3; every statistical bound downstream must be re-tuned after it, so tightening them first is
   wasted work.
2. **L1 / L2** — `bayes`: zero-denominator contract, and genericity over `T: Real`. The smallest
   whole-file win in the corpus, and fully validated.
3. **The T5 convention batch**, now eight items rather than nine (the day count turned out to be
   L11, not a convention). Cheap to decide, expensive to discover later.
4. **L12** — decide whether the library wants a modified-z or IQR rule at all. Currently its only
   outlier rule is the one that masks. This is a capability question, not a defect fix.

---

### Wave 2 — the structural test work, highest leverage first

5. **The gradient certificate for the multivariate optimizers.** Replaces ~40 distance-to-known-
   minimum assertions with `‖∇f(x*)‖ < tol` — the condition that *defines* a minimum — and extends
   to problems where no exact answer is known, which the current assertions cannot. **The single
   highest-leverage item in the ten reviews.**
6. **DEA units invariance for SBM and super-efficiency.** CCR and BCC have it; a scaling error
   breaks it while leaving every score plausible. Cheapest high-value addition in that domain.
7. **The ETS exact-recovery oracle.** Not for the phase defect — ETS delegates to
   `HoltWintersModel` and inherits that fix — but because ETS adds a parameter *search* whose
   recovery of a noiseless series is untested.
8. **Interval calibration** for `EmpiricalIntervalsTests`. Same shape as the antithetic-SE defect
   fixed in `88af88d7`: a reported uncertainty that nothing measures against realised spread.
9. **The driver composition identities** — the seeding contract already makes them cheap, and they
   catch a composite that re-draws its operands, which no band assertion can.

---

### Wave 3 — the mechanical bulk

10. **T1: 103 `?? 0` → `try #require`.** Highest-volume single item in the corpus.
11. **T4: the fixed test calendar, 93 sites** — *after* 0.2, which is what actually fixes it.
12. Deduplicate the ratio fixture (~115 lines × 2) and convert its 20 `guard let` blocks.

---

### Wave 4 — exactness

13. **T2, ~150 band assertions → exact values.** Start with the two `npvExcel` comment errors,
    which are wrong arithmetic rather than loose bounds.
14. Tornado impacts pinned exactly; baselines and error metrics pinned to their closed forms;
    backtest fold *boundaries* rather than counts.

---

### Wave 5 — hygiene and coverage

15. **T7: 10 `.disabled` tests and 30 commented-out `@Test` declarations.** The commented-out set
    is larger and worse — no count, no trait, no record of why.
16. **T6: error specificity**, starting with the `(any Error).self` sites.
17. The per-domain coverage gaps in §4, and the certificate techniques of §4.6 applied to K-means,
    the constrained optimizers (KKT rather than primal feasibility alone) and the cut generators.

---

### What moved, and why

| Item | Was | Now | Reason |
|---|---|---|---|
| 11 vacuous optimizer assertions | unplaced | **0.3** | one line each; either outcome is information, and one of them is a live defect |
| Gradient certificate | unplaced | **5** | highest leverage in the batch, but needs 0.3 first |
| L12 anomaly masking | unplaced | **4** | a capability decision for Justin, not a fix |
| 30 commented-out tests | unplaced | **15** | real, but nothing depends on them |
| Day-count convention | T5 decision | **0.1** | it was never a convention — it is a 4.01× error |
| Test-side calendar | Wave 2 | **11, after 0.2** | a test calendar cannot reach a module-level global |

---

## 5a. Which standard governs which question

Asked 2026-09-13, and the answer splits in a way that matters.

**IEEE 754** is floating-point arithmetic. It has nothing to say about day counts. It governs a
great deal else in this library — every tolerance, every `identical` claim, the signed zeros in the
optimizer — but not this.

**ISDA** is the right standard for *interest accrual*. The 2006 ISDA Definitions §4.16 define Day
Count Fractions: ACT/365 (Fixed), ACT/360, ACT/ACT (ISDA), 30/360 (Bond Basis), 30E/360, 30E/360
(ISDA), ACT/365L, BUS/252. **The library already implements a subset** —
`DayCountConvention` has ACT/365, ACT/360, ACT/ACT, 30/360 and 30E/360, with the 30E/360 end-of-month
distinction written out correctly, and `gregorianUTC` beneath it for the reason a day count must not
depend on the host.

**ISO 8601** governs date *representation*. Not day counts.

**But DSO/DIO/DPO are not an ISDA question, and answering them with ISDA would be a category
error.** An ISDA day-count fraction answers *"what fraction of a year is this accrual period?"* for
interest. DSO answers *"how many days of sales are sitting in receivables?"* — an activity ratio,
governed by financial-analysis practice rather than by any standards body. The rule there is
dimensional, not conventional: **the day count must match the period of the flow in the
denominator.** A quarterly revenue figure gives a per-quarter turn rate, so the numerator must be
the days in that quarter. Using 365 against a quarterly turn rate is not a defensible alternative
convention; it is L11.

So both answers land in the same place by different routes:

| Question | Standard | Mechanism |
|---|---|---|
| TVM, accrual, coupon schedules | **ISDA**, already implemented | `DayCountConvention` + `gregorianUTC` |
| DSO / DIO / DPO | none — dimensional analysis | `DayCountConvention.days(in: period)` |
| `Period` arithmetic and fiscal mapping | none — but must not read the host | `gregorianUTC`, replacing `Calendar.current` |

The practical upshot is one sentence: **`DayCountConvention` and `gregorianUTC` are the answer to
all three, and both already exist.** The work is application, not design.

---

## 6. Open questions for Justin

Marked **OPEN** above; collected here so none is lost.

1. **The nine convention pins in T5.** Several are genuinely business decisions (day count, P/E on
   losses, headcount rounding) rather than technical ones.
2. **L6/L7** need a look at the `Period`/`FiscalCalendar` source to answer; they are not
   preferences, but they change what the fix is.
3. **Do incoming reviews get validated before or as they are worked?** So far: before, and it has
   paid for itself every time. It is also the slower path.
4. **Where should validated reviews live?** §0 proposes `project/plans/reviews/` for intake and
   `proposals/REVIEW_*.md` for validated, matching the three already there.

---

## 7. Gate rules proposed across the batch

Not yet filed as quality-gate work. Highest-volume first.

| Rule | Volume | Severity proposed |
|---|---|---|
| Nil-coalescing inside an assertion (`?? <literal>` in `#expect`) | 103 | blocking |
| Ambient calendar or clock in a test target | 93 | blocking |
| `.disabled` requires `.bug(…)` | 10 | blocking |
| Transitive unseeded set — functions reaching unseeded randomness | ~15 | blocking |
| Skip-on-NaN in a loop containing the only assertions | ≥3 | blocking |
| Field-storage tests | ~35 | advisory |
| Encoding asserted only by size | 2 | advisory |
| Error asserted by type only, `(any Error)` separately | ~21 | advisory |
| Ordering assertions that are definitional | ~20 | advisory |
| **`.rounded()` inside a relational operator** | **7** | blocking |
| **Always-true disjunction on a convergence flag** | **4** | blocking |
| **Commented-out `@Test` declarations** | **30** | blocking |
| Certificate coverage for solver types | — | advisory |
| Comment arithmetic vs asserted value | 3 found | advisory |
| Subjunctive property in a comment with no assertion after it | 1 | advisory |
| Display-name-vs-body mismatch | several | advisory |

**Known gate bug to fix first:** the nested-`func` scope issue that makes the assertion-reachability
checker miss assertions after a local function, which is why `#expect(true) // TEST-QUALITY:
checker workaround` appears in at least three files. Those markers come out when it is fixed.
