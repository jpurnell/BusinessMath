# Test review roadmap

**Started 2026-09-13.** A living checklist across every incoming test-suite review. Reviews arrive
faster than they can be worked, and they repeat each other — this is where the repetition becomes a
plan instead of twenty-two separate documents.

**Last updated:** 2026-09-13. **Twenty-two reviews, ~370 test files.**

---

## The goal, stated once (2026-09-13)

**A strong 3.0.0 — and the library has to be correct first.** Everything below is ordered against
that, which resolves a question the first four revisions of this file left implicit.

Three consequences, and the third is the one that changed the plan:

1. **Correctness is the gate for 3.0.0**, not test-suite polish. A vacuous assertion matters exactly
   as much as the defect it is hiding.
2. **Reviews and gate rules are two different detectors**, and they find different things. Keep
   both.
3. **Neither detector ships a fix.** See §2b: of the ten library defects found so far, a static
   rule catches three. The five it misses outright are the five that make the library *wrong*.

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
| **Options / portfolio** | 7 files | 2026-09-13 | 🟡 partial — 1 escalated to L13 | ⬜ |
| **Valuation batch 1** | 19 files | 2026-09-13 | 🟡 partial — 1 resolved (library right) | ⬜ |
| **Stochastic / interpolation** | 20 files | 2026-09-13 | 🟡 partial — 1 confirmed (L14) | ⬜ |
| **Heuristics / async** | 12 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Streaming / builders** | 18 files | 2026-09-13 | 🟡 partial | ⬜ |
| **Helpers / diagnostics** | 14 files | 2026-09-13 | 🟡 partial — 1 confirmed exactly | ⬜ |
| **Operations / inventory** | 6 files | 2026-09-13 | ⬜ not yet — **cleanest batch in the corpus** | ⬜ |
| **Differential reference** | 6 files | 2026-09-13 | ✅ — 1 refuted, 1 stale claim caught | ⬜ |
| **Marketing** | 8 files | 2026-09-13 | ✅ — 1 refuted; **carries the design answer to T5** | ⬜ |
| **Attribution** | 2 files | 2026-09-13 | ✅ — axioms as oracle; **collapses the `#expect(true)` thread** | ⬜ |
| **Integer programming** | 31 files | 2026-09-13 | ✅ — **confirmed by measurement, and extended**; opens Q5 | ⬜ |
| **Network / survival / classification** | 18 files | 2026-09-13 | ✅ — **proved L7 empirically**; corrects a gate rule | ⬜ |

**Twenty-two reviews, ~370 test files, and Justin has more.** The per-domain detail is §4; the reason this
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
| L7 | **`Period`/`FiscalCalendar` read `Calendar.current` internally.** | **CONFIRMED BY MEASUREMENT, with the package's own detector** | `Period.swift:17` and `PeriodArithmetic.swift:56` are both `private let cachedCalendar = Calendar.current`; `FiscalCalendar.swift:154,236` read it directly, as do `TimeSeriesOperations` (3), `TimeSeriesAnalytics` (1), `BondPricing` (2), `CreditSpreadModel` (4), `LeaseAccounting` (1), `DebtInstrument` (1). **~15 executable sites** (the other ~70 matches are doc comments). A module-level global captured once — not a parameter anyone can override, so **no test-side fixed calendar can reach it**. Demonstrated live: a `Period` for 2024-Q1 stores `2024-01-01 05:00:00 +0000`, i.e. midnight in `America/New_York`.

**Measured 2026-09-13 with `ZoneInvariance.sweep`, the harness `BondClockZoneInvarianceTests` already ships:**

| sweep | `isInvariant` |
|---|---|
| control — `Calendar.current.component(.day,…)` | **false** (the harness has teeth) |
| `FiscalCalendar.standard.fiscalYear(2025-01-01 UTC)` | **false** |
| `FiscalCalendar(yearEnd: Sep 30).fiscalYear(2025-10-01 UTC)` | **false** |
| `Period.startDate` / `.endDate` / constructed inside the sweep | true |

**`FiscalCalendar.fiscalYear(for:)` returns a different fiscal year for the same instant depending on the machine's time zone.** Both failing dates are the day *after* a fiscal year-end, where a westward zone still reads the previous year — the highest-stakes place for a fiscal calendar to disagree with itself.

**And `Period` reporting `true` is not reassurance — it is a blind spot (Q6).** `Period.swift:17` captures `Calendar.current` into a module-level `let`, once, at first use. Mutating `NSTimeZone.default` afterwards cannot change it, so the sweep cannot see the dependence. `Period` is not zone-independent; it is **locked to whichever zone the process started in**, which is worse and undetectable by this harness. |
| L7a | **The fix already exists in the package, unapplied.** | **NEW** | `DayCountConvention.swift:49` defines `gregorianUTC` — Gregorian, fixed to UTC, `internal` so it is already shareable — with the doctrine written out above it, including: *"It is deliberately not named `cachedCalendar`, which is the name `Period` arithmetic uses for a cached `Calendar.current` — the opposite of this one."* and *"This reasoning was written here and applied here, while `Calendar.current` stayed in every other file that walks a schedule of dates … and the coupon grid drifted a day for exactly the reason set out above."* **This is a known, documented, unfixed defect with its own remedy sitting beside it.** |
| Q6 | **`ZoneInvariance.sweep` cannot detect a cached calendar.** | **NEW — a blind spot in the package's own detector** | The sweep mutates `NSTimeZone.default` and re-evaluates. A module-level `private let cachedCalendar = Calendar.current` is captured once at first use and never re-read, so the sweep reports `isInvariant = true` for code that plainly depends on the ambient zone. Measured: `Period.startDate` and `.endDate` both report invariant while storing `2024-01-01 05:00:00 +0000` for 2024-Q1. **The harness's own excellent principle — "a detector that has never been observed to fire is indistinguishable from one that cannot" — applies to itself here.** The fix for the *code* is L7/0.2; the fix for the *harness* is either to document the limitation or to run each probe in a fresh process. |
| Q5 | **Could not make `totalCutsGenerated` exceed zero on any fractional IP.** | **OPEN — needs investigation, not yet a defect claim** | Measured on four problems through the closure-objective API with `enableCuttingPlanes: true, maxCuttingRounds: 5`: `max 3x+4y s.t. 2x+3y≤11` (LP optimum x = 5.5, fractional), `max x+y s.t. 4x+5y≤17` (LP x = 4.25), and two more. Every one returned the **correct integer optimum**, but with `nodesExplored = 1`, `totalCutsGenerated = 0`, `gomoryCuts = 0`, `cuttingRounds = 0`, and an objective off by ~3e-8 from the exact integer (3.9999999752 for 4). The default relaxation *is* `SimplexRelaxationSolver`, so cuts should be reachable. **The likely innocent explanation** is the documented finite-difference path: `5.8-IntegerProgramming.md:953` says a closure objective is linearised by finite differences, which matches the 3e-8 residual and may not produce a tableau Gomory cuts can read. **What needs settling:** whether `enableCuttingPlanes: true` is inert for closure objectives, and if so whether that is documented anywhere a caller would see it. Not filed as a defect because the alternative — these fixtures are simply too small to need a cut — has not been excluded. |
| L16 | **Cut statistics were discarded on four of five return paths.** | ✅ **FIXED** | `solve` built its result with `enableCuttingPlanes ? CuttingPlaneStats() : nil` — a fresh empty object — instead of the tracker that had been accumulating, on every path except the last. So a solve that generated cuts reported `totalCutsGenerated == 0`. **Cutting planes worked the whole time and nothing could see it**, which is why the integer-programming review's `stats.totalCutsGenerated >= 0` assertions are worse than vacuous: they read a counter that was structurally zero. |
| L17 | ~~**`cuttingRounds` and `totalCutsGenerated` count different things.**~~ | **RESOLVED in A6 — the asymmetry was real but was masking L18** | Surfaced the moment L16 was fixed, by a guarded assertion in `NodeCutLoopTests` that had **never executed** — `if stats.totalCutsGenerated > 0 { … }`, with the outer counter structurally zero. A cut is counted when *generated*; a round only after the LP *re-solve succeeds*. A round that adds a cut and then fails to re-solve reports cuts without rounds. "Rounds attempted" and "rounds completed" are both defensible and are not the same number, so this is a design decision, not a patch. |
| L18 | **Gomory cuts were emitted in tableau space and imposed in structural space, so every one was infeasible by construction.** | **FIXED 2026-09-13** | Found by instrumenting L17 rather than accepting its trace. `generateGomoryCut` is handed `totalVariableCount = tableau.columnCount - 1` — structural variables **and slacks**, with the comment "including slacks" directly above it — while its own doc says "expressed over ALL original variables". The consumer then imposed the result over the structural variables alone. Measured on `max x+y` s.t. `x+2y ≤ 7`, `2x+y ≤ 7`: the cut was `[0, 0, -0.7071, -0.7071] · x ≤ -0.7071`, **both non-zeros on slack columns**, so over `(x,y)` the left side is identically zero and the constraint reads `0 ≤ -0.7071` — false at every point, including all three integer optima and the origin. The LP went infeasible on the first cut, every time. **It failed safe, which is why it survived:** the infeasible re-solve breaks the loop, the node-local constraints are discarded, and branch-and-bound continues unaided — same answer, same node count, pure wasted work. `enableCuttingPlanes: true` did nothing. **Fix:** `SimplexTableau.projectToStructuralSpace` substitutes each added column out via `x_j = (b_r - Σ A_ri x_i)/σ`, using the already-retained equilibrated `initialRows` and finding each column's row by **search, not by `numOriginalVars + k`** — the offset assumption that already produced wrong shadow prices here, as recorded beside `shadowPrices(from:)`. Artificials substitute to zero. **Measured after: node count 3 → 1**, the cut closing the root without branching. |
| L15 | **Three days-per-year conventions in one package.** | **NEW — found while refuting a claim** | `FinancialRatios` uses 365; `TimeSeriesAnalytics:181` and `BondPricing` use **365.25** ("to account for leap years over long periods"); `DayCountConvention` implements the ISDA set properly. None is wrong alone, and a CAGR over decades has a real case for 365.25. But the choice is undecided and undocumented, and it sits directly next to L11. Decide once, document, and route through `DayCountConvention` where a convention is genuinely at stake. |
| L13 | **`sharpeRatio` returns 0 when risk is 0.** | **NEW — escalated from the options/portfolio review** | `Portfolio.swift:182` is `guard risk > T(0) else { return T(0) }`. The review could not tell whether the implementation guarded or the test failed; it guards. But **0 is a plausible-but-wrong answer**: a Sharpe of 0 means "no excess return per unit of risk", and the fixture earns 7.5%/yr of excess return at *exactly zero risk* — infinitely good, reported as mediocre. The guard inverts the best possible case. Same family as `a * 0 → 0` and the antithetic SE: a guard returning a plausible number where the answer is undefined. **Decide +∞, NaN or throw, then pin it.** Consequence meanwhile: `sharpeFinite` asserts `.isFinite` on a constant 0, and `optimizerBeatsEqualWeights` reduces to `0 >= 0 - 1e-6`. |
| L14 | **A shared test helper ships a generator with two contract bugs.** | **CONFIRMED** | `Tests/.../Stochastic/StochasticTestHelpers.swift:13` is `Double(state) / Double(UInt64.max)` — **closed** on both ends, returning exactly 1.0 at `UInt64.max` and exactly 0.0 at 0, while its own doc says "(0, 1)". Its `nextNormal` guards `max(u1, 1e-15)`, the shape `BoxMullerPoleGuardTests` calls wrong, and does not guard u₁ = 1.0 where `log(1) = 0` collapses the draw. It duplicates `MMIXSeededRNG`, already in TestSupport. **This is the Nth inline Box-Muller in the corpus and the first found in a *shared* helper, so it seeds several files at once.** Delete it; use `DeterministicRNG` and the TestSupport transform. |
| L12 | ~~**The only outlier rule the library has is the one that masks.**~~ | **REFUTED, then replaced — resolved in A5** | ⚠️ **The masking claim below was wrong, and this row said "verified" without running the detector.** `ZScoreAnomalyDetector.detect` does **not** score against the series' own mean and standard deviation: the baseline is the `windowSize` points *before* the point under test, and `flaggedIndices` removes already-flagged points from later windows. On `[10,12,11,13,12,50,11,12]` the 50 is flagged at **z between 37 and 75** for every window from 2 to 5. The 2.4694 / 2.6399 figures are whole-series z-scores — arithmetic nobody in the library performs. **This is the fourth refuted review claim, and the second to be recorded here as verified when only the *arithmetic* had been checked and never the code path.** What *is* true: there was no modified-z or IQR rule (shipped in A5), and there is a real blind spot the review did not find — the scan starts at `windowSize`, so the leading `windowSize` points are never examined, and an outlier among them is invisible while inflating the deviation for everything after it. Measured: `[12,11,13,12,30,…]` flags the 30 at z = 25.46; `[50,11,13,12,30,…]` flags nothing. |
| L11 | **DSO / DIO / DPO are wrong on any non-annual statement.** | **NEW — measured, live defect** | `daysInventoryOutstanding` is `365 / inventoryTurnover`, and `inventoryTurnover` is `COGS / averageInventory` over the **period**, un-annualised. On the quarterly documentation fixture, measured: turnover 4.0 turns *per quarter*, DIO **91.25** days where the answer is 91/4 = **22.75** — **4.01× too large**. DSO returns 73.0 where it should be 18.2. The financial-ratio review presents "90-day quarter or 365-day year" as an open convention; it is neither. It is a dimensional error: an annual day count divided by a quarterly turn rate. **And 91.25 is within a quarter-day of the 91 days in the quarter, so a reader sanity-checking "is DIO about one quarter?" sees agreement.** The fix is `DayCountConvention.days(in: period)`, which already exists and returned the correct 91.0 in the same probe. |
| L8 | **`MonthDay` accepts February 30.** | UNVALIDATED | A 1–31 day range admits impossible dates. Also: what does a February 29 fiscal year-end mean in a non-leap year? Currently undefined. |
| L9 | **`npvExcel` discounts the first element by one period.** | UNVALIDATED (behaviour), **CONFIRMED** (design) | Implementation is `flow / (1+r)^(index+1)` — correct Excel semantics. Passing an array that *begins with the initial outlay* silently misprices. Documentation, not a code change. |
| L10 | **Mixed period types unsupported, recorded only in a commented-out test.** | UNVALIDATED | "Trigger a Strideable issue when Swift's stdlib tries to optimize." A capability recorded in a comment will be rediscovered by a user. |

---

## 2b. What a gate rule can and cannot catch

Tested against the ten library defects this programme has found, because "build durable quality
infrastructure" is only a correctness strategy if the infrastructure catches correctness problems.

| Defect | Static rule catches it? | Why |
|---|---|---|
| **L2** `bayes` is `Double`-only | **yes** | structural — a public numeric free function not generic over `T: Real` |
| **L3** `runFinancialSimulation` has no `seed:` | **yes** | the transitive-unseeded rule |
| **L7** `Calendar.current` in `Sources` | **yes** | an ambient-time read outside a documented seam |
| **L14** duplicate RNG in a shared helper | partial | a duplication rule flags the copy, not the closed interval |
| **L15** three days-per-year conventions | partial | could flag bare `365` / `365.25` outside `DayCountConvention` |
| **L1** `bayes` unguarded denominator | **no** | semantic — the divisor is zero only for particular inputs |
| **L4** two debt definitions, undocumented | **no** | semantic — both formulas are correct |
| **L11** DSO/DIO/DPO **4.01×** | **no** | dimensional — `365 / (per-quarter rate)` is type-correct and wrong |
| **L12** the only outlier rule is the masking one | **no** | a capability gap; there is nothing to flag |
| **L13** `sharpeRatio` returns 0 for zero risk | **no** | semantic — a guard returning a plausible value |

**Three of ten caught outright. Five missed, and those five are the ones that make the library
wrong.**

### What follows from that

- **The reviews are the semantic-defect detector, and the only one.** No rule would have found L11
  or L13; a reader working through the code did. That is the argument for continuing intake, and it
  is stronger than the argument I made against it.
- **Gate rules are the shape-defect preventer.** They stop the 225-site threads regrowing behind a
  sweep. That is real and compounding, and it is *not* a correctness mechanism.
- **Neither ships a fix.** For the five rule-invisible defects there is no path but changing the
  code.

So the programme has three tracks, not one: **find** (reviews), **prevent** (gate rules), **fix**
(the only one that makes the library correct). The first two have been running for a week. The third
has not started.

---

## 2a. Every review count is a lower bound

**Measured corpus-wide 2026-09-13, against the best single-review claim for the same pattern.**

| Pattern | Best review claim | Corpus-wide | Ratio |
|---|---|---|---|
| `?? 0` inside an assertion | 93 (time series) | **225** | 2.4× |
| `Calendar.current` in tests | 73 (time series) | **152** | 2.1× |
| `Date()` in tests | 16 (time series) | **210** | 13.1× |
| `#expect(true)` markers | 13 (helpers/Logger) | **75** | 5.8× |
| `converged \|\| iterations …` | 1 → 4 (optimization) | **11** | 11× |
| `results.count >= 1` | 17 (streaming) | **31** | 1.8× |
| `.rounded()` in a comparison | 2 (optimization) | **7** | 3.5× |
| Type-only `#expect(throws: X.self)` | ~300 (marketing) | **530** | 1.8× |
| `.disabled` tests | 2 (scenario) | **10** | 5× |
| Commented-out `@Test` | 7 (optimization) | **30** | 4.3× |

**Why, and it is structural rather than sloppiness.** Each review is scoped to its domain and counts
honestly *within* it. Nothing is wrong with any individual number. But the patterns are
package-wide, so **summing per-domain reviews systematically understates the work**, and planning
against the sum plans against a fraction.

**How to use this table.** These are pattern-match counts and need per-site triage before they are
work items — `Date()` at 210 certainly includes legitimate uses, and `count >= 1` will catch
unrelated code. The *order of magnitude* is the finding, not the digit. **Measure corpus-wide
before scheduling any thread**, which is what §3's counts now do.

---

## 3. Cross-cutting threads — where the volume actually is

Six shapes account for most of the findings across all eight reviews. Working them by *shape* rather
than by domain is what turns 900 lines of review into a finite amount of work.

### T1. Assertions that cannot fail — the largest single category

| Shape | Count | Where |
|---|---|---|
| `?? 0` inside an assertion, turning a missing lookup into a pass | **225 corpus-wide** (103 in time series alone) | everywhere |
| Field-storage tests: assert the initialiser's arguments come back out | ~30 + 5 | Time series (FiscalCalendar, TimeSeries), scenario (FinancialProjection) |
| Finiteness / sign / ordering only | ~45 + ~20 + ~12 | Time series financials, scenario, operational driver percentiles |
| Encoding asserted by `data.count > 0` | 2 | Period, FiscalCalendar |
| Guarded assertions that never execute (`if abs(npv) < 10.0`) | ≥1 | `profitabilityIndexBreakEven` |
| `#expect(true)` markers | **75 corpus-wide**, 13 in `LoggerTests` | **53 of the 75 say "no-throw" in their own comment** — mechanically convertible to `#expect(throws: Never.self)`, a form already used 11 times here. The rest are the gate's nested-scope bug plus a handful of genuine cases |
| `results.count >= 1` on a stream with fixed input | **31** | streaming, alignment, anomaly |
| Tautologies: `x == x`, `s >= 0 \|\| s < 0` | ≥4 | `CalculationTraceTests` ×2, `PortfolioTests`, `StreamAlignmentTests` |
| **`.rounded()` inside a relational operator** | **7** (review said 2) | `StochasticOptimizationTests` 3, `RobustOptimizationTests` 3, `ScenarioOptimizationTests` 1 |
| **Always-true disjunctions on convergence** | **11 corpus-wide** | Newton-Raphson, LBFGS, performance, NelderMead (`== 500`, `== 300`) |

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
| `Calendar.current` in **all** tests | **152** (75 in time series) |
| `Date()` in **all** tests | **210** (18 in time series) |
| `Calendar.current` in **Sources** | ~15 executable (L7) |

The valuation batch adds 50 of those test sites — 23 in `BondPricingTests` alone — including a
`referenceDate()` helper whose comment says "Use a fixed reference date to avoid wall-clock
dependencies" but which builds that date with `Calendar.current`. **The intent was right and the
mechanism was not**, which is the same gap as L7 one layer up.

A related live hazard from the stochastic batch: `bondDurationCouponRelationship` builds its date
with `Calendar.current.date(from:) ?? Date()` — **a silent fallback to *today***, which would make
the bond zero-length rather than fail.

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
than a convention). Several are the *same* decision reached from different directions.

### The design answer, from `CustomerValueTests`

The marketing review supplies a resolution this thread has lacked for twenty reviews, and it is an
**API** answer rather than a test one:

> "if there are four definitions of CLV in common use, then verifying that the code matches its
> documentation proves internal consistency and not correctness. A user who wants definition three
> gets a library rigorously computing definition one.
>
> The answer is that the variant is named at the call site. The library's claim is not 'we compute
> CLV' — which is not a claim anyone can check — but 'we compute exactly the definition you asked
> for', which is."

`QuantileType7ReferenceTests` solves the same problem one level down: **pin which of the nine
published definitions is implemented, by choosing an input the definitions disagree on.** Its table
is the template —

| definition | Q(0.4) on [15, 20, 35, 40, 50] |
|---|---|
| type 7 (R, NumPy) | **29** |
| type 6 (Minitab, SPSS) | 26 |
| type 4 | 20 |

— "so a single assertion at that point distinguishes type 7 from the three most common
alternatives."

**So each open convention now has two possible resolutions, and they are not exclusive:** name the
variant at the call site where there is a real choice a caller should make, and pin the default with
a discriminating case either way. The differential review supplies discriminating cases for several:

| Convention | Discriminating case |
|---|---|
| `weightedPercentile` type 5 vs 7 | n = 7, equal weights, p = 0.25 → **2.25 vs 2.5** |
| Skewness g₁ vs G₁ | the 24-point fixture → **−0.0577 vs −0.0616** |
| `weightedVariance` frequency vs reliability | any non-integer weight set |

**One row of that table is refuted and one is stale** — see the note below.

Several are the *same* decision reached from different directions:

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

**530 type-only sites corpus-wide** (`#expect(throws: X.self)`), against **99** that pin an
associated value. The loosest form, `(any Error).self`, appears in `ScenarioRunnerTests:497` — in a
file whose sibling tests pin `.invalidDriver` with its error code.

The marketing batch demonstrates the standard:

```swift
#expect(throws: UpliftError.unbalancedAllocation(treatedShare: 0.6875))
#expect(throws: SegmentationError.invalidSegmentCount(requested: 9, customers: 6))
#expect(throws: CLVError.definitionNeedsHistory(.historic))
```

**Correction to that review:** it calls these "the corpus's first error assertions that pin
associated values." They are not — 99 such sites exist and **83 are outside Marketing**, including
`ClusteringError.tooManyClusters(k: 5, dataPoints: 3)` in `KMeansTests` and
`BusinessMathError.divisionByZero(context: "Index of Dispersion")`. Marketing is the most
*systematic*, not the first. The technique is already in the corpus and needs spreading, which is a
cheaper problem than inventing it.

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

- [x] ~~**L4** — document the debt asymmetry on both properties; pin both values.~~ ✅ **DONE** — see A3.
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
- [x] ~~Fix the 7 `.rounded()` comparisons and 4 always-true disjunctions (T1).~~ ✅ **DONE** — see B1; the disjunction count was 11, not 4.
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
- [x] ~~**L12** — the anomaly capability gap, above. Pin the threshold behaviour; decide whether a
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

### 4.8 The 2026-09-13 batch — seven reviews, briefly

Full documents in `reviews/`. Only what is specific to each, and what validation changed.

**Options / portfolio (7 files).** `BlackScholesNormalCDFAccuracyTests` belongs with the corpus's
best — 13 reference values recomputed at 60 digits, all matching, with the oracle deliberately not
sharing arithmetic with the subject. Against it, `atmCall` asserts `5 < price < 20` for a value the
*same file's third suite* pins at 10.4505835721855682.
- [ ] **L13** first — the zero-risk Sharpe contract.
- [ ] Replace both degenerate portfolio fixtures with nonzero, unequal variances and a known
      covariance. Three tests are currently vacuous *because of the fixture*, not the assertion.
- [ ] Inverse-vol weights are exactly **1/3 and 2/3** and are asserted at ±0.10 — a band spanning
      0.233–0.433, which cannot distinguish 1/3 from 0.25.
- [ ] Extend the 120-digit reference suite to the Greeks, then delete the sign-and-range tests.
- [ ] Binomial: assert the **convergence order** (error ≈ 0.19/n, so doubling steps halves it)
      rather than a magnitude 26–52× looser than the actual error.

**Valuation batch 1 (19 files).** `ValuePerShareGuardTests` is the corpus's clearest statement of
the duplication argument: four types spell `valuePerShare`, two "carried byte-identical two-line
bodies that were declared `throws` and never threw". `CoxProcessSimulationTests` has a technique
found nowhere else — a **cross-width differential**, same seed through `Double` and `Float`,
agreeing to the narrower precision, which caught `meanHazardRate as? Double` silently failing for
`Float`.
- [ ] **H-Model: RESOLVED, no defect.** The review suspects a factor-of-two in `halfLife`. The
      implementation is the standard H-model and the API doc says *"full transition = 2H years"*
      correctly; the **test's** comment (`// Takes 10 years for growth to decline`) is the error.
      Value is exactly **61.3333333333**. *Second instance this session of "library right, test
      comment wrong" — the first was `npvExcel`.*
- [ ] 50 `Calendar.current` sites (T4); bond prices, durations, convexity, Merton and CDS all
      pinned — every one is closed form.

**Stochastic / interpolation (20 files).** `InterpolationReferenceTests` contributes a technique
worth stealing: **assert the property, then assert a sibling implementation violates it.** PCHIP
must not overshoot and a spline on the same data *must* — "if it did not, the two would be the same
code and the property above would be vacuous." `AsymmetricGarchTests` uses nesting as its oracle
(APARCH at γ=0, δ=2 *is* GARCH).
- [x] ~~**L14** — delete `StochasticTestHelpers`.~~ ✅ **DONE** — see A2.
- [ ] `ProcessStateTests`/`MeasureTagTests` assert literals against themselves; the *binding* is the
      test and it is a compile-time one. Keep the bindings, delete the assertions.
- [ ] `FinancialReferenceValidationTests` recomputes NPV's expected value from the implementation's
      own formula — consolidate into the files that already cover it.

**Heuristics / async (12 files).** `GPUAttemptTests` is the corpus's best example of making an
untestable defect testable: it **extracts the hazard into a closure seam** so a `body` returning nil
reproduces a GPU resource-pressure failure in microseconds with no GPU.
`HeuristicGPUSeedDeterminismTests` closes the exact non-vacuity gap the simulation review asked for
— it asserts the GPU path is *reachable* before testing behaviour at the threshold.
- [ ] NelderMead's `converged || iterations == 500` (T1).
- [ ] The three island-topology tests do not distinguish topologies — an implementation ignoring
      `topology` entirely passes all three.
- [ ] `gradientNorm < 0.1` is **the right assertion at the wrong tolerance**; promote it to primary
      and bind it to the optimizer's own convergence tolerance.

**Streaming / builders (18 files).** `MergeLeakRepro` is the best async test in the corpus and the
only one testing a resource-lifetime property: instrument the producer, take five, break, then
sample the counter twice. `StreamingFrequencyDomainTests` documents a tightening from
`0.5 < ratio < 2.0` to 1e-12 on Parseval, and has a genuine two-backend differential.
- [ ] 31 `results.count >= 1` (T1); `#expect(hasNaN || hasNonNaN)` is exhaustive by construction.
- [ ] FFT peak asserted within 2 Hz at 1 Hz resolution, where the peak lands exactly on bin 10.

**Helpers / diagnostics (14 files).** `ModelProfilerTests` solves the corpus's hardest testability
problem with an injected `ManualElapsedTimeSource`, and its comment is the sharpest one-line
statement of the whole series' theme: *"The value they all agree on is now known, not merely
self-consistent."*
- [ ] **`PerformanceOptimizationTests` has ~17 wall-clock assertions and is not `.benchmarkOnly`** —
      a standing CI-flake risk, tightest bound 50 ms. Split: timings behind the trait, correctness
      assertions stay.
- [ ] **`LoggerTests`: 13 `#expect(true)`, CONFIRMED exactly.** Inject a recording sink.

**Operations / inventory (6 files).** *No defects.* "The cleanest small batch in the corpus" — no
vacuous assertions, no unseeded randomness, no wall-clock timing, no field-storage padding. The
findings are tolerance-only, and two are exact identities checked at ±1.0 and ±0.05: at Q\* the EOQ
first-order condition makes ordering cost **equal** holding cost (both 187.34993995195194), and
stockout probability at the mean is exactly 0.5 by symmetry. **This batch is the model for what
"done" looks like** — and its full exact-value table is ready to transcribe.

---

### 4.9 Differential reference, marketing, attribution — the three that set the standard

These three batches are the corpus's best work, and validating them mostly confirmed them. What
they contribute is technique; what they cost is two stale claims to catch.

**Differential reference (6 files).** The TrustPlan §2.2 set. Every file cites its source precisely
enough to re-derive, carries a tolerance table with the *measured* worst case, and separates the
reference's precision from the code's. The policy statement in `NormalReferenceTests` is the one
this series has been asking for:

> "No tolerance in this file was chosen by loosening one that failed. Where the library disagreed
> with the reference the test was marked `withKnownIssue` with the measured magnitude, so that
> fixing the defect made the marker fail. Three such markers … were removed when the defects were
> fixed, not when they became inconvenient."

- [ ] `TVMReferenceTests`' header cites `NPV(10%, 3000, 4200, 6800) - 10000 = 1188.44`. That
      expression is 1307.29; the number 1188.44 belongs to `NPV(10%, -10000, 3000, 4200, 6800)`,
      which is what the body actually computes and what its inline comment says correctly. **Third
      instance of comment arithmetic being wrong while the code is right** — after `npvExcel` and
      the H-Model. **And it independently corroborates the `npvExcel` diagnosis**: this file gets
      the convention right, which strengthens the case that `NPVTests` is wrong rather than the
      implementation.
- [ ] `excelExampleDates` falls back to `Date(timeIntervalSince1970: 0)`; `monotoneInP` issues
      1,001 expectations where one would do.

**Two claims in it did not survive validation:**
- **REFUTED: "DIO on 365 vs DSO on 150 — internally inconsistent today."** There is no DSO-on-150.
  All three activity ratios use `T(365)`; the only `150`s in the package are a doc-example data
  point and `DayCountConvention`'s 30/360 prose, where 150 days for a stub period is correct. The
  claim is sourced to "valuation batch 2", a review not yet received — **reviews carrying each
  other's claims instead of the code, which is the trap `HANDOFF.md` §5 names.**
- **STALE: the H-model listed as an open convention (61.33 vs 48.00).** Settled in the previous
  round: the implementation and the API doc are both correct; the *test's* comment is the error.

**But looking for the refuted one surfaced a real inconsistency (L15):** the package uses **three
different days-per-year conventions** — `FinancialRatios` 365, `TimeSeriesAnalytics:181` and
`BondPricing` **365.25**, and `DayCountConvention`'s full ISDA set. Not wrong in itself; undecided,
undocumented, and adjacent to L11.

**Marketing (8 files).** The strongest domain batch. Every file opens by naming three *measured*
fail-silent shapes in its own subject — a cohort average that reports 0.17 where the answer is 0.50;
a log-log fit scoring R² 0.975 on exactly-linear data while missing by 2.75 units everywhere; an
optimal price that comes out **negative** under inelastic demand. And every file names an anchor
needing no reference implementation: the Lerner condition, the CLV/perpetuity limit,
Σ(yᵢ − pᵢ) = 0 at the likelihood maximum.
- [ ] Carries **the design answer to T5** — see §3, T5. This is the item with the longest reach in
      the batch.

**Attribution (2 files).** Adds a technique no other file has: **axioms as the oracle.** Attribution
has no ground truth — no experiment reveals what a channel "really" contributed — so the files test
what any credit allocation *must* satisfy: efficiency, null player, symmetry, order invariance.

The null-player test is the only assertion in the corpus that argues for its own exactness from
first principles: "a channel that changes no coalition's worth receives precisely zero, which is the
one assertion in attribution that can be made without a tolerance." It uses `== 0` deliberately, and
correctly.
- [ ] **`#expect(throws: Never.self)` is the answer to the `#expect(true)` thread.** 53 of the 75
      markers say "no-throw" in their own comments; `Never.self` says it as an assertion instead of
      a marker, and reads as the deliberate pair of the throwing case beside it.

---

### 4.10 Integer programming — 31 files, and the batch's sharpest single finding

`IntegerProgrammingCertificateTests` states the problem better than any of my own notes:

> "Across 29 files the integer-programming suite checks a great deal about the *machinery* … None of
> it answers the one question a caller asks: is the returned solution actually the best integer
> point? A branch-and-bound that prunes one node too eagerly returns a feasible integer solution
> with a plausible objective and a bound that still points the right way. Every existing assertion
> passes. The answer is simply not optimal."

Its oracle is exhaustive enumeration over a boxed integer region — "a complete, independent integer
programming solver, written in a dozen lines, sharing nothing with the one under test" — and the
reasoning for why that is the right oracle is the same one `LinearProgrammingCertificateTests`
reaches: **it cannot prune, so it cannot prune wrongly.** `degenerateTies` compares the optimal
*value* and not the point, because "asserting one would be asserting a convention rather than a
result."

The time-limit pair does the same for a budget: the clock is advanced **inside the objective
function**, ten modelled milliseconds per evaluation, so "one second" is exactly one hundred
evaluations and the assertion is fixed rather than machine-dependent. The pre-fix measurement is
recorded in the file: **153 seconds against a one-second limit.**

**The headline finding — confirmed by measurement, and it goes further than the review.**
`Phase1_CutValidityTests` is named for cutting-plane validity and, as shipped, never runs the
cutting-plane code. Sixteen of its seventeen `minimize:` settings are `true`, on fixtures of the
shape *minimise Σx subject to Σx ≤ b*, whose optimum is the origin — already integral. One test has
`minimize: false  // MAXIMIZE to hit the upper bound`, which is the smoking gun the review cites,
and it is there verbatim.

Measured on the file's own first fixture (`x + y`, `x + y ≤ 3.7`, x integer):

| | status | objective | nodes | cuts |
|---|---|---|---|---|
| `minimize: true`, as shipped | optimal | **0.0** | **1** | **0** |
| `minimize: false`, the proposed fix | optimal | 3.7 | 3 | **0** |

One node under minimisation — the root, never branched. **A solver with cutting planes entirely
unimplemented passes all fifteen tests.**

**But the review's one-word fix is necessary and not sufficient.** Flipping the sense does make it
branch, and still generates zero cuts. The deduplication tests (`identicalCutsDeduplicated` and
siblings) still could not mean what their names say. See **Q5** — I could not make
`totalCutsGenerated` exceed zero on any of four fractional IPs, and the reason needs settling before
this file is rewritten around cut counts.

- [ ] Flip the sense **and** establish a fixture that provably generates a cut (blocked on Q5).
- [ ] **Restore three stale assertions.** `handlesNegativeLowerBounds` prints
      `"Expected: x = -3, Got: …"` and comments "When fixed, should be: `#expect(...)`" — that
      assertion now exists and passes elsewhere. `detectsQuadraticObjective` and
      `detectsBilinearConstraint` each carry a commented-out `#expect(throws:)` with "TODO: should
      FAIL until we implement linearity checking" — and `validateLinearity` now exists.
      **All three capabilities shipped; none of the three tests was updated.** This is precisely
      what `withKnownIssue` is for: recorded as executable expectations, Swift Testing would have
      reported the unexpected pass when each fix landed.
- [ ] `CapitalBudgetingTests` accepts a **22%-suboptimal** answer by design: the three-project
      knapsack has a unique optimum of 90 at {A, B}, and the test asserts `>= 60.0`, which admits
      {B, C} at 70 and {A, C} at 80. The comment names the cause. `withKnownIssue` asserting 90.
- [ ] `cutsReduceTreeSize` never compares tree sizes; `stats.totalCutsGenerated >= 0` on an unsigned
      count; six `if stats.totalCutsGenerated > 0 { … }` guards whose bodies may never execute.
- [ ] Four more `#expect(true)` markers — and three are a **second form** of the gate's nested-scope
      bug: nested `struct` suites rather than nested `func`. They are the fixtures for fixing it.

---

### 4.11 Network, survival, classification, financial — 18 files, and the harness that proved L7

**`BondClockZoneInvarianceTests` implements the time-series review's recommendation and adds what
that recommendation lacked: a proof that the detector fires.**

> "A detector that has never been observed to fire is indistinguishable from one that cannot, and
> this entire file exists because a suite that *could not fail* was mistaken for a suite that
> passed."

`theSweepDetectsAKnownDependence` runs `Calendar.current.component(.day,…)` through the sweep and
requires `!isInvariant` first. **This is the third independent arrival at the self-testing oracle** —
after `enumerationIsItselfCorrect` in the integer-programming certificate and the paired
property/violation tests in interpolation.

**Using it proved L7 and found Q6** — see §2. The harness generalises, the defect is real at fiscal
year boundaries, and the harness cannot see the `Period` case at all.

**`WallClockAdoptionTests` is 33 tests of injected-clock adoption**, every one an exact equality,
and `Sources/BusinessMath/Determinism/` already ships `ElapsedTimeSource`, `ManualElapsedTimeSource`
and `WallClock`. **That lowers the cost of the `PerformanceOptimizationTests` item (1.6) and of any
future timing work** — the infrastructure exists and has 33 tests behind it.

**It also corrects one of my proposed gate rules.** §3.2 draws a distinction I had missed:

- A **tolerance** (`abs(recorded - Date()) < 0.1`) asserts a *duration* — it can fail on a loaded
  machine and passes for a clock that is merely close.
- **Bracketing** (`before <= recorded && recorded <= after`) asserts *ordering* — it cannot fail for
  a correct implementation however slow the machine, and fails for any other clock.

So the proposed "flag `Date()` in test targets" rule **needs a carve-out**: flag a reading used in an
*arithmetic* comparison; allow two readings bracketing a call. Without it the rule would flag nine
correct tests in `WallClockAdoptionTests`. Recorded in §7.

- [ ] `ClassifierEvaluationTests`' header cites tie-convention values (0.8125, 0.9375) that
      correspond to no standard convention. Verified on its own fixture: half-credit **0.875** =
      14/16 ✓ (the asserted value is right), strict wins 0.750, ties-as-wins 1.000, tied pairs
      dropped 1.000. **Fourth instance of comment arithmetic being wrong while the code is right.**
- [ ] `ExperimentDesignTests` still carries a "RED phase for v2.7.0" header while asserting exact
      integers — check whether it now passes and drop the label if so.

**Technique worth copying:** `ClassifierEvaluationTests`' Mann–Whitney helper is *deliberately* the
naive O(n²) double loop — "this is the definition, and a test that reimplements the implementation's
optimisation checks nothing." The implementation integrates the ROC curve; the test counts pairs.

---

## 5. Sequencing — against 3.0.0

**Re-sequenced 2026-09-13 (third revision)**, after the goal was stated: a strong 3.0.0, correctness
first. The previous revisions ordered by leverage; this one orders by **what must be true before the
tag**.

### 5.0 The 3.0.0 correctness cut line

The question for every item is no longer "how much does this improve the suite" but **"would we tag
with this in it?"** Three answers:

| | Meaning |
|---|---|
| **BLOCKS** | the library computes a wrong number, or returns a plausible value for an undefined one. Cannot ship. |
| **DOCUMENT** | real, but defensible to ship with a stated limitation and a `withKnownIssue` recording it |
| **AFTER** | genuine work, no bearing on whether 3.0.0 is correct |

**BLOCKS — ✅ ALL SIX CLEARED, shipped as `v3.0.0-alpha.5` (`82bff1ee`).** Five were invisible to
any gate rule (§2b), which is the whole argument for the review programme. Two further defects were
found *by fixing* rather than by reviewing — L16, fixed, and L17, recorded.

| | Defect | Why it blocks |
|---|---|---|
| ~~**B1**~~ | ~~**L11** DSO / DIO / DPO **4.01×**~~ | ✅ **DONE `4b666601`.** Day count now comes from the period via `DayCountConvention.days(in:)`, with `dayCount:` selectable. Two existing tests pinned the old values; both had the error written out in their own comments. The CCC identity did not fail — the control, as predicted. |
| ~~**B2**~~ | ~~**L7** fiscal year varies by time zone~~ | ✅ **DONE.** 17 source sites to `gregorianUTC`. Found a 17th the `Calendar.current` grep missed — `Calendar(identifier: .gregorian)` in `PeriodSequence`, which looks fixed and carries `TimeZone.current`, putting January's value in the previous year's Q4. Plus `formatted(using:)`, which rendered January 2025 as "December 2024" west of Greenwich. |
| ~~**B3**~~ | ~~**L13** `sharpeRatio` returns **0** for zero risk~~ | ✅ **DONE.** Guard deleted (Justin's call): `+infinity`, `-infinity` and `NaN` each answer for themselves. Blast radius was exactly one test — `sharpeFinite`, which the options review had already identified as testing the guard rather than the ratio. |
| ~~**B4**~~ | ~~**L1** `bayes` NaN by accident~~ | ✅ **DONE.** NaN was already the behaviour — what was missing was the *contract*. Now documented, pinned, and paired with a throwing `bayesChecked`, in the `factorial`/`factorialChecked` shape. **L2 landed with it**: `bayes` is generic over `T: Real`. |
| ~~**B5**~~ | ~~**Q5** is `enableCuttingPlanes` inert?~~ | ✅ **SETTLED — it was never inert, and my earlier reading was wrong.** Traced: a Gomory cut is generated, applied, and takes the LP optimum from a fractional 5.5 straight to the integer optimum at the root. **`totalCutsGenerated` was the defect (L16)**: four of five return paths built the result with a fresh empty `CuttingPlaneStats()` instead of the accumulated tracker. Fixed. |
| ~~**B6**~~ | ~~**Q6** `Period` locked to the process's launch zone~~ | ✅ **DONE** with B2 — there is no capture left to lose. Demonstrated en route: `periodStartsAtUTCMidnight` passed inside its suite and failed in isolation, because a sweep had already moved the default zone before `Period` first looked. |

**DOCUMENT — ship with a stated limitation.**

- **L4** the two debt definitions. Both formulas are correct and `BalanceSheet.swift:354` already
  documents one side; document the other and pin both values.
- **L12** the masking outlier rule. A z-score detector is a legitimate thing to ship; shipping it as
  *the only* option without saying so is not.
- ~~**L15** three days-per-year conventions.~~ ✅ **DONE** — see A4. Decide, document, and route through `DayCountConvention`
  where a convention is genuinely at stake.
- ~~**L2** `bayes` being `Double`-only.~~ ✅ **DONE** with B4 — generic over `T: Real`.
- ~~**L3** `runFinancialSimulation` without `seed:`.~~ ✅ **DONE**, additively — see A1.
- ~~**L14** delete `StochasticTestHelpers`.~~ ✅ **DONE** — see A2. Test-only; no bearing on the tag.

**AFTER — everything else**, ordered in §5.2. The 225 `?? 0` sites do not make the library wrong;
they make it under-tested. That is the next release's problem, but it is a *sequenced* problem.

---

### 5.2 The ordered remainder

**Written 2026-09-13, after the six blockers closed.** Until now "AFTER" was one sentence covering
89 checklist items and 17 proposed gate rules, which is a bucket and not a plan. This is the order.

A fourth ordering principle joins the three above, and it was learned by doing rather than
planning:

4. **An enabling fix can wake dormant assertions, so it goes before the sweep that depends on it.**
   Fixing the discarded cut statistics (L16) made a guarded assertion execute for the first time,
   and it immediately failed (L17). Six such guards exist in the integer-programming suite alone.
   Sweeping first would have meant sweeping past whatever they had to say.

Each item below carries a **done when** so implementation needs no further decision.

---

#### Phase A — finish 3.0.0 (the DOCUMENT set)

Small, release-relevant, and two of them are breaking so they belong in the major.

| | Item | Done when |
|---|---|---|
| ~~**A1**~~ | ~~**L3** — `seed:` on `runFinancialSimulation`~~ | ✅ **DONE — and additive, not breaking.** The randomness was never in `runFinancialSimulation`: it is in the caller's builder closure, which had nowhere to put a generator. Drivers already had `sample(for:using:)`. So a `SeededStatementBuilder` and a `run(…using:builder:)` overload thread one through, and existing builders are untouched. T3 is unblocked. |
| ~~**A2**~~ | ~~**L14** — delete `StochasticTestHelpers`.~~ | ✅ **DONE.** The file is gone and its 13 call sites across 6 files take `DeterministicRNG` and the library's `boxMullerSeed(using:)`. The Box-Muller is the *library's*, not TestSupport's — TestSupport has no transform, and the library's is the one whose `openUnitUniform` is open by construction. Both contract bugs were reproduced before deletion rather than taken on the review's word: the recurrence is a **full-period** LCG (modulus 2⁶⁴, increment 1, multiplier ≡ 1 mod 4), so both endpoints are *guaranteed* rather than unlikely, and inverting it gives the exact seeds. Seed `4568919932995229531` returns `u == 0.0`, where the `max(u1, 1e-15)` guard yields **z = 8.31** — an 8.3σ "standard normal" delivered deterministically. Seed `9137839865990459062` returns `u == 1.0`, unguarded, where `log(1) = 0` collapses the draw to **exactly 0.0**. Neither throws. At one occurrence per 2⁶⁴ draws both were latent, not firing — the live defect was duplication in a *shared* helper. |
| ~~**A3**~~ | ~~**L4** — document the debt asymmetry.~~ | ✅ **DONE.** Both properties now name their numerator and cross-reference each other, and `DebtDefinitionAsymmetryTests` (7 tests) pins both values at all four fixture quarters. **The item was bigger than "document `debtToAssets`": two doc comments stated a formula the code does not implement.** `SolvencyRatios.debtToEquity` was documented "Total Liabilities / Total Equity" while being fed `BalanceSheet.debtToEquity`, which is interest-bearing debt; `debtRatio`'s "Related Metrics" repeated the same false formula. Instances six and seven of "the code is right and the comment is wrong". The trap is real — the package has **two** `debtToEquity`s, and the *free function* genuinely does use total liabilities, so the sentence is true of one and false of the other. Also fixed in the same comment: the example used `year: 2025` where the fixture is 2024 (so it returned `nil` and printed the `?? 0` fallback), and wrote `?? 0 * 100` where `??` binds looser than `*`, printing a raw ratio labelled a percentage. The sharpest assertion is that the two ratios **cross** — debt-to-assets below leverage in Q1 (0.4 vs 0.4167) and above it in Q4 (0.3774 vs 0.3561). A sign flip survives no monotone rescaling, so it witnesses two different numerators rather than one scaled twice; it was among the three tests that failed when the wrong definition was injected. |
| ~~**A4**~~ | ~~**L15** — decide 365 vs 365.25.~~ | ✅ **DONE.** The rule adopted: *a convention is at stake where a counterparty settles on the number; everywhere else 365 or 365.25 is a modelling choice and has to say so.* **Routed:** all ten `BondPricing` sites now call `DayCountConvention.yearFraction(from:to:)`, with `dayCount` a stored property on `BondLike`, `Bond`, `ZeroCouponBond` and `AmortizingBond`, defaulting to `.actual365`. Those ten were byte-identical eight-line blocks the duplication checker had already flagged as a 188-token clone — filed as style, while what it pointed at was ten independent chances to pick a different year length. Two things were wrong beyond the repetition: **365.25 is not a convention** (it is the mean Gregorian year; no standard names it), and **seconds are not days** (`timeIntervalSince` absorbs DST shifts into a calendar-day count). **Stated, not routed:** CAGR in `TimeSeriesAnalytics` (365.25 is *correct* there precisely because it is not a day count — ACT/365 would drift upward with every leap day in the window and ACT/ACT would make "2020 to 2025" depend on which years those were), `EOQModel`, `GrowthRate.daily`, `DebtInstrument`, `LeaseAccounting` ×2, `EquityFinancing`. **Cost, measured not estimated:** 12¢ / 31¢ / 55¢ at 2 / 10 / 30 years per 1,000 of face. All 70 existing bond tests pass — *because their bands are a dollar wide*, not because nothing moved; that is pinned in `theMoveIsPinned` and is evidence for F3. **`doc-claims` blocked the push, correctly**, on a guide price of $1,043.82 against a produced $1,043.66 — and pricing the guide's own example under all four conventions showed **30/360 reproduces the closed-form textbook value 1043.7603 to ten significant figures**, because the whole-period formula textbooks print *assumes* 30/360 without saying so. The guide now carries that table and the identity is asserted in `thirty360MatchesTheClosedForm`. |
| ~~**A5**~~ | ~~**L12** — decide the outlier rule.~~ | ✅ **DONE — both branches, and L12's premise is REFUTED.** The review said `detect` scores against "the series' own mean and standard deviation", so a lone outlier inflates the deviation enough to hide itself: z = 2.4694 on `[10,12,11,13,12,50,11,12]`, below 3.0, missing the 50. **Measured against the code, that is wrong.** The baseline is the `windowSize` points *before* the one under test, so a value is never inside the baseline it is judged against, and `flaggedIndices` drops already-flagged points from later windows. The 50 is flagged at every window from 2 to 5, at **z between 37 and 75**; runs of consecutive spikes are caught too. The 2.4694 is a *whole-series* z-score, which is not what the code computes. **But hunting for where the claim would be true found a sharper defect the review missed: the loop bound.** The scan starts at `windowSize`, so the leading `windowSize` points are never examined — invisible themselves, *and* inflating the standard deviation for everything after. Measured at threshold 3.0, window 4: `[12,11,13,12,30,…]` flags the 30 at **z = 25.46**; `[50,11,13,12,30,…]` — same 30, same threshold, one changed value the scan never reaches — flags **nothing at all**. **Shipped:** `ModifiedZScoreAnomalyDetector` (median/MAD, Iglewicz-Hoaglin 3.5) and `IQRAnomalyDetector` (Tukey 1.5 fences), both whole-sample so they examine every point including the first, both built on the library's own `median` and `quantile` rather than the hand-rolled median in the streaming code — which matters, because `quantile` interpolates at `p·(n-1)` and that is what reproduces the documented 14.125 fence; `sorted[3n/4]` would give 16.0. The limitation is documented on `ZScoreAnomalyDetector` with the *corrected* worked example. `RobustAnomalyDetectionTests`, 7 tests; the load-bearing one is `theScaleDoesNotChaseTheOutlier`, which pushes the spike to 50/500/5,000/50,000 and asserts the score strictly rises — a property no mean-based rule can satisfy. |
| ~~**A6**~~ | ~~**L17** — decide the counter asymmetry.~~ | ✅ **DONE — and it was not a naming question. See L18.** The asymmetry is real and is now documented on `CuttingPlaneStats`: `totalCutsGenerated` counts work *attempted*, `cuttingRounds`/`lpResolves` count work that *survived a re-solve*, with the three exits between them named (infeasible, non-optimal, throw). But measuring the scenario instead of trusting the trace showed *why* every re-solve failed: **the cuts were invalid** (L18). `withKnownIssue` is removed and the assertion stands directly, because the tolerated state is no longer reachable there — on a feasible subproblem a valid cut cannot make the LP infeasible while integer points remain, so `cuts > 0 && rounds == 0` means the cuts are wrong. **The suite's known-issue count is now 0.** |

#### Phase B — the enabling fixes

Cheap, high-information, and each may expose something. Principles 2 and 4.

| | Item | Done when |
|---|---|---|
| ~~**B1**~~ | ~~The **18 vacuous optimizer assertions**~~ | ✅ **DONE — first branch: 18 unknowns became evidence, and the optimizers were fine.** **The 7 `.rounded()` comparisons:** measured before choosing any bound. Worst real violation across all seven is **−5.07e-5**, against a form that admits **0.5**. Bisecting showed only **two of seven** need 1e-4 (`StochasticOptimizationTests:237` at −5.07e-5, `ScenarioOptimizationTests:73` at −1.87e-5); the other five hold at **1e-6**, most at ~1e-10. A single blanket tolerance would have left five assertions 100,000× weaker than the code warrants. `RobustOptimizationTests:335` is the instructive one — it read `weight.rounded() >= -1e-6`, a real tolerance the rounding had swallowed; deleting the rounding restores the author's own bound and it holds with four orders of margin. **The 11 disjunctions:** **ten optimizers genuinely converge**, so `#expect(result.converged)` is simply what the authors meant and the disjunctions hid nothing. The eleventh, `GeneticAlgorithmTests.testGPUAcceleration`, **correctly does not converge** — its config sets `generations: 10` with the comment "Keep short for testing", so the run exhausts its budget, and a GA that finishes its budget has not converged. Asserting `converged` there would assert something false; it now asserts `iterations == 10`, which is falsifiable in both directions and is the real claim a GPU-path test makes. **No solver defect found.** 7,781 tests / 700 suites, exit 0, gate 0 errors. **The 10 standing `[test-quality]` warnings did not move, and were never going to** — they name a different population (`noCombinationBeatsTheReportedScore`, `seasonalBeatsGrid`, `testDuPontImprovementStrategies`, …), same species, none among these 18. |
| **B2** | The **3 stale integer-programming assertions**, each of which names its own expectation in a comment and tests nothing. | The assertions are written. All three capabilities have shipped, so they should pass; if one does not, that is the finding. |
| **B3** | **`Phase1_CutValidityTests`** — flip 16 of 17 to `minimize: false`. **Now genuinely unblocked**: the counters work, so cut assertions can mean something. | The file's fixtures are fractional at the root, `totalCutsGenerated > 0` is asserted rather than `>= 0`, and the three deduplication tests read the cut pool. |
| **B4** | **`PerformanceOptimizationTests`** — ~17 wall-clock assertions in the regular suite, tightest 50 ms. | Timing assertions behind `.benchmarkOnly`; the correctness assertions in the same tests stay in the regular suite. A standing CI-flake source removed. |

#### Phase C — gate rules, before their sweeps

Principle 3: past ~100 sites, a sweep without a rule is a one-off.

| | Rule | Done when |
|---|---|---|
| **C1** | Nil-coalescing inside an assertion — `?? <literal>` in `#expect`. **225 sites.** | Blocking rule lands; the existing 225 are recorded as the baseline to burn down. |
| **C2** | Ambient calendar or clock in a test target. **152 sites.** | Blocking rule lands **with the bracketing carve-out**: two `Date()` readings bracketing a call assert *ordering* and are correct; flag a reading used in an arithmetic comparison. Without it the rule flags nine correct tests in `WallClockAdoptionTests`. |
| **C3** | `#expect(true)` as a test's only assertion. **75 sites.** | Blocking rule lands. |
| **C4** | **Fix the checker's nested-scope bug** — it misses assertions after a local `func` *and* inside nested `struct` suites. | Both forms are handled; the `// TEST-QUALITY: checker workaround` markers come out with it. Three files are the fixtures for the second form. |

#### Phase D — the sweeps

Mechanical, high-volume, and safe once C is in.

| | Item | Done when |
|---|---|---|
| **D1** | **53 of the 75 `#expect(true)`** → `#expect(throws: Never.self)`. They say "no-throw" in their own comments; the form is already used 11 times here. | Substituted. `LoggerTests`' 13 need a recording sink and are the remainder. |
| **D2** | **225 `?? 0`** → `try #require`. The highest-volume single item in the corpus. | Swept; C1 keeps it swept. |
| **D3** | **~152 ambient-time sites** → the shared fixed calendar. Unblocked: the source fix landed in alpha.5. | Swept; C2 keeps it swept, and ~200 lines of `DateComponents` boilerplate go with it. |
| **D4** | Ratio fixture deduplication (~115 lines × 2) and its 20 `guard let` → `try #require`. | One fixture, one value table beside it, ~60 lines lighter. |

#### Phase E — the structural test work

Highest leverage in the corpus. No dependencies beyond B.

| | Item | Done when |
|---|---|---|
| **E1** | **The gradient certificate** for L-BFGS, gradient descent, Newton-Raphson, multi-start. Replaces ~40 distance-to-known-minimum assertions with `‖∇f(x*)‖ < tol` — the condition that *defines* a minimum, and one that extends to problems with no known answer. | Every smooth problem asserts the gradient norm against the optimizer's own tolerance. `gradientNorm < 0.1` already exists in two files at the wrong bound — promote it. |
| **E2** | **The two degenerate portfolio fixtures.** Three tests are vacuous *because of the fixture*; no assertion change rescues them. | Nonzero, unequal variances and a known covariance, so the Sharpe ratio and the frontier both exist. |
| **E3** | **DEA units invariance** for SBM and super-efficiency. CCR and BCC have it. | All four models covered. Cheapest high-value addition in that domain: a scaling error breaks it while leaving every score plausible. |
| **E4** | **ETS exact-recovery oracle.** Not the phase defect — ETS delegates to `HoltWintersModel` and inherits that fix — but the parameter *search* is untested. | A noiseless series in the model's span is recovered exactly by the fitted parameters. |
| **E5** | **Interval calibration** for `EmpiricalIntervalsTests`. Same shape as the antithetic-SE defect: a reported uncertainty nothing measures against realised spread. | An 80% interval contains the truth about 80% of the time over a seeded synthetic series, bounded by the binomial standard error. |
| **E6** | **Driver composition identities.** The seeding contract already makes them cheap. | `identical(composite.sample(seed:), a.sample(seed:) op b.sample(seed:))` — catches a composite that re-draws its operands, which no band assertion can. |

#### Phase F — exactness

| | Item | Done when |
|---|---|---|
| **F1** | **The operations/inventory batch.** No defects, tolerance-only findings, and a complete verified value table. **The cheapest domain to finish outright.** | Its table is transcribed; the EOQ optimality identity is asserted at 1e-12 rather than ±1.0, and the 0.5 stockout probability exactly. |
| **F2** | **The five comment-arithmetic errors**, where the code is right and the comment is wrong: `npvExcel` ×2, the H-model test, `TVMReferenceTests`' header, `ClassifierEvaluationTests`' tie values. | Each comment states the value the code produces, verified independently. |
| **F3** | **T2's remainder**, ~150 band assertions with verified reference values already supplied. | Bands become exact; binary-exact cases use `identical`, rationals a tight relative bound, statistics a standard-error multiple. |

#### Phase G — hygiene

| | Item | Done when |
|---|---|---|
| **G1** | 10 `.disabled` and 30 commented-out `@Test`. | Each is fixed and re-enabled, converted to `withKnownIssue` with a `.bug(…)`, or deleted. None is left with no record of why. |
| **G2** | **530 type-only error assertions** against 99 that pin a value. Not an invention problem — the technique is already in `KMeansTests`, the dispersion tests and the marketing batch. | The `(any Error).self` sites go first; the rest assert the case, and the associated values where they carry information. |

---

### 5.1 The three tracks, run in parallel

**Track FIX — the only one that makes 3.0.0 correct. Start here.**

1. ~~**B1 (L11)**~~ — ✅ **DONE `4b666601`.**
2. ~~**B2 + B6 (L7 / L7a)**~~ — ✅ **DONE.**
3. ~~**B3 (L13)**~~ and ~~**B4 (L1)** + **L2**~~ — ✅ **DONE.**
4. ~~**B5 (Q5)**~~ — ✅ **DONE.** Not documentation: a discarded statistics object (L16), plus L17 recorded.
5. Then the DOCUMENT set, and the two breaking API items that belong in the major.

**Track FIND — keep the reviews coming.** §2b is the argument: they are the only detector that finds
semantic defects, and four of the six blockers came from them. Validation stays mandatory —
22 for 22 reviews contained something that changed the fix.

**Track PREVENT — gate rules, sized by §2a and carved by §7.** Not a correctness mechanism; a
regrowth mechanism. Land the three highest-volume rules before their sweeps, which are AFTER anyway.

---

### What moved, and why

| Item | Was | Now | Reason |
|---|---|---|---|
| The whole Wave 0/1/2 structure | leverage-ordered | **cut-line ordered** | the goal is a tag, not a score |
| 18 vacuous optimizer assertions | Wave 0.3 | **AFTER** | they hide an unknown, not a known wrong number |
| The gradient certificate | Wave 2 item 6 | **AFTER** | highest leverage, zero bearing on correctness today |
| `?? 0` and calendar sweeps | Waves 3 | **AFTER** | under-tested is not wrong |
| L2 / L3 | Wave 1 | **DOCUMENT, in 3.0.0** | breaking API shapes, so the major is the moment |
| Q5 / Q6 | open questions | **B5 / B6, blocking** | one may be an inert feature, one is a shipped defect |

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
