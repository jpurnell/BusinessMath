# A review points at the file; only a generator reaches the geometry the solver makes

**2026-09-13 to 2026-09-18** · shipped **v3.0.0-alpha.6** at `346a50ad` (7,815 tests / 703
suites) and **v3.0.0-alpha.7** at `13b842f1` · 7,908 tests / 721 suites · quality-gate 40 of
45 checkers with 5 not selected at the alpha.7 tag; `--check all` last recorded at 45 of 45,
0 errors, 0 warnings in `d3359c3c`

Reconstructed on 2026-10-05 from the git history and the CHANGELOG; it is not a contemporaneous
note.

Sixty commits after the alpha.5 tag at `82bff1ee`, thirty to each release. alpha.6 is the
test-review roadmap (`project/plans/TEST_REVIEW_ROADMAP.md`, phases A to G). alpha.7 is Tier 2
of the quality programme, where a high cognitive-complexity score is treated as a marker for
code no one has an oracle for. The two halves found the same thing from opposite ends: **a
written claim about the code, whether a review row or a hand-built fixture, was wrong or blind
far more often than the code path it described had ever been run.**

---

## What shipped

**alpha.6.** Breaking: `Bond`, `ZeroCouponBond` and `AmortizingBond` take a
`dayCount: DayCountConvention`, defaulting to `.actual365`, replacing a `365.25` constant applied
to a seconds interval at ten sites (`03220a61`). Prices move 12¢, 31¢ and 55¢ per 1,000 of face
at two, ten and thirty years; 30/360 reproduces the textbook closed form 1043.7603. Fixed: a
negative lower bound written as a closure was truncated to zero (`1063934b`); `EOQModel.calculate`
overflowed at `S = D = 1e200` (`77c37352`); `MonthDay` constructed February 30 and returned a
plausible fiscal year (`651c81e9`). Added: `seed:` on `runFinancialSimulation`,
`ModifiedZScoreAnomalyDetector`, `IQRAnomalyDetector`, `SimplexTableau.projectToStructuralSpace`.
Tests: 211 `?? <literal>` lookups became `try #require`, every disabled and commented-out test
was answered for, and the type-only `#expect(throws:)` population went from 524 to 14.

**alpha.7.** `ContinuousDistribution` now requires `pdf(_:)` with no default implementation
(`e9a45ea2`), after `chi2pdf` was found to be a left-hand Riemann sum of the density, that is,
the CDF (`512e6458`); `chiSquaredPDF(x:df:)` replaces it. Breaking: `TerminationReason` gains
`.infeasible`. The rest is solver work: Gomory mixed-integer cuts, exact linear constraints in
branch-and-bound, an augmented-Lagrangian constrained solve shared by six heuristics, repaired
simulated annealing and genetic algorithm, `differentiationStep(_:at:)`, overflow-safe vector
norms, a bytecode optimizer arity table, a real lower bound in `CuttingPlaneMaster`, and
`solveRelaxation` decomposed from complexity 291 to 55 (`e70829ac`). Five Gaussian eliminations
became one `gaussianSolve` with a named `SingularityCriterion` (`34c779ae`), and `fitRandomSlope`
now delegates to `fitGeneralLME`, deleting 918 lines (`c25390e4`).

---

## What is worth carrying forward

### 1. The reviews were a detector, not an oracle

Every one of Phase A's items A2 to A6 differed materially from its roadmap entry. A3 was
"document one property" and found two doc comments stating a formula the code does not
implement. A4 was "pick 365 or 365.25" and was a non-convention at ten sites. A6 was a naming
question and was a solver feature that had never worked. A5's premise was refuted outright: the
z-score detector's baseline is the window *before* the point, so the review's 2.4694 was
arithmetic nobody in the library performs. Two rows had been marked "verified" when only the
arithmetic was checked and the code never run. Later batches refuted L10 and the H-model
"defect" as well, while F3's thirty-five supplied reference values all held.

The handoff's conclusion (`4923f33f`): the reviews are valuable because they point at the right
file with enough specificity that someone runs the code, not because they are right.

### 2. Cut tests that never cut, hiding cuts that were never valid

A6 led to `06d997ad`: every Gomory cut was expressed over structural variables *and slacks* and
then imposed over the structural variables alone, so it read `0 <= -0.7071` and made the LP
infeasible on the first cut. It failed safe, which is why it survived; answers were right and
`enableCuttingPlanes: true` bought nothing. With cuts working, `81f7d733` then found the
fractional cut was invalid on cut rows, whose slacks are not integral: on a problem with optimum
14, budgets of 3, 5 and 6 rounds returned 12, 10 and 7, each labelled `.optimal`.

The tests could not see either. Fourteen of sixteen tests in `Phase1_CutValidityTests` never
generated a cut, because single all-ones constraints leave zero fractional parts (`b4bd8761`).
All seven `DegeneracyProtectionTests` ran zero-cut problems. Four assertions were calibrated to
the defect, claiming an optimum of 3 where it is 4. The `withKnownIssue` on A6 worked as a
tripwire: after the fix the only failure in 7,781 tests was `Known issue was not recorded`.

### 3. A fixture set cannot reach the geometry the algorithm manufactures

`5a96e887` found three defects in a default `BranchAndBoundSolver()`. The relaxation solver
recovered every constraint's coefficients by central differences at h = 1e-8, including for
`.linearInequality`, which stores them exactly. Branching slices the polytope down to slivers
and single points, so a 1e-10 perturbation emptied a feasible node; the subtree was pruned and
18 returned as `.optimal`. Under `.depthFirst` the global bound was read from `queue.peek()`,
the next node to explore rather than the extremum.

Branch-and-bound had already been audited with exhaustive enumeration and marked complete. The
difference was coverage, not method: nobody writes down a polytope in order to branch it into a
single point. `IntegerProgramRandomizedAuditTests` (5,820 checks, fixed seeds) is the remedy,
and the commit states the rule: an audit of a numerical routine ends with a generator and an
oracle committed to the suite. Its first enumeration box was a fixed 30 and produced three false
failures; a box that misses the optimum makes the oracle wrong, not merely incomplete.

### 4. `converged` said the search had settled, and a default of zero said it was feasible

Nineteen of twenty-four constrained runs returned a point violating its constraints with
`converged == true` (`0809cd1c`). A fixed-weight quadratic penalty puts the stationary point at
`bw/(1 + w)`, strictly inside the bound, and the reported value came back below anything
attainable. At objective scale 1000 the violation was 91%. `IslandModel` was missed in that fix
and returned x0 = 0.2248 against a bound of 3 with `constraintViolation` reading 0.0, the
field's default (`85e1e991`). The commit's own lesson: a field whose default value is a claim is
a fail-silent trap. The same commit's `OptimizerSolutionQualityTests` exist because the old
tolerances included 3.0, 5.0, 10.0, 30.0, 50.0 and 100.

### 5. A fixed finite-difference step returns exactly zero, in seven places

`numericalGradient` stepped by a fixed absolute epsilon, so past about 1e10 `x + epsilon == x`
and the gradient was zero. Gradient descent diverging on Rosenbrock reported
`value = 1.9448624575642407e+105`, `.converged` (`65b4ebca`). The follow-up swept the class
(`c18434c5`): seven finite differences in the package, one already correct, two on bounded
domains, four wrong, with the Hessian failing soonest at 1e6. `NewtonRaphsonOptimizer` had the
right pattern with a comment explaining it the whole time.

### 6. The only cross-process determinism test was a documentation checker

Four sites iterated a `Set<Int>` and let the order decide something, so the same integer program
explored a different tree in each process (`39ed2885`). No unit test could catch it, because
the hash seed is fixed for the life of a process. `doc-run` did, by executing
`5.8d-LinearFunctionAPI.md` twice in separate processes and failing about one run in three.

---

## Process

**Flip to `throws: Never.self` and read the transcript.** Reading call sites back to their
guards produced seven wrong strings in the first two G2 batches. Rewriting every remaining site
to `Never.self` and running once made Swift Testing print what each site actually throws
(`077562dd`).

**Two commit messages carry wrong counts.** `741f786b` says ninety where 66 were new;
`077562dd` says 350 where the measured figure is 390. `3d8d59fc` put the measured ledger
(524, 522, 470, 404, 14) in the roadmap, which is the record to trust.

**One passing run is not evidence of determinism.** The hash-seed flake was first blamed on the
finite-difference change on the strength of one clean baseline run, and bisected for several
rounds; three runs at HEAD showed it failing without that work.

**A warning count from an incremental build describes what changed.** Three warnings surfaced
only when their file recompiled, each after an earlier run had reported zero (`2af9e0ff`).

**A debug benchmark can have the wrong sign.** The `BytecodeInterpreter.evaluate` change is 44%
faster at -O and measured 34% slower in debug, and was nearly reverted on that number
(`d3359c3c`).

**Check a harness by breaking things, and avoid parameters of 0 or 1.** Deleting
`DistributionDagum`'s scale factor from its density changed nothing because the subject was
built with `scale: 1` (`e9a45ea2`).

**Tagging does not change the gate profile.** Measured on both sides of the alpha.6 tag: 45 of
45 with `--check all`, 40 of 45 by default (`cbb83d98`). `doc-run` failures under load recurred
throughout and passed on quiet re-runs.

---

## Not done

- `SaaSModel` and `ManufacturingModel` do not validate inputs; a `churnRate` of 1.2 ends month
  one at -20 customers. Held as the suite's one deliberate `withKnownIssue`.
- The Gomory projection fix (`06d997ad`) has no Fixed entry in the alpha.6 CHANGELOG by decision;
  it is listed under "Not recorded here, deliberately".
- Phase C's gate rules were handed to `quality-gate-swift` as a proposal (`19857325`); 53
  `#expect(true)` sites and about 210 `Date()` sites remain for that work and for human review.
- `project/plans/TIER2_COMPLEXITY_QUEUE.md` lists 205 functions over the complexity threshold.
- Recorded and left: `dValue` and `kendallW` disagree on an incomplete ranking (19.0 and 10.0)
  and `dValue` answers empty input with 0; `harmonicMean` reports a NaN as a zero;
  `rootLPBoundAfterCuts` is assigned at every node; the interpolators' duplicated struct shape
  needs a public protocol to remove.
