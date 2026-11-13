"""SciPy reference for wilsonInterval, medianAbsoluteDeviation and poissonSurvival.

    python3 -I generate_hub_statistics.py

The second, independent reference beside generate_hub_statistics.R (base R); the two share
no code with each other or with BusinessMath. The cases are the R script's, in the same order,
and each line is printed in the same layout so the two outputs can be diffed.

- Wilson: scipy.stats.binomtest(k, n).proportion_ci(confidence_level, method="wilson"), the
  score interval without continuity correction ("wilsoncc" is the corrected one).
- MAD: scipy.stats.median_abs_deviation(x) (raw) and scale="normal", which divides by
  norm.ppf(3/4) -- the exact constant. R's mad() rounds it to 1.4826; that column is
  computed here as 1.4826 * raw for the diff.
- Poisson upper tail P(X >= k): scipy.stats.poisson.sf(k - 1, lambda).
"""

from scipy import stats

WILSON = [(0, 10, 0.95), (1, 10, 0.95), (10, 10, 0.95), (0, 5, 0.95), (3, 1000, 0.95),
          (1, 1, 0.95), (50, 100, 0.95), (999, 1000, 0.95), (7, 20, 0.90), (7, 20, 0.99)]

MADS = {
    "outlier": [1, 2, 3, 4, 100],
    "even": [1, 2, 3, 4],
    "single": [7],
    "constant": [5, 5, 5],
    "signed": [-3.5, 2.25, 0, 10, -1, 4.75],
    "lowCounts": [0, 0, 1, 0, 2, 0, 0, 1, 0, 0, 0, 3, 0, 1],
    "overdispersed": [3, 8, 1, 12, 4, 0, 6, 15, 2, 5, 9, 1, 7, 3],
}

POISSON = [(0, 3), (0, 0), (1, 0), (1, 0.5), (3, 1), (5, 1), (5, 0.1), (10, 2), (8, 2), (12, 3),
           (15, 10), (20, 10), (25, 10), (1, 50), (20, 1), (30, 2), (40, 5), (60, 10),
           (900, 1000), (1000, 1000), (1100, 1000), (1200, 1000), (101000, 100000),
           (50, 0.001)]


def fmt(v: float) -> str:
    return f"{v:.17g}"


print("# wilson\tsuccesses\ttrials\tconfidence\tlower\tupper")
for k, n, c in WILSON:
    ci = stats.binomtest(k, n).proportion_ci(confidence_level=c, method="wilson")
    print("\t".join(["wilson", str(k), str(n), str(c), fmt(ci.low), fmt(ci.high)]))

print("# mad\tname\traw\tR1.4826\texact")
for name, x in MADS.items():
    raw = stats.median_abs_deviation(x)
    exact = stats.median_abs_deviation(x, scale="normal")
    print("\t".join(["mad", name, fmt(raw), fmt(1.4826 * raw), fmt(exact)]))

print("# poisson\tk\tlambda\tsurvival")
for k, lam in POISSON:
    print("\t".join(["poisson", str(k), str(lam), fmt(stats.poisson.sf(k - 1, lam))]))
