#!/usr/bin/env python3
"""Reference values for multiple linear regression, from statsmodels OLS.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_regression.py

## What actually needs an oracle here

`MultipleLinearRegressionTests` has 22 tests. The coefficient checks are sound —
they fit noiseless data where the answer is exact and assert it to 1e-10. But
every *statistical* quantity is checked with a bound rather than a value:

    #expect(result.standardErrors.allSatisfy { $0 > 0 })
    #expect(result.fStatistic > 1000)
    #expect(result.fStatisticPValue < 0.001)
    #expect(result.adjustedRSquared < result.rSquared)

Not one standard error, t-statistic, p-value, VIF or confidence interval is
pinned to a number. Those are the quantities that get reported, and they are the
ones a convention error silently moves:

- residual variance divided by `n - p` instead of `n - p - 1`;
- a normal quantile where a t quantile belongs, which is close for large `n` and
  wrong for small;
- a one-tailed p-value reported as two-tailed, which halves every one;
- an F-statistic against the wrong pair of degrees of freedom;
- VIF computed from the correlation matrix rather than by regressing each
  predictor on the others — the same for two predictors, different for three.

Every one of those passes `> 0`, and several pass `> 1000`.

## Designs

Each case is chosen so that a specific convention is load-bearing:

- **small n** — a t quantile and a normal quantile differ by a wide margin at
  8 observations, so the confidence intervals separate the two.
- **many predictors** — `n - p - 1` and `n - p` differ proportionally more.
- **collinear** — VIF is only interesting when it is large, and the
  correlation-matrix shortcut breaks with three or more predictors.
- **weak fit** — an F-test near its acceptance region, where a p-value has to be
  right rather than merely small.

Values come from statsmodels' OLS with a constant added, which is the same model
BusinessMath fits. VIF comes from `variance_inflation_factor` on the predictor
matrix *without* the constant, matching a per-predictor auxiliary regression.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import scipy
import statsmodels
import statsmodels.api as sm
from statsmodels.stats.outliers_influence import variance_inflation_factor

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "regression.json")

CONFIDENCE = 0.95


def build_case(name, note, x, y):
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    n, p = x.shape

    design = sm.add_constant(x, has_constant="add")
    fit = sm.OLS(y, design).fit()

    # statsmodels orders parameters [const, x1, ..., xp]; BusinessMath reports the
    # intercept separately from the coefficient array, so split them here rather
    # than making the test do index arithmetic against a convention.
    params = fit.params
    bse = fit.bse
    tvalues = fit.tvalues
    pvalues = fit.pvalues
    intervals = fit.conf_int(alpha=1 - CONFIDENCE)

    # How much precision the normal equations can be expected to keep.
    #
    # BusinessMath forms and inverts X'X; statsmodels uses a pinv of X. Those agree
    # in exact arithmetic and diverge in floating point by roughly the condition
    # number of X'X, which is the *square* of X's. Deriving the tolerance from that
    # number states the honest expectation per design, rather than picking one bound
    # that is either vacuous on the easy cases or unmeetable on the hard ones.
    xtx_condition = float(np.linalg.cond(design.T @ design))
    tolerance = max(1e-9, 20 * xtx_condition * np.finfo(float).eps)

    # VIF needs at least two predictors to mean anything.
    if p >= 2:
        vif = [float(variance_inflation_factor(x, j)) for j in range(p)]
    else:
        vif = []

    return {
        "name": name,
        "note": note,
        "x": [[float(v) for v in row] for row in x],
        "y": [float(v) for v in y],
        "n": int(n),
        "p": int(p),
        "confidenceLevel": CONFIDENCE,
        "conditionNumber": xtx_condition,
        "tolerance": float(tolerance),
        "intercept": float(params[0]),
        "coefficients": [float(v) for v in params[1:]],
        # Standard errors, t and p are reported for the intercept as well, in the
        # same [intercept, coefficients...] order BusinessMath uses.
        "standardErrors": [float(v) for v in bse],
        "tStatistics": [float(v) for v in tvalues],
        "pValues": [float(v) for v in pvalues],
        "confidenceIntervals": [
            {"lower": float(lo), "upper": float(hi)} for lo, hi in intervals
        ],
        "rSquared": float(fit.rsquared),
        "adjustedRSquared": float(fit.rsquared_adj),
        "fStatistic": float(fit.fvalue),
        "fStatisticPValue": float(fit.f_pvalue),
        # statsmodels calls this mse_resid; its square root is the residual
        # standard error, the usual `s`.
        "residualStandardError": float(np.sqrt(fit.mse_resid)),
        "residuals": [float(v) for v in fit.resid],
        "fittedValues": [float(v) for v in fit.fittedvalues],
        "vif": vif,
    }


def cases():
    out = []

    # 1. Small sample, one predictor. n = 8, so the 97.5% t quantile is 2.447
    # against a normal's 1.960 — a 25% difference in every interval half-width.
    r = np.random.default_rng(21)
    x1 = np.array([[1.0], [2.0], [3.0], [4.0], [5.0], [6.0], [7.0], [8.0]])
    y1 = 3.0 + 2.5 * x1[:, 0] + r.normal(0, 1.5, 8)
    out.append(build_case(
        "smallSampleOnePredictor",
        "Eight observations. The t and normal quantiles differ by 25% here, so an "
        "interval built on the wrong one misses by far more than any tolerance.",
        x1, y1))

    # 2. Textbook-scale, two predictors, strong fit.
    r = np.random.default_rng(22)
    x2 = np.column_stack([np.linspace(0, 20, 30), r.normal(10, 3, 30)])
    y2 = 5.0 + 1.8 * x2[:, 0] - 0.9 * x2[:, 1] + r.normal(0, 2.0, 30)
    out.append(build_case(
        "twoPredictorsStrongFit",
        "Thirty observations, two predictors, a clear signal. The ordinary case, "
        "present so the ordinary case is pinned to numbers rather than bounds.",
        x2, y2))

    # 3. Many predictors relative to n: n - p - 1 = 12 against n - p = 13, so an
    # off-by-one in the residual degrees of freedom moves `s` by about 4%.
    r = np.random.default_rng(23)
    x3 = r.normal(0, 1, (18, 5))
    y3 = 1.0 + x3 @ np.array([2.0, -1.5, 0.5, 3.0, -0.25]) + r.normal(0, 1.0, 18)
    out.append(build_case(
        "manyPredictorsRelativeToN",
        "Five predictors on eighteen observations. Residual degrees of freedom are "
        "12, not 13 — an off-by-one moves the residual standard error, every "
        "standard error, every t and every p-value together.",
        x3, y3))

    # 4. Collinear predictors: VIF is only diagnostic when it is large, and with
    # three predictors the correlation-matrix shortcut and the auxiliary
    # regression stop agreeing.
    r = np.random.default_rng(24)
    base = r.normal(0, 1, 40)
    x4 = np.column_stack([base, base * 0.95 + r.normal(0, 0.2, 40), r.normal(0, 1, 40)])
    y4 = 2.0 + x4 @ np.array([1.0, 0.5, -2.0]) + r.normal(0, 1.0, 40)
    out.append(build_case(
        "collinearPredictors",
        "Two predictors correlated at about 0.98, one independent. VIF above 10 on "
        "the first two and near 1 on the third. With three predictors a VIF taken "
        "from the correlation matrix no longer equals the auxiliary-regression "
        "definition, so this case separates them.",
        x4, y4))

    # 5. A weak relationship, where the F-test lands near its acceptance region and
    # a p-value has to be correct rather than merely small.
    r = np.random.default_rng(25)
    x5 = np.column_stack([r.normal(0, 1, 25), r.normal(0, 1, 25)])
    y5 = 0.5 + 0.35 * x5[:, 0] + r.normal(0, 1.4, 25)
    out.append(build_case(
        "weakRelationship",
        "A weak signal: R² near 0.1 and an F-test close to its acceptance region. "
        "Every bound-style assertion in the existing suite ('F > 1000', 'p < "
        "0.001') is vacuous here, which is the point — a p-value has to be a value.",
        x5, y5))

    # 6. Wide scale spread between predictors, which is where the normal-equations
    # conditioning shows.
    r = np.random.default_rng(26)
    x6 = np.column_stack([r.normal(0, 1, 35), r.normal(50_000, 8_000, 35)])
    y6 = 12.0 + 3.0 * x6[:, 0] + 0.0004 * x6[:, 1] + r.normal(0, 1.0, 35)
    out.append(build_case(
        "wideScaleSpread",
        "Predictors four orders of magnitude apart. X'X is correspondingly "
        "ill-conditioned, so this case carries a looser tolerance honestly rather "
        "than pretending the others are as hard.",
        x6, y6))

    # 7. Exact fit, no noise: a boundary the statistics degenerate at.
    x7 = np.array([[float(i), float(i * i)] for i in range(1, 11)])
    y7 = 4.0 + 2.0 * x7[:, 0] - 0.5 * x7[:, 1]
    out.append(build_case(
        "exactFitNoNoise",
        "A relationship with no error term at all. R² is 1, the residual standard "
        "error is 0 and the t-statistics are unbounded — kept to pin what happens "
        "at that boundary rather than to compare finite numbers.",
        x7, y7))

    return out


def main() -> int:
    built = cases()
    payload = {
        "name": "regression",
        "reference": (f"statsmodels {statsmodels.__version__} OLS "
                      f"(scipy {scipy.__version__}, numpy {np.__version__})"),
        "note": ("Coefficients on noiseless data are already checked exactly by the "
                 "existing suite. What is new here is every derived statistic — "
                 "standard errors, t, p, F, adjusted R², VIF and the confidence "
                 "intervals — each of which the existing tests only bound. The "
                 "designs are chosen so a degrees-of-freedom, quantile or tail "
                 "convention changes the answer by more than any tolerance."),
        "confidenceLevel": CONFIDENCE,
        "cases": built,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(built)} designs")
    for c in built:
        vif = f" maxVIF={max(c['vif']):.1f}" if c["vif"] else ""
        print(f"  {c['name']:<28} n={c['n']:>3} p={c['p']} R2={c['rSquared']:.4f} "
              f"pF={c['fStatisticPValue']:.3e} cond={c['conditionNumber']:.2e} "
              f"tol={c['tolerance']:.1e}{vif}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  python {platform.python_version()} · generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
