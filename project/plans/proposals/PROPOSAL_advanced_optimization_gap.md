# Design Proposal — the Advanced Optimization gap, verified

**Status:** proposal, 2026-09-07. Written after auditing `project/plans/upcoming/optimizations/`
against the source, because the roadmap's status lines and the repository disagree in **both**
directions.
**Phase:** 0 (Design) for the six algorithms that are genuinely absent.
**Supersedes:** the status lines in `upcoming/optimizations/Roadmap.md`. The seven detailed
implementation plans beside it stay authoritative for *how* each algorithm works; this proposal
fixes *what is actually missing*, *why the priority order should change*, and the contracts all
six share.

---

## 1. Objective

The Advanced Optimization roadmap was written 2026-01-31 and lists nine phases, all marked
**Not Started**. Before implementing against it, two questions needed answering:

1. Is any of it already implemented and merely unrecorded?
2. Is the priority order still right, given what BusinessMath is now used for?

The answer to (1) is **yes for one phase and no for the rest**, and the answer to (2) is **no** —
one Tier 3 item has acquired a correctness argument it did not have in January, which moves it.

---

## 2. What was verified, and how

Method, so it is reproducible and so a future reader can distrust it properly:

```bash
# Presence in source
grep -rl "<algorithm identifiers>" Sources/

# Ever present, on any branch, including deleted code
git log --all --oneline -S"<identifier>" -- Sources/
```

The second command is the one that matters. It answers "was this ever written and then lost to
housekeeping?" — not "is it here now."

| Roadmap phase | Files in `Sources/` | Commits ever, all branches | Verdict |
|---|---:|---:|---|
| 1 — SQP | 0 | **0** | genuinely absent |
| 2 — Interior Point | 0 | **6** — see §2.2 | absent now, but **removed on purpose**, not never-written |
| 3 — MINLP | 4 | — | **substantially present** — §3.1 |
| 4 — Convexity Detection | 0 (5 incidental "convexity" hits: 2 bond convexity, 3 passing comments in `DEASolver`, `CuttingPlaneMaster`, `SimplexSolver`) | 0 | genuinely absent |
| 5 — ADMM | 0 | **0** | genuinely absent |
| 6 — GRG | 0 | **0** | genuinely absent |
| 7 — Network Flow | 0 | **0** | genuinely absent |
| 8 — Deterministic Global | 0 | **0** | genuinely absent |
| 9 — Dynamic Programming | 0 | **0** | genuinely absent |

Zero commits across every branch for SQP, ADMM, GRG, NetworkFlow, Hungarian, Bellman and
McCormick. **For those seven this is not a filing problem** — the code was never written.

Interior Point is the exception, and §2.2 corrects it.

### 2.2 Correction — Interior Point was written, and deliberately removed

Added 2026-09-08, on an independent re-check of this section.

The original audit searched for the identifier `InteriorPoint` and found nothing. That was the
wrong search: the method is not usually named after itself in code, it is named after its
mechanism. Searching for the mechanism finds it —

```bash
git log --all --oneline -S"logBarrier" -- Sources/     # 6 commits
```

`InequalityOptimizer` carried a full log-barrier interior-point method:

```
L(x,λ,μ,ρ) = f(x) + Σλᵢhᵢ(x) + (μ/2)Σhᵢ(x)² − ρΣlog(−gⱼ(x))
```

with `initialBarrier`, `barrierEpsilon` and `optimizeWithPenaltyBarrier`. It was removed on
**2025-12-12** by `14d75899`, whose subject states the reason: *"remove Barrier Method in favor
of Quadratic Penalty for Interior Optima."*

**The verdict in the table is unchanged — Interior Point is absent today.** What changes is what
Phase 2 *is*. It is not greenfield work; it is reversing a considered decision made ten months
ago by someone who had the barrier method working and preferred the quadratic penalty. Anyone
picking up Phase 2 should read `14d75899` first and be able to say what they would do
differently, or they will rediscover whatever drove the removal.

The lesson generalises to the rest of this audit, and is the same one §3.1 records about MINLP:
**searching for an algorithm's name finds only the implementations that were named after it.**
The seven remaining absences were re-checked by mechanism as well as by name — QP subproblems,
central path and barrier parameters, reduced gradients, min-cost flow and assignment, proximal
and Douglas–Rachford splitting, Hessian definiteness tests — and all seven stayed at zero.

The roadmap's own "Current Capabilities" list — gradient descent, Newton-Raphson, L-BFGS,
augmented Lagrangian, Simplex, branch-and-bound, the heuristics, multi-start — is accurate, and
verified present. That is the January/February work.

### 2.1 The `Optimization/` inventory, for the record

Present and working: `SimplexSolver` (48K) with `dualValues` and `reducedCosts`,
`BranchAndBound` (101K) with cutting planes and branch-and-cut, `ConstrainedOptimizer`,
`InequalityOptimizer`, `MultivariateLBFGS`, `MultivariateNewtonRaphson`,
`MultivariateGradientDescent`, `AsyncConjugateGradientOptimizer`, `MultiStartOptimizer`,
`ParallelOptimizer`, `NelderMead`, `GeneticAlgorithm`, `DifferentialEvolution`,
`ParticleSwarmOptimization`, `SimulatedAnnealing`, `IslandModel`, `KMeansClustering`,
`SparseMatrix`/`SparseSolver`, `DEASolver`, `CuttingPlaneMaster`, plus `AdvancedOptimization/`
(`RobustOptimizer` 40K, `StochasticOptimizer`, `ScenarioOptimizer`, `MultiPeriodOptimizer`).

---

## 3. Two housekeeping corrections — documentation, not code

The audit found drift in the opposite direction from the one suspected: the docs **understate**
what exists.

### 3.1 MINLP (Phase 3) is substantially done, and marked Not Started

`BranchAndBound` already takes a pluggable relaxation:

```swift
public let relaxationSolver: any RelaxationSolver
public init(..., relaxationSolver: (any RelaxationSolver)? = nil, ...)
// Defaults to SimplexRelaxationSolver for backward compatibility
```

and `NonlinearRelaxationSolver` already implements that protocol by wrapping `InequalityOptimizer`,
with its own doc comment reading *"Used for NLP relaxations in MINLP (Mixed-Integer Nonlinear
Programming)."*

So mixed-integer nonlinear programming works **today**:

```swift
let solver = BranchAndBound(relaxationSolver: NonlinearRelaxationSolver())
```

The roadmap's Phase 3 deliverable was "`MINLPSolver` extending `BranchAndBound`, replace Simplex
relaxation with SQP relaxation." The architecture chosen — a pluggable `RelaxationSolver` protocol
— is *better* than the one specified, because it makes the node solver a parameter rather than a
subclass. What is genuinely missing is only that the node solver is augmented-Lagrangian rather
than SQP, which is a quality-of-relaxation question, not a capability gap.

**Why the roadmap never learned this.** Both `RelaxationSolver.swift` and
`NonlinearRelaxationSolver.swift` entered in commit `fb626e3a`, whose message is
*"Package Fix Attempt 1 for CI"*. A capability shipped inside a housekeeping commit, so nothing
downstream — changelog, roadmap, release notes — was prompted to notice. That is the mechanical
cause of this whole audit, and it is worth naming: the doc-housekeeping rule catches drift at
release time, but a feature landing under a chore message evades the prompt that would have
started it.

**Action:** mark Phase 3 **Done (with a caveat)** in `Roadmap.md`; restate the remaining work as
"supply `SQPRelaxationSolver` once SQP exists" and fold it into Phase 1's deliverables. Add a
named convenience so the capability is discoverable — nobody finds it at present:

```swift
extension BranchAndBoundSolver {
    /// Branch-and-bound over a nonlinear relaxation — mixed-integer nonlinear programming.
    public static func minlp(...) -> BranchAndBoundSolver<V>
}
```

Shipped 2026-09-07 in `BranchAndBoundSolver+MINLP.swift`. Two things learned in the writing,
recorded because they bear on how the entry point should be used:

- The cut-generation parameters are **inert** under a nonlinear relaxation.
  `BranchAndBound.swift:958` gates cut generation on `RelaxationResult.simplexResult`, and
  `NonlinearRelaxationSolver` never supplies one — Gomory, MIR and cover cuts are all read off a
  simplex tableau that an NLP relaxation does not produce. Whether they belong on the factory's
  signature at all is §10.4.
- `validateLinearity: true` **rejects exactly the models this entry point exists for**, with
  `OptimizationError.nonlinearModel`. Documented as a trap on the symbol.

### 3.2 `NonsmoothOptimization.md` shipped but never moved

`project/plans/proposals/NonsmoothOptimization.md` still sits in `proposals/`, while
`Optimization/Nonsmooth/CuttingPlaneMaster.swift` shipped in `f1e70490`
(*"feat(nonsmooth): a cutting-plane master, and a check on its own assumption"*).

**Action:** move it to `project/plans/completed/`. This is exactly the drift the global doc
housekeeping rule exists to catch, and it is the one the suspicion was right about.

---

## 4. Re-prioritisation: GRG is not a marketing item

This is the substantive disagreement with the January roadmap.

`Roadmap.md` and `GRG.md` both frame GRG as Tier 3, its value as *"Marketing value for Excel
Solver parity"*, and explicitly: *"Functionally redundant with SQP (SQP is generally better)."*
On the mathematics that is correct. On the use BusinessMath has acquired since January, it is not.

**The argument the January roadmap could not have made.** `SwiftExcelFunctions` now treats Excel
as the specification (its ADR-001) and tests against workbooks' own cached values — 155,897 cells
at 99.60% agreement. A workbook that ran Excel Solver carries the answer Excel's **GRG2** found.

On a nonconvex problem, SQP and GRG converge to *different local optima*, both correct, neither
reproducing the other. So for any workbook whose recorded solution came from Excel Solver:

- SQP gives **an** optimum. Defensible, and unverifiable against the file.
- GRG gives **the** optimum Excel found. Checkable against a cached value.

That converts GRG from a marketing line into the only algorithm in this set that can be tested
against the oracle corpus. `PsiOptValue`, `PsiFinalValue` and the sensitivity family
(`PsiSenValue`, `PsiDualValue`, `PsiSlackValue`) all read back numbers a Frontline engine
produced, and reproducing them is a correctness claim, not a compatibility boast.

It does not become Tier 1 — SQP is still the better general-purpose algorithm and still goes
first, because GRG's active-set machinery reuses SQP's line search and KKT test. But it moves
ahead of Convexity Detection and ADMM, and its success criteria change: **agreement with a
recorded Excel result**, not just convergence.

### 4.1 Revised order

| Order | Phase | Was | Why it moved |
|---|---|---|---|
| 1 | **SQP** | Tier 1 ⭐⭐⭐⭐⭐ | unchanged — unblocks MINLP-proper, GRG and Convexity |
| 2 | **GRG** | Tier 3 ⭐⭐⭐ | §4 — oracle-testable; reuses SQP's line search and KKT test |
| 3 | **Interior Point** | Tier 1 ⭐⭐⭐⭐⭐ | unchanged in rank, second in time — scale is a real ceiling |
| 4 | **Network Flow** | Tier 3 optional ⭐⭐⭐ | promoted — self-contained, no dependencies, and the Operations module (inventory only today) is the natural caller |
| 5 | Convexity Detection | Tier 2 ⭐⭐⭐⭐ | unchanged |
| 6 | ADMM | Tier 2 ⭐⭐⭐⭐ | unchanged |
| — | Global, Dynamic Programming | Tier 3 optional | **defer indefinitely**; §9 |

MINLP leaves the list (§3.1). SQP's deliverables absorb `SQPRelaxationSolver`.

---

## 5. Shared contracts

All six new optimizers conform to the existing idiom rather than inventing one. The types they
must fit already exist and are load-bearing:

```swift
public enum MultivariateConstraint<V: VectorSpace>: Sendable where V.Scalar: Real, V: Sendable {
    case equality(function: @Sendable (V) -> V.Scalar, gradient: (@Sendable (V) -> V)?)
    case inequality(...)
}

public struct ConstrainedOptimizationResult<V: VectorSpace> where V.Scalar: Real {
    public let solution: V
    public let objectiveValue: V.Scalar
    public let lagrangeMultipliers: [V.Scalar]
    public let iterations: Int
}
```

`lagrangeMultipliers` is the seam that matters downstream: it is what `PsiDualValue` and
`PsiSenValue` read. Every new constrained optimizer populates it, and any that cannot must say so
in its result rather than returning zeros.

### 5.1 Proposed API

Matching `InequalityOptimizer`'s init idiom — tolerances and iteration caps as defaulted
parameters, no hidden global state, `Sendable` throughout.

```swift
/// Sequential quadratic programming. The recommended general-purpose constrained optimizer.
public struct SQPOptimizer<V: VectorSpace>: Sendable where V.Scalar: Real, V: Sendable {
    public init(
        constraintTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
        gradientTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
        maxIterations: Int = 100,
        hessianApproximation: HessianApproximation = .bfgs,
        meritFunction: MeritFunction = .l1
    )

    public func optimize(
        objective: @Sendable (V) -> V.Scalar,
        gradient: (@Sendable (V) -> V)? = nil,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V
    ) throws -> ConstrainedOptimizationResult<V>
}

/// Generalized reduced gradient — the Excel Solver algorithm.
///
/// Chosen over `SQPOptimizer` when the goal is to *reproduce* a result Excel Solver
/// recorded, rather than to find a good one. On nonconvex problems the two converge
/// to different local optima and neither is wrong.
public struct GRGOptimizer<V: VectorSpace>: Sendable where V.Scalar: Real, V: Sendable {
    public init(
        constraintTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
        convergenceTolerance: V.Scalar = V.Scalar(1) / V.Scalar(10_000),  // Excel's default
        maxIterations: Int = 100,
        multistart: MultistartPolicy = .off,
        derivatives: DerivativeMode = .forward                            // Excel's default
    )

    public func optimize(...) throws -> ConstrainedOptimizationResult<V>

    /// Basic/nonbasic split at the solution. Excel exposes this in its sensitivity report.
    public struct Partition: Sendable {
        public let basic: [Int], nonbasic: [Int], superbasic: [Int]
    }
}

/// Primal-dual interior point for LP and convex QP. Scales where Simplex degrades.
public struct InteriorPointSolver: Sendable {
    public init(tolerance: Double = 1e-8, maxIterations: Int = 100, centeringParameter: Double = 0.1)
    public func solveLP(...) throws -> LPResult      // duals, as SimplexSolver does
    public func solveQP(...) throws -> QPResult
}

/// Min-cost flow, max flow, shortest path, assignment.
public struct NetworkFlowSolver: Sendable {
    public func shortestPath(from: Node, to: Node, in: Graph) throws -> Path
    public func maxFlow(from: Node, to: Node, in: Graph) throws -> FlowResult
    public func minCostFlow(in: Graph) throws -> FlowResult
    public func assignment(cost: Matrix) throws -> Assignment   // Hungarian
}
```

`DerivativeMode.forward` and `convergenceTolerance` defaulting to 1e-4 are deliberate: they are
Excel's defaults, and §4's reproducibility argument only holds if the defaults match. This is the
same discipline as `master_plan.md`'s recorded Psi traps — a parameter that silently differs
produces a plausible wrong number.

---

## 6. Error handling

Existing rules, no exceptions: no force unwraps, no `try!`, guard-clause validation, division
checked. Three additions specific to this set.

**Non-convergence is a result, not a throw.** An optimizer that hits `maxIterations` returns its
best point with a `convergence` field saying so. Throwing discards work the caller may want, and
Excel Solver itself reports "Solver could not find a feasible solution" as an outcome.

```swift
public enum OptimizationOutcome: Sendable, Equatable {
    case converged(iterations: Int)
    case iterationLimit(best: /* objective */ Double)
    case infeasible(maxViolation: Double)
    case unbounded
    case numericalFailure(reason: String)
}
```

**Throw only for malformed input** — dimension mismatch between guess and constraints, an empty
constraint function, a non-finite initial point. These are programmer errors and should be loud.

**Never return zeroed multipliers as if computed.** `lagrangeMultipliers` is read downstream as
sensitivity information; an optimizer that did not compute them returns `[]`, not `[0, 0, 0]`.
This is the same class of failure as §5.1's defaults — a plausible number is worse than an absence.

---

## 7. Test strategy

**Differential against the existing stack.** Every new constrained optimizer solves the same
problems as `InequalityOptimizer` and must agree on convex cases to tolerance. On convex problems
the local optimum is the global one, so disagreement is a bug in exactly one of them — and that
test also protects the incumbent.

**Reference problems, quoted not derived.** Rosenbrock with constraints, Hock-Schittkowski, and
the netlib LP set. Expected values come from the published problem statements. A test whose
expected value was produced by the implementation proves only that it is self-consistent.

**GRG's own gate — the one that justifies §4.** A corpus workbook that ran Excel Solver, with
its recorded solution, and GRG must reproduce it within Excel's own convergence tolerance. This
requires fixtures from `SwiftExcelFunctions`' corpus and is the acceptance criterion for GRG.
If it cannot be met, §4's argument fails and GRG returns to Tier 3 where January put it — that
outcome should be recorded, not quietly dropped.

**Scale, for Interior Point.** The roadmap's target is 10,000 variables in under a second.
Benchmark against `SimplexSolver` across scales and publish the crossover point, which is the
number that tells a caller which to use.

**Determinism.** Multistart and any stochastic component takes an explicit seed. `SplitMix64` and
`DeterministicRNG` exist; use them. Two runs at one seed produce identical results or the test
fails.

**Property tests.** KKT conditions hold at every reported solution; a feasible returned point is
actually feasible; `maxFlow` equals min-cut on random graphs.

---

## 8. Performance

Targets carried from the roadmap, with the instrument named. `PerformanceBenchmark.swift` exists
and these register there.

| Algorithm | Target | Note |
|---|---|---|
| SQP | ≤50% of augmented Lagrangian's iterations | on the shared differential set |
| Interior Point | 10,000-var LP < 1s | publish the Simplex crossover |
| GRG | within 2–3× of SQP | slower is acceptable; §4 is not a speed argument |
| Network Flow | ≫ general LP on network problems | vs `SimplexSolver` on the same instance |

Two watch items. `SparseMatrix`/`SparseSolver` already exist and Interior Point must use them —
a dense factorisation at 10,000 variables defeats the purpose. And every optimizer here is a
candidate for `ParallelOptimizer` and the existing Metal path; none should be written in a way
that forecloses it, but none should be parallelised before it is correct.

---

## 9. Deferring Global Optimization and Dynamic Programming

Recorded rather than silently dropped, per the roadmap-housekeeping rule.

**Deterministic Global (Phase 8)** — 4–5 weeks, needs SQP and Convexity first, and delivers
guaranteed global optima for a narrow class. January already said *"Consider deferring."* Agreed,
and made explicit: not without a specific caller asking.

**Dynamic Programming (Phase 9)** — `MultiPeriodOptimizer`, `ScenarioOptimizer` and
`StochasticOptimizer` already cover much of the motivating use (multi-period allocation under
uncertainty). A Bellman formulation would be cleaner but is not new capability. Defer.

If either ships anyway, the note above should be struck through and left visible with the reason
recorded, rather than deleted.

---

## 10. Open questions

1. **Does SQP subsume GRG for the oracle test?** §4 assumes the two find different optima often
   enough for it to matter. Testable cheaply once SQP exists: run both on corpus Solver models and
   count the disagreements. **If SQP reproduces Excel's answers, GRG drops back to Tier 3** and
   §4 is wrong — resolve this before writing GRG, not after.
2. **Which `VectorSpace` conformances need sparse support** before Interior Point is useful at
   10,000 variables? `SparseMatrix` exists; whether `VectorN` is the right vector type at that
   scale is unresolved.
3. **Does `NonlinearRelaxationSolver` want SQP badly enough** to reorder anything? It works now
   with augmented Lagrangian (§3.1); the question is relaxation quality at branch-and-bound nodes,
   which is measurable on the existing MINLP portfolio model.
4. **Should `minlp()` mirror all 29 parameters, or only the ones that do something?**
   It currently mirrors every one, so `.minlp()` is *exactly* the composition it names — nothing
   hidden, nothing foreclosed. The cost is roughly fifteen cut-generation knobs that are provably
   inert (§3.1), on an entry point whose entire purpose is discoverability. A caller who sets
   `enableMIRCuts: true` and sees no effect has been misled by the API, which is the failure this
   change existed to fix. Dropping them forecloses nothing, since an inert parameter has no
   behaviour to lose. Recommend trimming to the effective set; deferred rather than done because
   the current version is tested and gate-clean, and this is a judgment call about surface, not a
   defect.

5. **Do the Excel defaults in §5.1 match current Excel for Mac**, or the version the corpus
   workbooks were saved from? Convergence 1e-4 and forward derivatives are Excel Solver's
   documented defaults; whether every corpus workbook used them is not knowable from the file, and
   §7's GRG gate has to tolerate that.

---

## 11. Documentation

Per phase: DocC on every public symbol, one tutorial in the numbered series (5.26+ as the roadmap
allocates), and at least two worked examples.

Three cross-cutting documents matter more than the per-algorithm tutorials:

- **"Choosing an optimizer"** — a selection flowchart. Six new entry points on top of the existing
  fifteen is the point at which a caller cannot choose without help, and that is a real risk of
  this proposal.
- **"Excel Solver migration"** — the GRG tutorial's second half, and the place where §4's
  reproducibility argument is stated honestly, including when SQP is the better choice.
- **`Roadmap.md` reconciled** — Phase 3 marked done with its caveat, the §4.1 order applied, §9's
  deferrals struck through rather than deleted, and Last Updated bumped with what was reconciled.

---

## 12. Sequencing

| # | Deliverable | Ends when |
|---|---|---|
| **0** | §3 housekeeping: `Roadmap.md` Phase 3, move `NonsmoothOptimization.md`, add `BranchAndBound.minlp` | The docs match the code. Hours, not days |
| **1** | Open question 10.1: do SQP and GRG disagree on corpus models? | GRG's priority is settled by evidence |
| **2** | SQP + `SQPRelaxationSolver` | §7 differential and reference sets pass |
| **3** | GRG, gated on §7's oracle test | A recorded Excel solution is reproduced — or 10.1 is answered no and this is dropped |
| **4** | Interior Point, sparse | 10,000-var LP under a second, crossover published |
| **5** | Network Flow | Hungarian and min-cost flow beat general LP on the same instances |
| **6** | Convexity Detection, then ADMM | Per the January plans, unchanged |

Step 0 costs almost nothing and stops the next reader repeating this audit. Step 1 costs little
and decides whether step 3 happens at all.

---

**Next action:** step 0. The code is right and the documents are wrong, which is the cheapest
category of defect to fix and the most expensive to leave.
