# BusinessMath valuation tests: credit derivatives, debt, equity

*September 2026. Covers 19 files across three areas: equity valuation (DividendDiscountModelTests, ResidualIncomeModelTests, FCFEModelTests, EquityValuationIntegrationTests, DDMPerformanceTests, EnterpriseValueBridgeTests, ValuePerShareGuardTests), debt (BondPricingTests, BondValuationIntegrationTests, CallableBondTests, SpecializedBondTests), and credit (CDSPricingTests, MertonModelTests, HazardRateModelTests, HazardCurveIntegrationTests, CreditTermStructureTests, CreditSpreadTests, RecoveryModelTests, CoxProcessSimulationTests). Batch 1 of 2. Companion to the sixteen preceding domain reviews.*

*All reference values recomputed in Python with scipy and exact discounting.*

## 1. Summary

Three files in this batch are written to the standard the corpus's best work sets, and all three were written *against* a specific defect:

**`ValuePerShareGuardTests`** states the finding plainly: four types spell `valuePerShare`, and they disagreed about an impossible share count. `DividendDiscountModel` guarded its denominator and threw; `ResidualIncomeModel` and `FCFEModel` "carried byte-identical two-line bodies that were declared `throws` and never threw, so zero shares produced infinity and a negative count produced a negative share price." The sentence that matters is the diagnosis: "The duplicate carried the defect with the code." That is the argument for the duplicated-code gate rule, made concretely.

**`CoxProcessSimulationTests`** found a generic-substitution defect: `meanHazardRate as? Double` failed for `T = Float`, so a Float model silently simulated at λ = 0.02 and σ = 0.30 regardless of its own parameters. The test that catches it runs the same seed through both widths and requires agreement to Float precision — a cross-width differential test, which is a technique that appears nowhere else in the corpus. It also uses a `CountingRNG` to assert that a path draws a fresh shock at every step, "the property the `seeds: [Double]` parameter did not have" — the same finding as the distribution review's seed-array exhaustion, arrived at independently.

**`EnterpriseValueBridgeTests`** covers the bridge from enterprise to equity value, which is where sign errors on net debt, minority interest and preferred stock live.

**Against that, the bulk of the batch asserts ranges and orderings where closed forms exist.** Bond pricing, Merton, and CDS are all closed-form or short-recursion calculations, and the assertions are mostly `price > 1000.0 && price < 1300.0`.

Two items need attention beyond that: a possible off-by-two in the H-Model (§2 item 1) and 50 uses of `Calendar.current` (§2 item 2).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| A defect that duplication spread | ValuePerShareGuardTests |
| Generic code over multiple `Real` widths | CoxProcessSimulationTests (same seed, both widths, agree to the narrower precision) |
| Draw-consumption in a simulated path | CoxProcessSimulationTests (`CountingRNG`) |
| Decomposition that must sum | DividendDiscountModelTests (`twoStageComponentsSumToTotal`) |

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **The H-Model's `halfLife` parameter may be off by a factor of two** | `hModelBasic` passes `halfLife: 10` with the comment "Takes 10 years for growth to decline," then derives the expectation as `2×1.04/0.06 + 2×10×0.08/0.06 = 34.67 + 26.67 = 61.33` — using 10 directly as H. In the standard H-model, H is *half* the decline period, so a 10-year decline means H = 5, a premium of 13.33, and a total of **48.00**. Either the parameter is correctly named and the comment is wrong (the decline takes 20 years), or the comment states the intent and the implementation doubles the premium. | Resolve, then pin the exact value. Both candidates are exact: 61.3333333333 for H = 10 and 48.0 for H = 5. The test's ±0.5 tolerance cannot distinguish them, but they are 13 apart, so the test is currently pinning whichever the code does. Note that `hModelReducesToGordon` passes under either reading, since the premium term vanishes when g_S = g_L. |
| 2 | **`Calendar.current` appears 50 times across the batch** | 23 in BondPricingTests, 10 each in CallableBondTests and SpecializedBondTests, 7 in BondValuationIntegrationTests. `referenceDate()` has the right intent — its comment says "Use a fixed reference date to avoid wall-clock dependencies in bond calculations" — but builds the date with `Calendar.current.date(from:)`, so the resulting instant still depends on the runner's time zone, and under a non-Gregorian calendar `components.year = 2025` denotes a different year. Every `calendar.date(byAdding: .year, value: 10, to: today)` inherits the same dependence. | Use the shared `testCalendar` (fixed Gregorian, UTC, `en_US_POSIX`) proposed in the time-series review. Same finding, same fix; the credit files (CDS, hazard, term structure) already avoid it by working in year fractions. |
| 3 | **Bond premium and discount prices are asserted as 300-point bands** | `bondPriceAtPremium`: `price > 1000.0 && price < 1300.0` where the exact value is **1163.5143334460**. `bondPriceAtDiscount`: `price < 1000.0 && price > 700.0` where it is **851.2252513954**. The comments call these "reasonable upper/lower bound". | Pin both. These are closed-form annuity-plus-redemption sums; 1e-9 relative is achievable. |
| 4 | **`macaulayDuration` is asserted as a 1-year band** | `duration < 5.0 && duration > 4.0`, with the comment "Typically 4.3-4.5 for this bond." The exact value is **4.4854327646**. | Pin it. The comment already knows the answer to two digits. |
| 5 | **`modifiedDuration` recomputes the relationship it tests** | `expectedModDuration = macDuration / (1.0 + 0.06 / 2.0)` compared against `modDuration`, where `macDuration` came from the same object. If `macaulayDuration` is wrong, both sides move together. | Pin the absolute values: Macaulay **7.8949973402**, modified **7.6650459613** for the 10-year 5% bond at 6%. Keep the ratio check as a second, cheaper assertion. |
| 6 | **`convexity` is asserted as `> 0 && < 200.0`** | "Typical range for 10-year bond." The exact annualised convexity for that bond at 6% is **71.7853980**, or 287.1415920 in periods². | Pin one, and state which convention the API returns — the factor-of-four difference between period-squared and year-squared conventions is exactly the kind of thing a 200-wide band hides. |
| 7 | **Merton outputs are asserted as wide bands** | `equityValue > 15_000_000.0` where the exact value is **25,412,512.00**; `debtValue > 70_000_000.0` where it is **74,587,488.00**; `spread > 0 && < 0.10` where it is **200.54 bps**; `pd < 0.20` where it is **0.16662853**; `dd > 0.5` where d₂ = **0.96757421**. | Pin all five. The Merton model is Black-Scholes with a relabelling, and the corpus already has a 120-digit Black-Scholes reference suite (see the options review) — the same generator produces these. |
| 8 | **CDS fair spread is asserted as `> 0 && < 0.10`** | The credit triangle gives s ≈ h(1 − R) as a close approximation, and the exact discrete-payment answers are computable. At h = 2%, R = 40%, T = 5, quarterly, r = 3%: **120.30 bps** against the triangle's 120.00. | Pin the exact spread, and add the triangle as a separate approximation test with a stated error bound. The near-agreement is itself a good check: it fails if the payment schedule or the accrual convention is wrong. |

## 3. What the strong files establish

### 3.1 The duplication finding

`ValuePerShareGuardTests`' header is the clearest statement in the corpus of why duplicated code is a test problem and not only a style problem. Three types, one of them guarded, two of them carrying "byte-identical two-line bodies that were declared `throws` and never threw."

The consequences it names are specific: zero shares → infinity, negative shares → a negative share price. Neither is a crash, so nothing downstream would flag it; a valuation pipeline would report a negative target price and a reader would blame the inputs.

Two extensions worth adding:

- **The fourth type.** The header says four types spell `valuePerShare`; the file pins two. Whichever the fourth is (`DividendDiscountModel` is named as already correct, so presumably `GordonGrowthModel` or a two-stage variant), it belongs in the same parameterised test so all four are covered by one corpus.
- **A NaN share count.** Zero and negative are covered. `Double.nan` shares would produce a NaN price through a guard that only checks `<= 0`.

### 3.2 The cross-width differential test

`floatModelHonoursItsParameters` runs seeds 1 through 20 through a `Float` model and a `Double` model with the same parameters and requires agreement within 5% relative. The reasoning is exactly right: same seed, same stream, same algorithm, so the only permissible difference is Float's precision.

This technique generalises to every generic type in the library. The corpus has `Float` tests scattered around — `BondPricingTests` has one, `DividendDiscountModelTests` has one — but they assert the same loose bounds as their `Double` siblings rather than asserting agreement *with* the Double result. A `Float` path that silently substituted a default would pass `abs(valueFloat - 40.0) < 0.01` if the default happened to be near 40.

The `as? Double` pattern that caused this defect is worth grepping for across `Sources/`. Any `as? Double` in a generic `Real` context has the same failure mode: it works for `Double`, returns nil for `Float`, and whatever the nil branch does becomes silent behaviour for half the type parameters.

### 3.3 Draw consumption

`CountingRNG` is used for three distinct claims:

- **`pathDrawsFreshShockEveryStep`**: at least 2 draws per step, so the path is not cycling a fixed set.
- **`consumptionGrowsWithPathLength`**: monotone in path length, and the longest path uses more than twice the shortest.
- **`volatilePathsDoNotCollapse`**: mean and CV of the intensity match the analytic values within 10%.

The second is the interesting one. A monotone claim plus a ratio claim together rule out an implementation that consumes a fixed number of draws regardless of horizon — which is what the old `seeds: [Double]` parameter did once the array was exhausted.

`CountingRNG` should move to TestSupport. It is the fourth counting generator in the corpus (the distribution review tracks `DrawCountingRNG`, the simulation review two more), and the generic `CountingRNG<Base>` proposed there covers all of them.

### 3.4 Decomposition

`DividendDiscountModelTests` has the batch's best-structured group: `twoStageHighGrowthPhaseValue`, `twoStageTerminalValue` and `twoStageComponentsSumToTotal`. The components are asserted individually *and* required to sum to the whole, so a mis-split that preserves the total still fails.

I verified all three against the blog-post fixture (D₀ = 1.00, 20% for 5 years, 5% stable, r = 12%): high-growth PV **6.1790939043**, terminal PV **21.1790939043**, total **27.3581878087**. The tolerances are ±0.05, which the exact values support tightening to 1e-12 — and the sum assertion is already at 0.01, which is the right shape.

The terminal-percentage test (`> 0.75 && < 0.80`) is the one to tighten most: the exact fraction is **0.774141**, and the 5-point band exists only because the value was never computed.

## 4. Assertions that cannot discriminate

**Ordering tests that hold for any monotone implementation.** These are correct claims, cheap to keep, and not evidence the values are right:

- Merton: equity falls with leverage, rises with volatility; spread rises with both; PD rises with leverage. Six tests.
- CDS: premium leg falls with default probability; protection leg rises with it and falls with recovery; fair spread rises with hazard. Five tests.
- DDM: value falls with required return.

Each pairs naturally with a pinned value at one point, which is what turns a direction into a magnitude.

**Bounds derived from the model's own structure.** `premiumPV < notional × spread × maturity` and `protectionPV < notional × (1 − recovery)` are true by construction — the undiscounted, zero-default limits. Worth keeping as sanity bounds; they cannot fail for a correct implementation and also cannot fail for many wrong ones.

**Round-trip tests that are self-consistent.** `Round-trip: Price → YTM → Price` at 0.01 is a genuine check of the solver. `YTM calculation - bond at par` asserting `abs(ytm - 0.05) < 0.001` is the pinned case. But the premium and discount YTM tests assert `ytm < 0.06 && ytm > 0.04` — the exact YTMs are recoverable from the prices in §2 item 3 and should be pinned.

**Initialisation tests.** `CDSPricingTests` and `MertonModelTests` each open with a test asserting the constructor stored its arguments — five and five assertions respectively. The field-storage pattern, ~25 sites across the batch.

## 5. Coverage gaps

**Equity.**
- The H-Model at H = 0 should reduce to Gordon at the terminal rate; untested, and it would help resolve §2 item 1.
- Negative residual income (a firm earning below its cost of equity) — `ResidualIncomeModel`'s value should fall below book value, which is the model's whole diagnostic purpose.
- FCFE with negative net borrowing, and with `netBorrowing: nil` versus zero — the fixture uses nil and nothing tests that the two agree.
- `DDMPerformanceTests` is a performance file; per the helpers review, it should be behind `.benchmarkOnly` if it asserts wall-clock time.

**Debt.**
- A bond priced on a coupon date versus between coupon dates: `Bond price between coupon payments` asserts ±50 on 1000, which is 5% and cannot distinguish clean from dirty price. The accrued-interest convention is the thing to pin.
- Negative yields, now ordinary in several markets. `price(yield:)` with a negative yield should still discount correctly.
- A callable bond where the call is deep in the money (call immediately) versus deep out (behaves as a straight bond) — the two limiting cases, each exactly computable.
- Zero-coupon duration equals maturity exactly; `Zero coupon bond approximation` asserts ±10 on a price instead.

**Credit.**
- The credit triangle as a stated approximation (§2 item 8).
- A hazard curve with a non-monotone term structure, where bootstrapping can produce negative implied hazards — the case that makes a bootstrapper fail loudly or silently.
- Recovery at 0% and 100%: at R = 100% the protection leg is worth zero and the fair spread is zero.
- Merton at V < D (already in default) and at σ → 0, where equity becomes max(0, V − De^(−rT)).

## 6. Recommended order of work

1. **Resolve the H-Model parameter** (§2 item 1). It is the one candidate live defect in the batch, and the two readings differ by 27%.
2. **Adopt the shared `testCalendar`** for the four bond files (§2 item 2).
3. **Pin the closed forms**: bond prices, durations, convexity, Merton's five outputs, the CDS fair spread (§2 items 3–8, Appendix A). This is mechanical and covers most of the batch's assertion volume.
4. **Extend `ValuePerShareGuardTests` to the fourth type** and add a NaN share count (§3.1).
5. **Apply the cross-width differential test** to the other generic models, and grep `Sources/` for `as? Double` in generic contexts (§3.2).
6. **Move `CountingRNG` to TestSupport** as the generic `CountingRNG<Base>` (§3.3).
7. **Tighten the DDM decomposition tolerances** and the terminal-percentage band (§3.4).
8. **Add the limiting cases** in §5, starting with callable-bond call/no-call and Merton at σ → 0.

## 7. Gate rules

No new rules. Five existing proposals apply, and one gains a strong supporting example:

- **Duplicated code (advisory → worth promoting).** `ValuePerShareGuardTests` documents a defect that existed *because* two bodies were byte-identical. The rule as proposed reports duplicated function bodies across files; this batch is the case for treating a duplicated body that contains a guard — or lacks one its sibling has — as a finding rather than a note.
- **Ambient calendar in a test (blocking).** 50 sites (§2 item 2).
- **Self-recomputation.** `modifiedDuration` deriving its expectation from `macaulayDuration` on the same object (§2 item 5).
- **Field-storage tests (advisory).** ~25 sites.
- **Band assertions where a closed form exists.** The bulk of §2 and §4. No static rule catches `price > 1000.0 && price < 1300.0`; this is what the fixture-coverage report is for — a list of library functions whose tests contain no pinned value.

One addition worth considering, from §3.2: **flag a `Float`-parameterised test whose assertions do not reference the `Double` result.** A generic model tested at two widths should assert agreement between them, not the same loose bound twice. That is narrow but precisely the defect the Cox process file caught.

## Appendix. Verified values

### A.1 Dividend discount models

| Quantity | Value |
|---|---|
| Gordon, D=2, g=5%, r=10% | 40.0 exactly |
| Gordon, D=5, g=6%, r=12% | 83.3333333333 |
| Gordon, D=1.5, g=5%, r=9% | 37.5 exactly |
| Gordon, D=2, g=5%, r=12% | 28.5714285714 |
| Two-stage (D₀=1, 15%×5, 5%, r=10%): high-growth PV / TV / PV(TV) / total | 5.7245750182 / 42.2385009375 / 26.2267858861 / **31.9513609043** |
| Two-stage (D₀=1, 20%×5, 5%, r=12%): high-growth PV | **6.1790939043** |
| Same: terminal value at year 5 / its PV | 37.3248 / **21.1790939043** |
| Same: total | **27.3581878087** |
| Same: terminal share of total | **0.774141** |
| H-Model (D₀=2, g_S=12%, g_L=4%, r=10%) with H=10 | **61.3333333333** (base 34.6667 + premium 26.6667) |
| Same with H=5 | **48.0** (base 34.6667 + premium 13.3333) |

### A.2 Bonds (face 1000, semi-annual)

| Bond | Quantity | Value |
|---|---|---|
| 6% coupon, 10y, 4% yield | price | **1163.5143334460** |
| 4% coupon, 10y, 6% yield | price | **851.2252513954** |
| 5% coupon, 5y, 5% yield | Macaulay duration | **4.4854327646** |
| 5% coupon, 10y, 6% yield | Macaulay duration | **7.8949973402** |
| Same | modified duration | **7.6650459613** |
| Same | convexity (years²) | **71.7853980** |
| Same | convexity (periods²) | **287.1415920** |
| 6% coupon at par / premium 1100 / discount 900 | current yield | 0.06 / 0.0545454545 / 0.0666666667 |

### A.3 Merton model (V=100M, σ=25%, D=80M, r=5%, T=1)

| Quantity | Value |
|---|---|
| d₁ / d₂ | 1.2175742053 / **0.9675742053** |
| Equity value | **25,412,512.00** |
| Debt value | **74,587,488.00** |
| Risk-free debt value | 76,098,353.96 |
| Credit spread | **0.0200538627** (200.54 bps) |
| Default probability N(−d₂) | **0.1666285324** |
| Equity + debt | 100,000,000.00 exactly |

### A.4 CDS (R=40%, T=5y, quarterly, r=3%)

| Hazard rate | Exact fair spread | Credit triangle h(1−R) |
|---|---|---|
| 1% | **60.08 bps** | 60.00 bps |
| 2% | **120.30 bps** | 120.00 bps |
| 3% | **180.68 bps** | 180.00 bps |

Survival probabilities at h = 2%: S(1) = 0.9801986733, S(2) = 0.9607894392, S(3) = 0.9417645336, S(5) = 0.9048374180.
