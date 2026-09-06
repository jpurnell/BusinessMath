# CURRENT — putting external oracles behind the numerical estimators

**Started** 2026-09-06 · **Branch** `main`

## Why

A concern about cognitive-complexity notes on `fitGeneralLME` turned out to be a red
herring — the complexity numbers are real but the `O(n^4)`/`O(n^5)` labels are static
nested-loop-depth counts, and the bounds are different variables (`m` groups, `r` random
effects of 1–3, `nig` group size), so the true cost is `O(m·r⁴)`.

The real finding was underneath it: **116 of 153 numerical-estimator test files, 1,359
tests, checked nothing against anything outside the package.** Every one of them asserted
self-consistency — a matrix is symmetric, residuals sum to zero, an information criterion
is finite. All true of a correct implementation. All equally true of a systematically
wrong one.

## Scorecard

Twelve oracles built. Six found defects; six found nothing, which is worth as much, because
the things they cleared are what everything else stands on.

| Target | Oracle | Result |
|---|---|---|
| Risk Solver distributions | SciPy fixture | **3 cancellations** — Cauchy `tan` beside π/2, Burr12 and Dagum `pow − 1` |
| `fitGeneralLME`, `fitRandomSlope` | statsmodels MixedLM | **projection bug** — variance components 12–24% low |
| `fitRandomIntercept` | same fixture | **ML while documented as REML** — τ² 23% low, σ² 83% high |
| Cholesky / `DenseMatrix` | LAPACK via SciPy | clean |
| Holt-Winters | exact recovery | **2 defects** — wrong seasonal phase, multiplicative residual |
| G-study (and `twoWayANOVA`) | statsmodels `anova_lm` | clean |
| Moving averages | pandas | clean |
| Bayesian ICC | ANOVA decomposition | clean |
| `irr` / `xirr` | scale invariance | **threw while sitting on the exact answer** at large magnitudes |
| Simplex duals | `d(obj)/d(rhs)`, vertex enumeration | **3 faults** — wrong column, reversed sign, equality rows unpriced |
| Branch-and-bound | exhaustive integer enumeration | **suboptimal answer reported `.optimal`** after one node |
| Multiple regression | statsmodels OLS | clean |
| DEA (CCR, BCC, super-efficiency) | closed form, units invariance, pair scan | clean |

## Tier A — iterative estimators · **COMPLETE**

- [x] `fitGeneralLME`, `fitRandomSlope`, `fitRandomIntercept` — statsmodels MixedLM
- [x] `DenseMatrix` Cholesky, solve, inverse — LAPACK
- [x] Holt-Winters — exact recovery on constructed series
- [x] `gStudy`, `twoWayANOVA` — statsmodels `anova_lm`
- [x] `movingAverage`, `exponentialMovingAverage` — pandas
- [x] `bayesianICC` — the ANOVA decomposition it must converge to

`LMEDiagnosticsTests`, `LMEApplicationsTests` and `RandomSlopeTests` are covered
indirectly: they exercise fitters that are now oracle-backed.

## Tier B — matrix and decomposition procedures · **COMPLETE**

37 files, 433 tests. Branch-and-bound, simplex, DEA, linear regression.

**Verification, not fixtures.** An LP optimum certifies itself — primal feasibility, dual
feasibility, complementary slackness, a zero duality gap — and a MIP adds integrality and
a bound. That is a stronger claim than agreeing with another solver, and it imports none
of that solver's tie-breaking or degeneracy conventions. Where a problem is degenerate or
has multiple optima, two correct solvers legitimately return different vertices with the
same objective, so matching them would manufacture false failures.

- [x] **Simplex** — feasibility, zero duality gap, complementary slackness, reduced-cost
      identity, plus exhaustive vertex enumeration and shadow prices measured by nudging
      the right-hand side. **Found 3 faults in one place.** The extraction indexed the
      objective row as if each row's slack sat in column `i` of the added block; standard
      form groups the added columns by kind, so a mixed model priced one constraint
      against another, a `≥` row's sign was reversed by its surplus column's `-1`, and an
      equality row — having neither slack nor surplus — was priced at zero, putting the
      whole objective outside `y'b = c'x`. All-≤ maximisation and all-≥ minimisation were
      right, the second only by two errors cancelling, and those are the two textbook
      shapes. Fixed by reconstructing `y' = c_B' B⁻¹` from the optimal basis.
- [x] **Branch-and-bound** — integrality, feasibility, objective consistency, the bound
      bracketing with a closed gap, the LP relaxation bounding the integer optimum, and
      exhaustive enumeration of the boxed integer points. **Found a suboptimal answer
      returned as `.optimal`.** The rounding heuristic abandoned a fractional node without
      branching and recomputed the bound from a queue that at the root is still empty;
      `updateBestBound` reads an empty queue as "search exhausted" and collapses the bound
      onto the incumbent, closing the gap around the answer being checked. Returned 13
      where the optimum is 14, after one node.
- [x] **DEA** — clean. Closed form for one input and one output, envelopment attainability
      from the reported reference set, peers efficient, units invariance over four scale
      factors, `BCC ≥ CCR` with scale efficiency at most one, `Σλ = 1` under BCC,
      super-efficiency at or above 1 exactly on the frontier, and a pair scan that cannot
      beat the reported score.
- [x] **Multiple regression** — clean. Every derived statistic the existing suite only
      bounded now matches statsmodels: standard errors, t, two-tailed p, t-quantile
      confidence intervals, F and its p-value, adjusted R², and auxiliary-regression VIF.
      Tolerances derived per design from `cond(X'X)`. Plus residual orthogonality
      `X'(y - Xβ) = 0`, which needs no reference at all.

## Tier C — closed-form, multi-step

20 files, 274 tests. Post-hoc ANOVA, interpolation, risk metrics. Hand-derivable, so
published worked examples are the cheapest oracle.

- [ ] Post-hoc tests (Tukey, Bonferroni, Scheffé) against published examples
- [ ] Interpolators against analytic values at the knots and known polynomials
- [ ] Risk metrics (VaR, CVaR) against closed forms for the normal case

## Technique that keeps working

1. **Watch the iteration trajectory.** Splitting a long routine into phases located the
   AI-REML bug in one probe: the EM warm-up converged to exactly statsmodels' ML estimate,
   so that phase was right and the next was moving the wrong way.
2. **Cross-check implementations of the same thing.** `fitRandomSlope` agreeing with
   `fitGeneralLME` to every digit proved the fault was shared; `fitRandomIntercept`
   disagreeing proved it had its own.
3. **Prefer the mathematics where it fixes the answer.** statsmodels and this package's
   Holt-Winters differ by 0.5% on initialisation convention alone — asserting against it
   would report a convention as a defect. A noiseless constructed series has one answer.
4. **Assert properties, not just numbers.** Scale invariance found the `irr` defect; every
   residue of `n mod m` found the Holt-Winters phase defect.

## Traps

- **Establish where an exactness claim holds, by measurement.** Holt-Winters exact recovery
  needs *both* no trend *and* a whole number of cycles; that took two rounds of asserting
  too broadly and reading what failed.
- **Differentiate tolerances and say why.** Near-degenerate designs, ill-conditioned
  matrices and boundary variance components each need their own bound. One bound across
  the lot is either meaningless or unachievable.
- **Keep some assertions independent of the oracle** — `LLᵀ = A`, `A·A⁻¹ = I`, percentages
  summing to 100 — so a fixture and the code cannot agree through a shared misreading.
- **`withKnownIssue` for a diagnosed-but-unfixed defect.** Suite stays green, the finding
  stays in the code, Swift Testing reports the unexpected pass when it is fixed.
- **Simulation-recovery is not a reference.** `estimatesRecoverTheTruth` passed throughout
  the REML defect; a 24% bias in a variance component sits inside the sampling noise of any
  one dataset.
- **Sweep `Tests/` for the Swift 6.2.1 type-check shape, not only `Sources/`.** Fixture code
  is full of index arithmetic and conversions inside mapped closures, which is exactly it.
- **Do not push over an in-flight CI run.** `swift.yml` has a concurrency group; a cancelled
  Linux job is not a passing one.
- **Verify a push by transfer, not by exit status.** `git push origin <branch>` pushes the
  *named local branch*, not `HEAD`. Run from a different branch it reports success and moves
  something else entirely; `git ls-remote` against the local SHA is what catches it.
- **A certificate beats a fixture where the theory supplies one.** An LP optimum, a MIP
  optimum and a DEA score all certify themselves, and none of the three imports another
  solver's tie-breaking. Degenerate LPs and tied MIP optima genuinely have several right
  answers — comparing solution *vectors* would have manufactured failures where comparing
  *values* found real ones.
- **An independent brute force is worth writing.** Vertex enumeration and integer-box
  enumeration are a dozen lines each, cannot prune, and therefore cannot prune wrongly.
  Both found what the theory-based checks alone would have missed.
- **Look for the shape that made the passing cases pass.** All-≤ and all-≥ were the two
  correct simplex shapes; they are also the two textbook examples. When a corpus agrees
  everywhere, ask what it is not varying.

## Tooling

`Scripts/reference-fixtures/` — `generate_risk_solver.py`, `generate_mixed_models.py`,
`generate_linear_algebra.py`, `generate_holt_winters.py`, `generate_gstudy.py`,
`generate_moving_average.py`, `generate_bayesian_icc.py`, `generate_regression.py`.

Until 2026-09-06 **none of these were in the repository**: `.gitignore` carried `scripts/`
to drop a long-removed `scripts/update_readme.sh`, and on a case-insensitive filesystem that
also matched `Scripts/`. Every fixture was unreproducible from a clean clone while CHANGELOG
and master_plan both cited the directory as part of the package. Now tracked.

Tier B needed no Python at all beyond the regression fixture — a certificate is generated by
the theory, not by another tool, which is a large part of why it is preferable where it
applies.

statsmodels and pandas are not installed system-wide; `requirements-mixedmodels.txt` pins
them. Build the venv **outside Dropbox** — SPM and Dropbox sync fight over `.build`.

CI never runs Python. Every fixture is committed JSON.
