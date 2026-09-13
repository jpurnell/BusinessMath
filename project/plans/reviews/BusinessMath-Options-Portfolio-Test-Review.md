# BusinessMath options and portfolio tests: review

*September 2026. Covers 7 files: BlackScholesTests (three suites), BinomialTreeTests, RealOptionsTests, PortfolioTests (two suites), PortfolioOptimizerTests, RiskParityTests (two suites), PortfolioUtilitiesTests. The other 13 files in this batch are the forecasting set already covered in the validation/forecasting review, unchanged. Companion to the distribution, simulation, statistics, time-series, Bayes, financial-ratio, scenario-analysis, operational-driver, financial-statement, validation/forecasting, optimization, risk, error-handling and fluent-API reviews.*

*All reference values recomputed in Python: Black-Scholes with mpmath at 60 digits, CRR trees by direct backward induction, portfolio moments with numpy.*

## 1. Summary

**`BlackScholesNormalCDFAccuracyTests` is the strongest file in this batch and belongs with the corpus's best.** I recomputed all 13 of its reference values with mpmath at 60 digits; every one matches to the last printed digit, calls and puts both. Three things it does that the rest of this batch does not:

- **The oracle does not share arithmetic with the subject.** The values were computed with a 120-digit `Decimal` implementation, and the file says why that matters: "a test that re-derived the expected value from `normalCDF` would only be asserting that the code equals itself." That is the same consideration `LinearProgrammingCertificateTests` raises about its Gaussian elimination, and the two files are the only places in the corpus where it is stated.
- **The tolerance is reasoned in both directions.** `1e-12 * max(|reference|, 1)` is "loose enough to absorb the handful of ulps that double-precision arithmetic contributes on top of an exact CDF, and roughly six orders of magnitude tighter than the error the A&S polynomial produced."
- **The defect is pinned where it is exactly checkable.** `cdfIsExactlyOneHalfAtZero` uses `identical`, with the reasoning spelled out: the old approximation was 5e-10 off, "inside any tolerance anyone would reach for here, and still enough to break put-call parity at the forward. Stating it as a bit pattern is the only phrasing that fails when the property fails."

**The other six files are the older generation**, and they share one pattern: the quantity is a closed form, and the assertion is a band or an ordering. `atmCall` asserts `5 < price < 20` for a value the same file's third suite pins at 10.4505835721855682.

Two findings need attention beyond that:

1. **Both "deterministic" portfolio suites are built on fixtures with exactly zero variance** (§2 item 1), which makes Sharpe ratio undefined and three tests either vacuous or failing.
2. **`PortfolioTests.sharpeRatio` asserts a tautology and its comment says so** (§2 item 2).

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`twoAssetConstant` has exactly zero variance, so Sharpe is undefined** | The fixture is `Array(repeating: 0.10/12, count: 12)` and the same for 0.05/12. Constant returns give variance identically 0, so the covariance matrix is all zeros, portfolio risk is exactly 0, and Sharpe = 0.00625 / 0 = **+infinity**. Yet `sharpeFinite` asserts `sharpe.isFinite`. Either the implementation guards the zero denominator and returns something finite — in which case the test is asserting the guard, not the ratio — or the test fails. `optimizerBeatsEqualWeights` on the same fixture compares `optimal.sharpeRatio >= equalSharpe - 1e-6`, which is `inf >= inf - 1e-6` (or `0 >= 0` if guarded): vacuous either way, because every weight vector gives risk 0. `frontierMonotonicReturn` runs an efficient frontier on a degenerate covariance matrix. | Give the suite a fixture with nonzero, unequal variances and a known covariance, so the Sharpe ratio and the frontier both exist. Separately, pin the zero-risk contract explicitly: `sharpeRatio` with zero volatility should return a documented value (+infinity, NaN, or 0), and a test should say which. This is the same absent-denominator question the financial-statement review raises for ratios. |
| 2 | **`PortfolioTests.sharpeRatio` asserts a tautology** | `#expect(sharpe >= 0.0 \|\| sharpe < 0.0)  // Just check it calculates`. For any non-NaN value this is true; it is a NaN check written as a disjunction, and the comment concedes it tests nothing else. Its fixture is `makeTwoAssetReturns`, which is also constant-return, so the value is +infinity and `>= 0.0` passes. | With a non-degenerate fixture, Sharpe is a closed form: (w'μ − r_f) / √(w'Σw). Assert it. |
| 3 | **`RiskParityTests` has a placeholder display name** | `@Test("x")` on `inverseVolWeights` — the most valuable test in that file. | Name it for what it checks: risk parity reduces to inverse-volatility weighting when the covariance matrix is diagonal. |
| 4 | **The inverse-vol closed form is exact and asserted at ±0.10** | `zeroCovarianceReturns` gives σ₁ = 2σ₂ exactly (sample sd 0.023094010767585032 and 0.011547005383792516; covariance −4.2e-22, i.e. zero to rounding). So w₁ = σ₂/(σ₁+σ₂) = **1/3** and w₂ = **2/3**, exactly. The ±0.10 band spans 0.233–0.433 and cannot distinguish 1/3 from 0.25 or 0.4. | Assert 1/3 and 2/3 at ~1e-9. The fixture was built to make this exact; the tolerance discards that. |
| 5 | **`PortfolioUtilitiesTests.generateReturns` is unseeded** | It asserts `abs(mean - 0.10) < 0.02` for n = 100, σ = 0.05. The standard error is 0.005, so the bound is 4 SE and a correct generator fails about 6.3e-5 of the time. It sits immediately above `returnsRange`, whose comment documents at length why seeding matters and cites the Deterministic Randomness Standard. | Pass a `DeterministicRNG`, as its neighbour does. |
| 6 | **`diversificationReducesRisk` asserts neither diversification nor risk reduction** | The body asserts both risks are positive. The comment concedes it: "This may not always be true if assets are perfectly correlated / So we just check that both are positive." | With a known covariance matrix the diversification benefit is computable exactly. `PortfolioOptimizerTests.diversificationBenefit` does assert `portfolio.volatility < volatility`, so the property is testable — this fixture just does not pin it. |
| 7 | **`frontierIncreasingReturn` asserts neither increase nor ordering** | Name says returns increase along the frontier; body compares `firstReturn >= 0.0` and `lastReturn >= 0.0`, with the comment "Just check they're both positive". | `PortfolioDeterministicTests.frontierMonotonicReturn` has the right assertion — once its fixture is fixed (§2 item 1), delete this one. |

## 3. Closed forms checked as bands

### 3.1 Black-Scholes

The first two suites are now superseded by the third for everything they cover. Values I verified:

| Test | Current assertion | Exact |
|---|---|---|
| `atmCall` | `> 5.0 && < 20.0` | 10.4505835721855682 |
| `atmPut` | `> 5.0 && < 20.0` | 5.57352602225696803 |
| `itmCall` (S=110) | `>= 10.0` | computable; the reference suite's `itmOneYear` at S=120 is 26.1690439468473102 |
| `otmCall` (S=90) | `> 0.0 && < 10.0` | the reference suite's `otmOneYear` at S=80 is 1.85941957281218362 |
| `putCallParity` | `< 0.01` | Parity is exact in the formula: C − P = S − Ke^(−rT) holds to rounding, so ~1e-13 |
| `bsKnownPrice` | `abs(price − 10.4506) < 0.05` | 10.4505835721855682, pinned at 1e-12 in the reference suite |
| `shortExpiry` | `abs(price − 10.0) < 1.0` | computable exactly; the band admits a 10% error on a near-intrinsic option |

The Greeks tests assert signs and (0,1) ranges only. All five Greeks have closed forms, and `finiteDifferenceGreeks` already establishes the harder property — that the analytic Greeks match central differences. Its bounds (1e-3 on delta, 5e-3 on gamma, 2% relative on vega) are reasonable for the step sizes chosen, though the gamma step `hS = 0.01` on a second difference gives a truncation-versus-cancellation tradeoff worth stating: at S = 100 the cancellation term is roughly ε·C/hS² ≈ 2e-12, so the bound is dominated by truncation and could be tighter.

**Recommendation:** extend the reference suite to the Greeks — the same 13 cases, with delta, gamma, vega, theta and rho from the 120-digit implementation. Then delete the sign-and-range tests and the `bsKnownPrice` duplicate.

### 3.2 Binomial tree

CRR converges as O(1/n) with the alternating-parity oscillation. Measured against the exact BS call (10.450583572185565):

| Steps | CRR price | Relative error | Test bound |
|---|---|---|---|
| 20 | 10.3512601891 | 9.50e-3 | — |
| 50 | 10.4106915407 | 3.82e-3 | — |
| 100 | 10.4306116622 | 1.91e-3 | — |
| 200 | 10.4405912599 | 9.56e-4 | `< 0.05` — 52× loose |
| 500 | 10.4465851364 | 3.83e-4 | `< 0.01` — 26× loose |
| 1000 | 10.4485841038 | 1.91e-4 | — |

The error is almost exactly 0.19/n, which makes the *convergence order* the assertion worth making rather than the magnitude:

```swift
@Test("Binomial convergence is first order in the step count")
func convergenceIsFirstOrder() {
    let exact = BlackScholesModel<Double>.price(/* ... */)
    // CRR error is O(1/n), so doubling the steps should halve it.
    var previous = abs(price(steps: 50) - exact)
    for steps in [100, 200, 400, 800] {
        let error = abs(price(steps: steps) - exact)
        let ratio = previous / error
        #expect(ratio > 1.8 && ratio < 2.2, "error ratio \(ratio) at \(steps) steps")
        previous = error
    }
}
```

That fails for an implementation with the wrong `u`, `d` or `p`, which the 5% band does not. `stepSizeAccuracy`'s `diff < fewSteps * 0.1` is 11× loose by the same measure and is subsumed.

Two exact values the American tests should use:

- **American call equals European call exactly** with no dividends. I measured the difference as **0.0** at 100 steps. The test allows 0.1; `identical` is the claim.
- **The deep-ITM American put equals intrinsic.** At S = 80, K = 100, the American put is **exactly 20.0** (immediate exercise is optimal), against a European put of 16.98597066882717 — an early-exercise premium of 3.0140293311728286. The test asserts `american >= european - 0.1`, which passes by 3.1. Asserting 20.0 exactly is both stronger and the more interesting fact, and it is the one case where the American algorithm's exercise decision is unambiguous.

`intrinsicValue` asserts `price >= 20.0` for a deep-ITM American call at S=120, T=0.1 — also exactly at intrinsic, by the same argument.

### 3.3 Real options

The decision-tree tests are the good half of this file: `decisionTreeChance` pins 140.0 (0.6·200 + 0.4·50), `decisionTreeDecision` pins 200.0, `complexDecisionTree` pins 100.0 with the high-risk branch's expected value of 80 computed in the comment, and `emptyDecisionNode` pins 50.0. All exact, all with the arithmetic shown. `decisionTreeTerminal` at 100.0 and `emptyDecisionNode` at 50.0 are stored values and should use `identical`.

The expansion and abandonment tests are ordering-only: `projectValue > baseNPV` and `highVolValue > lowVolValue`. Both are Black-Scholes calls in disguise — an expansion option is a call on the expansion NPV struck at the expansion cost, and an abandonment option is a put on the project NPV struck at the salvage value. So both have closed forms, and the reference-suite treatment applies directly.

`zeroTimeExpansion` asserts `>= 10M && <= 14M` where the stated expectation is 13M. As T → 0 the option value converges to max(0, 8M − 5M) = 3M, so the total is 13M; at T = 0.001 it is within a few thousand of that. The 4M-wide band is 1,000× looser than needed.

`abandonmentAddsValue` asserts `projectValue - projectNPV >= -0.01`, with the comment "or very small negative due to numerical precision". An option value cannot be negative, so this admits a sign error of up to a cent. If the implementation really can return a small negative, that is worth understanding rather than tolerating.

### 3.4 Portfolio and optimizer

`PortfolioOptimizerTests` is the better of the two portfolio files: it uses explicit covariance matrices rather than generated returns, and `equalAssetsProduceEqualWeights`, `diversificationBenefit` and `highSharpeAssetDomination` all assert properties that discriminate. Its weaknesses are the familiar ones:

- **`optimizerConvergesQuickly`** asserts `iterations < 50` and `converged || iterations < 20` — a performance claim and a disjunction that passes when the optimizer fails in under 20 iterations. Same shape as `portfolioOptimization` in the optimization review.
- **Volatility asserted as `> 0.0 && < 0.3`** ("should be reasonable") throughout. For an explicit covariance matrix the minimum-variance weights and the resulting volatility are closed forms: w = Σ⁻¹1 / (1'Σ⁻¹1), and σ² = 1/(1'Σ⁻¹1).
- **Max-Sharpe weights are also closed form** with no constraints: w ∝ Σ⁻¹(μ − r_f·1). `maximumSharpe2Assets` asserts `weights[1] > 0.3`; the exact weight is available.
- **`weightSum` tolerances range from 0.01 to 0.1** across tests in the same file. The constraint is an equality, so 1e-9 should hold everywhere; a test needing 0.1 is reporting a solver problem.

The gradient/KKT certificate from the optimization review applies here too: a constrained minimum-variance portfolio satisfies Σw = λ1 on the unconstrained assets, and for box-constrained problems the KKT multipliers are checkable. `boxConstraints` currently asserts only that the weights lie in [0.05, 0.35] — primal feasibility alone.

## 4. Coverage gaps

**Options.**
- Put-call parity at the exact forward (S = Ke^(−rT)), where `cdfIsExactlyOneHalfAtZero` shows the old defect lived. Delta should be exactly 0.5 for the call and −0.5 for the put there.
- Zero volatility: the option value collapses to max(0, S − Ke^(−rT)) for a call. An undefined d₁ if σ√T = 0.
- Zero time to expiry: exactly intrinsic.
- Very deep OTM, where the reference suite's `deepItmShort` put value of 1.93614990445625430e-08 shows the scale that matters.
- Negative rates, which are now ordinary in several currencies.
- American put convergence: the tree price should converge in n, and the exercise boundary should be monotone in time.

**Portfolio.**
- A singular covariance matrix (two perfectly correlated assets), where Σ⁻¹ does not exist.
- Negative expected returns for every asset, where max-Sharpe is degenerate.
- A short-selling-permitted case, if the API supports it — every current test assumes non-negativity.
- Reproducibility: two `optimizePortfolio()` calls on the same input should be `identical`.
- Risk parity's defining property: equal *risk contribution*, w_i(Σw)_i equal across i. Every current test checks weights or their ordering, not the contributions, and the equal-contribution condition is what makes it risk parity rather than inverse-volatility weighting. The two coincide only for a diagonal covariance matrix — which is exactly the fixture `inverseVolWeights` uses, so the general case is untested.

## 5. Recommended order of work

1. **Replace the two constant-return portfolio fixtures** (§2 item 1) with non-degenerate ones, and pin the zero-volatility Sharpe contract.
2. **Fix `PortfolioTests.sharpeRatio`** (§2 item 2) and the two tests whose names promise properties their bodies do not check (§2 items 6–7).
3. **Assert the inverse-vol closed form exactly** and name the test (§2 items 3–4).
4. **Extend the Black-Scholes reference suite to the Greeks**, then delete the superseded sign-and-range tests and the `bsKnownPrice` duplicate (§3.1).
5. **Replace the binomial convergence bands with a convergence-order test**, and pin the two exact American values (§3.2).
6. **Add risk parity's equal-risk-contribution property** with a non-diagonal covariance matrix (§4).
7. **Pin the minimum-variance and max-Sharpe closed forms** in `PortfolioOptimizerTests` (§3.4), and tighten the weight-sum tolerances to 1e-9.
8. **Give the expansion and abandonment options their Black-Scholes reference values** (§3.3).
9. **Seed `generateReturns`** (§2 item 5).

## 6. Gate rules

No new rules. Five existing proposals apply:

- **Vacuous assertions.** `sharpe >= 0.0 || sharpe < 0.0` is a new instance of the contract-free disjunction rule, and the narrowest one yet — two alternatives covering the whole non-NaN range.
- **Subjunctive comments with no assertion.** "This may not always be true… So we just check that both are positive" and "Just check they're both positive" are the pattern the scenario review proposed flagging, here stated even more plainly.
- **Display name versus body.** `diversificationReducesRisk` and `frontierIncreasingReturn` are the semantic form; `@Test("x")` is a different failure — a placeholder that shipped.
- **Convergence asserted as a magnitude rather than an order.** Worth adding to the derived-tolerance advisory: a test comparing a discretised method against its continuum limit should assert the error ratio between two resolutions, not a single bound. That covers the binomial tests here and the ETS/Holt-Winters convergence tests in the forecasting review.
- **Unseeded randomness** (§2 item 5), where the transitive rule from the scenario review applies since `generateRandomReturns` has both a seeded and an unseeded overload.

## Appendix. Verified values

### A.1 Black-Scholes 120-digit references

All 13 cases confirmed against mpmath at 60 digits, to every printed digit, calls and puts. Spot checks:

| Case | Call | Put |
|---|---|---|
| atmOneYear (100/100/1.0/5%/20%) | 10.4505835721855682 | 5.57352602225696803 |
| itmOneYear (120/100/1.0/5%/20%) | 26.1690439468473102 | 1.29198639691871198 |
| otmOneYear (80/100/1.0/5%/20%) | 1.85941957281218362 | 16.9823620228835850 |
| deepItmShort (150/100/0.25/5%/15%) | 51.2422199699733554 | 1.93614990445625430e-08 |
| indexScale (4500/4600/0.5/4.5%/18%) | 229.457226321541896 | 227.112917410889168 |
| pennyStock (2.5/3/0.75/5%/80%) | 0.550639881081281146 | 0.940223134243746372 |

Φ(0) = 0.5 exactly.

### A.2 CRR binomial convergence (100/100/1.0/5%/20% call)

Exact BS: 10.450583572185565. Error ≈ 0.19/n.

| Steps | Price | Relative error |
|---|---|---|
| 20 | 10.3512601891 | 9.50e-3 |
| 50 | 10.4106915407 | 3.82e-3 |
| 100 | 10.4306116622 | 1.91e-3 |
| 200 | 10.4405912599 | 9.56e-4 |
| 500 | 10.4465851364 | 3.83e-4 |
| 1000 | 10.4485841038 | 1.91e-4 |

### A.3 American options (100 steps)

| Quantity | Value |
|---|---|
| American call − European call, no dividends | 0.0 exactly |
| American put, S=80, K=100, T=1, r=5%, σ=20% | 20.0 exactly (= intrinsic) |
| European put, same parameters (tree) | 16.98597066882717 |
| European put, same parameters (Black-Scholes) | 16.982362022883592 |
| Early-exercise premium | 3.0140293311728286 |

### A.4 Risk parity fixture

Returns A = [0.02, −0.02, 0.02, −0.02], B = [0.01, 0.01, −0.01, −0.01]:

| Quantity | Value |
|---|---|
| Means | 0.0 both |
| Sample covariance | −4.19e-22 (zero to rounding) |
| Sample standard deviations | 0.023094010767585032 and 0.011547005383792516 (ratio exactly 2) |
| Population standard deviations | 0.02 and 0.01 |
| Inverse-volatility weights | w₁ = 1/3, w₂ = 2/3 (same under either convention) |

### A.5 Constant-return portfolio fixture

Returns A = 0.10/12 repeated, B = 0.05/12 repeated:

| Quantity | Value |
|---|---|
| Variance of each | 0.0 exactly |
| Covariance matrix | all zeros |
| Portfolio risk at any weights | 0.0 exactly |
| Portfolio return at [0.5, 0.5] | 0.00625 |
| Sharpe ratio at r_f = 0 | +infinity (0.00625 / 0) |

### A.6 Real options decision trees

| Test | Value |
|---|---|
| Chance node, 0.6·200 + 0.4·50 | 140.0 |
| Decision node, max(150, 200) | 200.0 |
| Complex tree: max(0.3·500 + 0.7·(−100), 100) = max(80, 100) | 100.0 |
| Expansion at T → 0: base + max(0, 8M − 5M) | 13,000,000 |
