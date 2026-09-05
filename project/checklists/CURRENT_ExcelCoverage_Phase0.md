# CURRENT — Excel/Risk Solver coverage, Phase 0

**Design proposal:** `project/plans/proposals/PROPOSAL_distribution_contract_and_sampling.md` — approved 2026-09-04, all open questions resolved.
**Work list it unblocks:** `project/plans/proposals/excel-coverage/businessmath_work.tsv` — 49 rows, 42 of them blocked on this phase.
**Branch:** `docs/excel-function-coverage` → implementation branch `feature/distribution-contract`.
**Target version:** 2.10.0 — additive.

---

## Why this phase exists

Two things had to be settled before 33 distributions get written:

1. `DistributionRandom` requires only `next()`, so the coverage proposal's verification plan — CDF to
   1e-10, quantile round-trip, KS against the reference CDF — was not expressible.
2. Latin hypercube and Sobol are joint across inputs, and `SimulationInput` erases every distribution
   to an independent per-input closure. There was no seam.

Both resolve to the same missing idea: **a distribution should be able to say what value sits at a
given uniform.**

---

## Decisions taken (do not re-litigate)

| # | Decision | Where |
|---|---|---|
| 1 | `ContinuousDistribution` / `DiscreteDistribution` protocols with `cdf`/`quantile` | §3.3 |
| 2 | QMC eligibility = **conforms to the protocol**, not "didn't override `next(using:)`" | §3.4 |
| 3 | Retrofits keep their existing `next(using:)`; no seeded stream changes | §3.4 |
| 4 | Per-distribution CDF tolerance relaxation allowed, must state the reason | §15.1 |
| 5 | Latin hypercube **requires** a seed; throws without one | §15.2 |
| 6 | `samplingMethod` is a property on `MonteCarloSimulation` | §15.3 |
| 7 | Sobol skips the origin — our point *i* is SciPy's *i+1* | §15.4 |
| 8 | Owen scrambling now (~25 lines); the R-replicate RQMC estimator deferred | §3.5a |
| 9 | Alias table O(1) on the pseudo-random path; monotone binary search O(log n) on QMC | §3.5b |
| 10 | SciPy fixtures generated once, committed, version-pinned; CI never runs Python | §10.2a |

---

## Ordered work

### 0. Special functions — the highest-leverage items, do first

Between them these supply quantiles for Gamma, Erlang, Chi-squared, Beta, F, Pearson V, Pearson VI
and the Johnson family.

- [x] RED — tests for `regularizedLowerIncompleteGamma` as public API (currently `private` at `chiSquaredCDF.swift:56`)
- [x] GREEN — promote it; new home `Statistics/SpecialFunctions/`
- [ ] Move `regularizedIncompleteBeta` into `SpecialFunctions/` — **separate commit**, pure file move of a public symbol
- [x] RED — `inverseRegularizedLowerIncompleteGamma` against SciPy `gammaincinv`
- [x] GREEN — Newton with bisection fallback; bounded iteration, no unbounded `while`
- [x] RED — `inverseRegularizedIncompleteBeta` against SciPy `betaincinv`
- [x] GREEN — same shape
- [x] Verify `chiSquaredCDF` still passes unchanged — it is the existing caller

### 1. The SciPy harness  — *generator + 344 special-function cases done; distribution fixtures added per row*

- [x] `Scripts/reference-fixtures/{generate.py,spec.py,requirements.txt}` — pin scipy==1.17.1, numpy==2.5.2
- [x] Fixture JSON schema: Frontline **and** SciPy parameters, plus the conversion as data
- [x] `Tests/BusinessMathTests/Fixtures/` + `MANIFEST.json` with versions, date, sha256 per fixture
- [x] `Package.swift` — `resources: [.copy("Fixtures")]` on the test target (first use of `resources:`)
- [x] Swift-side fixture loader (`Tests/BusinessMathTests/Support/ReferenceFixture.swift`)
- [x] The shared assertion template of §10.1 — lands with the protocols in step 2

### 2. The protocols

- [x] RED — protocol conformance tests using the shared template
- [x] `ContinuousDistribution` + default `next(using:)` via inverse transform
- [x] `DiscreteDistribution` with `pmf` / `cdf(Int)` / `quantile -> Int`
- [x] `Double.openUnitRandom(using:)` — **open** interval; `quantile(0)` is −∞ for most of these
- [x] Regression test pinning existing seeded streams of `DistributionNormal` and `DistributionGamma` (§10.4) — **write this before any retrofit lands**

### 3. Retrofit the fifteen (§3.4a audit) — **done**

- [x] Already complete, declaration only: `Normal`, `T`, `F`
- [x] Trivial quantile: `Uniform`, `Exponential`, `LogNormal` (`exp(inverseNormalCDF(p))`)
- [x] Extract the inlined quantile, derive the CDF: `Triangular`, `Weibull`, `Pareto`, `Rayleigh`, `Logistic`, `Geometric`
- [x] Root-found quantile on the new inverses: `Beta`, `ChiSquared`, `Gamma`
- [x] `gammaCDF` / `erlangCDF` from the promoted incomplete gamma

### 4. Sampling — **done**

- [x] `QuasiRandomPointSet` protocol, `SamplingMethod` enum
- [x] `LatinHypercubeSampler` — seed required
- [x] `SobolSequence` + generated Joe & Kuo direction numbers, 256 dimensions, throwing `init`
- [x] `OwenScramble` — hash-based nested uniform scrambling
- [x] `HaltonSequence` — record the high-dimension correlation rather than asserting quality
- [x] `AliasTable` — Vose's method
- [x] `SimulationError.quasiRandomUnsupported(inputName:details:)`
- [x] `MonteCarloSimulation.samplingMethod` + the QMC branch in `run()` and `run() async`
- [x] QMC runs skip GPU and say so in `executionNotes`
- [x] LHS + `runCorrelated` — Iman–Conover composes; verify the marginal stays stratified

### 5. Documentation

- [ ] DocC on every public symbol; `SobolSequence` states its direction-number source in prose
- [ ] Narrative article `4.6-QuasiRandomSamplingGuide.md` (extends `4.5-DeterministicSimulationGuide.md`)
- [ ] ADRs A–D from §11
- [ ] CHANGELOG, README, `master_plan.md` reconciled per the doc-housekeeping rule

### 6. Verify

- [x] `swift build -Xswiftc -Xfrontend -Xswiftc -solver-expression-time-threshold=500` — the `PsiHypSecant` quantile is the 5-operator CI-timeout shape
- [ ] Full `swift test` — not `--filter`; capture the real exit code
- [ ] `quality-gate --no-cache` — 0 errors / 0 warnings, no overrides

---

## Decision revised: Sobol keeps the origin (2026-09-04)

Decision #7 was "skip the origin", because every coordinate of it is zero and zero
inverse-transforms to −infinity. The half-cell offset — added later, from the
open-interval requirement — already lifts it to 2⁻³³, so the reason had evaporated;
and keeping the skip cost the balance property, which is the entire point of using
Sobol. Over 2^m points starting from the second you hold all but one of one block plus
one of the next, leaving one dyadic interval empty and another doubled. The
`sobolIsBalanced` test found it.

**Our point *i* is now SciPy's point *i*, plus 2⁻³³ in every coordinate.** Halton still
starts at index 1, because its radical inverse carries no offset and index 0 really is
the origin.

## Follow-up closed: t and F tail accuracy (2026-09-04)

Recorded at 2.10.0 rather than fixed: `tQuantile` and `fQuantile` were accurate to
about 1e-5 and 1e-6 relative at p = 1e-8, so their conformance grid stopped at 1e-4.

Both bisected on their own CDFs against an **absolute** tolerance of 2⁻⁴⁰, which at a
probability of 1e-8 is 9e-5 relative — not a tolerance to tighten but a method to
replace. Both distributions invert in closed form through the beta, which the phase had
just made accurate:

- `ν/(ν+T²) ~ Beta(ν/2, ½)`, so `t = ±√(ν(1−x)/x)` with `x = I⁻¹(2·tail, ν/2, ½)`.
- `d₁F/(d₁F+d₂) ~ Beta(d₁/2, d₂/2)`, so `f = d₂x/(d₁(1−x))`; above the median the
  mirrored `I⁻¹(1−p, d₂/2, d₁/2)` gives `1−x` directly instead of subtracting from one.

Both now hold the **default** 1e-9 round-trip tolerance, not the root-found relaxation,
and the tail-limited grid is deleted.

Two things found on the way:

- **`fCDF` had the same cancellation.** It computed `1 − I_{d₂/(d₂+d₁f)}(d₂/2, d₁/2)`,
  whose argument rounds to within an ulp of 1 for small `f` — at f = 1.65e-16 with
  (1, 10) degrees of freedom it returned exactly zero where the answer is 1e-8. The
  direct form subtracts nothing.
- **We are now more accurate than the reference in one place.** At f = 4.05e19 with
  (1, 1), `scipy.stats.f.cdf` saturates to exactly 1.0; the true value is
  1 − 1.0000000827e-10, which is what we return.

And a testing trap worth keeping: **an identity between `p` and `1 − p` can only be
tested where those two are actually complementary.** `1 − (1 − 1e-8)` recovers
1.0000000050e-08, a 5e-9 error in the argument before any function runs — which is
exactly the asymmetry the symmetry test reported. Negative powers of two have exact
complements and reach further into the tail anyway (2⁻⁴⁰ ≈ 9e-13).

## Standing rule: no magic numbers, and derive what can be derived

Stated by the user 2026-09-04, and it changed the code rather than just its comments.

- **Fitted constants that only seed a root-finder get deleted, not named.** Both
  special-function inverses opened with a textbook initial estimate — Wilson–Hilferty
  over a rational fit to the normal quantile, and Abramowitz & Stegun 26.5.22 — which
  between them carried nine decimal coefficients that cannot be derived from anything.
  They exist to start the iteration somewhere good. A bracket does that job with a
  number the distribution supplies itself: its mean. Both are gone, all 344 SciPy
  reference cases still pass, and the cost is a few iterations nobody measures.
- **A test's critical value is derived too.** The KS bound is found by solving
  Kolmogorov's series for λ; the χ² bound is `2·P⁻¹(1−α, ν/2)` through the library's
  own gamma inverse. Both are then *checked against* the published tables in a test —
  the table is the check on the derivation, never an input to it.
- **Format constants come from the format.** `>> 11` is
  `UInt64.bitWidth − (significandBitCount + 1)`; `0x1p-53` is `ulpOfOne / 2`; iteration
  caps are the exponent range plus the significand width. The same code is then right
  for `Float`.
- Where a constant genuinely is the algorithm — Acklam's minimax fit inside
  `inverseNormalCDF` — it stays, and `decimal(_:over:)` stays private beside it.

## Traps found while building (2026-09-04)

- **`1 - exp(-y)` keeps no digits in the lower tail.** It cost every one of
  Exponential, Weibull and Rayleigh their round trip at p = 1e-8; `expMinusOne` is
  exact there. The same cancellation was already in the shipped `exponentialCDF`, now
  fixed. Pareto needed `log(onePlus:)` on the relative offset for the same reason.
- **Triangular cancelled twice.** `1 − (b−x)²/(W·R)` computes near-zero values as one
  minus one when the mode sits at the lower bound; `R·L + e(2R − e)` is the same
  quantity with no subtraction. Its quantile had the mirror problem — `b − √(…)` built
  the answer down from `b` when it needed to build up from `a`.
- **A single-seed χ² test fails one time in a hundred by construction.** Seed 4242 put
  Geometric at 21.75 against a critical 20.09 and looked exactly like a broken sampler;
  thirty seeds averaged 7.64 against a theoretical 8.0 and 2,000,000 draws gave 6.92.
  The test now requires two failures out of nine.
- **`try?` is not a way to satisfy a total contract.** Twenty-three of them became one
  `totalizedResult` bridge that logs what it discards, and ChiSquared's CDF lost its
  error path entirely by calling the non-throwing function underneath.

- **Defaulting both samplers costs you associated-type inference.** With `next()` and
  `next(using:)` both supplied by the extension, `T` has little left to be inferred
  from and the diagnostic names the associated type rather than the confusing line.
  Conformers state `typealias T = Double`; the protocol's doc example says why.
- **`next()` cannot take a generator — it is the protocol requirement.** Both the
  `SystemRandomNumberGenerator` and the `.random()` spellings trip the stochastic
  checker, and no code change removes the need for an unseeded entry point that
  `DistributionRandom` itself requires. Marked with the project's established
  `// stochastic:exempt — the documented unseeded path`, matching the wording at the
  ten existing sites. The marker must sit **inline on the call line**, not the
  signature line.
- **DocC will not link an extension member of a protocol.** ``next(using:)`` resolves
  to nothing from inside `ContinuousDistribution`'s own documentation; single
  backticks are correct there, and the Topics section keeps real links only for the
  requirements.

- **A safeguarded root-finder must test convergence *before* it bisects.** On the final
  iteration the step is zero, so `candidate == x`, and `x` has just become a bracket
  endpoint — which fails a strict `candidate > low` test. Bisecting first replaced an
  exact root with the midpoint of the remaining bracket and then broke, returning
  68.969 where the answer was 67.903. Both inverses had it. The fixtures caught it; a
  smoke test would not have.
- **`P(a, x) − p` is worthless above the median.** At `p = 1 − 1e-10` both terms are
  within 1e-10 of 1 and the residual keeps about six digits. `regularizedUpperIncompleteGamma`
  now exists so the iteration can work on whichever tail is small; the beta inverse
  reflects through `I_x(a,b) = 1 − I_{1−x}(b,a)` for the same reason.
- **Wilson–Hilferty takes *minus* the deviate.** The rational approximation returns the
  lower-tail normal deviate, so a probability above the median arrives negative. The
  sign error put the initial estimate at 35.0 instead of 67.9.
- **A round-trip tolerance near a bounded support is a conditioning question, not a
  quality one.** For the arcsine case at `p = 1 − 1e-8` the root sits one ulp below 1,
  so `1 − x` carries a single significant digit and one ulp is worth 2.4e-9 in `p`.
  SciPy's own round-trip error there is 5.1e-10. The test now asserts
  `density(x) · ulp(x)`, which states the limit instead of hiding it.
- **`Real` has no `ExpressibleByFloatLiteral`.** `T(0.5)` resolves to `init(_: Int)` and
  fails to compile. `decimal(_:over:)` — promoted out of `inverseNormalCDF.swift`, where
  it was private — is the existing answer.

## Traps recorded during design

- **Never let a retrofit adopt the default `next(using:)`.** `DistributionNormal` is Box–Muller (2 uniforms), `DistributionGamma` is Marsaglia–Tsang rejection (unbounded). Inheriting inverse-transform would change the stream for the same seed. The §10.4 regression test is what makes this rule real rather than a comment.
- **The alias method is not monotone in `u`.** Correct distribution, zero variance reduction under QMC, and nothing in the output says so. Hence two implementations.
- **Sobol without stated direction numbers is unreproducible** against SciPy or Frontline, which defeats the purpose of using it.
- **Do not convert a parameterisation in both `spec.py` and Swift.** Wrong in the same direction twice = green test, wrong library. The conversion lives in the fixture as data.
- **`uniformCDF(x:)`, `logNormalCDF(_:mean:stdDev:)`, `exponentialCDF(_:λ:)`, `normalCDF(x:mean:stdDev:)`** — four different first-argument labellings. `cdf(_:)` unifies them without renaming any.

---

## Not in this phase

Importance sampling and the R-replicate RQMC estimator — both need weight- or replicate-aware
statistics across `SimulationStatistics`, `Percentiles` and `RiskMetrics`. GPU quasi-random sampling.
Narrowing `FormulaEvaluator.Function`, which is source-breaking and belongs in 3.0.
