# Session summary — 2026-08-13 (afternoon/evening)

**Outcome:** `doc-comment-code` 852 → **420 non-macro**, `doc-claims` 8 → **0**, the live tree
clean under the new `gpu-safety` checker, and the GPU nondeterminism root-caused and fixed.
Suite 6,582 → 6,597, all green. 26 commits, all pushed.

The morning half of the day is `SUMMARY_2026-08-13_gpu-seed-contract-and-ci-green.md`.

---

## 1. The GPU defect, finally root-caused

Earlier sessions fixed three things on the *fallback* path — a `catch` guard, a `nil` return
converted to a throw, a missing `commandBuffer.status` check — and none cured the seeded
optimizer that reproduced only sometimes.

**None of the eight kernels bounds-checked its thread id.** Dispatch rounds up:

```swift
let threadGroups = MTLSize(width: (populationSize + 255) / 256, height: 1, depth: 1)
```

At 1200 that is 1280 threads for 1200 individuals, and the surplus 80 read `randomSeeds[id]`
past its allocation and wrote the population buffer past its end. Undefined behaviour, which
is exactly what differs between two otherwise identical runs.

The sizes explain themselves once seen: 999 uses the CPU path, 1000 dispatches 1024, 1200
dispatches 1280. **Both failing sizes are non-multiples of 256 and the passing one never
reached the GPU.** A test written at 1024 would have passed forever.

`tournamentSelection` already *received* `populationSize` and used it to pick tournament
candidates — never to bound `id`. The parameter the guard needed was there.

Fixed twice over: every kernel guards, and every dispatch now uses `dispatchExactly`
(`dispatchThreads`), which sizes the last threadgroup to fit so the surplus does not exist.
`shouldUseGPU` requires non-uniform threadgroup support; where it is absent the GPU is
declined, since every path has a complete CPU implementation.

## 2. `gpu-safety` shipped and immediately earned its keep

The proposal written this morning was implemented, and on its first run it found the gap the
proposal itself had described and I had not applied: `DifferentialEvolution`,
`ParticleSwarmOptimization` and `MetalMatrixBackend` still read their buffers after a
possibly-failed dispatch. All three now check `commandBuffer.status`.

Its other 53 errors are all in `.claude/worktrees/` — stale pre-fix copies. Whether the gate
should scan worktrees is open, and is the same shape as auditing `.metal` files excluded from
the build.

## 3. `doc-claims` cleared — three causes, one wrong number

- **A miscalculated figure.** `1.2` documented growth as `[10%, 10%, 9.9%, 9.8%]`; 146.45/133
  is 10.1%. The code was right.
- **Four claims read their input from the clock.** `let date = Date()` documenting FY2025 Q1,
  and XIRR dates built from `timeIntervalSinceNow` — the checker caught the latter as *two
  values changing between two runs of the same binary*.
- **One over-precise tolerance**, and two formatting mismatches.

## 4. `doc-comment-code`: 852 → 420

**What worked.** Type from usage, never from the name — `.zip` and `.aggregate` are TimeSeries
methods, `.positive()` is a Driver method, `entity:` takes an Entity. `model` alone named six
different types across nine files.

**What did not.** A pass keyed on plausible names produced **205 bindings for 13 errors**,
because `\btimeSeries\b` matches the argument label in `Account(..., timeSeries:)`. Reverted.
Driving from the checker's own report gave **27 bindings for 17 errors**.

**The recurring find** was API the examples still describe and the library no longer has:
`BalanceSheet(assetAccounts:liabilityAccounts:equityAccounts:)`,
`DistributionNormal(mean:stdDev:)` (12 calls), `Account(type:)`,
`Investment(initialCost:cashFlows:discountRate:)`, `CashFlow(year:)`,
`OptimizationResult.x`, `ValidationReport.issues`, `findInput(whereOutputEquals:)`. Each
fails three ways at once — undefined references for the values it invents, generic-inference
failures because the arguments that would pin `T` are themselves broken, and extra-argument
errors — so the error-kind histogram badly overstates how many distinct problems exist.

**Two genuine library bugs** surfaced: a precedence error in a published percentage
(`(ar[q1] ?? 0 / (currentAssets[q1] ?? 0))` divides before the `??`), and three fences using
`Period.documentationQuarters` with `periodsPerYear: 4` — one seasonal cycle where the
algorithm needs two, which compiles and then fails at runtime.

## 5. Duplicate audit

Asked for one canonical version of everything. 373 top-level public functions; 55 names carry
more than one declaration and **every one is a genuine overload** with distinct parameters.
Three identical method bodies exist across files and all three are justified: `encode` on the
statement types (which really do share three stored properties), `callAsFunction` on the
interpolators, and `valuePerShare` on FCFE and Residual Income.

So `ExpressionArray.stdDev` — a second, divergent implementation of a canonical function,
dividing by `n` under the name this library gives the `n−1` form — was the exception.

One name collision did turn up: `Scenario` is the Monte Carlo type, and the builder component
is `ModelScenario`. A fence using the bare name got two unrelated-looking errors from one
cause.

---

## Corrections made during the session

Kept because the reasoning outlasts the conclusions.

- **Claimed the TSan SEGV was why the nightly had been red.** It was not — Ubuntu failed both
  nights; TSan passed the first.
- **Dismissed the `.timeLimit` timeouts as a local artifact.** CI hit one on the next run.
- **Proposed a "headroom ratio" checker for time limits.** Wrong direction: limits should be
  *large*, because one tuned near observed runtime is the one that lies.
- **Audited `.metal` files that are excluded from the build**, reporting eight defects in code
  the compiler never sees and missing the two that ship.
- **Wrote a proposal into `BusinessMath/quality-gate-swift/`**, a directory that existed only
  because I put a file in it. The real repo is `Tools/quality-gate-swift`.
- **Inferred APIs instead of reading them**, three times: `marketPrice` as a `Double`,
  `projection` as the wrong projection type, `.operatingExpense` as an `IncomeStatementRole`
  case. Reading the declaration first has never once been wrong.
- **Pushed twice on a red suite**, both times because `swift test` and `git commit` were
  chained with `;` rather than `&&`.

## Still open

`HANDOFF.md` carries the resume detail. In short: the 420 with no cluster left, the worktree
question, `v3.0.0_SCOPE.md`, the seedless simulation wrappers, and `doc-symbol-link`.
