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

**2.10.0 shipped 2026-09-04** — a distribution can say what value sits at a given uniform, and a
simulation can choose where its sample points go. Those turned out to be one requirement rather
than two: a stratified or low-discrepancy point set hands each input a coordinate and asks what
value is there, which only an inverse transform answers.

`ContinuousDistribution` and `DiscreteDistribution` add `cdf` and `quantile`; `SamplingMethod`
adds Latin hypercube, Sobol and Halton, with Sobol matching `scipy.stats.qmc` against a committed
fixture. All fifteen existing distributions were retrofitted, and doing so found four numerical
defects — three distributions and the shipped `exponentialCDF` all lost their lower tail to
`1 - exp(-y)`, which keeps no digits when `y` is small.

This is **Phase 0 of the Excel/Risk Solver coverage work**: 42 of the 49 items on
`project/plans/proposals/excel-coverage/businessmath_work.tsv` were blocked on the contract
existing. See `project/checklists/CURRENT_ExcelCoverage_Phase0.md`.

A standing rule came out of it and is recorded as ADR-005: constants are derived where they can
be derived and deleted where they cannot. Both special-function inverses opened with fitted
initial estimates carrying nine decimal coefficients between them; the estimates only seeded a
bracketed root-finder, so they were removed in favour of starting from the distribution's mean,
and all 344 SciPy reference cases still pass.

**2.9.0 shipped 2026-09-03** — a model can be written in a vocabulary that says what its numbers
mean, and the compiler checks it. `revenue * margin` compiles, `revenue + margin` does not, and
`revenu` is not a variable that exists. A typed model **is** a `ModelDefinition`: same engine,
same numbers, a spelling rather than a second implementation.

`validateUnits()` adds the checks a compiler cannot make because they depend on the model — one
name meaning two things, a rate with no period basis, and an annual rate applied to a monthly
timeline. That last is what the layer is worth building for: off by twelve, evaluating without
complaint, entirely plausible in a report.

The compile-time budget §15 Q5 left open was measured before any of it was written, and passes
with a wide margin: nothing in the worked example or a twenty-term stress file exceeds 10 ms to
type-check. Three name collisions were found by compiling — `Account`, `Duration`, and `Unit`,
the last belonging to Foundation and invisible from inside the module.

**2.8.0 shipped 2026-09-01** — the formula grammar gained functions, and a balance can move
between periods. Together those close the gap that made a cash sweep inexpressible as
configuration: a debt paydown whose interest depends on the repayment that depends on the
interest.

Seventeen function names are registered, each binding to a canonical implementation rather than
a second one written inside the evaluator, and where Excel's definition differs from the
textbook's the grammar means Excel's — `NPV` to `npvExcel`, `PMT` negative for money leaving,
`STDEV` and `STDEVP` by their denominators. Each is pinned by a test asserting the *difference*.

`PeriodDriver` and `Rollforward` make the caller's loop reusable, keeping within-period cycles
with the solver and cross-period carry separate from them. Year-one interest on a 120 draw at
10% is 11.75 — the average-balance figure, requiring a cyclic solve, where beginning-balance
accrual gives 12.00 with no cycle at all.

The waterfall types migrated into `Financial Statements/Waterfall/` with `Sendable` conformance
and throwing initializers, ahead of `BusinessMathDSL`'s removal in 3.0.0.

One defect fixed that had been latent: `accountNames(in:)` walked tokens, so a function name was
counted as a required account. It was correct before functions existed and silently wrong the
moment they did.

Additive throughout — no signature changes, nothing removed. 6,716 tests in 592 suites.
Scope and decisions: `plans/proposals/TypedModelAuthoring.md`, phases 1 and 2a–2e.

**2.7.0 shipped 2026-09-01** — tagged `v2.7.0` on the release commit, 33 commits of code
past `v2.6.0`. The last code change is `44d3774`; the release commit itself is documentation
only, so the tagged tree compiles identically to the state the tests and sibling builds below
were measured against.
Additive by construction: `Statistics/Experiment/` (two-arm design and power analysis),
`Sendable` completed on nine distribution types, and deprecations on the two `AB Test.swift`
defects. No signature changes. `plans/completed/v2.7.0_SCOPE.md` is the release's scope
document, and every item in it shipped.

Its one pre-tag open question — *do the sibling packages break on the deprecation?* — was
answered before tagging: `BusinessMathPro` (local path dependency, so it compiles this
working tree) and `businessMathMCP` (resolved at `44d37741`) both build clean with zero
deprecation warnings. Neither still calls the deprecated functions. That result holds for
consumers built with warnings-as-warnings; `v3.0.0_SCOPE.md` §230 correctly notes a
warnings-as-errors consumer must migrate first.

**2.6.0 shipped 2026-08-15** — tagged `v2.6.0` at `c6e44a7`, 159 commits past `v2.5.2`,
CI green on the tagged commit.

| | |
|---|---|
| tests | **6,632 in 585 suites**, 0 known issues, ~30s (measured 2026-09-01 at `44d3774`) |
| build | **0 warnings**, library and test target |
| quality gate | **0 errors, 0 warnings**, verified against the installed binary |
| CI | green — 4/4 jobs, including `Linux release compile check` |
| gate, worktrees | excluded via `excludePatterns`, honoured — the `gpu-safety` fix landed in quality-gate `4470dfa` and is installed |
| nightly (Release Tests) | green — Ubuntu release, macOS release, and Thread Sanitizer |
| documentation coverage | 100% — 6,504 of 6,504 public APIs |
| DocC catalogue | **73 articles**, all compiling as one program under `quality-gate --check doc-code` |
| `doc-comment-code` | **0 errors** — macro modules included. The tag gate is cleared. |
| `doc-claims` | **0 errors** — cleared 2026-08-13 |
| `doc-run` | **0 errors** — 73 of 73 articles run cleanly and reproducibly |
| `quality-gate --check all` | **0 errors, 0 warnings** across **43 of 43** checkers |
| toolchain | `swift-tools-version: 6.2`, Swift 6 strict concurrency |

**Outstanding before the tag — all cleared; kept for the record.** None was a code defect.
A fifth item surfaced *after* the tag and is the live one: the quality gate has never run on
GitHub CI, because a public repository cannot resolve the reusable workflow in the private
`quality-gate-swift`. Four public repos are affected and have been dead since June. The
decision between publishing that repo and inlining its clone-and-build steps is recorded in
`HANDOFF.md`; until it is made, "CI green" in this document means build, test, lint and the
Linux compile check, and **not** the gate.

1. ~~**The `gpu-safety` exclusion fix is staged in quality-gate, uncommitted and not
   installed.** Until it lands, the installed binary reports 53 errors from stale copies
   under `.claude/worktrees/`, and a release verified on this machine today looks red. The
   0/0 above is from a local build carrying that fix.~~ **Landed** in quality-gate
   `4470dfa` and installed. Verified against the installed binary: **43 of 43 checkers,
   0 errors, 0 warnings.** Note that this entry was written while the fix was staged and
   was still asserting it *after* the commit and install — the claim was carried forward
   rather than re-checked. Cost of the check: one `git status`.
2. ~~**`--check all` runs 42 checkers; the default run is 35.** The seven it omits are
   opt-in by convention or by cost, which is a defensible default — but this project's
   config asked for all of them through a key the schema does not have (`checkers:`
   rather than `enabledCheckers:`), and unknown keys are discarded silently. That is how
   `recursion` came never to run, and how a crashable parser reached a release candidate.~~
   **Fixed upstream, both halves.** An unknown key is now a **startup refusal** rather
   than a silent discard — the gate declines to run against a configuration it cannot
   fully read, on the reasoning that a 35-checker run and a 42-checker run otherwise print
   an identical `PASSED`. And the summary now states its roster (`43 of 43 checkers`), so
   the count is visible without inspecting the config. Three of the four proposals filed
   from this release are implemented; `UnboundedRecursionIsAnError` remains proposed,
   pending its advisory window.
3. ~~Commits not yet on `origin`.~~ **Pushed.** `main` and `origin/main` agree.
4. **`doc-run`'s 30-second deadline is wall-clock, and the checker pool is concurrent.**
   `2.5-ModelValidationGuide.md` runs in **5.7 seconds** on its own and was killed at the
   deadline during a `--check all` run — the same invocation in which `doc-run` itself took
   121s rather than its usual 43s. Nothing is wrong with the article. A gate that fails on
   contention rather than on content is the flake that teaches people to re-run rather than
   read, so this is worth a fix upstream: measure CPU time, or give the runner a share of
   the pool rather than competing with 42 other checkers for it. Filed alongside the other
   quality-gate proposals.
4. ~~`5.10-ParallelOptimization.md` hangs under `doc-run`.~~ **Resolved.** Both articles
   run, and all 73 in the catalogue now run cleanly and reproducibly. The hang was an
   arithmetic explosion rather than a loop — `ParallelOptimizer` forwards `maxIterations`
   to the constrained algorithms as their *outer* count, and each outer step runs an inner
   BFGS solve of up to 1,000 iterations. Chasing it also found that `VectorN.zero`
   annihilated the vector it was added to, which was giving `5.4-VectorOperations.md` a
   different answer on every run.

The test figure is measured. A `--bootstrap --check status` run estimates 7,818 by counting
test-shaped declarations; that heuristic is not the number of tests and should not be quoted.

### Known Issues

The honest list. Sources: `project/plans/TrustPlan.md`, and the gate's own output.

**In the gate**

The gate is at **0 errors, 0 warnings across 44 of 45 checkers** (2026-08-24). What follows is
not currently firing.

- **Nothing was running the gate between June and August 2026.** This repository had no
  pre-commit hook, and CI could not supply one: `.github/workflows/quality-gate.yml` failed at
  startup in 0 seconds on every scheduled run, because BusinessMath is public and
  `jpurnell/quality-gate-swift` is private, so a public repo cannot call its reusable workflow.
  The count had reached **1,187 blocking findings** before anyone looked. The hook is installed
  now; **CI is still dead**, and stays that way until `quality-gate` is published somewhere a
  public repo can reach — the `swift-vigil` release-tarball-plus-Homebrew-tap pattern already
  works in this ecosystem.
- **`--exclude test` excludes the test *runner*, not test *files*.** The command in the project
  guidelines skips executing the suite, which is what it is for, but `safety` still scans
  `Tests/`. The suite's 1,111 force unwraps were in scope the whole time; the flag's name is
  what hid them.

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

**2.6.0 shipped 2026-08-15**, after being written and deliberately held. The hold was never about
the code: the work that produced this release found defects in documentation nothing was checking —
a runtime trap in `4.2` inherited from `ScenarioRunner`'s own `///` comments, two published figures
that were simply wrong, and a headline percentage computed off the wrong array. Shipping before the
codebase was clean would have meant shipping whatever else was in that class. The bar was clearing
this codebase under the new checkers, and it was met: `doc-comment-code` went 1,515 → **0** with no
`docs:illustrative` marker added to any `///` fence, and `--check all` passes **43 of 43**.

The CHANGELOG heading and the README's `from:` pin both moved to `2.6.0` in the release commit.

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

### Phase 0 of Excel coverage — the distribution contract (done, 2.10.0)

- [x] Promote `regularizedLowerIncompleteGamma` out of `private`, and write the two
      special-function inverses that eight-plus distributions need — Gamma, Erlang, Chi-squared,
      Beta, F, Pearson V, Pearson VI, Johnson
- [x] `ContinuousDistribution` / `DiscreteDistribution`, with inverse-transform sampling supplied
- [x] Retrofit all fifteen existing distributions and verify them through one shared battery
- [x] Latin hypercube, Sobol (Joe & Kuo, vendored), Halton, Owen scrambling, Vose alias table
- [x] The `MonteCarloSimulation` seam, refusing rather than downgrading when an input has no
      quantile
- [x] Reference-fixture harness against SciPy, committed and version-pinned (ADR-004)
- [ ] **Next: the Excel financial ten** — `RATE`, `NPER`, `PDURATION`, `NOMINAL`, `SLN`, `DDB`,
      `SYD`, `VDB`, `ACCRINT`, plus the two `DayCountConvention` cases they need. Independent of
      the distribution work; measured as the higher priority after SwiftExcelFunctions found all
      3,425 corpus `YEARFRAC` calls use the default basis, which BusinessMath already covers.
- [ ] Then the 33 distributions and the AR/GARCH family, which now have a contract to be written
      against

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

**Last Updated:** 2026-09-04 — reconciled for the 2.10.0 release: Current Status leads with the
distribution contract and quasi-random sampling, the Roadmap gains a Phase 0 section for the Excel
coverage work with the financial ten named as next, and five ADRs (001–005) were written into
`project/decisions/architecture_decisions.md`, which had no entries before. `4.6-QuasiRandomSamplingGuide.md`
is written and indexed in `Part4-Simulation.md`. README's "Latest release" was three versions
stale at 2.7.0 and now reads 2.10.0. Counts refreshed to 6,818 tests / 602 suites.

**Previously:** 2026-09-03 — reconciled for the 2.9.0 release: Current Status leads with the typed authoring layer and `validateUnits()`, `project/capability_map.md` gains a Typed Model Authoring section, and `1.10-TypedModelAuthoring.md` is written and indexed. Recorded that Phase 3's compile-time gate was measured and passed, and that three name collisions were found by compiling rather than by review. Counts refreshed to 6760 tests.
