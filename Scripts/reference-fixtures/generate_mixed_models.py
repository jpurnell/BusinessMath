#!/usr/bin/env python3
"""Reference fits for the linear mixed-effects models, from statsmodels.

Run once; commit the output. CI never executes this — the Swift suite reads the
committed JSON.

    python3 -m venv .venv
    .venv/bin/pip install -r requirements-mixedmodels.txt
    .venv/bin/python generate_mixed_models.py

## Why this exists

`GeneralLMETests` had 22 tests and no external oracle. Every one of them asserted a
*self-consistency* property — the G matrix is symmetric, residuals sum to zero, AIC and
BIC are finite, fitted values plus residuals recover the observations. All true of a
correct fit, and all equally true of a systematically wrong one: a REML implementation
that converges to the wrong optimum still produces a symmetric G, still has residuals
summing to zero, still reports finite information criteria.

The same gap in the Risk Solver distributions produced three real defects the moment a
SciPy fixture was pointed at them. A 997-line EM/AI-REML routine is a much larger surface
than a closed-form quantile, and unlike those it has no hand-checkable answer at all.

## What is recorded

The **data** as well as the estimates. The Swift side must fit exactly the same X, Z, y
and grouping, or the comparison means nothing — so the arrays are written out in full
rather than regenerated from a seed on both sides, where the two RNGs would diverge.

## What is NOT compared, and why

The REML log-likelihood. Implementations differ by additive constants in it — whether the
`-n/2 log(2π)` term is included, whether the `log|X'V⁻¹X|` term is, and how the constant
is folded in. Two correct fits can report different numbers. The estimates themselves —
β, G, σ²_e — carry no such convention, so those are what the fixture asserts on.
"""

import hashlib
import json
import platform
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import scipy
import statsmodels
import statsmodels.api as sm

warnings.filterwarnings("ignore")

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "mixedModels.json")


def build_case(name, note, m, sizes, r, beta_true, tau, sigma, seed, slope_data=True):
    """Simulate one dataset, fit it with statsmodels, and record both."""
    rng = np.random.default_rng(seed)

    groups = np.concatenate([np.full(sizes[g], g) for g in range(m)])
    n = len(groups)

    x1 = rng.normal(0.0, 1.0, n)
    X = np.column_stack([np.ones(n), x1])          # intercept + one covariate

    if r == 1:
        Z = np.ones((n, 1))
    else:
        # Random intercept and random slope on the same covariate.
        Z = np.column_stack([np.ones(n), x1])

    # True random effects, drawn per group.
    cov = np.diag(np.asarray(tau, dtype=float))
    u = rng.multivariate_normal(np.zeros(r), cov, size=m)

    zu = np.einsum("ij,ij->i", Z, u[groups])
    eps = rng.normal(0.0, np.sqrt(sigma), n)
    y = X @ np.asarray(beta_true, dtype=float) + zu + eps

    model = sm.MixedLM(y, X, groups=groups, exog_re=Z)
    fit = model.fit(reml=True, method="lbfgs", maxiter=500)

    cov_re = np.asarray(fit.cov_re, dtype=float)
    if cov_re.ndim == 0:
        cov_re = cov_re.reshape(1, 1)

    return {
        "name": name,
        "note": note,
        "groups": [int(g) for g in groups],
        "X": [[float(v) for v in row] for row in X],
        "Z": [[float(v) for v in row] for row in Z],
        "y": [float(v) for v in y],
        "randomEffectsPerGroup": int(r),
        "truth": {
            "beta": [float(v) for v in beta_true],
            "tau": [float(v) for v in tau],
            "sigmaSquared": float(sigma),
        },
        "statsmodels": {
            "beta": [float(v) for v in np.asarray(fit.fe_params)],
            "standardErrors": [float(v) for v in np.asarray(fit.bse_fe)],
            # The random-effects covariance in the response's own units. statsmodels also
            # exposes `cov_re_unscaled`, which is this divided by `scale`; taking the
            # wrong one would inflate or shrink G by the residual variance and every
            # symmetry and positivity check would still pass.
            "gMatrix": [[float(v) for v in row] for row in cov_re],
            "residualVariance": float(fit.scale),
            "converged": bool(fit.converged),
        },
    }


CASES = [
    dict(name="randomIntercept_balanced",
         note="Eight groups of six, random intercept only. The simplest case that has a "
              "variance component to get wrong.",
         m=8, sizes=[6] * 8, r=1, beta_true=[3.0, 1.5], tau=[2.0], sigma=0.5,
         seed=20260906),
    dict(name="randomIntercept_unbalanced",
         note="Unequal group sizes, which is where a method-of-moments start and a "
              "likelihood optimum diverge most.",
         m=10, sizes=[3, 8, 4, 12, 5, 6, 9, 4, 7, 11], r=1,
         beta_true=[-1.0, 2.25], tau=[1.25], sigma=0.8, seed=20260907),
    dict(name="randomIntercept_smallVariance",
         note="A random-effect variance far below the residual variance, where an "
              "estimator that floors it at zero would still look plausible.",
         m=12, sizes=[5] * 12, r=1, beta_true=[10.0, -0.5], tau=[0.05], sigma=2.0,
         seed=20260908),
    dict(name="randomSlope_balanced",
         note="Random intercept and slope, r = 2. The G matrix now has an off-diagonal "
              "the diagonal-only checks in the suite cannot see.",
         m=15, sizes=[8] * 15, r=2, beta_true=[2.0, 0.75], tau=[1.5, 0.6], sigma=0.4,
         seed=20260909),
    dict(name="randomSlope_unbalanced",
         note="Random slope with unequal group sizes and more groups.",
         m=20, sizes=[4, 9, 6, 11, 5, 7, 8, 3, 10, 6,
                      12, 5, 7, 4, 9, 8, 6, 11, 5, 7], r=2,
         beta_true=[0.5, -1.75], tau=[0.9, 0.35], sigma=1.1, seed=20260910),
    dict(name="randomIntercept_manyGroups",
         note="Forty small groups — the regime where REML and ML differ most, so an "
              "implementation quietly computing ML would show here.",
         m=40, sizes=[4] * 40, r=1, beta_true=[5.0, 3.0], tau=[3.0], sigma=1.0,
         seed=20260911),
]


def main() -> int:
    cases = [build_case(**spec) for spec in CASES]

    payload = {
        "name": "mixedModels",
        "reference": f"statsmodels {statsmodels.__version__} MixedLM, reml=True",
        "note": ("Generated once by Scripts/reference-fixtures/generate_mixed_models.py. "
                 "The data is recorded alongside the estimates because both sides must "
                 "fit the same problem. The REML log-likelihood is deliberately absent: "
                 "implementations differ by additive constants in it, so two correct fits "
                 "can disagree. Beta, G and the residual variance carry no such "
                 "convention."),
        "cases": cases,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(cases)} fitted models")
    for c in cases:
        s = c["statsmodels"]
        converged = "converged" if s["converged"] else "DID NOT CONVERGE"
        print(f"  {c['name']:<32} n={len(c['y']):>3} r={c['randomEffectsPerGroup']} "
              f"beta={np.round(s['beta'], 4)} sigma2={s['residualVariance']:.4f} "
              f"({converged})")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  statsmodels {statsmodels.__version__} · scipy {scipy.__version__} · "
          f"numpy {np.__version__} · pandas {pd.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
