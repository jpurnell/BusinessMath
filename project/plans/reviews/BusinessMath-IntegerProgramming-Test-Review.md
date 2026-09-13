# BusinessMath integer programming tests: consolidated review

*September 2026. Covers 31 test files across both batches — the Phase1 suites, the BranchAndCut tiers, the branch-and-bound correctness and refactoring suites, the cut and node-loop suites, the relaxation solvers, the time-limit pair, the MINLP entry points, variable shifting, capital budgeting, and the certificate file. Companion to the twenty-four preceding domain reviews; supersedes the two integer-programming batch reviews.*

*Every numeric claim below was independently recomputed in Python: the certificate corpus by exhaustive enumeration, the LP and IP optima of each cut fixture by hand, the capital-budgeting knapsack by exhaustive subset search.*

## 1. Summary

The suite divides cleanly by whether a test can distinguish a correct solver from a plausible wrong one.

**Three files answer the question a caller actually asks.** `IntegerProgrammingCertificateTests` states the problem better than my own batch reviews did:

> "Across 29 files the integer-programming suite checks a great deal about the *machinery*: that a bound points the right way for each sense, that the gap is non-negative, that cuts are valid, that node and time limits are honoured. All real, all worth having. None of it answers the one question a caller asks: is the returned solution actually the best integer point?
>
> A branch-and-bound that prunes one node too eagerly returns a feasible integer solution with a plausible objective and a bound that still points the right way. Every existing assertion passes. The answer is simply not optimal."

Its oracle is exhaustive enumeration over a boxed integer region — "a complete, independent integer programming solver, written in a dozen lines, sharing nothing with the one under test." I verified all eight corpus optima and every one matches (Appendix A.1). The two time-limit files do the same for the time budget, replacing wall-clock with a clock driven by the objective function so that "one second" means exactly one hundred evaluations.

**Against that, the file named for cutting-plane validity never runs the cutting-plane code.** Fourteen of the fifteen tests in `Phase1_CutValidityTests` pose *minimise Σxᵢ subject to Σxᵢ ≤ b, xᵢ ≥ 0 integer*, whose LP relaxation optimum is the origin — already integral. Branch-and-bound terminates at the root, nothing branches, no Gomory cut is generated, and every assertion holds for a solver with cutting planes disabled or unimplemented.

**And three tests document defects that have since been fixed, while still asserting nothing.** Each prints a discrepancy or carries a commented-out assertion naming the value that "should" hold once the capability shipped. All three capabilities have shipped. None of the three tests was updated.

The four highest-value fixes, in order:

1. Flip the optimisation sense in `Phase1_CutValidityTests` — one word per test (§2 item 1).
2. Restore the three stale assertions (§2 item 2).
3. Assert on the cut pool, which is already observable (§2 items 3–4).
4. Convert the loosened capital-budgeting bound to `withKnownIssue` (§2 item 5).

### Templates to copy

| Kind of test | Copy from |
|---|---|
| Optimality, as distinct from feasibility | IntegerProgrammingCertificateTests |
| Any time or resource budget | TimeLimitEnforcementTests, TimeLimitSemanticsTests |
| A sentinel value removed from an API | TimeLimitSemanticsTests |
| Absence asserted as a value | BranchAndCutRobustnessTests (`totalCutsGenerated == 0`) |
| A fractional fixture that reaches the cut code | NodeCutLoopTests |

## 2. Findings

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`Phase1_CutValidityTests` exercises no cutting-plane code** | Fourteen tests minimise Σx subject to Σx ≤ b. Verified for b = 2.3, 3.5, 4.5, 4.7, 5.1, 5.5, 5.7, 5.9 and 6.8: under minimisation every one gives LP = IP = 0 at the origin, integral, so no cut and no branch. Under maximisation each has a fractional LP optimum at b/n per variable with a 2–18% gap. Three independent pieces of evidence show the fixtures were designed for maximisation: `cutsViolateFractionalSolution`'s comment cites "LP solution (2.75, 2.75)" for b = 5.5, which is exactly 5.5/2; `cutsImproveBound` asserts `relativeGap < 0.2` where the maximise gap at b = 5.9 is **0.180** and the minimise gap is 0; and the one test in the file that gets it right says why — `minimize: false  // MAXIMIZE to hit the upper bound`. | Flip to `minimize: false`. The fixtures then become fractional at the root, the cutting-plane code becomes reachable, and `cutsImproveBound`'s 0.2 bound starts discriminating. `NodeCutLoopTests` and `CutGenerationDiagnosticTests` both get the sense right — the latter by negating the objective under `minimize: true` — so the idiom exists in the suite. |
| 2 | **Three tests record fixed defects and assert nothing** | `handlesNegativeLowerBounds`: its only `#expect` is a checker-workaround marker; it prints `"Expected: x = -3, Got: …"` and comments "When fixed, should be: `#expect(result.integerSolution[0] == -3)`". That assertion now exists and passes in `BranchAndCutRobustnessTests.variableShiftingCorrectness`, and `VariableShiftTests` is a whole file testing the shift machinery. `detectsQuadraticObjective` and `detectsBilinearConstraint`: each carries a commented `#expect(throws: OptimizationError.nonlinearModel)` block with "TODO: This test should FAIL until we implement linearity checking" — and `BranchAndBoundSolver` now takes `validateLinearity`, which `CutGenerationDiagnosticTests` passes explicitly as `false`. | Write the three assertions. This is what `withKnownIssue` exists for: had the defects been recorded as executable expectations, Swift Testing would have reported the unexpected pass when each fix landed. The risk review's CVaR marker is the same story with the opposite outcome — it was removed *because* the fix made it fail. |
| 3 | **Cut behaviour is never inspected, and the pool is observable** | Five tests in `Phase1_CutValidityTests` assert only `result.status == .optimal`; three of them are named for deduplication (`identicalCutsDeduplicated`, `nearlyIdenticalCutsDeduplicated`, `differentCutsNotDeduplicated`) and nothing anywhere reads the cut pool. But `CutGenerationDiagnosticTests` reads `result.cuttingPlaneStats` for `totalCutsGenerated`, `gomoryCuts`, `cuttingRounds`, `lpResolves`, `rootLPBoundBeforeCuts` and `rootLPBoundAfterCuts` — and prints all six. | The API is not the obstacle. Assert cut counts before and after deduplication; that is the only way the three tests can mean what their names say. Converting `CutGenerationDiagnosticTests`' prints to assertions would make it the most valuable cut test in the suite. |
| 4 | **Cut-count assertions are vacuous or guarded** | Vacuous: `stats.totalCutsGenerated >= 0`, `stats.cuttingRounds >= 0, "Should track cutting rounds"`, `result.cuttingPlaneStats?.mirCuts ?? 0 >= 0` — an unsigned count is never negative. Guarded: six sites across `NodeCutLoopTests` and the three tier suites wrap their assertion in `if stats.totalCutsGenerated > 0 { … }`, so given §2 item 1 those inner assertions may never execute. | Assert `> 0` on a fractional fixture, and convert the guards to `try #require(stats.totalCutsGenerated > 0)`. The suite's own `cutsDisabledForNonSimplexSolver` asserts `totalCutsGenerated == 0` for a relaxation solver with no tableau — the right shape, and the only cut count pinned to a value anywhere. Its complement is missing everywhere. |
| 5 | **`CapitalBudgetingTests` accepts a 22%-suboptimal answer by design** | The three-project knapsack — A (NPV 50, cost 30), B (40, 20), C (30, 15), budget 50 — has a unique optimum of **90** at {A, B}, cost exactly 50. The test asserts `totalNPV >= 60.0` with the comment "But may find sub-optimal due to SimplexSolver Phase I limitations." By enumeration, 60 admits {B, C} at 70 and {A, C} at 80. `maximizeProfitabilityIndex` has the same shape at `>= 70.0`. | `withKnownIssue` asserting 90. The comment already names the defect; recording it as a loosened bound means fixing Phase I produces no signal. |
| 6 | **`cutsReduceTreeSize` does not compare tree sizes** | It builds two solvers, one with cuts and one without, and asserts both reach `.optimal` and that their objective values are equal. The name and the comment ("Cutting planes should reduce nodes explored (usually)") describe a node-count comparison that is never made. `nodesExplored` is available — the tier suites use it. | Assert the comparison, or rename to what it checks. The `objectiveValue` equality it does assert is a real and valuable claim — cuts must not change the optimum — but it uses `==` on two independently-computed Doubles, which two different search orders can reach by different arithmetic paths. |
| 7 | **Several feasibility assertions are satisfied at the origin** | `solutionSatisfiesLinearInequalityConstraints` asserts 2x + y ≤ 8, x + 2y ≤ 7, x ≥ 0, y ≥ 0 — all true at (0,0), which is the minimisation optimum. `zeroAsValidIntegerSolution` likewise. | The two tests in the same file that force a non-trivial answer are the models: `solutionSatisfiesEqualityConstraints` (x + y = 5 exactly) and `variableWithTightIntegerBounds` (asserts 3.0). Give the inequality tests a binding constraint, or maximise. |
| 8 | **Four `#expect(true) // TEST-QUALITY: checker workaround`** | Three in `BranchAndBoundCorrectnessTests` on tests inside nested `struct` suites, one in `CutGenerationDiagnosticTests` as `#expect(Bool(true))` with "Test should pass - we just want to see the output". | The three markers are the nested-scope gate defect, now seen in two forms: nested `func` (the original quality-gate discussion) and nested `struct` suites. The reachability visitor needs to handle both, and these three are the fixtures for the second form. |
| 9 | **The knapsack corpus note describes a property the problem lacks** | The note says "Its LP relaxation takes a fraction of one item, so the integer answer is never the rounded continuous one." By ratio ordering (item 2 at 2.6, item 1 at 2.5) the LP fills capacity 9 exactly with items 1 and 2 for value 23 — integral. The file's own `enumerationIsItselfCorrect` says so correctly: "that happens to be integral here." | Fix the note. The two comments contradict each other and the second is right. `roundingMisleads` is the problem that has the stated property, and it is named for it. |

## 3. What the strong files establish

### 3.1 Enumeration as a complete second solver

`IntegerProgrammingCertificateTests` is the model, and five design details make it work:

- **One `Problem` struct drives both the solver and the enumeration**, "so the two cannot be given different problems."
- **The box is stated as explicit constraints to the solver**, not assumed — "the solver is not being asked to guess at a bound the oracle assumes."
- **`corpusIsRepresentative`** requires both senses, an equality row, a `≥` row, a negative objective coefficient, and every box between 8 and 100,000 points. All eight problems satisfy it (Appendix A.1).
- **`enumerationIsItselfCorrect`** checks the oracle against a hand-known answer, because "an oracle needs checking too."
- **`degenerateTies`** compares the optimal *value*, not the point — "asserting one would be asserting a convention rather than a result." That is the reasoning `LinearProgrammingCertificateTests` gives for LP vertices, arrived at again.

The value is in being a different algorithm, stated plainly: "it cannot prune, so it cannot prune wrongly."

**Four of its assertions need no oracle at all**, and the header lists them as what a MIP certifies about itself:

| Claim | Why it matters |
|---|---|
| The point is integral and feasible in every constraint | The baseline |
| **The reported objective is that point's objective** | "A node's bound reported in place of the incumbent's value would show up exactly here, and nowhere else" |
| The bound brackets from the correct side and the gap has closed | "`optimal` is a claim that the search finished, not merely that something was found" |
| The continuous relaxation bounds the integer optimum | Checked against the simplex directly — "a cross-check between two solvers in the package rather than a self-consistency claim" |

The second is the one worth copying elsewhere. Reporting a stale node bound as the objective is a plausible defect that every other assertion in the suite tolerates, and recomputing c'x from the returned point is two lines.

### 3.2 A clock driven by the work, not the wall

`TimeLimitEnforcementTests` advances its clock inside the objective function at ten modelled milliseconds per evaluation, so a one-second budget is exactly one hundred evaluations. Three consequences:

- The assertion (`spent < 400`) is **fixed**, not machine-dependent. The comment says so: "No wall clock, and no sleeping… The assertion is then about the solver rather than about the scheduler" and "it is a *fixed* bound, not one that moves with the machine."
- The slack is explained rather than tuned: "the deadline can only be tested at iteration boundaries and a single BFGS step costs several evaluations, so the bound is generous."
- The pre-fix measurement is recorded: **153 seconds against a one-second limit**, because the deadline was only tested between nodes "and a node is an arbitrary program over the caller's objective."

This is the `ModelProfilerTests` technique from the helpers review, applied to a harder case — and it is the answer to the wall-clock assertions that review found in `PerformanceOptimizationTests`.

### 3.3 A sentinel removed rather than guarded

`TimeLimitSemanticsTests` closes the item raised in the very first TestSupport review, which noted `SolverBudgets`' comment about `timeLimit: 0` meaning unlimited and recommended `Duration? = nil`. It records what the sentinel cost:

> "The elapsed comparison was unguarded, so `elapsed > .seconds(0)` was true the moment the clock advanced at all, and a zero budget expired at the first node rather than never. Nothing caught it, because the branch-and-cut solver — whose `timeLimit` *defaulted* to `0` — had no test constructing it… The consequence was not a slow solver but a silent one: a default-constructed `BranchAndCutSolver` returned `success: false` after exactly one node, objective at infinity, for every problem it was ever given."

And the closing line is the right way to describe a fix: "The guard that fixed it was correct and is now gone, because there is nothing left to guard."

The file pins all three values that now mean different things — `nil`, `.zero`, and a positive budget tight and generous — which is what stops the sentinel drifting back. Its `SteppingElapsedTimeSource` handles the case `ManualElapsedTimeSource` cannot, and says why: "`solve` is synchronous, so nothing can call `advance(by:)` in the middle of it. Stepping on read is the smallest thing that lets these assertions be about the solver rather than about the scheduler." The `@unchecked Sendable` carries a `// Justification:` comment naming the lock — the formal exemption pattern.

### 3.4 Absence asserted as a value

`cutsDisabledForNonSimplexSolver` builds a `DummyNonlinearRelaxationSolver` returning `simplexResult: nil` and asserts `totalCutsGenerated == 0`. Gomory cuts need a tableau, so a relaxation solver without one must produce none — and asserting zero is stronger than asserting the solver still works. The mock is minimal and honest: it returns `.optimal` with the initial guess, enough to exercise the path without pretending to solve anything.

### 3.5 Feasibility asserted per constraint

`Phase1_IntegerFeasibilityTests` checks the things a rounded integer solution can get wrong, individually: integrality to 1e-6, binary membership as `value == 0 || value == 1`, each constraint named with its own tolerance, an equality constraint two-sided, and — the unobvious one — that `result.solution` (continuous) and `result.integerSolution` (rounded) agree on the integer variables. That last catches a rounding step applied to one view and not the other.

The file also covers negative integers, large values (1001), the integrality-tolerance boundary from both sides, and a variable whose bounds force integrality implicitly. That is a genuine boundary sweep, and it is the batch's best non-certificate work.

### 3.6 Bound monotonicity as a cut oracle

`BranchAndCutTier1Tests` asserts `stats.rootLPBoundAfterCuts >= stats.rootLPBoundBeforeCuts - 0.1`. A valid cut cannot weaken the relaxation, so the root bound must not move the wrong way — no reference implementation needed, and it fails for an invalid cut. Two refinements: the `- 0.1` slack admits a small weakening (2% on a bound of order 5), and with §2 item 1 fixed the assertion could be strict. `infeasibleLPAfterCutsReturnsCorrectStatus` asserts `.infeasible` outright where its sibling accepts `.optimal || .infeasible`, which shows the fixture can be made determinate.

## 4. Coverage gaps

**Cuts.** Once the sense is fixed and the pool is asserted on:

- **`totalCutsGenerated > 0`** on a fractional fixture — the non-vacuity guard.
- **Cut count before and after deduplication** — what the three deduplication tests need.
- **Validity by enumeration**: every integer point in the box satisfies every generated cut. The certificate file's enumeration already produces those points, so this is a few lines on existing machinery, and it is the definition of cut validity.
- **A cut violated by the point that generated it** — otherwise the cut accomplishes nothing. `cutsViolateFractionalSolution` is named for exactly this.
- **A Gomory cut's derivation**: for a single-row tableau the cut coefficients are that row's fractional parts, computable by hand.
- **Strict root-bound improvement** on a fixture where cuts must bite (§3.6).

**Branch and bound.**
- **Node count against an enumerable tree.** The certificate corpus is small enough to bound the full search tree exactly, replacing the `< 50` and `< 100` sanity limits.
- **Optimality rather than feasibility**, across the Phase1 sweeps. The recurring claim is that the returned solution satisfies its constraints — primal feasibility, which the optimization review notes is one of four KKT conditions. For an integer program the certificate is a matching bound, and `relativeGap` carries it; the certificate file asserts `< 1e-4` at `.optimal` and the sweeps do not.
- **The `.timeLimit` status with a known-suboptimal answer**: the incumbent returned and the gap *not* closed. `TimeLimitEnforcementTests` asserts the status disjunction; asserting an open gap under `.timeLimit` is the complement.

**Relaxation solvers.** `SimplexRelaxationSolverTests` and `NonlinearRelaxationSolverTests` test the two implementations separately. The cross-check — both solving the same relaxation to the same optimum — is the differential test the optimization review recommends for the matrix backends and the simulation review for GPU-versus-CPU.

**MINLP.** Given the two commented-out linearity assertions (§2 item 2), the question worth checking in `MINLPIntegrationTests` and `MINLPEntryPointTests` is whether the MINLP path asserts anything the linear path cannot — a genuinely nonlinear objective whose integer optimum is known.

**Degeneracy and scaling.** `DegeneracyProtectionTests` and `CutScalingTests` are the two smallest files, and both names describe properties (cycling protection, coefficient scaling) with specific failure modes. Worth checking they assert those rather than `.optimal` — the same question as §2 item 3.

## 5. Recommended order of work

1. **Flip `minimize: true` to `minimize: false` in `Phase1_CutValidityTests`** (§2 item 1). One word per test, and it is the difference between the file exercising the cutting-plane code and not.
2. **Restore the three stale assertions** (§2 item 2): `x == -3` in `handlesNegativeLowerBounds`, and the two `nonlinearModel` blocks with `validateLinearity: true`. All three name a capability that has shipped.
3. **Assert on the cut pool** (§2 items 3–4): counts for deduplication, `> 0` on fractional fixtures, and `#require` in place of the six `if … > 0` guards. Convert `CutGenerationDiagnosticTests`' prints while there.
4. **Convert the capital-budgeting bounds to `withKnownIssue`** asserting 90 (§2 item 5), so the Phase I fix produces a signal.
5. **Add cut validity by enumeration** (§4), reusing the certificate file's integer-point generator.
6. **Make `cutsReduceTreeSize` compare node counts**, or rename it (§2 item 6).
7. **Give the origin-satisfied feasibility tests a binding constraint** (§2 item 7).
8. **Extend the certificate corpus** to a problem the time limit interrupts, so `.timeLimit` gets the same treatment as `.optimal` (§4).
9. **Cross-check the two relaxation solvers** (§4), fix the knapsack note (§2 item 9), and tighten the root-bound slack (§3.6).

## 6. Quality-gate rules

**One new rule.** *An optimisation fixture whose LP relaxation is already integral (advisory).* In general a static check cannot decide this, but a narrow version catches the whole cut-validity file: flag a test that enables a solver feature (cutting planes, branching) and poses a problem where the objective and a single `lessOrEqual` constraint share the same coefficient vector under minimisation. That is the exact shape here, it is syntactically recognisable, and it means the feature under test is unreachable.

**Two refinements to existing rules.**

*Guarded assertions need a visible precondition.* The rule already flags `guard … else { continue }` and `if !x.isEmpty`; `if <count> > 0` wrapped around a test's only assertion is the same shape. Six sites here, and `#require` is the fix.

*A test that records a known defect must record it as an executable expectation.* The pieces are already covered — commented-out assertions, warn-and-pass, `.disabled` requires `.bug(…)` — but this domain shows why they are one pattern. Three tests here documented defects in comments and prints; all three defects were fixed and none of the tests noticed. `withKnownIssue` would have failed on each fix, which is how the risk review's CVaR marker came out.

**A generalisation worth naming.** A test that enables a feature should assert the feature was reached. For cuts that means a nonzero cut count; for branching, a node count above one; for a hardware path, a reachability check. The interpolation review's off-knot requirement, the marketing batch's "this fixture has an interior optimum", and the heuristics batch's GPU-reachability guard are the same idea reached independently. This belongs in the fixture-coverage report as a per-feature question rather than a per-file one.

## Appendix. Verified values

### A.1 The certificate corpus, by exhaustive enumeration

All eight optima confirmed. Lower bounds are zero throughout.

| Problem | Sense | Optimum | An optimal point | Feasible / box |
|---|---|---|---|---|
| knapsack | max | **23** | (1, 1, 0, 0) | 12 / 16 |
| roundingMisleads | max | **4** | (0, 4) | 13 / 49 |
| equalityRow | max | **31** | (2, 5, 0) | 18 / 216 |
| minimisationWithFloor | min | **16** | (1, 4, 0) | 297 / 343 |
| mixedRelations | max | **16** | (2, 4, 0) | 19 / 125 |
| negativeCoefficients | max | **14** | (2, 0, 2) | 59 / 125 |
| tightBudget | max | **15** | (0, 1, 0, 1) | 10 / 16 |
| degenerateTies | max | **5** | (0, 2, 3) | 44 / 64 |

Every box is within the file's stated 8–100,000 range. `tightBudget` admits 10 of 16 points and `knapsack` 12 of 16, so both budgets bind as their notes claim.

**Knapsack LP relaxation** (§2 item 9): value-to-weight ratios are 2.5, 2.6, 2.333, 2.0, so the greedy order is item 2 then item 1, filling capacity 9 exactly at value 23 — integral, not fractional.

### A.2 The cut-validity fixture shape

Objective Σxᵢ, one constraint Σxᵢ ≤ b, xᵢ ≥ 0 integer:

| b | n | Minimise (as coded) | Maximise (as commented) | Each var at LP optimum |
|---|---|---|---|---|
| | | LP / IP / gap | LP / IP / gap | |
| 2.3 | 1 | 0 / 0 / 0 | 2.3 / 2 / 0.150 | 2.300 |
| 3.5 | 2 | 0 / 0 / 0 | 3.5 / 3 / 0.167 | 1.750 |
| 4.5 | 2 | 0 / 0 / 0 | 4.5 / 4 / 0.125 | 2.250 |
| 4.7 | 2 | 0 / 0 / 0 | 4.7 / 4 / 0.175 | 2.350 |
| 5.1 | 2 | 0 / 0 / 0 | 5.1 / 5 / 0.020 | 2.550 |
| 5.5 | 2 | 0 / 0 / 0 | 5.5 / 5 / 0.100 | **2.750** |
| 5.7 | 3 | 0 / 0 / 0 | 5.7 / 5 / 0.140 | 1.900 |
| 5.9 | 2 | 0 / 0 / 0 | 5.9 / 5 / **0.180** | 2.950 |
| 6.8 | 3 | 0 / 0 / 0 | 6.8 / 6 / 0.133 | 2.267 |

The b = 5.5 row gives (2.75, 2.75) — exactly what `cutsViolateFractionalSolution`'s comment describes. The b = 5.9 row gives 0.180, which is what `cutsImproveBound`'s `< 0.2` bound was tuned against.

### A.3 A fixture that does reach the cut code

`NodeCutLoopTests`: maximise x + y subject to x + 2y ≤ 7, 2x + y ≤ 7, x, y ≥ 0 integer.

| Quantity | Value |
|---|---|
| LP optimum | x = y = 7/3 ≈ 2.3333, objective 14/3 ≈ 4.6667 |
| IP optimum | 4, at (1, 3) or (2, 2) |
| Gap | 0.667 absolute, 16.7% relative |

Fractional at the root, so cuts are reachable — the property batch 1's fixtures lack.

### A.4 The capital-budgeting knapsack

Projects A (NPV 50, cost 30), B (40, 20), C (30, 15). Budget 50.

| Selection | Cost | NPV |
|---|---|---|
| {} | 0 | 0 |
| {C} | 15 | 30 |
| {B} | 20 | 40 |
| {A} | 30 | 50 |
| {B, C} | 35 | 70 |
| {A, C} | 45 | 80 |
| **{A, B}** | **50** | **90** |

The optimum is unique. The test's `>= 60.0` bound admits {B, C} at 70 and {A, C} at 80.

### A.5 The time-limit model

| Quantity | Value |
|---|---|
| Cost per objective evaluation | 10 ms (modelled) |
| One-second budget | exactly 100 evaluations |
| Assertion bound | `spent < 400` — four seconds of modelled work |
| Pre-fix measurement | 153 seconds against a one-second limit |

Generous by design, because the deadline can only be tested at iteration boundaries and a BFGS step costs several evaluations — but fixed, so it does not move with the machine.
