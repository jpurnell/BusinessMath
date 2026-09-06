#!/usr/bin/env python3
"""Reference values for the Risk Solver distributions that name a SciPy analogue.

Run once; commit the output. CI never executes this — the Swift suite reads the
committed JSON, because a test that needs a working SciPy to run is a test that goes
red for reasons unrelated to the library.

    python3 generate_risk_solver.py

Why this exists rather than round-trip tests alone: a `cdf`/`quantile` pair that is
self-consistent but wrongly *parameterised* round-trips perfectly. Only a second,
independent implementation catches an argument bound to the wrong slot, and
PROPOSAL_excel_function_coverage.md §2.1 says that is where the errors are. So each
entry below records the exact SciPy construction alongside the values, and the mapping
from Frontline's argument names is written out in `FRONTLINE_MAPPING`.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy
import scipy
from scipy import stats

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "riskSolverDistributions.json")

# Probabilities to evaluate the quantile at. The tails matter more than the middle —
# a parameterisation error often looks fine at the median and diverges in the tails.
PROBABILITIES = [1e-8, 1e-6, 1e-4, 0.001, 0.01, 0.05, 0.1, 0.25,
                 0.5, 0.75, 0.9, 0.95, 0.99, 0.999, 1 - 1e-4, 1 - 1e-6]

# How Frontline's arguments map onto SciPy's. Where the two disagree, the work list's
# NOTE column is the authority and the reason is recorded here.
FRONTLINE_MAPPING = {
    "cauchy": "PsiCauchy(loc, lambda) -> cauchy(loc=loc, scale=lambda). Frontline's prose "
              "contradicts its signature about which argument is which; the signature wins.",
    "laplace": "PsiLaplace(loc, beta) -> laplace(loc=loc, scale=beta). Same prose/signature "
               "contradiction as PsiCauchy, in reverse.",
    "levy": "PsiLevy(loc, scale) -> levy(loc, scale). Stable with alpha=1/2, beta=1; the "
            "mean does not exist, so no moment check is possible.",
    "gumbel_r": "PsiMaxExtreme(m, s) -> gumbel_r(loc=m, scale=s).",
    "gumbel_l": "PsiMinExtreme(m, s) -> gumbel_l(loc=m, scale=s). A distinct distribution, "
                "NOT gumbel_r negated — negating would move the location too.",
    "invweibull": "PsiFrechet(loc, scale, shape) -> invweibull(c=shape, loc=loc, scale=scale). "
                  "Extreme value type II; SciPy names it invweibull, not frechet.",
    "fisk": "PsiLogLogistic(gamma, beta, alpha) -> fisk(c=alpha, loc=gamma, scale=beta). "
            "Frontline orders the arguments location, scale, shape — SciPy does not.",
    "loguniform": "PsiReciprocal(min, max) -> loguniform(min, max). SciPy renamed "
                  "`reciprocal` to `loguniform`; the old name is the one Frontline uses.",
    "burr12": "PsiBurr12(loc, scale, shape1, shape2) -> burr12(c=shape1, d=shape2, loc, scale). "
              "Burr type XII: F = 1-(1+x^c)^-d, verified against scipy directly.",
    "burr": "PsiDagum(loc, scale, shape1, shape2) -> burr(c=shape1, d=shape2, loc, scale). "
            "Dagum IS Burr type III, and scipy's `burr` is type III while `burr12` is type XII — "
            "the work list says to confirm which shape maps to which before binding, and it was: "
            "F = (1+x^-c)^-d. Same argument slots as burr12, different distribution.",
    "johnsonsb": "PsiJohnsonSB(shape1, shape2, min, max) -> johnsonsb(a=shape1, b=shape2, "
                 "loc=min, scale=max-min). Bounded on [min, max], so scipy's scale is the WIDTH, "
                 "not the upper bound.",
    "johnsonsu": "PsiJohnsonSU(shape1, shape2, loc, scale) -> johnsonsu(a=shape1, b=shape2, "
                 "loc, scale). Unbounded, so loc/scale are the usual pair.",
    "fatiguelife": "PsiFatigueLife(loc, scale, shape) -> fatiguelife(c=shape, loc, scale). "
                   "Birnbaum-Saunders.",
    "erlang": "PsiErlang(k, beta) -> erlang(a=k, scale=beta). Gamma with an integer shape; "
              "cdf is the regularized lower incomplete gamma P(k, x/beta).",
    "invgamma": "PsiPearson5(alpha, beta) -> invgamma(a=alpha, scale=beta). cdf is the UPPER "
                "regularized incomplete gamma Q(alpha, beta/x) — note the reciprocal argument "
                "and the upper tail, both easy to get backwards.",
    "betaprime": "PsiPearson6(alpha1, alpha2, beta) -> betaprime(a=alpha1, b=alpha2, scale=beta). "
                 "cdf is I_{y/(1+y)}(alpha1, alpha2) with y = x/beta.",
    "invgauss": "PsiInvNormal(mu, lambda) -> invgauss(mu/lambda, scale=lambda). **scipy's first "
                "argument is the RATIO mu/lambda, not mu.** Passing mu straight through gives a "
                "different distribution. No closed-form quantile exists; ours bisects its own cdf.",
    "nbinom": "PsiNegBinomial(s, p) -> nbinom(n=s, p=p). Counts FAILURES before the s-th success, "
              "so the support starts at 0.",
    "logser": "PsiLogarithmic(p) -> logser(p). Support starts at 1, not 0.",
}

CASES = [
    ("cauchy",     "PsiCauchy",       lambda: stats.cauchy(loc=2.0, scale=3.0),
     {"loc": 2.0, "lambda": 3.0}),
    ("cauchy",     "PsiCauchy",       lambda: stats.cauchy(loc=-1.5, scale=0.5),
     {"loc": -1.5, "lambda": 0.5}),
    ("laplace",    "PsiLaplace",      lambda: stats.laplace(loc=0.0, scale=1.0),
     {"loc": 0.0, "beta": 1.0}),
    ("laplace",    "PsiLaplace",      lambda: stats.laplace(loc=5.0, scale=2.5),
     {"loc": 5.0, "beta": 2.5}),
    ("levy",       "PsiLevy",         lambda: stats.levy(loc=0.0, scale=1.0),
     {"loc": 0.0, "scale": 1.0}),
    ("levy",       "PsiLevy",         lambda: stats.levy(loc=1.0, scale=2.0),
     {"loc": 1.0, "scale": 2.0}),
    ("gumbel_r",   "PsiMaxExtreme",   lambda: stats.gumbel_r(loc=0.0, scale=1.0),
     {"m": 0.0, "s": 1.0}),
    ("gumbel_r",   "PsiMaxExtreme",   lambda: stats.gumbel_r(loc=10.0, scale=3.0),
     {"m": 10.0, "s": 3.0}),
    ("gumbel_l",   "PsiMinExtreme",   lambda: stats.gumbel_l(loc=0.0, scale=1.0),
     {"m": 0.0, "s": 1.0}),
    ("gumbel_l",   "PsiMinExtreme",   lambda: stats.gumbel_l(loc=10.0, scale=3.0),
     {"m": 10.0, "s": 3.0}),
    ("invweibull", "PsiFrechet",      lambda: stats.invweibull(c=2.0, loc=0.0, scale=1.0),
     {"loc": 0.0, "scale": 1.0, "shape": 2.0}),
    ("invweibull", "PsiFrechet",      lambda: stats.invweibull(c=3.5, loc=1.0, scale=2.0),
     {"loc": 1.0, "scale": 2.0, "shape": 3.5}),
    ("fisk",       "PsiLogLogistic",  lambda: stats.fisk(c=3.0, loc=0.0, scale=1.0),
     {"gamma": 0.0, "beta": 1.0, "alpha": 3.0}),
    ("fisk",       "PsiLogLogistic",  lambda: stats.fisk(c=1.5, loc=2.0, scale=4.0),
     {"gamma": 2.0, "beta": 4.0, "alpha": 1.5}),
    ("loguniform", "PsiReciprocal",   lambda: stats.loguniform(1.0, 100.0),
     {"min": 1.0, "max": 100.0}),
    ("loguniform", "PsiReciprocal",   lambda: stats.loguniform(0.5, 4.0),
     {"min": 0.5, "max": 4.0}),

    ("burr12",     "PsiBurr12",       lambda: stats.burr12(c=2.0, d=3.0, loc=0.0, scale=1.0),
     {"loc": 0.0, "scale": 1.0, "shape1": 2.0, "shape2": 3.0}),
    ("burr12",     "PsiBurr12",       lambda: stats.burr12(c=1.5, d=0.8, loc=2.0, scale=3.0),
     {"loc": 2.0, "scale": 3.0, "shape1": 1.5, "shape2": 0.8}),
    ("burr",       "PsiDagum",        lambda: stats.burr(c=2.0, d=3.0, loc=0.0, scale=1.0),
     {"loc": 0.0, "scale": 1.0, "shape1": 2.0, "shape2": 3.0}),
    ("burr",       "PsiDagum",        lambda: stats.burr(c=1.5, d=0.8, loc=2.0, scale=3.0),
     {"loc": 2.0, "scale": 3.0, "shape1": 1.5, "shape2": 0.8}),
    ("johnsonsb",  "PsiJohnsonSB",    lambda: stats.johnsonsb(1.0, 2.0, loc=0.0, scale=1.0),
     {"shape1": 1.0, "shape2": 2.0, "min": 0.0, "max": 1.0}),
    ("johnsonsb",  "PsiJohnsonSB",    lambda: stats.johnsonsb(-0.5, 1.5, loc=10.0, scale=20.0),
     {"shape1": -0.5, "shape2": 1.5, "min": 10.0, "max": 30.0}),
    ("johnsonsu",  "PsiJohnsonSU",    lambda: stats.johnsonsu(1.0, 2.0, loc=0.0, scale=1.0),
     {"shape1": 1.0, "shape2": 2.0, "loc": 0.0, "scale": 1.0}),
    ("johnsonsu",  "PsiJohnsonSU",    lambda: stats.johnsonsu(-0.5, 1.5, loc=5.0, scale=2.0),
     {"shape1": -0.5, "shape2": 1.5, "loc": 5.0, "scale": 2.0}),
    ("fatiguelife", "PsiFatigueLife", lambda: stats.fatiguelife(c=0.5, loc=0.0, scale=1.0),
     {"loc": 0.0, "scale": 1.0, "shape": 0.5}),
    ("fatiguelife", "PsiFatigueLife", lambda: stats.fatiguelife(c=1.2, loc=1.0, scale=3.0),
     {"loc": 1.0, "scale": 3.0, "shape": 1.2}),

    ("erlang",     "PsiErlang",       lambda: stats.erlang(a=3, scale=2.0),
     {"k": 3.0, "beta": 2.0}),
    ("erlang",     "PsiErlang",       lambda: stats.erlang(a=7, scale=0.5),
     {"k": 7.0, "beta": 0.5}),
    ("invgamma",   "PsiPearson5",     lambda: stats.invgamma(a=2.5, scale=3.0),
     {"alpha": 2.5, "beta": 3.0}),
    ("invgamma",   "PsiPearson5",     lambda: stats.invgamma(a=5.0, scale=1.5),
     {"alpha": 5.0, "beta": 1.5}),
    ("betaprime",  "PsiPearson6",     lambda: stats.betaprime(a=2.0, b=3.0, scale=1.5),
     {"alpha1": 2.0, "alpha2": 3.0, "beta": 1.5}),
    ("betaprime",  "PsiPearson6",     lambda: stats.betaprime(a=4.0, b=6.0, scale=2.5),
     {"alpha1": 4.0, "alpha2": 6.0, "beta": 2.5}),
    ("invgauss",   "PsiInvNormal",    lambda: stats.invgauss(2.0 / 5.0, scale=5.0),
     {"mu": 2.0, "lambda": 5.0}),
    ("invgauss",   "PsiInvNormal",    lambda: stats.invgauss(3.0 / 1.5, scale=1.5),
     {"mu": 3.0, "lambda": 1.5}),
    ("nbinom",     "PsiNegBinomial",  lambda: stats.nbinom(n=5, p=0.4),
     {"s": 5.0, "p": 0.4}),
    ("nbinom",     "PsiNegBinomial",  lambda: stats.nbinom(n=2, p=0.75),
     {"s": 2.0, "p": 0.75}),
    ("logser",     "PsiLogarithmic",  lambda: stats.logser(0.6),
     {"p": 0.6}),
    ("logser",     "PsiLogarithmic",  lambda: stats.logser(0.95),
     {"p": 0.95}),
]

# Which entries are discrete. Their quantile is integer-valued, so the Swift side
# compares them exactly rather than to a relative tolerance.
DISCRETE = {"PsiNegBinomial", "PsiLogarithmic"}


def build() -> dict:
    entries = []
    for scipy_name, psi_name, factory, params in CASES:
        dist = factory()
        quantiles = []
        for p in PROBABILITIES:
            x = float(dist.ppf(p))
            if not numpy.isfinite(x):
                continue
            quantiles.append({
                "p": p,
                "x": x,
                # The CDF re-evaluated at the quantile. Storing both directions lets the
                # Swift test check each function against SciPy rather than only against
                # its own inverse.
                "cdfAtX": float(dist.cdf(x)),
            })

        # A few CDF probes at fixed abscissae, chosen relative to the distribution's own
        # median so they land somewhere meaningful for every parameterisation.
        median = float(dist.median())
        spread = float(dist.ppf(0.75) - dist.ppf(0.25))
        probes = [median + k * spread for k in (-3, -1, -0.5, 0, 0.5, 1, 3)]
        cdfs = [{"x": float(x), "cdf": float(dist.cdf(x))}
                for x in probes if numpy.isfinite(x)]

        entries.append({
            "psi": psi_name,
            "scipy": scipy_name,
            "discrete": psi_name in DISCRETE,
            "parameters": params,
            "mapping": FRONTLINE_MAPPING[scipy_name],
            "quantiles": quantiles,
            "cdfProbes": cdfs,
        })
    return {
        "name": "riskSolverDistributions",
        "reference": f"scipy {scipy.__version__}",
        "note": ("Generated once by Scripts/reference-fixtures/generate_risk_solver.py. "
                 "Parameterisation, not arithmetic, is what these guard: a self-consistent "
                 "cdf/quantile pair bound to the wrong arguments round-trips perfectly."),
        "cases": entries,
    }


def main() -> int:
    payload = build()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)
    digest = hashlib.sha256(text.encode()).hexdigest()

    total = sum(len(c["quantiles"]) + len(c["cdfProbes"]) for c in payload["cases"])
    print(f"{OUTPUT.name}: {len(payload['cases'])} parameterisations, {total} values")
    print(f"  sha256 {digest}")
    print(f"  scipy {scipy.__version__} · numpy {numpy.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
