# BusinessMath distribution test suite: consolidated review

*September 2026. Covers 40 distribution and statistics test files and the 7 TestSupport files they build on, reviewed in four batches.*

*Every numeric claim was checked by running the arithmetic. Reference values were computed with mpmath at 30–40 digits. Failure rates were measured by numpy simulation over 150 to 4,000 seeds, using each test's own clamp and parameterisation.*

## 1. Summary

The suite was written in three generations, and they sit side by side without sharing infrastructure.

**Generation 1** is the 2022 files and the October 2025 sampler files. It tests samplers statistically: it draws 1,000 to 10,000 values from a clamped LCG stream and compares a sample mean, median or histogram with an analytic value at a hand-picked tolerance. Six of these files (gamma, beta, t, χ², F, geometric) have been partly migrated to seeded xoshiro streams; the rest have not.

**Generation 2** is InverseNormalCDFTests and DistributionSeedDeterminismTests. It derives every tolerance from a measured error or a standard error, and names the regression each test guards.

**Generation 3** is the Risk Solver coverage files. Its oracles certify themselves:

- elicited points reproduced exactly;
- parameters recovered from their own quantiles;
- closed-form identities between families;
- a committed SciPy fixture with its generator script;
- a Kolmogorov–Smirnov (KS) test that handles discrete ties correctly.

The central finding is that generation 3 has already built most of what generation 1 lacks, but none of it lives in TestSupport, and none of its seventeen files imports TestSupport. The highest-leverage work is to promote that machinery into the shared layer and rebuild generation 1 on it.

In the process, the tests surfaced a number of library defects (section 2). They also contain a set of tests that cannot fail, fail silently, or fail for a correct implementation on some seeds (section 4). Finally, the quality-gate checker is now steering authors toward assertions that assert nothing (section 4.9).

These are the files to copy from:

| Kind of test | Template |
|---|---|
| Analytic functions | InverseNormalCDFTests |
| Seeding contracts and moments of sampling primitives | DistributionSeedDeterminismTests |
| External parity | RiskSolverScipyParityTests |
| Self-certifying round trips | PercentileFittingTests, MomentFitTests |

## 2. Library defects and API issues

| # | Issue | Evidence | Fix |
|---|---|---|---|
| 1 | `normalCDF` loses accuracy in the lower tail | `(1 + erf(x/√2))/2` cancels as erf approaches −1. Relative error is 3.9e-11 at z = −5, 2.3e-6 at −7 and 1.8e-2 at −8. InverseNormalCDFTests works around it with a private `accurateLowerCDF`; `logNormalCDF` inherits it. | Use `0.5 * erfc(-x/√2)`, which is at least as accurate everywhere. Then delete the workaround and the p ≥ 1e-4 restriction in `roundTripLibraryCDF`, and add lower-tail tests (Appendix A.1). |
| 2 | Bit-exact reproducibility depends on the Swift version | `gammaSumOfExponentials` reproduces the library's uniforms with `Double.random(in: 0...1, using:)`. That only works if the library maps generator output through the standard library, whose documentation says the algorithm may change between releases. `0...1` also includes 0, where −ln u is infinite. | A library-owned open-interval mapping, for example `(Double(x >> 11) + 0.5) * 0x1p-53`. |
| 3 | Two seeding regimes | Rejection-based samplers take `seed: UInt64` or `using:`. Inverse-transform samplers still take a single `Double` uniform, which the tests clamp to [0.0001, 0.9999]. | Give every sampler `seed:` and `using:`. Keep the `Double` entry points, documented as the quantile function (section 4.1). |
| 4 | Myerson loses precision beside its symmetric branch | The branch switches when b is within 1e-9 of 1. If the general branch is the textbook `(bʳ − 1)/(b − 1)`, it carries up to 3.9e-6 absolute error just outside the switch (measured with 50-unit arms at 90% confidence). | `expm1(r·log1p(b − 1))/(b − 1)` is exact to rounding at the same points and needs a special case only at b = 1 exactly. |
| 5 | PERT uses a singular shape formula | The symmetric-mode 0/0 exists only in the mean-based form α = (μ−a)(2m−a−b)/((m−μ)(b−a)). | The λ form α = 1 + λ(m−a)/(b−a), β = 1 + λ(b−m)/(b−a) gives the same shapes with no singularity. The branch and its continuity test then become unnecessary. |
| 6 | `DistributionLogNormal.mean` is not the mean | `mean` and `stdDev` are log-scale parameters. This is the trap `lognormalMeanIsNotItsMedian` warns about. `DistributionMVLogNormal` already uses `logMeans` and `logStandardDeviations`. | Rename, with deprecated aliases. |
| 7 | Solver `timeLimit: 0` means unlimited | The sentinel already caused one defect: an unguarded elapsed-time check made a zero budget expire immediately. | `timeLimit: Duration? = nil`. |
| 8 | Beta may return NaN at small shapes (conditional) | This applies if Beta is computed as a gamma ratio and shapes below 1 use the U^(1/k) boost. Then both gammas can underflow and X/(X+Y) is 0/0. In simulation, 22.6% of draws were NaN at α = β = 0.001. The tests draw one sample at 0.1. | Compute in log space. At minimum, test many draws at 0.01 and 0.001 to find out. |
| 9 | Combinatorics may overflow intermediates (to probe) | If computed from factorials, `combination(30, c: 2)` and `permutation(25, p: 2)` trap for `Int` or lose exactness for `Double`, although the answers are 435 and 600. | Use multiplicative formulas. Pin the contract for k > n, negative inputs and `factorial(21)`, with exit tests if trapping is intended. |
| 10 | Degenerate standard deviation is unspecified | `inverseNormalCDF(p: 0, mean: 5, stdDev: 0)` evaluates 5 + 0·(−∞) = NaN. Negative stdDev is untested. | Decide the contract and pin it. |
| 11 | Metalog feasibility near the tails (conditional) | Coefficients [0, −ε, 0, 10] reverse only below roughly y = ε/10, so any finite grid refinement can be defeated by a small enough ε. For unbounded metalogs, the limiting slope as y → 0 or 1 is set by the coefficients of the ln(y/(1−y)) terms, which allows an analytic check. | Add an ε = 1e-12 case. It shows which approach the implementation takes. |

## 3. TestSupport

### 3.1 Fixes to the existing files

| File | Issue | Fix |
|---|---|---|
| SeededRNG.swift | `reset()` returns to 12345, not to the initial seed. Only 32 bits of the seed are used: seeds 1 and 2³² + 1 give identical streams. It is a non-final, non-Sendable class, and its doc recommends it for new tests. | Mark it legacy and keep it only for bit-exact compatibility with migrated tests. |
| SeededRNG.swift (MMIX) | Uses Knuth's multiplier with increment 1, not Knuth's increment. | Document this, or someone will "correct" it and break every migrated test. |
| DeterministicHelpers.swift | `stochasticMigrationTopology` exists to hide a token from the checker, and the case is `.stochastic` anyway. The file imports BusinessMath. The closed-range `nextDouble(in:)` never returns its upper bound; the half-open form can (1.0..<2.0 gives 2.0 at the top raw value). `nextInt(in:)` traps on empty and very wide ranges. | Delete the topology helper. Factor out one unit-interval function. Add preconditions. |
| ConditionTraits.swift | `requiresParallelHardware` says "Skipped in CI" but skips everywhere. It tests `== "1"`, where `benchmarkOnly` deliberately tests `!= nil`. Five suites spell the benchmark gate inline. | One private flag helper; `@Suite(.benchmarkOnly)` for the five suites. |
| PlatformSupport.swift | Imports are file-scoped, so this file makes nothing visible to other files. `#else import Glibc` fails on Android, musl and Windows. | `@_exported` imports behind a `canImport` chain, inside the TestSupport module. |
| FloatingPointClaims.swift | Tolerance is absolute only. `approximatelyEqual(.infinity, .infinity)` is false. The collection overloads require both sides to be the same type. A Bool result gives poor failure messages on large vectors. | Relative tolerance with an `==` short-circuit (Swift Numerics' `isApproximatelyEqual` semantics). Two generic parameters. A recording helper that reports the first failing index and its delta. |
| HangGuard.swift | Exposed as a constant rather than a trait. | `extension Trait where Self == TimeLimitTrait { static var hangGuard }`. Document that time limits end cooperative hangs but may not stop a synchronous spin. |
| SolverBudgets.swift | BusinessMath-specific. | Move to a BusinessMath-only support target (3.4). |
| All generators | Five stream implementations (SeededRNG, MMIXSeededRNG, DeterministicGenerator, SplitMix64, DeterministicRNG) and no known-answer tests. | Converge on `DeterministicRNG` (Xoshiro256StarStar). Pin the first outputs of every generator (Appendix A.4). |

### 3.2 Helpers to promote

| Helper | Where it lives today | Notes |
|---|---|---|
| Distribution contract: quantile monotone and finite, `cdf(quantile(p)) ≈ p`, CDF bounded and non-decreasing with the right limits | `assertRoundTrip` and `assertMonotoneCDF` in RiskSolverClosedFormTests, generic over `ContinuousDistribution`. Reimplemented in the Myerson, Metalog, MomentFit, PERT, Histogram, Reparameterised and ContinuousShape tests. | Start from the ClosedForm version; make the grid and tolerance parameters. |
| Kolmogorov–Smirnov, continuous and discrete, with a critical value computed from α | Continuous: inline in RiskSolverScipyParityTests. Discrete: RiskSolverDiscreteSamplerTests, plus an inline copy in the parity file. | The discrete form must compare the two step functions at every integer, as the DiscreteSampler comment explains. |
| Standard-error tolerances | `4 * se` inline in about six places; the derivation in `geometricStructNext`. | `expectMean(_:equals:standardDeviation:sigmas:)` and a proportion variant. |
| Moments by integrating the quantile | MomentFit (Simpson in z), NormalSkew (midpoint in u), Reparameterised (midpoint in u). | Midpoint in u under-reports σ of N(30, 10) by 3.3e-4 at 20,000 steps; prefer the z-space form for unbounded supports. |
| Counting generator | `DrawCountingRNG` in DistributionSeedDeterminismTests. | Make it generic over the base generator. |
| Sample statistics | Private `sampleMean` and `sampleVariance` in DistributionSeedDeterminismTests; about forty inline reductions in generation 1. | One `SampleStatistics` type. |
| Seed streams | Fourteen file-local helpers in generation 1. | `seeds(count:master:)` over `DeterministicRNG`, and an open-interval uniform stream. |
| Diagnostic approximate equality | Hand-written `abs(a − b) < tol` with custom messages throughout. | Generation 3 annotates every intermediate as `Double` because Swift 6.2.1's `#expect` cannot type-check compound arithmetic. A helper moves the arithmetic out of the macro, which removes that workaround too. |
| Error-case assertions | A manual do/catch in PercentileFittingTests. | Swift 6.1's `let error = #expect(throws: E.self) { … }` returns the error for pattern matching. |

### 3.3 Conventions

Generation 3 spells "these are the same value" four different ways: `.isEqual(to:)`, `==`, sets of `bitPattern`s, and `abs(a − b) < 1e-15`. Settle on the FloatingPointClaims vocabulary:

- `identical` for a literal returned by a guard, a value passed through unchanged, and every reproducibility claim.
- `exactlyEqual` where either sign of zero is correct.
- `approximatelyEqual`, with a derived tolerance, for everything computed.

Reproducibility checks should never use `==` or `!=` on arrays. FloatingPointClaims' own documentation shows `==` failing on two identical NaN streams and `!=` passing on a stream that went NaN. Both forms appear in DistributionSeedDeterminismTests and MVLogNormalTests.

### 3.4 Module boundary

Split TestSupport into two targets:

- **A library-agnostic core:** floating-point claims, generators, traits, hang guard, platform imports, and the helpers above.
- **A thin BusinessMath-specific target:** solver budgets and anything that names a library type.

The core can then serve BioFeedbackKit and YahooFinanceKit unchanged. If SplitMix64 or DeterministicRNG must be shared between the library and its tests, put it in a small package beneath both. SwiftPM does not fetch test-only dependencies for downstream consumers.

## 4. Patterns across the suite

### 4.1 Inverse-transform samplers are tested statistically when their distribution can be checked exactly

With a `Double` seed, `distributionExponential(λ:seed:)` is not really a sampler: it is the quantile function evaluated at u. The same holds for Pareto, Weibull, logistic, Rayleigh and triangular, and for the Box-Muller normal and lognormal given (u₁, u₂). Their distributions can be checked at full precision instead of through 5,000-sample means.

At u = 0.5 the result does not depend on whether the implementation uses u or 1 − u:

```swift
@Test("At u = 0.5 each inverse-transform sampler returns its analytic median")
func mediansAtHalf() {
    #expect(approximatelyEqual(distributionExponential(λ: 2.0, seed: 0.5), log(2.0) / 2.0, tolerance: 1e-15))
    #expect(approximatelyEqual(distributionPareto(scale: 1.0, shape: 2.0, seed: 0.5), 2.0.squareRoot(), tolerance: 1e-15))
    #expect(approximatelyEqual(distributionWeibull(shape: 2.0, scale: 5.0, seed: 0.5), 5.0 * log(2.0).squareRoot(), tolerance: 1e-14))
    #expect(approximatelyEqual(distributionRayleigh(scale: 10.0, seed: 0.5), 10.0 * (2.0 * log(2.0)).squareRoot(), tolerance: 1e-14))
    #expect(exactlyEqual(distributionLogistic(50.0, 10.0, seed: 0.5), 50.0))
}
```

One parameterised test per family over a grid of u, checked against the analytic quantile, then pins down the whole distribution. It also pins the u versus 1 − u convention, which should be documented.

What remains per family is:

- parameter validation;
- one check that `next(using:)` matches `seed:` given the same uniform;
- the identities below.

Generation 3 already works this way: its continuous types expose `quantile` and are tested through it.

Several tests already use shared seeds, which turns their loose inequalities into exact identities:

| Test | Asserts | Actually exact |
|---|---|---|
| `paretoDifferentScales` | Mean ratio in 8–12, "due to heavy tails" | 10, with no sampling variance |
| `rayleighDifferentScales` | Ratio in 3–7 | 5 |
| `exponentialRateParameter` | Ratio above 4 | 5 |
| `triangularDifferentRanges` | Range ratio above 10 | 50 |
| `normalDifferentStdDevs` | range20 above 2 × range5 | Every sample is an affine image of the standard draw |
| LogNormal suite | Positivity, skew, median, relationship to the log | `distributionLogNormal(μ, σ, u₁, u₂) == exp(distributionNormal(μ, σ, u₁, u₂))`, if that is the construction |
| `weibullExponentialCase`, `weibullRayleighLike` | Means | Weibull(1, λ) is Exponential(1/λ), and Weibull(2, σ√2) is Rayleigh(σ), draw for draw |
| `rayleighAs2DNormalMagnitude` | A mean | σ·hypot(z₁, z₂) from Box-Muller equals σ√(−2 ln u₁) |

### 4.2 Test primitives statistically and compositions by identity

This is already partly in place:

- DistributionSeedDeterminismTests pins χ²(7) at seed 42 as bit-identical to `gammaVariate(shape: 3.5, scale: 2.0)` at seed 42.
- `gammaSumOfExponentials` pins Gamma(r, λ) as a sum of exponentials drawn from one stream.
- ContinuousShapeDistributionTests does the same at the quantile level: χ² is the Gamma it claims to be, t(1) is Cauchy, and χ²(2) is an exponential.

The plan: test `gammaVariate` (both shape branches) and the normal once, statistically, at n = 60,000, and pin every composition by identity. Once that is done, the roughly fifty mean, variance and skewness checks in the generation 1 gamma, beta, t, χ² and F files duplicate the moment suite with weaker tolerances.

### 4.3 Tolerances not derived from standard errors

Because the streams are pinned, every statistical assertion either always passes or always fails. The tolerance only matters when the seed or generator changes, which the consolidation in section 3 will do.

These assertions fail for a correct implementation on some seeds:

| Test | Assertion | Correct implementation fails on |
|---|---|---|
| `exponentialConstantHazardRate` | Hazard within 0.5 of λ at four times | 15% of seeds. The finite-Δt estimator is biased by −0.107 before any noise. |
| `logisticUnbounded` | Max abs(x) above 5 in 10,000 draws | 9.4%. The clamp caps abs(x) at 5.08. |
| `chiSquaredFunctionStatistics` | χ²(10) variance within 1.0 | 4.9% |
| `chiSquaredVarianceRelationship` | χ²(15) variance within 1.5 | 3.6% |
| `chiSquaredDF20` | χ²(20) variance within 2.0 | 2.7% |
| `paretoMeanShapeGreaterThan1` | α = 2 mean within 0.15, without the clamp | 1.0% |
| `fVarianceFormula` | F(5, 10) variance within 0.3 | 0.8%. DistributionSeedDeterminismTests declines to pin F's variance for exactly this reason. |
| MVLogNormal `sampleMatchesTheClosedForms` | cov(1, 2) within 6% | Rare, but only about 3 standard errors: 95th percentile 3.7%, worst of 150 seeds 5.6%. |

These assertions are too loose to catch much:

| Test | Tolerance | In standard errors |
|---|---|---|
| MVLogNormal means | 1.5% relative, described as "the honest bound" | 30–65. The worst of 150 seeds was 0.2%. |
| Sampled-quantile checks in Myerson, Metalog, PERT and MVLogNormal margins | 2–3% relative at 200,000 draws | About 30 at the median |
| Weibull mean | 15% | About 13 |
| Beta(2, 5) variance | 0.01 absolute | About 20 |
| `tFunctionRange` | 900 of 1,000 within ±3 | About 24 |
| Myerson and PERT continuity | 1e-3 for changes of 1e-6 to 1e-10 | A jump 10⁵ times the perturbation passes |

The fix is the same in both directions. Derive each bound as k standard errors from the analytic variance, as `geometricStructNext` does, or replace spot checks with a KS statistic against the CDF.

Choose α for the suite as a whole rather than per test. RiskSolverScipyParityTests runs at least 32 KS tests at α = 0.001, so a correct library has a 3.2% chance of at least one spurious failure whenever the streams change. Across the roughly 38 KS checks in the suite today that rises to 3.7%, and it grows as generation 1 moves to KS.

### 4.4 Tests that cannot fail

| Test | Why it cannot fail |
|---|---|
| `betaIndependence` | For Beta(2, 2), E[X₁X₂] = 0.25 + 0.05ρ, so the 0.05 bound fails only if ρ lies outside [−1, 1]. Normalise to a lag-1 autocorrelation and compare with about 4/√n. |
| `logNormalCDFComplementary` | It computes `survival = 1 − cdf` and then checks `cdf + survival ≈ 1`. |
| `fMeanDefinedForDF2GreaterThan2` | It checks `samples.count == 1000` after appending 1,000 samples. |
| Three `#expect(true) // TEST-QUALITY` lines | In ChiSquared and F `approachesNormal`, and DistributionSeeding `varConsistency`. |
| Unconditional counters | `#expect(checked == N)` after a loop that always runs N times. There are six in NormalSkewTests, eight in ContinuousShapeDistributionTests, four each in MetalogShapeTests and MultivariateAndFitTests, and MVLogNormal's `matched == 500`. Counters that guard a real skip path are useful and should stay: the parity file's `checked > 100`, the `if let` families in PercentileFittingCoverageTests, and `checked >= 1` in MetalogShape's mode test. |
| Four Inference tests and `LWeightedAverage` | They never call BusinessMath. The t-tests, chi-square and z-test compute everything inline. |
| `LHypergeometricProbability` | It rounds the result to one decimal and checks that it is about 0. |
| χ² mode for df 1 and 2 | An `if df >= 3` guard skips the assertion. |
| Most of DistributionSeedingTests | They check that a pure function returns the same output for the same input; `distributionUniform(seed)` simply returns its argument. |

### 4.5 Silent skips

The most serious is in RiskSolverScipyParityTests. `guard actual.isFinite, point.x.isFinite else { continue }` skips a case whenever the library returns NaN or infinity where SciPy has a finite value, which is exactly the failure the test exists to catch. Only the aggregate `checked > 100` would notice. Skip only when SciPy's value is non-finite, and in that case require the library's value to be the same infinity.

Smaller cases:

- `if !conditionedSamples.isEmpty` in two exponential tests and one geometric test: use `#require`.
- `samples.max() ?? 0` in Pareto.
- `d.antiModes()[1]` in MetalogShapeTests, which indexes without checking the count and would trap the whole test process.

### 4.6 Errors asserted by type only

PercentileFittingTests documents how asserting only `ParameterFitError.self` let a swallowed error survive: the Cauchy `.mean` constraint came back as `noSolution` and the test passed anyway. The same weak form remains in:

- `malformedConstraintsAreRefused` (four cases), whose name promises the constraint "reports itself" rather than failing to converge;
- `impossibleConstraintsFail`;
- `generalisedTriangularRefuses` (four cases);
- `sampleFitRefusesSmallSamples`;
- `unsupportedMoment`, which is the Lévy version of the exact Cauchy regression.

Assert the specific case in each.

### 4.7 Seeding

**Unseeded draws.** Three struct tests still draw from the unseeded path: `logNormalStructNext`, `rayleighStructNext` and `rayleighStructParameters`.

**The clamp truncates tails.** The [0.0001, 0.9999] clamp has visible effects:

- Box-Muller output is capped at abs(z) ≤ 4.29.
- Pareto α = 1.2 has a clamped mean of 4.92 against a true 6.0.
- The logistic cap is 5.08.
- The clamp also hides the u₁ = 0 contract.

**LCG pairs.** The Box-Muller helpers feed consecutive LCG outputs as (u₁, u₂), a pairing known to distort the tails.

**Seed ramps are not draws.** DistributionSeedingTests uses evenly spaced seeds instead of random ones. Its CVaR test's "N(100, 10)" samples all lie in [117.3, 120.4]. Its paired (u, 1 − u) seeds give a KS p-value of 3 × 10⁻⁸⁵ against the normal, even though their mean and standard deviation look normal.

**Unstable per-case seeds.** In the parity file, `seed: 41_000 &+ UInt64(exercised)` changes every later case's stream whenever an earlier distribution is implemented. Derive each seed from the fixture index or a stable hash of the case, not `hashValue`, which is randomised per process.

**Cross-suite coupling.** `LogNormalDistributionTests.seedsForLogNormal` and `ChiSquaredDistributionTests.seedSetsForChiSquared` are used by other suites. They should move to TestSupport.

### 4.8 Test names that promise more than the body checks

- **Struct tests that never touch the struct.** In the Pareto, Weibull, χ², F and t files, every struct-named test calls the free function, so those five structs are untested. The normal and lognormal files have two such tests each. Two comments claim the struct cannot be seeded, though other files call `next(using:)`.
- **Weibull failure rates.** Four failure-rate tests assert only x ≥ 0.
- **Exponential MGF.** `exponentialMGF` checks mean and variance, not the moment-generating function.
- **Triangular uniformity.** `triangularApproachesUniform` asserts the opposite of uniformity.
- **t with df = 2.** `tDF2Case` says deterministic seeding allows a tighter tolerance, which it does not.
- **NormalSkew.** `mappingMatchesRiskSolver` asserts the library's own mean and σ to 1e-3, while the Risk Solver evidence (about 200 draws, standard error near 0.6) supports agreement within about 2. State the external check at its real precision, and label the tight values as regression pins.
- **Alias sampler.** `discreteAliasMatchesInverse` never calls `quantile`.

### 4.9 The quality-gate checker

The checker is shaping the tests, often for the worse:

- It scans for `.random` and misses unseeded `.next()` on distributions.
- It prompted DeterministicHelpers, whose stated purpose is to keep a token out of scanned files.
- It evidently cannot see assertions in nested scopes or helper calls. That produced three `#expect(true)` markers, and in generation 3 a comment explaining that an extra assertion was added because a test looked "empty to a reader and to the checker alike". It plausibly explains the unconditional counters as well.

Recommended changes:

1. Count calls to TestSupport assertion helpers and assertions in nested functions.
2. Reject `#expect(true)`, and counters compared with their own loop bound.
3. Flag `next()` without `using:` on distribution types.
4. Accept `.random(in:using:)`.

The "Justification:" comments on documented unseeded calls are the right exemption pattern, and should be the only one.

### 4.10 Reference precision and provenance

RiskSolverScipyParityTests is the model. Its values were generated once by a committed script against a recorded SciPy version, are stored at full precision, and CI never runs Python.

The PERT, Reparameterised and ContinuousShape tests instead carry about forty inline SciPy literals with no recorded version. Nine spot-checked with mpmath are correct to every printed digit. But at 10–12 digits they cap tolerances near 1e-7 to 1e-9, where the implementations may be good to 1e-14. Route them through the fixture generator.

Hand-rounded constants have the same problem: Γ(1.5) written as 0.8862, 8/3 as 2.67, and 1/√(2π) as 0.3989. Some tests compare against a 3-digit expected value with a tolerance tighter than its own rounding: `normDist` checks 0.00621 ± 1e-6, and passes only because the true value happens to be 3.3e-7 away.

### 4.11 Mathematical errors in comments

| Location | Says | Correct |
|---|---|---|
| AdvancedStatistics `LLogNormalDistribution` | x = 1 is the mode of LogNormal(0, 1) | x = 1 is the median. The mode is e⁻¹, with density 0.6577 against 0.3989 at x = 1. |
| Pareto `pareto8020Rule` | α ≈ 1.5 models the 80/20 rule | 80/20 is α = log₄5 ≈ 1.16. At 1.5 the top 20% hold 58.5%. |
| Triangular PERT use case | PERT's expected time is (a + m + b)/3 | That is the triangular mean. PERT's is (a + 4m + b)/6. |
| LogNormalCDF Black-Scholes | "risk-neutral measure" with μ = 0.08 | That is the physical measure; risk-neutral pricing uses r. |
| Parity `minExtremeIsNotNegatedMaxExtreme` | The two are mirror images about the origin, not about their location | They are mirror images about their shared location: MinExtreme(m).quantile(p) = 2m − MaxExtreme(m).quantile(1 − p), verified to 9e-16. Assert that identity. |
| MomentFit `impossibleMomentsAreRefused` | β₂ ≥ β₁ + 1 follows from Var[(X − μ)²] ≥ 0 | That only gives β₂ ≥ 1; the bound follows from E[(Z² − γZ − 1)²] ≥ 0. The same test lists (0, 1) twice. |
| MultivariateAndFit `compoundMatchesWald` | The tolerance allows for clipping the normal's negative tail | P(X < 0) = Φ(−10); the tolerance is really simulation noise. |
| NormalSkew `coverageIsThreeSigma` | The constants agree to nine figures | Nine decimal places, which is seven significant figures. They differ by 8.3e-11. |
| StudentT `tDF2Case` | Deterministic seeding permits a tighter tolerance | Seeding freezes one realisation without reducing its variance. |

### 4.12 Hygiene

- **Loggers.** Most generation 1 files declare an unused `Logger`. Unless BusinessMath ships a Linux shim, they also fail to compile on Linux, because OSLog is imported conditionally but used unconditionally.
- **Imports.** Inference and AdvancedStatistics import Darwin/Glibc directly. The comment `import TestSupport // Cross-platform math functions` is wrong in every file that carries it.
- **Leftovers.** A "Test Template.swift" header; a stray `//^[[A` terminal escape at FDistributionTests line 334; swapped doc comments on NormalSkew's two helpers; a reference to "the brief" in InverseNormalCDFTests.
- **Duplication and naming.** The xoshiro migration comment is pasted into six files, and several file names contain spaces.

## 5. File-by-file dispositions

Generation key: **1** is statistical sampler tests, **1m** is partly migrated to xoshiro seeds, **2** is measured oracles, **3** is Risk Solver coverage.

| File | Gen | Disposition | Main items |
|---|---|---|---|
| InverseNormalCDFTests | 2 | Keep, small fixes | Use `identical` in exactSymmetry's first loop and in normInvAgreement. Accumulate the 200,000-point monotonicity check into one assertion. Pin the degenerate-stdDev contract. Delete `accurateLowerCDF` once §2 item 1 lands. |
| DistributionSeedDeterminismTests | 2 | Keep, small fixes | `!identical` in the nil-seed test; `identical` for the three array reproducibility checks; move helpers to TestSupport. |
| NormalDistributionTests | 1 | Rewrite | Affine identity, KS, and the u₁ = 0 contract. Move the seed helper to TestSupport. Exact check for zero stdDev. |
| LogNormalDistributionTests | 1 | Rewrite | exp(normal) identity; seed `logNormalStructNext`. |
| LogNormalCDFTests | 1 | Fix | Tail tests after §2 item 1. Delete the survival tautology. Assert ordering instead of `!identical`. Full-precision references; remove the duplicate test; add edge cases. |
| Normal Distribution Functions | 1 | Rewrite | Check every wrapper's delegation with `identical`. Remove `throws`. Fix the header. |
| Combination And Permutation Tests | 1 | Rewrite | Pascal and symmetry properties; overflow probe; merge AdvancedStatistics' duplicates. |
| ExponentialDistributionTests | 1 | Rewrite | Quantile grid. Delete the hazard test (15% seed failure). Test the memoryless property once. |
| ParetoDistributionTests | 1 | Rewrite | Quantile grid; scale identity; fix the 80/20 comment; exercise the struct. |
| WeibullDistributionTests | 1 | Rewrite | Quantile grid; Exponential and Rayleigh identities; drop the tests that only check non-negativity. |
| LogisticDistributionTests | 1 | Rewrite | Quantile grid. Delete `logisticUnbounded` (9.4% seed failure). |
| RayleighDistributionTests | 1 | Rewrite | Quantile grid; seed the struct tests; Box-Muller radius identity. |
| TriangularDistributionTests | 1 | Rewrite | Quantile grid, including the mode at u = (c − a)/(b − a). Fix the PERT comment and the misleading test name. |
| GammaDistributionTests | 1m | Trim | Keep `gammaSumOfExponentials` and parameter validation; drop the duplicated mean checks. |
| BetaDistributionTests | 1m | Trim | Replace `betaIndependence`; add a small-shape NaN test. |
| StudentTDistributionTests | 1m | Trim | KS; fix `tDF2Case`; test the struct. |
| ChiSquaredDistributionTests | 1m | Trim | The Gamma identity replaces the moment checks. Delete the three fragile variance checks and the `#expect(true)`. |
| FDistributionTests | 1m | Trim | Delete `fVarianceFormula`. Stop reaching into the χ² suite's seeds. Remove the `#expect(true)` and the stray escape. |
| GeometricDistributionTests | 1m | Trim | Use `==` for the integer predicate (NaN passes `identical`); exact mode check; `#require` instead of `if !isEmpty`. |
| DistributionSeedingTests | 1 | Delete | Move the boundary cases into DistributionSeedDeterminismTests, pinning u = 0. |
| Inference Tests | 1 | Rewrite | Four tests call no library code. Pin `confidence` at 0.69295191217483884. Keep the AB characterization test. |
| AdvancedStatisticsTests | 1 | Fix | Reference values from Appendix A.3; fix the lognormal mode comment; exact DataTable checks. |
| t Distribution Functions | 1 | Fix | Pin the t(100) density; exact tStatistic; test the throwing path. |
| RiskSolverClosedFormTests | 3 | Keep, promote helpers | Check the HypSecant scale deterministically: cdf(loc + σ) = (2/π)·atan(e^(π/2)) = 0.8695181135728437. |
| RiskSolverScipyParityTests | 3 | Fix | Remove the silent non-finite skip; suite-level α; stable per-case seeds; MinExtreme identity and comment. |
| RiskSolverDiscreteSamplerTests | 3 | Keep, promote KS | `identical` for returned values; rename `discreteAliasMatchesInverse`. |
| PoissonDistributionTests | 3 | Keep | `identical` for guard literals and the floored argument. The log-space reference's own error is 1.7e-13 against a 1e-12 bound, so that margin holds. |
| MyersonDistributionTests | 3 | Fix | Bound the continuity gap by a multiple of the nudge, probed on both sides of the switch. Add a near-symmetric case to the exactness table. KS for sampling. |
| MVLogNormalTests | 3 | Fix | Remove the `matched == 500` tautology; `identical` for reproducibility; standard-error-derived mean bound. |
| MetalogDistributionTests | 3 | Fix | Normal-equations oracle for the least-squares fit, if unconstrained (residuals orthogonal to each basis column). ε = 1e-12 feasibility case. KS for sampling. |
| MetalogShapeTests | 3 | Fix | Guard the `antiModes()[1]` index; drop the unconditional counters. |
| MomentFitTests | 3 | Keep, small fixes | Remove the duplicate (0, 1) case and fix the inequality comment; `identical` for the reported moments. |
| PertDistributionTests | 3 | Fix | λ-form shapes remove the branch and its continuity test. KS for sampling. |
| ReparameterisedDistributionTests | 3 | Fix | The Pareto2 tail test's premise is wrong: a naive cdf(1e-12) returns 4.9993e-13 (1.3e-4 relative error), not zero, so `p > 0` passes it. Assert relative accuracy near 1e-14 against −expm1(−q·log1p(x/b)). |
| HistogramAndCumulativeTests | 3 | Keep, small fix | Pin `quantile(0.5)` exactly on the zero-weight knot, which the header names as the risk. |
| PercentileFittingTests | 3 | Fix | Assert specific error cases. Use or drop the returned count consistently: it is discarded in 15 of 29 calls, including 11 of the 13 in `twoParameterFamilies`. |
| PercentileFittingCoverageTests | 3 | Fix | Specific error cases, including Lévy. Explain each widened tolerance with a well-conditioned control, as the triangular case does. |
| MultivariateAndFitTests | 3 | Keep, small fixes | Check Anderson–Darling against the 1% critical value for a fully specified null (3.857), not only right < wrong. Fix the Wald comment; drop the unconditional counters. |
| NormalSkewTests | 3 | Keep, small fixes | Separate external agreement from regression pins; fix the swapped doc comments; drop the unconditional counters. |
| ContinuousShapeDistributionTests | 3 | Keep | Move the literals into the fixture pipeline; drop the unconditional counters. |

## 6. Order of work

1. **Fix the library defects first.** Several tests cannot be written correctly until these land: the erfc `normalCDF`, a library-owned unit-interval mapping, `seed:` and `using:` on the inverse-transform samplers, the Myerson and PERT formulas, and the lognormal parameter names.
2. **Then TestSupport,** because everything after it depends on the shared layer: the fixes in 3.1, the helpers in 3.2, known-answer tests for the generators, and the module split in 3.4.
3. **Fix the tests that are themselves wrong.** This is small and high-value: the parity file's silent skip, the type-only error assertions, the unguarded index, the tests in 4.4 that cannot fail, and the three unseeded struct tests.
4. **Rebuild generation 1 on the new helpers:**
   - quantile grids and identities for the inverse-transform families;
   - trim the migrated families to identities and validation;
   - delete DistributionSeedingTests;
   - rewrite Inference and the wrapper tests.
5. **Sweep the tolerances.** Derive every remaining statistical bound from its standard error, set a suite-level KS α, stabilise per-case seeds, and move inline references into the fixture pipeline.
6. **Finish with the checker and hygiene:** the checker changes in 4.9, then loggers, imports, headers and names.

## Appendix A. Verified reference values

All values were computed with mpmath at 30 or more digits.

### A.1 LogNormal(0, 1) lower tail

Evaluated at the Double actually passed, x = exp(z).

| z | logNormalCDF(exp(z)) | Naive-form relative error | erfc-form relative error |
|---|---|---|---|
| −5 | 2.866515718791939e-07 | 3.9e-11 | 2.4e-15 |
| −6 | 9.865876450376983e-10 | 1.3e-10 | 2.9e-15 |
| −7 | 1.2798125438858354e-12 | 2.3e-6 | 3.2e-16 |
| −8 | 6.220960574271786e-16 | 1.8e-2 | 5.4e-15 |

### A.2 Normal and lognormal known values

| Quantity | Value |
|---|---|
| Φ(1) | 0.8413447460685429 |
| Φ(−1) | 0.15865525393145705 |
| logNormalCDF(1, μ = 0, σ = 1) | 0.5 exactly (log 1 = 0) |
| logNormalCDF(e) and logNormalCDF(1/e), standard | Φ(1) and Φ(−1); log(exp(±1)) round-trips exactly |
| LogNormalCDF Black-Scholes case (S₀ = 100, μ = 0.08, σ = 0.2, T = 1) | 0.3820885778110481 |
| LogNormalCDF documentation example (below 90) | 0.17701452303313378 |
| normDist(10, mean 10.1, stdev 0.04) | 0.006209665325776291 |
| 2Φ(−3) | 0.002699796063260189 |

### A.3 Statistics functions

| Assertion | Reference |
|---|---|
| `poisson(3, µ: 2.5)` | 0.21376301724973645 |
| `exponentialPDF(1, λ: 0.5)` | 0.30326532985631671 |
| `hypergeometric(total: 52, r: 4, n: 5, x: 2)` | 103776 / 2598960 = 0.039929818081078585 |
| `logNormalPDF(1, mean: 0, stdDev: 1)` | 0.39894228040143268 |
| `logNormalPDF(e, mean: 1, stdDev: 0.5)` | 0.2935253263474798 |
| LogNormal(0, 1) density at its mode e⁻¹ | 0.65774462347945691 |
| `geometricMean([1, 2, 3, 4, 5])` | 2.6051710846973519 |
| `harmonicMean([1, 2, 4])` | 12/7 = 1.7142857142857143 |
| `confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high` | 0.69295191217483884 |
| `studentTPDF(t: 2, df: 100)` | 0.05490864329540969 (normal density at 2 is 0.053990966513188052) |
| $100,000 at 3% over 360 months | 421.60403372945603 |
| AB test (85/1000 vs 110/1000, unpooled standard error) | normSDist of z = 0.9703652021; two-sided p = 0.05926959574 |

### A.4 Generator known answers

| Generator | First outputs |
|---|---|
| SplitMix64, seed 0 (reference algorithm) | 0xE220A8397B1DCDAF, 0x6E789E6AA1B965F4, 0x06C45D188009454F |
| SeededRNG(seed: 12345) | 0.02040268573909998 |
| MMIXSeededRNG(state: 12345) | 0.03136995109528535 |

### A.5 Closed-form anchors

| Quantity | Value |
|---|---|
| Median at u = 0.5: exponential | ln 2 / λ |
| Median at u = 0.5: Pareto | xₘ·2^(1/α) |
| Median at u = 0.5: Weibull | λ(ln 2)^(1/k) |
| Median at u = 0.5: Rayleigh | σ√(2 ln 2) |
| Median at u = 0.5: logistic | μ, exactly |
| Hyperbolic secant, scale as σ | cdf(loc + σ) = (2/π)·atan(e^(π/2)) = 0.8695181135728437 |
| Extreme-value reflection | MinExtreme(m).quantile(p) = 2m − MaxExtreme(m).quantile(1 − p) |
| Pearson's bound | kurtosis ≥ skewness² + 1, from E[(Z² − γZ − 1)²] ≥ 0 |
| 80/20 Pareto shape | log₄5 = 1.160964047443681 |
| Anderson–Darling, fully specified null | 5% critical value 2.492; 1% critical value 3.857 |
