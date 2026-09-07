#!/usr/bin/env python3
"""Reference values for the interpolators, from SciPy.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_interpolation.py

## What needs an oracle

The four interpolation test files hold 76 tests and check no value against
anything outside the package. What they do check is real but weak: that the
interpolant passes through its knots, that a query between two knots lands
between their values, that out-of-bounds policies fire. Every interpolation
scheme ever written satisfies all of that — passing through the knots is what
makes something an interpolator rather than a fit.

What separates the schemes is the shape *between* the knots, and that is set by
choices no self-consistency check can see:

- **Cubic spline boundary conditions.** Natural sets `f'' = 0` at the ends;
  not-a-knot makes the third derivative continuous at the second and
  second-to-last knots. They agree nowhere except at the knots themselves, and
  not-a-knot is the SciPy and MATLAB default while natural is the common
  textbook one. Getting the wrong one is invisible without a reference.
- **Akima, original against modified.** The 1970 original divides by a sum of
  slope differences that can vanish when three points are collinear; the modified
  form (`makima`) adds a term that removes the degeneracy. BusinessMath defaults
  to `modified: true`, SciPy defaults to the original — so both are generated
  here, and mixing them up would look like a small wiggle rather than an error.
- **PCHIP's slope rule.** The harmonic-mean formula is what makes it monotone and
  overshoot-free. Several plausible slope choices interpolate the knots equally
  well and none of the others preserve shape.
- **Barycentric weights.** A degree n−1 polynomial through n points is unique, so
  this one has a right answer everywhere, and it is the numerically delicate one.

## Sample points

Each case is evaluated on a dense grid that deliberately includes the knots
themselves, points immediately either side of a knot, and the midpoints of every
interval — the midpoint is where two schemes differ most, and the knot is where
they must agree.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import scipy
from scipy.interpolate import (Akima1DInterpolator, BarycentricInterpolator,
                               CubicSpline, PchipInterpolator)

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "interpolation.json")


def sample_points(xs):
    """Knots, their immediate neighbourhoods, and every interval midpoint."""
    xs = np.asarray(xs, float)
    points = list(xs)
    span = float(xs[-1] - xs[0])
    epsilon = span * 1e-6
    for x in xs[1:-1]:
        points.extend([x - epsilon, x + epsilon])
    for a, b in zip(xs[:-1], xs[1:]):
        points.extend([
            a + 0.25 * (b - a),
            a + 0.50 * (b - a),   # where schemes differ most
            a + 0.75 * (b - a),
        ])
    # Rounding can push a point a hair outside [xs[0], xs[-1]], and SciPy's Akima
    # returns NaN there while BusinessMath clamps — a difference of extrapolation
    # policy, not of interpolation, which is not what this fixture is measuring.
    # Round first, then clamp, then put the exact knots back.
    lo, hi = float(xs[0]), float(xs[-1])
    rounded = {min(max(round(float(p), 12), lo), hi) for p in points}
    rounded.update(float(x) for x in xs)
    return sorted(rounded)


def build_case(name, note, xs, ys):
    xs = np.asarray(xs, float)
    ys = np.asarray(ys, float)
    query = sample_points(xs)
    q = np.asarray(query, float)

    schemes = {}

    schemes["linear"] = {
        "note": "np.interp — the piecewise-linear interpolant.",
        "values": [float(v) for v in np.interp(q, xs, ys)],
    }

    if len(xs) >= 3:
        schemes["cubicSplineNatural"] = {
            "note": "CubicSpline(bc_type='natural'): f''=0 at both ends.",
            "values": [float(v) for v in CubicSpline(xs, ys, bc_type="natural")(q)],
        }
        schemes["cubicSplineNotAKnot"] = {
            "note": "CubicSpline(bc_type='not-a-knot'): the SciPy and MATLAB default.",
            "values": [float(v) for v in CubicSpline(xs, ys, bc_type="not-a-knot")(q)],
        }

    if len(xs) >= 2:
        schemes["cubicSplineClamped"] = {
            "note": "CubicSpline(bc_type=((1, 0.0), (1, 0.0))): zero slope at both ends.",
            "values": [float(v) for v in CubicSpline(xs, ys, bc_type=((1, 0.0), (1, 0.0)))(q)],
        }

    if len(xs) >= 3:
        schemes["akimaOriginal"] = {
            "note": "Akima1DInterpolator default — the 1970 original.",
            "values": [float(v) for v in Akima1DInterpolator(xs, ys)(q)],
        }
        schemes["akimaModified"] = {
            "note": "Akima1DInterpolator(method='makima') — BusinessMath's default.",
            "values": [float(v) for v in Akima1DInterpolator(xs, ys, method="makima")(q)],
        }
        schemes["pchip"] = {
            "note": "PchipInterpolator — monotone, overshoot-free.",
            "values": [float(v) for v in PchipInterpolator(xs, ys)(q)],
        }

    if len(xs) <= 12:
        # Barycentric is a single global polynomial; beyond a dozen points it is
        # Runge's phenomenon rather than a useful interpolant, and the values stop
        # being reproducible across implementations at double precision.
        schemes["barycentric"] = {
            "note": "BarycentricInterpolator — the unique degree n-1 polynomial.",
            "values": [float(v) for v in BarycentricInterpolator(xs, ys)(q)],
        }

    return {
        "name": name,
        "note": note,
        "xs": [float(v) for v in xs],
        "ys": [float(v) for v in ys],
        "query": query,
        "schemes": schemes,
    }


def cases():
    out = []

    out.append(build_case(
        "smoothSine",
        "Eight points on a sine. Every scheme is well behaved, so differences "
        "between them are the schemes' own and not a reaction to bad data.",
        np.linspace(0, 2 * np.pi, 8), np.sin(np.linspace(0, 2 * np.pi, 8))))

    out.append(build_case(
        "monotoneStep",
        "Monotone data with a sharp rise. A cubic spline overshoots here and "
        "PCHIP must not — the clearest separation between an interpolant that "
        "preserves shape and one that only passes through the points.",
        [0, 1, 2, 3, 4, 5], [0, 0, 0, 10, 10, 10]))

    out.append(build_case(
        "collinearRun",
        "Three collinear points in the middle. This is the configuration that "
        "makes the original Akima formula divide by zero and the modified one "
        "not, so the two methods are furthest apart here.",
        [0, 1, 2, 3, 4, 5, 6], [0, 2, 4, 6, 6.5, 5, 3]))

    out.append(build_case(
        "unevenSpacing",
        "Knots bunched at one end. Several slope formulas are written assuming "
        "an even grid and are correct only there.",
        [0, 0.1, 0.15, 0.2, 1.0, 3.0, 8.0], [1, 3, 2.5, 4, 4.2, 1, 0.5]))

    out.append(build_case(
        "cubicPolynomial",
        "Samples of 2x³ − 5x² + 3x − 1. A not-a-knot cubic spline reproduces a "
        "cubic exactly, and so does barycentric with enough points; natural does "
        "not, because f''=0 at the ends is false for this function. That "
        "disagreement is the boundary condition made visible.",
        [-2, -1, 0, 1, 2, 3], [2 * x ** 3 - 5 * x ** 2 + 3 * x - 1 for x in [-2, -1, 0, 1, 2, 3]]))

    out.append(build_case(
        "linearData",
        "Points on a straight line. Every scheme here reproduces a line exactly, "
        "so any deviation is a defect rather than a difference of method — the "
        "one case where all of them must agree between the knots as well as on "
        "them.",
        [0, 1, 2, 3, 4], [3.0, 5.0, 7.0, 9.0, 11.0]))

    out.append(build_case(
        "twoPointsOnly",
        "The minimum for a linear interpolant, and the boundary at which the "
        "cubic schemes must either decline or degrade gracefully.",
        [0, 1], [4.0, 9.0]))

    return out


def main() -> int:
    built = cases()
    payload = {
        "name": "interpolation",
        "reference": f"scipy {scipy.__version__} interpolate (numpy {np.__version__})",
        "note": ("Passing through the knots is what makes something an "
                 "interpolator, so the existing tests' checks hold for every "
                 "scheme ever written. What is pinned here is the shape between "
                 "the knots, which is where a boundary condition, an Akima "
                 "variant or a slope rule actually shows."),
        "cases": built,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # allow_nan=False so a NaN raises here rather than being written as the
    # non-standard `NaN` token, which Python reads back happily and every strict
    # JSON parser rejects.
    text = json.dumps(payload, indent=2, sort_keys=True, allow_nan=False) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(built)} datasets")
    total = 0
    for c in built:
        counts = sum(len(s["values"]) for s in c["schemes"].values())
        total += counts
        print(f"  {c['name']:<20} n={len(c['xs']):>2} query={len(c['query']):>3} "
              f"schemes={len(c['schemes'])} values={counts}")
    print(f"  {total} reference values")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  python {platform.python_version()} · {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
