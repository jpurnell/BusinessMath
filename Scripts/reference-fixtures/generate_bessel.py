#!/usr/bin/env python3
"""Reference values for the four Bessel functions, from mpmath at 40 digits.

Run once; commit the output. CI never executes this.

    python3 -m venv .venv && .venv/bin/pip install -r requirements-bessel.txt
    .venv/bin/python generate_bessel.py

## Why mpmath and not SciPy

Every other fixture here comes from SciPy, and this one deliberately does not.

SciPy's `jv`, `yv`, `iv` and `kv` are accurate to roughly 1e-12 relative at large
argument — not to their own arithmetic's precision. Measured against mpmath at 50
digits while this family was being written:

    J_200(3000)   scipy 1.781e-12 relative error
    J_50(1000)    scipy 3.481e-12
    J_200(2000)   scipy 3.636e-12

Our implementation is at 1e-16 on those same points. A fixture generated from SciPy
and asserted at 1e-12 would therefore fail a *correct* implementation, and the only
way to make it pass would be to loosen the tolerance until it no longer said
anything. This is the same trap the design proposal (section 3.3) identifies for
Excel, whose BESSELJ is out by about 3e-8 — it just bites an order of magnitude
later.

mpmath computes to arbitrary precision, so the values below are correctly rounded
doubles and the tolerance the tests assert is a statement about *us*.

## What the grid covers

Section 6.1 of the design proposal asks for x crossed with n straddling the n < x
boundary in both directions. The x values here also sit either side of every method
boundary in the implementation, because those are where a wrong branch would hide:

    x = 2        Temme series  ->  Steed continued fraction   (Y and K)
    x = 4        ascending series  ->  Miller recurrence      (J)
    x ~ 18.02    Miller/continued fraction  ->  Hankel asymptotic  (J and Y)

Non-finite and subnormal results are excluded. They are not a tolerance question --
an overflow is exact or it is wrong -- and they are asserted directly in
BesselFunctionsTests instead.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import mpmath as mp

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "besselFunctions.json")

mp.mp.dps = 40

FUNCTION_ORDER = ["besselJ", "besselY", "besselI", "besselK"]
KERNELS = [mp.besselj, mp.bessely, mp.besseli, mp.besselk]

# Either side of every method boundary, plus the span section 6.1 asks for.
XS = [1e-6, 0.001, 0.1, 0.5, 1.0, 1.5, 1.9, 2.0, 2.1, 3.0, 4.0, 4.1, 5.0, 8.0,
      10.0, 15.0, 17.9, 18.0, 18.1, 20.0, 25.0, 50.0, 100.0, 500.0, 700.0]
NS = [0, 1, 2, 5, 10, 25, 50]

MAX_DOUBLE = mp.mpf("1.7976931348623157e308")
MIN_NORMAL = mp.mpf("2.2250738585072014e-308")


def cases():
    out = []
    for index, kernel in enumerate(KERNELS):
        for x in XS:
            for n in NS:
                value = kernel(n, mp.mpf(x))
                if not mp.isfinite(value):
                    continue
                if abs(value) > MAX_DOUBLE or (value != 0 and abs(value) < MIN_NORMAL):
                    continue
                out.append({"function": float(index), "x": float(x),
                            "n": float(n), "value": float(value)})
    return out


def main() -> int:
    generated = cases()
    payload = {
        "name": "besselFunctions",
        "functionOrder": FUNCTION_ORDER,
        "reference": f"mpmath {mp.__version__} besselj/bessely/besseli/besselk at 40 dps",
        "note": ("mpmath rather than SciPy on purpose: SciPy's own error reaches 3.6e-12 "
                 "at large argument, so a SciPy fixture asserted at 1e-12 would fail a "
                 "correct implementation. The 'function' key indexes functionOrder. "
                 "Non-finite and subnormal results are excluded and asserted directly in "
                 "BesselFunctionsTests instead."),
        "cases": generated,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    per = {}
    for c in generated:
        per[FUNCTION_ORDER[int(c["function"])]] = per.get(
            FUNCTION_ORDER[int(c["function"])], 0) + 1
    print(f"{OUTPUT.name}: {len(generated)} cases")
    for name in FUNCTION_ORDER:
        print(f"  {name:<10} {per.get(name, 0):>4}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  mpmath {mp.__version__} · python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
