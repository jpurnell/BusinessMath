#!/usr/bin/env python3
"""Reference values for the exact, tie-aware null distribution of Spearman's rho.

Run by hand; commit the output. CI never executes this, and the Swift tests need neither
Python nor R.

    .venv/bin/python generate_spearman.py      # SciPy, NumPy, and R if Rscript is on PATH

Writes Tests/BusinessMathTests/Fixtures/spearmanDistribution.json.

## The null hypothesis

Two judges rank the same n items. One judge's ranking is held fixed; the other's is a
uniformly random permutation of that judge's own multiset of ranks, averaged for ties. The
tie structures of both judges are conditioned on as observed. The statistic is the Pearson
correlation of the averaged ranks (Spearman's rho, tie-corrected), which under permutation
is an increasing function of sum(X_i * Y_i) and a decreasing function of
S = sum(d_i^2). Everything is computed in doubled ranks, where every averaged rank is an
integer, and S is recorded as 4S, also an integer.

## References, independent of the Swift code and, where it matters, of each other

1. **Brute force** (this file): every one of the n! permutations, with Python integers, for
   every case with n <= 9 (tied or not) and, with NumPy, n = 10 without ties.
2. **Exact dynamic programming** (this file): a second exact method, over positions with the
   multiset of values already used as the state, in Python integers (NumPy int64 where the
   count provably fits). Checked against (1) wherever both run, and used beyond.
3. **R 4.6.2** (`generate_spearman.R`): `cor.test(method = "spearman")` with
   `exact = TRUE` and `exact = FALSE`. R's "exact" p-value is exact only for n <= 9 without
   ties; for 10 <= n <= 1290 it is the AS 89 Edgeworth series, and with ties R uses the t
   approximation (see the R script).
4. **SciPy 1.18.1**: `spearmanr` (the t approximation) and, for n <= 8, the exact
   `permutation_test(..., permutation_type="pairings")`, tied and untied.
5. **Monte Carlo** (NumPy, seeded): for tied panels too large for the exact method, the
   p-value by permuting one judge's ranks, to characterise the t approximation there.

## Critical values

At two-sided level alpha, on the exact distribution:

- `upper` is the smallest attainable rho U with P(rho >= U) <= alpha/2,
- `lower` is the largest attainable rho L with P(rho <= L) <= alpha/2,
- a rho >= U or <= L is significant; either may not exist (null in the JSON).

Comparisons with alpha/2 are made in exact rational arithmetic.

## p-values

Two-sided: min(1, 2 min(P(rho <= r), P(rho >= r))), the convention of both R's
`cor.test` and SciPy's `permutation_test`.
"""

import hashlib
import itertools
import json
import math
import platform
import shutil
import subprocess
import sys
import tempfile
from decimal import Decimal, getcontext
from fractions import Fraction
from pathlib import Path

import numpy as np
import scipy
from scipy import stats

HERE = Path(__file__).resolve().parent
R_SCRIPT = HERE / "generate_spearman.R"
OUTPUT = (HERE.parents[1] / "Tests" / "BusinessMathTests" / "Fixtures"
          / "spearmanDistribution.json")

ALPHAS = [Fraction(5, 100), Fraction(10, 100), Fraction(1, 100)]
SEED = 20261112
MC_DRAWS = 1_000_000
getcontext().prec = 60


# MARK: - Ranks

def doubled_ranks(values):
    """Averaged ranks, doubled, as Python ints (exact: 2 * average rank is an integer)."""
    ranks = stats.rankdata(values)
    out = []
    for r in ranks:
        d = 2 * r
        assert d == round(d)
        out.append(int(round(d)))
    return out


def tie_sizes(doubled):
    counts = {}
    for v in doubled:
        counts[v] = counts.get(v, 0) + 1
    return sorted(counts.items())


# MARK: - Reference 1: brute force

def brute_force(x2, y2):
    """Counts of sum(X*Y) over all n! permutations of y (duplicates counted), Python ints."""
    n = len(x2)
    counts = {}
    if n <= 9:
        for perm in itertools.permutations(y2):
            k = sum(a * b for a, b in zip(x2, perm))
            counts[k] = counts.get(k, 0) + 1
        return counts, math.factorial(n)
    # n = 10: all 3,628,800 permutations as one int64 array, in chunks.
    xs = np.array(x2, dtype=np.int64)
    ys = np.array(y2, dtype=np.int64)
    gen = itertools.permutations(range(n))
    while True:
        chunk = np.array(list(itertools.islice(gen, 500_000)), dtype=np.int64)
        if chunk.size == 0:
            break
        k = (ys[chunk] * xs).sum(axis=1)
        values, freq = np.unique(k, return_counts=True)
        for v, f in zip(values.tolist(), freq.tolist()):
            counts[v] = counts.get(v, 0) + f
    return counts, math.factorial(n)


# MARK: - Reference 2: exact dynamic programming

def exact_dp(x2, y2):
    """Counts of sum(X*Y) over the n!/prod(t!) distinct arrangements of y's multiset.

    Positions are x's values in sorted order; the state is how many of each distinct y value
    have been placed. Each distinct arrangement is one path, and under the null every
    distinct arrangement is equally likely (each stands for prod(t!) permutations).
    """
    n = len(x2)
    xs = sorted(x2)
    groups = tie_sizes(y2)                     # [(value, multiplicity)]
    values = [v for v, _ in groups]
    sizes = [t for _, t in groups]
    total = math.factorial(n)
    for t in sizes:
        total //= math.factorial(t)
    dtype = np.int64 if total < 2 ** 62 else object
    layer = {tuple(0 for _ in sizes): (0, np.array([1], dtype=dtype))}
    for k in range(n):
        children = {}
        for state, (lo, arr) in layer.items():
            for j, v in enumerate(values):
                if state[j] == sizes[j]:
                    continue
                child = state[:j] + (state[j] + 1,) + state[j + 1:]
                children.setdefault(child, []).append((lo + xs[k] * v, arr))
        layer = {}
        for child, parts in children.items():
            lo = min(p[0] for p in parts)
            hi = max(p[0] + len(p[1]) - 1 for p in parts)
            acc = np.zeros(hi - lo + 1, dtype=dtype)
            for plo, arr in parts:
                acc[plo - lo:plo - lo + len(arr)] += arr
            layer[child] = (lo, acc)
    ((lo, arr),) = layer.values()
    counts = {lo + i: int(c) for i, c in enumerate(arr.tolist()) if c}
    assert sum(counts.values()) == total
    return counts, total


# MARK: - Mapping the statistic

def moments(x2, y2):
    n = len(x2)
    sx, sy = sum(x2), sum(y2)
    a = n * sum(v * v for v in x2) - sx * sx
    b = n * sum(v * v for v in y2) - sy * sy
    return n, sx, sy, a, b


def rho_of(k, x2, y2):
    """rho for sum(X*Y) = k, to 60 digits, then one rounding to float."""
    n, sx, sy, a, b = moments(x2, y2)
    num = Decimal(n * k - sx * sy)
    den = (Decimal(a) * Decimal(b)).sqrt()
    return float(num / den)


def four_s_of(k, x2, y2):
    """4 * sum(d^2) for sum(X*Y) = k: sum((X - Y)/2)^2 * 4 = sum(X^2) + sum(Y^2) - 2k."""
    return sum(v * v for v in x2) + sum(v * v for v in y2) - 2 * k


# MARK: - Exact critical values and p-values

def critical(counts, total, alpha):
    keys = sorted(counts)
    tail = alpha / 2
    lower = upper = None
    lower_c = upper_c = None
    running = 0
    for k in keys:
        running += counts[k]
        if Fraction(running, total) <= tail:
            lower, lower_c = k, running
        else:
            break
    running = 0
    for k in reversed(keys):
        running += counts[k]
        if Fraction(running, total) <= tail:
            upper, upper_c = k, running
        else:
            break
    return lower, upper, lower_c, upper_c


def exact_p(counts, total, k):
    below = sum(c for key, c in counts.items() if key <= k)
    above = sum(c for key, c in counts.items() if key >= k)
    return min(Fraction(1), 2 * Fraction(min(below, above), total))


# MARK: - Approximations (Python ports, for characterising error; the Swift tests use R)

def prho_upper(n, s):
    """AS 89 as in R's prho.c, Edgeworth branch: P(S >= s), no ties."""
    c = [.2274, .2531, .1745, .0758, .1033, .3932, .0879, .0151, .0072, .0831, .0131, 4.6e-4]
    if s <= 0:
        return 1.0
    n3 = n * (n * n - 1) / 3
    if s > n3:
        return 0.0
    y = float(n)
    b = 1 / y
    x = (6 * (s - 1) * b / (y * y - 1) - 1) * math.sqrt(y - 1)
    y = x * x
    u = x * b * (c[0] + b * (c[1] + c[2] * b) + y * (-c[3] + b * (c[4] + c[5] * b)
        - y * b * (c[6] + c[7] * b - y * (c[8] - c[9] * b + y * b * (c[10] - c[11] * y)))))
    y = u / math.exp(y / 2)
    p = y + stats.norm.sf(x)
    return min(max(p, 0.0), 1.0)


def edgeworth_two_sided(n, s):
    """R's two-sided p from the Edgeworth branch: S = sum(d^2), even integer."""
    if s > (n ** 3 - n) / 6:
        p = prho_upper(n, s)
    else:
        p = 1 - prho_upper(n, s + 2)
    return min(2 * p, 1.0)


def t_two_sided(r, n):
    if abs(r) >= 1:
        return 0.0
    return float(scipy.special.betainc((n - 2) / 2, 0.5, 1 - r * r))


# MARK: - Cases

def untied_case(n):
    return [2 * i for i in range(1, n + 1)]


def observations_for(rng, x, y, extra):
    """The case's own pairing plus `extra` seeded shuffles of y, and the extremes."""
    obs = [(list(x), list(y))]
    obs.append((list(x), sorted(y)))
    obs.append((list(x), sorted(y, reverse=True)))
    for _ in range(extra):
        obs.append((list(x), list(rng.permutation(y))))
    return obs


def build_cases(rng):
    cases = []
    for n in range(2, 15):
        x = list(range(1, n + 1))
        y = list(rng.permutation(x))
        cases.append((f"untied, n = {n}", x, y))
    tied = [
        ("n = 4, one tied pair in y", [1, 2, 3, 4], [1, 2, 2, 4]),
        ("n = 5, ties in both", [1, 1, 3, 4, 5], [1, 2, 2, 2, 5]),
        ("n = 6, three pairs in y", [1, 2, 3, 4, 5, 6], [1, 1, 2, 2, 3, 3]),
        ("n = 6, y two values", [1, 2, 3, 4, 5, 6], [0, 0, 0, 1, 1, 1]),
        ("n = 7, scores 1-4", [3, 1, 4, 1, 5, 9, 2], [2, 4, 1, 3, 3, 2, 4]),
        ("n = 8, one tied triple", [1, 2, 3, 4, 5, 6, 7, 8], [5, 3, 3, 3, 8, 1, 2, 7]),
        ("n = 8, scores 1-5 both", [1, 2, 2, 3, 4, 4, 5, 5], [2, 1, 3, 3, 5, 4, 4, 1]),
        ("n = 9, x tied pair, y tied pair", [1, 2, 3, 4, 5, 5, 7, 8, 9],
         [9, 8, 1, 2, 3, 4, 4, 6, 7]),
        ("n = 10, scores 1-5", list(rng.integers(1, 6, 10)), list(rng.integers(1, 6, 10))),
        ("n = 12, scores 1-5", list(rng.integers(1, 6, 12)), list(rng.integers(1, 6, 12))),
        ("n = 12, one judge two ties", list(range(1, 13)),
         [1, 2, 2, 4, 5, 6, 7, 8, 9, 9, 9, 12]),
        ("n = 14, scores 1-10", list(rng.integers(1, 11, 14)), list(range(1, 15))),
        ("n = 20, scores 1-5", list(rng.integers(1, 6, 20)), list(rng.integers(1, 6, 20))),
    ]
    cases.extend(tied)
    return cases


def degenerate_cases():
    return [("n = 5, y tied everything", [1, 2, 3, 4, 5], [3, 3, 3, 3, 3])]


# MARK: - R

def run_r(observations):
    if shutil.which("Rscript") is None:
        return None, {}
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "observations.tsv"
        with path.open("w") as f:
            for name, idx, x, y in observations:
                f.write(f"{name}\t{idx}\t{','.join(map(repr, map(float, x)))}\t"
                        f"{','.join(map(repr, map(float, y)))}\n")
        out = subprocess.run(["Rscript", str(R_SCRIPT), str(path)], check=True,
                             capture_output=True, text=True).stdout
    version, values = None, {}
    for line in out.splitlines():
        fields = line.split("\t")
        if fields[0] == "#version":
            version = fields[1]
            continue
        values[(fields[0], int(fields[1]))] = (float(fields[2]), float(fields[3]),
                                               float(fields[4]))
    return version, values


# MARK: - Records

def distribution_record(name, x, y, rng, r_values):
    x2, y2 = doubled_ranks(x), doubled_ranks(y)
    n = len(x2)
    print(f"// building {name}", flush=True)
    counts, total = exact_dp(x2, y2)
    record = {"name": name, "x": [float(v) for v in x], "y": [float(v) for v in y],
              "n": n, "total": str(total)}
    if n <= 10 and (n <= 9 or len(set(y2)) == n):
        brute, brute_total = brute_force(x2, y2)
        same = (set(brute) == set(counts) and
                all(Fraction(brute[k], brute_total) == Fraction(counts[k], total)
                    for k in counts))
        assert same, name
        record["bruteForceAgrees"] = True
    keys = sorted(counts)
    if n <= 14:
        record["fourS"] = [four_s_of(k, x2, y2) for k in keys]
        record["counts"] = [str(counts[k]) for k in keys]
    record["supportSize"] = len(keys)

    _, sx, sy, a, b = moments(x2, y2)
    # Var(rho) = 1/(n - 1) for any fixed, non-constant vectors under permutation: a closed
    # form, independent of either computation.
    mean = sum(Fraction(c, total) * Fraction(n * k - sx * sy) for k, c in counts.items())
    second = sum(Fraction(c, total) * Fraction((n * k - sx * sy) ** 2, a * b)
                 for k, c in counts.items())
    assert mean == 0 and second == Fraction(1, n - 1), name

    record["critical"] = []
    for alpha in ALPHAS:
        lo, hi, lo_c, hi_c = critical(counts, total, alpha)
        record["critical"].append({
            "alpha": float(alpha),
            "lowerRho": None if lo is None else rho_of(lo, x2, y2),
            "upperRho": None if hi is None else rho_of(hi, x2, y2),
            "lowerFourS": None if lo is None else four_s_of(lo, x2, y2),
            "upperFourS": None if hi is None else four_s_of(hi, x2, y2),
            "lowerTail": None if lo_c is None else float(Fraction(lo_c, total)),
            "upperTail": None if hi_c is None else float(Fraction(hi_c, total)),
            "tCritical": t_critical(alpha, n),
        })

    record["observations"] = []
    extra = 4 if n >= 4 else 0
    for idx, (ox, oy) in enumerate(observations_for(rng, x, y, extra)):
        ox2, oy2 = doubled_ranks(ox), doubled_ranks(oy)
        k = sum(p * q for p, q in zip(ox2, oy2))
        obs = {"x": [float(v) for v in ox], "y": [float(v) for v in oy],
               "rho": rho_of(k, ox2, oy2), "fourS": four_s_of(k, ox2, oy2)}
        p = exact_p(counts, total, k)
        obs["exactP"] = float(p)
        if n >= 3:
            sp = stats.spearmanr(ox, oy)
            obs["scipyT"] = float(sp.pvalue)
        if n <= 8:
            # One sample: 'pairings' permutes it against the fixed y, n! arrangements. (Passing
            # both samples permutes both, (n!)^2.)
            fixed_y = np.array(oy, float)
            res = stats.permutation_test(
                (np.array(ox, float),),
                lambda a, axis=-1: spearman_statistic(a, np.broadcast_to(fixed_y, a.shape), axis),
                permutation_type="pairings", n_resamples=np.inf, alternative="two-sided",
                vectorized=True)
            obs["scipyPermutation"] = float(res.pvalue)
        rv = r_values.get((name, idx))
        if rv:
            obs["rRho"], obs["rExactArgument"], obs["rT"] = rv
        if len(set(x2)) == n and len(set(y2)) == n and n >= 3:
            obs["edgeworth"] = edgeworth_two_sided(n, four_s_of(k, ox2, oy2) // 4)
        record["observations"].append(obs)
    return record


def spearman_statistic(a, b, axis=-1):
    """Pearson correlation of averaged ranks along `axis`: SciPy's spearmanr, vectorised."""
    ra = stats.rankdata(a, axis=axis)
    rb = stats.rankdata(b, axis=axis)
    ra = ra - ra.mean(axis=axis, keepdims=True)
    rb = rb - rb.mean(axis=axis, keepdims=True)
    return (ra * rb).sum(axis=axis) / np.sqrt((ra * ra).sum(axis=axis) * (rb * rb).sum(axis=axis))


def t_critical(alpha, n):
    if n < 3:
        return None
    x = scipy.special.betaincinv((n - 2) / 2, 0.5, float(alpha))
    return math.sqrt(1 - x)


# MARK: - Error characterisation (printed; summarised in the DocC article)

def characterise_untied(max_n):
    """Edgeworth (R, n >= 10), t, and Fisher-z-1.06 against the exact distribution."""
    rows = []
    for n in range(4, max_n + 1):
        x2 = untied_case(n)
        counts, total = exact_dp(x2, x2)
        keys = sorted(counts)
        worst_e = worst_t = 0.0
        for k in keys:
            s = four_s_of(k, x2, x2) // 4
            p = float(exact_p(counts, total, k))
            r = rho_of(k, x2, x2)
            worst_e = max(worst_e, abs(edgeworth_two_sided(n, s) - p))
            worst_t = max(worst_t, abs(t_two_sided(r, n) - p))
        row = {"n": n, "edgeworthMaxAbsError": worst_e, "tMaxAbsError": worst_t}
        for alpha in ALPHAS:
            lo, hi, lo_c, hi_c = critical(counts, total, alpha)
            exact_upper = None if hi is None else rho_of(hi, x2, x2)
            # Edgeworth critical value on the attainable lattice (as R's p-values would give).
            edge_upper = None
            for k in reversed(keys):
                s = four_s_of(k, x2, x2) // 4
                if prho_upper(n, 0) and (1 - prho_upper(n, s + 2)) <= float(alpha) / 2:
                    edge_upper = rho_of(k, x2, x2)
                else:
                    break
            # t: the smallest attainable rho with t p-value <= alpha.
            t_upper = None
            for k in reversed(keys):
                r = rho_of(k, x2, x2)
                if t_two_sided(r, n) <= float(alpha):
                    t_upper = r
                else:
                    break
            z = stats.norm.ppf(1 - float(alpha) / 2) / math.sqrt((n - 3) / 1.06) if n > 3 else None
            fisher = math.tanh(z) if z is not None else None
            row[f"alpha {float(alpha)}"] = {
                "exactUpper": exact_upper, "exactUpperTail":
                    None if hi_c is None else float(Fraction(hi_c, total)),
                "edgeworthUpper": edge_upper, "tUpper": t_upper, "fisher106": fisher}
        rows.append(row)
        print(f"// n = {n:2d}: max |p - exact|  Edgeworth {worst_e:.2e}  t {worst_t:.2e}; "
              f"5% upper exact {row['alpha 0.05']['exactUpper']}, "
              f"Edgeworth {row['alpha 0.05']['edgeworthUpper']}, t {row['alpha 0.05']['tUpper']}, "
              f"Fisher-1.06 {row['alpha 0.05']['fisher106']}")
    return rows


def monte_carlo_section(rng):
    """t approximation against permutation Monte Carlo, on tied panels the exact method
    refuses (the state space of both judges' multisets is too large)."""
    out = []
    specs = [("n = 24, two tied pairs each", 24, 2), ("n = 30, scores 1-20 vs untied", 30, 20)]
    for name, n, kind in specs:
        if kind == 2:
            x = list(range(1, n + 1)); x[3] = x[4] = 4.5; x[10] = x[11] = 11.5
            y = list(range(1, n + 1)); y[0] = y[1] = 1.5; y[20] = y[21] = 21.5
        else:
            x = [float(v) for v in rng.integers(1, kind + 1, n)]
            y = list(range(1, n + 1))
        xr = stats.rankdata(x)
        yr = stats.rankdata(y)
        xc = (xr - xr.mean()) / np.sqrt(((xr - xr.mean()) ** 2).sum())
        yc = (yr - yr.mean()) / np.sqrt(((yr - yr.mean()) ** 2).sum())
        sims = np.empty(MC_DRAWS)
        batch = 50_000
        for start in range(0, MC_DRAWS, batch):
            perms = rng.permuted(np.tile(yc, (batch, 1)), axis=1)
            sims[start:start + batch] = perms @ xc
        grid = []
        for target in [0.2, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6]:
            # Observed rho near the target, reached exactly by a lattice point of the data.
            r = target
            pl = float((sims <= r + 1e-12).mean())
            pu = float((sims >= r - 1e-12).mean())
            mc = min(1.0, 2 * min(pl, pu))
            se = math.sqrt(max(min(pl, pu) * (1 - min(pl, pu)), 1e-300) / MC_DRAWS) * 2
            grid.append({"rho": r, "monteCarloP": mc, "standardError": se,
                         "tP": t_two_sided(r, n)})
            print(f"// MC {name}: rho {r:.2f}  MC p {mc:.5f} ± {se:.5f}  t p {t_two_sided(r, n):.5f}")
        out.append({"name": name, "x": [float(v) for v in x], "y": [float(v) for v in y],
                    "draws": MC_DRAWS, "seed": SEED, "grid": grid})
    return out


# MARK: - Zar (1984) Table B.19

ZAR = HERE / "zar_1984_table_b19.txt"
ZAR_ALPHAS = [Fraction(50, 100), Fraction(20, 100), Fraction(10, 100), Fraction(5, 100),
              Fraction(2, 100), Fraction(1, 100), Fraction(5, 1000), Fraction(2, 1000),
              Fraction(1, 1000)]
ZAR_EXACT_THROUGH = 18
SWIFT_TEST_THROUGH = 17
LEE = HERE / "lee_york_spearman_upper.txt"


def exact_upper_rho(counts, total, alpha, x2):
    _, hi, _, _ = critical(counts, total, alpha)
    return None if hi is None else hi


def rounded3(k, x2):
    """The exact rho at key k rounded half-up to three decimals, from 60 digits."""
    n, sx, sy, a, b = moments(x2, x2)
    value = Decimal(n * k - sx * sy) / (Decimal(a) * Decimal(b)).sqrt()
    q = value.quantize(Decimal("0.001"), rounding="ROUND_HALF_UP")
    assert abs(value - q) != Decimal("0.0005"), "a value on a rounding boundary"
    return float(q)


def zar_section():
    """Every cell of Zar's table against the exact upper bound, rounded to the table's three
    decimals. Read as Zar prints it: reject if rho >= the tabled value."""
    rows, cells, matches, mismatches = [], 0, 0, []
    tested = {"cells": 0, "matches": 0}
    cache = {}
    for raw in ZAR.read_text().splitlines():
        if raw.startswith("#") or not raw.strip():
            continue
        fields = raw.split()
        n = int(fields[0])
        printed = [None if f == "-" else float(f) for f in fields[1:]]
        row = {"n": n, "printed": printed}
        if n <= ZAR_EXACT_THROUGH:
            x2 = untied_case(n)
            counts, total = exact_dp(x2, x2)
            cache[n] = (counts, total)
            exact = []
            for col, alpha in enumerate(ZAR_ALPHAS):
                k = exact_upper_rho(counts, total, alpha, x2)
                exact.append(None if k is None else rho_of(k, x2, x2))
                mine = None if k is None else rounded3(k, x2)
                cells += 1
                if n <= SWIFT_TEST_THROUGH:
                    tested["cells"] += 1
                    tested["matches"] += mine == printed[col]
                if mine == printed[col]:
                    matches += 1
                else:
                    mismatches.append([n, float(alpha), printed[col] if printed[col] is not None else -1,
                                       mine if mine is not None else -1])
            row["exact"] = exact
        rows.append(row)
    print(f"// Zar 1984 B.19: {matches} of {cells} cells (n <= {ZAR_EXACT_THROUGH}) equal the exact "
          f"upper bound rounded to 3 decimals; mismatches (n, alpha, printed, exact): {mismatches}")
    lee_section(cache)
    return {"source": "Zar, J. H. (1984). Biostatistical Analysis, 2nd ed., Prentice-Hall, "
                      "Appendix Table B.19 (after Zar 1972, JASA 67:578-580), as reproduced in "
                      "D. Samanta, IIT Kharagpur, 'Statistical Tables', p. 12; transcribed in "
                      "Scripts/reference-fixtures/zar_1984_table_b19.txt",
            "alphas": [float(a) for a in ZAR_ALPHAS], "rows": rows,
            "exactThrough": ZAR_EXACT_THROUGH, "swiftTestThrough": SWIFT_TEST_THROUGH,
            "agreement": {"cells": cells, "matches": matches, "mismatches": mismatches},
            "agreementSwiftTested": dict(tested, mismatches=[m for m in mismatches
                                                             if m[0] <= SWIFT_TEST_THROUGH])}


def lee_section(cache):
    """Lee's York table (computed by Lee, not a published table): printed for comparison only.
    One-sided alpha a corresponds to the two-sided 2a."""
    alphas = [Fraction(20, 100), Fraction(10, 100), Fraction(5, 100), Fraction(2, 100),
              Fraction(1, 100), Fraction(2, 1000)]
    cells = matches = 0
    mismatches = []
    for raw in LEE.read_text().splitlines():
        if raw.startswith("#") or not raw.strip():
            continue
        fields = raw.split()
        n = int(fields[0])
        if n not in cache:
            continue
        counts, total = cache[n]
        x2 = untied_case(n)
        for col, alpha in enumerate(alphas):
            printed = None if fields[1 + col] == "-" else float(fields[1 + col])
            k = exact_upper_rho(counts, total, alpha, x2)
            mine = None if k is None else rounded3(k, x2)
            cells += 1
            if mine == printed:
                matches += 1
            else:
                mismatches.append((n, float(alpha), printed, mine))
    print(f"// Lee (York) table: {matches} of {cells} cells (n <= {ZAR_EXACT_THROUGH}) equal exact; "
          f"mismatches {mismatches}")


def main():
    rng = np.random.default_rng(SEED)
    cases = build_cases(rng)
    print(f"// SciPy {scipy.__version__}, NumPy {np.__version__}, Python {platform.python_version()}")

    # Observations are drawn inside distribution_record; draw them once here with a fixed
    # stream so R sees the same ones.
    obs_rng_state = rng.bit_generator.state
    planned = []
    for name, x, y in cases:
        n = len(x)
        for idx, (ox, oy) in enumerate(observations_for(rng, x, y, 4 if n >= 4 else 0)):
            if n >= 3:
                planned.append((name, idx, ox, oy))
    r_version, r_values = run_r(planned)
    print(f"// {r_version or 'R not available'}")
    rng.bit_generator.state = obs_rng_state

    records = [distribution_record(name, x, y, rng, r_values) for name, x, y in cases]
    for rec in records:
        five = rec["critical"][0]
        print(f"// {rec['name']}: support {rec['supportSize']}, 5% rho bounds "
              f"{five['lowerRho']}, {five['upperRho']}")

    degenerate = []
    for name, x, y in degenerate_cases():
        degenerate.append({"name": name, "x": [float(v) for v in x], "y": [float(v) for v in y]})

    untied = characterise_untied(16)
    mc = monte_carlo_section(np.random.default_rng(SEED + 1))

    payload = {
        "name": "spearmanDistribution",
        "reference": "brute-force enumeration (Python ints, n <= 10), exact dynamic programming "
                     "(Python ints), R cor.test (generate_spearman.R), SciPy spearmanr and "
                     "permutation_test, Monte Carlo by permutation",
        "note": "Statistic recorded as 4 * sum(d^2), an integer for averaged ranks. "
                "lowerRho/upperRho are significant bounds: P(rho <= lower) <= alpha/2, "
                "P(rho >= upper) <= alpha/2, both attainable; null when none exists. "
                "rExactArgument is R's cor.test(exact = TRUE): exact for n <= 9 untied, "
                "Edgeworth (AS 89) for n >= 10, and t with ties.",
        "generator": {"scipy": scipy.__version__, "numpy": np.__version__,
                      "python": platform.python_version(), "r": r_version},
        "cases": records,
        "degenerate": degenerate,
        "untiedApproximationError": untied,
        "monteCarlo": mc,
        "zar1984": zar_section(),
    }
    text = json.dumps(payload, indent=1, sort_keys=True) + "\n"
    OUTPUT.write_text(text)
    print(f"// wrote {OUTPUT.name}, sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
