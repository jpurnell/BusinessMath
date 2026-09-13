# BusinessMath heuristic optimizer and async tests

*September 2026. Covers 12 files: GPUAttemptTests, HeuristicGPUSeedDeterminismTests, GeneticAlgorithmSeedDeterminismTests, GeneticAlgorithmTests, DifferentialEvolutionTests, ParticleSwarmOptimizationTests, SimulatedAnnealingTests, IslandModelTests, NelderMeadTests, LBFGSOptimizerTests, ConjugateGradientOptimizerTests, AdaptiveProgressTests. Companion to the eighteen preceding domain reviews, and a direct follow-on to the optimization review.*

## 1. Summary

**`GPUAttemptTests` is the best example in the corpus of making an untestable defect testable.** Its header states the problem exactly:

> "The defect this guards against needed a Metal command queue to refuse a command buffer under resource pressure — not something a test can summon on demand, which is why it survived as an occasional red suite rather than a reproducible failure."

The fix is not a better GPU test. It is extracting the hazard into a seam: `attemptGPU(seeded:body:)` takes a closure, so a `body` that draws from the generator and then returns nil reproduces the exact failure in microseconds with no GPU involved. The file then pins all four quadrants — abandoned rewinds, throwing rewinds and reports, completed does *not* rewind, and the seeded-versus-unseeded promise — plus the resolution logic in a second suite, "independently of any optimizer and of any GPU."

The closing observation is the one worth carrying forward: the original bug existed in three optimizers, and `GeneticAlgorithm` "wrote that answer inline, which is how the rule failed to travel the first time." That is the third independent instance in this corpus of duplication carrying a defect (the others being `valuePerShare` and the projection correction in the LME fitters).

**`HeuristicGPUSeedDeterminismTests` closes two gaps I had left open in the simulation review.** First, it crosses the GPU threshold deliberately — 999, 1000, 1200 — with the reasoning that "a determinism test that only runs a small population tests the CPU implementation and reports on the API." Second, and more important, `gpuPathIsReachable` asserts the precondition:

> "Every 'at the threshold' test below is a CPU test on a machine whose Metal device declines the work, and would pass without exercising anything it claims to. Assert the precondition once, so that machine fails loudly here instead of quietly there."

That is precisely the non-vacuity guard the simulation review recommended for the GPU suite, implemented. The file also notes that an earlier fix "made the 1000 case pass by declining the GPU whenever a seed was set, which is determinism bought by giving up the acceleration" — a fix that satisfied the test by removing the behaviour under test, caught and reversed.

Both determinism files use `!identical` plus an `isFinite` guard for divergence, with the reasoning written out: "`!=` reports a NaN as different from itself, so this assertion would pass for free if either stream went non-finite." That is the FloatingPointClaims vocabulary applied correctly, unprompted.

**Against that, the five heuristic optimizer files and the three local-optimizer files are the older generation**, asserting distance-to-known-minimum at unmotivated tolerances — the same finding as the optimization review, in the same code area.

### Templates to copy

| Kind of test | Copy from |
|---|---|
| A defect that needs hardware conditions to reproduce | GPUAttemptTests (extract the hazard into a closure seam) |
| Any GPU-thresholded behaviour | HeuristicGPUSeedDeterminismTests (999/1000/1200 + reachability guard) |
| Seed reproducibility and divergence | GeneticAlgorithmSeedDeterminismTests (`identical` / `!identical` + `isFinite`) |
| Deterministic scheduling logic | AdaptiveProgressTests (exact report schedule) |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`result.converged \|\| result.iterations == 500`** | NelderMeadTests, twice (also `== 300`). The disjunction passes when the optimizer exhausts its budget without converging — which is the failure the `converged` flag exists to report. | Assert `converged`, or if non-convergence is acceptable for that problem, assert the objective value reached and say why in a comment. As written the test cannot distinguish success from budget exhaustion. |
| 2 | **The island topology tests do not distinguish topologies** | `Ring topology migration`, `Fully connected topology migration` and `Random topology migration` each assert `bestFitness < 1.0` and `generations > 0`, on the same objective with the same population. An implementation that ignored `topology` entirely passes all three. | The observable difference is migration connectivity. With a `CountingRNG`-style instrument or a migration log, ring should move individuals between adjacent islands only, fully-connected between all pairs, and the counts differ. That is checkable without a fitness claim — and it is the same instrumentation technique `MergeLeakRepro` and `CoxProcessSimulationTests` use. |
| 3 | **`stochasticMigrationTopology` is live** | Used in `Random topology migration`. This is the helper from `DeterministicHelpers` whose only purpose, per its own header, was to keep a `.random` token out of files the quality gate scans — and whose enum case is `.stochastic`, so there is no token to hide. | Delete the helper and write `.stochastic` at the call site. This confirms the finding from the TestSupport review: the escape hatch is in use, so removing it requires touching this file. |
| 4 | **Redundant assertion pairs** | `#expect(result.iterations < 1000)` immediately followed by `#expect(result.iterations < 100)` in both LBFGSOptimizerTests and ConjugateGradientOptimizerTests. The first is implied by the second. | Delete the weaker one. Harmless, but it inflates the assertion count and suggests the bound was tightened without removing the original. |
| 5 | **`first.conjugateDirection != 0.0 \|\| first.iteration == 1`** | ConjugateGradientOptimizerTests:215. `!=` on a `Double`, inside a disjunction whose second term makes the first optional. | The claim appears to be that the conjugate direction is non-zero except on the first iteration, where beta is zero by definition. Split it: assert `identical(betaValues[0], 0.0)` for the first iteration (which the file already does at line 247, at 1e-6 where exact is available) and a non-trivial direction thereafter. |
| 6 | **Iteration-count assertions in correctness tests** | `#expect(result.iterations < 50)` in LBFGSOptimizerTests, `< 100` in both local-optimizer files. These are performance claims in correctness tests, and the bounds are not derived. | Same recommendation as the optimization review: move to `.benchmarkOnly` if the point is speed, or assert the convergence-rate property if the point is algorithmic — for L-BFGS on a quadratic, convergence in at most n iterations with exact line search is a theorem, not a budget. |
| 7 | **Config field-storage tests** | IslandModelTests opens with twelve assertions that a config returned the values it was constructed with (`numberOfIslands == 4`, `migrationInterval == 10`, and so on), then a third test asserting `numberOfIslands >= 4` and `migrationInterval > 0` for a preset. | The preset test is the useful one, and it should assert the preset's actual values rather than bounds. The first two are the field-storage pattern; ~25 more sites across this batch. |
| 8 | **`gradientNorm < 0.1` is the right assertion at the wrong tolerance** | LBFGSOptimizerTests and ConjugateGradientOptimizerTests each assert `gradientNorm < 0.1` once. That is the optimality certificate the optimization review recommends — but 0.1 is loose for a converged run on a smooth problem, where the gradient norm should reach the configured tolerance. | Assert against the optimizer's own convergence tolerance. Then promote this from an incidental check on the metrics history to the primary assertion for every smooth problem in both files, replacing the `abs(solution[0] - x) < 0.1` distance checks. |

## 3. What the strong files establish

### 3.1 Extracting a hazard into a seam

`GPUAttemptTests` generalises beyond GPUs. The pattern is:

1. A defect requires a condition the test cannot create (resource pressure, a device refusal, a network failure, a disk-full error).
2. The code path that handles that condition is separable from the condition itself.
3. Extract the handler so it takes the outcome as an input, then test the handler exhaustively.

The corpus has other candidates. The simulation review's GPU-versus-CPU error-behaviour question (`#2 item 6` there) is one: whether a model that divides by zero throws on the CPU path and returns infinities on the GPU is a question about the *dispatch and fallback logic*, not about Metal. The validation review's schema-migration failure paths are another.

Two details worth noting:

- **The rewind test uses a reference generator.** `expected` comes from a second `RNGWrapper` at the same seed, so the assertion is "the stream is where it started" rather than "the stream has some particular value." That survives a change to the generator.
- **`completedAttemptDoesNotRewind` is the half a naive fix would break.** Rewinding unconditionally would make the next generation replay the same seeds, and the comment says so. A test suite with only the abandonment cases would accept that regression.

### 3.2 The non-vacuity guard

`gpuPathIsReachable` is one assertion, and it converts every "at the threshold" test in the file from possibly-vacuous to load-bearing. The reasoning in the header is worth quoting because it names the failure mode precisely: without it, "the determinism tests would keep passing on the CPU while proving nothing about the path they are named for."

This should be applied to the GPU suites reviewed earlier. The simulation review found about 25 tests that guard with `guard MonteCarloGPUDevice() != nil else { return }`, which pass on Linux and on any Mac whose kernel fails to compile. `.requiresMetalGPU` plus `#require` reports a skip rather than a pass; a single reachability assertion in the suite makes the skip itself visible.

### 3.3 Deterministic logic tested deterministically

`AdaptiveProgressTests` is the quiet success of the batch. Progress reporting is scheduling logic, fully determined by its inputs, and the file tests it that way:

- The fixed-interval strategy reports at 0, 10, 20 and not at 5, 15.
- The doubling strategy reports at 0, 1, 3, 7 and not at 2, 4, 5, 6 — which pins the schedule exactly, since a doubling interval starting at 1 gives cumulative positions 0, 1, 3, 7, 15.
- Stagnation is asserted at one threshold and denied at a tighter one, which brackets the comparison rather than testing one side.
- Convergence and oscillation detection are asserted with their negations (`isOscillating` true and `hasConverged` false for the same history).

The one weak spot is `#expect(rate > 0.0)` for a convergence rate, and `earlyReports > 0 && lateReports > 0` — the adaptive strategy's whole point is that late reports are *fewer*, which is a ratio claim the test does not make.

## 4. The older generation

The five heuristic files (GA, DE, PSO, SA, Island) and three local-optimizer files (Nelder-Mead, L-BFGS, CG) share the pattern the optimization review documents: run on a known function, assert the solution is within some distance of the known minimum.

| Assertion shape | Instances |
|---|---|
| `abs(result.solution[i] - known) < 0.1` (or 0.2, 0.5, 1.0) | ~30 |
| `result.value < 0.1` (or 0.2, 1.0, 5.0, 50.0) | ~25 |
| `result.bestFitness < 1.0` | ~10 |
| `result.converged` | ~20 |

Two observations specific to this batch:

**Stochastic optimizers genuinely cannot promise a distance.** A genetic algorithm with 5 generations on a 2-D sphere will land somewhere; how close is a property of the seed. That makes the distance assertions here different from the L-BFGS ones — they are not loose versions of a tight claim, they are the wrong kind of claim. What a seeded heuristic *can* promise:

- **Reproducibility**, which the two determinism files now cover.
- **Monotone improvement**: the best fitness never worsens across generations, which is true by construction for an elitist algorithm and checkable from the history.
- **Improvement over the initial population**, which is the weakest honest claim and stronger than a fixed bound.
- **A distribution over seeds**: across 50 seeds, the median final fitness below some value, with the value measured rather than guessed. That is the multi-seed approach `DistributionRetrofitTests` uses for its χ² test, with a stated false-alarm rate.

**The local optimizers can promise the gradient.** Nelder-Mead is derivative-free so it needs a different certificate — the simplex diameter at termination, which is its actual convergence criterion. L-BFGS and CG both already compute `gradientNorm` (§2 item 8).

`ConjugateGradientOptimizerTests`' method comparison (`for method in ...` asserting each converges and `objectiveValue < 3.0`) is the right shape for a family of variants, and would be stronger with the gradient certificate applied per method.

## 5. Coverage gaps

- **Migration semantics** (§2 item 2), the island model's distinguishing feature.
- **Simulated annealing's acceptance criterion.** The Metropolis rule accepts a worse solution with probability exp(−Δ/T), which is checkable with a scripted generator: feed a known uniform and a known Δ, and assert the accept/reject decision. That is the algorithm's core and it is testable exactly.
- **Cooling schedule.** Whether temperature follows the configured schedule is deterministic and untested.
- **Differential evolution's mutation and crossover**, likewise: given a scripted generator and a fixed population, the trial vector is determined.
- **Nelder-Mead's operations.** Reflection, expansion, contraction and shrink each have exact formulae. A one-step test on a constructed simplex pins which operation fired and where the new vertex landed. `BoxMullerPoleGuardTests`' scripted-generator approach is the model.
- **The GPU attempt path for the third optimizer.** The header says the defect was in all three; the determinism file covers DE and PSO, and the GA has its own file. Worth confirming all three route through `attemptGPU` rather than two of them doing so.
- **`AdaptiveProgressTests`' adaptive ratio** (§3.3).

## 6. Recommended order of work

1. **Apply the reachability guard to the other GPU suites** (§3.2). One assertion per suite, and it converts ~25 possibly-vacuous tests in the simulation domain.
2. **Delete `stochasticMigrationTopology`** and write `.stochastic` at the call site (§2 item 3). This unblocks removing the helper from TestSupport.
3. **Fix the two `converged || iterations == N` disjunctions** (§2 item 1).
4. **Promote `gradientNorm` to the primary assertion** in the L-BFGS and CG files, at the optimizer's own tolerance (§2 item 8).
5. **Add scripted-generator tests** for the SA acceptance rule, the DE trial vector, and the Nelder-Mead operations (§5). These replace distance assertions with exact ones for the algorithms' cores.
6. **Replace the heuristic distance assertions** with reproducibility, monotone improvement, and a measured multi-seed distribution (§4).
7. **Make the island topology tests distinguish topologies** (§2 item 2).
8. **Clean up** the redundant pairs, the `!=` disjunction, and the config field-storage tests (§2 items 4, 5, 7).

## 7. Gate rules

No new rules, but two existing proposals gain their strongest supporting examples:

**Duplicated code carrying a defect (advisory → blocking for guard-bearing bodies).** This is the third independent instance: `GPUAttemptTests` states that `GeneticAlgorithm` wrote the resolution inline, "which is how the rule failed to travel the first time," and the defect was in three optimizers at once. Combined with `ValuePerShareGuardTests` ("the duplicate carried the defect with the code") and the LME projection correction, the case for treating a duplicated body that contains — or omits — a guard as a blocking finding is now well evidenced.

**The GPU-reachability guard as a required pattern.** Worth encoding in the fixture-coverage report: a suite whose tests are conditioned on hardware availability should contain one assertion that the hardware is available. That is checkable statically — a suite with `#if canImport(Metal)` or a `.requiresMetalGPU` trait and no assertion on `shouldUseGPU` or equivalent.

Existing rules that apply: the vacuous-disjunction rule (§2 items 1, 5), `!=` on floating point (§2 item 5), field-storage tests (§2 item 7), and the assertion-strength advisory for the ~65 distance and bound assertions in §4.

## Appendix. Verified values

### A.1 Adaptive progress schedules

| Strategy | Reports at | Does not report at |
|---|---|---|
| Fixed interval 10 | 0, 10, 20 | 5, 15 |
| Doubling from 1 | 0, 1, 3, 7, 15 | 2, 4, 5, 6 |

Cumulative positions for a doubling interval starting at 1: 0, 0+1, 1+2, 3+4, 7+8 → 0, 1, 3, 7, 15. The test's assertions match exactly.

### A.2 GPU threshold

`MetalDevice.shouldUseGPU(populationSize:)` engages at 1000. The determinism files test 999 (below), 1000 (at) and 1200 (above) — the three cases that matter for a threshold, with the boundary itself included.

### A.3 Rewind contract

| Attempt outcome | Generator state after |
|---|---|
| Body returns nil (abandoned) | rewound to entry position |
| Body throws (abandoned) | rewound to entry position, error propagated |
| Body returns a value (completed) | left advanced by the body's draws |
| Abandoned + `seeded: true` | `seedPromiseBroken == true`, resolution throws |
| Abandoned + `seeded: false` | `seedPromiseBroken == false`, resolution returns nil (CPU fallback) |

All five pinned. The third is the one a naive unconditional-rewind fix would break.
