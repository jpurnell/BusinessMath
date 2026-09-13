# BusinessMath network, concentration, survival, classification, financial and experiment tests

*September 2026. Covers 18 files: WallClockAdoptionTests, BondClockZoneInvarianceTests, CouponPeriodCalendarTests, ExcelBondFunctionTests, AccruedInterestTests, CashFlowParityTests, DepreciationTests, AnnuitySolvingTests, GraphTests, CentralityTests, ProjectionAndCommunityTests, MarkovTests, ConcentrationTests, SurvivalTests, ClassifierEvaluationTests, LogisticRegressionTests, ExperimentDesignTests, SequentialTestingTests. Companion to the twenty-five preceding domain reviews.*

*All reference values independently recomputed: Gini both ways, Kaplan-Meier with Greenwood standard errors, AUC by pairwise enumeration, R's power formulas, design effects.*

## 1. Summary

This batch contains two files that close findings from earlier reviews, and a consistent house style across the rest: an identity or invariance that needs no reference, plus external values where an identity cannot pin the scale.

**`BondClockZoneInvarianceTests` implements the recommendation from the time-series review** — a zone-invariance sweep over the date-handling code — and adds something my recommendation did not: a proof that the sweep works.

> "A detector that has never been observed to fire is indistinguishable from one that cannot, and this entire file exists because a suite that *could not fail* was mistaken for a suite that passed. So: a function that plainly does read the zone must be reported as reading it."

`theSweepDetectsAKnownDependence` runs `Calendar.current.component(.day, from:)` through the sweep and requires `!isInvariant`, because 15 November at UTC midnight is the 14th in New York and the 15th in Tokyo. Only then are the real sweeps trusted. The file also states how it pairs with its sibling: `CouponPeriodCalendarTests` pins Microsoft's published values in one zone, and this file asserts the invariance those values depend on — "The two together are what the original suite lacked — it had values, built in the same zone the code read, and so could not fail."

That is the same self-testing-oracle pattern as `enumerationIsItselfCorrect` in the integer-programming certificate file and the paired property/violation tests in the interpolation review, reached independently for a third time.

**`WallClockAdoptionTests` is 33 tests of injected-clock adoption, every one an exact equality**, and its header explains why a tolerance would be self-defeating:

> "A tolerance would defeat the purpose: the point of injecting a clock is that the moment is no longer approximate, and a test written with a tolerance passes just as well against `Date()` — which is the state these tests were written to replace."

It also makes a distinction I have not seen elsewhere and which my own proposed gate rule needs as a carve-out. Nine tests assert that the *default* path uses the system clock, and they bracket rather than tolerate:

> "Bracketed rather than given a tolerance. The property is that the instant came from the system clock, and an instant between two readings of that clock is exactly that claim — true no matter how slow the machine is. A slack window asserts a duration instead, which is a different thing and can be unlucky."

**The remaining files share a structure worth naming.** Each identifies one oracle that costs nothing, then adds external values only where the identity cannot fix the scale:

| File | The free oracle | Verified |
|---|---|---|
| ClassifierEvaluation | AUC equals the Mann–Whitney U statistic over positive-negative pairs | 0.96, 0.875, 1.0, 0.0 — exact on all four fixtures |
| Markov | A chain built from journeys reproduces those journeys' conversion rate — 6 of 10 convert, absorption is exactly 0.6 | exact |
| Concentration | Gini from the Lorenz area equals Gini from pairwise differences | agree to 1e-12; external values 0, 0.2666666667, 0.76, 0.62 all exact |
| Survival | Kaplan-Meier without censoring is the empirical survival function | plus Greenwood errors verified to 10 digits |
| Depreciation | Every schedule totals the depreciable base | exact |
| CashFlowParity | Two cash-flow constructions agree | — |
| Centrality | PageRank sums to one; the eigenvector has unit length | — |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`ClassifierEvaluationTests`' header cites tie-convention values that do not correspond to any standard convention** | The header says half-credit gives "0.875 rather than the 0.8125 or 0.9375 that dropping or full-crediting ties gives." On the `withTies` fixture (4 positives, 4 negatives, 16 pairs, 12 strict wins, 4 ties) I get: half-credit **0.875** = 14/16 ✓; strict wins over all pairs **0.750** = 12/16; ties as wins **1.000** = 16/16; tied pairs dropped from both numerator and denominator **1.000** = 12/12. Neither 0.8125 (13/16) nor 0.9375 (15/16) arises — they look like 14/16 ∓ 1/16. | Fix the header. The asserted value is correct and the Mann–Whitney identity is the right oracle, so the test is sound; only the motivating arithmetic is wrong. This is the same class as the `npvExcel` header expression in the differential-reference review — a provenance note a reader would reproduce and get a different answer from. |
| 2 | **`CentralityTests` mixes exact values with ordering-only assertions** | The five measures are each pinned to 1e-6…1e-12 against reference values, which is right. But the fixture's motivating test asserts only `bridgeDegree < hubDegree`, `bridgeRank <= other` and `bridgeBetween >= other`, with `bridgeBetween > 0.5`. | Those orderings are the file's argument for shipping all five measures — §12.3's finding that "degree matched PageRank to within noise on one dataset" — so they carry real intent. Making them quantitative would carry it better: the point is that betweenness *separates* the bridge from the hubs by a large margin where degree does not, and that margin is computable from the fixture. |
| 3 | **`ExperimentDesignTests` is labelled RED phase** | The header says "RED phase for v2.7.0 — see project/plans/upcoming/v2.7.0_SCOPE.md §5." Its assertions are exact integers (1565, 8158, 5142 per arm) with R's unrounded values in the messages. | If the implementation now satisfies them, drop the RED-phase label — it tells a reader the tests are expected to fail. I verified the methodology: R's `power.prop.test` normal approximation at p₁ = 0.05, p₂ = 0.06, α = 0.05, power = 0.80 gives **8157.731**, matching the file's second case exactly, so the references are reproducible as claimed. |

## 3. Techniques worth propagating

### 3.1 Prove the detector fires before trusting it

`BondClockZoneInvarianceTests` inverts the usual order: before asserting that eleven functions are zone-invariant, it asserts that one function known to read the zone is *reported* as reading it. Without that, an invariance sweep that silently tested nothing would pass identically.

The sweep's coverage is thorough and the fixtures are chosen for the rules they turn on: day counts are swept across all cases with "a February month end to a 31st: the pair both 30/360 rules turn on", and the note records why that case matters — "fixing three of four left the fourth looking like a rule defect. This is the check that would have said so", which is the finding the valuation review made about `thirty360` versus `siaThirty360`.

One structural detail: the `Bond` struct holds settlement and maturity "built once at UTC midnight and passed into the sweep rather than rebuilt inside it." Rebuilding inside the sweep would make each zone construct a different instant, which tests the constructor rather than the function.

### 3.2 Bracketing versus tolerating

The distinction `WallClockAdoptionTests` draws is worth stating generally. For a test of "this value came from the system clock":

- **A tolerance** (`abs(recorded - Date()) < 0.1`) asserts a *duration* — that no more than 100 ms elapsed. It can fail on a loaded machine and it passes for a clock that is merely close.
- **Bracketing** (`before <= recorded && recorded <= after`) asserts *ordering* — that the instant lies between two readings of the clock in question. It cannot fail for a correct implementation however slow the machine, and it fails for any other clock.

That means my proposed gate rule — flag `Date()` in test targets — needs an exception: two readings bracketing a call, where the assertion is a comparison against both. The rule should flag a `Date()` reading used in an *arithmetic* comparison and allow one used as an ordering bound.

### 3.3 An identity that reimplements the definition, not the implementation

`ClassifierEvaluationTests`' Mann–Whitney helper is a naive O(n²) double loop, and the comment says why:

> "Deliberately the naive `O(n²)` double loop rather than anything clever: this is the definition, and a test that reimplements the implementation's optimisation checks nothing."

The implementation integrates the ROC curve; the test counts pairs. Different computations over different intermediate structures, so agreement is evidence. And the file identifies where the identity earns its keep — ties, "where AUC implementations go wrong" — with a fixture built around them.

### 3.4 The free oracle, stated as such

`MarkovTests`' header is the clearest short version:

> "A chain built from observed journeys must reproduce the conversion rate of those journeys… That is not a coincidence to be checked to a tolerance — it follows from the transition counts being the empirical ones — and it breaks immediately if the matrix is built wrong, if the start state is mis-seeded, or if absorption is solved incorrectly."

Three distinct defects, one assertion, no reference. `ConcentrationTests` does the same with two routes to Gini, and adds the bound that most implementations get wrong: maximum inequality on a finite sample is (n−1)/n, not one — 0.5, 0.8, 0.9 and 0.98 at n = 2, 5, 10, 50, with `gini < 1` asserted alongside.

### 3.5 A published value that is not the naive one

`SequentialTestingTests` asserts that five looks at a nominal 0.05 cutoff give a **0.1417** error rate. The naive independent-looks calculation gives 1 − 0.95⁵ = 0.226; the correct figure for accumulating data with correlated statistics is about 0.142, which is the published Armitage–McPherson–Rowe value. Asserting the right one means the test fails for an implementation that treats the looks as independent.

Its Pocock design test is also well shaped: boundaries clustered on the published 2.413, with `spread < 0.08` for tightness *and* `spread > 0.01` because "an exactly flat result would mean the wrong design." That second assertion is the non-degeneracy guard the reviews keep recommending.

## 4. Coverage gaps

**Clock adoption.** The file covers CapTable, the async gradient descent optimizer, ModelDebugger, template registry and financial projections. Worth checking against the corpus-wide `Date()` inventory: the helpers review found `Date()` in `ParallelOptimizerTests`, and the time-series review found 16 uses across the period files. If those types now take a clock, the adoption sweep should include them; if not, they are the remaining work.

**Zone invariance.** The bond path is swept. The time-series review found 73 `Calendar.current` uses in the period and fiscal-calendar files, and the valuation review found 50 more in the bond and callable-bond tests. The `ZoneInvariance` helper exists and generalises; extending the sweep to `Period`, `FiscalCalendar` and the DST boundary cases would close that finding the same way.

**Survival.** Kaplan-Meier, Greenwood, median, restricted mean and log-rank are covered. Missing: a stratified log-rank, and the case where the two groups' curves cross — where the log-rank test has low power by construction and a naive implementation can report significance from a crossing rather than a difference.

**Classification.** AUC, KS, confusion matrix, calibration and gains are covered. Missing: precision-recall AUC, which differs from ROC AUC on imbalanced data and is the metric that matters there; and a fully imbalanced fixture (1 positive in 1000) where ROC AUC stays high while precision collapses.

**Concentration.** Gini, Lorenz and top share are covered. Missing: Herfindahl-Hirschman, if shipped — it has a documented convention question (shares as fractions versus percentages, giving indices in [0,1] or [0,10000]) of exactly the kind the marketing review's named-variant design resolves.

**Markov.** Steady state, absorption, expected steps and removal effect are covered. Missing: a chain with a loop (the gap the attribution review noted for the same removal-effect machinery), and a reducible chain with two distinct closed classes, where the steady state is not unique.

**Graph and community.** `GraphTests` and `ProjectionAndCommunityTests` were surveyed rather than read in detail. Given the marketing review's finding that dictionary iteration order made k-means non-reproducible, the question worth checking is whether the community detection and projection paths publish a deterministic node order.

## 5. Recommended order of work

1. **Fix the tie-convention arithmetic** in the `ClassifierEvaluationTests` header (§2 item 1).
2. **Drop the RED-phase label** from `ExperimentDesignTests` if it now passes (§2 item 3).
3. **Extend the zone sweep** to `Period` and `FiscalCalendar` (§4), which closes the largest remaining item from the time-series review — the helper and the pattern both already exist.
4. **Extend the clock-adoption sweep** to whatever remaining types take a clock (§4).
5. **Make the centrality separation quantitative** (§2 item 2).
6. **Add the precision-recall AUC and an imbalanced fixture** (§4).
7. **Add the Markov loop and reducible-chain cases** (§4).

## 6. Gate rules

**One refinement, and it matters.** The proposed rule *flag `Date()` in test targets* needs an exception for bracketing. Two readings around a call, with the recorded instant asserted between them, is the correct way to test that a default path uses the system clock — and it is strictly better than a tolerance, per §3.2. The rule should flag a `Date()` reading that feeds an arithmetic comparison (`abs(x - Date()) < t`) and permit one that feeds an ordering bound (`x >= before && x <= after`).

**One positive pattern to add.** *A detector must be shown to fire.* An invariance sweep, a difference detector, or any test whose passing condition is "nothing changed" needs a companion case where something does change, asserted to be detected. `BondClockZoneInvarianceTests` states the reasoning most plainly — "a detector that has never been observed to fire is indistinguishable from one that cannot" — and the corpus now has four independent instances of the same idea: this file's sweep self-test, `enumerationIsItselfCorrect` in the integer-programming certificates, the interpolation review's paired property/violation tests, and the 30/360 variants' "they must differ where February *is* involved."

Existing rules that apply: exact-equality-over-tolerance where a value is determined (§1, and this batch is the model), and the non-degeneracy guard (`spread > 0.01` in §3.5).

## Appendix. Verified values

### A.1 Gini and Lorenz

Both routes — Lorenz area and pairwise differences — agree to 1e-12 on every dataset, and all four external values are exact.

| Values | Gini |
|---|---|
| [10, 10, 10, 10, 10] | **0.0** exactly |
| [1, 2, 3, 4, 5] | **0.2666666667** |
| [1, 1, 1, 1, 96] | **0.76** |
| [50, 25, 12, 6, 3, 2, 1, 1] | **0.62** |

Maximum inequality on a finite sample is (n−1)/n: 0.5 at n = 2, 0.8 at n = 5, 0.9 at n = 10, 0.98 at n = 50. Top quarter of the eight-value dataset: 0.75 exactly.

### A.2 Kaplan-Meier with Greenwood standard errors

Times [6, 7, 10, 15, 19, 25, 25, 28], events [T, F, T, T, F, T, F, F]. All four points verified to 10 digits.

| t | At risk | Events | S(t) | Standard error |
|---|---|---|---|---|
| 6 | 8 | 1 | **0.8750000000** | **0.1169267933** |
| 10 | 6 | 1 | **0.7291666667** | **0.1649762364** |
| 15 | 5 | 1 | **0.5833333333** | **0.1855609613** |
| 25 | 3 | 1 | **0.3888888889** | **0.2012691215** |

The censored observations at t = 7, 19, 25 and 28 leave the risk set without producing a point, which is the estimator's whole content.

### A.3 AUC and tie handling

| Fixture | AUC (Mann–Whitney, half-credit ties) |
|---|---|
| noTies | **0.96** |
| withTies | **0.875** |
| perfect | **1.0** |
| inverted | **0.0** |

The `withTies` fixture has 4 positives, 4 negatives, 16 pairs, 12 strict wins and 4 ties:

| Convention | Value |
|---|---|
| Half credit for ties (correct, asserted) | 14/16 = **0.875** |
| Strict wins over all pairs | 12/16 = 0.750 |
| Ties counted as wins | 16/16 = 1.000 |
| Tied pairs dropped from both | 12/12 = 1.000 |

Neither 0.8125 nor 0.9375 arises — see §2 item 1.

### A.4 Confusion matrix

TP 4, FP 0, FN 1, TN 5, total 10. Sensitivity 4/5 = 0.8, specificity 5/5 = 1.0, precision 4/4 = 1.0 — all exact, and the counts partition the data.

### A.5 Experiment design

R's `power.prop.test` normal approximation, α = 0.05 two-sided, power = 0.80:

| p₁ | p₂ | n per arm |
|---|---|---|
| 0.05 | 0.06 | **8157.731** → 8158 (matches the file's second case exactly) |

Design effect 1 + (m − 1)·ICC ≈ 4.0731 is reproduced by several (m, ICC) pairs — m = 50 at ICC 0.0627 gives 4.0723, m = 31 at 0.1024 gives 4.0720 — so the asserted 4.0731 ± 0.001 pins whichever pair the fixture uses.

### A.6 Sequential testing

| Quantity | Value |
|---|---|
| Type I error at five looks, nominal 0.05 | **0.1417** (published; asserted ± 0.002) |
| The naive independent-looks figure | 1 − 0.95⁵ = 0.226 — *not* what is asserted |
| One look | 0.05 |
| Pocock five-look boundary | **2.413** (asserted ± 0.04, with spread bounded both above and below) |
