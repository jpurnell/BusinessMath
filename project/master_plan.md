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

Cutting **2.6.0** (previous tag `v2.5.2`), from `main`. 154 commits since the tag, **not yet pushed**.

| | |
|---|---|
| tests | **6,610 in 582 suites**, 0 known issues, ~35s |
| build | **0 warnings**, library and test target |
| quality gate | **0 errors, 0 warnings** — but see the note below: the default run is 35 of 42 checkers, and the worktree exclusion needs a quality-gate build that is not yet installed |
| CI | green — 4/4 jobs, including `Linux release compile check` |
| gate, worktrees | excluded via `excludePatterns` — needs the `gpu-safety` fix that honours it, which is staged in quality-gate and not yet installed |
| nightly (Release Tests) | green — Ubuntu release, macOS release, and Thread Sanitizer |
| documentation coverage | 100% — 6,504 of 6,504 public APIs |
| DocC catalogue | **73 articles**, all compiling as one program under `quality-gate --check doc-code` |
| `doc-comment-code` | **0 errors** — macro modules included. The tag gate is cleared. |
| `doc-claims` | **0 errors** — cleared 2026-08-13 |
| toolchain | `swift-tools-version: 6.2`, Swift 6 strict concurrency |

**Outstanding before the tag.** None of these is a code defect; all four are release
hygiene, and the first two are not in this repository.

1. **The `gpu-safety` exclusion fix is staged in quality-gate, uncommitted and not
   installed.** Until it lands, the installed binary reports 53 errors from stale copies
   under `.claude/worktrees/`, and a release verified on this machine today looks red. The
   0/0 above is from a local build carrying that fix.
2. **`--check all` runs 42 checkers; the default run is 35.** The seven it omits are
   opt-in by convention or by cost, which is a defensible default — but this project's
   config asked for all of them through a key the schema does not have (`checkers:`
   rather than `enabledCheckers:`), and unknown keys are discarded silently. That is how
   `recursion` came never to run, and how a crashable parser reached a release candidate.
   Proposals for both are filed in the quality-gate repository.
3. **154 commits unpushed.**
4. **`5.10-ParallelOptimization.md` hangs under `doc-run`** and is killed at the 30-second
   deadline. `5.9-AdaptiveSelection.md` had the same symptom and is fixed — a
   200-dimension example running to the default 1,000 iterations, where a numerical
   gradient costs 400 objective calls a step. 5.10's cause is *not* its optimisation
   budget: the hang survives reducing every executed run to 6 starts and 200 iterations,
   so it is neither the work nor compilation (the deadline guards the linked executable,
   not the build). Unresolved and recorded rather than guessed at.

The test figure is measured. A `--bootstrap --check status` run estimates 7,818 by counting
test-shaped declarations; that heuristic is not the number of tests and should not be quoted.

### Known Issues

The honest list. Sources: `project/plans/TrustPlan.md`, and the gate's own output.

**In the gate**

The gate is at **0 errors, 0 warnings across 37 checkers**. What follows is not currently firing.

- **A cached run executes 10 of 37 checkers and prints the same summary line.** Measured. Only
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
- **~~`.timeLimit` traits sized against a test's runtime~~ — fixed 2026-08-13, `22d22a0`.** All 46
  `.timeLimit(.minutes(2))` sites now use `testHangGuard` (20 minutes). Recorded because the
  mechanism generalises: Swift Testing measures **elapsed wall clock per test, not work
  performed**, and tests run concurrently, so an `async` test that awaits is descheduled while
  others hold the cores and its clock keeps running. Tests reporting ~25s in a full run take
  **0.014s alone**. The binding number was therefore never any test's runtime — it was the whole
  suite's, because a test that starts early and awaits spans the entire run. Under
  `--sanitize thread` this suite takes ~347s against ~29s, and the 120s limit sat below that;
  `fiftyDMUsModerateScale` failed at 281s elapsed for 33ms of work. A limit tuned near observed
  runtime will fire for a busy machine long before it fires for a hang.

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

- **The `///` doc-comment corpus is checked now, and failing.** `doc-comment-code` landed (opt-in,
  not in the default run) and reports **852 errors**, down from 1,515. It compiles every ```swift
  fence in isolation against Foundation and this module only. The corpus is *upstream* of the
  catalogue — `RiskMetrics.swift` documented an initialiser that does not exist, and article `4.3`
  carried the identical error because it was copied out of Quick Help. **This is the tag gate.**
  Remaining shape: ~445 undefined references, the rest compile failures; the head of the tail is
  `builder` (29), `model` (26), `optimizer` (21), `result` (11), each needing a per-file
  constructor rather than a shared fixture. 33 fences contain literal `...` elision and cannot
  compile as written.
- **Published outputs are executed now.** `doc-run` (rung 2) and `doc-claims` (rung 3) both
  landed. `doc-claims` reports **8 errors**, all in `1.2-TimeSeries.md` — documented figures that
  disagree with what the code produces (`2025.0 ± 0.5` against `2026.0`; `1.0 ± 0.5` against
  `4.0`). Each needs deciding which side is wrong before either is edited; the checker cannot tell
  a numerical improvement from a regression, and editing the comment to match output is the repair
  that always works and sometimes means nothing. `4.1`'s headline figure was wrong because the code
  indexed the one-year array under a two-year label; that article is seeded end to end with all 170
  figures regenerated, and two-year growth reads 113.5%.
- **`doc-generated` landed and passes** — 0 regions found, 10 generators unused. It is not
  currently doing anything for this codebase.
- **`doc-symbol-link` has not landed.** The fourth of the four; still outstanding in
  quality-gate-swift.
- **One line in `4.1` cannot be made deterministic.** `Compute time` comes from
  `Date().timeIntervalSince(start)`. Named in the article rather than hidden, and it is the case
  `doc-claims` has to handle gracefully.

---

## Current Priorities

**2.6.0 is written and deliberately unshipped**, and the reason has narrowed. The checkers have
largely landed; what remains is clearing this codebase under them. The original reasoning still
holds: the work that produced this release found defects in documentation nothing was checking — a
runtime trap in `4.2` inherited from `ScenarioRunner`'s own `///` comments, two published figures
that were simply wrong, and a headline percentage computed off the wrong array. Shipping before the
codebase is clean means shipping whatever else is in that class.

Until then the CHANGELOG heading reads `[2.6.0] — unreleased` and the README advertises `2.5.2`.
Both revert at tag time. `release-readiness` passes on that basis.

1. **~~Land the four `doc-*` checkers~~ — 3 of 4 done.** `doc-comment-code`, `doc-generated` and
   `doc-claims` have landed, joining `doc-run`. **`doc-symbol-link` is still outstanding.** The
   ordering argument held up: `doc-comment-code` is upstream, and repairing the catalogue while
   Quick Help still hands out the wrong signature would have let the drift return.
2. **Clear this codebase under them. This is the gate on the tag.**
   - `doc-comment-code`: **420 non-macro**, from 1,515. The live work, and the only thing
     left gating the tag. No cluster remains — 163 files, worst holds 7 — so it is per-file
     reading from here. Method and traps are in `HANDOFF.md`.
   - `doc-claims`: **0** — cleared 2026-08-13. Three causes: one miscalculated figure, four
     claims reading their input from the clock, one over-precise tolerance.
   - `doc-generated`: clean.
   - 51 further `doc-comment-code` errors are in `Sources/BusinessMathMacros/` and are not
     author-fixable: the checker compiles those fences without the macro plugin. Proposal
     filed in the quality-gate repo; being handled separately.
3. **Cut 2.6.0** — tag, revert the two version strings. Nothing is unpushed; `main` and
   `origin/main` agree at 96 commits past `v2.5.2`.
4. **Differential testing against published references** (TrustPlan §2.2) — still the highest
   ratio of defects-found to effort in the plan. It is how the discontinuous `inverseNormalCDF`,
   the `normalCDF` lower tail and the Black-Scholes negative prices were all found. Remaining
   targets: the distribution family, `irr`/`npv`/`xirr`, the greeks.
5. **Split the three timed correctness tests**, so a wall clock stops gating a claim about the
   library. Still open — `22d22a0` fixed the `.timeLimit` *traits*, which is a different
   instrument from the `#expect(elapsed < N)` assertions inside those three.
6. **`v3.0.0` scope**, at `project/plans/upcoming/v3.0.0_SCOPE.md`. `DifferentialEvolution` and
   `ParticleSwarmOptimization` cannot refuse a seeded CPU fallback because `optimizeDetailed` is
   non-throwing; fixing that is source-breaking and forces a major, so the major should carry the
   rest of the breaking work with it. Three open questions in §4.

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
- [x] `doc-claims` (rung 3): compare printed output against the documented claims. Landed;
      **8 errors outstanding**, all in `1.2-TimeSeries.md`. **No `--fix`, ever** — an autofixer
      that rewrites a documented number to match the program launders regressions into
      documentation, and this release produced the case that proves it. The shipped checker
      states this in its own diagnostic: *"editing the comment to match the output is the one
      repair that always works and sometimes means nothing."*
- [x] `doc-comment-code`: the `///` corpus, upstream of the catalogue. Landed as opt-in;
      **852 errors outstanding**, from 1,515. This is the gate on the 2.6.0 tag.
- [x] `doc-generated`: landed, passes — 0 regions found, 10 generators unused.
- [ ] `doc-symbol-link`: the last of the four, still outstanding in quality-gate-swift.

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

## A recurring shape

Recorded here rather than in a session summary, because it has now produced defects in three
unrelated subsystems and will produce more.

**A check that appears to assert a property of the code, while actually measuring the
environment.** Each of these passed for months, then failed when the environment moved — never
when the code did:

| the check | appeared to assert | actually measured |
|---|---|---|
| `.timeLimit(.minutes(2))` | this test is not pathologically slow | how busy the runner is |
| `seed: 42` on the optimizer, `seed: nil` on its scenarios | this optimization is reproducible | one draw from an unseeded stream |
| GPU path with silent CPU fallback | this seed reproduces | whether the GPU happened to succeed |
| a cached `quality-gate` run | 37 checkers pass | 10 checkers pass |
| `grep -c '❌ error:'` on a failed invocation | zero errors | the command did not run |

The tell is the same every time: the failing and passing runs are **byte-identical in the code
under test**. When that is true, no property of that code can be the cause, and the search should
start at the instrument.

This is the same family as the 2026-08-11 table of checkers reporting honestly on an input
narrower than anyone believed (build checker never compiling the test target; the diagnostic
parser never matching a coloured line; `stochastic-determinism` skipping test files entirely).
The earlier table was about *scope*; this one is about *what is being measured*.

---

**Last Updated:** 2026-08-15 — reconciled against the tree after the doc-comment-code pass reached 0
and the gate. `doc-comment-code` 852 → **420 non-macro**, and `doc-claims` 8 → **0**, so the
tag now waits on one number rather than two. Tests 6,582 → 6,597; commits since `v2.5.2`
96 → 122. Added: the `gpu-safety` checker is live and its findings against
`.claude/worktrees/` are stale copies rather than live defects; the 51 macro errors are
recorded as not author-fixable so they are not counted against the gate. The method for the
remaining 420, and the traps that cost round trips, are in `HANDOFF.md` rather than here —
they are resume notes, not plan.

**Previously, 2026-08-13 (morning):** — reconciled against the tree and against CI, not against the
previous revision. Counts corrected throughout: 6,520→**6,582** tests in 579 suites, 36→**37**
checkers, 6,471→**6,508** documented APIs, and "64 commits unpushed"→**0** (96 past `v2.5.2`,
all pushed). Closed as done: three of the four `doc-*` checkers landed (`doc-comment-code`,
`doc-claims`, `doc-generated`), so Priority 1 and three Phase 3 items are struck; the `.timeLimit`
sizing defect (`22d22a0`). Added: `doc-comment-code` at 852 and `doc-claims` at 8 as the concrete
tag gate, `doc-symbol-link` as the one checker still outstanding, the v3.0.0 scope as Priority 6,
CI and nightly status rows, and "A recurring shape" above. Corrected: the documentation section
claimed `doc-comment-code` "does not exist yet" and `doc-claims` was "in build"; both shipped.
