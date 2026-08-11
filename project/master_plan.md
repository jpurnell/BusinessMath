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
| tests | 6,520 in 567 suites, 0 known issues |
| build | **0 warnings**, library and test target |
| quality gate | **0 errors, 0 warnings** across 36 checkers (`--no-cache`; a cached run executes 10) |
| documentation coverage | 100% — 6,471 of 6,471 public APIs |
| DocC catalogue | **73 articles**, all compiling as one program under `quality-gate --check doc-code` |
| toolchain | `swift-tools-version: 6.2`, Swift 6 strict concurrency |

The test figure is measured. A `--bootstrap --check status` run estimates 7,818 by counting
test-shaped declarations; that heuristic is not the number of tests and should not be quoted.

### Known Issues

The honest list. Sources: `project/plans/TrustPlan.md`, and the gate's own output.

**In the gate**

The gate is at **0 errors, 0 warnings across 36 checkers**. What follows is not currently firing.

- **A cached run executes 10 of 36 checkers and prints the same summary line.** Measured. Only
  `--no-cache` reaches `unreachable`, `doc-coverage`, `recursion`, `concurrency` and
  `release-readiness`. Every figure quoted in this document came from a `--no-cache` run; a plain
  `quality-gate` is not evidence of anything. This is the third instance of the same shape found
  in one session — see also the build checker compiling only the library, and the diagnostic
  parser that never matched a coloured line.
- **`release-readiness` reads a version out of any heading containing a number.** "…accurate to
  ~1.5e-7" was reported as a missing `v1.5` tag. Worked around here by moving the figure into the
  body; the checker bug is unfixed and lives in quality-gate-swift.
- **`TestQualityAuditor` has no warning-only state**, so the gate exits 1 at zero errors if any
  test-quality warning exists. One line, in quality-gate-swift.

**In the test suite**

- **Three performance tests carry a correctness assertion behind a wall-clock bound.**
  `Performance_SummaryGeneration` (12× margin), `ModelValidation` (16×), `ModelInspectionOnLargeModel`
  (17×) — all tighter than the 37× that went red under load, and each also asserts something real
  (`summary.contains("Revenue")`). Gating them on `RUN_BENCHMARKS` would delete that coverage, so
  they need *splitting* into a correctness test and a benchmark, which is why they were left. The
  file header's stated "10× headroom" policy is not a sufficient bar.
- **`Performance_MemoryEfficiency` asserts elapsed time and is named for memory.** ~1100× margin,
  so not a flake risk — the same name-versus-instrument defect as the test renamed
  `Benchmark_TimeSeriesCreationThroughput`, left for the same sweep as the three above.

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
- **`BusinessMathDSL` offers no non-trapping parameter access.** `evaluate`, `statistics`, `best`,
  `worst` and `percentile` take non-throwing `(Scenario) -> Double` closures over a bare
  `[String: Double]` with no accessor, so a missing parameter can only trap or invent a number.
  Seven doc examples use `preconditionFailure` naming the key — a workaround, not a fix. Two
  remedies: make the closures throwing, as `ScenarioRunner.StatementBuilder` already is, or add
  the accessor `MonteCarloScenario` already has at `AdvancedOptimization/Scenario.swift:73`.

**In the documentation**

- **The `///` doc-comment corpus is unchecked.** 1,394 fenced code blocks against the catalogue's
  ~1,291, and it is *upstream* of the catalogue — `RiskMetrics.swift` documents an initialiser
  that does not exist, and article `4.3` had the identical error because it was copied from Quick
  Help. `doc-code` covers the catalogue; `doc-comment-code` does not exist yet.
- **Published outputs are typechecked but not executed** — *closing*. `doc-run` (rung 2) is
  committed in quality-gate-swift and `doc-claims` (rung 3) is in build. Until they ship and clear
  this codebase, the only evidence is by hand: executing five articles found four real defects
  that all pass `doc-code`, and `4.1`'s headline figure was wrong because the code indexed the
  one-year array under a two-year label. That article is now seeded end to end with all 170 figures
  regenerated; two-year growth reads 113.5%.
- **One line in `4.1` cannot be made deterministic.** `Compute time` comes from
  `Date().timeIntervalSince(start)`. Named in the article rather than hidden, and it is the case
  `doc-claims` has to handle gracefully.

---

## Current Priorities

**2.6.0 is written and deliberately unshipped.** The code, the CHANGELOG and the README are done;
the tag is being held until three checkers land and clear this codebase. The reasoning is that the
last two days found defects in documentation nothing was checking — a runtime trap in `4.2`
inherited from `ScenarioRunner`'s own `///` comments, two published figures that were simply wrong,
and a headline percentage computed off the wrong array. Shipping before the checkers exist means
shipping whatever else is in that class.

Until then the CHANGELOG heading reads `[2.6.0] — unreleased` and the README advertises `2.5.2`,
which is what resolves today. Both revert at tag time. `release-readiness` passes on that basis;
it failed, correctly, while they claimed otherwise.

1. **Land the four `doc-*` checkers, in the order the proposal argues for.** `doc-comment-code`
   first, because it is upstream: repairing the catalogue while Quick Help still hands out the
   wrong signature guarantees the drift returns. Then `doc-symbol-link`, `doc-generated`, and
   `doc-claims` (rung 3; `doc-run` is already committed).
2. **Clear this codebase under all four.** That is the gate on the tag, not the checkers existing.
3. **Cut 2.6.0** — tag, revert the two version strings, push. 64 commits are unpushed.
4. **Differential testing against published references** (TrustPlan §2.2) — the highest ratio of
   defects-found to effort in the plan. It is how the discontinuous `inverseNormalCDF`, the
   `normalCDF` lower tail and the Black-Scholes negative prices were all found. Remaining targets:
   the distribution family, `irr`/`npv`/`xirr`, the greeks.
5. **Split the three timed correctness tests**, so a wall clock stops gating a claim about the
   library.

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

### Phase 3 — the published numbers must be real (in progress)

Specified in `quality-gate-swift/project/plans/proposals/DocOutputVerification.md`, which measured
the corpus first: 101 output claims across 16 of the 73 articles, in three spellings
(`// Result:` 85, `// Output:` 9, `// →` 7).

- [x] Seed every Monte Carlo example in the catalogue — a precondition, not a nicety. An unseeded
      example has no pinned output, so rung 3 cannot verify it at all. There were 29 this morning.
- [x] `doc-run` (rung 2): execute the assembled article. Committed in quality-gate-swift.
- [ ] `doc-claims` (rung 3): compare printed output against the documented claims. **No `--fix`,
      ever** — an autofixer that rewrites a documented number to match the program launders
      regressions into documentation, and this release produced the case that proves it.
- [ ] `doc-comment-code`: the `///` corpus, 1,394 blocks and upstream of the catalogue
- [ ] `doc-symbol-link`, `doc-generated`: the other two rules from the same proposal

The known limit, recorded rather than resolved: rung 3 is a change detector, not a truth detector.
Fixing `normalCDF` moved five expectations that had been recorded from this library's own output —
under rung 3 that correct fix turns documented figures red, and the tempting repair is to edit the
documentation. It enforces "published numbers are real" and is silent on "the library does not
lie".

### Candidates, not commitments

- Cross-period reference in the formula language (`openingDebt(t) = closingDebt(t−1)`), which is
  what would make the canonical circular-interest example expressible at all
- Reconcile `BusinessMathDSL.ScenarioAnalysis.percentile` with the core `quantile`

---

**Last Updated:** 2026-08-11 — reconciled against the tree after the 2.6.0 work, not against
the previous revision. Closed as done: the `weak-assertion` cluster (0 in the gate), the unseeded
`MonteCarloSimulation` audit (all 22 remaining constructions verified correct — 13 pass their seed
to `runCorrelated`, the rest are custom-sampler tests the seeded path rejects by design), and the
CHANGELOG backfill (29 commits that had no entry now do). Added: the cached-gate coverage gap, the
`release-readiness` heading false positive, the `BusinessMathDSL` accessor gap, and three timed
correctness tests needing splitting. Roadmap Phase 3 rewritten around the four `doc-*` checkers,
which are now the gate on the tag.
