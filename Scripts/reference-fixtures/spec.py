"""What to generate, and at which points.

One entry per fixture. Everything the Swift side asserts comes from here, so this
file is the reviewable record of *which* reference was consulted and *how* our
parameters were converted to it.

Two rules that the whole harness exists to enforce:

1. A parameter conversion is recorded as data in the emitted fixture, never only as
   code here. Writing the conversion in this file *and* in the Swift implementation
   risks converting wrongly in the same direction twice, which produces a green test
   and a wrong library.

2. Evaluation points always include both tails. A distribution fixture that samples
   only the body proves the easy half.
"""

import numpy as np
from scipy import special


# --------------------------------------------------------------------------
# Special functions — the shared layer under Gamma, Erlang, Chi-squared, Beta,
# F, Pearson V, Pearson VI and the Johnson family.
# --------------------------------------------------------------------------

def _gamma_p_cases():
    """P(a, x), the regularized lower incomplete gamma.

    Shapes span the two branches of the Numerical Recipes split (series for
    x < a+1, continued fraction otherwise) and both sides of a = 1.
    """
    shapes = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 50.0]
    cases = []
    for a in shapes:
        # Points either side of the a+1 branch cut, plus both tails.
        xs = [1e-8, 0.1 * a, 0.5 * a, a, a + 1.0, 2.0 * a, 5.0 * a, 20.0 * a]
        for x in xs:
            cases.append({"a": a, "x": float(x),
                          "value": float(special.gammainc(a, x))})
    return cases


def _gamma_p_inverse_cases():
    """The inverse of P(a, x) in x. Tails included deliberately: a root-finder
    that only works in the body is a root-finder that fails on a VaR tail."""
    shapes = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 50.0]
    ps = [1e-10, 1e-6, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999,
          1 - 1e-6, 1 - 1e-10]
    return [{"a": a, "p": p, "value": float(special.gammaincinv(a, p))}
            for a in shapes for p in ps]


def _beta_i_cases():
    """I_x(a, b), the regularized incomplete beta."""
    params = [(0.5, 0.5), (1.0, 1.0), (2.0, 3.0), (5.0, 2.0),
              (0.5, 5.0), (10.0, 10.0), (50.0, 2.0), (2.0, 50.0)]
    xs = [1e-8, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1 - 1e-8]
    return [{"a": a, "b": b, "x": x, "value": float(special.betainc(a, b, x))}
            for (a, b) in params for x in xs]


def _beta_i_inverse_cases():
    params = [(0.5, 0.5), (1.0, 1.0), (2.0, 3.0), (5.0, 2.0),
              (0.5, 5.0), (10.0, 10.0), (50.0, 2.0), (2.0, 50.0)]
    ps = [1e-10, 1e-6, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999,
          1 - 1e-6, 1 - 1e-10]
    return [{"a": a, "b": b, "p": p, "value": float(special.betaincinv(a, b, p))}
            for (a, b) in params for p in ps]


SPECIAL_FUNCTIONS = [
    {
        "name": "regularizedLowerIncompleteGamma",
        "reference": "scipy.special.gammainc(a, x)",
        "note": "P(a, x) = γ(a, x) / Γ(a). SciPy's `gammainc` is already regularized; "
                "its `gammainc` is our P, not the unnormalized γ.",
        "cases": _gamma_p_cases,
    },
    {
        "name": "inverseRegularizedLowerIncompleteGamma",
        "reference": "scipy.special.gammaincinv(a, p)",
        "note": "Solves P(a, x) = p for x.",
        "cases": _gamma_p_inverse_cases,
    },
    {
        "name": "regularizedIncompleteBeta",
        "reference": "scipy.special.betainc(a, b, x)",
        "note": "I_x(a, b). SciPy's `betainc` is regularized; the unnormalized form "
                "is `betainc(a,b,x) * beta(a,b)`.",
        "cases": _beta_i_cases,
    },
    {
        "name": "inverseRegularizedIncompleteBeta",
        "reference": "scipy.special.betaincinv(a, b, p)",
        "note": "Solves I_x(a, b) = p for x.",
        "cases": _beta_i_inverse_cases,
    },
]


# --------------------------------------------------------------------------
# Distributions — populated as the coverage work list is worked through.
# Each entry states Frontline's parameters, SciPy's, and the conversion between
# them as prose that lands in the fixture. See businessmath_work.tsv.
# --------------------------------------------------------------------------

def _t_cases():
    from scipy import stats
    dfs = [1, 2, 3, 5, 8, 12, 30, 100]
    ps = [1e-10, 1e-8, 1e-6, 1e-4, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99,
          0.999, 1 - 1e-4, 1 - 1e-6, 1 - 1e-8, 1 - 1e-10]
    cases = []
    for df in dfs:
        for prob in ps:
            x = float(stats.t.ppf(prob, df))
            cases.append({"df": float(df), "p": prob, "quantile": x,
                          "cdf": float(stats.t.cdf(x, df))})
    return cases


def _f_cases():
    from scipy import stats
    pairs = [(1, 1), (1, 10), (5, 9), (10, 10), (3, 20), (20, 3), (50, 2), (2, 50)]
    ps = [1e-10, 1e-8, 1e-6, 1e-4, 0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99,
          0.999, 1 - 1e-4, 1 - 1e-6, 1 - 1e-8, 1 - 1e-10]
    cases = []
    for d1, d2 in pairs:
        for prob in ps:
            x = float(stats.f.ppf(prob, d1, d2))
            cases.append({"df1": float(d1), "df2": float(d2), "p": prob,
                          "quantile": x, "cdf": float(stats.f.cdf(x, d1, d2))})
    return cases


DISTRIBUTIONS = [
    {
        "name": "studentT",
        "reference": "scipy.stats.t.ppf(p, df) and .cdf(x, df)",
        "note": "Inverted through the beta: nu/(nu+T^2) ~ Beta(nu/2, 1/2), so "
                "P(|T|>t) = I_{nu/(nu+t^2)}(nu/2, 1/2). Both tails included, because "
                "the previous bisection implementation was accurate only in the body.",
        "cases": _t_cases,
    },
    {
        "name": "fDistribution",
        "reference": "scipy.stats.f.ppf(p, df1, df2) and .cdf(x, df1, df2)",
        "note": "Inverted through the beta: d1*F/(d1*F+d2) ~ Beta(d1/2, d2/2). Above "
                "the median the mirrored form I^-1(1-p, d2/2, d1/2) is used, which "
                "yields 1-x directly instead of subtracting a value near one.",
        "cases": _f_cases,
    },
]


# --------------------------------------------------------------------------
# Quasi-random point sets.
#
# Two conventions are recorded in the fixture rather than left implicit, because
# both are exactly the kind of off-by-one that makes two implementations disagree
# while each looks correct on a plot:
#
#   * SciPy emits the origin as its first point. Sobol keeps it — the half-cell
#     offset already lifts it off zero, and dropping it would break the balance
#     property. Halton starts at index 1 instead, because its radical inverse has no
#     offset and index 0 really is the origin.
#   * Our coordinates carry a half-cell offset (2^-33 for Sobol) so that no
#     coordinate is ever exactly zero, which would inverse-transform to -infinity.
# --------------------------------------------------------------------------

def _sobol_cases():
    from scipy.stats import qmc
    cases = []
    for d in (1, 2, 4, 8, 16):
        engine = qmc.Sobol(d=d, scramble=False)
        points = engine.random(64)              # origin included; we keep it too
        for index, point in enumerate(points):
            for axis, value in enumerate(point):
                cases.append({"dimension": float(d), "index": float(index),
                              "axis": float(axis), "value": float(value)})
    return cases


def _halton_cases():
    from scipy.stats import qmc
    cases = []
    for d in (1, 2, 3, 5):
        engine = qmc.Halton(d=d, scramble=False)
        points = engine.random(33)[1:]          # drop the origin, as we do
        for index, point in enumerate(points):
            for axis, value in enumerate(point):
                cases.append({"dimension": float(d), "index": float(index),
                              "axis": float(axis), "value": float(value)})
    return cases


POINT_SETS = [
    {
        "name": "sobolPoints",
        "reference": "scipy.stats.qmc.Sobol(d, scramble=False).random(n)",
        "note": "Joe & Kuo new-joe-kuo-6.21201 direction numbers, the same table "
                "vendored in SobolDirectionNumbers.swift. Origin included. Our values "
                "carry a +2^-33 half-cell offset so no coordinate is ever zero.",
        "cases": _sobol_cases,
    },
    {
        "name": "haltonPoints",
        "reference": "scipy.stats.qmc.Halton(d, scramble=False).random(n+1)[1:]",
        "note": "Radical inverse in the first d primes. Origin dropped; our sequence "
                "starts at index 1, so no offset is needed.",
        "cases": _halton_cases,
    },
]
