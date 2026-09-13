# BusinessMath optimization tests: consolidated review

*September 2026. Covers 78 test files in four batches: certificates and vector space (19), DEA and multivariate optimizers (20), simplex, clustering and applications (20), and the async, robust, stochastic and fault-injection layers (19). Companion to the distribution, simulation, statistics, time-series, Bayes, financial-ratio, scenario-analysis, operational-driver, financial-statement and validation/forecasting reviews.*

*All reference values recomputed in Python: LP optima by independent vertex enumeration, DEA scores from the closed form.*

## 1. Summary

This domain settles a question the whole review series has been circling: **when is a fixture the right oracle, and when is it the wrong one?**

`LinearProgrammingCertificateTests` and `DEACertificateTests` answer it directly, and their answer is not "always use a fixture." A linear program certifies its own answer — feasibility, objective consistency, zero duality gap, complementary slackness and non-negative reduced costs are jointly *sufficient* for optimality, so nothing has to trust another solver. More importantly, a fixture here would be actively harmful: two correct LP codes routinely return different vertices of the same optimal face, so comparing solution vectors would manufacture failures where there is no defect.

That gives a three-way rule, and this domain contains a clean example of each:

| The answer is… | Use | Because |
|---|---|---|
| **Verifiable but not unique** — LP vertices, DEA reference sets, optimizer solutions on flat regions | A certificate | A fixture imports another implementation's tie-breaking as if it were correctness |
| **Unique and externally published** — Cooper et al. Table 1.3, a textbook optimum | A fixture | It pins the *scale*, which no self-consistency check can (a solver returning θ = 1 for everything satisfies attainability) |
| **Determined by the mathematics** — a noiseless series a model must reproduce exactly | Exact recovery | Nothing is estimated that is not already present, so no convention enters |

The third row is the Holt-Winters technique from the forecasting review. All three appear here, and `DEACertificateTests` uses two of them in one file, deliberately: definitional checks for what they can prove, and a single-input/single-output closed form for the one thing they cannot.

**Three files also record defects with an unusual quality of evidence.** The LP file's corpus was built around a defect that appeared only away from all-≤ maximisation and all-≥ minimisation, "which is exactly the pair a small corpus tends to consist of." `VectorSpaceTests` records how a wrong-but-tested behaviour reached published documentation and printed a different answer on every run. `StochasticOptimizationTests` documents a seeding fix that made the problem *harder to solve* — and measured it: 10 convergences in 60 versus 40 in 40.

**Against that, the older generation is broad and shallow.** The multivariate optimizer files assert distance-to-known-minimum at unmotivated tolerances; `SimplexSolverTests` asserts solution vectors the certificate file argues against; the applied files (resource allocation, production planning, multi-period) largely restate their own constraints.

Highest-leverage work, in order:

1. Apply the gradient certificate to the multivariate optimizers (§4.1) — it replaces about 40 distance assertions with the condition that actually defines a minimum.
2. Fix the assertions that cannot fail (§5), the `rounded()` non-negativity checks first.
3. Retire the solution-vector assertions in `SimplexSolverTests` in favour of objective values (§4.2).
4. Extend units invariance to SBM and super-efficiency (§2 item 3).

## 2. Defects and open questions

| # | Issue | Evidence | Recommendation |
|---|---|---|---|
| 1 | **`weight.rounded() >= 0.0` cannot detect a violation** | Two sites in `StochasticOptimizationTests` (`constraintSatisfactionUnderUncertainty`, `degenerateTowardsDeterministic`). Rounding before the comparison turns any violation smaller than 0.5 into a pass — a weight of −0.4 rounds to −0.0 and passes. Likewise `optimalProduction.rounded() <= 200.0` admits 200.49. | `#expect(weight >= -1e-9)`. If the rounding was there to absorb solver noise, name the tolerance instead of hiding it in a rounding mode. |
| 2 | **`portfolioOptimization` asserts a disjunction that always holds** | `#expect(result.converged \|\| result.iterations > 50)` in `MultivariateLBFGSTests`. An optimizer that ran 51 iterations and diverged passes. | Assert convergence, or assert the gradient norm reached. |
| 3 | **Units invariance is untested for SBM and super-efficiency** | `DEACertificateTests` establishes it for CCR and BCC — the property DEA is chosen for, and one a scaling error breaks while leaving every score plausible. `DEASBMTests` and `DEASuperEfficiencyTests` have no equivalent. | Extend the invariance test across all four models. It is the cheapest high-value addition in the domain. |
| 4 | **`compareMemorySizes` never compares** | It runs L-BFGS at m = 3, 5, 10, 20 and asserts `val < 1.0` for each, discarding the comparison its name promises. | On a smooth problem, larger memory should not do worse. Assert the ordering, or rename. |
| 5 | **Gomory cut tests assert only non-emptiness** | `cuts.count > 0`, `tableauRow.count > 0` in `SimplexTableauAccessTests`. A valid cut has two checkable properties. | Assert that the cut excludes the current fractional point and excludes no integer-feasible point. Both are checkable by enumeration at these sizes. |
| 6 | **Async paths are not checked against their sync counterparts** | `AsyncSimplexSolverTests`, `AsyncDEASolverTests`, `AsyncGradientDescentOptimizerTests`, `AsyncOptimizationTests`. | `identical` between the async and sync results for the same input — the delegation check used elsewhere in the corpus. For a deterministic solver this should be bit-exact. |
| 7 | **Reproducibility asserted with `==`, divergence with `!=`** | `ScenarioGeneratorDeterminismTests` throughout. `!=` passes on a stream that has gone NaN, which is the case FloatingPointClaims documents. | `identical` and `!identical`. |
| 8 | **Seven commented-out `@Test` declarations** | `VectorSpaceTests`: matrix-vector multiplication, convenience creation, two performance tests, empty-vector operations, large-dimension vectors, description strings. The largest concentration in the corpus. | Restore or delete. Matrix-vector multiplication in particular is a core operation with no coverage. |

## 3. The certificate technique

Worth setting out fully, because it transfers to any solver in the package.

### 3.1 What makes a certificate possible

A certificate exists when the *answer* is hard to compute but *checking* an answer is easy. The LP file's checklist:

1. the point is feasible;
2. the reported objective is that point's objective;
3. `y'b = c'x` — zero duality gap;
4. complementary slackness — a slack constraint has zero price, a positive variable has zero reduced cost;
5. reduced costs are non-negative, so no non-basic variable would improve the objective.

Together those are sufficient. Nothing imports another solver's conventions.

Two of its checks owe nothing even to duality theory:

- **Exhaustive vertex enumeration** — a bounded LP attains its optimum at a vertex, and a vertex is where *n* linearly independent constraints hold with equality. At these sizes every subset can be enumerated and solved by Gaussian elimination. That is a complete second LP solver.
- **Shadow prices against their own definition** — a dual *is* `d(objective)/d(rhs)`, measurable by nudging the right-hand side and re-solving. This is what found the defect the file was written against.

### 3.2 The details that make it work

**The oracle must not share code with the subject.** The Gaussian elimination behind the enumeration is written out in the test file rather than taken from the package, "because an oracle that shared the package's linear algebra could agree with the simplex through a fault they both inherit." This consideration appears nowhere else in the corpus and applies to every differential test.

**Skipping a check can be the honest reading.** Degenerate problems carry `dualsAreDetermined: false` and are excluded *only* from the finite-difference comparison, because the one-sided derivatives genuinely differ and no single number exists for a dual to be. They remain held to the gap and complementary slackness, which need no uniqueness. The file says why: "skipping it is the honest reading rather than a loosened tolerance." That is the correct handling of an inapplicable check, and the opposite of widening a bound until it passes.

**Corpus design is part of the oracle.** `corpusIsRepresentative` requires every relation in both senses, an equality row, a negative right-hand side, a degenerate problem, and something beyond two variables — because the defect appeared only outside the two shapes a small corpus tends to consist of. It also keeps the two problems that were already correct, one of which was correct *for a compensating reason* (the surplus column's sign and the negation inside `minimize` cancelled), so a fix cannot regress them.

**A certificate bounds one side; something else must bound the other.** `DEACertificateTests` names this in its own header: attainability proves a score cannot be too low, but a solver returning θ = 1 for everything satisfies it. Hence the single-input/single-output closed form, which pins the scale, and `noCombinationBeatsTheReportedScore`, which scans pairs to bound from above.

### 3.3 Where else it applies

| Target | Certificate available |
|---|---|
| Multivariate optimizers | ∇f(x*) ≈ 0, and for a convex quadratic the exact minimiser −A⁻¹b (§4.1) |
| Newton-Raphson root finding | \|f(x*)\| ≈ 0 — a residual, not a distance |
| K-means | Each point is assigned to its nearest centroid; each centroid is the mean of its cluster. Both are Lloyd's-algorithm fixed-point conditions, checkable directly |
| Relaxation / cutting plane | The relaxation bound must not exceed the integer optimum; each cut must exclude the current point and no integer point |
| Robust counterpart | The robust solution must be feasible for every realisation in the uncertainty set — checkable by sampling the set's vertices |
| Constrained optimizers | KKT conditions: stationarity, primal and dual feasibility, complementary slackness |

The last row matters most, because `ConstrainedOptimizerTests` and `InequalityOptimizerTests` currently test that constraints are satisfied, which is primal feasibility alone — one of four KKT conditions.

## 4. What the older generation asserts instead

### 4.1 Distance to a known minimum, at unmotivated tolerances

The multivariate files (L-BFGS, gradient descent, Newton-Raphson, multi-start) share one pattern: run on a known function, assert the solution is within some distance of the known minimiser.

| Assertion | Problem |
|---|---|
| `result.iterations < 50, "Should converge quickly"` | A performance claim in a correctness test. L-BFGS on a 2D quadratic with exact line search converges in 2 iterations; 50 is not a derived bound. |
| Rosenbrock: `abs(x - 1.0) < 0.1`, `value < 0.1` | Loose enough that a run stalled in the curved valley passes. The minimum is exactly (1, 1) with value 0. |
| 1000-D sphere: `norm < 10.0` | The initial norm is ~31.6, so this asserts a 3× reduction and calls it convergence. |
| 100-D sphere: `norm < 0.5`, `value < 0.5` | For a sphere, value = norm², so the second is implied by the first and adds nothing. |

The replacement is the certificate. A local minimum is *defined* by a vanishing gradient:

```swift
@Test("A reported minimum satisfies the first-order condition")
func gradientVanishesAtTheReportedMinimum() throws {
    for problem in Self.smoothCorpus {
        let result = try problem.solve()
        #expect(result.converged, "\(problem.name): \(result.status)")
        // Not "close to the answer we know" — the condition that makes it an answer.
        #expect(result.gradientNorm < problem.tolerance,
                "\(problem.name): gradient norm \(result.gradientNorm)")
    }
}

@Test("On a convex quadratic the exact minimiser is known in closed form")
func quadraticMatchesTheClosedForm() throws {
    // ½x'Ax − b'x is minimised at A⁻¹b, so this pins the scale as well as the condition.
    let result = try solve(quadratic)
    for (j, expected) in exactMinimiser.enumerated() {
        #expect(abs(result.solution[j] - expected) < 1e-9 * max(1, abs(expected)))
    }
}
```

The first applies to every smooth problem in the suite, including Rosenbrock and the high-dimensional spheres where no exact assertion is currently possible. The second pins the scale, playing the role Cooper et al. plays for DEA.

### 4.2 Solution vectors where only the value is determined

`SimplexSolverTests` asserts `solution[0] == 1.0` and `solution[1] == 3.0` and so on across ten problems. For problems with a unique optimum that is safe today; for `degenerateProblem` and any future multiple-optima case it asserts a tie-break convention. This is exactly what `LinearProgrammingCertificateTests` explains a fixture must not do.

I verified every objective value in the certificate corpus by independent vertex enumeration (Appendix A.1). All twelve agree. The objective values are the durable claims; the vertices are not.

Where a solution vector genuinely is unique, the test should say so — the certificate file's `dualsAreDetermined` flag is the model for recording that kind of precondition in the corpus rather than in a comment.

### 4.3 Constraint restatement

The applied files — `ResourceAllocationTests`, `ProductionPlanningTests`, `MultiPeriodOptimizationTests`, `CapitalAllocationTests`, `DriverOptimizationTests`, and much of `StochasticOptimizationTests` — assert that the returned solution satisfies the constraints that were passed in. Weights sum to 1; production is non-negative; resource use is within capacity.

That tests the constraint machinery, not the objective. What is missing is whether the *right* solution was found. Two cheap additions:

- **A hand-solvable instance.** Most of these are small enough that the optimum can be computed by hand or by enumeration, as the LP corpus does.
- **A dominance check.** Perturb the reported solution in a feasible direction and confirm the objective does not improve. That is the certificate reduced to its minimum useful form, and it needs no second solver.

`meanVarianceOptimization` is the clearest instance: it sets up exactly the comparison its name promises — max-return versus mean-variance should differ in a specific direction — and then asserts only that both converged and both have positive standard deviation.

## 5. Assertions that cannot fail

| Test | Why |
|---|---|
| `weight.rounded() >= 0.0` (×2) | §2 item 1 |
| `optimalProduction.rounded() <= 200.0` | Admits 200.49 |
| `result.converged \|\| result.iterations > 50` | §2 item 2 |
| `result.expectedObjective > -1000.0` | "Profit should not be extremely negative" |
| `result.solution.dimension == numAssets` | Restates the input |
| `result.numberOfScenarios == 40` | Restates the configuration |
| `scenario.probability - 1.0/1000.0 < 1e-10` for equiprobable scenarios | Restates the construction |
| `history.count <= 20` where the configured memory is 20 | Restates the configuration |
| `cuts.count > 0`, `tableauRow.count > 0` | §2 item 5 |
| `bccScore >= ccrScore - 1e-6` | True by construction of the models — worth keeping as a cheap invariant, but it is not evidence the scores are right |
| Feasibility restatements across the applied files | §4.3 |

## 6. What the strong files record

Three defect narratives worth preserving as they are, because each documents a failure mode the rest of the corpus would not have caught.

**The LP shadow-price defect.** The extraction read an unsigned slack column by row index. That is correct for all-≤ maximisation and all-≥ minimisation, and wrong everywhere else: an equality row has no slack column, so it was priced at zero and strong duality failed by the whole objective; a type-grouped column layout means a row-indexed read lands on another row's column; a normalised negative right-hand side flips the relation. Every number in the result still looked ordinary.

**The empty-vector annihilator.** Adding vectors of unequal dimension returned a zero vector of the larger dimension — deliberate, tested, and wrong. It reached published documentation: `5.4-VectorOperations.md` seeded an accumulator with `VectorN.zero` (dimension 0), so the first addition mismatched and returned `[0, 0]`, discarding one customer. Dictionary order varies per process, so a different customer was dropped each run and the article printed a different warehouse location every time — (5.09, 4.67), then (6.30, 4.36). The replacement asserts bit-identical identity laws and NaN propagation for a genuine mismatch, and explains why NaN rather than a `precondition`: the package does not ship one that can crash a release build.

**The scenario-stream seeding.** This is the inverse of every other seeding finding in the corpus. Elsewhere the problem is that a fixed seed freezes one realisation. Here, passing `seed:` to `ScenarioGenerator.normal` seeds a *fresh* generator per call, so a generator invoked once per sample returns the same scenario every time and the sample average collapses to a point — which is not merely unrepresentative but materially harder to solve: 10 convergences in 60, against 40 in 40 for a real sample. Holding one generator and advancing it is what makes an SAA test reproducible without changing the problem.

The comment also frames the flakiness it replaced correctly: the unseeded path converged 298 times in 300, "a defensible property of the algorithm at 150 iterations, and a 1-in-150 chance of a red suite for reasons having nothing to do with the change under test."

**`ScenarioGeneratorDeterminismTests`** is the companion and covers ground nothing else in the corpus does: concurrent seeded runs each matching their serial baseline across rounds and across two generator types simultaneously; a seed above `Int.max` accepted rather than trapping; and seeds differing only above bit 47 producing different scenarios — which generalises the `SeededRNG` 32-bit defect from the first distribution batch into a standing test.

## 7. Coverage gaps

**Simplex.** Cycling under Bland's rule or a perturbation scheme; an empty constraint set; a variable appearing in no constraint; the interaction between `maximize` and an all-negative objective.

**DEA.** Units invariance for SBM and super-efficiency (§2 item 3); a DMU with a zero input or zero output; duplicate DMUs (partly covered — `DEACertificateTests` checks a duplicate scores identically); more DMUs than the frontier can distinguish, where nearly everything is efficient.

**Multivariate optimizers.** A function with no minimum (unbounded below); a saddle point, where Newton-Raphson converges to a non-minimum and the gradient certificate alone would accept it — the second-order condition is what distinguishes them; exact reproducibility of two runs from the same start.

**K-means.** The fixed-point conditions in §3.3; empty-cluster handling; k > n; reproducibility under a fixed seed.

**Constrained and inequality optimizers.** Full KKT rather than primal feasibility alone; an infeasible starting point; constraints that are inconsistent with each other.

**Robust and stochastic.** Feasibility across the uncertainty set's vertices; whether the robust solution is more conservative than the nominal one in the direction the model claims.

## 8. Recommended order of work

1. **Apply the gradient certificate** to L-BFGS, gradient descent, Newton-Raphson and multi-start (§4.1). This replaces roughly 40 distance assertions with the condition that defines a minimum, and it extends to problems where no exact answer is known.
2. **Fix the assertions that cannot fail** (§5), starting with the two `rounded()` non-negativity checks.
3. **Retire solution-vector assertions** in `SimplexSolverTests` in favour of objective values, keeping vectors only where uniqueness is established (§4.2).
4. **Extend units invariance** to SBM and super-efficiency (§2 item 3).
5. **Add KKT checks** to the constrained optimizers, and the fixed-point checks to K-means (§3.3).
6. **Assert async-versus-sync agreement** with `identical` (§2 item 6).
7. **Add a hand-solvable instance or a dominance check** to each applied file (§4.3).
8. **Restore or delete** the seven commented-out tests (§2 item 8), and switch the determinism file to `identical` (§2 item 7).

## 9. Gate rules

Two additions, both from patterns first seen clearly here.

1. **Rounding inside a comparison (blocking).** `x.rounded() >= 0.0` and `x.rounded() <= bound` defeat the comparison. This is distinct from the rounding-as-tolerance rule in the statistics review, which targets `(x * 1e4).rounded() / 1e4` against a literal; this one is a bare `.rounded()` inside a relational operator. Both sites here are in one file, so the rule is cheap.
2. **Certificate coverage (advisory).** For solver types, report whether the suite contains a test asserting an optimality condition (gradient norm, KKT, duality gap, fixed point) as distinct from a distance-to-expected-answer assertion. This is the solver-specific form of the fixture-coverage report, and it is what would surface §4.1 without reading 20 files.

Existing rules that apply: the vacuous-assertion rule (§5), the commented-out-assertion rule (seven sites), the `identical`-for-reproducibility rule (§2 item 7), and the silent-skip rule — `guard … else { continue }` after an `#expect` appears in both certificate files, where nothing is lost because the expectation reports first, but `try #require` is the cleaner form.

## Appendix A. Verified reference values

### A.1 LP corpus optima

Computed by independent vertex enumeration. Optimal *values* are unique; the vertices listed are the ones enumeration found, and where the optimal face is not a single point they are a tie-break, not a claim.

| Problem | Optimum | A vertex attaining it |
|---|---|---|
| wyndorGlass | 36.0 | (2, 6) |
| dietAllGreater | 9.0 | (3, 1) |
| minimiseWithBindingUpperBound | −12.0 | (2, 5) |
| minimiseMixedRelations | 9.0 | (3, 1) |
| maximiseWithLowerBound | 14.0 | (4, 2) |
| equalityAndUpperBound | 12.0 | (0, 4) |
| equalityOnly | 15.0 | (0, 5) |
| blendingThreeVariables | 45.0 | (5, 5, 0) |
| negativeRightHandSide | 6.0 | (4, 2) |
| wideScaleSpread | 3.0 | (1.9999, 1.0001) |
| degenerateVertex | 4.0 | (2, 2) — three constraints meet here |
| multipleOptima | 5.0 | (4, 1) — every point of the edge x+y=5 with x≤4, y≤4 |

Wyndor duals: (0, 1.5, 1).

### A.2 DEA closed-form scores

θ = (y_o/x_o) / max_j(y_j/x_j), input-oriented CCR with one input and one output.

**singleRatio** — A(2,1), B(4,3), C(6,3), D(3,1):

| DMU | Ratio | θ |
|---|---|---|
| A | 0.5 | 2/3 = 0.6666666666666666 |
| B | 0.75 | 1.0 |
| C | 0.5 | 2/3 |
| D | 0.3333 | 4/9 = 0.4444444444444444 |

**singleRatioManyUnits** — P1(10,4), P2(12,9), P3(8,2), P4(20,15), P5(5,3), P6(15,6):

| DMU | Ratio | θ |
|---|---|---|
| P1 | 0.4 | 0.5333333333 |
| P2 | 0.75 | 1.0 |
| P3 | 0.25 | 1/3 |
| P4 | 0.75 | 1.0 |
| P5 | 0.6 | 0.8 |
| P6 | 0.4 | 0.5333333333 |

Two units share the maximum ratio, so both are efficient — a useful case, since a frontier of one is the easier thing to get right.

### A.3 Optimizer closed forms

| Problem | Minimiser | Value |
|---|---|---|
| Sphere, any dimension | 0 | 0 |
| Rosenbrock (2D) | (1, 1) | 0 |
| Convex quadratic ½x'Ax − b'x | A⁻¹b | −½b'A⁻¹b |
| L-BFGS on a 2D quadratic with exact line search | — | converges in 2 iterations |

For a sphere, `value == norm²`, so asserting both is one assertion.
