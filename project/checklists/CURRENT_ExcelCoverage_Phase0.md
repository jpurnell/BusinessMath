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

- [ ] RED — tests for `regularizedLowerIncompleteGamma` as public API (currently `private` at `chiSquaredCDF.swift:56`)
- [ ] GREEN — promote it; new home `Statistics/SpecialFunctions/`
- [ ] Move `regularizedIncompleteBeta` into `SpecialFunctions/` — **separate commit**, pure file move of a public symbol
- [ ] RED — `inverseRegularizedLowerIncompleteGamma` against SciPy `gammaincinv`
- [ ] GREEN — Newton with bisection fallback; bounded iteration, no unbounded `while`
- [ ] RED — `inverseRegularizedIncompleteBeta` against SciPy `betaincinv`
- [ ] GREEN — same shape
- [ ] Verify `chiSquaredCDF` still passes unchanged — it is the existing caller

### 1. The SciPy harness

- [ ] `Scripts/reference-fixtures/{generate.py,spec.py,requirements.txt}` — pin scipy==1.17.1, numpy==2.5.2
- [ ] Fixture JSON schema: Frontline **and** SciPy parameters, plus the conversion as data
- [ ] `Tests/BusinessMathTests/Fixtures/` + `MANIFEST.json` with versions, date, sha256 per fixture
- [ ] `Package.swift` — `resources: [.copy("Fixtures")]` on the test target (first use of `resources:`)
- [ ] Swift-side fixture loader + the shared assertion template of §10.1

### 2. The protocols

- [ ] RED — protocol conformance tests using the shared template
- [ ] `ContinuousDistribution` + default `next(using:)` via inverse transform
- [ ] `DiscreteDistribution` with `pmf` / `cdf(Int)` / `quantile -> Int`
- [ ] `Double.openUnitRandom(using:)` — **open** interval; `quantile(0)` is −∞ for most of these
- [ ] Regression test pinning existing seeded streams of `DistributionNormal` and `DistributionGamma` (§10.4) — **write this before any retrofit lands**

### 3. Retrofit the fifteen (§3.4a audit)

- [ ] Already complete, declaration only: `Normal`, `T`, `F`
- [ ] Trivial quantile: `Uniform`, `Exponential`, `LogNormal` (`exp(inverseNormalCDF(p))`)
- [ ] Extract the inlined quantile, derive the CDF: `Triangular`, `Weibull`, `Pareto`, `Rayleigh`, `Logistic`, `Geometric`
- [ ] Root-found quantile on the new inverses: `Beta`, `ChiSquared`, `Gamma`
- [ ] `gammaCDF` / `erlangCDF` from the promoted incomplete gamma

### 4. Sampling

- [ ] `QuasiRandomPointSet` protocol, `SamplingMethod` enum
- [ ] `LatinHypercubeSampler` — seed required
- [ ] `SobolSequence` + generated Joe & Kuo direction numbers, 256 dimensions, throwing `init`
- [ ] `OwenScramble` — hash-based nested uniform scrambling
- [ ] `HaltonSequence` — record the high-dimension correlation rather than asserting quality
- [ ] `AliasTable` — Vose's method
- [ ] `SimulationError.quasiRandomUnsupported(inputName:details:)`
- [ ] `MonteCarloSimulation.samplingMethod` + the QMC branch in `run()` and `run() async`
- [ ] QMC runs skip GPU and say so in `executionNotes`
- [ ] LHS + `runCorrelated` — Iman–Conover composes; verify the marginal stays stratified

### 5. Documentation

- [ ] DocC on every public symbol; `SobolSequence` states its direction-number source in prose
- [ ] Narrative article `4.6-QuasiRandomSamplingGuide.md` (extends `4.5-DeterministicSimulationGuide.md`)
- [ ] ADRs A–D from §11
- [ ] CHANGELOG, README, `master_plan.md` reconciled per the doc-housekeeping rule

### 6. Verify

- [ ] `swift build -Xswiftc -Xfrontend -Xswiftc -solver-expression-time-threshold=500` — the `PsiHypSecant` quantile is the 5-operator CI-timeout shape
- [ ] Full `swift test` — not `--filter`; capture the real exit code
- [ ] `quality-gate --no-cache` — 0 errors / 0 warnings, no overrides

---

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
