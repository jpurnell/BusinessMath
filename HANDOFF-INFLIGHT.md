# Handoff — work in flight, 2026-08-11

**Read this before `HANDOFF.md`.** That file describes the last committed state and is accurate.
This one describes 17 uncommitted files that three agents were mid-way through when the session
hit its limit. Nothing here is verified. Nothing here should be trusted until it is.

---

## The state in one line

`main` at `9a6c73b`, **one commit unpushed**, **17 files dirty** — 10 modified sources
(+716 / −101) and 7 new test files, one per defect. `swift build` was still running when the
session ended, so **it is not known whether this tree compiles.**

## First action on resume

```sh
swift build --build-tests     # does it even compile? nothing below matters until it does
swift test                    # baseline was 6,520 in 567 suites, exit 0
```

If it does not build, the fastest route is `git stash` the lot, confirm `9a6c73b` is green, then
reapply and fix incrementally. **`9a6c73b` is a known-good commit**: 6,520 tests, gate 0 errors /
0 warnings across 37 checkers, `doc-code` clean, `doc-run` at 71 of 73 articles clean.

---

## What the three agents were doing

Six library defects, all found by *executing documentation* rather than by testing the library.
Each agent wrote its red test first, so the untracked test files are the specification.

### Agent 1 — `InequalityOptimizer` (the one that matters)

`Optimization/Algorithms/InequalityOptimizer.swift` (+227 / −59), test
`InequalityOptimizerScaleInvarianceTests.swift`.

**The optimizer returns different answers depending on the units the problem is written in.**

```
written in dollars:   a = 0.833, b = 0.750
written in millions:  a = 1.000, b = 0.500   ← the true optimum
```

Cause: the outer loop grows the penalty tenfold per iteration (`rho = rho * penaltyIncrease`,
line ~215) while handing the inner BFGS a **fixed absolute** `gradientTolerance` of 1e-6. The
augmented Lagrangian's gradient scales with ρ, so the target becomes unreachable by construction
and the inner solve burns its full 1,000-iteration budget on every one of 100 outer iterations.

This is the same defect this release *opened* with. See `817ea6f` — simplex feasibility depended
on the units the model was written in, because an absolute 1e-10 met a residual carrying the
magnitude of the data. That commit's reasoning applies unchanged, and `753f79b` is the companion
argument for fixing conditioning at the source rather than widening a constant.

It also caused three article hangs (`5.7`, `5.13`, `5.14`), which were worked around by shrinking
the examples. `ArticleRestorationProbe.swift` was written to test whether they can be restored.

### Agent 2 — the two seeding defects

`MetalBuffers.swift` (+27 / −7), `ParallelOptimizer.swift` (+47 / −4), `GeneticAlgorithm.swift`
(+12 / −1). Tests `GeneticAlgorithmSeedDeterminismTests.swift`, `ParallelOptimizerSeedTests.swift`.

**`GeneticAlgorithmConfig.seed` is silently inert once the GPU path engages.**
`MetalBuffers.swift:105` filled GPU RNG state from `UInt32.random(in:)` rather than the caller's
generator — so a seeded run reproduces at `populationSize: 999` and does not at 1000. Same API,
same seed, no error. `DifferentialEvolution.swift:586` does the same job correctly and is the
model. The offending line carried a bare `// stochastic:exempt`, which is what kept the
determinism auditor quiet over the exact line that defeats it.

**`ParallelOptimizer` has no seed at all** — zero occurrences of `seed` or `using:`. It draws
starting points from `Double.random(in: 0...1)` and offers no way to influence them. This is why
`5.10-ParallelOptimization` cannot be made deterministic from the article, and in one gate run
the unseeded starts produced `OptimizationError.nonFiniteValue` — they do not merely vary, they
intermittently kill it.

**The GPU test must cross the threshold**: reproducibility at 999 *and* at 1000+. A CPU-only test
passes before the fix, which is how this shipped.

### Agent 3 — three correctness defects (**killed by the session limit, least complete**)

`NonlinearRegression.swift` (+247 / −15), `BalanceSheet.swift` (+67 / −6), `ResourceAllocation.swift`
(+32 / −4), plus `ModelValidation`, `DebtCovenants`, `FinancialPeriodSummary` as call sites.
Tests `ReciprocalRegressionScaleTests.swift`, `BalanceSheetUndefinedRatioTests.swift`,
`WeightedValueObjectiveTests.swift`.

1. **`ReciprocalRegressionFitter.fit` reports `converged: true` while diverging.** It descends a
   *summed* log-likelihood at fixed `learningRate`, so the gradient grows with *n* and the step
   does not. At N = 500 it diverges by 10¹¹ and still claims success. Two agents reached this
   independently from different articles.
2. **`maximizeWeightedValue(strategicWeight:)` adds unnormalised dollars to a 0–10 score**, so the
   weight means nothing without the caller pre-scaling.
3. **`BalanceSheet` ratios return `+infinity`** on zero current liabilities, which then breaks
   `Codable`. Same class as `0330fc2` / `afcedee` (`MarketplaceModel`), where the decision was that
   zero makes the *downstream arithmetic* correct rather than merely finite — but verify that holds
   here, since a current ratio with no current liabilities may mean something different.

---

## Still open, beyond the six

- **`doc-run`: 3 of 73 articles.** `5.1-OptimizationGuide` hangs past 30s. `5.10` unblocks when
  Agent 2 lands. `5.4-VectorOperations` (12 of 145 lines differ) belonged to no work stream and
  has never been looked at.
- **`5.9-AdaptiveSelection` runs 25.7s against a 30s deadline.** Passes today; `doc-run` executes
  articles concurrently, so it will flake under load.
- **Workarounds to revert** once the library is fixed: `5.16` drops to `populationSize: 800` to
  dodge the GPU seed bug; `4.2` and `Part4-Simulation` hand-roll seeded loops instead of the
  convenience APIs.
- **Three seedless wrappers over seeded primitives**: `ScenarioAnalysis`, `runFinancialSimulation`,
  `ReciprocalParameterRecoveryCheck.run`.
- **The tag is still deliberately held** — see `HANDOFF.md`, "Why the tag is held". `doc-comment-code`,
  `doc-symbol-link` and `doc-generated` must land and clear this codebase first. The CHANGELOG
  heading reads `[2.6.0] — unreleased` and the README advertises `2.5.2`; both revert at tag time.

## Two checker bugs found here, unfixed in quality-gate-swift

- `release-readiness` reads a version out of any heading containing a number — "…accurate to
  ~1.5e-7" was reported as a missing `v1.5` tag.
- A cached `quality-gate` run executes **10 of 37 checkers** and prints the same summary line.
  **Always use `--no-cache`.** Every figure in these handoffs came from one.

---

## Why this session ran long, honestly

The release was ready many hours ago by the standard in force at the time. It kept not shipping
because each tool we fixed revealed a backlog that had accumulated behind it:

| the checker | reported | was actually |
|---|---|---|
| build checker | library compiles | never compiled the test target |
| diagnostic parser | parses diagnostics | never matched a coloured line — so *no* compiler diagnostic, ever |
| `stochastic-determinism` | tests audited | skipped test files entirely |
| cached gate run | PASSED | 10 of 37 checkers |
| `doc-code` | 73 articles clean | discarded every error it could not attach to a line |
| `doc-code` (rung 1 only) | articles compile | 32 of them crashed, hung, or changed every run |

Each row is one tool honestly reporting on an input narrower than anyone believed. The defects
were already in the library; the day's work was making them visible, then fixing what appeared.
That is why the count kept growing rather than shrinking — and why stopping early would have
shipped them.

**Last verified good state: `9a6c73b`.** Everything above that line is unverified.
