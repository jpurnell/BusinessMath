# Advanced Optimization Roadmap

**Status**: Planning
**Start Date**: 2026-01-31
**Last Updated**: 2026-09-07 — reconciled against the source per
[PROPOSAL_advanced_optimization_gap.md](../../proposals/PROPOSAL_advanced_optimization_gap.md).
Phase 3 (MINLP) marked **Done (with caveat)** — it shipped and was never recorded; the other eight
phases were verified genuinely absent (§ "Verification"); the priority order was revised (GRG moves
from position 6 to position 2, Network Flow to position 4); Phases 8 and 9 were deferred
indefinitely. Superseded January text is struck through, not deleted.
**Target Completion**: Q2-Q3 2026
**Strategic Goal**: Position BusinessMath as the premier Swift optimization library with capabilities exceeding Excel Solver and approaching commercial solvers.

---

## Executive Summary

This roadmap extends BusinessMath's optimization capabilities from current state (gradient descent, Newton-Raphson, L-BFGS, augmented Lagrangian, branch-and-bound) to cover industry-standard algorithms for all major optimization problem classes.

**Current Capabilities** (✅ Implemented):
- Unconstrained optimization: Gradient Descent, Newton-Raphson, L-BFGS
- Equality-constrained: Augmented Lagrangian (`ConstrainedOptimizer`)
- Inequality-constrained: Augmented Lagrangian + Penalties (`InequalityOptimizer`)
- Linear programming: Simplex method
- Integer programming: Branch-and-bound with cutting planes
- Heuristics: Simulated Annealing, Nelder-Mead, Genetic Algorithm, K-Means
- Parallel: Multi-start optimization, parallel branch-and-bound

**Gap Analysis** - What We're Missing (as revised 2026-09-07):
- ❌ Industry-standard constrained optimization (SQP)
- ❌ Large-scale optimization (Interior Point)
- ~~❌ Nonlinear integer programming (MINLP)~~ → ✅ **shipped**; `BranchAndBound` takes a pluggable
  `RelaxationSolver` and `NonlinearRelaxationSolver` implements it. See Phase 3.
- ❌ Automatic convex optimization
- ❌ Modern parallel/distributed methods (ADMM)
- ❌ Excel Solver parity (GRG)

---

## Verification (2026-09-07) — do not repeat this audit

Every "Not Started" line below was checked against the repository, not against memory. Two commands:

```bash
grep -rl "<identifier>" Sources/                      # present now
git log --all --oneline -S"<identifier>" -- Sources/  # ever present, any branch, including deleted code
```

The second is the one that matters — it answers "was this written and then lost to housekeeping?"
rather than "is it here today."

| Phase | Identifier searched | Files in `Sources/` | Commits ever, all branches | Verdict |
|---|---|---:|---:|---|
| 1 — SQP | `SQPOptimizer` | 0 | **0** | genuinely absent |
| 2 — Interior Point | `InteriorPoint` | 0 | **0** | genuinely absent |
| 3 — MINLP | `RelaxationSolver` | 4 | — | **substantially present** — see Phase 3 |
| 4 — Convexity Detection | `ConvexityAnalyzer` | 0 (5 false hits on "convexity"; see Phase 4) | **0** | genuinely absent |
| 5 — ADMM | `ADMM` | 0 | **0** | genuinely absent |
| 6 — GRG | `GRGOptimizer` | 0 | **0** | genuinely absent |
| 7 — Network Flow | `NetworkFlow`, `Hungarian` | 0 | **0** | genuinely absent |
| 8 — Deterministic Global | `McCormick` | 0 | **0** | genuinely absent |
| 9 — Dynamic Programming | `Bellman` | 0 | **0** | genuinely absent |

Zero commits across every branch and worktree for SQP, InteriorPoint, ADMM, GRG, NetworkFlow,
Hungarian, Bellman and McCormick. **This was not a filing problem — the code was never written**,
and the "Not Started" status on those eight phases is correct as it stands.

The "Current Capabilities" list above was checked the same way and is accurate.

---

## Strategic Priorities

### Revised implementation order (2026-09-07)

The tiers below are January's, and the ⭐ ratings are kept as written. This table is the order work
should actually happen in; where it disagrees with a tier, the table wins and the phase entry says
why.

| Order | Phase | January's placement | Why it moved |
|---|---|---|---|
| 1 | **SQP** | Tier 1 ⭐⭐⭐⭐⭐ | unchanged — unblocks GRG, Convexity, and MINLP-proper |
| 2 | **GRG** | Tier 3 ⭐⭐⭐ | **promoted** — the only algorithm here testable against the Excel oracle corpus; reuses SQP's line search and KKT test. See Phase 6 |
| 3 | **Interior Point** | Tier 1 ⭐⭐⭐⭐⭐ | unchanged in rank, second in time — scale is a real ceiling |
| 4 | **Network Flow** | Tier 3, optional ⭐⭐⭐ | **promoted** — self-contained, no dependencies, and the Operations module (inventory only today) is the natural caller |
| 5 | Convexity Detection | Tier 2 ⭐⭐⭐⭐ | unchanged |
| 6 | ADMM | Tier 2 ⭐⭐⭐⭐ | unchanged |
| — | ~~Deterministic Global, Dynamic Programming~~ | Tier 3, optional | **deferred indefinitely** — Phases 8 and 9 |

MINLP leaves this list: it shipped (Phase 3). Its remaining work — `SQPRelaxationSolver` — is
folded into Phase 1's deliverables.

**Before GRG is written**, settle the open question its promotion rests on: run SQP and GRG on the
corpus's Solver models and count how often they disagree. If SQP already reproduces Excel's
answers, the argument in Phase 6 is wrong and GRG returns to Tier 3 where January put it. That
outcome gets recorded here, not quietly dropped.

---

### Tier 1: Critical Path - Industry Standard Algorithms
**Goal**: Match or exceed capabilities of MATLAB's Optimization Toolbox and SciPy.optimize

#### Phase 1: SQP - Sequential Quadratic Programming
**File**: [SQP.md](./SQP.md)
**Priority**: ⭐⭐⭐⭐⭐ (Highest)
**Effort**: 2-3 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `SQPOptimizer`)
**Order**: 1 of 6
**Dependencies**: None (uses existing infrastructure)
**Value**: Becomes primary constrained optimizer, industry standard

**Rationale**: SQP is **the** algorithm for nonlinear constrained optimization. Used by MATLAB, SciPy, commercial solvers. Better than our current augmented Lagrangian for most problems. This should be implemented first.

**Deliverables**:
- `SQPOptimizer<V: VectorSpace>` in `Sources/BusinessMath/Optimization/Algorithms/`
- **`SQPRelaxationSolver`** — conforms to the existing `RelaxationSolver` protocol so
  `BranchAndBound` can use SQP at its nodes. *(Absorbed from Phase 3, 2026-09-07: MINLP already
  works with a nonlinear relaxation; upgrading the node solver from augmented Lagrangian to SQP is
  all that Phase 3 has left, and it cannot start until SQP exists.)*
- Tutorial: `5.26-SQPOptimizationTutorial.md`
- Tests: Rosenbrock with constraints, portfolio optimization comparison; plus a relaxation-quality
  comparison of `SQPRelaxationSolver` against `NonlinearRelaxationSolver` on the existing MINLP
  portfolio model
- Documentation updates to position SQP as recommended method

---

#### Phase 2: Interior Point Methods
**File**: [InteriorPoint.md](./InteriorPoint.md)
**Priority**: ⭐⭐⭐⭐⭐ (Highest)
**Effort**: 3-4 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `InteriorPoint`)
**Order**: 3 of 6 — unchanged in rank, third in time; GRG now precedes it
**Dependencies**: None
**Value**: Unlocks large-scale problems (10,000+ variables)

**Rationale**: Modern algorithm that scales where Simplex struggles. Essential for institutional portfolio optimization, large production planning. Differentiates from Excel Solver.

**Deliverables**:
- `InteriorPointSolver` for linear programming
- Extension to convex quadratic programming (QP)
- Tutorial: `5.27-InteriorPointTutorial.md`
- Benchmarks vs Simplex at various scales
- Large-scale portfolio optimization example (1,000+ securities)

---

#### Phase 3: MINLP - Mixed-Integer Nonlinear Programming
**File**: [MINLP.md](./MINLP.md)
**Priority**: ⭐⭐⭐⭐⭐ (Highest)
**Effort**: 2-3 weeks
**Status**: ~~Not Started~~ → ✅ **Done (with caveat)** — corrected 2026-09-07
**Dependencies**: ~~SQP.md (uses SQP as NLP solver at branch-and-bound nodes)~~ — none; it shipped
without SQP, using the augmented-Lagrangian `InequalityOptimizer` at the nodes
**Value**: New problem class - discrete + nonlinear

**Rationale**: Natural extension of existing branch-and-bound (linear integer) to nonlinear. Opens up facility location, production scheduling with economies of scale. Rare capability.

**What actually shipped.** `BranchAndBound` takes a pluggable relaxation:

```swift
public let relaxationSolver: any RelaxationSolver
public init(..., relaxationSolver: (any RelaxationSolver)? = nil, ...)
// defaults to SimplexRelaxationSolver, preserving the linear behaviour
```

`Sources/BusinessMath/Optimization/IntegerProgramming/` holds `RelaxationSolver.swift`,
`SimplexRelaxationSolver.swift` and `NonlinearRelaxationSolver.swift`, the last of which wraps
`InequalityOptimizer` and whose own doc comment reads *"Used for NLP relaxations in MINLP
(Mixed-Integer Nonlinear Programming)."* So mixed-integer nonlinear programming works **today**:

```swift
let solver = BranchAndBound(relaxationSolver: NonlinearRelaxationSolver())
```

It is already documented and exercised in `5.8-IntegerProgramming.md` (three call sites, one
commented *"Enable MINLP!"*) and `5.8b-IntegerProgrammingInPractice.md`.

**Why this roadmap missed it.** The protocol and both conformances entered in `fb626e3a`, whose
message is *"Package Fix Attempt 1 for CI"* — a capability landed inside a housekeeping commit and
nothing pointed back here. That is the failure mode, not the code.

**The design that was built is better than the one specified.** January called for `MINLPSolver`
*extending* `BranchAndBound` with the Simplex relaxation *replaced* by SQP. What exists instead
makes the node solver a **parameter** rather than a subclass, so branch-and-bound has one
implementation, linear and nonlinear relaxations are peers, and `SQPRelaxationSolver` will drop in
later without touching `BranchAndBound` at all. The specified design would have forked the
branch-and-cut machinery in two. Recorded here because the plan was wrong in the useful direction
and should not be quietly restated as if it had said this.

**The caveat**: the node solver is augmented Lagrangian, not SQP. That is a
quality-of-relaxation question — weaker bounds, more nodes explored — not a capability gap.

**Remaining work** (all of it moved elsewhere):
- ~~`MINLPSolver` extending `BranchAndBound`~~ — superseded by the `RelaxationSolver` protocol
- ~~Replace Simplex relaxation with SQP relaxation~~ → **supply `SQPRelaxationSolver` once SQP
  exists**; folded into Phase 1's deliverables
- Discoverability: nobody finds this capability at present. A named convenience —
  `BranchAndBound.minlp(...)` — and a mention in the optimizer-selection guide
- Tutorial: `5.28-MINLPTutorial.md` — still owed, though `5.8`/`5.8b` cover the mechanics
- Example: Facility location with fixed costs + nonlinear shipping costs — still owed

---

### Tier 2: High-Value Enhancements

#### Phase 4: Automatic Convexity Detection
**File**: [ConvexityDetection.md](./ConvexityDetection.md)
**Priority**: ⭐⭐⭐⭐
**Effort**: 2-3 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `ConvexityAnalyzer`. A
case-insensitive `grep` for "convexity" in `Sources/` returns five files, none of them a detector:
two are bond convexity (`BondPricing`, `CallableBond`) and three are passing mentions in comments
in `DEASolver`, `CuttingPlaneMaster` and `SimplexSolver`)
**Order**: 5 of 6
**Dependencies**: SQP.md, InteriorPoint.md
**Value**: Automatic 10-100× speedup for convex problems

**Rationale**: Many finance problems are convex (portfolio optimization, risk minimization). Detecting convexity allows using specialized fast solvers. Professional polish.

**Deliverables**:
- `ConvexityAnalyzer` for symbolic/heuristic detection
- Automatic dispatch: convex → Interior Point, nonconvex → SQP
- Tutorial: `5.29-ConvexOptimizationTutorial.md`
- CVX-style API: `minimize { ... } subjectTo { ... }` DSL

---

#### Phase 5: ADMM - Alternating Direction Method of Multipliers
**File**: [ADMM.md](./ADMM.md)
**Priority**: ⭐⭐⭐⭐
**Effort**: 3-4 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `ADMM`)
**Order**: 6 of 6
**Dependencies**: ConvexityDetection.md (ADMM primarily for convex problems)
**Value**: Modern parallel/distributed optimization, multi-period decomposition

**Rationale**: Trendy algorithm in ML/quant community. Decomposes large problems. Excellent for multi-period portfolio optimization with coupling constraints.

**Deliverables**:
- `ADMMOptimizer` with consensus/sharing/generalized forms
- Parallel actor-based implementation (Swift 6 concurrency)
- Tutorial: `5.30-ADMMTutorial.md`
- Example: Multi-period portfolio optimization with transaction costs

---

### Tier 3: Excel Parity & Specialized

#### Phase 6: GRG - Generalized Reduced Gradient
**File**: [GRG.md](./GRG.md)
**Priority**: ⭐⭐⭐ (rating unchanged; **position changed** — see below)
**Effort**: 2-3 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `GRGOptimizer`)
**Order**: **2 of 6** — promoted from position 6 on 2026-09-07
**Dependencies**: ~~None~~ — SQP in practice: GRG's active-set machinery reuses SQP's line search
and KKT test, which is why it stays behind SQP rather than going first
**Value**: ~~Excel Solver compatibility, user migration~~ → **the only algorithm in this set that
can be tested against the Excel oracle corpus**

**Rationale (January 2026, superseded)**: ~~Marketing value for Excel Solver parity. Functionally
redundant with SQP (SQP is generally better), but familiar to finance users. Implement after SQP so
we can position as "traditional" vs "modern" method.~~

**Why that assessment reversed (2026-09-07).** The mathematics in January's note is still correct —
SQP is the better general-purpose algorithm and GRG is redundant *as an optimizer*. What changed is
what BusinessMath is used for, which January could not have known.

`SwiftExcelFunctions` now treats Excel as the specification (its ADR-001) and tests against
workbooks' own cached values — 155,897 cells at 99.60% agreement. A workbook that ran Excel Solver
carries the answer Excel's **GRG2** engine found. On a nonconvex problem SQP and GRG converge to
*different local optima*, both correct, neither reproducing the other. So for any workbook whose
recorded solution came from Excel Solver:

- SQP gives **an** optimum — defensible, and unverifiable against the file.
- GRG gives **the** optimum Excel found — checkable against a cached value.

`PsiOptValue`, `PsiFinalValue` and the sensitivity family (`PsiSenValue`, `PsiDualValue`,
`PsiSlackValue`) all read back numbers a Frontline engine produced. Reproducing them is a
correctness claim, not a compatibility boast — which is precisely what "marketing value" got wrong.
GRG does not become Tier 1; it moves ahead of Convexity Detection and ADMM.

**Deliverables**:
- `GRGOptimizer<V: VectorSpace>`
- Reduced gradient projection algorithm
- Active set tracking, exposing the basic/nonbasic/superbasic partition Excel shows in its
  sensitivity report
- **Excel's defaults, deliberately**: convergence tolerance 1e-4, forward derivatives. The
  reproducibility argument above only holds if the defaults match; a parameter that silently
  differs produces a plausible wrong number.
- Tutorial: `5.31-GRGTutorial.md` (include Excel migration guide, and state honestly when SQP is
  the better choice)
- Comparison: GRG vs SQP performance benchmarks. Target: within 2–3× of SQP. Slower is acceptable —
  none of the above is a speed argument.

**Acceptance criterion (new, and the one that justifies the promotion)**: a corpus workbook that
ran Excel Solver, with its recorded solution, reproduced within Excel's own convergence tolerance.
Requires fixtures from `SwiftExcelFunctions`' corpus. **If it cannot be met, the argument above
fails and GRG returns to Tier 3 where January put it** — and that outcome is recorded here rather
than quietly dropped.

---

#### Phase 7: Network Flow Optimization ~~(Optional)~~
**File**: [NetworkFlow.md](./NetworkFlow.md)
**Priority**: ⭐⭐⭐
**Effort**: 2-3 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `NetworkFlow` or `Hungarian`)
**Order**: **4 of 6** — promoted from optional on 2026-09-07: it is entirely self-contained, has no
dependencies on SQP or anything else in this roadmap, and the Operations module (inventory only
today) is the natural caller waiting for it. "Optional" was a statement about its dependencies,
which is exactly what makes it cheap to schedule.
**Dependencies**: None
**Value**: 1000× speedup for network problems, supply chain applications

**Rationale**: Specialized algorithms for min-cost flow, assignment, transportation problems. Niche but extremely valuable for operations research users.

**Deliverables**:
- `NetworkFlowSolver` with shortest path, max flow, min-cost flow
- Hungarian algorithm for assignment problems
- Tutorial: `5.32-NetworkFlowTutorial.md`
- Supply chain optimization example

---

#### ~~Phase 8: Deterministic Global Optimization (Optional)~~ — DEFERRED INDEFINITELY
**File**: [DeterministicGlobal.md](./DeterministicGlobal.md)
**Priority**: ⭐⭐⭐
**Effort**: 4-5 weeks (complex)
**Status**: Not Started (verified — 0 files, 0 commits ever for `McCormick`) — **deferred
indefinitely, 2026-09-07**
**Dependencies**: SQP.md, ConvexityDetection.md
**Value**: Guaranteed global optima (vs local from gradient methods)

**Rationale**: Branch-and-bound with convex relaxations for global optimization. High complexity, narrow use cases. Consider deferring.

**Deferral (2026-09-07)**: 4–5 weeks, blocked behind two other phases, and it delivers guaranteed
global optima for a narrow class of problems. January already wrote *"Consider deferring"* — this
makes that explicit rather than leaving it as a standing intention: **not scheduled without a
specific caller asking for it.** The plan in `DeterministicGlobal.md` stays valid and stays put.

**Deliverables** (unchanged, unscheduled):
- `GlobalOptimizer` with interval arithmetic
- McCormick envelopes for bilinear terms
- Tutorial: `5.33-GlobalOptimizationTutorial.md`

---

#### ~~Phase 9: Dynamic Programming Infrastructure (Optional)~~ — DEFERRED INDEFINITELY
**File**: [DynamicProgramming.md](./DynamicProgramming.md)
**Priority**: ⭐⭐⭐
**Effort**: 3-4 weeks
**Status**: Not Started (verified — 0 files, 0 commits ever for `Bellman`) — **deferred
indefinitely, 2026-09-07**
**Dependencies**: None
**Value**: Sequential decision optimization, resource allocation over time

**Rationale**: Formalize multi-period optimization with Bellman equations. Useful for inventory control, optimal stopping.

**Deferral (2026-09-07)**: `MultiPeriodOptimizer`, `ScenarioOptimizer` and `StochasticOptimizer`
already cover most of the motivating use — multi-period allocation under uncertainty. A Bellman
formulation would be *cleaner*, but cleaner is not new capability, and this roadmap's remaining
budget is better spent on the six phases that are.

**Deliverables** (unchanged, unscheduled):
- `DynamicProgramSolver` with state space representation
- Value iteration, policy iteration
- Tutorial: `5.34-DynamicProgrammingTutorial.md`
- Example: Multi-period resource allocation

*If either phase ships anyway, strike these deferral notes through and leave them visible with the
reason recorded — do not delete them.*

---

## Timeline & Milestones

The January schedule below is kept for the record and struck through where the reconciliation
changed it. The live sequence is the one in "Revised implementation order".

### Revised sequence (2026-09-07)

| # | Deliverable | Ends when |
|---|---|---|
| **0** | Housekeeping: this file reconciled, `NonsmoothOptimization.md` moved to `completed/`, `BranchAndBound.minlp` convenience added | The docs match the code. Hours, not days |
| **1** | Evidence for GRG's promotion: do SQP and GRG disagree on corpus Solver models? | GRG's priority is settled by measurement, not argument |
| **2** | SQP + `SQPRelaxationSolver` | Differential set vs `InequalityOptimizer` and the published reference problems pass |
| **3** | GRG, gated on the oracle test | A recorded Excel solution is reproduced — or step 1 answers "no" and this is dropped back to Tier 3 |
| **4** | Interior Point, sparse | 10,000-var LP under a second, Simplex crossover published |
| **5** | Network Flow | Hungarian and min-cost flow beat general LP on the same instances |
| **6** | Convexity Detection, then ADMM | Per the January plans, unchanged |

Step 0 costs almost nothing and stops the next reader repeating the audit. Step 1 costs little and
decides whether step 3 happens at all.

---

### ~~Q2 2026 (Apr-Jun): Core Algorithms~~
~~**Target**: Complete Tier 1 critical path~~

| Weeks | Phase | Milestone |
|-------|-------|-----------|
| ~~1-3~~   | ~~Phase 1: SQP~~ | ~~SQP optimizer complete, documented, tested~~ |
| ~~4-7~~   | ~~Phase 2: Interior Point~~ | ~~Large-scale LP/QP working, benchmarks done~~ |
| ~~8-10~~  | ~~Phase 3: MINLP~~ | ~~Branch-and-bound with nonlinear relaxation working~~ — **already shipped**; see Phase 3 |

~~**Deliverable**: Blog post "Announcing Advanced Optimization" covering SQP, Interior Point, MINLP~~

---

### ~~Q3 2026 (Jul-Sep): Enhancements~~
~~**Target**: Complete Tier 2 high-value features~~

| Weeks | Phase | Milestone |
|-------|-------|-----------|
| ~~11-13~~ | ~~Phase 4: Convexity Detection~~ | ~~Automatic dispatch working, CVX-style API~~ |
| ~~14-17~~ | ~~Phase 5: ADMM~~ | ~~Parallel implementation, multi-period example~~ |

~~**Deliverable**: Tutorial series "Modern Optimization in Swift"~~

---

### ~~Q4 2026 (Oct-Dec): Excel Parity & Polish~~
~~**Target**: Complete Tier 3 specialized features~~

| Weeks | Phase | Milestone |
|-------|-------|-----------|
| ~~18-20~~ | ~~Phase 6: GRG~~ | ~~Excel-compatible optimizer, migration guide~~ — GRG moved to position 2 |
| ~~21+~~   | ~~Optional: Network Flow, Global, DP~~ | ~~As time permits~~ — Network Flow moved to position 4; Global and DP deferred indefinitely |

**Deliverable**: "Excel Solver to BusinessMath Migration Guide" — still wanted, and now the place
where the reproducibility argument in Phase 6 is stated honestly, including when SQP is the better
choice.

**Calendar note**: the January dates are unrecoverable — none of Q2's work started. The revised
sequence above is deliberately ordered rather than dated; it will be dated when step 0 is done and
step 1 has an answer.

---

## Success Metrics

### Functional Metrics
- ✅ All optimizers pass test suite (>95% coverage)
- ✅ Performance benchmarks vs reference implementations (MATLAB, SciPy)
- ✅ Documentation tutorials for each algorithm
- ✅ At least 2 real-world examples per optimizer

### Performance Targets
- **SQP**: Converge in <50% iterations vs augmented Lagrangian on standard problems
- **Interior Point**: Handle 10,000 variable LP in <1 second, and publish the Simplex crossover —
  that number is what tells a caller which solver to use
- **MINLP**: Solve 100-variable MINLP with 20 integer variables in <10 seconds — *unmeasured; the
  capability shipped without anyone benchmarking it. Measure against the current
  `NonlinearRelaxationSolver` before assuming `SQPRelaxationSolver` is needed to hit this.*
- **GRG**: within 2–3× of SQP. Slower is acceptable — its promotion is not a speed argument
- **Network Flow**: decisively faster than general LP on network instances, benchmarked against
  `SimplexSolver` on the same problem
- **Convexity Detection**: <100ms overhead for detection, 10× speedup for detected convex problems
- **ADMM**: Linear scaling with subproblems in parallel

### Marketing Impact
- "Industry-standard SQP constrained optimization"
- "Scales to institutional portfolios (10,000+ securities)"
- "Full MINLP capability (rare in open-source)" — ✅ true today, and has been for months
- ~~"Excel Solver compatible + modern alternatives"~~ → "reproduces the answer Excel Solver
  recorded, and can be checked against it". Phase 6 explains why the weaker claim was the wrong
  reason to build GRG.

---

## Dependencies & Integration

### Code Dependencies
```
Existing Infrastructure (✅ Available):
├── VectorSpace protocol
├── MultivariateConstraint enum
├── NumericalDifferentiation
├── LineSearch
├── BranchAndBound framework
│   └── RelaxationSolver protocol (✅ pluggable node solver)
│       ├── SimplexRelaxationSolver  (✅ default — linear integer programming)
│       ├── NonlinearRelaxationSolver (✅ shipped — MINLP, augmented Lagrangian nodes)
│       └── SQPRelaxationSolver      (❌ to come, with Phase 1)
├── SimplexSolver
└── SparseMatrix / SparseSolver (InteriorPoint must use these — a dense
    factorisation at 10,000 variables defeats the purpose)

New Dependencies (Sequential):
SQP (standalone)
├── SQPRelaxationSolver (conforms to the existing RelaxationSolver protocol)
├── GRG (reuses SQP's line search and KKT test)
└── InteriorPoint (standalone)
    └── ConvexityDetection (requires SQP + InteriorPoint)
        └── ADMM (requires ConvexityDetection)

~~MINLP (requires SQP)~~            ✅ shipped without it; see Phase 3
NetworkFlow (standalone)
~~GlobalOptimization (requires SQP + ConvexityDetection, optional)~~  deferred
~~DynamicProgramming (standalone, optional)~~                         deferred
```

Every optimizer here is a candidate for `ParallelOptimizer` and the existing Metal path. None
should be written in a way that forecloses it; none should be parallelised before it is correct.

### Documentation Dependencies
- Each optimizer needs standalone tutorial (5.26+)
- Update main optimization guide (5.1) with algorithm selection flowchart
- Update portfolio optimization guide (5.2) to use SQP
- Create comparison guide: "Choosing an Optimizer"

---

## Risk Mitigation

### Technical Risks
1. **Complexity**: SQP, Interior Point are non-trivial
   - *Mitigation*: Start with well-documented reference implementations (Nocedal & Wright textbook)
   - *Mitigation*: Comprehensive test suite before moving to next phase

2. **Performance**: May not match MATLAB/commercial solvers
   - *Mitigation*: Focus on "good enough" (within 2-3× of commercial)
   - *Mitigation*: GPU acceleration for large-scale if needed (Phase 10)

3. **API Design**: Wrong abstractions make future changes hard
   - *Mitigation*: Follow existing `MultivariateOptimizer` protocol patterns
   - *Mitigation*: Write tutorials before implementation to validate API

### Schedule Risks
1. **Underestimated complexity**: Each phase might take longer
   - *Mitigation*: Phases are independent, can defer lower-priority items
   - *Mitigation*: Tier 1 delivers core value even if Tier 2/3 delayed

2. **Context switching**: Other priorities interrupt
   - *Mitigation*: Modular design allows picking up later
   - *Mitigation*: Each phase fully documented before pausing

---

## Decision Points

### After Phase 1 (SQP Complete)
~~**Evaluate**: Does SQP sufficiently obsolete GRG for marketing?~~
- ~~**If yes**: Defer GRG to Phase 6 or eliminate~~
- ~~**If no**: Move GRG to Phase 4 for Excel parity marketing~~

**Revised (2026-09-07)** — the question is no longer about marketing, and it is answered by
measurement rather than judgement:

**Evaluate**: run SQP and GRG on the corpus's Excel Solver models and count the disagreements.
- **If they disagree often**: GRG stays at position 2 and its acceptance criterion is agreement
  with the recorded Excel value.
- **If SQP already reproduces Excel's answers**: the argument in Phase 6 is wrong, GRG drops back
  to Tier 3, and *that* is written down here. Resolve this **before** writing GRG, not after.

### After Phase 2 (Interior Point Complete)
**Evaluate**: Is large-scale performance sufficient?
- **If yes**: ~~Continue to Phase 3 (MINLP)~~ → continue to Network Flow (position 4)
- **If no**: Add Phase 2b: GPU Interior Point acceleration

### ~~After Phase 3 (MINLP Complete)~~ → After Network Flow
**Evaluate**: ~~Tier 1 complete~~ — assess ROI on Tier 2
- **Option A**: Continue to Tier 2 (Convexity, ADMM)
- **Option B**: Ship v2.0 with what is done, gather user feedback
- **Option C**: Pivot to different capability (GPU acceleration, stochastic optimization)

---

## Version Tagging

- ~~**v2.0**: Phase 1-3 complete (SQP, Interior Point, MINLP) - "Advanced Optimization"~~ →
  **v2.0**: SQP, GRG, Interior Point complete. MINLP is already in a shipped release and cannot be
  a v2.0 headline; it should instead be announced as a capability that was there and undocumented.
- **v2.1**: Convexity + ADMM - "Modern Optimization"
- ~~**v2.2**: Phase 6 complete (GRG) - "Excel Solver Parity"~~ — GRG moves into v2.0 with SQP
- **v2.2**: Network Flow - "Specialized Optimization"
- ~~**v2.3**: Optional phases (Network Flow, Global, DP)~~ — Global and DP are deferred
  indefinitely and get no version allocation until a caller asks

---

## References

Each implementation plan references:
1. **Academic Papers**: Original algorithm papers
2. **Textbooks**: Nocedal & Wright "Numerical Optimization", Boyd & Vandenberghe "Convex Optimization"
3. **Reference Implementations**: MATLAB, SciPy, IPOPT, SNOPT
4. **Test Problems**: CUTEst, netlib, MINLP library

---

## Getting Started

To implement a phase:

1. Read the detailed plan: `./[Algorithm].md`
2. Review academic references in that file
3. Set up test harness with benchmark problems
4. Implement core algorithm
5. Write tutorial with examples
6. Run performance benchmarks
7. Update main documentation
8. Tag version and ship

Each phase is **fully independent** - you can implement in any order, though the recommended order captures dependencies and strategic value.

**Before starting any phase**, read the audit that reconciled this file:
[PROPOSAL_advanced_optimization_gap.md](../../proposals/PROPOSAL_advanced_optimization_gap.md).
It carries the shared contracts (`MultivariateConstraint`, `ConstrainedOptimizationResult` and the
`lagrangeMultipliers` seam that `PsiDualValue`/`PsiSenValue` read), the error-handling rules
(non-convergence is a result, not a throw; never return zeroed multipliers as if computed), and the
test strategy that applies to all six remaining phases.

---

~~**Next Action**: Proceed to [SQP.md](./SQP.md) to begin Phase 1 implementation.~~

**Next Action (2026-09-07)**: finish step 0 — this file is reconciled and
`NonsmoothOptimization.md` has moved to `completed/`; what remains is the `BranchAndBound.minlp`
convenience that makes the shipped MINLP capability discoverable. Then step 1, the SQP-vs-GRG
disagreement count, which settles Phase 6's priority before any of it is written. Then
[SQP.md](./SQP.md).
