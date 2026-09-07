#!/usr/bin/env python3
"""Reference values for the post-hoc ANOVA tests, from SciPy and statsmodels.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_posthoc.py

## What needs an oracle

`PostHocTests` has 30 tests. They check that a p-value lies in [0, 1], that a test
statistic is non-negative, that a method reports its own name, that the count of
comparisons is `k(k-1)/2`, and that at least one comparison comes out significant
on obviously separated data. Every one of those holds for a wrong implementation.

Not one p-value or critical value is pinned to a number, and the three methods
differ *only* in how they set that number:

- **Bonferroni** multiplies the raw two-sample t p-value by the number of
  comparisons, using the pooled MSE and the ANOVA's error degrees of freedom —
  not each pair's own variance and df.
- **Scheffé** refers `F = d² / (MSE·(1/nᵢ + 1/nⱼ)·(k-1))` to `F(k-1, dfError)`.
  The `(k-1)` factor is what makes it the most conservative of the three; without
  it the test is simply an unadjusted F.
- **Tukey** uses the **studentized range** distribution, which has no closed form
  and is the one people substitute a t or a normal for. At k = 3, df = 27 the
  Tukey critical difference is q₀.₀₅,₃,₂₇/√2 = 2.479 standard errors against a
  t₀.₉₇₅,₂₇ of 2.052 — a 21% difference. Both "look like" critical values.

Each case below is sized so those three answers separate, and the group counts
are varied because the gap between the studentized range and a t grows with k.

Tukey comes from `scipy.stats.tukey_hsd`, which evaluates the studentized range
directly; Bonferroni and Scheffé are computed here from `scipy.stats.t` and
`scipy.stats.f` against the pooled ANOVA quantities, which is their definition.
`statsmodels.pairwise_tukeyhsd` is recorded alongside as a second opinion on the
Tukey column.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from itertools import combinations
from pathlib import Path

import numpy as np
import scipy
import statsmodels
from scipy import stats
from statsmodels.stats.multicomp import pairwise_tukeyhsd

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "postHoc.json")

ALPHA = 0.05


def anova_quantities(groups):
    """MSE and error degrees of freedom, the pooled terms all three methods share."""
    k = len(groups)
    n_total = sum(len(g) for g in groups)
    df_error = n_total - k
    ss_within = sum(((np.asarray(g) - np.mean(g)) ** 2).sum() for g in groups)
    mse = ss_within / df_error

    grand = np.concatenate([np.asarray(g) for g in groups]).mean()
    ss_between = sum(len(g) * (np.mean(g) - grand) ** 2 for g in groups)
    df_between = k - 1
    f_stat = (ss_between / df_between) / mse
    return {
        "mse": float(mse),
        "dfError": int(df_error),
        "dfBetween": int(df_between),
        "fStatistic": float(f_stat),
        "fPValue": float(stats.f.sf(f_stat, df_between, df_error)),
    }


def build_case(name, note, groups):
    groups = [list(map(float, g)) for g in groups]
    k = len(groups)
    q = anova_quantities(groups)
    mse, df_error = q["mse"], q["dfError"]
    means = [float(np.mean(g)) for g in groups]

    # SciPy's Tukey, which evaluates the studentized range distribution.
    tukey = stats.tukey_hsd(*[np.asarray(g) for g in groups])

    # statsmodels' independent implementation, keyed by pair for a second opinion.
    flat = np.concatenate([np.asarray(g) for g in groups])
    labels = np.concatenate([[i] * len(g) for i, g in enumerate(groups)])
    sm = pairwise_tukeyhsd(flat, labels, alpha=ALPHA)
    sm_by_pair = {}
    for row in sm.summary().data[1:]:
        sm_by_pair[(int(row[0]), int(row[1]))] = float(row[3])

    comparisons = []
    for a, b in combinations(range(k), 2):
        diff = means[a] - means[b]
        standard_error = float(np.sqrt(mse * (1.0 / len(groups[a]) + 1.0 / len(groups[b]))))

        # Bonferroni: the raw t against the POOLED variance and the ANOVA's df,
        # then multiplied by the number of comparisons and capped at 1.
        t_stat = diff / standard_error
        raw_p = float(2 * stats.t.sf(abs(t_stat), df_error))
        bonferroni_p = min(1.0, raw_p * (k * (k - 1) // 2))

        # Scheffé: an F on (k-1, dfError), with the (k-1) that makes it conservative.
        scheffe_f = (diff ** 2) / (mse * (1.0 / len(groups[a]) + 1.0 / len(groups[b])) * (k - 1))
        scheffe_p = float(stats.f.sf(scheffe_f, k - 1, df_error))

        # Tukey: q = |d| / sqrt(MSE/2 · (1/nᵢ + 1/nⱼ)) referred to the studentized
        # range. The factor of two beside MSE is the difference between the
        # studentized range's scale and a t's, and is easy to drop.
        tukey_se = float(np.sqrt((mse / 2.0) * (1.0 / len(groups[a]) + 1.0 / len(groups[b]))))
        q_stat = abs(diff) / tukey_se
        tukey_p = float(tukey.pvalue[a, b])

        comparisons.append({
            "groupA": a,
            "groupB": b,
            "meanDifference": float(diff),
            "standardError": standard_error,
            "bonferroni": {"tStatistic": float(t_stat), "rawPValue": raw_p,
                           "pValue": bonferroni_p, "isSignificant": bonferroni_p < ALPHA},
            "scheffe": {"fStatistic": float(scheffe_f), "pValue": scheffe_p,
                        "isSignificant": scheffe_p < ALPHA},
            "tukey": {"qStatistic": float(q_stat), "pValue": tukey_p,
                      "isSignificant": tukey_p < ALPHA,
                      "statsmodelsPValue": sm_by_pair.get((a, b))},
        })

    # How far apart a studentized-range critical value and a t critical value are
    # for this design, recorded so the test can assert the case is discriminating.
    q_critical = float(stats.studentized_range.ppf(1 - ALPHA, k, df_error))
    t_critical = float(stats.t.ppf(1 - ALPHA / 2, df_error))
    return {
        "name": name,
        "note": note,
        "groups": groups,
        "groupCount": k,
        "balanced": len({len(g) for g in groups}) == 1,
        "alpha": ALPHA,
        "anova": q,
        "means": means,
        "tukeyCriticalInStandardErrors": q_critical / np.sqrt(2),
        "tCriticalInStandardErrors": t_critical,
        "comparisons": comparisons,
    }


def cases():
    r = np.random.default_rng(71)
    out = []

    out.append(build_case(
        "threeGroupsClearlySeparated",
        "Three balanced groups of ten with means far apart. Every method should "
        "find every pair significant, so this case pins the p-values rather than "
        "the verdicts — a wrong critical value still gets the verdicts right here.",
        [r.normal(10, 2, 10), r.normal(20, 2, 10), r.normal(30, 2, 10)]))

    out.append(build_case(
        "threeGroupsNoRealDifference",
        "Three balanced groups drawn from one distribution. The verdicts agree "
        "(nothing significant) and the p-values do not, which is where the "
        "methods can be told apart.",
        [r.normal(50, 5, 12), r.normal(50, 5, 12), r.normal(50, 5, 12)]))

    out.append(build_case(
        "threeGroupsMarginal",
        "Separation near the decision boundary, so the three methods disagree on "
        "the verdict and not merely the number. This is the case a t-for-q "
        "substitution fails outright: Tukey's critical difference is 21% wider "
        "than a t's at this k and df.",
        [r.normal(20, 3, 9) + 0.0, r.normal(23, 3, 9) + 0.0, r.normal(24.5, 3, 9) + 0.0]))

    out.append(build_case(
        "unbalancedGroups",
        "Group sizes 6, 12 and 20. Tukey becomes Tukey-Kramer here, using each "
        "pair's own harmonic term rather than a single common one; an "
        "implementation that assumes balance is wrong only off the diagonal of "
        "the size table.",
        [r.normal(15, 4, 6), r.normal(19, 4, 12), r.normal(17, 4, 20)]))

    out.append(build_case(
        "fiveGroupsManyComparisons",
        "Five groups make ten comparisons, so Bonferroni multiplies by ten and "
        "the gap between the studentized range and a t is at its widest. The "
        "three methods are furthest apart here.",
        [r.normal(100, 8, 10), r.normal(104, 8, 10), r.normal(97, 8, 10),
         r.normal(112, 8, 10), r.normal(101, 8, 10)]))

    out.append(build_case(
        "twoGroupsDegenerate",
        "Two groups: one comparison, so Bonferroni's multiplier is 1 and its "
        "adjusted p-value must equal the raw pooled t p-value exactly. Scheffé "
        "with k-1 = 1 reduces to the same test, and F = t². A boundary where all "
        "three should coincide.",
        [r.normal(30, 5, 15), r.normal(36, 5, 15)]))

    out.append(build_case(
        "unequalVariancesPooled",
        "Group variances differing by a factor of nine. All three methods pool "
        "regardless — that is their shared assumption, not a defect — so this "
        "case pins what pooling actually produces rather than letting a "
        "per-pair variance slip in unnoticed.",
        [r.normal(40, 1, 10), r.normal(44, 3, 10), r.normal(42, 9, 10)]))

    return out


def main() -> int:
    built = cases()
    payload = {
        "name": "postHoc",
        "reference": (f"scipy {scipy.__version__} tukey_hsd / t / f / studentized_range, "
                      f"statsmodels {statsmodels.__version__} pairwise_tukeyhsd"),
        "note": ("The three methods differ only in the reference distribution they "
                 "use, and the existing suite pins none of them. Tukey's studentized "
                 "range is the one with no closed form and the one a t or normal is "
                 "substituted for; the designs vary k because that gap widens with "
                 "the number of groups."),
        "alpha": ALPHA,
        "cases": built,
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(built)} designs")
    for c in built:
        ratio = c["tukeyCriticalInStandardErrors"] / c["tCriticalInStandardErrors"]
        print(f"  {c['name']:<28} k={c['groupCount']} df={c['anova']['dfError']:>3} "
              f"pairs={len(c['comparisons']):>2} q/√2={c['tukeyCriticalInStandardErrors']:.3f} "
              f"t={c['tCriticalInStandardErrors']:.3f} (x{ratio:.2f})")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  python {platform.python_version()} · {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
