# BusinessMath time-series test suite: consolidated review

*September 2026. Covers 33 test files in two batches: time value of money, trend, seasonality and forecast metrics (13 files); and the period/calendar layer, TimeSeries core, formula engine and stationarity diagnostics (20 files). Companion to the distribution, simulation and statistics reviews; uses the same TestSupport vocabulary.*

*How the numbers were checked. Every reference value was recomputed in Python. Two questions about the library's internals could not be answered from the tests alone and are flagged as **open** in §2 — the recommendations that depend on them state both branches.*

## 1. Summary

This domain divides into three groups with markedly different quality.

**The formula engine is the strongest work here.** FormulaEvaluatorTests, FormulaConditionalTests and FormulaFunctionCallTests name the defect each test guards (the bracketed-identifier lexer bug, `IF` evaluating both branches, argument-count validation), separate parse errors from evaluation errors, and test operator precedence and associativity as properties rather than by example. PeriodSemiannualAndCustomTests is the model for the calendar layer: exact labels, exact arithmetic and distance, negative cases (`Period.quarter(...).semiannuals().isEmpty`), and fiscal mappings with the reasoning written out. AutocorrelationTests pins hand-computed ACF values that discriminate between the two standard divisors — I verified that [1,2,3,4] gives 0.25, −0.30, −0.45 under the 1/n convention and 0.333, −0.60, −1.80 under 1/(n−k), so the test does fix the convention. TrendModelConfidenceIntervalTests derives its interval width from the t distribution instead of hardcoding 1.96.

**The financial functions are mathematically the easiest part of the corpus and the most loosely tested.** Every answer is a closed form, and about 60 assertions use a $0.01 tolerance against hand-rounded comments while roughly 45 more assert only finiteness, a sign, or an ordering. One of those comments is arithmetically wrong, and the loose tolerance hides it (§3 item 1).

**The period and calendar layer has a systemic reproducibility problem.** `Calendar.current` appears 73 times and `Date()` 16 times, which makes these tests depend on the runner's time zone, calendar identifier and locale. Only XNPVTests uses a fixed `Calendar(identifier: .gregorian)`.

Cutting across all three: **93 assertions in the TimeSeries files wrap a subscript in `?? 0`**, which converts a missing lookup into a passing comparison. That is the most common defect shape in the domain and the one most worth fixing first.

The highest-leverage work, in order:

1. Resolve the wrong NPV expectation in §3 item 1 — it is either a test bug or a library bug.
2. Replace the 93 `?? 0` sites with `try #require`.
3. Introduce a fixed test calendar and answer the two open questions in §2.
4. Replace the closed-form tolerances with the exact values in Appendix A.
5. Fix the assertions that cannot fail (§5).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Parser and evaluator behaviour | FormulaEvaluatorTests, FormulaConditionalTests |
| Period semantics and arithmetic | PeriodSemiannualAndCustomTests |
| A statistic against a published critical value | LjungBoxTests, StationarityTests |
| A convention-fixing hand computation | AutocorrelationTests |
| An interval derived rather than hardcoded | TrendModelConfidenceIntervalTests |
| Fixed-calendar date construction | XNPVTests |

## 2. Open questions about the library

Neither can be settled from the tests, and both change what the fix should be.

**Q1. Does `Period` arithmetic go through `Calendar` components, or does anything add fixed second counts?**

Every `+`/`-` test checks the result's date components, so an implementation that added 86,400 seconds per day would pass all of them when run in UTC and fail across a daylight-saving boundary. No test crosses one. A daily period on 2025-03-09 in `America/New_York` is 23 hours; on 2025-11-02 it is 25.

- If arithmetic uses components: add DST tests to prove it, and the issue is test coverage only.
- If anything uses fixed seconds: that is a library defect, and the DST test will find it.

**Q2. Do `Period.startDate`/`endDate` and `FiscalCalendar.fiscalYear(for:)` read `Calendar.current` internally, or take a calendar?**

- If they take one: a fixed test calendar (§4) fixes the 73 sites and the library is fine.
- If they read the ambient calendar: the same computation returns different answers for different users' regions, which is a library defect a test-side fix cannot address. `FiscalCalendar` should take a `Calendar` parameter defaulting to `.current`, and `Period.day(_:)` should document which zone interprets the date.

## 3. Library defects and API issues

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`npvExcel` at 8% may be wrong, or its test is** | `npvExcelDocumentationExample` expects 13234.62. The correct value is 13233.246964385507. The comment's own arithmetic is the source: it gives 9200/1.08² as 7888.89 (correct: 7887.517…) and sums to 23234.62 where the true sum is 23233.246964385507. Excel's `=NPV(8%,8000,9200,10000)` returns 23233.25. The ±2.0 tolerance hides the 1.37 gap. | Recompute. If the implementation returns 13233.25, fix the test; if it returns 13234.62, fix the implementation. |
| 2 | Two more comments carry the same error | `npvExcelComparison` calls the 10% three-year total 1306.00 (correct: 1307.287753568743); `npvExcelMultiYear` says 11306.00 (correct: 11307.287753568744). Both pass on ±2.0. | Use the exact values. |
| 3 | `additiveDecomposition`'s fixture does not match its comment | The comment states the trend is 100, 110, 120, 130 in year 1 and 140, 150, 160, 170 in year 2. Subtracting the stated seasonal pattern from the values gives 100, 110, 120, 130 then 110, 120, 130, 140 — the trend rises 10 per *year*, not per quarter. | Correct the comment or the fixture, then assert the recovered components against the known ones. |
| 4 | `multiplicativeDecomposition`'s fixture does not match its multipliers | With base 100, 110, 120, 130 and multipliers 1.0, 1.2, 0.8, 1.0, year 1 (100, 132, 96, 130) matches. Year 2's values (140, 180, 128, 170) imply a base of 140, 150, 160, 170 — a 40 jump between years. This is why the tolerance had to be relaxed to 1.0. | Rebuild the fixture from a stated trend and multipliers; the tolerance then returns to ~1e-12. |
| 5 | Mixed period types are unsupported and unpinned | `mixedPeriodTypes` is commented out with: "supported, but currently trigger a Strideable issue when Swift's stdlib tries to optimize operations. For now, users should use time series with consistent period types." | Either pin the current behaviour with `withKnownIssue` and a `.bug(…)` trait, or make the constraint explicit in the API so it fails at compile time rather than at optimisation time. A capability recorded only in a comment will be rediscovered by a user. |
| 6 | `MonthDay` accepts impossible dates | The comment says preconditions cover month 1–12 and day 1–31, and that these "should be caught during testing" — but nothing tests them, and a 1–31 range check admits February 30. | Test the preconditions with `#expect(processExitsWith:)` (Swift 6.2). Decide what a February 29 fiscal year-end means in a non-leap year; that is a real convention and currently undefined. |
| 7 | `npvExcel`'s discounting convention is a trap | It discounts the first element by one period, so passing an array that begins with the initial outlay silently misprices the project. `npvExcelVsStandard` depends on this behaviour. | Document prominently. Excel users hit this constantly. |
| 8 | `annualPeriodMapping` may be pinning a fallback | An annual period maps to fiscal period 1. | Confirm this is intended rather than an unhandled case returning a plausible value — the same question as a `default:` branch that happens to look right. |
| 9 | `profitabilityIndex` with no initial investment | `profitabilityIndexNoInvestment` accepts `isInfinite \|\| > 1000`. PV of [100, 200, 300] at 10% with no outlay is 481.59, so PI is genuinely infinite. | Pin infinity, or throw. Another contract-free disjunction. |

## 4. The calendar dependence

`Calendar.current` by file: PeriodArithmeticTests 27, FiscalCalendarTests 23, PeriodTests 19, PeriodSemiannualAndCustomTests 2, IntegrationTests 1, TimeSeriesTests 1. Plus 16 uses of `Date()`.

Three ambient settings leak in:

1. **Time zone.** `calendar.date(from:)` with year/month/day resolves to local midnight. A `Period.day` boundary computed in one zone and compared against a date built in another can land on the previous day. CI runners are usually UTC; developer machines usually are not.
2. **Calendar identifier.** `Calendar.current` follows the user's region. Under a Japanese, Buddhist or Islamic calendar, `components.year = 2025` denotes a different year, and `fiscalYear(for:) == 2025` fails.
3. **First weekday and locale.** Anything computing week boundaries shifts between the US (Sunday) and ISO (Monday) conventions.

None of this fails today because everyone runs a similar configuration — which is precisely the latent-failure shape the corpus's own `srand48` and CI-timing comments describe.

The fix, in TestSupport:

```swift
/// One calendar for every date-based test, so a test's result does not depend
/// on the region, time zone or locale of the machine that runs it.
public let testCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    c.locale = Locale(identifier: "en_US_POSIX")
    c.firstWeekday = 1
    return c
}()

public func date(_ y: Int, _ m: Int, _ d: Int,
                 _ hh: Int = 0, _ mm: Int = 0, _ ss: Int = 0) -> Date {
    var c = DateComponents()
    (c.year, c.month, c.day, c.hour, c.minute, c.second) = (y, m, d, hh, mm, ss)
    return testCalendar.date(from: c)!
}
```

This also removes roughly 200 lines of repeated `DateComponents` boilerplate: the 30-line pattern in each FiscalCalendarTests quarter test becomes one line. PeriodSemiannualAndCustomTests already has a private `date(_:_:_:)` helper doing exactly this — promote it.

**`Date()` in 16 places** is the related problem. `periodDate`, `dailyProductionScenario` and the several `Period.day(Date())` tests behave differently when run within a second of midnight or across a DST transition. Use a fixed date.

**Missing calendar edge cases** throughout: DST boundaries (both directions), a leap day as a period boundary rather than merely a member, the 23:59:59.999 end-of-period instant, and periods spanning a year boundary in a non-December fiscal year.

## 5. Assertions that cannot fail

### 5.1 The `?? 0` pattern — 93 sites

```swift
#expect(abs((ts[jan] ?? 0) - 0.0) < 1e-6)   // zeroValues
```

If the subscript returns nil, this passes. `zeroValues` is the worst case, since the fallback equals the expected value exactly, but every one of the 93 sites converts "the period is missing" into "the value was right". The fix is uniform:

```swift
#expect(identical(try #require(ts[jan]), 0.0))
```

`rollingSumEqualsTotalWhenWindowIsFull` and `fillPreservesMetadata` already use `try #require(roll[lastPeriod])`, so the pattern is established in the same file — it just was not applied retroactively.

### 5.2 Field-storage tests — about 30

FiscalCalendarTests opens with four tests that construct `MonthDay(month: 9, day: 30)` and assert the fields are 9 and 30, repeated for December 31, February 28 and June 30, then again in `appleFiscalCalendar` and `standardCalendarYearEnd`. TimeSeriesTests' `metadataCreation` and `metadataDefaults` are the same shape. `createFirstHalf`/`createSecondHalf` partly are, though they also assert the derived `month` (1 and 7), which is real.

The valuable tests in FiscalCalendarTests are the quarter mappings, the September 30 / October 1 boundary pair, and the `periodInFiscalYear` mappings. The suite would be stronger as one parameterised test over `(yearEnd, date, expectedFY, expectedQuarter, expectedMonth)` covering standard, September, June and March year-ends plus the four transition boundaries.

### 5.3 Encoding tests that assert only non-emptiness

`encodingToJSON` (FiscalCalendar) and `encodeToJSON` (Period) assert `data.count > 0`, true of any encoding. The round-trip tests beside them cover the real property; where the type is Equatable, `#expect(decoded == original)` states it in one line, which `codableRoundTrip` in PeriodTests already does correctly. Keep one decode-from-literal-JSON test per type — `decodingFromJSON` — since that is the part a refactor can silently break.

### 5.4 Structurally true assertions

| Test | Why it cannot fail |
|---|---|
| `irrNPVRelationship`, `npvZeroAtIRR` | True by construction, not by implementation. `npvZeroAtIRR`'s ±1.0 on a $1,000 investment is also ~1e10 looser than the solver's own tolerance; at the true IRR the NPV is about 1e-10. |
| `mirrLowerThanIRR` | Holds identically whenever the reinvestment rate is below the IRR. |
| `npvExcelVsStandard` | `excelNPV > standardNPV` holds for any negative first flow. |
| `profitabilityIndexBreakEven` | Wraps its only assertion in `if abs(npvValue) < 10.0`. The NPV there is −45.45, so nothing is asserted. Break-even for that shape is 576.19 per period. |
| `seasonalIndicesScaleInvariant`, `seasonalIndicesPartialTrailingYear` | Contain `#expect(true) // TEST-QUALITY: checker workaround`. Both have real assertions after a nested `func` — this is the nested-scope gate bug, not a test defect. |
| `decompositionPreservesMetadata` | Asserts that component names contain "Trend", "Seasonal", "Residual" — string formatting. |
| ~12 finiteness-only tests | `npvNegativeEnding`, `npvExcelMonthly`, `npvSmallCashFlows`, `profitabilityIndexMultipleInvestments`, `softwareProjectScenario`, `npvTimeSeriesMonthly`, and others. |
| `largeValues` | Stores 1e9 and reads it back at ±1e-2. |
| `timeSeriesNPVWorkflow`, `historicalToForecastWorkflow` | Assert only `npv > 0`, `irr > 0.10`, `pv > 0`, `forecastGrowth > 0`. An end-to-end workflow with four sign checks. |

### 5.5 Skip-on-NaN loops

`additiveDecomposition` and `multiplicativeDecomposition` both `continue` when the trend is NaN. A centred moving average is undefined for the first and last `periodsPerYear/2` points, so on 12 quarterly observations that skips 4 of 12 — and the tests never assert *which* indices are NaN, only reconstructing the remaining 8. `iceCreamSeasonality` has the same `continue` in its monotonicity loop.

Two fixes: assert exactly which indices are NaN, and `#require` the count of reconstructed points so a change in edge handling cannot silently empty the loop.

More substantively, both decomposition fixtures are built from a stated trend and seasonal pattern, so the recovered seasonal indices should come back as [1.0, 1.2, 0.8, 1.0] or [+10, +20, −10, −20]. Reconstruction alone holds for any decomposition that partitions correctly, including one that assigns trend variation to the seasonal term — the same weakness the statistics review identifies in the ANOVA partition tests.

## 6. Closed forms checked as approximations

Roughly 60 assertions in the financial files use a $0.01 tolerance against values computable exactly. Appendix A has the full list; the pattern:

| Test | Current | Exact |
|---|---|---|
| `npvSimple` | ±0.01 | 41.32231404958662 |
| `paymentSimpleLoan` | ±0.01 | 188.7123364401099 |
| `paymentMortgage` | ±0.01 | 1193.5382386636345 |
| First-payment interest, car loan | `> 0` | 150.0 exactly |
| Total interest, 60-month loan | `> 1000, < 1500` | 1322.7401864065941 |
| 401(k) projection | `> 500_000` | 609985.4978879724 |
| `irr` 3-year $400 | ±0.001 | 0.097010257403 |
| `cagr` 5M→12.5M over 7 years | ±0.0001 | 0.13985228104759662 |
| `applyGrowth` continuous | ±1.0 | 3320.116922736547 |

Several are exact in binary or simple fractions and should use `identical` or `exactlyEqual`: `npvZeroRate` = 200, `npvAllZero` = 0, `npvHighRate` = 0, `npvExcelZeroRate` = 1200, `npvExcelSingleFlow` = 1000, `npvSingleCashFlow` = −1000, and the zero-rate payment and future-value cases.

The suite-level `let tolerance: Double = 0.01` properties in most of these files should disappear for pure arithmetic and become per-computation relative bounds elsewhere.

## 7. Coverage gaps

**Financial functions.** `payment` at rate = 0 and n = 0; `irr` with all-positive flows, with multiple sign changes (multiple roots), and with no sign change (should throw); `xnpv`/`xirr` with unsorted or duplicate dates; `cagr` with a zero or negative beginning value; `growthRate` from zero.

**Seasonality.** `periodsPerYear` of 0 or 1; a series whose length is not a multiple of the cycle (partially covered by `seasonalIndicesPartialTrailingYear`); additive decomposition of data with a zero or negative level, where a multiplicative index is undefined.

**TimeSeries.** `range(from:to:)` with periods absent from the series; `aggregate` with a target period finer than the source; `fillForward` when the first period is missing (nothing to carry); duplicate periods in the initialiser; mismatched `periods`/`values` lengths.

**Period.** Non-sorted input to the initialiser despite ordering assumptions; `distance(to:)` overflow at extreme years; subdivision of a custom period.

**Formula engine.** Already strong; the gap is deeply nested expressions and the recursion limit.

## 8. Smaller items

- **Error specificity.** About 20 type-only assertions (`SeasonalityError.self`, `FinancialError.self`, plus the formula files' — which do better, distinguishing parse from evaluation). The formula files' approach is the model.
- **`import TestSupport  // Cross-platform math functions`** in IntegrationTests: the comment is wrong, as elsewhere in the corpus. The import is for the assertion vocabulary.
- **Test names quoting numbers.** "MonthDay February 28", "NPV for 3-year investment: -10000, +3000, +4200, +6800" — the stale-name risk the gate rule from the probability batch catches if a body changes.
- **`dailyProductionScenario`** asserts an average of 1085.71 at ±1.0; the exact value is 1085.714285714286 (7600/7).
- **Suite organisation.** `Period` behaviour is spread across PeriodTests, PeriodArithmeticTests, PeriodTypeTests and PeriodSemiannualAndCustomTests with overlapping coverage of arithmetic and subdivision; the semiannual file is the best of the four and the natural destination.

## 9. Quality-gate rules this domain adds

Beyond the rules already proposed:

1. **Nil-coalescing inside an assertion (blocking).** Flag `?? <literal>` in any `#expect` operand. 93 sites here, and the fix is always `try #require`. This is the highest-volume single rule in the corpus.
2. **Ambient calendar or clock in a test (blocking).** Flag `Calendar.current`, `Date()`, `TimeZone.current` and `Locale.current` in test targets; require the fixed test calendar. 89 sites here.
3. **Skip-on-NaN in a loop (blocking).** Extends the silent-skip rule: `if x.isNaN { continue }` inside a loop containing the test's only assertions, with no assertion about how many iterations ran.
4. **Comment arithmetic versus asserted value (advisory).** Where a comment contains a chain like `a + b + c = d` and the assertion compares against `d`, parse and check it. This is what would have caught §3 item 1. The practical narrower form: flag an assertion whose expected value is a decimal literal with 2–6 significant digits and whose tolerance is looser than half a unit in its last digit — the reverse of the probability-batch rule, and the shape of every `± 2.0` on a penny-precise value here.
5. **Encoding asserted only by size (advisory).** Flag `data.count > 0` as the sole assertion after an `encode` call.
6. **Field-storage tests (advisory).** Flag a test whose every assertion compares a property against a literal passed to the initialiser in the same function. About 30 sites.

## 10. Order of work

1. **Resolve §3 item 1.** It is either a wrong test or a wrong library function, and $1.37 on a documentation example is the kind of thing users reproduce.
2. **Answer the two open questions in §2**, then add DST and region tests accordingly.
3. **Replace the 93 `?? 0` sites** with `try #require`. Mechanical and high-value.
4. **Introduce the fixed test calendar** and convert the 89 ambient-time sites.
5. **Fix the tests that cannot fail** (§5): the finiteness-only assertions, the break-even guard, the encoding-size tests, the skip-on-NaN loops, and the `#expect(true)` markers once the nested-scope gate bug is fixed.
6. **Replace the closed-form tolerances** with Appendix A values, and rebuild the two decomposition fixtures so the recovered components can be asserted.
7. **Close the coverage gaps** in §7, starting with `irr`'s multiple-root and no-root cases.
8. **Consolidate** the four `Period` suites, and promote the semiannual file's `date` helper.

## Appendix A. Verified reference values

All recomputed in Python.

### A.1 NPV and related

| Quantity | Value |
|---|---|
| `npv(0.10, [-1000, 600, 600])` | 41.32231404958662 |
| `npv(0.10, [-10000, 3000, 4200, 6800])` | 1307.287753568743 |
| `npv(0.10, [-1000, 400, 400, 400])` | −5.259203606311189 |
| `npvExcel(0.10, [400, 400, 400])` | 994.7407963936888 |
| `npvExcel(0.10, [3000, 4200, 6800])` | 11307.287753568744 |
| `npvExcel(0.08, [8000, 9200, 10000])` | 23233.246964385507 (test expects 23234.62 — see §3 item 1) |
| PI, `[-1000, 600, 600]` at 10% | 1.0413223140495866 |
| PI, `[-1000, 400, 400]` at 10% | 0.6942148760330579 |
| PI break-even payment for a 2-period $1,000 outlay at 10% | 576.19 per period |
| PI of `[100, 200, 300]` at 10%, no outlay | PV 481.59; PI infinite |

### A.2 IRR and MIRR

| Cash flows | IRR |
|---|---|
| `[-1000, 400, 400, 400]` | 0.097010257403 |
| `[-1000, 600, 600]` | 0.130662386292 |
| `[-1000, 200, 200, 800]` | 0.076347479202 |
| `[-5000, 1000, 2000, 3000, 1000]` | 0.143061180358 |
| `[-100000, 12000×4, 130000]` | 0.146863173103 |
| `[-50000, 20000, 25000, 30000]` | 0.216477854184 |
| `[-200000, 30000×10]` | 0.081441656464 |
| MIRR, `[-1000, 400, 400, 400]`, both rates 10% | 0.09806823486065386 |
| MIRR, same flows, finance 12% / reinvest 8% | 0.09098975834465173 |

### A.3 Payments and amortisation

| Quantity | Value |
|---|---|
| `payment(10000, 5%/12, 60)` | 188.7123364401099 |
| `payment(250000, 4%/12, 360)` | 1193.5382386636345 |
| `payment(30000, 6%/12, 60)` | 579.9840458828482 |
| First interest / principal, $10,000 loan | 41.666666666666664 / 147.04566977344325 |
| Final interest / principal, $10,000 loan | 0.7830387404152076 / 187.9292976996947 |
| Total interest, $10,000 over 60 months | 1322.7401864065941 |
| Cumulative interest / principal, months 1–12 | 458.99550746532736 / 1805.5525298159916 |
| Cumulative interest / principal, months 49–60 | 60.15734037457867 / 2204.3906969067402 |
| Mortgage first interest / principal | 833.3333333333334 / 360.20490533030113 |
| Mortgage final interest / principal | 3.9652433178830955 / 1189.5729953457515 |
| Car loan first interest / principal | 150.0 / 429.98404588284825 |
| Car loan total interest | 4799.042752970898 |

### A.4 Future and present value

| Quantity | Value |
|---|---|
| FV lump sum, 1000 at 10% for 5 | 1610.5100000000004 |
| PV lump sum, same | 620.9213230591549 |
| FV ordinary annuity / annuity due, 100 at 10% for 5 | 610.5100000000006 / 671.5610000000007 |
| PV ordinary annuity / annuity due, same | 379.07867694084507 / 416.9865446349296 |
| FV / PV of 1000 monthly for 12 months at 1% | 12682.503013196976 / 11255.077473484642 |
| FV of 200 monthly for 60 months at 0.5% | 13954.0061019723 |
| 401(k): 500/month, 30 years, 7% | 609985.4978879724 |
| College fund: 300/month, 18 years, 6% | 116205.95832214215 |
| Lump sum 10000 at 8% for 20 years | 46609.57143849308 |
| 1000 at 5% for 100 years | 131501.257846304 |
| Lottery PV: 50000/year, 20 years, 6% | 573496.0609282631 |
| Retirement PV: 50000/year, 30 years, 4% | 864601.6650332245 |
| Bond: 50 coupon, 10 years, 6%, par 1000 | 926.3991294858529 |

### A.5 Growth

| Quantity | Value |
|---|---|
| CAGR 10000→15000 over 5 | 0.08447177119769855 |
| CAGR 5M→12.5M over 7 | 0.13985228104759662 |
| CAGR 0.001→0.002 over 2 | 0.41421356237309515 (√2 − 1) |
| CAGR 1B→2B over 5 | 0.1486983549970351 |
| `growthRate(123.45, 145.67)` | 0.17999189955447537 |
| `applyGrowth` 1000 at 12%: quarterly / monthly / daily / continuous | 1125.50881 / 1126.8250301319697 / 1127.4746156384 / 3320.116922736547 |
| Semiannual, 1000 at 8% | 1081.6000000000001 |
| Revenue 1M at 15% for 5 | 2011357.1874999993 |
| Population 1M at 2% for 10 | 1218994.4199947573 |
| Investment 10000 at 7% for 10 | 19671.513572895663 |
| Inflation 100 at 3% for 20 | 180.61112346694148 |
| 100 at 1% for 100 | 270.48138294215283 |

### A.6 Time series and diagnostics

| Quantity | Value |
|---|---|
| ACF of [1, 2, 3, 4], 1/n convention (what the test pins) | 0.25, −0.30, −0.45 |
| Same under 1/(n−k) | 0.333…, −0.60, −1.80 |
| `dailyProductionScenario` mean | 7600/7 = 1085.714285714286 |
| `monthlyRevenueScenario` total | 1,970,000 exactly |
| Q1 2025 day count / 2025 day count | 90 / 365 |
| Quarterly→semiannual aggregation of [10, 20, 30, 40] | 30 and 70 exactly |
