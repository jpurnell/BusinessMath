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

## Scorecard — **all three tiers complete**

Sixteen oracles built. Seven found defects; nine found nothing, which is worth as much,
because the things they cleared are what everything else stands on.

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
| Tukey HSD | SciPy `tukey_hsd` + statsmodels | **`df` ignored** — returned the ν=∞ studentized range, so every p-value was anti-conservative |
| Bonferroni, Scheffé | SciPy `t` / `f` | clean |
| Interpolators (7 schemes) | SciPy `interpolate` | clean |
| VaR / CVaR | numpy type-7 + normal closed forms | clean; two CVaR entry points compute different things |

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

## Tier C — closed-form, multi-step · **COMPLETE**

- [x] **Post-hoc tests** — Bonferroni and Scheffé clean. **Tukey carried a real defect:**
      `studentizedRangeCDF(q:k:df:)` took `df` and never referred to it, computing
      `k∫φ(z)[Φ(z+q)−Φ(z)]^(k−1)dz` — the studentized range at ν = ∞, where the standard
      deviation is known rather than estimated. Too narrow a distribution, too thin a tail,
      and every p-value too small. Two comparisons crossed α = 0.05 (0.0431 reported for
      0.0554); at k = 2, where the studentized range *is* the t, it was wrong by 428×.
      Anti-conservative is the one direction a family-wise correction must not fail in, and
      the error grew with k — exactly when the correction matters most. Fixed by adding the
      missing outer integral over the chi density.
- [x] **Interpolators** — clean. 1,599 SciPy values across linear, cubic spline (natural,
      not-a-knot, clamped), Akima (original and modified), PCHIP and barycentric. Plus
      polynomial reproduction and PCHIP's monotonicity, neither of which needs a reference.
- [x] **Risk metrics** — clean against numpy's type-7 quantile and against the normal closed
      forms `μ + σΦ⁻¹(α)` and `μ − σφ(z)/α`, checked on a stratified sample that carries no
      sampling noise. Recorded as a known issue: `SimulationResults.conditionalValueAtRisk`
      and `ConditionalValueAtRisk.calculate` compute **different** estimators and agree only
      when `n·alpha` is an integer.

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
- **`quality-gate --no-cache` is not the whole gate.** It runs the *default profile* and says
  so quietly: "40 of 45 checkers · 5 not selected". `doc-claims` and `doc-run` are among the
  five, and both were failing while every local run reported PASSED — including the runs that
  cleared v2.13.0 for tagging. Use **`--check all`**, and `--continue-on-failure` so one early
  failure does not hide the rest behind "15 NOT REACHED".
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
- **An unused parameter is a defect the compiler will not report.** `studentizedRangeCDF`
  accepted `df` and never mentioned it again; Swift does not warn on unused parameters, so
  the gate was silent. Reading a signature against its body found in seconds what 30 tests
  had missed for as long as they had existed.
- **Make the corpus prove it can discriminate.** Each fixture now asserts its own
  discriminating power — that the two Akima variants actually differ somewhere, that a
  design exists where the studentized range and a t are far apart, that an all-positive
  sample exists so a signed quantile can be told from a magnitude. Without that, a green
  suite may only mean the corpus was easy.
- **`json.dumps` writes `NaN` by default**, which Python reads back happily and every strict
  parser rejects. Always `allow_nan=False`; the failure is then at generation, where it is
  cheap.

## Tooling

`Scripts/reference-fixtures/` — `generate_risk_solver.py`, `generate_mixed_models.py`,
`generate_linear_algebra.py`, `generate_holt_winters.py`, `generate_gstudy.py`,
`generate_moving_average.py`, `generate_bayesian_icc.py`, `generate_regression.py`,
`generate_posthoc.py`, `generate_interpolation.py`, `generate_risk_metrics.py`.

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
