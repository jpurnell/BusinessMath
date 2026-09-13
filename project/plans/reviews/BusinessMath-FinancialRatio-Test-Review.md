# BusinessMath financial ratio tests: review

*September 2026. Covers 6 files: LiquidityRatiosTests, ProfitabilityRatiosTests, SolvencyRatiosTests, EfficiencyRatiosTests, DSCR_EdgeCaseTests, RatioConvenienceFunctionsTests (two suites). Companion to the distribution, simulation, statistics, time-series and Bayes reviews.*

*All reference values below were recomputed in Python from the suite's own shared fixture.*

## 1. Summary

This suite is split across two generations, and the split runs *inside* one file.

`RatioConvenienceFunctionsTests` (the first suite) checks that each ratio is present and falls in a plausible band: gross margin between 0.5 and 0.7, ROA above 0.05, current ratio above 1.0. `RatioConvenienceFunctionsAdditionalTests` (the second suite in the same file) computes the same quantities by hand and asserts them at 1e-9 to 1e-12. The second suite is the model; the first is largely superseded by it.

The suite's best work is `DSCR_EdgeCaseTests`. It pins the `diff(lag: 1)` contract (four periods in, three out, Q1 absent), then walks a CPLTD reclassification through three quarters with exact expected values of 6.0×, 12.0× and 6.0×. The 12.0× quarter is the one that matters: it is the period with no principal payment, so a formula that silently substituted a prior period's principal would give 6.0× and the test would catch it.

The main gaps:

1. **One assertion contradicts standard accounting and passes only because of a definitional choice** (§2 item 1). `debtToAssets + equityRatio == 1.0` holds in the test at ±0.01 — but with the fixture's numbers it holds only if `debtToAssets` counts *all* liabilities, while `debtToEquity` in the same result counts only long-term debt. Two different debt definitions in one struct.
2. **About 40 band assertions** where the exact value is one division away.
3. **The `guard let … else { Issue.record(); return }` pattern appears 20 times** in the first suite, where `try #require` is one line and the second suite already uses it.
4. **The day-count convention is never pinned**, so DSO/DIO/DPO could be on a 90-day quarter or a 365-day year and no test would notice. The CCC identity test cannot see the difference because the convention cancels.

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`debtToAssets` and `debtToEquity` appear to use different debt definitions** | Fixture Q1: total assets 3,000,000; long-term debt 1,000,000; accounts payable 150,000; equity 1,850,000. `debtToEquity` is asserted `> 0.0` only, but 1,000,000/1,850,000 = 0.5405 uses LTD alone. `testSolvencyRatios` asserts `debtToAssets + equityRatio ≈ 1.0`; equity ratio is 1,850,000/3,000,000 = 0.6167, so the identity requires `debtToAssets` = 0.3833 = (1,000,000 + 150,000)/3,000,000 — all liabilities. With LTD alone it would be 0.3333 and the sum would be 0.95, failing the ±0.01 bound. | Confirm which is intended. If both definitions are deliberate, document them and rename one (`longTermDebtToEquity`). If not, this is a live bug that the loose `> 0.0` assertion on `debtToEquity` is concealing. |
| 2 | **The day-count convention for DSO/DIO/DPO is unpinned** | On a 90-day quarter: DSO 27.0, DIO 45.0, DPO 33.75, CCC 38.25. On 365 days: DSO 109.5, DIO 182.5, DPO 136.875, CCC 155.125. `testEfficiencyRatios` asserts only `> 0.0` for each, then checks CCC = DIO + DSO − DPO — an identity that holds under *either* convention, since the day count is a common factor. | Pin one set of values. A quarterly statement reporting DSO of 109.5 days is a reasonable choice (annualised) or an error (mixing a quarterly flow with an annual day count), and nothing currently distinguishes them. |
| 3 | **Gross margin for a company with no COGS account is 1.0, not nil** | `testServiceCompanyWithoutOptionalAccounts` builds a service company with no COGS and checks that `inventoryTurnover`, `receivablesTurnover`, `daysSalesOutstanding`, `daysInventoryOutstanding`, `daysPayableOutstanding` and `cashConversionCycle` are all nil — good, discriminating tests. It never checks `grossMargin`, which for revenue 500,000 and no COGS is (500,000 − 0)/500,000 = 1.0. | Decide whether a 100% gross margin is the right answer for a service company or whether gross margin should be nil when COGS is absent, and assert it. This is the same optional-versus-defaulted question the file handles well everywhere else. |
| 4 | **`interestCoverage` uses EBIT, and the test confirms it — but `debtServiceCoverage` uses EBITDA** | `testInterestCoverageExact` pins EBIT/Interest = 250,000/25,000 = 10.0 exactly. `testSolvencyRatiosWithDSCR` asserts only `dscr > 1.0`; the value is EBITDA/(P+I) = 300,000/35,000 = 8.571428571428571. | Both conventions are defensible and both are in use, but the asymmetry should be documented and the DSCR value pinned. |
| 5 | **`valuationMetrics` EV formula is asserted, EV/EBITDA is not** | `testValuationMetrics` pins EV = 50,000,000 + 1,000,000 − 500,000 = 50,500,000 at ±1.0, which is good. `evToEbitda` and `evToSales` are asserted `> 0.0`; they are 168.33333333333334 and 50.5. | Pin both. EV/EBITDA is the metric most sensitive to a wrong EBITDA definition. |
| 6 | **`testProfitabilityRatios` asserts ROE > ROA "due to leverage"** | True here (0.0961 vs 0.0593), but the assertion holds for any leveraged company and would also pass if both were computed wrongly by the same factor. | Pin both values. |
| 7 | **`#expect(true) // TEST-QUALITY: checker workaround`** in `testNoNaNOrInfinite` | The nested `func isFinite` triggers the checker's scope bug, as elsewhere in the corpus. | Fixed by gate rule 1 (assertion reachability over the call graph); remove the marker then. |

## 3. Exact values for the band assertions

All computed from the shared fixture (Q1: revenue 1,000,000; COGS 400,000; opex 300,000; depreciation 50,000; interest 25,000; tax 47,250; cash 500,000; receivables 300,000; inventory 200,000; PP&E 2,000,000; payables 150,000; LTD 1,000,000; equity 1,850,000).

| Metric | Current assertion | Exact value |
|---|---|---|
| Net income | — | 177,750 |
| EBIT | — | 250,000 |
| EBITDA | — | 300,000 |
| Total assets | — | 3,000,000 |
| `grossMargin` | `> 0.5 && < 0.7` | 0.6 exactly |
| `netMargin` | `> 0.15 && < 0.20` | 0.17775 |
| `roa` | `> 0.05` | 0.05925 |
| `roe` | `> 0.08` | 0.09608108108108109 |
| `roic` | `> 0.05` | depends on the invested-capital definition — worth pinning for that reason |
| `currentRatio` | `> 1.0` | 20/3 = 6.666666666666667 |
| `quickRatio` | `> 0.0`, `< currentRatio` | 16/3 = 5.333333333333333 |
| `cashRatio` | `> 0.0`, `< quickRatio` | 10/3 = 3.3333333333333335 |
| `workingCapital` | `> 0.0` | 850,000 exactly |
| `debtToEquity` | `> 0.0` | 0.5405405405405406 (LTD basis) |
| `debtToAssets` | `> 0.0 && < 1.0` | 0.3833333333333334 (all liabilities) or 0.3333333333333333 (LTD) — see §2 item 1 |
| `equityRatio` | `> 0.0 && < 1.0` | 0.6166666666666667 |
| `interestCoverage` | `> 1.0` | 10.0 exactly (already pinned in the second suite) |
| `debtServiceCoverage` | `> 1.0` | 8.571428571428571 |
| `assetTurnover` | `> 0.0` | 1/3 = 0.3333333333333333 |
| `inventoryTurnover` | `> 0.0` | 2.0 exactly |
| `receivablesTurnover` | `> 0.0` | 10/3 = 3.3333333333333335 |
| `daysSalesOutstanding` | `> 0.0` | 27.0 (90-day) or 109.5 (365-day) |
| `daysInventoryOutstanding` | `> 0.0` | 45.0 or 182.5 |
| `daysPayableOutstanding` | `> 0.0` | 33.75 or 136.875 |
| `cashConversionCycle` | identity only | 38.25 or 155.125 |
| `marketCap` | `== 50_000_000` (already exact) | 50,000,000 |
| `priceToEarnings` | `> 0.0` | 281.29395218002816 |
| `priceToSales` | `> 0.0` | 50.0 exactly |
| `priceToBook` | `> 0.0` | 27.027027027027028 |
| `enterpriseValue` | ±1.0 of 50,500,000 | 50,500,000 exactly |
| `evToEbitda` | `> 0.0` | 168.33333333333334 |
| `evToSales` | `> 0.0` | 50.5 exactly |
| Service company net income | — | 158,000 |

Several are exact in binary and should use `identical` rather than a tolerance: `grossMargin` = 0.6 is not (0.6 is not representable), but `workingCapital` = 850,000, `marketCap` = 50,000,000, `priceToSales` = 50.0, `evToSales` = 50.5, `inventoryTurnover` = 2.0 and `enterpriseValue` = 50,500,000 all are. The second suite already uses `identical(marketCap, marketCapQ1)`, so the vocabulary is established.

## 4. Assertions that cannot fail or barely discriminate

| Test | Why |
|---|---|
| `testProfitabilityTrends` | Asserts the Q2/Q1 gross-margin ratio is within 10% of 1. Both margins are exactly 0.6 by construction (Q2 revenue 1,100,000 and COGS 440,000 preserve the 60% margin), so the ratio is exactly 1.0. The test would pass for any implementation that computed *both* periods wrongly by the same factor. |
| `testEfficiencyRatios`' CCC identity | Holds under any day-count convention (§2 item 2), and the individual components are asserted only `> 0.0`. |
| `testNoNaNOrInfinite` | The local `isFinite` helper returns `true` for nil, so every metric that is absent passes. For the full fixture all metrics are present, so this is currently fine — but the helper means the test cannot distinguish "finite" from "missing", which is exactly the distinction the service-company test exists to check. |
| `testPiotroskiScoreBounds` | `score.totalScore >= 0 && <= 9` is the type's whole range. The first suite's `testPiotroskiFScoreAlias` is the better test (it compares the alias against the original component by component), but neither pins a score for the fixture. |
| `testLiquidityRatios`' orderings | `quickRatio < currentRatio` and `cashRatio < quickRatio` hold whenever inventory and receivables are positive — true by construction from the fixture. |
| `testValuationRatiosExactValues` P/E bound | ±1e-6 on 281.29 is 3.6e-9 relative, which is appropriate. Noted as the good case. |

## 5. The `guard let … else { Issue.record(); return }` pattern

It appears 20 times across `testProfitabilityRatios` (5), `testEfficiencyRatios` (6), `testLiquidityRatios` (4), `testSolvencyRatios` (4) and `testSolvencyRatiosWithDSCR` (1):

```swift
guard let grossMargin = profitability.grossMargin[q1] else {
    Issue.record("Gross margin should be present for Q1")
    return
}
```

This is correct — it records an issue and stops — but `try #require` does the same in one line with a better failure message, and the second suite in the same file uses it throughout. Converting all 20 removes about 60 lines.

A related smaller point: `#expect(efficiency.inventoryTurnover?[q1]?.isFinite == true)` appears immediately before the `guard let` that extracts the same value. The `== true` comparison on an optional Bool means nil fails, which is the intent, but it duplicates what the guard already establishes.

## 6. Coverage gaps

**The four focused files** (Liquidity, Profitability, Solvency, Efficiency) are short and mostly test the throwing paths, which is the right division of labour against the convenience-function file. What is missing:

- **Zero and negative denominators.** `SolvencyRatiosTests` has "throws on zero equity" and "throws on zero interest", which is good. No equivalent for zero revenue (all margins), zero assets (ROA, asset turnover), zero COGS (inventory turnover — see §2 item 3), zero current liabilities (current/quick/cash ratios), or negative equity (a leveraged buyout balance sheet, where `debtToEquity` is negative and `equityRatio` exceeds 1).
- **Negative net income.** Every fixture is profitable. A loss-making period makes `netMargin`, `roa`, `roe` and `priceToEarnings` negative; P/E in particular is conventionally reported as nil or N/A rather than negative, and nothing says which this library does.
- **Single-period statements.** `DSCR_EdgeCaseTests` covers this for DSCR ("returns empty with single period"). Nothing covers it for the ratios that need a prior period (Piotroski).
- **`piotroskiScore` component values.** Only the alias equivalence and the 0–9 bound are tested. The nine components are individually checkable from the fixture.
- **Mismatched periods.** `testMismatchedPeriodsIntersection` is a good test (IS has Q1–Q3, BS has Q2–Q3, asset turnover is nil at Q1). Worth extending to the other convenience functions, since each joins a different pair of statements.

## 7. Duplication

`createTestFinancialStatements()` is defined twice in `RatioConvenienceFunctionsTests.swift` — once per suite, identically, at about 115 lines each. Together they are roughly a quarter of the file.

That fixture is also the natural shared fixture for the whole ratio suite. It should move to a single place (a TestSupport helper or a shared file-scope factory) with the exact expected values from §3 alongside it, so a test asserting `grossMargin == 0.6` sits next to the fixture that makes 0.6 correct. The suite would then read as: one fixture, one table of expected values, one test per convenience function.

## 8. Recommended order of work

1. **Resolve §2 item 1.** Two debt definitions in one result struct is either a documented choice or a bug, and the current `> 0.0` assertion on `debtToEquity` means nobody would find out.
2. **Pin the day-count convention** (§2 item 2) and the gross-margin-without-COGS contract (§2 item 3).
3. **Deduplicate the fixture** and put the §3 value table beside it.
4. **Convert the first suite's band assertions to exact values.** Most become one-liners against the table; several of its tests then duplicate the second suite and can be deleted.
5. **Convert the 20 `guard let` blocks** to `try #require`.
6. **Add the zero/negative-denominator and loss-making cases** from §6.
7. Remove the `#expect(true)` marker once the gate's scope bug is fixed.

## 9. Gate rules this suite exercises

No new rules; four existing proposals apply directly.

- **Nil-coalescing and optional-defaulting inside assertions.** The `isFinite(_ x: Double?)` helper returning `true` for nil is a variant worth adding to that rule: a test-local helper whose nil path returns the passing value.
- **Band assertions where an exact value is available.** The advisory rule on tolerances looser than the reference's own precision covers the `± 2.0`-style cases; the `> 0.0` cases need the fixture-coverage report instead, since there is no literal to compare against.
- **Display name versus body.** `testProfitabilityTrends` ("remain consistent across periods") describes a property its fixture makes trivially true.
- **Assertion reachability.** The `#expect(true)` marker in `testNoNaNOrInfinite`.

## Appendix. Fixture and derived values

**Shared fixture, Q1 / Q2:**

| Account | Q1 | Q2 |
|---|---|---|
| Revenue | 1,000,000 | 1,100,000 |
| COGS | 400,000 | 440,000 |
| Operating expenses | 300,000 | 330,000 |
| Depreciation | 50,000 | 50,000 |
| Interest expense | 25,000 | 25,000 |
| Income tax | 47,250 | 51,450 |
| Cash | 500,000 | 550,000 |
| Receivables | 300,000 | 330,000 |
| Inventory | 200,000 | 220,000 |
| PP&E | 2,000,000 | 1,950,000 |
| Payables | 150,000 | 165,000 |
| Long-term debt | 1,000,000 | 1,000,000 |
| Equity | 1,850,000 | 1,885,000 |

**Derived, Q1:** net income 177,750; EBIT 250,000; EBITDA 300,000; total assets 3,000,000; total liabilities 1,150,000; EPS (1M shares) 0.17775.

**DSCR fixture** (principal 10,000, interest 25,000): 300,000/35,000 = 8.571428571428571.

**CPLTD walk** (DSCR_EdgeCaseTests): Q2 6.0×, Q3 12.0× (no principal payment), Q4 6.0× — already pinned exactly, and the Q3 value is the discriminating one.
