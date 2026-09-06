#!/usr/bin/env python3
"""Reference cases for the Holt-Winters forecaster.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_holt_winters.py

## Why not statsmodels

`statsmodels.tsa.holtwinters.ExponentialSmoothing` was tried first and rejected as the
oracle. Given the same data, the same smoothing parameters and the same initial level,
trend and seasonals, it and this package's recursion disagree by about 0.5%. Both are
self-consistent implementations of additive Holt-Winters; they differ in how the supplied
initial state lines up with the first observation, and there is no single right answer to
that — the literature carries several conventions.

Asserting against it would therefore report a convention as a defect. That is the failure
mode the distribution fixtures were built to avoid, and it would be worse here because
the disagreement is small enough to look like a tolerance problem.

## What is used instead: exact recovery

A stronger oracle is available, and it needs no second implementation at all.

Construct a series that additive Holt-Winters **must** reproduce exactly — a constant
level, a linear trend and a fixed seasonal pattern, with no noise — and the mathematics
fixes the answer. Every residual must be zero and every forecast must equal the true
continuation of the generating formula, to floating-point precision. No convention enters,
because the model has nothing to estimate that is not exactly present in the data.

This is the same principle as §2.2 of the coverage proposal, where the closed-form
distributions are checked against their own formulas rather than against SciPy: when the
mathematics determines the answer, the mathematics is the better reference.

It is also not a weak test. It found both defects in the implementation as it stood:

  - the fitted value used for residuals multiplied by the seasonal in an otherwise
    additive model, so a noiseless series that the model fits perfectly still produced
    residuals in the hundreds — and those residuals feed the confidence intervals;
  - the forecast indexed the seasonal array from zero regardless of where the training
    data stopped, so any series whose length was not a whole number of cycles came back
    phase-shifted, with nothing to indicate it.

## Exact recovery holds under two conditions, both measured

The initialisation lands exactly on the representation the recursion converges to only
when **the series has no trend and its length is a whole number of cycles**. Both were
found by measurement, after asserting exactness too broadly and watching which cases
failed.

*No trend*, because `seasonal[i]` initialises to
`pattern[i] - mean(pattern) + slope*(i - (m-1)/2)`, and that trend-dependent term is not
of the form the exact representation needs.

*A whole number of cycles*, because otherwise the phases hold unequal counts. At n = 17
with m = 4, phase 0 has five observations and the rest four, so the overall mean is pulled
off `base` and every seasonal inherits the offset. The first residual comes out at exactly
0.588 for the series below — not noise, arithmetic.

Away from those conditions the recursion still converges, geometrically. The largest
forecast error on a quarterly trended series falls 1.68 -> 0.33 -> 0.025 -> 6.7e-05 -> 0.0
as the series grows 24 -> 48 -> 96 -> 200 -> 400.

So every case here is either on a boundary and untrended, or long enough to have
converged. Asserting exactness where it does not hold would have meant asserting something
untrue of correct code — which is how a suite acquires tolerances that get quietly
loosened later, until they assert nothing.

## What the fixture carries

The generating parameters, the series, and the true continuation computed from the
generating formula — never from a Holt-Winters implementation. The Swift side asserts
equality with that continuation.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "holtWinters.json")


def exact_case(name, note, base, slope, pattern, n, horizon, alpha, beta, gamma):
    """A noiseless series the model must reproduce exactly, plus its true continuation."""
    m = len(pattern)
    t = np.arange(n)
    y = base + slope * t + np.asarray(pattern, float)[t % m]

    # The continuation, straight from the generating formula. Not from any forecaster.
    future = np.arange(n, n + horizon)
    truth = base + slope * future + np.asarray(pattern, float)[future % m]

    return {
        "name": name,
        "note": note,
        "kind": "exact",
        "alpha": alpha, "beta": beta, "gamma": gamma,
        "seasonalPeriods": m,
        "base": base, "slope": slope,
        "pattern": [float(v) for v in pattern],
        "values": [float(v) for v in y],
        "horizon": horizon,
        "expectedForecast": [float(v) for v in truth],
    }


CASES = [
    # The one case where the initialisation is exact from the first observation: no
    # trend, and a whole number of cycles.
    exact_case("levelOnly_endsOnBoundary",
               "No trend, sixteen points, four per cycle. The initialisation is exactly "
               "the fixed point here, so residuals are zero from the very first "
               "observation — nothing to converge.",
               base=100.0, slope=0.0, pattern=[10, -5, -10, 5],
               n=16, horizon=8, alpha=0.5, beta=0.0, gamma=0.5),

    # Every residue of n mod m, long enough to have converged. These are what catch a
    # forecast that indexes the seasonal array from a fixed origin.
    exact_case("levelOnly_offBoundary_1",
               "One point past a cycle boundary. The forecast must start one phase "
               "further round; the old indexing returned the boundary answer.",
               base=100.0, slope=0.0, pattern=[10, -5, -10, 5],
               n=401, horizon=8, alpha=0.5, beta=0.0, gamma=0.5),

    exact_case("levelOnly_offBoundary_2",
               "Two points past.",
               base=100.0, slope=0.0, pattern=[10, -5, -10, 5],
               n=402, horizon=8, alpha=0.5, beta=0.0, gamma=0.5),

    exact_case("levelOnly_offBoundary_3",
               "Three points past — with the boundary case above, every residue mod the "
               "cycle length is covered.",
               base=100.0, slope=0.0, pattern=[10, -5, -10, 5],
               n=403, horizon=8, alpha=0.5, beta=0.0, gamma=0.5),

    exact_case("withTrend_quarterly",
               "A linear trend as well as a season. The trend must be carried into the "
               "forecast at the right rate; a model that dropped it would still look "
               "seasonal.",
               base=50.0, slope=2.0, pattern=[6, -2, -8, 4],
               n=400, horizon=8, alpha=0.6, beta=0.3, gamma=0.4),

    exact_case("withTrend_offBoundary",
               "Trend and season, ending mid-cycle: both defects at once.",
               base=50.0, slope=2.0, pattern=[6, -2, -8, 4],
               n=402, horizon=8, alpha=0.6, beta=0.3, gamma=0.4),

    exact_case("monthly_converged",
               "Twelve periods per cycle with slower smoothing (alpha 0.3, gamma 0.2), so "
               "it needs far more data to settle: the largest relative forecast error "
               "runs 1.4e-05 at n=600, 2.9e-08 at 1200, 5.1e-14 at 2400 and exactly zero "
               "at 4800. Generated at 2400, comfortably inside the assertion.",
               base=200.0, slope=1.5,
               pattern=[20, 14, 5, -3, -12, -18, -20, -11, -2, 6, 12, 9],
               n=2400, horizon=12, alpha=0.3, beta=0.1, gamma=0.2),

    exact_case("negativeTrend",
               "A declining series. Nothing in the algebra prefers a positive slope, and "
               "a sign error would only show here.",
               base=500.0, slope=-3.0, pattern=[15, -5, -15, 5],
               n=400, horizon=8, alpha=0.5, beta=0.25, gamma=0.5),
]

def main() -> int:
    payload = {
        "name": "holtWinters",
        "reference": ("exact recovery — the generating formula, not another "
                      "implementation. See the module docstring for why statsmodels was "
                      "tried and rejected as the oracle."),
        "note": ("Each series is a constant level plus a linear trend plus a fixed "
                 "seasonal pattern, with no noise, so additive Holt-Winters must "
                 "reproduce it exactly: residuals zero, forecasts equal to the "
                 "continuation of the generating formula. `expectedForecast` is computed "
                 "from that formula and never from a forecaster."),
        "cases": CASES,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(CASES)} series")
    for c in CASES:
        n, m = len(c["values"]), c["seasonalPeriods"]
        print(f"  {c['name']:<28} n={n:>3} m={m:>2} n%m={n % m}  "
              f"slope={c['slope']:+.1f}  horizon={c['horizon']}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  numpy {np.__version__} · python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
