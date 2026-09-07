#!/usr/bin/env python3
"""Reference values for value at risk and expected shortfall.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_risk_metrics.py

## What needs an oracle

`RiskMetricsTests` (27) and `RiskAggregationTests` (17) check no value against
anything outside the package. VaR and CVaR are single numbers that get reported
to a risk committee and turned into a capital requirement, and the ways to get
them slightly wrong all produce a plausible number:

- **Which quantile estimator.** There are nine conventional definitions of a
  sample quantile. BusinessMath documents type 7 (linear interpolation between
  order statistics), which is numpy's and R's default; type 1 or type 6 shift the
  answer by a fraction of the gap between two order statistics, which at the 1%
  level on a fat tail is a large amount of money.
- **Which tail.** CVaR is the mean of the tail *beyond* VaR. Including the VaR
  observation itself, or taking `⌈nα⌉` observations instead of `⌊nα⌋`, changes
  the answer at every sample size and is invisible without a reference.
- **The sign.** These are signed returns, so a loss is negative and VaR is the
  low quantile. An implementation that returns `|VaR|` looks identical on a
  loss-only distribution and inverts the ranking on a mixed one.

## Two estimators, deliberately both recorded

BusinessMath exposes two CVaR entry points that do **not** compute the same
thing, and this fixture records both definitions so each can be checked against
its own:

- `SimulationResults.conditionalValueAtRisk` takes the type-7 quantile as the
  threshold and averages every observation at or below it.
- `ConditionalValueAtRisk.calculate` averages the worst `max(1, ⌊nα⌋)`
  observations, never forming a quantile at all.

They agree only when `nα` is an integer and no observation sits exactly on the
threshold. Recording both is the honest thing; deciding whether the library
should offer two is a separate question.

## The analytic anchor

For a normal distribution the answers are closed forms:

    VaR_c  = μ + σ·Φ⁻¹(α)
    CVaR_c = μ − σ·φ(Φ⁻¹(α)) / α        (α = 1 − c)

Those hold exactly, so a large stratified sample — the inverse CDF evaluated on
an even probability grid, which carries no Monte Carlo noise at all — must
reproduce them closely. That is the check that catches an estimator which is
self-consistent but centred on the wrong place.
"""

import hashlib
import json
import math
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import scipy
from scipy import stats

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "riskMetrics.json")

LEVELS = [0.90, 0.95, 0.99]


def measures(values, confidence):
    """Both CVaR definitions plus the VaR they are built on."""
    v = np.sort(np.asarray(values, float))
    n = len(v)
    alpha = 1.0 - confidence

    # Type 7: numpy's default, and what BusinessMath's `quantile(sorted:p:)` documents.
    var_type7 = float(np.percentile(v, alpha * 100.0, method="linear"))

    tail = v[v <= var_type7]
    cvar_threshold = float(tail.mean()) if len(tail) else var_type7

    count = max(1, int(n * alpha))
    cvar_count = float(v[:count].mean())

    return {
        "confidence": confidence,
        "valueAtRisk": var_type7,
        "cvarBelowThreshold": cvar_threshold,
        "tailSize": int(len(tail)),
        "cvarWorstCount": cvar_count,
        "worstCount": int(count),
    }


def build_case(name, note, values, analytic=None, construction=None):
    values = [float(v) for v in values]
    entry = {
        "name": name,
        "note": note,
        "n": len(values),
        "levels": [measures(values, c) for c in LEVELS],
    }
    if construction is None:
        entry["values"] = values
    else:
        # A 200,000-point sample is 5 MB of JSON and entirely redundant: it is a
        # closed-form construction, so the recipe is the data. Swift rebuilds it
        # from these parameters, which also puts the package's own normal quantile
        # in the path — deliberately, since a wrong one would move these numbers.
        entry["construction"] = construction
    if analytic is not None:
        entry["analytic"] = analytic
    return entry


def normal_analytic(mu, sigma):
    out = []
    for c in LEVELS:
        alpha = 1.0 - c
        z = float(stats.norm.ppf(alpha))
        out.append({
            "confidence": c,
            "valueAtRisk": float(mu + sigma * z),
            # Lower-tail conditional mean: μ − σ·φ(z)/α.
            "conditionalValueAtRisk": float(mu - sigma * stats.norm.pdf(z) / alpha),
        })
    return out


def stratified_normal(mu, sigma, n):
    """The normal inverse CDF on an even probability grid.

    Carries no sampling noise, so a comparison against the closed form measures
    the estimator rather than the luck of a draw.
    """
    probabilities = (np.arange(n) + 0.5) / n
    return mu + sigma * stats.norm.ppf(probabilities)


def cases():
    out = []

    # A hand-checkable sample: twenty values, so the 5% quantile lands between the
    # first and second order statistics and the interpolation convention shows.
    small = [-42.0, -31.5, -28.0, -19.0, -12.5, -8.0, -5.5, -2.0, 0.5, 3.0,
             6.5, 9.0, 12.0, 15.5, 18.0, 22.5, 27.0, 33.0, 41.0, 55.0]
    out.append(build_case(
        "twentySignedReturns",
        "Twenty signed returns. At 95% the type-7 quantile falls between the "
        "first and second order statistics, so the interpolation convention is "
        "load-bearing; at 99% it is below the first, where the estimators clamp.",
        small))

    out.append(build_case(
        "allLosses",
        "Every observation negative. A sign error is invisible here, which is why "
        "it sits beside the mixed cases rather than alone.",
        [-x for x in [5.0, 12.0, 18.0, 23.0, 31.0, 44.0, 52.0, 67.0, 88.0, 120.0]]))

    out.append(build_case(
        "allGains",
        "Every observation positive. VaR is still the low quantile and is "
        "therefore positive — an implementation returning a magnitude cannot "
        "distinguish this case from the last.",
        [5.0, 12.0, 18.0, 23.0, 31.0, 44.0, 52.0, 67.0, 88.0, 120.0]))

    out.append(build_case(
        "constantSeries",
        "No dispersion at all. VaR and both CVaRs must equal the constant, and "
        "nothing may divide by a zero spread.",
        [7.5] * 25))

    out.append(build_case(
        "heavyLeftTail",
        "A few very large losses among ordinary returns. This is where the two "
        "CVaR definitions diverge most, because whether one extra observation "
        "falls inside the tail moves the mean a long way.",
        [-500.0, -300.0, -180.0] + list(np.linspace(-20, 40, 97))))

    mu, sigma = 0.08, 0.20
    out.append(build_case(
        "stratifiedNormalLarge",
        "The normal inverse CDF on an even grid of 200,000 probabilities: the "
        "empirical distribution of a normal with no sampling noise. Its VaR and "
        "CVaR must reproduce the closed forms, which is the check that catches an "
        "estimator centred on the wrong place rather than merely inconsistent.",
        stratified_normal(mu, sigma, 200_000),
        analytic=normal_analytic(mu, sigma),
        construction={"kind": "stratifiedNormal", "mean": mu, "standardDeviation": sigma,
                      "count": 200_000}))

    mu2, sigma2 = -0.02, 0.35
    out.append(build_case(
        "stratifiedNormalNegativeDrift",
        "The same construction with a negative mean and a wider spread, so the "
        "closed form is checked at more than one location and scale.",
        stratified_normal(mu2, sigma2, 200_000),
        analytic=normal_analytic(mu2, sigma2),
        construction={"kind": "stratifiedNormal", "mean": mu2, "standardDeviation": sigma2,
                      "count": 200_000}))

    return out


def main() -> int:
    built = cases()
    payload = {
        "name": "riskMetrics",
        "reference": f"numpy {np.__version__} percentile(method='linear'), scipy {scipy.__version__} norm",
        "note": ("VaR is the signed low quantile, not a magnitude. Two CVaR "
                 "definitions are recorded because BusinessMath exposes two entry "
                 "points that compute different things: one averages below the "
                 "type-7 quantile, the other averages the worst floor(n·alpha) "
                 "observations."),
        "levels": LEVELS,
        "cases": built,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(built)} datasets")
    for c in built:
        marker = "  [analytic]" if "analytic" in c else ""
        levels = " ".join(f"{m['confidence']:.0%}:VaR={m['valueAtRisk']:.4g}" for m in c["levels"])
        print(f"  {c['name']:<30} n={c['n']:>6}  {levels}{marker}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  python {platform.python_version()} · {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
