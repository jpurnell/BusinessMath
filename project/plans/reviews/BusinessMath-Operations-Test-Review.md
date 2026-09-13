# BusinessMath operations tests: inventory models

*September 2026. Covers 6 files: EOQModelTests, NewsvendorModelTests, SafetyStockModelTests, ReorderPointModelTests, InventorySimulatorTests, InventoryAdvisorTests. Companion to the twenty preceding domain reviews.*

*All reference values recomputed in Python with scipy.*

## 1. Summary

This is the cleanest small batch in the corpus. Every model file opens with a golden path carrying its hand arithmetic in a comment, every file tests its validation errors, and the fixtures are textbook problems whose answers are checkable. There are no vacuous assertions, no unseeded randomness, no wall-clock timing, and no field-storage padding.

Three things are done particularly well:

**The seed comments explain themselves.** `InventorySimulatorTests` marks three tests "Seeded for reproducibility only" and says why the assertion cannot vary — constant demand makes every path identical, and the two rejection tests fail before any path is drawn. That is the honest form of a seed that is present for hygiene rather than for the test's logic, and it is the first place in the corpus I have seen it written down.

**Degenerate cases are used as oracles.** `demandAndLeadTimeDegenerates` asserts that the demand-and-lead-time method reduces to demand-only when σ_L = 0, which is the nesting oracle `AsymmetricGarchTests` uses for APARCH/GARCH. `demandOnlyZeroVariability` asserts exactly zero safety stock at σ_d = 0, at 1e-10.

**`convergestoAnalytical` is a genuine cross-validation.** It generates normal demand, computes the analytical safety stock from the sample moments, then compares against a 50,000-path simulation. Two routes to the same quantity, sharing no code.

The findings below are mostly about tolerance, and two of them are exact identities checked at ±1.0 and ±0.05.

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`orderingEqualsHoldingAtOptimal` checks an exact identity at ±1.0** | At Q*, the EOQ first-order condition makes ordering cost and holding cost *equal*, not approximately equal — that is what setting the derivative to zero means. For the textbook fixture both are exactly 187.34993995195194. The test asserts their difference is `< 1.0`. | Tighten to ~1e-12 relative. This is the most informative assertion in the file — it is the optimality condition itself — and the 1.0 window admits a Q* off by about 1.3%. |
| 2 | **`stockoutProbabilityAtMean` checks an exact 0.5 at ±0.05** | Stock = 70 = mean demand during lead time, so z = 0 and the stockout probability is exactly 0.5 by symmetry. | `exactlyEqual(prob, 0.5)`, or ~1e-15 if the implementation routes through `normalCDF` (whose value at 0 the options review confirms is exactly 0.5 after the erfc fix). The neighbouring tests are fine as bounds: at stock 500 the true probability is 4e-11 (asserted `< 0.01`) and at 20 it is 0.99992 (asserted `> 0.5`) — both could be pinned, but neither is an identity. |
| 3 | **`reorderPointGoldenPath`'s comment describes a different fixture than the test uses** | The comment derives SS = 21.76 and r = 91.76 from σ_d = 5. The test then passes `Array(repeating: 10.0, count: 30)` — constant demand, σ_d = 0 — and asserts r ≈ 70 and SS ≈ 0. The assertions are correct for the fixture; the first three comment lines belong to a different scenario, and a reader sees "r = 91.76" immediately above an assertion of 70. | Either change the fixture to the variable-demand series the comment describes (in which case r is exactly 91.75936820008103), or rewrite the comment for the constant case. The variable version is the better test, since σ_d = 0 makes the safety-stock term disappear entirely. |
| 4 | **`optimalityProperty` brackets Q* by exactly ±1** | `TC(Q*) ≤ TC(Q* ± 1)`. This is not vacuous — the cost curve is convex, so a Q* off by more than about 1 unit fails on one side — but a 1-unit window on a Q* of 50 is a 2% bracket. | Evaluate TC over a grid (say Q* ± 1, 2, 5, 10) and assert Q* is the minimum of the set. Same cost, much tighter bracket, and it fails for a Q* off by any amount that matters. |
| 5 | **`deterministicWithSeed` uses `==` and `differentSeeds` uses `!=` on Doubles** | The reproducibility claim is `result1.reorderPoint == result2.reorderPoint`; the divergence claim is `!=`. Per FloatingPointClaims, `==` fails on two identical NaN streams and `!=` passes on one that has gone NaN. | `identical` and `!identical`, and add an `isFinite` guard to the divergence test. `GeneticAlgorithmSeedDeterminismTests` in the heuristics batch has the exact template, including the reasoning in a comment. |
| 6 | **`InventorySimulatorTests` inlines Box-Muller** | `convergestoAnalytical` builds its own normal draws from `DeterministicRNG`. This one is *correct* — `Double(raw >> 11) * 0x1.0p-53` cannot reach 1.0, and the `max(u1, leastNonzeroMagnitude)` guard handles 0 — but it is another copy of a transform the corpus has been consolidating. | Use the TestSupport Box-Muller. Noted as correct because most inline copies in the corpus are not: the stochastic review found one in a shared helper with a closed interval and an unguarded u₁ = 1.0. |
| 7 | **`InventoryAdvisorTests` asserts on reasoning strings** | `rec.reasoning.count > 0`, `rec.reasoning.allSatisfy { !$0.isEmpty }`, and `rec.reasoning.contains { $0.contains("cost") }`. | The model-selection assertions in the same file (`recommendedModel == .newsvendor`, `safetyStockMethod == .forecastError`, `eoqApplicable == true`) are the contract and are well chosen — five distinct decisions across nine tests, each with a fixture that forces it. The reasoning strings are a diagnostic; one test pinning a full reasoning array for one fixture is stronger than three substring checks, and it will not break when the wording improves. |
| 8 | **`extremeInputs` asserts only finiteness** | For D = 1e12, S = 1e6, H = 0.01, Q* = √(2·1e6·1e12/0.01) = 1.4142135624e10. The intermediate 2SD is 2e18, well inside Double's range, so nothing here is actually at risk of overflow. | Pin the value. If the point is overflow safety, the interesting case is one where 2SD *would* overflow — D = 1e200, S = 1e200 — where a naive √(2SD/H) gives infinity but √(2S/H)·√D does not. That is a real numerical-stability test and the current one is not. |
| 9 | **Error assertions are all by type** | About 14 `#expect(throws: OperationsError.self)` sites. The tests' names state the specific case — zero demand, negative ordering cost, zero holding cost, invalid service level, missing RMSE. | `OperationsError` presumably distinguishes these; assert the case. `forecastErrorRequiresRMSE` is the one where it matters most: a missing-parameter error and an invalid-value error are different bugs, and the test cannot tell them apart. |

## 3. Exact values available

Every golden path in this batch has a full-precision answer. The tolerances are mostly 0.1 to 1.0 against 4-significant-digit comments.

| Test | Asserted | Exact |
|---|---|---|
| `eoqGoldenPath` | 49.96 ± 0.1 | **49.95998398718719** |
| `eoqSecondExample` | 632.46 ± 0.1 | **632.4555320336759** |
| `totalCostCalculation` (Q = 50) | 374.7 ± 1.0 | **374.7** exactly |
| `totalCostWithUnitCost` | 47174.7 ± 1.0 | **47174.7** exactly |
| `derivedFields` orders/year | 18.72 ± 0.5 | **18.734993995195193** |
| `derivedFields` days between | 19.5 ± 1.0 | **19.48225871295227** |
| Ordering = holding at Q* | ± 1.0 | both **187.34993995195194** |
| `zScoreAt95Percent` | 1.6449 ± 0.001 | **1.6448536269514722** |
| `zScoreAt99Percent` | 2.3263 ± 0.001 | **2.3263478740408408** |
| `demandOnlyGoldenPath` | 21.76 ± 0.1 | **21.759368200081024** |
| `demandAndLeadTimeGoldenPath` | 39.44 ± 0.5 | **39.44220437684565** |
| `forecastErrorGoldenPath` | 13.06 ± 0.1 | **13.055620920048614** |
| `criticalFractileGoldenPath` | 5/7 ± 0.001 | **0.7142857142857143** |
| `optimalQuantityWatermelon` | 47.75 ± 1.0 | **47.753091387318236** (z = 0.43072729929545744) |
| `optimalQuantityMatchesNormInv` | 124.18 ± 1.0 | **124.18553915254253** (z = 0.967421566101701) |
| `highMarginStockMore` | > 100, SL > 0.95 | Q* = **151.54791252023654**, p_c = **0.9803921568627451** |
| `lowMarginStockLess` | < 100, SL < 0.05 | Q* = **48.45208747976346**, p_c = **0.0196078431372549** |
| `stockoutProbabilityAmpleStock` | < 0.01 | **4.0e-11** |
| `stockoutProbabilityLowStock` | > 0.5 | **0.9999214739** |
| `stockoutProbabilityAtMean` | 0.5 ± 0.05 | **0.5** exactly |
| Reorder point, variable demand (σ_d = 5) | — | **91.75936820008103** |
| `extremeInputs` Q* | finite, > 0 | **1.4142135624e10** |

Several are exactly representable and should use `identical` or `exactlyEqual`: `totalCostCalculation` (374.7 is not binary-exact, but the sum 187.2 + 187.5 is computed from exact inputs), `criticalFractileEqualCosts` (10/20 = 0.5 exactly), `demandOnlyZeroVariability` (already at 1e-10), and `expectedProfitZeroQuantity` (already at 0.01, where zero is exact).

## 4. Coverage gaps

**EOQ.**
- **Quantity discounts.** The classic extension, and the one where the EOQ formula stops being the answer — the optimum is either the unconstrained Q* or a price-break quantity.
- **Q* rounding to a case pack.** TC(Q) is convex but flat near Q*, so rounding 49.96 to 50 costs 0.0001; the test at Q = 50 implicitly relies on this and it is worth stating.
- **Sensitivity.** The EOQ's practical selling point is that TC is within 2% of optimal for Q anywhere in [0.7Q*, 1.4Q*]. That is a checkable property and it explains why the ±1 bracket in §2 item 4 is weak.

**Newsvendor.**
- **The expected-profit formula.** `expectedProfitCalculation` asserts only finiteness and positivity. For normal demand the expected profit at Q has a closed form involving the standard normal loss function L(z) = φ(z) − z(1 − Φ(z)); at the watermelon fixture that is computable exactly.
- **Profit is maximised at Q\*.** The analogue of `optimalityProperty`, and the newsvendor's defining claim. Currently `optimalQuantity` and `expectedProfit` are tested independently and never connected.
- **Salvage value.** Every test uses `salvageValue: 0.0`. A nonzero salvage lowers the overage cost and raises Q*, which is the parameter's whole effect.

**Safety stock.**
- **Service level as a fill rate versus a cycle service level.** The z-score approach gives the probability of no stockout *per cycle*; a fill rate is a different quantity. Which one `serviceLevel` means is not pinned, and it is the same class of convention question as the day-count and percentile conventions found elsewhere.
- **`demandOnlyMonotonicInServiceLevel` starts `previousSS` at 0.0** and its first service level is 0.50, where SS ≈ 0 — so the first comparison is trivially satisfied. Starting the loop at 0.80 or seeding `previousSS` with `-.infinity` makes every iteration load-bearing.

**Simulator.**
- **The 20% tolerance in `convergestoAnalytical`** is not derived. At 50,000 paths the Monte Carlo error on a 95th percentile is small, so most of the 20% is the structural difference between an empirical quantile and a normal one. Measuring that difference and stating it would turn the bound into evidence.
- **`empiricalStrategy` and `normalStrategy` are the same test twice** apart from the strategy name, and neither asserts anything that distinguishes them. For a demand history with visible skew the two strategies give different reorder points — that is the reason both exist.
- **A demand history with a single observation**, and one with all-zero demand.

**Advisor.** The nine decision tests are good. Missing: a fixture on the boundary of each rule (the advisor presumably switches on a coefficient of variation or a cost ratio, and the threshold is untested), and what happens when two rules conflict.

## 5. Recommended order of work

1. **Tighten the two exact identities** (§2 items 1–2): ordering = holding at Q*, and stockout probability = 0.5 at the mean. Both are the most informative assertions in their files.
2. **Fix `reorderPointGoldenPath`** (§2 item 3) — preferably by switching to the variable-demand fixture the comment describes, since the constant one erases the safety-stock term.
3. **Replace `==`/`!=` with `identical`/`!identical`** and add the `isFinite` guard (§2 item 5).
4. **Pin the §3 values** at full precision. Mechanical, and it covers most of the batch's assertions.
5. **Connect `optimalQuantity` to `expectedProfit`** (§4) — assert that profit is maximised at Q*, which is the newsvendor's defining property and currently untested.
6. **Widen `optimalityProperty` to a grid** (§2 item 4) and add the EOQ flatness property.
7. **Differentiate the two sampling strategies** (§4).
8. **Assert specific error cases** (§2 item 9), starting with `forecastErrorRequiresRMSE`.

## 6. Gate rules

No new rules. This batch is notable for what it *doesn't* trip: no vacuous assertions, no unseeded randomness, no ambient calendar, no wall-clock assertions, no commented-out tests, no field-storage padding. Existing rules that apply:

- **`==`/`!=` on floating point** (§2 item 5), two sites.
- **Error by type only** (§2 item 9), ~14 sites.
- **String-content assertions** (§2 item 7), three sites in the advisor.
- **Exact identities checked with tolerances.** No static rule catches this; it is what the fixture-coverage report is for.
- **Duplicated generator or transform bodies** (§2 item 6).

One positive pattern worth adding to the gate's list, from §1: **a seed present for hygiene rather than for the test's logic should say so.** The three "Seeded for reproducibility only" comments in `InventorySimulatorTests` distinguish a seed that makes the test deterministic from a seed the assertion depends on — and the distinction matters, because the seed-robustness nightly run proposed in the gate design would otherwise flag those tests as candidates for multi-seed variation when varying the seed cannot change their outcome.

## Appendix. Formulae and verified values

### A.1 EOQ (D = 936, S = 10, H = 7.50)

| Quantity | Formula | Value |
|---|---|---|
| Q* | √(2SD/H) | 49.95998398718719 |
| Ordering cost at Q* | SD/Q* | 187.34993995195194 |
| Holding cost at Q* | HQ*/2 | 187.34993995195194 (equal by construction) |
| TC at Q* | sum of the two | 374.6998799039039 |
| TC at Q = 50 | 187.2 + 187.5 | 374.7 |
| Orders per year | D/Q* | 18.734993995195193 |
| Days between orders | 365/(D/Q*) | 19.48225871295227 |

Second example (D = 5000, S = 10000, H = 250): Q* = 632.4555320336759.

### A.2 Safety stock (z(0.95) = 1.6448536269514722)

| Method | Formula | Value |
|---|---|---|
| Demand only | z·σ_d·√L, σ_d = 5, L = 7 | 21.759368200081024 |
| Demand + lead time | z·√(Lσ_d² + d̄²σ_L²), d̄ = 10, σ_L = 2 | 39.44220437684565 |
| Forecast error | z·RMSE·√L, RMSE = 3 | 13.055620920048614 |
| Reorder point | d̄L + SS | 91.75936820008103 |

z(0.99) = 2.3263478740408408. z(0.50) = 0 exactly.

### A.3 Newsvendor

| Case | p_c = c_u/(c_u+c_o) | z* | Q* = μ + z*σ |
|---|---|---|---|
| Watermelon (μ=40, σ=18, c_u=1, c_o=0.5) | 2/3 | 0.43072729929545744 | 47.753091387318236 |
| (μ=100, σ=25, c_u=5, c_o=1) | 5/6 | 0.967421566101701 | 124.18553915254253 |
| High margin (c_u=50, c_o=1) | 50/51 = 0.9803921568627451 | 2.0619165008094615 | 151.54791252023654 |
| Low margin (c_u=1, c_o=50) | 1/51 = 0.0196078431372549 | −2.0619165008094615 | 48.45208747976346 |

Equal costs give p_c = 0.5 exactly; c_u = 5, c_o = 2 gives 5/7 = 0.7142857142857143.

### A.4 Stockout probability (d̄ = 10, σ_d = 5, L = 7; μ = 70, σ = 13.2288)

| Current stock | P(stockout) |
|---|---|
| 500 | 4.0e-11 |
| 70 | 0.5 exactly |
| 20 | 0.9999214739 |
