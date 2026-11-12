#!/usr/bin/env python3
"""Reference values for the exact, tie-aware rank-sum distribution and its critical values.

Run by hand; commit the output. CI never executes this, and the Swift tests need neither
Python nor R.

    .venv/bin/python generate_rank_sum.py      # SciPy, NumPy, and R if Rscript is on PATH

Writes Tests/BusinessMathTests/Fixtures/rankSumDistribution.json.

## What is being checked

`rankSumDistribution(judgeRanks:)` claims the null distribution of one wine's rank sum
across m judges. Under H0 each judge's ranking is a uniformly random permutation of that
judge's own multiset of (averaged) ranks, so the wine's rank from judge j is uniform over
judge j's multiset, independently across judges, and the sum is the convolution of m
discrete uniforms. Averaged ranks are multiples of 0.5, so everything is done in doubled
units, where every rank is an integer.

Four references, each independent of the Swift code and of each other where it matters:

1. **Exact rational arithmetic** (this file). Integer counts over n^m outcomes, convolved
   with Python's arbitrary-precision integers, so the pmf, the tail probabilities, and the
   comparison against alpha/2 are exact. Nothing is rounded until the JSON is written.
2. **NumPy float64 convolution** (`numpy.convolve`) of the same per-judge pmfs. Recorded as
   the largest disagreement with (1); it is a check on (1), not a separate fixture.
3. **R** (`generate_rank_sum.R`, base R only), a second implementation of the convolution
   and of the critical-value rule, in another language. Its pmf and critical values are
   recorded and the Swift tests check both.
4. **Monte Carlo by permutation**, on a large tied panel. Each draw shuffles every judge's
   *whole row* with NumPy and takes the resulting rank sums, so it tests the claim the
   method rests on (a wine's rank from a shuffled judge is uniform over the multiset) rather
   than re-sampling from that model. The empirical tail frequencies at the exact critical
   values are recorded with their binomial standard errors, and so is the share of draws in
   which *some* wine is significant: the multiple-comparison rate the docs warn about.

## The critical-value convention

At two-sided level alpha:

- `lower` is the largest attainable sum L with P(S <= L) <= alpha/2,
- `upper` is the smallest attainable sum U with P(S >= U) <= alpha/2,
- a sum <= L or >= U is significant; either may not exist (null in the JSON).

"Attainable" means a point of the support. Without ties every sum is an integer and odd
doubled sums have probability zero; restricting to the support is what keeps L and U on
sums that can actually occur.

## Kramer (1963)

`kramer_1963_5pct.txt` is the 5% table as WineTaster carries it. For every cell the exact
untied critical values at alpha = 0.05 and 0.10 are recorded, and the generator reports
how often the published cell equals them under two readings of the table (the significant
bounds L, U themselves, or the bounds of the non-significant range L+1 .. U-1). The table
does not match the exact per-wine test at any single level; see the printed summary.
"""

import hashlib
import json
import platform
import shutil
import subprocess
import sys
import tempfile
from fractions import Fraction
from pathlib import Path

import numpy as np
import scipy
from scipy import stats

HERE = Path(__file__).resolve().parent
CASES = HERE / "rank_sum_cases.txt"
KRAMER = HERE / "kramer_1963_5pct.txt"
R_SCRIPT = HERE / "generate_rank_sum.R"
OUTPUT = (HERE.parents[1] / "Tests" / "BusinessMathTests" / "Fixtures"
          / "rankSumDistribution.json")

ALPHAS = [Fraction(5, 100), Fraction(10, 100), Fraction(1, 100)]
SEED = 20261112
MC_DRAWS = 400_000
MC_BATCH = 20_000


# MARK: - Input

def read_cases(path):
    cases, name, rows = [], None, []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if raw.startswith("#"):
            continue
        if line.startswith("case "):
            if name is not None and rows:
                cases.append((name, np.array(rows, dtype=float)))
            name, rows = line[5:], []
        elif not line:
            if name is not None and rows:
                cases.append((name, np.array(rows, dtype=float)))
            name, rows = None, []
        else:
            rows.append([float(v) for v in line.split()])
    if name is not None and rows:
        cases.append((name, np.array(rows, dtype=float)))
    return cases


def seeded_score_panel(rng, judges, wines, top):
    """Integer scores 1..top, so ties are common, as with a real scoring panel."""
    return rng.integers(1, top + 1, size=(judges, wines)).astype(float)


def untied_panel(judges, wines):
    return np.tile(np.arange(1, wines + 1, dtype=float), (judges, 1))


def averaged_ranks(values):
    return np.apply_along_axis(stats.rankdata, 1, values)


# MARK: - Reference 1: exact integer counts

def doubled(ranks_row):
    out = []
    for r in ranks_row:
        d = 2 * r
        if d != round(d):
            raise ValueError(f"not a half-integer rank: {r}")
        out.append(int(round(d)))
    return out


def exact_counts(ranks):
    """Counts over n^m equally likely outcomes, indexed from the minimum doubled sum."""
    counts = [1]
    low = 0
    for row in ranks:
        d = doubled(row)
        lo, hi = min(d), max(d)
        step = [0] * (hi - lo + 1)
        for v in d:
            step[v - lo] += 1
        # Python integers are arbitrary precision: numpy.convolve over dtype=object adds
        # and multiplies them exactly, term by term (no FFT, no floating point).
        counts = list(np.convolve(np.array(counts, dtype=object), np.array(step, dtype=object)))
        low += lo
    total = len(ranks[0]) ** len(ranks)
    assert sum(counts) == total
    return low, counts, total


def exact_critical(low, counts, total, alpha):
    tail = alpha / 2
    lower = upper = None
    lower_p = upper_p = None
    running = 0
    for i, c in enumerate(counts):
        running += c
        if c and Fraction(running, total) <= tail:
            lower, lower_p = low + i, Fraction(running, total)
    running = 0
    for i in range(len(counts) - 1, -1, -1):
        running += counts[i]
        if counts[i] and Fraction(running, total) <= tail:
            upper, upper_p = low + i, Fraction(running, total)
    return lower, upper, lower_p, upper_p


def exact_moments(ranks):
    m, n = ranks.shape
    mean = Fraction(0)
    var = Fraction(0)
    for row in ranks:
        d = [Fraction(v, 2) for v in doubled(row)]
        mu = sum(d) / n
        mean += mu
        var += sum((x - mu) ** 2 for x in d) / n
    return mean, var


def tie_formula_variance(ranks):
    """(n^2 - 1)/12 - sum(t^3 - t)/(12 n) per judge: the textbook form, as a cross-check."""
    m, n = ranks.shape
    total = Fraction(0)
    for row in ranks:
        _, sizes = np.unique(row, return_counts=True)
        ties = sum(int(t) ** 3 - int(t) for t in sizes)
        total += Fraction(n * n - 1, 12) - Fraction(ties, 12 * n)
    return total


# MARK: - Reference 2: NumPy float convolution

def numpy_pmf(ranks):
    m, n = ranks.shape
    pmf = np.array([1.0])
    low = 0
    for row in ranks:
        d = doubled(row)
        lo, hi = min(d), max(d)
        step = np.zeros(hi - lo + 1)
        for v in d:
            step[v - lo] += 1.0 / n
        pmf = np.convolve(pmf, step)
        low += lo
    return low, pmf


# MARK: - Reference 3: R

def run_r(cases):
    rscript = shutil.which("Rscript")
    if rscript is None:
        return None, None
    version = subprocess.run([rscript, "--version"], capture_output=True, text=True)
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
        for name, ranks in cases:
            handle.write(f"case {name}\n")
            for row in ranks:
                handle.write(" ".join(repr(float(v)) for v in row) + "\n")
            handle.write("\n")
        path = handle.name
    out = subprocess.run([rscript, str(R_SCRIPT), path],
                         capture_output=True, text=True, check=True)
    values = {}
    for line in out.stdout.splitlines():
        name, low, pmf, *crit = line.split("\t")
        parsed = []
        for c in crit:
            lo, hi = c.split("|")
            parsed.append((None if lo == "NA" else int(lo), None if hi == "NA" else int(hi)))
        values[name] = (int(low), [float(v) for v in pmf.split(",")], parsed)
    return (version.stdout or version.stderr).strip().splitlines()[0], values


# MARK: - Reference 4: Monte Carlo by permutation

def monte_carlo(ranks, lower, upper, rng):
    """Shuffle every judge's whole row; count tail hits for wine 0, and any-wine hits."""
    m, n = ranks.shape
    low_hits = high_hits = any_hits = 0
    draws = 0
    lo_sum = None if lower is None else lower / 2
    hi_sum = None if upper is None else upper / 2
    while draws < MC_DRAWS:
        b = min(MC_BATCH, MC_DRAWS - draws)
        keys = rng.random((b, m, n))
        perm = np.argsort(keys, axis=2)
        permuted = np.take_along_axis(np.broadcast_to(ranks, (b, m, n)), perm, axis=2)
        sums = permuted.sum(axis=1)  # (b, n): every wine's rank sum in this draw
        wine0 = sums[:, 0]
        sig = np.zeros_like(sums, dtype=bool)
        if lo_sum is not None:
            low_hits += int(np.count_nonzero(wine0 <= lo_sum + 1e-9))
            sig |= sums <= lo_sum + 1e-9
        if hi_sum is not None:
            high_hits += int(np.count_nonzero(wine0 >= hi_sum - 1e-9))
            sig |= sums >= hi_sum - 1e-9
        any_hits += int(np.count_nonzero(sig.any(axis=1)))
        draws += b
    return {
        "draws": draws,
        "lowerTailFrequency": low_hits / draws,
        "upperTailFrequency": high_hits / draws,
        "anyWineSignificantFrequency": any_hits / draws,
    }


# MARK: - Kramer 1963

def read_kramer():
    cells = []
    for raw in KRAMER.read_text().splitlines():
        if raw.startswith("#") or not raw.strip():
            continue
        wines, judges, lo, hi = (int(v) for v in raw.split())
        cells.append((wines, judges, lo, hi))
    return cells


def untied_counts(judges, wines):
    ranks = np.tile(np.arange(1, wines + 1, dtype=float), (judges, 1))
    return exact_counts(ranks)


def kramer_section():
    cells = read_kramer()
    out = []
    for wines, judges, lo, hi in cells:
        low, counts, total = untied_counts(judges, wines)
        exact = {}
        for alpha in (Fraction(5, 100), Fraction(10, 100)):
            l, u, _, _ = exact_critical(low, counts, total, alpha)
            exact[str(float(alpha))] = {
                "lower": None if l is None else l // 2,
                "upper": None if u is None else u // 2,
            }
        out.append({"wines": wines, "judges": judges, "tableLow": lo, "tableHigh": hi,
                    "exact": exact})

    def reading(alpha_key, offset):
        hits, misses = 0, []
        for cell in out:
            e = cell["exact"][alpha_key]
            if e["lower"] is None:
                expected = (0, 0)
            else:
                expected = (e["lower"] + offset, e["upper"] - offset)
            if expected == (cell["tableLow"], cell["tableHigh"]):
                hits += 1
            else:
                misses.append((cell["wines"], cell["judges"],
                               (cell["tableLow"], cell["tableHigh"]), expected))
        return hits, misses

    summary = {}
    for alpha_key in ("0.05", "0.1"):
        for offset, label in ((0, "significantBounds"), (1, "nonSignificantRange")):
            hits, misses = reading(alpha_key, offset)
            summary[f"alpha {alpha_key}, {label}"] = {"matches": hits, "cells": len(out),
                                                      "mismatches": len(misses)}
            print(f"// Kramer: alpha {alpha_key}, table read as {label}: {hits}/{len(out)}")
            if alpha_key == "0.05" and offset == 1:
                for w, j, table, exp in misses:
                    print(f"//   {j:2d} judges x {w:2d} wines: table {table}, exact {exp}")
    asymmetric = [(c["wines"], c["judges"], c["tableLow"], c["tableHigh"]) for c in out
                  if c["tableLow"] + c["tableHigh"] not in (0, c["judges"] * (c["wines"] + 1))]
    print(f"// Kramer: cells with low + high != judges (wines + 1): {asymmetric}")
    return {"source": "Kramer, A. (1963). Revised tables for determining significance of "
                      "differences. Food Technology 17(12), 1596-1597. 5% table, as "
                      "transcribed in WineTaster's significanceBreakpointArray.",
            "cells": out, "agreement": summary,
            "asymmetricCells": [list(a) for a in asymmetric]}


# MARK: - Assembly

def case_record(name, ranks, r_values, rng=None, with_pmf=True, mc=False):
    m, n = ranks.shape
    low, counts, total = exact_counts(ranks)
    pmf = [Fraction(c, total) for c in counts]
    np_low, np_pmf = numpy_pmf(ranks)
    assert np_low == low and len(np_pmf) == len(pmf)
    numpy_gap = max(abs(float(p) - q) for p, q in zip(pmf, np_pmf))
    mean, var = exact_moments(ranks)
    assert var == tie_formula_variance(ranks), name
    assert mean == Fraction(m * (n + 1), 2), name

    critical = []
    for alpha in ALPHAS:
        lo, hi, lo_p, hi_p = exact_critical(low, counts, total, alpha)
        nominal = float(alpha) / 2
        z = float(stats.norm.ppf(1 - nominal))
        sd = float(var) ** 0.5
        critical.append({
            "alpha": float(alpha),
            "lower": lo, "upper": hi,
            "lowerTail": None if lo_p is None else float(lo_p),
            "upperTail": None if hi_p is None else float(hi_p),
            "lowerTailIsExactlyHalfAlpha": lo_p == alpha / 2,
            "normalLower": float(mean) - z * sd,
            "normalUpper": float(mean) + z * sd,
        })

    record = {
        "name": name,
        "judgeRanks": ranks.tolist(),
        "minimumDoubledSum": low,
        "mean": float(mean),
        "variance": float(var),
        "numpyMaxAbsoluteDifference": numpy_gap,
        "critical": critical,
    }
    if with_pmf:
        record["probabilities"] = [float(p) for p in pmf]
    if r_values and name in r_values:
        r_low, r_pmf, r_crit = r_values[name]
        assert r_low == low, name
        r_gap = max(abs(float(p) - q) for p, q in zip(pmf, r_pmf))
        record["rMaxAbsoluteDifference"] = r_gap
        if with_pmf:
            record["rProbabilities"] = r_pmf
        record["rCritical"] = [{"alpha": float(a), "lower": lo, "upper": hi}
                               for a, (lo, hi) in zip(ALPHAS, r_crit)]
        agree = all((c["lower"], c["upper"]) == (lo, hi) for c, (lo, hi) in zip(critical, r_crit))
        record["rAgreesWithExact"] = agree
        if not agree:
            print(f"// WARNING {name}: R's double-precision critical values differ from exact: "
                  f"{r_crit} vs {[(c['lower'], c['upper']) for c in critical]}")
    # What a plain float64 pmf with a bare `<=` would have chosen, for the record.
    float_choice = []
    for alpha in ALPHAS:
        half = float(alpha) / 2
        cdf = np.cumsum(np_pmf)
        sf = np.cumsum(np_pmf[::-1])[::-1]
        lows = [low + i for i in range(len(np_pmf)) if np_pmf[i] > 0 and cdf[i] <= half]
        highs = [low + i for i in range(len(np_pmf)) if np_pmf[i] > 0 and sf[i] <= half]
        float_choice.append((max(lows) if lows else None, min(highs) if highs else None))
    record["float64AgreesWithExact"] = all(
        (c["lower"], c["upper"]) == f for c, f in zip(critical, float_choice))
    if not record["float64AgreesWithExact"]:
        print(f"// NOTE {name}: float64 pmf with bare <= picks {float_choice}")
    if mc:
        five = critical[0]
        result = monte_carlo(ranks, five["lower"], five["upper"], rng)
        p_lo = five["lowerTail"] or 0.0
        p_hi = five["upperTail"] or 0.0
        result["alpha"] = 0.05
        result["lowerTailStandardError"] = (p_lo * (1 - p_lo) / result["draws"]) ** 0.5
        result["upperTailStandardError"] = (p_hi * (1 - p_hi) / result["draws"]) ** 0.5
        result["seed"] = SEED
        record["monteCarlo"] = result
        print(f"// {name}: exact tails {p_lo:.6f} / {p_hi:.6f}, "
              f"MC {result['lowerTailFrequency']:.6f} / {result['upperTailFrequency']:.6f} "
              f"(se {result['lowerTailStandardError']:.6f}); "
              f"any wine significant {result['anyWineSignificantFrequency']:.4f}")
    return record


def main():
    rng = np.random.default_rng(SEED)
    small = [(name, averaged_ranks(values)) for name, values in read_cases(CASES)]
    large = [
        ("Monte Carlo panel, 24 judges x 12 wines, scores 1-6",
         averaged_ranks(seeded_score_panel(rng, 24, 12, 6))),
        ("large panel, 40 judges x 30 wines, scores 1-10",
         averaged_ranks(seeded_score_panel(rng, 40, 30, 10))),
    ]
    # Large panels for the exactness guarantee: critical values only (no pmf in the JSON),
    # each from exact integer counts. Tied and untied, up to 200 judges and 50 wines.
    big = [
        ("large untied panel, 100 judges x 50 wines", untied_panel(100, 50)),
        ("large tied panel, 100 judges x 50 wines, scores 1-20",
         averaged_ranks(seeded_score_panel(rng, 100, 50, 20))),
        ("large untied panel, 200 judges x 20 wines", untied_panel(200, 20)),
        ("large tied panel, 150 judges x 30 wines, scores 1-10",
         averaged_ranks(seeded_score_panel(rng, 150, 30, 10))),
        ("large tied panel, 60 judges x 40 wines, scores 1-5",
         averaged_ranks(seeded_score_panel(rng, 60, 40, 5))),
    ]
    r_version, r_values = run_r(small + large + big)

    print(f"// SciPy {scipy.__version__}, NumPy {np.__version__}, Python {platform.python_version()}")
    print(f"// {r_version or 'R not available'}")
    records = [case_record(name, ranks, r_values) for name, ranks in small]
    records.append(case_record(*large[0], r_values, rng=rng, with_pmf=True, mc=True))
    records.append(case_record(*large[1], r_values, with_pmf=False))
    for name, ranks in big:
        records.append(case_record(name, ranks, r_values, with_pmf=False))
    for rec in records:
        five = rec["critical"][0]
        print(f"// {rec['name']}: mean {rec['mean']} var {rec['variance']} "
              f"5% doubled bounds {five['lower']}, {five['upper']} "
              f"numpy gap {rec['numpyMaxAbsoluteDifference']:.2e} "
              f"R gap {rec.get('rMaxAbsoluteDifference', float('nan')):.2e}")

    payload = {
        "name": "rankSumDistribution",
        "reference": "exact integer-count convolution (Python), numpy.convolve, base R "
                     "convolution (generate_rank_sum.R), Monte Carlo by row permutation",
        "note": "Sums are in doubled units (2 x rank sum) so tied, averaged ranks are "
                "integers. lower/upper are significant bounds: P(S <= lower) <= alpha/2, "
                "P(S >= upper) <= alpha/2, both attainable; null when none exists.",
        "generator": {"scipy": scipy.__version__, "numpy": np.__version__,
                      "python": platform.python_version(), "r": r_version},
        "cases": records,
        "kramer1963": kramer_section(),
    }
    text = json.dumps(payload, indent=1, sort_keys=True) + "\n"
    OUTPUT.write_text(text)
    print(f"// wrote {OUTPUT.name}, sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
