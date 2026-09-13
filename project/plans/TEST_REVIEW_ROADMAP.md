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

**Eight reviews, and Justin has more.** The per-domain detail is §4; the reason this file is
organised around §3 instead is that the same six findings account for most of the volume.

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
| L6 | **`Period` arithmetic may add fixed second counts rather than calendar components.** | **OPEN** | Time-series review Q1. If it uses components, this is test coverage only; if anything adds 86,400s, it is a DST defect. No test crosses a DST boundary, so nothing currently distinguishes them. **Must be answered before the calendar work.** |
| L7 | **`Period.startDate`/`endDate` and `FiscalCalendar.fiscalYear(for:)` may read `Calendar.current` internally.** | **OPEN** | Time-series review Q2. If so, the same computation returns different answers per region — a library defect no test-side fix reaches. |
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

**The `?? 0` fix is mechanical and the highest-volume single item in the corpus.** `try #require`
is the replacement, and the same files already use it in places.

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

**Blocked on L6/L7** — if the library reads the ambient calendar internally, a fixed test calendar
does not fix it. The review's proposed `testCalendar` helper in TestSupport is right either way and
also removes ~200 lines of `DateComponents` boilerplate.

### T5. Convention pins that are owed

Every one of these is a decision, not a bug, and several are the *same* decision reached from
different directions:

| Convention | Reached from | Status |
|---|---|---|
| **Percentile interpolation (R-7)** | statistics (`weightedPercentile`), operational driver (`ProjectionResults`), scenario | **DECIDED R-7** in the statistics review. Now needs applying, plus a delegation test that every percentile path uses one implementation. The reviews count "three or four percentile conventions in the library". |
| Day count for DSO/DIO/DPO | financial ratio | **OPEN** — 90-day quarter or 365-day year. The CCC identity cancels it, so no test can see it. |
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

The ordering principle: **library defects, then unblockers, then bulk.** Bulk work done before an
unblocker has to be redone.

**Wave 1 — decide and unblock.** Nothing large starts until these land.
1. L6/L7 — the two calendar questions. They gate ~93 sites.
2. L3 — seed `runFinancialSimulation`. Gates ~15 tests and all of T3.
3. L1/L2 — `bayes`: contract and genericity. Smallest whole-file win in the corpus.
4. T5 decisions, as a batch. They are cheap to decide and expensive to discover later.

**Wave 2 — the mechanical bulk**, once Wave 1 fixes what it must.
5. T1: 103 `?? 0` → `try #require`.
6. T4: fixed test calendar, 93 sites.
7. Deduplicate the ratio fixture; 20 `guard let` → `try #require`.

**Wave 3 — exactness.**
8. T2 across all domains, starting with the two npvExcel comment errors.
9. The composition identities (driver) and tornado pins (scenario).

**Wave 4 — coverage and hygiene.**
10. T7: 10 disabled tests.
11. T6: error specificity.
12. The per-domain coverage gaps in §4.

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
| Comment arithmetic vs asserted value | 3 found | advisory |
| Subjunctive property in a comment with no assertion after it | 1 | advisory |
| Display-name-vs-body mismatch | several | advisory |

**Known gate bug to fix first:** the nested-`func` scope issue that makes the assertion-reachability
checker miss assertions after a local function, which is why `#expect(true) // TEST-QUALITY:
checker workaround` appears in at least three files. Those markers come out when it is fixed.
