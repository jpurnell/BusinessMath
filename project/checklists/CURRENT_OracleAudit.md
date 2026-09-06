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

Six oracles built. Four found defects; two found nothing, which is worth as much, because
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

## Tier A — iterative estimators · **COMPLETE**

- [x] `fitGeneralLME`, `fitRandomSlope`, `fitRandomIntercept` — statsmodels MixedLM
- [x] `DenseMatrix` Cholesky, solve, inverse — LAPACK
- [x] Holt-Winters — exact recovery on constructed series
- [x] `gStudy`, `twoWayANOVA` — statsmodels `anova_lm`
- [x] `movingAverage`, `exponentialMovingAverage` — pandas
- [x] `bayesianICC` — the ANOVA decomposition it must converge to

`LMEDiagnosticsTests`, `LMEApplicationsTests` and `RandomSlopeTests` are covered
indirectly: they exercise fitters that are now oracle-backed.

## Tier B — matrix and decomposition procedures · **NEXT**

37 files, 433 tests. Branch-and-bound, simplex, DEA, linear regression.

**Verification, not fixtures.** An LP optimum certifies itself — primal feasibility, dual
feasibility, complementary slackness, a zero duality gap — and a MIP adds integrality and
a bound. That is a stronger claim than agreeing with another solver, and it imports none
of that solver's tie-breaking or degeneracy conventions. Where a problem is degenerate or
has multiple optima, two correct solvers legitimately return different vertices with the
same objective, so matching them would manufacture false failures.

- [ ] Simplex — certificate: feasibility, duality gap, complementary slackness
- [ ] Branch-and-bound — the above plus integrality and the bound at each node
- [ ] DEA — efficiency scores in [0,1], frontier peers feasible, envelopment/multiplier duality
- [ ] Linear regression — normal equations residual, and a SciPy `lstsq` cross-check where
      the solution is unique

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

## Tooling

`Scripts/reference-fixtures/` — `generate_risk_solver.py`, `generate_mixed_models.py`,
`generate_linear_algebra.py`, `generate_holt_winters.py`, `generate_gstudy.py`,
`generate_moving_average.py`, `generate_bayesian_icc.py`.

statsmodels and pandas are not installed system-wide; `requirements-mixedmodels.txt` pins
them. Build the venv **outside Dropbox** — SPM and Dropbox sync fight over `.build`.

CI never runs Python. Every fixture is committed JSON.
