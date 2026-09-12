# BusinessMath statistics test suite: validated review and remediation plan

*September 2026. Covers 86 test files across six batches: probability distributions and binomial,
descriptive statistics and agreement, ANOVA/estimation/regression, reliability and mixed models,
special functions and nonlinear regression, and the shared quantile layer.*

*An external review arrived 2026-09-12. This document is that review **after validation** — about
45 of its claims checked against the tree or recomputed with mpmath at 20–40 digits. Companion to
`REVIEW_simulation_tests.md`, which was validated the same way.*

## 1. Summary

**The incoming review is accurate.** Every exact value checked out: the five incomplete-beta
decimals, `chiSquaredCDF(50,50)`, the exact rationals (`1/26`, `8/19`, `2/7`, `−2/21`, `80/83`),
the t-tails, the variance of 1…10000, and Brennan's EMS coefficients. Its structural claims held
verbatim in every case tested.

**Three corrections** are recorded in §2.2. One is a stale claim being carried between reviews for
the second time; one has a real defect with an inverted diagnosis and two wrong reference values;
one is a pair of undercounts.

The decisions in §3 were taken by the author 2026-09-12 and close eight open convention questions
that between them blocked **32 assertions** written as `isNaN || ≈ 0`.

## 2. Validation

### 2.1 What was checked

| | |
|---|---:|
| checked against the tree or recomputed | ~45 |
| found correct | ~42 |
| corrected in §2.2 | 3 |

Confirmed verbatim, among others: `weightedPercentile` is Hazen/type-5 (it places observations at
`midpoints`; R-5 gives 2.25 at n = 7, p = 0.25 where R-7 gives 2.5) · `LRSquaredAdjusted` calls
`rSquared` and asserts `0.91983`, *and* uses `.rounded(.up)` · the D-study tests recompute
`sigmaE / Double(nrPrime)`, the implementation's own formula · `RandomSlopeTests` substitutes
`DenseMatrix(rows: 20, columns: 2, repeating: 0.0)` in a `catch` · `MatrixBackendBenchmarks` carries
suite-level `.requiresMetalGPU` over **6** CPU and Accelerate tests · `logNormalCDFComplementary`
computes `1.0 - cdf` and then asserts the two sum to one · `LVarianceTDist` computes
`Double(df)/Double(df-2)` in the test body · the `chiSquaredCDF(13.816, 5)` test tests `15.086`
against `0.99` · `pearsonUsesMarginialResiduals` has the typo.

**§A.6 independently confirms all 21 reference values in `BesselFunctionsTests`**, including the two
corrections that file makes to the design proposal's own table.

### 2.2 Corrections to the incoming review

**1. Item 9 (`normalCDF` lower tail) is stale, for the second time.** The code is already
`T.erfc(-scaled) / T(2)` — the exact fix recommended — since `91ca7f03`, whose commit message reads
*"the lower tail was noise, and everything downstream inherited it."* The review labels it "carried
from the distribution review", where the previous session had **already** established it was stale.
A dead claim is propagating between reviews; it should be struck at the source.

**2. Item 5 (`binomialPMF`) has the mechanism inverted, and both its reference values are wrong.**

Tested directly. `n = 30` does **not** trap: `combination` guards with `if n <= maxFactorialInt` and
takes the multiplicative branch, returning `C(30,15) = 155117520`. What does trap is `n = 2000`,
with SIGTRAP, because `result = result * (n - i) / (i + 1)` overflows `Int` in that same
multiplicative loop. The defect is real and the fix (log-space) is right; the diagnosis is
backwards.

Its reference values are also wrong:

| | review | correct |
|---|---|---|
| `binomialPMF(30, 15, 0.5)` | 0.14446444809436781 | **0.14446444809436798** |
| `binomialPMF(2000, 1000, 0.5)` | 0.017839011145854313 | **0.01783901114585432** |

The first is **exactly scipy's output**, and scipy is out by about 5 ulp. The true value is
`C(30,15)/2³⁰` — a rational with a power-of-two denominator, computable with no oracle at all. The
second matches neither scipy (`…431`) nor the exact value (`…432`) and looks like a transcription
slip.

The review's header says values were recomputed "with mpmath (30–40 digits) **or scipy**." That
"or scipy" is the crack, and it is the same trap the review itself documents in §A.6, where it
notes SciPy is out by 1.8e-12 on `J₂₀₀(3000)`. **Reference values for this suite should come from
mpmath or from exact arithmetic, never from another approximating library.**

**3. Two undercounts.** `close(_:_:accuracy:)` has 4 definitions, not one declaration with three
users. The `Bundle.module.url` fixture-loading dance appears in 13 files against
`ReferenceFixture.load`'s 9, not 5 against 4. Direction right, magnitude off.

## 3. Decisions taken (2026-09-12)

1. **Empty collections, NaN and infinity — two tiers.** Free functions return `T.nan`; the composed
   and checked entry points **throw**. This is the shape already used by
   `factorial`/`factorialChecked`, and it settles §3's questions 1–4 together. Free functions are
   the "you validated it" tier; anything linked into a larger analysis throws.
2. **Binomial descriptors** follow that rule. `meanBinomial`, `varianceBinomial` and
   `stdDevBinomial` are currently unguarded — `T(n) * prob` and `T(n) * prob * (1 - prob)` — so
   `n = −5` returns a mean of −2.5 and `p = −0.5` returns a **negative variance**. Both are
   plausible-but-wrong, which the fail-silent rule forbids. They return `T.nan`, with throwing
   `…Checked` variants for the recoverable path.
3. **`weightedPercentile` reduces to R-7 under equal weights**, and joins
   `QuantileConsistencyTests`. No convention flag: `winsorizedWeightedVariance` uses the result only
   as a clipping boundary and has no need for Hazen, nothing in the library needs a second
   convention today, and `quantile(sorted:p:)` — the R-7 one — has 32 call sites. A fourth
   percentile convention behind a flag is the same risk `QuantileConsistencyTests` exists to catch.
   Revisit if Excel `PERCENTILE.EXC` parity lands.
4. **`weightedVariance` gains a weight-kind flag, defaulting to `.frequency`.** Both denominators
   have real users, so this one earns a flag. The default preserves every current result.

   **Its docstring contradicts its formula and must be corrected.** The first line says "Computes
   the weighted variance using **reliability weights**"; the formula three lines below is
   `/ (sum(w_i) - 1)`, which is the **frequency**-weight denominator. Reliability weights need
   `W − Σwᵢ²/W`. The body then muddies it further by claiming usefulness for "reliabilities,
   frequencies, or precisions" — all three conventions at once. The formula is the only unambiguous
   statement and is taken as the intent.
5. **`SimulationStatistics` exposes the skewness estimator, defaulting to `.sample`.** No new
   machinery: `skew(_:_ pop: Population = .sample)` already dispatches to `skewS` (G1, Excel `SKEW`,
   unbiased under normality) and `skewP` (g1, Excel `SKEW.P`). The defect is only that
   `simulationStatisticsSkewness` asserts `> 0.5`, which passes for both estimators; it should
   assert **1.059228**.
6. **PERCENTRANK** is settled and is the model: measure the behaviour, then pin it. 5/9 returns
   0.556, so the spreadsheet rounds rather than truncates.
7. **`binomialPMF` moves to log-space.** In scope, and paired with decision 2.
8. **Nakagawa R², QQ plotting positions and residual scaling need no flags**, for three different
   reasons:
   - **Residual scaling is not a convention question.** `standardizedResiduals` (divides by
     `√varianceResidual`) and `pearsonResiduals` (divides by `√(varianceRandom + varianceResidual)`)
     both already exist as public functions. Only one is pinned by a test; that is a missing test,
     not an API decision. **Separately:** `standardizedResiduals` omits the leverage term
     `√(1−hᵢᵢ)`, so it is "scaled by the residual SD" rather than standardized in the textbook
     sense. The name overpromises and should be documented or changed.
   - **Nakagawa's 2017 revision is identical here.** It adds a distribution-specific variance term
     for GLMMs. This library is Gaussian-only — no families, no link functions — and for a Gaussian
     LMM the 2017 formulation reduces to the 2013 one, which is what is implemented. Add the flag
     when GLMMs land.
   - **QQ plotting positions get a `PlottingPosition` flag, defaulting to Blom.** This one differs
     from the other two and the difference is what justifies the flag: the positions are a single
     one-parameter family, `p_i = (i − a)/(n + 1 − 2a)`, so the whole set costs one enum and one
     constant rather than two code paths.

     | Member | a | p at n = 10, i = 3 |
     |---|---|---|
     | Weibull (1939) | 0 | 0.272727 |
     | Benard median ranks | 0.3 | 0.259615 |
     | Filliben (1975) | 0.3175 | 0.258804 |
     | Tukey (1962) | 1/3 | 0.258065 |
     | **Blom (1958)** — default | **3/8** | **0.256098** |
     | Cunnane (1978) | 0.4 | 0.254902 |
     | Hazen (1914) | 1/2 | 0.250000 |

     Blom is the default, and *not* because it is oldest or newest — "most recent" does not select
     here, since these are alternatives rather than revisions and Cunnane (1978) would win that
     test. Blom is right for **normal** QQ plots specifically: `(i − 3/8)/(n + 1/4)` is the best
     simple approximation to `E[Φ⁻¹(U₍ᵢ₎)]`, which is exactly what the plot's y-axis is. Weibull
     and Hazen have their own constituencies — hydrology and reliability engineering — which is why
     they are offered rather than argued away.

   Nakagawa and the residuals keep their current behaviour and gain a documented rationale naming
   the alternatives; all three gain a test that pins the choice.

## 4. Library defects

Beyond the decisions above, the review's remaining library items, with verdicts:

| # | Item | Verdict |
|---|---|---|
| 2 | Two files disagree about weighted Bland-Altman — one asserts 1e-10 at equal weights, the other allows 0.1 at λ = 1.0 | Unverified; both cannot be right. Resolve by measurement |
| 3 | `confidenceInterval` is a coverage interval | **Already decided** — `coverageInterval` plus a real `confidenceInterval`. Tracked in `REVIEW_simulation_tests.md` §5.3; not duplicated here |
| 4 | `rSquaredAdjusted` untested; `LRSquaredAdjusted` calls `rSquared` | Confirmed. Adjusted value for that data is 0.9118029115 against the unadjusted 0.9198208287 |
| 7 | `tCDF(t:df:)` takes `Int` df, `DistributionStudentT` takes `Double`; never compared | Unverified; add a delegation test using `identical` |
| 8 | Tail probabilities may be computed by subtraction | Reference values confirmed: `tPValue(t: 20, df: 10)` = 2.1460623172042523e-9, `t = 100` = 2.44968955541983e-16 |
| 10 | `ExpressionArray.normalize` divides by the sum while `norm()` is Euclidean | Confirmed. **Documentation only** — no API change |
| 11 | `successiveDifferences` returns absolute differences | Unverified |
| 12 | `DistributionSeedingTests.seedArray` feeds (u, 1−u) ramps | Unverified |

## 5. Order of work

**Phase A — decisions into code.** The two-tier NaN/throw rule across the descriptors; binomial
descriptor guards plus `…Checked` variants; `weightedPercentile` to R-7; `weightedVariance`'s
weight-kind flag and corrected docstring; `SimulationStatistics` skewness exposure; `binomialPMF`
in log-space.

**Phase B — the 32 blocked assertions.** With the tier rule settled, every `isNaN || ≈ 0`
disjunction becomes a single assertion.

**Phase C — tests that cannot fail.** The D-study suite first (~20 assertions with no discriminating
power), using the hand-computed values: `oneFacetGResult` has σ²_p = 20/3, σ²_r = 1, σ²_e = 0, so at
n_r' = 4, σ²_δ = 0, σ²_Δ = 0.25, ρ² = 1, Φ = **80/83 = 0.963855421686747**. Then
`logNormalCDFComplementary`, `LVarianceTDist`, `vifPerfectMulticollinearity`, and the
`#expect(Bool(true))` markers.

**Phase D — tolerances and exact answers.** Replace the rounding-as-tolerance idiom (~15 tests, four
using the asymmetric `.rounded(.up)`); assert the exact values in §A at 1e-12; tighten the §4.5
table.

**Phase E — the weak files.** Delete `NonlinearRegressionTests` and `ModelValidationEdgeCaseTests`,
moving their distinct cases into `ReciprocalRegressionScaleTests` with real expectations.

**Phase F — oracle gaps.** Generalized G-study first; then `nestedANOVA`/`multiWayANOVA`,
`generateEMSTable`, `clusterICC`/`designEffect`/`nakagawaR2`, LME diagnostics, the LRT statistic.

**Phase G — hygiene and duplication.** The `close`/`agrees` duplication, fixture loading onto
`ReferenceFixture.load`, the 260 type-only error assertions, `RandomSlopeTests`' zero-matrix
fallback, `MatrixBackendBenchmarks`' misplaced suite trait.

## 6. Quality-gate additions

Beyond those already proposed in `REVIEW_simulation_tests.md` §7:

1. **Self-recomputation.** Flag a test that derives its expected value by calling the same library
   function, or by restating its formula over values pulled from the result under test.
2. **Rounding as tolerance.** Flag `(x * 10^k).rounded() / 10^k` compared at a tolerance finer than
   the rounding.
3. **Reference provenance.** A fixture generator that imports an approximating library for a
   quantity with a closed form should say why. See §2.2 item 2.
4. **Disjunctive contracts.** Flag `isNaN || …` in an assertion; after decision 3.1 there is one
   right answer.

## Appendix A. Verified reference values

Recomputed here with mpmath at 20–40 digits, or exactly.

| Quantity | Value |
|---|---|
| I₀.₃(2,5), I₀.₁(3,7), I₀.₆(5,5) | 0.579825, 0.052972138, 0.73343232 |
| I₀.₅(2,3) = 11/16, I₀.₀₀₁(2,3) | 0.6875, 5.992003e-6 |
| `chiSquaredCDF(50, df=50)` | 0.5266015314436506 (the median of χ²(50) is 49.335) |
| `tPValue(t=20, df=10)`, `t=100` | 2.1460623172042523e-9, 2.44968955541983e-16 |
| CCC, offset-by-10 case = 1/26 | 0.038461538461538464 |
| CCC, y = 2x = 8/19 | 0.42105263157894735 |
| ICC(2,1) on the offset fixture = 2/7 | 0.2857142857142857 |
| Bland-Altman slope, y = 1.1x = −2/21 | −0.09523809523809523 |
| Φ at n_r' = n_r = 80/83 | 0.963855421686747 |
| Sample variance of 1…10000 = n(n+1)/12 | 8334166.666666667 |
| `binomialPMF(30,15,0.5)` = C(30,15)/2³⁰ | **0.14446444809436798** (not scipy's …781) |
| `binomialPMF(2000,1000,0.5)` | **0.01783901114585432** |
| Skewness of [1,2,3,4,5,10,15,20]: G1, g1 | 1.059228, 0.849272 |
| LogNormal(0,1): pdf(1), pdf(e⁻¹) | 0.39894228, **0.65774462** — x = 1 is the median, not the mode |
| Brennan EMS coefficients, n = (5,3,4,2) | 24, 12, 8, 6, 4, 3, 2, 1 (= 120 divided by 5 and by subsets of the rest) |
