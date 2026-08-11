# BusinessMath Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

## Mission

A Swift library for financial analysis, forecasting and quantitative modelling whose numbers can
be trusted without being re-derived. Two things follow from that and shape most decisions here:

1. **The library does not lie about what it does.** A wrong number is a bug; a confident wrong
   *answer* is worse, because the caller has no reason to check it. Where a capability was
   documented and did not exist, the correction has been retraction, not silence — see the 2.6.0
   removal of the two circular-dependency detectors.
2. **Where a number cannot be exact, the library says so.** Measured accuracy belongs in the doc
   comment, non-reproducibility belongs in the signature, and a seeded path that silently falls
   through to a global generator is a defect even when every test passes.

The long form of this, with the ordering and the reasoning, is `project/plans/TrustPlan.md`.

---

## Targets

Four targets, declared in `Package.swift` at `swift-tools-version: 6.2`.

| target | shape | what it is for |
|---|---|---|
| **BusinessMath** | 526 source files, ~139,945 lines | The library. Time series and fiscal calendars, time value of money, forecasting and seasonal decomposition, financial statements, securities and credit valuation, risk analytics, Monte Carlo, optimisation (simplex, branch-and-bound, heuristics, GPU), statistics and distributions. Generic over `T: Real & BinaryFloatingPoint`. |
| **BusinessMathDSL** | 15 source files, 3,813 lines | A declarative result-builder surface over the modelling types, for expressing scenarios and models as prose-shaped Swift. Depends only on swift-numerics; deliberately not merged into the core. |
| **BusinessMathMacros** | 1 source file, 302 lines | The macro declarations, backed by the `BusinessMathMacrosImpl` SwiftSyntax compiler plugin. Kept out of `BusinessMath`'s dependency list so Playgrounds do not have to load a plugin. Not built on Linux. |
| **TestSupport** | 5 source files, test-only | Shared test infrastructure — `FloatingPointClaims` (which kind of exactness an assertion claims), `SeededRNG` / `DeterministicHelpers` (reproducible draws), `ConditionTraits` and `PlatformSupport` (skip conditions that name their reason). Used throughout `BusinessMathTests`. |

A previous generated revision of this document recorded "TestSupport — Not yet implemented".
That was wrong: it exists at `Tests/TestSupport`, is declared in `Package.swift`, and the test
suite depends on it.

---

## Current Status

Cutting **2.6.0** (previous tag `v2.5.2`), from
`fix/simplex-scale-relative-feasibility`.

| | |
|---|---|
| tests | **6,494 in 565 suites**, 0 known issues — two consecutive clean runs |
| build | **0 warnings**, library and test target |
| quality gate | **0 errors, 1 warning** — a `weak-assertion` consistency cluster, 137 occurrences |
| documentation coverage | **100% — 6,447 of 6,447 public APIs documented** (`quality-gate --check doc-coverage`) |
| DocC catalogue | **73 articles**, all compiling as one program under `quality-gate --check doc-code` |
| toolchain | `swift-tools-version: 6.2`, Swift 6 strict concurrency |

The test figure is measured. A `--bootstrap --check status` run estimates 7,818 by counting
test-shaped declarations; that heuristic is not the number of tests and should not be quoted.

### Known Issues

The honest list. Sources: `project/plans/TrustPlan.md`, and the gate's own output.

**In the gate**

- **`weak-assertion`, 137 occurrences** — the single remaining gate warning, a consistency
  cluster rather than 137 independent findings. Assertions that hold whether or not the code under
  test is correct: bounds checks where a value was available, `!= nil` where the value mattered.
  The 2.6.0 quantile fix is exactly what this class hides — every assertion touching
  `DriverProjection.percentile` was an ordering check, and all of them held under a 37% error.
- **`TestQualityAuditor` has no warning-only state**, so the gate exits 1 at zero errors if any
  test-quality warning exists. One line, and it lives in quality-gate-swift, not here.

**In the test suite**

- **34 unseeded `MonteCarloSimulation` constructions remain unaudited.** Each is a test asserting a
  statistical property of an unseeded run, which measures sampling noise rather than the thing
  named in the test. Two of this class were found failing by chance and seeded in `da932ec`; the
  rest have not been looked at individually. An audit is in progress.

**In the library**

- **`Period.<` compares granularity before start date**, so a `TimeSeries` mixing annual and
  quarterly points is stored out of chronological order. Pinned in a test, not fixed.
- **Three `BusinessMathError` cases still have no producer** — `negativeValue` (E301),
  `outOfRange` (E302), `resourceExhausted` (E400). E301/E302 are refactors that belong with a
  consolidation of the four parallel validation vocabularies (`BusinessMathError`,
  `Validation/ValidationTypes`, `StandardValidation`'s unused rules, and the macro-generated one),
  not standalone work. E400 is undocumented as well as unwired and needs a decision.
- **Documented API that does not exist**, catalogued in
  `project/plans/proposals/IntendedSurface.md` §2. `3.15`'s ingestion subsystem and
  `Period.custom` are resolved; remaining are `FinancialModel`'s balance-sheet surface,
  `DataTable`'s fluent chain, and structured logging. Each is build-it-or-retract-it.
- **`BusinessMathDSL.ScenarioAnalysis.percentile` diverges from the core `quantile`** —
  nearest-rank against R-7, so `percentile(50)` of `[1,2,3,4]` is 2.0 rather than 2.5. Deliberate
  for now, and recorded so it is not rediscovered as a bug.

**In the documentation**

- **The `///` doc-comment corpus is unchecked.** 1,394 fenced code blocks against the catalogue's
  ~1,291, and it is *upstream* of the catalogue — `RiskMetrics.swift` documents an initialiser
  that does not exist, and article `4.3` had the identical error because it was copied from Quick
  Help. `doc-code` covers the catalogue; `doc-comment-code` does not exist yet.
- **Published outputs are typechecked but not executed.** `doc-code` proves the articles compile;
  it does not prove that a `// prints:` claim is what the code prints. `4.1` published "Total
  Growth over 2 years: 62.3%" where the code yields 113.9%, and its 90/95/99% confidence intervals
  printed identically. Both are fixed; the class is not closed.
- **The 2.6.0 CHANGELOG entry does not cover every code-affecting commit on the branch.** Roughly
  half the 45 commits have a corresponding entry. The numerically significant ones now do.

---

## Current Priorities

1. **Cut 2.6.0.** Documentation is reconciled; the release itself is the tag and the push. 45
   commits are unpushed.
2. **The `weak-assertion` cluster.** It is the last gate warning and, more to the point, it is the
   class of test that let a 37% percentile error and a never-executed branch of
   `correctedStdErr` ship. Fixing it is not warning-hygiene.
3. **Audit the 34 unseeded `MonteCarloSimulation` constructions.** Same reasoning: an assertion
   over an unseeded run either fails intermittently or asserts nothing.
4. **Differential testing against published references** (TrustPlan §2.2) — the highest ratio of
   defects-found to effort in the plan. It is how the discontinuous `inverseNormalCDF`, the
   `normalCDF` lower tail and the Black-Scholes negative prices were all found. Remaining targets:
   the distribution family, `irr`/`npv`/`xirr`, the greeks.
5. **`doc-comment-code`.** Larger corpus than the catalogue, entirely unchecked, and upstream of it.

---

## Roadmap

### Phase 1 — stop the lying (largely done)

- [x] Retract the two circular-dependency detectors, and build real cycle detection where the
      condition is representable (`ModelDefinition`, Tarjan, exact solution of linear cycles)
- [x] Wire `numericalInstability` (E004), `invalidDriver` (E200), `inconsistentData` (E202) to the
      sites that already detected those conditions
- [x] Rewrite `3.15` around the boundary that exists rather than an ingestion subsystem that does not
- [ ] `negativeValue`, `outOfRange`, `resourceExhausted` — with the validation-vocabulary consolidation
- [ ] The remaining `IntendedSurface.md` §2 items: build or retract

### Phase 2 — say when a number is inexact (in progress)

- [x] `normalCDF` in the lower tail — `erfc(-x/√2)/2`, 2.2e-5 → 5.3e-15 at p = 1e-12
- [x] One canonical `inverseNormalCDF`, one Box-Muller, one empirical quantile
- [x] Seeds that survive: `seed: UInt64?` / `using: inout G` across the distribution family,
      `integrate`, `ScenarioGenerator`, the GPU path, and `bayesianICC`
- [ ] Differential suites for the distribution family, the TVM functions and the greeks
- [ ] Record measured accuracy in every doc comment where the answer is approximate, as
      `inverseNormalCDF` now does

### Phase 3 — the published numbers must be real

- [ ] `doc-comment-code`: typecheck the `///` corpus
- [ ] Execute assembled articles and compare against their `// prints:` claims — expensive, and
      the only thing that closes the class

### Candidates, not commitments

- Cross-period reference in the formula language (`openingDebt(t) = closingDebt(t−1)`), which is
  what would make the canonical circular-interest example expressible at all
- Reconcile `BusinessMathDSL.ScenarioAnalysis.percentile` with the core `quantile`

---

**Last Updated:** 2026-08-11 — replaced the generated stub for the 2.6.0 release. Reconciled
against the tree rather than against the previous revision: corrected "TestSupport — Not yet
implemented" (it exists and is used throughout the suite), replaced "Known Issues: None currently"
with the list from `TrustPlan.md` plus the 137-occurrence `weak-assertion` cluster and the 34
unaudited unseeded `MonteCarloSimulation` constructions, dropped the heuristic 7,818 test estimate
in favour of the measured 6,494 in 565 suites, and added mission, targets, priorities and roadmap
in place of the three `<!-- TODO -->` markers.
