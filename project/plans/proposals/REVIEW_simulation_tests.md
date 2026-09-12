# BusinessMath simulation test suite: validated review and remediation plan

*September 2026. Covers the 48 files under `Tests/BusinessMathTests/Simulation Tests/`, the Monte
Carlo engine, the bytecode compiler and optimizer, and the Metal GPU path.*

*An external review of this batch arrived 2026-09-12. This document is that review **after
validation**: roughly 95 of its ~100 claims were checked against the tree or recomputed. Every
verdict below says which. Reference values were computed with mpmath at 20–40 digits; failure
rates were derived analytically or measured by running the code over 200 seeds.*

## 1. Summary

**The incoming review is accurate.** Every piece of arithmetic in it checked out — twelve
significant figures on both Black-Scholes references, the Weibull quadrature, the Gaussian-copula
identity, both skewness estimators, the R-7 quantiles, the Box-Muller radius cap, and exact file
counts. Six claims were overstated and are corrected in §2.2. One was *under*stated, and it turned
out to be the most serious finding in the batch (§3.1).

The defects fall into two groups that need different treatment.

**Library defects (§3).** Five of these produce wrong numbers, not just weak tests. The antithetic
standard error is overstated by 40%. `integrate` samples on a lattice with a systematic downward
bias. The bytecode optimizer rewrites `a * 0 → 0` unconditionally, which discards infinities, NaNs
and the sign of zero, and bypasses errors the interpreter would throw. `confidenceInterval` is a
coverage interval wearing the wrong name. Nothing specifies what happens when the CPU and GPU
executors disagree.

**Test defects (§4).** The largest single class is assertions whose bounds are 15 to 280 standard
errors wide, in tests whose own comments compute the standard error and then leave the bound where
it was. The second largest is tests that cannot fail at all: a bound derived from the measurement
it bounds, an assertion that is a tautology for every `UInt64`, an `#expect` inside an unawaited
`Task`, and three suites of `#expect(Bool(true))`.

## 2. How this review was validated

### 2.1 Tally

| | count |
|---|---:|
| claims in the incoming review | ~100 |
| checked against the tree or recomputed | ~95 |
| found correct | ~88 |
| overstated, corrected in §2.2 | 6 |
| understated, escalated in §3.1 | 1 |
| errors found in *this* validation, corrected in §2.3 | 1 |

### 2.2 Corrections to the incoming review

**1. "About 25 GPU tests report green when the GPU doesn't work." There are 17, and 14 of them
cannot.** `MonteCarloGPUIntegrationTests` and `MonteCarloGPUPerformanceTests` carry
`.requiresMetalGPU` at suite level, and `MetalAvailability.canRunKernels` has `#else return false`,
so those suites skip on Linux *and* on a Mac whose shader will not compile. Their internal guards
are dead code, not false greens. Only **three sites in two files** are genuinely exposed:
`AdvancedExpressionTests` (2) and `GPUPerformanceBenchmark` (1), neither of which carries a trait.

**2. "A NaN constant means the optimizer never converges." It is bounded.**
`BytecodeOptimizer.optimize` is `while passCount < maxPasses` with `maxPasses = 10` and a
`current == previous` break. The mechanism is real — `.constant(.nan) != .constant(.nan)` defeats
the convergence check — but the cost is ten wasted passes, not a hang.

**3. "About 70 `print` calls." There are 166** across the GPU, correlation and debug files:
`MonteCarloGPUIntegrationTests` 51, `MonteCarloGPUPerformanceTests` 33, `CorrelationExpressionTests`
23, `RNGDebugTest` 22, `GPUDebugTest` 21, `MonteCarloGPUDeviceTests` 9, `GPUPerformanceBenchmark` 7.

**4. The `integrate` fix is half stale, and the live half is worse than described.** The review asks
to move off `Double.random(in: 0..<1, using:)`. That already happened in `70d29b1e`; the current
line is `distributionUniform(openUnitUniform(Double.self, using: &generator))`. The defect is the
**wrapper**, which is
`(randomSeed * 10_000_000).rounded(.down) / 10_000_000` — rounded **down**, so it is a systematic
downward bias of about 5e-8 per sample, not merely a 1e-7 lattice. For a Monte Carlo integrator a
directional bias does not average out with more samples, which makes this worse than a precision
loss.

**5. "`testMixedDistributions` still ends in `guard … else { return }`." It does not.** It uses
`try #require(MonteCarloGPUDevice(), …)` like its siblings. Stale.

**6. "ExpressionArrayTests tells stdDev's story and never tests it." There is nothing to test.**
`variance()` and `stdDev()` were **removed** from `ExpressionArray`, deliberately, because they
divided by `count`. `ExpressionArray.swift:238` says so. The public surface is sum, product, max,
min, mean, map, zipWith, dot, norm, normalize, array, forEach. The absence *is* the fix; adding a
stdDev test would mean re-adding the defective method.

### 2.3 One correction to this validation

The review says the GPU `nextUniform` rounds to exactly `1.0f` for words within **2³⁹** of 2⁶⁴, about
3 in 10⁸ per draw and roughly 3% per million-draw run. This validation first computed 2⁴⁰ and ~6%,
using the ulp *above* 1.0. That was wrong. Float32 spacing in [0.5, 1) is 2⁻²⁴, so the
round-to-nearest midpoint sits at 1 − 2⁻²⁵, and the probability is 2⁻²⁵. Confirmed empirically:
`Float(1 - 0x1p-25) == 1.0` is `true` and `Float(1 - 0x1p-24) == 1.0` is `false`. **The review was
right.**

## 3. Library defects

### 3.1 The antithetic standard error is overstated by 40% — escalated

The incoming review filed this as a test-quality item: *"the antithetic SE test could pass for the
wrong reason."* It is a library defect, and it was measured over 200 seeds:

| | plain | antithetic |
|---|---:|---:|
| realised sd(price) across seeds | 0.3010 | **0.2084** |
| reported average `standardError` | 0.2926 | 0.2921 |
| honesty = reported ÷ realised | 0.972 | **1.402** |

The antithetic machinery **works** — it delivers a genuine 31% variance reduction. The reported
standard error does not see it, because `MonteCarloEngine.price` accumulates
`sumPayoffs`/`sumPayoffsSquared` over all `effectivePaths` and divides by `n = effectivePaths`,
treating 2N negatively correlated paths as 2N independent observations. The correct estimator is the
variance of the N/2 **pair means**.

`MonteCarloPricingResult`'s own documentation promises `price ± 2 * standardError` at 95%
confidence. For antithetic runs that interval is 40% too wide. Conservatively wrong, so not
dangerous — but it hides the entire benefit of the feature.

**The guarding test cannot see it.** `antitheticReducesStandardError` asserts
`antitheticResult.standardError < plainResult.standardError`, which held for **109 of 200 seeds
(54.5%)** with a mean ratio of 0.9988. It is a coin flip that seed 42 happens to win.

### 3.2 `integrate` samples on a biased lattice

See §2.2 item 4. `distributionUniform` quantizes with `.rounded(.down)`, so every sample carries a
downward bias of about 5e-8. `singleIterationIsTheSample` currently pins this as the integrator's
contract.

### 3.3 The optimizer's `a * 0 → 0` rewrite is unsound

`BytecodeOptimizer.swift:299–306` rewrites unconditionally, discarding `a`:

```
inf * 0  = NaN   -> rewrite gives 0
NaN * 0  = NaN   -> rewrite gives 0
(-3) * 0 = -0.0  -> rewrite gives +0.0
```

All three verified. `a * 1 → a` is sound and needs no change; only `a * 0` does.

### 3.4 Constant folding must preserve interpreter errors

`BytecodeInterpreter` throws `EvaluationError.divisionByZero`
(`MonteCarloExpressionModel.swift:246`), `invalidOperation("sqrt of negative")` (:281) and
`invalidOperation("log of non-positive")` (:287). A fold of `log(0) * 0` therefore returns 0
optimized and **throws** unoptimized. The same model must not behave differently for having been
optimized.

### 3.5 `confidenceInterval(level:)` is a coverage interval

`SimulationStatisticsTests` asserts `mean ± 1.645 * stdDev`, confirming μ ± zσ. That is a coverage
interval; a confidence interval for the mean is μ ± zσ/√n. **Decision taken (5.3): rename to
`coverageInterval` and add a correctly defined `confidenceInterval`.**

### 3.6 Unseeded APIs the seeding gate cannot see

`ScenarioAnalysis` contains zero occurrences of "seed". `SensitivityAnalysis` likewise.
`CorrelatedNormals.sample()` and `SimulationInput.sample()` take no parameters.
`distributionNormal(mean:stdDev:)` and `distributionUniform(min:max:)` have *positional* seed
parameters that default to fresh draws, so a call site that omits them looks seeded and is not. The
proposed gate rule flags calls that omit `seed:`; these have no `seed:` to omit.

The seeded simulation path also rejects custom samplers, which is why eight simulations in
`MonteCarloSimulationTests` carry "Justification:" comments. A sampler taking
`(inout any RandomNumberGenerator) -> Double` removes both the rejection and the comments.

### 3.7 The CPU and GPU executors have no shared contract

Five gaps, none tested: error behaviour (CPU throws, GPU produces ±inf/NaN); opcode numbering
(assertions are `>= 0` and `<= 16`, so any renumbering passes —
`ExpressionCompilationIntegrationTests:40,153`); stack depth (`MAX_STACK = 32`, unchecked);
constant narrowing to `Float`; malformed bytecode.

## 4. Test defects

### 4.1 Tests that cannot fail

- **`LTriangularZero`** (`Simulation Tests.swift:41–43`) derives its bound from the measurement:
  `roundedCount = (Double(countUnderC) / 10).rounded() * 10; roundedLow = Int(roundedCount * 0.975)`.
  The commented-out line holds the real expected value, and `cdfAtModeMatchesTheory` already does the
  job. **Delete.**
- **`conformsToProtocol`** (`CorrelatedNormalsSeededTests:290`) asserts
  `Double(raw >> 11) * 0x1.0p-53 ∈ [0, 1)`. That holds for every `UInt64`. It also pins the 53-bit
  mapping the library replaced with 52 in `70d29b1e`.
- **`simulationInputSendableConformance`** (`SimulationInputTests:176`) puts its only `#expect`
  inside an unawaited `Task {}`. Sendable is a compile-time property; a call to a generic
  `requireSendable<T: Sendable>(_:)` states it.
- **`#expect(Bool(true))`** — 4 in this batch, including one in `ExpressionTreeTests`.
- **The "Throwing Init" suite never throws.** All three tests take the success path.

### 4.2 Tolerances not derived from standard errors

`MonteCarloSimulationTests` computes the standard error in the comment and then leaves the bound:
27.7, 15.9, 31.6, 54, 264, 284 and 94 SE. Bound each at expected ± 4 SE.

One of those comments has the wrong reference value. `MonteCarloSimulationTests:402` states that
min(Weibull(2, 1000), Weibull(1.5, 1200)) has "mean ≈ 560 and stdDev ≈ 330". By quadrature of
S₁S₂ the true values are **643.905** and **377.488**. The assertion is `mean < 1000`, which is 67
true SE wide.

Other measured widths: the standard-normal stdDev bound of 0.02 at n = 10,000 is **2.83 SE**
(SE of a sample sd is 1/√(2n) = 0.00707), failing about 0.47% of seeds; its σ = 15 twin sits at
9.4 SE. The Black-Scholes checks use 2 SE, which fails **4.55%** of seeds by construction, and
gives an 8.9% chance that a generator change turns one of the two red. Use 4 SE.

### 4.3 Correlation-insensitive assertions

`MultiVariableMonteCarloTests` sets a nonzero correlation and asserts only what correlation does not
change. `negativeCorrelation` uses ρ = −0.6 and its comment says *"(for uncorrelated normals,
E[XY] = E[X]E[Y])"* — which is exactly what correlation breaks — then asserts
`abs(mean - 5000) < 300`, about 47 SE.

`positiveCorrelation` is the model to copy: it does the algebra in the comment
(100 + 400 + 2·0.8·10·20 = 820, sd ≈ 28.6) and asserts `stdDev > 25 && < 32`, which **excludes** the
independent √500 = 22.4.

Non-normal marginals are never tested with correlation. Under a Gaussian copula at ρ = 0.8 the
uniform marginals stay uniform and their Pearson correlation is (6/π)·arcsin(0.4) = **0.785939**.

### 4.4 Tests that don't touch what they're named for

- **`MonteCarloTheoryCrossValidationTests`**: 0 references to `MonteCarloSimulation`, 0 `.run()`
  calls.
- **`MonteCarloGPUDeviceTests`**: 0 references to `runSimulation`, though its header promises
  "Swift-side GPU orchestration". Seven of its nine tests exercise Apple APIs.
- **`ExpressionCompilationIntegrationTests`**: 0 evaluate/run/interpret references, though its header
  promises "end-to-end equivalence".
- **`monteCarloSimulationConvergence`**: `stride(from: 0, to: 1_000, by: 2)` puts **500** values in
  `values1000` and 5,000 in `values10000`. It also re-inlines unguarded Box-Muller.
- **`testCompoundInterestModel`**: its own comment says "simplified to multiplication for this test".

### 4.5 GPU tests that exercise copies of production code

`MonteCarloModelEvaluatorTests` carries its own Metal evaluator ("matching Metal implementation")
and its own CPU reference, so it proves the test agrees with the test. The copy handles opcodes 0–5;
production spans 0–16. `MonteCarloDistributionTests` defines `sampleNormal`, `sampleUniform` and
`sampleTriangular` in the test. The fix is the one the RNG already got: move them into
`MetalShaderSource` and interpolate.

No test checks the *shape* of any GPU-sampled distribution. One KS test per kernel distribution
against the CPU type's `cdf`, plus a CPU-versus-GPU differential per opcode, closes it.

### 4.6 Silent skips and platform reachability

Three exposed `guard … else { print("⊘ Skipping"); return }` sites (§2.2 item 1). The other 14 are
redundant under their suite traits and should be removed as dead code.

**Decision taken (5.2): the Mac CI job must fail, not skip, when Metal is unavailable.**

### 4.7 Errors asserted by type only

`customSamplerThrows` (twice), both correlation-validation tests, `latinHypercubeRequiresASeed`, the
Sobol dimension test, `asyncCancellation` (which accepts any error where `CancellationError` is the
claim), and about 14 more including FaultInjection's four, whose test names state the specific case
they do not check.

### 4.8 Hygiene

`Simulation Tests.swift` has a `File.swift` header, an unused logger, two Darwin/Glibc imports, and
`NormalDistributionTests_SwiftTesting` / `TriangularDistributionTests_Additional` suffixes. Five
files carry "RED-phase" headers. `DistributionRetrofitTests` numbers `report1`…`report16`. 166
`print` calls. `SeededRNG2` is documented "Value-type LCG" and implements Marsaglia xorshift64. A
`private struct SeededRNG` in `MonteCarloIntegrationStressTests:21` shadows TestSupport's, whose own
doc already flags the duplication. `SamplerFeed` traps on overrun; `SequentialSampler` silently
returns 0.0.

## 5. Decisions taken

1. **Correctness over compatibility.** Anything incorrect is corrected regardless of blast radius.
   This puts the `distributionUniform` lattice and the antithetic standard error in scope even though
   both change published numbers, and callers are updated with them.
2. **The GPU suite is expected to run on Apple hardware in CI.** Metal being unavailable on the
   Mac job is a failure, not a skip — the GPU path is a useful test and a silently skipped one buys
   nothing. `.requiresMetalGPU` keeps skipping on Linux and on developer machines without a GPU; the
   Mac CI job must fail instead. The `ProcessInfo.processInfo.environment["CI"]` /
   `["GITHUB_ACTIONS"]` pattern in `ConditionTraits.swift` already distinguishes the two.
3. **`confidenceInterval` → `coverageInterval`** (μ ± zσ), plus a new correctly defined
   `confidenceInterval` (μ ± zσ/√n). Breaking; belongs in the 3.0.0 line.
4. **Skewness needs no new flag.** `skew(_:_ pop: Population = .sample)` already dispatches to
   `skewS` (G1, Excel `SKEW`, unbiased under normality) and `skewP` (g1, Excel `SKEW.P`).
   `SimulationStatistics` already uses `.sample` and will **expose** the choice, defaulting to
   `.sample`. The test simply has to assert **1.059228** rather than `> 0.5`, which passes for both
   estimators.
5. **`.serialized` stays on all 14 suites.** The incoming review assumed it was an `srand48`
   leftover masking data races. It is not: it is there because Linux CI runs on overloaded cores. The
   advisory changes from "name the shared state it protects" to "name why", and the comment should
   say CI core contention.
6. **`CorrelatedNormalsTests` is deleted** after its ρ₁₃ check moves to the seeded file. 13 tests, 0
   seed references. Nothing unseeded survives.
7. **No API change for `normalize`/`norm`/`valueAtRisk`.** Both are documentation: `norm()` is
   Euclidean while `normalize()` divides by the sum, so `norm(normalize(x)) ≠ 1`; and
   `FinancialFunctions.valueAtRisk` returns the μ − zσ *level*, not a positive loss. Two doc notes,
   zero compile errors.

## 6. Order of work

**Phase 1 — library correctness, non-breaking.** Antithetic SE from pair means (§3.1). `integrate`
drops the `distributionUniform` wrapper (§3.2). `a * 0` restricted to known-finite operands (§3.3).
Constant folding preserves interpreter errors (§3.4). CPU/GPU contract: pinned opcode table,
stack-depth rejection, `Float` constant narrowing, malformed-bytecode validation, error parity
(§3.7).

**Phase 2 — GPU test integrity.** Three exposed guards to traits; 14 dead guards removed. CI-aware
trait so the Mac job fails rather than skips (decision 5.2). KS per kernel distribution. CPU-versus-GPU
differential per opcode. Samplers and evaluator into `MetalShaderSource`. The two disabled tests to
`withKnownIssue` + `.bug`.

**Phase 3 — breaking API, with the 3.0.0 line.** `coverageInterval` rename plus real
`confidenceInterval`. `seed:` on `ScenarioAnalysis` and `SensitivityAnalysis`. Custom sampler taking
the generator. `SimulationStatistics` exposes the skewness choice.

**Phase 4 — assertion strength.** The SE-derived bounds of §4.2. The Weibull reference. The
correlation-sensitive assertions of §4.3. Delete `LTriangularZero`. Existential tests via
`identical`. Exact answers asserted exactly: R-7 percentiles (p10 = 10.9 not "9 to 11", unsorted
median 50.5, duplicates median 3), √(55/6), skewness 1.059228, NPV 90.90909090909091, stack depth 3.
Errors by case.

**Phase 5 — test infrastructure.** One scripted generator and one `CountingRNG` in TestSupport.
`Issue.record` on feed overrun. Remove prints. One reproducibility spelling. Loop volume. Hygiene.

**Phase 6 — quality gate.** §7.

## 7. Quality-gate additions

1. **Platform-aware reachability.** An `#expect` inside an `IfConfigDeclSyntax` branch for
   `canImport(Metal)` is unreachable on Linux; require a matching condition trait.
2. **Silent skips.** Flag `guard … else { return }` at a test's top level, with or without a `print`.
3. **Self-referential bounds.** Flag an expectation whose bound is computed from the value under
   test.
4. **Transitive unseeded set.** Compute, from `Sources/`, the functions that reach unseeded
   randomness, and flag test calls into that set. This is what §3.6 defeats today.
5. **`#expect` inside an unawaited `Task {}`.**
6. **Test helpers returning a literal default on exhaustion**, like `guard … else { return 0.0 }`.
7. **Forbid `print` in test targets.**
8. **`.disabled` must carry `.bug(…)`**, or prefer `withKnownIssue`.
9. **Clock or `Date()` reads that no assertion consumes.**
10. **Test-local shader reimplementations** — a `kernel void` string literal that does not
    interpolate `MetalShaderSource`.
11. **Dead fixture fields** — a labelled field in a test-case array the body never reads.
12. **Advisory:** `.serialized` should carry a comment naming why (decision 5.5).

## 8. Open questions

1. Should `MonteCarloPricingResult` keep reporting a single `standardError`, or expose the pair-mean
   estimator alongside it so the variance reduction is visible to callers?
2. The KS tests in §4.5 need a per-family tolerance. Adopt the α = 1e-5 two-sample critical value of
   0.0156 at n = m = 50,000 the review proposes, or derive per distribution?

## Appendix A. Verified reference values

| quantity | value | method |
|---|---|---|
| Black-Scholes call, S=100 K=105 r=.05 σ=.20 T=1 | 8.021352235143171 | mpmath, 25 dps |
| Black-Scholes put, S=100 K=95 r=.05 σ=.20 T=1 | 3.713260273447414 | mpmath, 25 dps |
| mean of min(Weibull(2,1000), Weibull(1.5,1200)) | 643.905 | ∫S₁S₂ |
| sd of the same | 377.488 | 2∫tS₁S₂ − m² |
| √(55/6), the sample sd of 1…10 | 3.0276503540974917 | exact; variance is exactly 55/6 |
| skewness of [1,2,3,4,5,10,15,20], G1 | 1.059228 | scipy, bias=False — what the API promises |
| the same, g1 | 0.849272 | scipy, bias=True |
| R-7 p10 of 1…100 | 10.9 | R-6 gives 10.1; the test window [9,11] admits both |
| R-7 median, unsorted fixture | 50.5 | exact |
| R-7 median, duplicates fixture | 3.0 | exact |
| uniform Pearson correlation, Gaussian copula ρ=0.8 | 0.785939 | (6/π)·arcsin(ρ/2) |
| Box-Muller radius cap, 32-bit uniforms | 6.66044σ | √(−2 ln 2⁻³²) |
| NPV, −1000 + 1200/1.1 | 90.90909090909091 | exact |

## Appendix B. Measured failure rates

| assertion | width | failure rate |
|---|---|---|
| Black-Scholes at 2 SE | 2 SE | 4.55%; 8.9% that one of the two turns red |
| standard-normal stdDev, 0.02 at n=10,000 | 2.83 SE | 0.47% |
| legacy 3σ bounds | 3 SE | 0.27% |
| progressive-tax 2% two-sample bound | ≈2.2 SE | ≈2.8% analytic (review measured 2.5%) |
| GPU `nextUniform` → exactly 1.0f | 2⁻²⁵ | 3e-8 per draw; 2.94% per 10⁶ draws |
| `antitheticReducesStandardError` | — | **passes 54.5% of 200 seeds**; mean ratio 0.9988 |
