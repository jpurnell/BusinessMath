# Design Proposal: `IterativeSolver` — resolving a cycle to a fixed point

**Status:** proposal, for argument. Nothing here is implemented.

**Last updated:** 2026-08-10

**Companion:** `CircularDependencyDetection.md`, in this folder. The two are halves of one
capability — **detect the cycle, then resolve it.** This document assumes the other's output: a
strongly-connected component, a topological order over the condensation, and a structural
classification of whether the cycle is linear in its members. Without those, a solver has nothing
to tell it what to iterate, in what order, or whether iterating is even the right method (§9).

Every claim about current state below carries a `file:line` and was verified against the working
tree on 2026-08-10.

---

## 1. The motivating case

**People migrating from Excel.**

Circular references in financial models are not a mistake there — they are the normal shape of a
three-statement model. The canonical instance is **circular interest**:

```
interestExpense = rate × (openingDebt + closingDebt) / 2
closingDebt     = openingDebt − cashAvailableForDebtService
cashFlow        = EBITDA − taxes − capex − interestExpense
```

Interest depends on the debt balance; the balance depends on the cash flow; the cash flow depends
on interest. Excel resolves this with `Enable iterative calculation` — maximum iterations, maximum
change — and the model settles in a dozen passes. Cash sweeps, profit-share accruals, tax on income
net of an interest shield, and any fee charged on a total that includes the fee are all the same
shape.

A modelling library that cannot resolve these is a wall for anyone porting a real model. This is
the constituency, and the design should be judged against what it does for them.

**One thing must be said here rather than at the end.** The library's formula language has **no
references to other periods** — stated at `Time Series/FormulaEvaluator.swift:99` and
`1.9-FormulaEvaluation.md:152-156`, and confirmed by the absence of any lag, shift or
prior-period operator anywhere in `Time Series/TimeSeries.swift` or `TimeSeriesOperations.swift`.
The `openingDebt(t) = closingDebt(t−1)` roll-forward above therefore **cannot currently be
written**, with or without this solver. What this proposal delivers is the *within-period* half:
given opening balances, solve the period. The roll-forward stays the caller's loop until a
prior-period reference exists. `CircularDependencyDetection.md` §3.1 argues the same point at
length, and both documents should be read as scoped by it.

---

## 2. What `IterativeSolver` was promised to be

`BusinessMathError.circularDependency`'s `recoverySuggestion` used to tell users to resolve the
cycle "using an iterative solver". There has never been an `IterativeSolver` in this repository —
zero occurrences, verified. That sentence was removed during the retraction described at
`CHANGELOG.md:42-45`; the text at `Error Handling/BusinessMathError.swift:264-275` now names
`FormulaEvaluator.accountNames(in:)` instead, and the two tests that pin it
(`BusinessMathErrorTests.swift:199`, `:496`) assert on the new string.

So this proposal is no longer *closing a lie* — that has been done. It is proposing the feature the
lie was reaching for, on its merits.

---

## 3. What exists, and what is honestly reusable

| symbol | what it is | reusable? |
|---|---|---|
| `Solver/GoalSeek.swift:32` `goalSeek(function:target:guess:tolerance:maxIterations:)` | scalar Newton–Raphson to a root, with `derivative(of:at:)` from `Solver/Derivative.swift` | **As a precedent, yes; as code, no.** It is one-dimensional over `(T) -> T`; a cycle is a simultaneous system over *n* named accounts, each a `TimeSeries`. But see below — its *error behaviour* is the model to copy. |
| `Optimization/SparseSolver.swift:96` `solve(A:b:method:…)` | CG and BiCG for sparse linear systems, `maxIterations` 10,000 and `defaultTolerance` 1e-10 (`:79`) | **Directly relevant to §9.** A `.linear` SCC *is* a small dense linear system; this type solves large sparse ones. Different regime, same idea. Worth reusing if an SCC is ever large; a 3×3 Gaussian elimination is better for the common case. |
| `Optimization/AdaptiveProgress.swift:339` `ConvergenceDetector`, `:399` `hasConverged`, `:419` `isOscillating` | a sliding window over `ConvergenceMetrics` (`:13`) | **Partially.** `isOscillating` as a distinct state from "not yet converged" is exactly the distinction §5 needs, and the window idea transfers. The type itself is `Double`-only and gradient-oriented (`gradientNorm` at `:20`), and a fixed-point iteration has no gradient. Reuse the *design*, not the type. |
| `Optimization/Optimizer.swift:60` `OptimizationResult<T>` | `optimalValue: T` (`:62`), `converged: Bool` (`:71`), `history: [IterationHistory<T>]` (`:14`) | **No.** `optimalValue` is a scalar. A solved cycle is a *set of named series*. Forcing it through this type would lose the names, which are the useful part. |
| `Optimization/GoalSeekOptimizer.swift:189-195` | returns `OptimizationResult(optimalValue: x, …, converged: converged, …)` | **This is the anti-precedent.** See §3.1. |

### 3.1 The pattern to design against, and it is already in the tree

`GoalSeekOptimizer.optimize` breaks out of its loop on a near-zero derivative at `:158-161`, and on
exhausted iterations by simply falling out of `for iteration in 0..<maxIterations` at `:135`. In
both cases it reaches `:189-195` and returns the last iterate, with `converged: false` set at
`:125` and never updated.

That value is a number. It is in the right units. It will print. It is, in the zero-derivative
case, wherever Newton happened to stall — which can be arbitrarily far from any answer. The only
thing distinguishing it from a solution is a `Bool` on a struct that a caller has to remember to
read. The type's own documentation gets this right — `Optimizer.swift:54` guards the example's
whole body with `if result.converged` — which is precisely the discipline the compiler does not
enforce and a hurried caller will skip.

Compare `Solver/GoalSeek.swift:53-63`, which **throws** `calculationFailed` with five concrete
suggestions when it fails to converge, and `:44-48`, which throws on a zero derivative rather than
breaking. Same algorithm, opposite contract, and the throwing one is right.

`SparseSolver.SolverError.notConverged(iterations:residual:)` (`Optimization/SparseSolver.swift:44`)
is the same good choice, and it carries the residual, which is the number that tells you *how* far
short it fell.

**The library has spent a day removing exactly the pattern at `GoalSeekOptimizer:189-195`** — a
plausible number returned where an answer is expected, with the failure recorded somewhere the
caller may not look. `IterativeSolver` must not add another instance. §6.3 makes this structural.

---

## 4. The method

### 4.1 Iterate inside SCCs, not over the model

The single most important design choice, and it comes free from the companion proposal.

The dependency graph condenses to a DAG of strongly-connected components. Components with one
member and no self-edge are ordinary accounts: **evaluate them once, in topological order.** Only
multi-member components (and self-loops) need iterating, and each can be iterated *independently*,
in topological order, with every upstream component already at its final value.

For a real three-statement model this is the difference between iterating three accounts and
iterating four hundred. A model with 400 accounts and one interest cycle does 397 single
evaluations and iterates 3. Excel, by contrast, iterates the whole recalculation chain, because it
does not decompose. **This is the first place where doing better than Excel is easy and worth
doing.**

### 4.2 Gauss–Seidel over Jacobi

Within an SCC, both are available:

- **Jacobi**: compute all new values from the previous iterate, then swap. Order-independent, so
  trivially deterministic and trivially parallel.
- **Gauss–Seidel**: update in place, so later accounts in the sweep see this iteration's values for
  earlier ones. Typically converges in roughly half the iterations; order-dependent.

**Recommend Gauss–Seidel as the default, with Jacobi available.** Financial models are nearly
triangular — most of a model is a chain, with a small feedback edge closing it — and Gauss–Seidel
exploits exactly that, propagating a whole sweep's worth of information per iteration where Jacobi
propagates one edge's worth. On the canonical interest cycle, sweeping in the order
`cashFlow → debt → interest` converges in a handful of passes.

The order-dependence is the cost, and it is a determinism problem, not a correctness one. §7 makes
the order a stored, derived, documented thing rather than an accident.

Jacobi should still exist, for two reasons: it is the honest comparison when a user reports that
Gauss–Seidel oscillated, and it is the one that can be parallelised across accounts if an SCC ever
gets large enough to care.

### 4.3 Damping

Some cycles oscillate rather than converge — the iterate overshoots, comes back past the fixed
point, and the amplitude grows. The standard remedy is relaxation:

```
x_{k+1} = x_k + ω · (F(x_k) − x_k)
```

with `ω = 1` plain iteration, `ω < 1` damped (stabilises an oscillating cycle at the cost of
speed), `ω > 1` over-relaxed (faster on a slowly-converging one, and can destabilise). Financial
feedback loops with a coefficient magnitude near or above 1 — a highly levered structure where the
interest feedback is strong — are the case that needs `ω < 1`.

**Proposal: `ω` is a caller-set constant, default 1.0.** An *adaptive* `ω` is tempting and should
be rejected for the first version: it makes the answer depend on the trajectory, which makes a
regression in convergence behaviour indistinguishable from a change in the model, and it is one
more thing that must be proven deterministic. If oscillation turns out to be common, adaptive
damping is a second proposal with its own evidence.

---

## 5. Excel's contract, and where to depart from it

Excel offers exactly two knobs: `Maximum Iterations` (default 100) and `Maximum Change` (default
0.001). When either is satisfied, iteration stops and the sheet shows the last values.

| Excel | follow, or not | reasoning |
|---|---|---|
| `Maximum Iterations` | **follow.** Default 100. | Familiar, and the right shape. Anyone who has enabled iterative calculation knows this number. |
| `Maximum Change`, absolute | **follow, but not alone.** | An absolute threshold of 0.001 is meaningless across a model where cash is 1e9 and a margin is 0.4. Ship both: converged when `|Δ| ≤ absoluteTolerance` **or** `|Δ| ≤ relativeTolerance × |x|`, per account. |
| stop at max iterations and show the last values | **do not follow.** | This is `GoalSeekOptimizer:189-195` with a spreadsheet UI. Excel gives no signal at all that the numbers on screen are an unconverged iterate; the model just looks slightly wrong forever. §6.3. |
| one global setting for the whole workbook | **do not follow.** | Configuration belongs on the solve, not on a global. §6.1. |
| iterate the whole recalculation chain | **do not follow.** | SCC decomposition, §4.1. |
| no distinction between diverging, oscillating and merely slow | **do not follow.** | Three different problems with three different fixes: reformulate, damp, raise the iteration cap. §5.1. |

### 5.1 Naming the failure, not just reporting it

`ConvergenceDetector` already distinguishes `hasConverged` (`AdaptiveProgress.swift:399`) from
`isOscillating` (`:419`), and that distinction is the useful one. Proposed states, and what each
licenses saying:

| state | detected by | what to tell the user |
|---|---|---|
| converged | max per-account change within tolerance | the numbers, and the iteration count |
| **diverging** | the change is growing monotonically over a window | the cycle's feedback gain exceeds 1. Damping will not save this; the model needs reformulating. |
| **oscillating** | the change alternates sign with roughly stable magnitude | try `ω < 1`. This is the case damping exists for. |
| **stalled** | change small but above tolerance, not decreasing | the tolerance may be below what the arithmetic can deliver, or the system is near-singular |
| exhausted | none of the above, iterations spent | raise `maxIterations`; report the change achieved so the caller can judge whether it was close |

Per `quality-gate-swift/project/plans/proposals/TestQualityAuditor.md` §6a — *a diagnostic that
confidently names the wrong cause is worse than one that lists possibilities* — these should be
reported as **the state observed** plus the checks worth making, not as an assertion about the
model's economics. "The change grew over the last 8 iterations" is observed. "Your model is
wrong" is not.

---

## 6. The interface

### 6.1 Where configuration lives

Three candidates: on the model, on the evaluator, on the solve call.

**On the model** — rejected. It makes an iteration budget a property of the *thing being modelled*,
which it is not; it means two callers with different accuracy needs cannot share a model; and it is
Excel's global-setting mistake at a smaller scale.

**On the evaluator** — rejected for the reason `CircularDependencyDetection.md` §4 Option C rejects
its analogue: `FormulaEvaluator` (`Time Series/FormulaEvaluator.swift:103`) is a small, stateless,
`Sendable` struct that evaluates one expression, and every job pushed into it makes the type harder
to reason about.

**On the solve call** — recommend.

```swift
public struct IterationSettings: Sendable {
    public var maxIterations: Int          // default 100, per Excel
    public var absoluteTolerance: Double   // default 1e-9
    public var relativeTolerance: Double   // default 1e-9
    public var relaxation: Double          // ω, default 1.0
    public var method: Method              // .gaussSeidel (default) | .jacobi
    public var initialValues: InitialValues // see §7.3
}
```

Passed to a `solve`, not stored. That keeps the same `ModelDefinition` usable at draft tolerance
during exploration and tight tolerance for a published figure, which is a real workflow.

### 6.2 What a result carries

Beyond the numbers. The brief asks for this explicitly and it is the part most easily
under-specified.

```swift
public struct SolvedModel<T>: Sendable {
    public let values: [String: TimeSeries<T>]   // every account, derived and input
    public let cycles: [CycleSolution]
}

public struct CycleSolution: Sendable {
    public let accounts: [String]        // sorted, matching Cycle.accounts
    public let iterations: Int           // used, not the cap
    public let finalChange: Double       // the largest per-account change on the last sweep
    public let stillMoving: [String]     // accounts whose change exceeded tolerance, sorted
    public let method: Method            // which was used, and ω
}
```

`stillMoving` should be populated **even on success** — empty when everything settled, and
non-empty on the failure path. Knowing that seven accounts settled and one did not is a far better
starting point than a single scalar residual, and it is nearly free to record.

`iterations` is the count actually used. `finalChange` is the number that answers "was it close?",
and it is the same choice `SparseSolver.SolverError.notConverged` already makes by carrying the
residual (`Optimization/SparseSolver.swift:44`).

Deliberately **not** included: a full per-iteration history like `IterationHistory`
(`Optimizer.swift:14`). It is `O(iterations × accounts × periods)` and almost never read. If
trajectory inspection is wanted, it belongs behind an opt-in observer closure — and that closure
must not be able to change the result, or determinism is gone.

### 6.3 Failure is a `throw`, not a flag

```swift
public func solve(_ model: ModelDefinition<T>, settings: IterationSettings) throws -> SolvedModel<T>
```

Non-convergence throws. It does not return `SolvedModel` with `converged: false`.

The argument is `GoalSeekOptimizer.swift:189-195` versus `Solver/GoalSeek.swift:53-63` — the same
algorithm with opposite contracts, one of which requires the caller to remember and one of which
does not. The library already chose, correctly, in `GoalSeek` and in `SparseSolver`. A returned
struct with a `converged: Bool` will be destructured for its numbers by someone in a hurry, and the
numbers will be an unconverged iterate that looks exactly like an answer.

The proposed error carries the diagnosis:

```swift
case notConverged(
    accounts: [String],       // the cycle
    state: ConvergenceState,  // diverging | oscillating | stalled | exhausted
    iterations: Int,
    finalChange: Double,
    stillMoving: [String]
)
```

A caller who genuinely wants the last iterate — plotting a divergence to show a client why the
structure does not work — should get it from a separate, unmistakably-named entry point
(`solveReportingLastIterate`, or the error carrying it). It should never be the thing you get by
not reading a field.

---

## 7. Determinism, by construction

The library has spent a day making results reproducible. `git show 0b52198` fixed a GPU RNG whose
XOR seeding correlated adjacent Monte Carlo iterations at ρ ≈ 0.26. `git show d247691` fixed three
scenario generators that accepted a seed and then drew from `drand48`'s process-global stream, so
that two seeded generations running concurrently were both irreproducible — 96.1% of assertions
failing before the fix, 0 of 25 runs after. `Determinism/WallClock.swift` and
`Determinism/ElapsedTime.swift` record the same standard for clocks.

Gauss–Seidel is order-dependent by definition. So this must be deterministic **by construction, not
by luck**, and there are exactly three places it can leak.

### 7.1 Sweep order

**Dictionary iteration order is not stable across processes in Swift** — hashing is seeded per
process. Any sweep order derived from iterating a `[String: …]` produces different numbers on
different runs of the same binary against the same data. Not different by much, and that is worse:
it is different in the last few digits, which is exactly the kind of difference nobody notices until
a regression test starts flapping.

The sweep order must be a **stored `[String]`**, computed once, from a deterministic source:

- Adjacency comes from `FormulaEvaluator.accountNames(in:)` (`Time Series/FormulaEvaluator.swift:136`),
  which returns `Set<String>` — **sort it**. The existing documentation already does, at
  `1.6-DebuggingGuide.md:215`, for exactly this reason.
- SCC membership order and the topological order over the condensation follow from Tarjan's
  traversal, which is deterministic once its adjacency and root order are (`CircularDependencyDetection.md` §5.3).
- The within-SCC sweep order should then be **documented as part of the contract**, because it is
  observable in the last digits of the answer. A user who reorders their definitions and sees the
  eleventh significant figure move deserves to have been told that could happen.

### 7.2 Floating-point accumulation

Every arithmetic step goes through the `TimeSeries` operators (`TimeSeriesOperations.swift:391-427`),
which are period-wise and order-fixed — the periods array is sorted at construction
(`TimeSeries.swift:174`, `self.periods = valueDict.keys.sorted()`). So summation order within an
expression is already stable. Nothing further is required *provided* no step introduces a
reduction over an unordered collection. That is a constraint on the implementation to state now
rather than discover.

One caveat worth recording: `Period`'s `<` (`Time Series/Period.swift:1171`) sorts by *type* before
start date, so a series mixing annual and quarterly points is stored in an order that is stable but
not chronological. This is a known defect, tracked at `TrustPlan.md:138-140`. It does not make the
solver non-deterministic — stable is what determinism needs — but a solver that reports "which
periods are still moving" against a series ordered like that will confuse anyone reading the
output.

### 7.3 Initial values

The starting iterate changes the trajectory, the iteration count, and — for a nonlinear cycle with
more than one fixed point — potentially *which answer you get* (§8). It cannot be left to whatever
is lying around.

Propose an explicit, enumerated choice:

```swift
public enum InitialValues: Sendable {
    case zero                              // default: reproducible, and the obvious neutral
    case supplied([String: TimeSeries<T>]) // a warm start, e.g. last period's solution
}
```

`case zero` as the default because it is the one a reader can predict. A "use whatever data is
already in the account" default would make the answer depend on load order — the same class of bug
as the process-global RNG stream in `d247691`.

### 7.4 No parallelism inside an SCC

Gauss–Seidel is sequential by construction; parallelising it changes the answer. Jacobi could be
parallelised across accounts, and even that should be resisted unless the reduction order is fixed,
because floating-point addition is not associative. Independent SCCs at the same topological depth
*could* be solved concurrently without affecting any result — they share no state — but this should
be deferred until there is a model large enough to motivate it. Say so, rather than leaving it as
an implicit "someday".

---

## 8. What this will not do

Stated plainly, so the documentation written against it stays true.

- **It does not guarantee convergence.** No fixed-point iteration does. A cycle whose feedback gain
  exceeds 1 diverges, and no choice of `ω`, tolerance or iteration cap fixes that — the model needs
  reformulating. The solver's job is to *say so*, quickly and by name (§5.1), not to succeed.
- **It does not find a unique answer for a nonlinear cycle.** A nonlinear system can have several
  fixed points, and Gauss–Seidel converges to the one in whose basin the initial iterate sat. Two
  users with different warm starts can get different, both-correct answers. The result should
  therefore record the initial values used, and the documentation must not describe the output as
  "the" solution for a `.nonlinear` cycle.
- **It cannot tell an intended circularity from a modelling error.** A typo that makes an account
  read a total it contributes to produces a perfectly well-behaved cycle that converges to a
  number, and that number is wrong. This is why `CircularDependencyDetection.md` §6 makes the user
  declare which cycles they expect, and why the solver should refuse — or at minimum warn — on an
  undeclared one rather than quietly resolving it. **Iteration must not become a way for mistakes
  to stop being visible.** That is the single largest risk this feature introduces, and it is
  Excel's actual failure mode: once the checkbox is on, every accidental circularity is absorbed.
- **It does not handle cross-period cycles**, because the language has none (§1). The canonical
  circular-interest model needs a roll-forward this cannot express.
- **It does not solve for a target.** "What debt balance makes DSCR exactly 1.25" is goal-seeking,
  and `Solver/GoalSeek.swift:32` is that. Composing the two — a goal seek whose objective is a
  solved cycle — is legitimate and expensive, and out of scope.
- **It says nothing about whether the model balances.** Convergence is not correctness.

---

## 9. The argument against iterating at all, for the case that matters most

Recorded because it is the strongest objection to this proposal and it is largely right.

**Circular interest is linear.** `interest = rate × (opening + closing) / 2` is linear in `closing`
because `rate` and `opening` are not members of the cycle. So is the debt roll, and so is the cash
flow. The whole canonical example is a small linear system — typically 2×2 or 3×3 — with a closed
form. Gaussian elimination solves it **exactly, in one step, with no tolerance, no iteration cap,
no oscillation and no convergence question at all.** The same is true of cash sweeps, gross-ups and
profit-share accruals: they are linear in the cycle variables, and Excel iterates them only because
Excel has no idea what its cells mean.

`CircularDependencyDetection.md` §7 proposes classifying each cycle as `.linear`, `.nonlinear` or
`.selfReferential` from the parse tree — decidable, because the grammar is `+ − × ÷` and nothing
else (`FormulaEvaluator.swift:76-82`). That classification is what makes the following possible:

> **Solve `.linear` SCCs directly; iterate only the `.nonlinear` ones.**

For a linear SCC of size *n*, build the *n×n* coefficient matrix by evaluating each formula's
partial contributions — the coefficients are constants with respect to the cycle members, so they
can be extracted, per period, without iterating — and solve. Exact, deterministic by construction
(no sweep order to worry about), and it eliminates the entire class of "it oscillated" support
questions for the cases users actually hit. It also puts `Optimization/SparseSolver.swift:96` in
play if an SCC is ever large enough to want it, though a 3×3 does not.

**This is strictly better than Excel on the motivating case, and it is the reason to build the
detector first.** Without `Cycle.Form`, a solver has no way to know it could take the exact route.

**Where iteration is still needed**, and so where this proposal is not obsolete:

- Nonlinear cycles: anything with a cycle member in a denominator (a ratio computed from a total
  that includes it), or two cycle members multiplied (interest at a rate that itself depends on
  leverage — a covenant-priced revolver).
- A singular or near-singular linear system, where a damped iteration may still land somewhere
  useful and elimination will not.
- The fallback when coefficient extraction is not implemented for some grammar case.

**Consequence for the plan.** If only one of the two is built, build detection, and build the
direct linear solve as the first resolution path. `IterativeSolver` is then the *general* method,
covering the cases the exact one cannot — which is a smaller and better-defined feature than "the
thing that resolves circular interest".

---

## 10. Size, and order

**Size: medium-to-large**, and larger than the detector — most of the cost is in the failure
paths, not the happy one. Gauss–Seidel over an SCC is perhaps thirty lines. Convergence-state
classification, the error vocabulary, the determinism tests, and the documentation that has to be
honest about §8 are the bulk.

| piece | size |
|---|---|
| `IterationSettings`, `SolvedModel`, `CycleSolution`, the error case | small |
| Gauss–Seidel / Jacobi sweep over one SCC, with damping | small |
| convergence-state classification (diverging / oscillating / stalled / exhausted) | medium — the tests are the work, and each state needs a model that provably exhibits it |
| direct solve for `.linear` SCCs (§9) | medium — coefficient extraction from the parse tree is the new algorithm here |
| determinism tests: same model, same answer, across processes; sweep-order sensitivity documented | medium, and non-negotiable |
| DocC article, CHANGELOG, worked example | medium |

**Order: detection first, and not only for narrative reasons.**

1. `ModelDefinition` and topological evaluation of an acyclic definition set
   (`CircularDependencyDetection.md` §11 step 1).
2. Tarjan, SCC decomposition, `DependencyReport`. The solver consumes both.
3. `Cycle.Form`. This decides whether the solver iterates or solves exactly, so it comes before
   either.
4. **Direct linear solve.** Covers circular interest, cash sweeps and gross-ups — the whole
   motivating case — exactly, with no convergence question.
5. `IterativeSolver` proper, for the nonlinear remainder.
6. Prior-period reference, separately — and only then is the circular-interest tutorial a true
   document.

Building 5 before 4 would ship an approximate, tolerance-dependent, order-sensitive answer to a
problem that has an exact one. That is the wrong trade, and it is worth saying even though it makes
this proposal the second thing built rather than the first.
