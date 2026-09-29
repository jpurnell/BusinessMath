# Handoff — 2026-09-29 (the contaminated-input campaign is CLOSED, all five phases)

**8,883 tests / 828 suites. Gate 46/46, 0 errors, 0 warnings, 0 new findings gating.**

One defect class, swept to completion: **a guard that is correct while the value it returns is
a claim landing at the favourable end of a scale the caller reads** — plus its cousin, `Int(x)`
trapping the process. Roughly **1,200 sites read, ~200 real defects, 5 hard crashes**, across
five phases and 29 commits.

## The one fact underneath all of it

**Every comparison against `nan` is false, including `nan == nan`.** It never raises. It answers
*no*, and "no" is a valid answer everywhere in Swift. Five structurally different failures follow:

| expression | what breaks |
|---|---|
| `nan > 0` | a guard fires → its fallback is returned as a measurement |
| `nan < x` | `sorted()` is unspecified — **valid** elements come back out of order |
| `nan == nan` | `firstIndex(of:)` → nil → the element vanishes |
| `nan > 0` **and** `nan < 0` | both arms of if/else-if skipped |
| `Swift.min(1, nan)` | returns **`1`** — the idiomatic clamp turns "unknown" into "maximum" |

And `Int(Double)` **traps** rather than answering — on non-finite values *and* on anything past
`Int.max ≈ 9.22e18`.

## The design principle the campaign actually found

Late, and worth more than any individual fix. `Core/GaussianElimination.swift` is clean because
every guard is written so a NaN **fails the comparison and therefore lands on the failure enum**.
`FinancialValidation.swift` was broken because every rule is written so a NaN fails the
comparison and **lands on "valid"**. Identical mechanism, opposite default.

> **The question is not "does this check for NaN". It is: when the comparison cannot be
> evaluated, which way does the default fall?**

A solver that defaults to failure gets NaN-safety free. A validator that defaults to "no problem
found" gets the campaign's worst defect free.

## What each phase found

| phase | shape | sites | defects |
|---|---|---|---|
| 1 | `Int(x)` traps | ~92 | 39 + 4 crashes |
| 2 | `?? 0` on a period lookup | 34 | 9 (+18 legitimate, pinned) |
| 3 | Streaming / Time Series, by probe | 21 probes | ~25 |
| 4 | `else { return T(0) }` after a valid guard | ~420 | ~96 |
| 5 | ordering, Fluent API, 20 never-swept dirs | ~400 | 36 |

**Measurements worth keeping**, because they are what made the class legible:

- `ModelValidator` printed `✅ Validation PASSED - 0 errors, 0 warnings` for a projection with
  NaN assets and NaN revenue.
- `[1,2,3,nan,5,6,7,8].rank()` → `[3,2,1,nan,8,7,6,5]`. The largest ranked **last**.
- `altmanZScore` returned **0.00 — the distress zone** — for a solvent, profitable company asked
  about a period outside its statements.
- `piotroskiScore` scored a deteriorating company **4 against its real prior quarter and 7
  against a fabricated one**, crossing the "buy signal" threshold the file documents.
- A gradient-descent optimizer reported `converged = true, optimalValue = 10.0` **at iteration
  zero** on `min x²` from 10, because a collapsed step made the derivative estimate exactly 0 —
  which *is* the convergence test.
- `detectSeasonalAnomalies` let one NaN poison a season baseline permanently, so a genuine
  **50x spike 24 observations later** reported `isAnomaly = false`.
- `decomposeTimeSeries(.additive)` subtracted a **dimensionless** re-centred ratio from values
  carrying units; the error factor ~128 *is* the level of the series, so unbounded.
- `OilGasEPModel` priced a missing commodity price at $0/bbl while still charging full lease
  operating expense: a *producing* well booking zero revenue at full cash cost, −$196,500.

## Patterns that cost the most to learn

- **A fix installed upstream of the leak reads as done and is not.** Three times: fixing
  `mostFractionalVariable` when `isIntegerFeasible` runs first; fixing eight risk metrics when
  `ComprehensiveRiskMetrics.init` short-circuits before calling them; `ModelDebugger` routing
  *around* `RevenueComponent` rather than fixing it. **When you guard the thing that computes
  the answer, check whether anything decides not to call it.**
- **The remediation carries the defect.** Four times: `Swift.min(span, limit)` returns the
  `nan`; `T(Int.max)` rounds to 2^63 and traps; a filter after `let n = count` gives
  `Index out of range`; `abs(nan) > 0.001` being false let a `.nan` reach an `.infinity` exit —
  the *passing* end of a covenant.
- **A correctly-behaving sibling decides the contract.** Used a dozen times, and twice the
  sibling was eight lines away (`manhattanDistance` vs `chebyshevDistance`) or in another
  backend (the Metal kernel had never had the CPU's `u > 0` bug).
- **A justification comment is a claim.** `// Edge case: no data` hid a second implementation of
  a whole report. `numberOfPoints >= 2` was asserted in an `fp-safety:disable` comment and
  enforced nowhere. A rank test's "the other positions still rank normally" was false.
- **A site is not a defect.** ~1,000 of ~1,200 sites were legitimate. `pdf` returning 0 outside
  its support is 68 sites of correct-by-specification. Network's accumulators are correct by
  construction. `ConstrainedDriver.clamped` is correct *only because of its argument order* —
  a tidying refactor would break it, and it is now commented so.
- **The specification was already right, three times**: `varianceS`'s DocC stated the
  precondition, `FinancialPeriodSummary.init` was declared `throws` with zero throws,
  `PowerAnalysis` promised `- Throws:` for a function that trapped. Not a missing decision — a
  missing implementation of a decision already made.

## STILL OPEN — deliberately, with reasons

**Needs a decision, not a guard:**
1. `FinancialModel.validate()` can never return `isValid == false` on its own — no branch
   appends `.error` severity. Whether negative revenue is an error is a judgement about sign.
2. `DriverOptimization.optimize` does no entry validation; `normalisationScale`'s guard answers
   two questions ("driver pinned at zero" and "bound is not a number") identically.
3. `ModelDebugger.validate(_:)` checks NaN only in `revenueComponents` — the same gap as
   `findMissingData`, but *documented*, so it looks deliberate. Still returns "✅ Model is valid".
4. `bottlenecks(threshold: .nan)` returns `[]` = "no bottlenecks"; a NaN warning threshold
   silences every warning. Contaminated *parameter*, no room in the return type to say so.
5. Three renderings of a NaN coexist in public output: `"NaN"`, `"∞"`, `"nan"`/`"inf"`. Each
   documented at its own site; nobody has decided whether they should agree.
6. `Date(timeIntervalSince1970: .nan)` **clamps** — year 4713; `+.infinity` gives 506713. The
   wrong answer is manufactured at construction, where no `??` can see it. Needs its own probe.

**Located, unfixed, ordinary work:**
- `Constraint.swift:650,654` — `Swift.max(0, value)` turns a NaN violation into "no violation".
- `weightedBreakdownPoint.swift:38` — right action, wrong diagnosis (throws "total weight is
  zero" for a NaN weight; §3.2 forbids that reuse).
- `LogisticRegression.separatesByThreshold` — an all-NaN column returns `false` = "no
  separation", so fitting proceeds.
- `bayesianICC.swift:126` — `mergedICC.sorted()` drives the posterior median off an unspecified
  order. Already throws, so §3.2 gives a clean answer.
- `PercentileLocation` — `T: Comparable`, sorted then indexed; the clean detector is to verify
  the postcondition (`zip(sorted, sorted.dropFirst()).allSatisfy { $0 <= $1 }`).
- `Interpolation`: `VectorInterpolators.swift:30` lets `xs: [5, 1, nan, 1], ys: []` construct
  successfully; the two-point `.clamped` spline discards the caller's endpoint slopes; no
  divide-by-zero guard anywhere in the interpolation path.
- `cdf(±infinity)` is `nan` for Beta, F and Pearson6 (they route through
  `regularizedIncompleteBeta`, which throws on an infinity); `gammaCDF` returns `nan` for a
  finite `x` below the support where the protocol promises 0.

## Working notes

- **`✅ Quality Gate: PASSED` is not evidence — read the `N of M checkers` line.** The gate
  truncates at the first failure and the baseline ledger then rewrites that failure into a pass.
  Fixed in quality-gate `41ff038` (an all-green truncated run now says INCOMPLETE), but the
  runner still never sees the ledger, so **use `--continue-on-failure` here**.
- **Never `git add -A`** — a peer session works in this repository and its untracked files land
  in your commit. Stage explicit paths and account for every `git status` line. Note
  `Sources/BusinessMathDSL` is a *sibling* of `Sources/BusinessMath`, not under it.
- **The `agree` test helper must be NaN-tolerant** — `isEqual(to:)` is IEEE equality, so
  `nan.isEqual(to: .nan)` is false and a deliberately-marked position can never match.
- **`#expect` gotchas**: a key path (`allSatisfy(\.isNaN)`) makes `rethrows` unprovable and will
  not compile; a failure message must be a string *literal*, so `"a" + "b"` is not a `Comment`.
- **A guard inserted before a one-expression body drops the implicit return.** Eleven sites in
  one session; give bulk-inserted guards a distinctive marker comment so the sweep is one grep.
- **Do not run parallel `swift build`s**, and check `uptime` before the gate — `doc-run` reports
  slow articles as hangs under load, and the OS has killed gate runs outright.
