#!/usr/bin/env python3
"""Reference values for the moving averages, from pandas.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_moving_average.py

## Conventions, which are the whole risk here

The arithmetic is trivial; the ways to get a moving average subtly wrong are all about
alignment and initialisation, and each has an exact pandas counterpart:

- **Simple moving average.** `TimeSeries.movingAverage(window:)` is *trailing* and emits
  its first value at index `window - 1`, so the result is `window - 1` shorter than the
  input. That is `rolling(window).mean().dropna()`. A centred window, or one that padded
  the front, would produce a series of a different length and a different alignment — and
  would still look like a smoothed version of the input.

- **Exponential moving average.** The implementation seeds with the first observation and
  then applies `ema = alpha*x + (1-alpha)*ema`. That is `ewm(alpha=..., adjust=False)`.
  pandas defaults to `adjust=True`, which uses a bias-corrected weighted average instead
  and differs most in the early terms — exactly where a mismatched convention is easiest
  to overlook, because both series converge later.

Recording which pandas call each case corresponds to is the point: a fixture that agreed
with the code but not with a stated convention would be worth nothing.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "movingAverage.json")


def sma_case(name, note, values, window):
    s = pd.Series(values, dtype=float)
    rolled = s.rolling(window).mean().dropna()
    return {
        "name": name,
        "note": note,
        "kind": "sma",
        "pandas": f"Series.rolling({window}).mean().dropna()",
        "values": [float(v) for v in values],
        "window": window,
        "expected": [float(v) for v in rolled],
    }


def ema_case(name, note, values, alpha):
    s = pd.Series(values, dtype=float)
    smoothed = s.ewm(alpha=alpha, adjust=False).mean()
    return {
        "name": name,
        "note": note,
        "kind": "ema",
        "pandas": f"Series.ewm(alpha={alpha}, adjust=False).mean()",
        "values": [float(v) for v in values],
        "alpha": alpha,
        "expected": [float(v) for v in smoothed],
    }


rng = np.random.default_rng(20260906)

trend = [100.0 + 5 * i for i in range(24)]
seasonal = [100.0 + [10, -5, -10, 5][i % 4] for i in range(20)]
noisy = list(50 + rng.normal(0, 8, 40))
spiky = [10.0] * 8 + [1000.0] + [10.0] * 8          # one outlier
flat = [42.0] * 15
declining = [500.0 - 12 * i for i in range(18)]

CASES = [
    sma_case("sma_trend_w3", "A pure linear trend, window 3. A trailing mean of a linear "
                             "series lags it by exactly (window-1)/2, which is a property "
                             "a mis-aligned window would break.", trend, 3),
    sma_case("sma_trend_w12", "The same trend at window 12 — the length drops by 11.",
             trend, 12),
    sma_case("sma_seasonal_w4", "Window equal to the seasonal period, which should "
                                "flatten the season out entirely.", seasonal, 4),
    sma_case("sma_noisy_w5", "Noise, where nothing cancels and every term matters.",
             noisy, 5),
    sma_case("sma_spike_w3", "A single large outlier. It must enter and leave the window "
                             "cleanly across exactly three outputs.", spiky, 3),
    sma_case("sma_flat_w7", "A constant series: every output must equal the constant.",
             flat, 7),
    sma_case("sma_window1", "Window of one, which is the identity.", trend, 1),
    sma_case("sma_windowEqualsLength", "Window equal to the series length: exactly one "
                                       "output, the overall mean.", seasonal, 20),

    ema_case("ema_trend_a03", "Linear trend, alpha 0.3. An EMA of a trend converges to a "
                              "fixed lag behind it.", trend, 0.3),
    ema_case("ema_noisy_a01", "Heavy smoothing on noise — small alpha, long memory, so an "
                              "error in the recursion compounds visibly.", noisy, 0.1),
    ema_case("ema_noisy_a09", "Light smoothing: alpha 0.9 tracks the input closely.",
             noisy, 0.9),
    ema_case("ema_spike_a05", "The outlier again. Under adjust=False it decays "
                              "geometrically from the spike; under adjust=True the early "
                              "terms differ, which is the convention this pins down.",
             spiky, 0.5),
    ema_case("ema_flat_a05", "A constant series: seeded with the first value, the EMA "
                             "must stay exactly on it forever.", flat, 0.5),
    ema_case("ema_declining_a04", "A falling series. Nothing in the recursion prefers a "
                                  "rising one, but a sign error would only show here.",
             declining, 0.4),
    ema_case("ema_alpha1", "Alpha of one, which is the identity — every weight on the "
                           "newest observation.", trend, 1.0),
]


def main() -> int:
    payload = {
        "name": "movingAverage",
        "reference": f"pandas {pd.__version__}",
        "note": ("The arithmetic is trivial; alignment and initialisation are the risk. "
                 "Each case records the exact pandas call it corresponds to. The simple "
                 "moving average is trailing and drops the first window-1 points; the "
                 "exponential one is seeded with the first observation, which is "
                 "adjust=False and NOT pandas' default."),
        "cases": CASES,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(CASES)} cases")
    for c in CASES:
        print(f"  {c['name']:<26} {c['kind']}  in={len(c['values']):>3} "
              f"out={len(c['expected']):>3}  {c['pandas']}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  pandas {pd.__version__} · numpy {np.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
