# Design Proposal — the distribution contract, and where a sampler gets its uniforms

**Status:** proposal, 2026-09-04. **All open questions resolved; ready for RED.**
**Phase:** 0 (Design) for `PROPOSAL_excel_function_coverage.md`.
**Blocks:** every one of the 49 rows in `excel-coverage/businessmath_work.tsv` that is a distribution
or a sampling method — 42 of them.

---

## 1. Objective

Fix two things before the 33 new distributions are written, because both get much more expensive
afterwards:

1. **There is no contract to write them against.** `DistributionRandom` requires `next()` and
   nothing else. The coverage proposal's verification plan — CDF to 1e-10, quantile round-trip, KS
   against the reference CDF — cannot be expressed against that protocol, so each of the 33 would
   be verified ad hoc.
2. **There is nowhere to put Latin hypercube, Sobol or Halton.** `MonteCarloSimulation` samples each
   input independently through a per-input closure. A quasi-random point set is joint across inputs
   by construction, and no seam exists where one could be injected.

Both resolve to the same missing idea: **a distribution should be able to say what value sits at a
given uniform**. That is the CDF's inverse, it is what the tests need, and it is what a point set
needs to hand a distribution a coordinate.

**Master Plan reference:** the coverage work list; `project/plans/proposals/PROPOSAL_excel_function_coverage.md` §2, §3.5.

---

## 2. Motivation

### 2.1 What a new distribution looks like today

`distributionLogistic.swift:41` is the pattern the sixteen existing distributions follow:

```swift
let p: T = seed.map { distributionUniform(min: T(0), max: T(1), $0) } ?? distributionUniform()
let magicNumber = T.sqrt(3) / T.pi
return mean + magicNumber * stdDev * T.log(p / (1 - p))
```

That expression *is* the logistic quantile evaluated at `p`. The quantile is present, inlined, and
unreachable. Every closed-form row on the work list would repeat this: write the quantile, hide it
inside a sampler, then be unable to test it directly.

Quantile coverage in the package today is three functions under three spellings —
`inverseNormalCDF`, `fQuantile`, `tQuantile`. Thirty-three more written without a frozen naming
rule produce thirty-three more spellings, and the coverage proposal explicitly contemplates
parallel work across the list.

### 2.2 What blocks the sampling methods

`MonteCarloSimulation.swift:500`:

```swift
let sampledValues = samplers.map { $0(&generator) }
```

Each `sampler` is `(inout Xoshiro256StarStar) -> Double`, erased at `SimulationInput.swift:95`. It
draws whatever randomness it wants from a shared stream. Latin hypercube needs the opposite: for
iteration *i*, hand input *j* the *j*-th coordinate of the *i*-th point of a stratified n×d design.
There is no way to say that through a closure that takes a generator.

**Workaround available today:** none. A caller wanting LHS must abandon `MonteCarloSimulation` and
write their own loop, losing seeding, correlation, GPU dispatch, and `SimulationResults`.

### 2.3 The constraint that makes the seam mandatory rather than convenient

A point set supplies **exactly one coordinate per input per iteration**. Two existing samplers
cannot honour that:

| Distribution | Method | Uniforms per draw |
|---|---|---|
| `DistributionNormal` | Box–Muller (`distributionNormal.swift:34`) | 2 |
| `DistributionGamma` | Marsaglia–Tsang rejection (`distributionGamma.swift:141`) | unbounded |

So quasi-random sampling is only available to inputs that are one-uniform inverse transforms. That
is a real restriction, it must be enforced rather than papered over, and `quantile(_:)` is precisely
the predicate that decides it.

---

## 3. Proposed architecture

### 3.1 New files

```
Sources/BusinessMath/Simulation/
	ContinuousDistribution.swift          protocol + open-unit-interval helper
	DiscreteDistribution.swift            protocol for the counting distributions
	AliasTable.swift                      Vose's method; the O(1) pseudo-random path (§3.5b)
	Sampling/
		QuasiRandomPointSet.swift         protocol over LHS / Sobol / Halton
		SamplingMethod.swift              the enum MonteCarloSimulation reads
		LatinHypercubeSampler.swift
		SobolSequence.swift
		SobolDirectionNumbers.swift       generated; Joe & Kuo (2008)
		OwenScramble.swift                hash-based nested uniform scrambling (§3.5a)
		HaltonSequence.swift
		ImportanceSampling.swift          deferred — see §3.6

Sources/BusinessMath/Statistics/SpecialFunctions/          new home, see §15.6
	regularizedIncompleteBeta.swift       MOVED from Beta Distribution/
	regularizedLowerIncompleteGamma.swift PROMOTED from private in chiSquaredCDF.swift
	inverseRegularizedIncompleteBeta.swift    new — Newton with bisection fallback
	inverseRegularizedLowerIncompleteGamma.swift  new — same

Scripts/reference-fixtures/               the SciPy harness, §10.2a
	generate.py  spec.py  requirements.txt
Tests/BusinessMathTests/Fixtures/         generated, committed, never hand-edited
```

The two special-function inverses are the highest-leverage items on the page: between them they
supply quantiles for Gamma, Erlang, Chi-squared, Beta, F, Pearson V, Pearson VI and the Johnson
family — eight or more rows of the coverage work list, written once.

### 3.2 Modified files

| File | Change | Breaking? |
|---|---|---|
| `SimulationInput.swift` | store an optional `(Double) -> Double` quantile alongside the existing samplers | No — new internal property |
| `MonteCarloSimulation.swift` | `samplingMethod` property; a QMC branch in `run()` and `run() async` | No — property defaults to today's behaviour |
| `SimulationError.swift` | `quasiRandomUnsupported(inputName:details:)` | No — new case, enum is not frozen |
| `SimulationResults.swift` | optional `weights` (deferred phase only) | No — defaulted property |
| the fifteen `distribution*.swift` | additive conformance extensions; twelve also gain a CDF and/or quantile | **No — see §3.4 and §3.4a** |
| `chiSquaredCDF.swift` | `regularizedLowerIncompleteGamma` promoted out of `private` and moved | No — the file keeps its public function |
| `Package.swift` | `resources: [.copy("Fixtures")]` on the test target | No — test target only |

### 3.3 The protocols

```swift
/// A distribution whose law is expressible as a CDF and its inverse.
public protocol ContinuousDistribution<T>: SeedableDistribution {

	/// P(X ≤ x).
	func cdf(_ x: T) -> T

	/// The value at which the CDF equals `p`; the inverse of ``cdf(_:)``.
	///
	/// - Parameter p: A probability in the *open* interval (0, 1).
	func quantile(_ p: T) -> T
}

extension ContinuousDistribution {
	/// Inverse-transform sampling: one uniform in, one draw out.
	///
	/// A conforming type that samples by another route — rejection, Box–Muller —
	/// overrides this, and by doing so declares itself ineligible for quasi-random
	/// sampling. See ``SamplingMethod``.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> T {
		quantile(T(Double.openUnitRandom(using: &generator)))
	}
}
```

```swift
/// A distribution over a countable support.
public protocol DiscreteDistribution<T>: SeedableDistribution {
	func pmf(_ k: Int) -> T
	func cdf(_ k: Int) -> T

	/// The smallest `k` for which `cdf(k) >= p`.
	func quantile(_ p: T) -> Int
}
```

`DiscreteDistribution.next()` returns `T`, not `Int`, because `DistributionRandom` requires it and
the whole simulation pipeline is `Double`-typed. The integer is returned exactly representable.

**Endpoint safety.** `quantile(0)` is `-infinity` for most of these distributions and `quantile(1)`
is `+infinity`. The existing code draws from `0...1` *closed* (`distributionLogistic.swift:95`),
which is a latent infinity for any quantile-based sampler. This proposal adds:

```swift
extension Double {
	/// A uniform draw from the open interval (0, 1) — never 0, never 1.
	static func openUnitRandom<G: RandomNumberGenerator>(using generator: inout G) -> Double
}
```

and requires every inverse-transform sampler to use it.

### 3.4 How the existing sixteen are retrofitted — and the rule that keeps them safe

Conformance is **declaration-only and additive**. Each existing distribution gains an extension
naming the free functions that already compute its CDF and quantile:

```swift
extension DistributionNormal: ContinuousDistribution {
	public func cdf(_ x: Double) -> Double { normalCDF(x: x, mean: mean, stdDev: stdDev) }
	public func quantile(_ p: Double) -> Double { inverseNormalCDF(p: p, mean: mean, stdDev: stdDev) }
	// next(using:) is NOT inherited — Box–Muller is kept, deliberately. See below.
}
```

The protocol also does quiet housekeeping the free functions never got. Their first arguments are
labelled four different ways — `normalCDF(x:mean:stdDev:)`, `logNormalCDF(_:mean:stdDev:)`,
`exponentialCDF(_:λ:)`, `uniformCDF(x:)` — so there is no way to call "the CDF" generically today.
`cdf(_:)` gives the sixteen a single spelling without renaming any of them.

> **Rule: a retrofit never adopts the default `next(using:)`.**
>
> `DistributionNormal` samples by Box–Muller and `DistributionGamma` by Marsaglia–Tsang rejection.
> If either inherited the inverse-transform default, it would draw a *different stream from the same
> seed* — the same distribution, different numbers — and every seeded-determinism test in the suite
> would fail. Correctly. Swift's dispatch already prefers the concrete method, but this is stated as
> a rule because it is invisible at the call site and would be reintroduced by anyone tidying up a
> "redundant" method.

**This rule says nothing about quasi-random eligibility, and an earlier draft wrongly conflated the
two.** The QMC path calls `quantile(_:)` directly and never touches `next(using:)` at all, so the
admission criterion is simply:

> **A distribution is eligible for quasi-random sampling if and only if it conforms to
> `ContinuousDistribution` or `DiscreteDistribution`** — that is, if it can state a quantile.
> How it samples on the pseudo-random path is irrelevant.

That is a better criterion than "did it override `next(using:)`" in three ways: it is a compile-time
property rather than a convention, it cannot be broken by an unrelated refactor, and it is *more
permissive in the right place*. `DistributionNormal` has `inverseNormalCDF` and is therefore
QMC-eligible — it uses inverse-CDF under Sobol and Box–Muller under pseudo-random, which is correct
in both cases and changes no existing stream, because no seeded QMC run exists today to be
compatible with.

A distribution with no CDF or quantile is **not** retrofitted in this phase and is not QMC-eligible.
Partial conformance is fine: `ContinuousDistribution` is a capability, not a taxonomy.

### 3.4a The retrofit audit — measured, 2026-09-04

Fifteen concrete distribution types conform to `DistributionRandom` and `SeedableDistribution`
today. **Only three can conform to `ContinuousDistribution` with no new mathematics.** The earlier
claim that the retrofit is purely declarative was wrong, and this table is why the retrofit is now
in scope rather than opportunistic.

| Type | CDF today | Quantile today | Pseudo-random sampler | Work to conform |
|---|---|---|---|---|
| `DistributionNormal` | `normalCDF` | `inverseNormalCDF` | Box–Muller (2 uniforms) | **none** |
| `DistributionT` | `tCDF` | `tQuantile` | normal / χ² | **none** |
| `DistributionF` | `fCDF` | `fQuantile` | χ² ratio | **none** |
| `DistributionUniform` | `uniformCDF` | — | inverse (1) | trivial quantile |
| `DistributionExponential` | `exponentialCDF` | — | inverse (1) | trivial quantile |
| `DistributionLogNormal` | `logNormalCDF` | — | exp(Box–Muller) (2) | `exp(inverseNormalCDF(p))` |
| `DistributionTriangular` | — | — | inverse, piecewise (1) | both, closed form — **quantile is already inlined in the sampler** |
| `DistributionWeibull` | — | — | inverse (1) | both, closed form — same |
| `DistributionPareto` | — | — | inverse (1) | both, closed form — same |
| `DistributionRayleigh` | — | — | inverse (1) | both, closed form — same |
| `DistributionLogistic` | — | — | inverse (1) | both, closed form — same |
| `DistributionGeometric` | — | — | inverse (1), documented O(1) | both, closed form — same |
| `DistributionBeta` | `betaCDF` | — | two-gamma rejection | inverse regularized incomplete beta (root-found) |
| `DistributionChiSquared` | `chiSquaredCDF` | — | sum of *k* normals (2*k*) | inverse regularized lower incomplete gamma (root-found) |
| `DistributionGamma` | — | — | Marsaglia–Tsang rejection | CDF **already exists but is private** — see below; quantile root-found |

**Three findings that shrink this considerably.**

1. **Six of the seven missing CDFs belong to distributions whose sampler is already the inverse
   transform.** `distributionLogistic.swift:41` computes the logistic quantile inline; Triangular,
   Weibull, Pareto, Rayleigh and Geometric do the same. For each, the quantile is an extraction and
   the CDF is its algebraic inverse. This is bookkeeping, not derivation.

2. **`regularizedLowerIncompleteGamma` already exists — as a `private` function inside
   `chiSquaredCDF.swift:56`,** complete with its series and continued-fraction branches. Promoting
   it to `public` yields `gammaCDF` and `erlangCDF` immediately, and makes the `PsiErlang` row of
   the work list a delegation rather than an implementation. This is precisely the
   "computed and unreachable" pattern the coverage proposal names as the shape of most of this work
   — found here inside our own special-function layer.

3. **`regularizedIncompleteBeta` is already public** (`Beta Distribution/regularizedIncompleteBeta.swift:19`,
   throwing), so Beta's CDF is done and Pearson VI has its forward function too.

**What genuinely remains** is two special-function *inverses*: inverse regularized lower incomplete
gamma and inverse regularized incomplete beta. Both are Newton-with-bisection-fallback on forward
functions that now exist, both are ~60 lines, and both are shared infrastructure — between them they
supply the quantiles for Gamma, Erlang, Chi-squared, Beta, F, Pearson V, Pearson VI and the Johnson
family. They are the single highest-leverage items in the whole coverage effort and belong in
Phase 0, not scattered across the distribution rows.

They are also the reason open question §15.1 was raised and answered as it was: a root-found quantile
may not reach 1e-10, and per-distribution tolerance relaxation is the accepted response.

### 3.5 The sampling seam

```swift
/// A deterministic low-discrepancy or stratified point set over the unit hypercube.
public protocol QuasiRandomPointSet: Sendable {
	var dimension: Int { get }

	/// `count` points, each `dimension` coordinates in the open interval (0, 1).
	func points(count: Int) -> [[Double]]
}

public enum SamplingMethod: Sendable, Hashable {
	/// Independent pseudo-random draws. Today's behaviour, and the default.
	case pseudoRandom
	case latinHypercube
	case sobol(scrambled: Bool)
	case halton(scrambled: Bool)
}
```

On the simulation:

```swift
extension MonteCarloSimulation {
	/// How sample points are chosen. Defaults to ``SamplingMethod/pseudoRandom``.
	///
	/// Any method other than `.pseudoRandom` requires every input to be a one-uniform
	/// inverse transform; `run()` throws ``SimulationError/quasiRandomUnsupported(inputName:details:)``
	/// otherwise rather than silently reverting.
	public var samplingMethod: SamplingMethod { get set }
}
```

The QMC branch replaces `MonteCarloSimulation.swift:500` with:

```swift
let plan = try resolveQuantiles()                 // throws on the first ineligible input
let grid = pointSet.points(count: iterations)     // n × d, generated once
for (i, point) in grid.enumerated() {
	let sampledValues = zip(plan, point).map { $0($1) }
	outcomes.append(try validatedOutcome(from: sampledValues, iteration: i))
}
```

**Correlation composes for free, and this is the design's luckiest property.** `runCorrelated`
already uses Iman–Conover: generate independent marginals, sort them, reorder by correlated ranks.
Rank reordering permutes a marginal sample set without changing which values are in it — so an LHS
marginal stays stratified through the reordering. LHS + Iman–Conover is the standard combination
(it is what @RISK and Crystal Ball do), and it needs no new code beyond sourcing step 1's samples
from the point set.

**Sobol's direction numbers.** Joe & Kuo (2008), the `new-joe-kuo-6.21201` table, truncated to the
first **256 dimensions** and emitted as a generated `[UInt32]` in `SobolDirectionNumbers.swift`.
`SobolSequence.maxDimension` is public and `init(dimension:)` throws beyond it. The choice is stated
in the type's DocC, because a Sobol sequence whose direction numbers are unstated cannot be
reproduced against SciPy or anything else, which defeats the purpose of using one.

### 3.5a Scrambling is Owen's, and it is nearly free

`SamplingMethod` already carries `scrambled: Bool`. The question is only *which* scramble implements
it, and the answer costs essentially nothing extra: **hash-based Owen scrambling** (Burley 2020,
*Practical Hash-Based Owen Scrambling*), which is nested uniform scrambling computed in constant
time per coordinate:

```swift
/// Nested uniform (Owen) scrambling of a base-2 radical-inverse coordinate.
internal func owenScramble(_ x: UInt32, seed: UInt32) -> UInt32 {
	var v = x.reversedBits
	v ^= v &* 0x3d20_adea
	v = v &+ seed
	v = v &* ((seed >> 16) | 1)
	v ^= v &* 0x0552_6c56
	v ^= v &* 0x53a2_2864
	return v.reversedBits
}
```

Roughly 25 lines with its bit-reversal helper. Against a digital shift or Matoušek linear scramble it
is the same integration cost and strictly better equidistribution, so there is no version of this
where we should pick the weaker one.

**Randomised QMC — the estimator — is a separate, larger thing and is deferred.** Owen scrambling
makes a *single* scrambled Sobol run unbiased. Getting an *error bar* out of it means running `R`
independent scrambles (typically 10–30), taking each replicate's mean, and reporting the standard
error across replicates. That changes the shape of a run: `SimulationResults` would need to carry
replicate structure, and every statistic in `SimulationStatistics`, `Percentiles` and `RiskMetrics`
would need a replicate-aware form. That is the same surface area as importance sampling in §3.6, and
it lands with it.

So: **scrambling now, replicate-based error estimation later.** The split is clean because the
scramble is what makes the later work possible, and nothing about the deferred half changes the API
added here.

### 3.5b Discrete sampling: O(1) and O(log n) are both required, and not interchangeably

`PsiDiscrete` and `PsiGeneral` sample from an explicit pmf, and the obvious optimisation is Vose's
alias method — O(n) setup, O(1) per draw, about 50 lines, no external reference needed.

**It cannot be the only implementation, because the alias method is not monotone in `u`.** It maps
the unit interval onto the support through a permuted bin table, so two nearby uniforms can land on
distant outcomes. That is harmless for pseudo-random draws and fatal for quasi-random ones: the
entire benefit of a stratified or low-discrepancy uniform is that a *monotone* transform carries the
stratification through to the sample. Sample a stratified uniform through an alias table and you get
the right distribution with none of the variance reduction — you pay for Sobol and receive
pseudo-random convergence, silently.

The resolution is to implement both and select by path, which the architecture already distinguishes:

| Path | Method | Cost | Why |
|---|---|---|---|
| `.pseudoRandom` — `next(using:)` | Vose alias table | **O(1)** | the default and the common case |
| QMC — `quantile(_:)` | binary search on the cumulative array | O(log n) | monotone, so stratification survives |

The alias table is built once in `init` and stored, so the O(n) setup is paid per distribution, not
per draw. The O(log n) branch is a binary search over a precomputed cumulative array — for a
1,000-outcome pmf that is ten comparisons, which is not the cost worth optimising away at the price
of correctness.

This answers "O(1) generally" honestly: **O(1) on every pseudo-random draw, which is the default
path**, and O(log n) only where the mathematics requires monotonicity.

### 3.6 Importance sampling is a different animal, and is sequenced last

LHS, Sobol and Halton change *where the points are*. Importance sampling changes *the estimator*:
draws come from a proposal distribution and each carries a likelihood-ratio weight, so
`SimulationResults` needs weighted mean, weighted percentiles and weighted VaR/CVaR — touching
`SimulationStatistics`, `Percentiles` and `RiskMetrics`.

It is therefore **not** a `SamplingMethod` case. It is a separate entry point landing after the
other three, with `SimulationResults.weights: [Double]?` defaulted to `nil` so unweighted runs are
unaffected.

---

## 4. API surface

```swift
// MARK: Contract
public protocol ContinuousDistribution<T>: SeedableDistribution {
	func cdf(_ x: T) -> T
	func quantile(_ p: T) -> T
}

public protocol DiscreteDistribution<T>: SeedableDistribution {
	func pmf(_ k: Int) -> T
	func cdf(_ k: Int) -> T
	func quantile(_ p: T) -> Int
}

// MARK: Point sets — usable directly, not only through MonteCarloSimulation
public struct LatinHypercubeSampler: QuasiRandomPointSet {
	public init(dimension: Int, seed: UInt64?)
	public let dimension: Int
	public func points(count: Int) -> [[Double]]
}

public struct SobolSequence: QuasiRandomPointSet {
	public static let maxDimension: Int          // 256, per §3.5
	public init(dimension: Int, scrambled: Bool, seed: UInt64?) throws
	public let dimension: Int
	public func points(count: Int) -> [[Double]]
}

public struct HaltonSequence: QuasiRandomPointSet {
	public init(dimension: Int, scrambled: Bool, seed: UInt64?) throws
	public let dimension: Int
	public func points(count: Int) -> [[Double]]
}

// MARK: Integration
public enum SamplingMethod: Sendable, Hashable { … }
extension MonteCarloSimulation { public var samplingMethod: SamplingMethod { get set } }

// MARK: Error
extension SimulationError {
	case quasiRandomUnsupported(inputName: String, details: String)
}
```

The point sets are public and independently useful — a caller wanting a Sobol grid for a
quadrature or a design of experiments should not have to construct a `MonteCarloSimulation`.

---

## 5. MCP schema

**Tool description:** Run a Monte Carlo simulation, choosing how sample points are placed.

```json
{
  "iterations": 10000,
  "seed": 42,
  "samplingMethod": {"type": "latinHypercube"},
  "inputs": [
    {"name": "price", "distribution": {"type": "kumaraswamy",
      "parameters": {"shape1": 2.0, "shape2": 3.0, "min": 0.0, "max": 1.0}}}
  ]
}
```

**Parameter types**

- `iterations` (integer) — > 0.
- `seed` (integer, optional) — required for reproducibility; required for `latinHypercube`.
- `samplingMethod.type` (string) — exhaustively one of `"pseudoRandom"`, `"latinHypercube"`,
  `"sobol"`, `"halton"`. Default `"pseudoRandom"`.
- `samplingMethod.scrambled` (boolean, optional) — `sobol` and `halton` only. Default `false`.
  Unscrambled Halton correlates badly above roughly 10 dimensions; the tool description says so.
- `inputs[].distribution.type` (string) — the distribution's name, lowercased.
- `inputs[].distribution.parameters` (object) — keys exactly as the `SIGNATURE` column of
  `businessmath_work.tsv`, which is Frontline's order, not SciPy's.

**Error surface:** a request naming a non-`pseudoRandom` method with an input that has no quantile
returns `quasiRandomUnsupported` with the offending input's name. It never silently downgrades.

---

## 6. Constraints and compliance

| Rule | How this complies |
|---|---|
| **Concurrency** | All point sets are `Sendable` immutable value types. `points(count:)` is non-mutating and pure given the seed. |
| **Determinism** | LHS takes a seed (its stratum permutation is random). Sobol and Halton are deterministic unless `scrambled`, which takes the seed. |
| **Generics** | Protocols are generic over `T: Real & BinaryFloatingPoint`, inherited from `DistributionRandom`. Point sets are `Double`, matching `SimulationInput`. |
| **Division safety** | `quantile` implementations guard `p <= 0` and `p >= 1` before any division or log. |
| **Fail-silent** | Explicitly upheld: the QMC admission check throws rather than reverting to pseudo-random, which would return plausible numbers from the wrong sampling scheme. |
| **No force unwraps** | `zip(plan, point)` replaces indexed access; `init(dimension:)` throws rather than trapping. |
| **Generic expression complexity** | Quantile formulas are decomposed to ≤ 3 operators per expression with explicit `: T` bindings. `PsiHypSecant`'s `loc + scale*(2/pi)*ln(tan(pi*u/2))` is 5 operators as written and **must** be split — see §10's fixture. |
| **DocC** | Every public symbol documented; `SobolSequence` documents its direction-number source in prose, not only in a comment. |

---

## 7. Source and API compatibility

**Breaking changes: none.**

- `DistributionRandom` and `SeedableDistribution` are unchanged, character for character.
- `ContinuousDistribution` and `DiscreteDistribution` are new protocols. Existing conformances are
  added by extension; no existing type loses a capability.
- No existing sampler's numeric behaviour changes — §3.4's rule is what guarantees it, and §10 adds
  a regression test that pins the existing seeded streams so a future refactor cannot quietly break
  the guarantee.
- `samplingMethod` defaults to `.pseudoRandom`, so every existing simulation behaves identically.
- `SimulationError` gains a case. Callers with exhaustive switches over it will need a new arm —
  the only source-compatibility cost in the proposal, and it is a compile error rather than a
  behaviour change.

**Target version:** 2.10.0. Additive.

**Incremental adoption:** yes, in both directions. New distributions can conform to
`ContinuousDistribution` before any retrofit happens; existing ones can be retrofitted one at a time
without touching the sampling work.

---

## 8. Backend abstraction

**Point-set generation is CPU-only.** Generating n×d uniforms is bounded by memory bandwidth, not
arithmetic, and n is at most the iteration count.

**Quasi-random simulation runs are CPU-only in this phase**, mirroring the existing constraint that
`runCorrelated` is CPU-only. The GPU kernels sample from parameterised distributions on-device and
have no way to consume a host-generated point set. A run with `samplingMethod != .pseudoRandom`
skips GPU dispatch and records the reason in `SimulationResults.executionNotes`, the same mechanism
already used for GPU fallback — so the user is told, not left to infer.

**Linux:** unaffected. Nothing here imports Metal or Accelerate.

---

## 9. Dependencies

**Internal:** `SeedableDistribution`, `Xoshiro256StarStar` (`DeterministicRNG.swift`),
`SimulationInput`, `MonteCarloSimulation`, and the existing CDF free functions
(`normalCDF`, `inverseNormalCDF`, `logNormalCDF`, `exponentialCDF`, `betaCDF`, `chiSquaredCDF`,
`fCDF`, `tCDF`, `uniformCDF`, `poissonCDF`).

**External (library):** none. swift-numerics only.

**External (development tooling, never at build or CI time):** Python 3.14.7, SciPy 1.17.1,
NumPy 2.5.2, pinned in `Scripts/reference-fixtures/requirements.txt`. Used once to generate
committed JSON fixtures; the Swift test target reads JSON and has no Python dependency. See §10.2a.

**Data:** the Joe & Kuo direction-number table, vendored as generated Swift source rather than an
SPM resource, so the package gains no resource bundle.

---

## 10. Test strategy

### 10.1 The shared template — the point of the whole proposal

One generic harness, parameterised over any `ContinuousDistribution`, applied to all 33 new
distributions and to every retrofit:

| Category | Assertion |
|---|---|
| **CDF fixtures** | `cdf(x)` matches the reference at ≥ 6 quantiles including both tails, to 1e-10 |
| **Round trip** | `quantile(cdf(x)) ≈ x` to 1e-9 across the support |
| **Monotonicity** | `cdf` non-decreasing; `quantile` non-decreasing on (0,1) |
| **Endpoints** | `quantile(p)` for `p` at 1e-15 and 1-1e-15 is finite or a documented infinity — never NaN |
| **Distributional** | Kolmogorov–Smirnov statistic of 100,000 fixed-seed draws against `cdf`, below the 1% critical value. **The statistic is asserted, never an individual draw.** |
| **Determinism** | Same seed → identical array, twice |

### 10.2 Reference truth

| Source | Applies to | Recording rule |
|---|---|---|
| `scipy.stats` | 24 rows | Fixtures **generated by a committed script**, never typed by hand. SciPy version recorded in the test file — `reciprocal`→`loguniform` is exactly the rename that silently invalidates a stale fixture. |
| Closed form | 7 rows | The formula is the reference; test the round trip and the analytically exact points below. |
| `scipy.stats.qmc` | LHS, Halton, scrambled Sobol | Same generated-fixture rule. |
| Joe & Kuo (2008) | unscrambled Sobol | Cross-check against `scipy.stats.qmc.Sobol(scramble=False)`, which uses the same table. |
| Frontline Reference Guide | Myerson, MomentFit | The guide's worked examples are the only authority. |

### 10.2a The SciPy cross-check harness — built once, in Phase 0

Twenty-four of the 33 distributions name `scipy.stats` as their authority, plus three of the four
sampling methods. Generating those fixtures ad hoc, distribution by distribution, is how a
parameterisation error gets converted into a passing test. The harness is built once, up front.

**Available locally:** SciPy 1.17.1, NumPy 2.5.2, Python 3.14.7 — verified 2026-09-04.

```
Scripts/reference-fixtures/
	generate.py            one entry point, one spec table, deterministic output
	spec.py                per-distribution: scipy ctor, parameter conversion, eval points
	requirements.txt       scipy==1.17.1, numpy==2.5.2 — pinned, not floated
Tests/BusinessMathTests/Fixtures/
	<distribution>.json    generated; committed; never hand-edited
	MANIFEST.json          scipy/numpy versions, generation date, sha256 per fixture
```

Each fixture carries the CDF at a fixed set of quantiles including both tails, the quantile at a
fixed set of probabilities, and the parameter values used — in **Frontline's** parameterisation
alongside SciPy's, with the conversion recorded explicitly:

```json
{
  "name": "PsiInvNormal", "scipy": "invgauss",
  "frontline_parameters": {"mu": 2.0, "lambda": 3.0},
  "scipy_parameters": {"mu": 0.6666666666666666, "scale": 3.0},
  "conversion": "scipy_mu = frontline_mu / frontline_lambda; scale = lambda",
  "cdf": [{"x": 0.5, "p": 0.0416...}, …],
  "ppf": [{"p": 1e-10, "x": …}, …]
}
```

**Four rules, each answering a specific failure mode:**

1. **Fixtures are committed, and CI never runs Python.** The test target reads JSON. A Swift test
   suite that needs a working SciPy to run is a test suite that goes red for reasons unrelated to
   the library.
2. **`MANIFEST.json` pins the SciPy version.** The coverage proposal's own example —
   `reciprocal` becoming `loguniform` — is a rename that silently invalidates a stale fixture. A
   version mismatch should be discoverable by reading a file, not by debugging a tolerance.
3. **The conversion is data, not code.** `PsiInvNormal` and `PsiLogLogistic` need explicit
   parameterisation changes. Writing the conversion into `spec.py` *and* into the Swift
   implementation risks converting wrongly in the same direction twice, which produces a green test
   and a wrong library. Recording it in the fixture makes it reviewable in the diff.
4. **Every fixture with an independent authority gets a spot-check against it.** Where Frontline's
   guide or a textbook states a value, one assertion in the Swift test uses *that* number rather
   than the generated one. This is the only defence against a systematically wrong `spec.py`.

**Package.swift** gains `resources: [.copy("Fixtures")]` on the test target — it has no `resources:`
clause today, so this establishes the convention.

The harness also generates the `scipy.stats.qmc` fixtures for Latin hypercube, Halton, and
unscrambled Sobol, which is what makes §15.4's off-by-one detectable rather than theoretical.

### 10.3 Validation trace — analytically exact, no oracle needed

These are computed from the definitions and become literal assertions. They are here because a
fixture generated by a script proves the script ran; a value derived by hand proves the formula.

| Case | Input | Expected | Derivation |
|---|---|---|---|
| Kumaraswamy CDF | `a=2, b=3, x=0.5` | `0.578125` exactly | `1-(1-0.25)^3 = 1-0.421875` |
| Kumaraswamy round trip | `quantile(0.578125)` | `0.5` to 1e-12 | inverse of the above |
| HypSecant quantile | `loc=0, scale=1, p=0.5` | `0.0` exactly | `tan(π/4)=1`, `ln 1 = 0` |
| Cauchy quantile | `loc=0, scale=1, p=0.75` | `1.0` to 1e-12 | `tan(π/4)=1` |
| Laplace quantile | `loc=0, b=1, p=0.5` | `0.0` exactly | median of a symmetric law |
| Halton dim 1 | first 7 points | `0.5, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875` | van der Corput base 2 |
| LHS stratification | `n=100, d=1` | exactly one point in each `[k/100,(k+1)/100)` | the definition of the design |
| Sobol dim 1 | first 1024 points | every `[k/1024,(k+1)/1024)` occupied exactly once | balance property of a (0,m,s)-net |

`PsiHypSecant`'s quantile is the CI-timeout fixture: written as one expression it is five operators
on a generic `T` and is the shape that compiles locally on 6.4 and times out on 6.0.3. Its test
exists partly to keep the decomposed form from being "simplified" back.

### 10.4 The regression test that protects §3.4

Pin the current seeded output of `DistributionNormal` and `DistributionGamma` — 20 draws each from a
fixed seed, as literals captured before any change lands. If someone later deletes Box–Muller in
favour of the inherited inverse-transform default, this fails immediately and says why. Without it,
§3.4 is a comment.

### 10.5 Negative cases

- `MonteCarloSimulation` with `.latinHypercube` and a `DistributionGamma` input → throws
  `quasiRandomUnsupported`, naming that input. Asserted, because the whole admission design is
  worthless if it ever silently succeeds.
- `SobolSequence(dimension: 257)` → throws.
- `quantile(0)` and `quantile(1)` → documented behaviour, not NaN.
- Unscrambled Halton at d=30 → the test *records* the correlation rather than asserting quality, so
  the known weakness is visible rather than folklore.

---

## 11. Architecture decision review

- [x] Reviewed `architecture_decisions.md`
- Supersedes an existing ADR? **No.**
- Amends an existing ADR? **No.**
- New ADR required? **Yes — two.**

**ADR draft A**
- Title: Inverse-transform is the distribution contract; other sampling routes are opt-outs
- Category: api
- Key decision: `ContinuousDistribution` supplies `next(using:)` by inverse transform, and a type
  that overrides it declares itself ineligible for quasi-random sampling rather than being silently
  excluded or silently downgraded.

**ADR draft B**
- Title: Sobol uses Joe & Kuo (2008) direction numbers, capped at 256 dimensions
- Category: architecture
- Key decision: the direction numbers are vendored, generated, stated in public documentation, and
  bounded by a throwing initializer, because a Sobol sequence that cannot be reproduced against
  another tool does not do the job Sobol sequences exist to do.

**ADR draft C**
- Title: Discrete sampling keeps two implementations, selected by sampling path
- Category: performance
- Key decision: Vose's alias table serves the pseudo-random path at O(1); the QMC path uses a
  monotone binary search at O(log n), because the alias method's non-monotone mapping destroys the
  stratification a low-discrepancy sequence exists to provide — producing a correct distribution
  with silently pseudo-random convergence.

**ADR draft D**
- Title: SciPy reference fixtures are generated once, committed, and version-pinned
- Category: testing
- Key decision: a committed generator script produces JSON fixtures with the SciPy version recorded
  in a manifest; CI never executes Python; parameterisation conversions are recorded as data in the
  fixture so they are reviewable in a diff rather than duplicated in two places that can be wrong in
  the same direction.

---

## 12. Adversarial review

**Strongest case for a different approach.**
A reviewer would reasonably push for **no new protocol at all**: write generic free functions
`kumaraswamyCDF` / `kumaraswamyQuantile` next to the existing `normalCDF` and `betaCDF`, and leave
the structs alone. That is more idiomatic to this codebase — the sixteen existing distributions are
free-function-first and the structs are thin `Double` wrappers — and it adds zero public protocol
surface to document and support. It might genuinely be better if the sampling methods were not in
scope, because then the protocol buys only test convenience, and a shared test harness can be built
over free functions with a bit more boilerplate.

**Where this design is most likely wrong.**
It assumes **one uniform per draw is a reasonable admission criterion for QMC**. That is textbook,
but it silently excludes any distribution whose quantile has no closed form and is computed by
root-finding — the Johnson family, `PsiMetalog` if its coefficients are ill-conditioned, and Pearson
V/VI unless we accept an iterative inverse incomplete gamma. If a large fraction of the 33 end up
with iterative quantiles, "conforms to `ContinuousDistribution`" starts to mean "has a slow
quantile," and the KS test at 100,000 draws becomes the slowest test in the suite. We accepted the
1e-10 CDF tolerance from the coverage proposal without asking whether a root-found quantile can
reach it; for a few of these it may not, and the tolerance will have to be stated per distribution
rather than globally.

**What an experienced critic would say.**
*"You are adding a protocol whose main early customer is your test harness, and paying for it with
public API you will support forever."*

We proceed because the second customer is real and known: the QMC seam has no alternative
formulation — a point set must be able to ask a distribution for the value at a coordinate, and a
free function cannot be asked that through a type-erased `SimulationInput`. The change we made in
response is §3.4: the retrofit is declaration-only, so the protocol costs the existing sixteen
nothing and can be adopted at whatever pace the evidence justifies.

---

## 13. Alternatives considered

**Alternative 1 — free functions only, no protocol** (the §12 counter-design).
- *Advantage:* zero new public protocol surface; exactly matches the existing sixteen.
- *Disadvantage:* no seam for LHS/Sobol; the test harness cannot be generic; nothing prevents the
  33 arriving under 33 naming conventions, which is the failure the frozen contract exists to stop.
- *Rejected because:* the sampling seam has no free-function formulation, and both decisions were
  taken together precisely so the seam would exist.

**Alternative 2 — put `cdf`/`quantile` on `DistributionRandom` itself.**
- *Advantage:* one protocol instead of three; no capability-checking at the QMC boundary.
- *Disadvantage:* source-breaking for every existing conformer and every downstream one, including
  `ProbabilisticDriver` and `ScenarioAnalysis`; and it would be a lie for any distribution defined
  only by a sampling procedure.
- *Rejected because:* it converts an additive 2.10.0 into a breaking 3.0 for no gain.

**Alternative 3 — a `UniformSource` injected into `SeedableDistribution.next(using:)`,
generalising `RandomNumberGenerator` to a low-discrepancy source.**
- *Advantage:* no admission check; a Sobol source just *is* a generator, and Box–Muller keeps
  working by consuming two coordinates.
- *Disadvantage:* it is **wrong**. Feeding successive Sobol coordinates to Box–Muller pairs
  dimension *j* with dimension *j+1* and destroys the equidistribution the sequence exists to
  provide, while producing numbers that look fine. Rejection sampling is worse: the number of
  coordinates consumed depends on the draws, so different inputs desynchronise from the point set.
- *Rejected because:* it is the design most likely to be silently wrong, which this project's rules
  name as the one unacceptable outcome. The explicit admission check is slower to use and impossible
  to be quietly wrong about.

**Alternative 4 — vendor the full 21,201-dimension Joe & Kuo table.**
- *Advantage:* no dimension cap.
- *Disadvantage:* megabytes of generated source for dimensions no financial model reaches.
- *Rejected because:* 256 dimensions with a throwing initializer and a public `maxDimension` is
  honest and bounded; the cap can be raised by regenerating one file if a caller ever needs it.

---

## 14. Future directions

*Owen scrambling and the alias-method sampler were listed here in the first draft and have been
pulled into scope — see §3.5a and §3.5b. What remains deferred:*

- **The randomised-QMC estimator.** `R` independent Owen scrambles yield a standard error that plain
  Sobol cannot provide. Deferred with importance sampling (§3.6) because both need replicate- or
  weight-aware statistics across `SimulationStatistics`, `Percentiles` and `RiskMetrics`. The
  scrambling this proposal adds is the prerequisite, so nothing here is blocked by the deferral.
- **A `quantile` fast path for correlated runs** might let `runCorrelated` skip its sort, since an
  LHS marginal arrives already ordered.
- **GPU quasi-random sampling** could become possible if the kernels were reworked to take a
  uniform buffer rather than generating device-side.
- **Convergence diagnostics** comparing pseudo-random and Sobol error decay might make the case for
  a default change, which this proposal deliberately does not make.
- **An alias-table fast path for continuous distributions** via a fine discretisation could give
  O(1) draws where exactness is not required; this proposal does not pursue approximate sampling.

---

## 15. Open questions — **all resolved 2026-09-04**

1. **Per-distribution CDF tolerance — RESOLVED: relaxation allowed.**
   1e-10 remains the default. A distribution whose quantile is root-found may declare a looser
   tolerance, and the test file must state the reason and the achieved accuracy. Silent relaxation
   is not permitted: the constant is named, commented, and greppable, so the set of relaxed
   distributions can be audited in one search. §3.4a makes this concrete — Beta, Gamma, Chi-squared
   and the Johnson family all invert a special function numerically.

2. **Does LHS require a seed — RESOLVED: yes, required.**
   `SamplingMethod.latinHypercube` with `seed == nil` throws. LHS's stratum permutation is random,
   so an unseeded run is reproducible in its stratification but not its values — a partial
   determinism that is worse than none, because it looks reproducible. This matches the quality
   gate's standing expectation that stochastic results be reproducible, and it matches the existing
   `seedingUnsupported` posture of refusing rather than half-delivering. Scrambled Sobol and Halton
   take the same rule; unscrambled Sobol and Halton are deterministic and need no seed.

3. **Property or parameter for `SamplingMethod` — RESOLVED: property.**
   `public var samplingMethod: SamplingMethod` on `MonteCarloSimulation`, sitting alongside `seed`
   and `correlationMatrix`, which are the two settings it interacts with. Consistent with the
   configure-then-`run()` shape the type already has.

4. **Sobol's first point — RESOLVED: skipped.**
   Our point *i* is SciPy's point *i+1*. SciPy emits the origin as point zero, which inverse-transforms
   to `quantile(0) = -infinity`; SciPy's own guidance is to skip it. Documented on `SobolSequence`
   in prose, asserted in the fixture comparison, and called out here because it is exactly the
   off-by-one that lets two implementations disagree while both look right.

### 15.1 Newly open, from the §3.4a audit

5. **Promoting `regularizedLowerIncompleteGamma` to public API.** It is `private` in
   `chiSquaredCDF.swift:56` today. Making it public commits us to supporting it forever; making it
   `internal` unlocks `gammaCDF` inside the package but not for callers. Proposal: **public**, in a
   `SpecialFunctions/` home alongside `regularizedIncompleteBeta`, which is already public — the
   asymmetry between the two is an accident, not a decision.

6. **Where the two special-function inverses live.** They are shared by eight or more distributions
   and are not distribution-specific. Proposal: `Sources/BusinessMath/Statistics/SpecialFunctions/`,
   a new directory, with the existing `regularizedIncompleteBeta` moved into it. That is a file move
   of a public symbol — source-compatible, but it should be a separate commit from anything
   behavioural.

---

## 16. Documentation strategy

**Documentation type:** narrative article required.

- Combines 3+ APIs? **Yes** — protocols, point sets, `MonteCarloSimulation`.
- Explanation needs 50+ lines? **Yes.**
- Needs theory/background? **Yes** — why stratification reduces variance, why unscrambled Halton
  degrades in high dimensions, and why a distribution can be excluded from a quasi-random run.

**Article name:** `4.6-QuasiRandomSamplingGuide.md`, following `4.5-DeterministicSimulationGuide.md`,
which is the article this one extends. No Swift symbol shares the name.

API docs alone for the retrofit extensions: they add no concepts.
