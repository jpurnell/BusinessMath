# BusinessMath marketing tests

*September 2026. Covers 8 files: CustomerValueTests, ParametricCLVTests, CohortRetentionTests, BehaviouralSegmentsTests, PriceResponseTests, PricingAndResponseTests, ResponseModelTests, UpliftTests. Companion to the twenty-two preceding domain reviews.*

*All reference values independently recomputed with mpmath and numpy.*

## 1. Summary

This is the strongest batch of domain tests in the corpus, and it does two things no other batch does.

**First, every file opens by naming the specific ways its subject goes quietly wrong**, with measured magnitudes. Not "edge cases" in the abstract — three named fail-silent shapes per file, each producing a well-formed plausible number:

| File | A fail-silent shape it names |
|---|---|
| CohortRetention | Averaging a column with every cohort in the denominator: "the naive figure at offset two is 0.17 where the answer is 0.50 — a threefold error with nothing in its shape to give it away" |
| PriceResponse | Choosing a functional form by R²: a log-log fit on exactly-linear data scores 0.975, "which almost anyone would report as a good fit, while the same curve is out by 2.75 units of quantity at every point" |
| Uplift | A response model presented as uplift: "the customers who would have bought anyway score highest on response and zero on uplift" |
| BehaviouralSegments | Feeding a dictionary into k-means: "`[String: [Double]]` has no order… the same customers land in different segments under different labels — and every run looks entirely reasonable" |
| ResponseModel | `LogisticFit.probability` returns 0.5 on a width mismatch "because a probability is its return type and it has nowhere to put an error" |
| PricingAndResponse | Optimal price under inelastic demand: the closed form "returns a **negative price**" |

**Second, every file names an anchor that needs no reference implementation**, and says so:

| File | Anchor |
|---|---|
| CustomerValue | Finite-horizon CLV converges on the perpetuity — "both are the same geometric series, one truncated" |
| PriceResponse | The Lerner condition (P* − c)/P* = −1/ε(P*), "the first-order condition for profit restated, so it must hold at the optimum of **every** form" |
| Uplift | Two-model and class-transformation are algebraically identical on a balanced saturated design |
| CohortRetention | Kaplan-Meier equals the cohort curve where nobody is censored |
| ResponseModel | Σ(yᵢ − pᵢ) = 0 at the likelihood maximum — fitted probabilities average to the observed rate |
| BehaviouralSegments | The partition property — every customer in exactly one segment, sizes summing to the total |

I verified the two hardest anchors. The Lerner condition holds exactly at all three optima (linear at P* = 25 gives Lerner 0.6 against −1/ε = 0.6; log-log at 30 gives 2/3 both ways; semi-log at 20 gives 0.5 both ways). And the R² claim is right: a log-log fit on exactly-linear data scores **0.974810** with a quantity-space residual sum of squares of **45.52**, which the file's comment records as 45.5.

**This batch also contains the corpus's first error assertions that pin associated values.** Five of them:

```swift
#expect(throws: UpliftError.unbalancedAllocation(treatedShare: 0.6875))
#expect(throws: UpliftError.emptyArm(treated: 8, control: 0))
#expect(throws: SegmentationError.invalidSegmentCount(requested: 9, customers: 6))
#expect(throws: LogisticRegressionError.separation(variables: [0]))
#expect(throws: CLVError.definitionNeedsHistory(.historic))
```

That is the standard the roughly 300 type-only `#expect(throws: SomeError.self)` sites across the rest of the corpus should meet, demonstrated.

## 2. The design answer to the convention problem

`CustomerValueTests`' header is the most important passage in this batch, and it answers a question twenty-two reviews have raised without resolving:

> "§12.5 of the marketing proposal records a criticism that changed the design: if there are four definitions of CLV in common use, then verifying that the code matches its documentation proves internal consistency and not correctness. A user who wants definition three gets a library rigorously computing definition one.
>
> The answer is that the variant is named at the call site. The library's claim is not 'we compute CLV' — which is not a claim anyone can check — but 'we compute exactly the definition you asked for', which is."

`QuantileType7ReferenceTests` answers the same problem at the *test* level: pin which of the nine published definitions is implemented. This answers it at the *API* level: make the caller name it, so there is nothing to pin.

**That is the resolution for the eight open conventions the differential-reference review listed.** Each is a case where several definitions are in use and the library silently picks one:

| Open convention | Resolution under this design |
|---|---|
| `weightedPercentile` type 5 vs 7 | `weightedPercentile(_:type:)` |
| Skewness biased g₁ vs adjusted G₁ | `skewness(_:estimator:)` |
| `weightedVariance` frequency vs reliability weights | `weightedVariance(_:weights:kind:)` |
| Max drawdown peak- vs trough-relative | `maxDrawdown(_:relativeTo:)` |
| Rolling variance sample vs population | already parameterised elsewhere in the library |
| `confidenceInterval` coverage vs CI of the mean | two differently-named methods |
| Day count DIO/DSO | already a `DayCountConvention` parameter — the inconsistency is a bug, not a convention gap |
| H-model `halfLife` | a naming fix, not a variant |

`ParametricCLVTests` shows the pattern applied to a case discovered after the fact. The industry's `margin / churn` is *not* the discounted perpetuity — I confirmed it differs by exactly one period's margin (733.33 against 633.33 at 5% churn and 10% discount, a difference of exactly 100). The file's response:

> "That is not a discrepancy to split the difference on. It is the distinction between an ordinary annuity and an **annuity due**, it has a name in finance, and shipping it as a named case is what lets a caller say which one they meant. The alternative — picking one and quietly renumbering everybody's LTV — is precisely what the explicit `CLVDefinition` parameter exists to prevent."

## 3. Other techniques worth propagating

### 3.1 Stating what floating point cannot assert

`finiteConvergesToPerpetuity` checks that a truncated series never exceeds its limit, and explains why the inequality is not strict:

> "Mathematically the truncated series is *strictly* below its limit at every finite horizon, but by T = 200 the remaining tail is under an ulp and the two are equal in floating point. Asserting strict inequality would be asserting something true that a Double cannot represent."

I confirmed the exact gap at T = 200 is 5.8e-26, far below a Double ulp at 266. This is the same discipline as `SamplerMomentReferenceTests` declining to assert a variance where the fourth moment does not exist, and `LinearProgrammingCertificateTests` declining to compare duals on a degenerate problem — three files reaching the same conclusion that an inapplicable assertion should be skipped with a recorded reason rather than widened.

### 3.2 Deliberately non-degenerate fixtures

`PricingAndResponseTests` states the requirement plainly:

> "A gains table with a low contact cost is maximised by contacting everyone, and a fixture built that way cannot tell a working optimiser from one that always returns the last bucket. This fixture has an interior optimum."

That is the fixture-discrimination argument from `InterpolationReferenceTests` (off-knot samples must outnumber knots) applied to an optimiser. Two other instances in this batch: `UpliftTests`' balanced-versus-70/30 pair, and `BehaviouralSegmentsTests`' empty-projection case.

### 3.3 Dictionary ordering as a reproducibility hazard

`BehaviouralSegmentsTests` names it: `[String: [Double]]` has no order, so k-means initial centroids come from a differently-ordered array each run, and "nothing about the output says it moved." The fix — "rows are built in sorted key order and the order is published so it can be checked" — is stronger than just sorting, because publishing the order makes it assertable.

This is the same defect class as the `VectorSpace` article bug from the optimization review, where dictionary iteration order made a published documentation example print a different warehouse location every run. Two independent discoveries of the same hazard; worth a grep for `.values` on a dictionary anywhere in `Sources/` that feeds an order-dependent algorithm.

## 4. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **"Out by 2.75 units at every point" overstates uniformity** | The log-log fit's residuals against exactly-linear data are not constant: the RMS is 2.7544 and the mean absolute is 2.4444, varying point to point. 2.75 is the RMS. | Say "an RMS error of 2.75 units of quantity on a curve running from 150 down to 100." The point stands — the assertion `wrongError > 40` is correct and the measured 45.52 matches — only the phrasing suggests a uniform offset. |
| 2 | **`theOptimumIsAMaximum` brackets by ±1** | Same shape as `optimalityProperty` in the operations review: profit at P* against P* ± 1. | Lower priority here than in the EOQ case, because the Lerner identity in the same file already pins the optimum exactly and this test is a secondary confirmation. A grid (±1, 2, 5) would still be tighter for no cost. |
| 3 | **`#expect(checked == 5)` after a fixed five-element loop** | `finiteConvergesToPerpetuity`. The loop iterates over a literal array of five horizons, so the counter always reaches 5. | This is the unconditional-counter pattern the statistics review flags in ~23 places. It is arguably defensible here as a guard on the fixture list, but `#expect(previousGap < 1e-9)` on the next line already fails if the list is emptied. |
| 4 | **Some type-only error assertions remain** | `CustomerValueTests` has five `CLVError.self` sites; the `refusals` test asserts four distinct conditions — empty cohort, negative discount rate, zero horizon, retention above one — all against the same bare type. | The specific-case form is used elsewhere in the same batch (`CLVError.definitionNeedsHistory(.historic)` in `ParametricCLVTests`), so the vocabulary exists. Four different refusals in one test, all indistinguishable, is the one place this batch falls below its own standard. |

Note that `PriceResponseTests` and `PricingAndResponseTests` use failable initialisers and `nil` returns rather than throws, and assert `== nil`. That is a reasonable choice for a fit that cannot be made and needs no change — a refusal with no information to carry does not need an error case.

## 5. Coverage gaps

**CustomerValue / ParametricCLV.** The two entry points — cohort-based and parametric — are tested separately. The cross-check worth adding: a parametric CLV with retention r should equal a cohort CLV whose estimated retention is r, which ties the two paths together the way `ARMAFamilyTests` ties its family type to its dedicated AR(1).

**CohortRetention.** The Kaplan-Meier anchor is checked where nobody is censored. The interesting case is partial censoring, where the product-limit estimate and the naive cohort curve genuinely differ — that is when Kaplan-Meier earns its keep, and the direction of the difference is predictable.

**PriceResponse.** `best` chooses on quantity-space error. Worth adding a case where two forms are close in quantity space, to pin the tie-break; and a case where the data is generated by *none* of the three forms, where the answer is "the closest of three wrong models" and a caller should be told so.

**Uplift.** The class-transformation method refuses an unbalanced allocation, which is right. Missing: what happens at a *nearly* balanced allocation — 0.5001 — since the refusal presumably has a tolerance, and that tolerance is a convention.

**ResponseModel.** The Σ(yᵢ − pᵢ) = 0 anchor holds at the likelihood maximum. Its complement is worth asserting: that the fit *is* a maximum, by perturbing a coefficient and checking the log-likelihood falls — the gradient certificate from the optimization review, applied to a logistic fit.

**BehaviouralSegments.** The partition property holds for both methods. Missing: reproducibility across runs for the k-means path, which is the defect the sorted-key-order fix addresses. Two runs with the same input should give `identical` segment assignments, and that is the assertion that proves the fix rather than describing it.

## 6. Recommended order of work

1. **Apply the named-variant design to the eight open conventions** (§2). This is the largest outstanding item across the whole review series, and this batch demonstrates both the design and the tests for it.
2. **Add the reproducibility assertion for k-means** (§5) — it proves the sorted-key fix rather than documenting it.
3. **Tie the parametric and cohort CLV paths together** (§5).
4. **Use specific error cases in `CustomerValueTests.refusals`** (§4 item 4), matching the rest of the batch.
5. **Add the partial-censoring Kaplan-Meier case** (§5).
6. **Fix the "2.75 units at every point" phrasing** (§4 item 1).
7. **Grep `Sources/` for dictionary `.values` feeding order-dependent code** (§3.3), given two independent instances of this defect.

## 7. Gate rules

No violations of note. Three positive patterns belong in the gate's list, and the first is the most valuable thing in this batch:

**A "how this goes quietly wrong" section in the suite doc comment.** Every file here names three fail-silent shapes with measured magnitudes. That is not statically checkable, but it is a review checklist item, and it is what makes these files' fixtures non-degenerate — each fixture exists to exercise one named hazard. The fixture-coverage report should record whether a suite documents the failure modes its fixtures target.

**Error assertions with associated values.** Five instances here, against roughly 300 type-only sites elsewhere. The existing rule requires a specific case where the enum has more than one; this batch shows the stronger form — pinning the associated values, which turns the error into a checkable contract rather than a category. `UpliftError.unbalancedAllocation(treatedShare: 0.6875)` asserts the error, the case, *and* the computed share.

**Naming the anchor that needs no reference.** Six files, six anchors, each explicitly labelled as needing no fixture. The differential-reference review noted that a reference file should record oracles it rejected; the complement is that a domain file should record the identity it relies on instead of a reference. Both are provenance, and both are what a later contributor needs.

## Appendix. Verified values

### A.1 Customer lifetime value (m = 100, r = 0.8, d = 0.10)

| Quantity | Value |
|---|---|
| Finite horizon, T = 5: Σ 100·0.8ᵗ/1.1ᵗ | **212.40973356266** |
| Perpetuity: m·r/(1 + d − r) = 100·0.8/0.3 | **266.666666666667** |
| Finite horizon, T = 200 | 266.666666666667 (gap to the limit: 5.8e-26, well under an ulp) |
| Historic: 120 + 95 + 0 + 60 | 275 exactly |
| Discounted historic, flows at t = 1…4 | **228.584113107028** |
| Estimated retention from active counts 10, 8, 6, 5, 4 | mean of (0.8, 0.75, 0.8333…, 0.8) = **0.7958333333333334** |
| Perpetuity at the estimated retention | 261.643835616438 |
| Net of a 150 acquisition cost | 116.6666666667 |
| LTV/CAC ratio | 1.777777777778 |
| Payback periods, 150/100 | 1.5 exactly |

### A.2 Parametric CLV (m = 100, churn = 0.05, d = 0.10)

| Definition | Value |
|---|---|
| `margin / churn` (undiscounted, annuity due) | 2000 |
| Undiscounted ordinary: m·r/(1 − r) | 1900 (differs by exactly one period's margin) |
| Discounted annuity due: m(1 + d)/(1 + d − r) | **733.333333333** |
| Discounted ordinary perpetuity: m·r/(1 + d − r) | **633.333333333** |
| Difference | exactly 100 — one period's margin |

### A.3 Price response (prices 10…20 by 2, marginal cost 10)

Generating curves: Q = 200 − 5P, Q = 1000·P^−1.5, Q = 500·e^−0.1P.

| Form | Optimum | Elasticity at P* | Lerner (P*−c)/P* | −1/ε |
|---|---|---|---|---|
| Linear | (bc − a)/2b = **25** | −5·25/75 = −1.6667 | 0.6 | 0.6 |
| Log-log | cb/(b+1) = **30** | −1.5 (constant) | 0.6667 | 0.6667 |
| Semi-log | c − 1/b = **20** | bP = −2.0 | 0.5 | 0.5 |

Linear elasticity varies along the curve: −1/3 at P = 10, −3.0 at P = 30.

The R² trap, verified: a log-log fit on exactly-linear data gives slope −0.578451, **R² = 0.974810**, and a quantity-space residual sum of squares of **45.52** (RMS residual 2.7544). The linear fit on the same data has RSS below 1e-18.

Choke price: Q = 200 − 5P is zero at P = 40 and refused above it.

### A.4 Uplift (balanced saturated design, one binary predictor)

| Quantity | Value |
|---|---|
| Low cell rate difference | 0.125 |
| High cell rate difference | 0.375 |
| Observed treatment effect | 0.25 exactly |
| Two-model estimate | r_T − r_C |
| Class transformation | (r_T + 1 − r_C)/2, so 2p − 1 = r_T − r_C exactly |
| Refused allocation | treatedShare 0.6875 (11 of 16) |

### A.5 Cohort retention (the header's triangle)

| Quantity | Naive | Correct |
|---|---|---|
| Retention at offset 2 | 0.17 (≈1/6) | 0.50 |
| Period-over-period from pooled values | 0.667 (2/3) | 0.625 (5/8) like-for-like |
| Past the observation window | 0 (reads as total churn) | undefined |
