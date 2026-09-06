#!/usr/bin/env python3
"""Reference values for the Bayesian ICC.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_bayesian_icc.py

## A sampler cannot be checked draw by draw

`bayesianICC` is a Gibbs sampler. Two implementations of the same posterior will produce
entirely different sequences of draws even from the same seed, because the draws depend on
the order and parameterisation of every conditional and on the underlying generator. There
is nothing to compare element-wise.

What *can* be checked is the distribution it converges to, and there the Bayesian and
frequentist estimators have a known relationship: **with vague priors and adequate data
the posterior mean of each variance component approaches the ANOVA estimate.** That is not
an approximation anyone chose — it is what "vague prior" means. So a sampler targeting the
wrong posterior, or one whose conditionals are mis-derived, shows up as a systematic gap
from the frequentist answer that does not close as the data grows.

This fixture therefore records the **frequentist** decomposition, computed independently
in Python from the two-way ANOVA:

    sigma_subjects^2 = (MS_subjects - MS_error) / k
    sigma_raters^2   = (MS_raters   - MS_error) / n
    sigma_error^2    =  MS_error

    ICC(2,1) absolute    = s_subj / (s_subj + s_rater + s_err)
    ICC(3,1) consistency = s_subj / (s_subj + s_err)

The mean squares come from statsmodels' `anova_lm`, the same external implementation the
G-study fixture uses, so the frequentist side is itself oracle-backed rather than being a
second opinion of unknown quality.

## Designs are sized so the comparison is meaningful

A posterior mean equals an ANOVA estimate only in the limit. On a small, noisy design the
prior still has a say and the two legitimately differ, so asserting agreement there would
be asserting something untrue. Each case records the design size alongside the estimate,
and the large ones are where the tight comparison belongs.
"""

import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels
import statsmodels.api as sm
from statsmodels.formula.api import ols

OUTPUT = (Path(__file__).resolve().parents[2]
          / "Tests" / "BusinessMathTests" / "Fixtures" / "bayesianICC.json")


def mean_squares(data):
    n, k = data.shape
    frame = pd.DataFrame({
        "score": data.ravel(),
        "subject": np.repeat(np.arange(n), k).astype(str),
        "rater": np.tile(np.arange(k), n).astype(str),
    })
    model = ols("score ~ C(subject) + C(rater)", data=frame).fit()
    table = sm.stats.anova_lm(model, typ=2)
    ms_s = table.loc["C(subject)", "sum_sq"] / table.loc["C(subject)", "df"]
    ms_r = table.loc["C(rater)", "sum_sq"] / table.loc["C(rater)", "df"]
    ms_e = table.loc["Residual", "sum_sq"] / table.loc["Residual", "df"]
    return float(ms_s), float(ms_r), float(ms_e)


def build_case(name, note, data, tight):
    data = np.asarray(data, float)
    n, k = data.shape
    ms_s, ms_r, ms_e = mean_squares(data)

    s_subj = max((ms_s - ms_e) / k, 0.0)
    s_rater = max((ms_r - ms_e) / n, 0.0)
    s_err = ms_e

    total_absolute = s_subj + s_rater + s_err
    total_consistency = s_subj + s_err

    return {
        "name": name,
        "note": note,
        # Whether this design is large enough for the posterior mean and the ANOVA
        # estimate to be expected to agree closely.
        "supportsTightComparison": tight,
        "ratings": [[float(v) for v in row] for row in data],
        "subjectCount": int(n),
        "raterCount": int(k),
        "meanSquares": {"subjects": ms_s, "raters": ms_r, "error": ms_e},
        "frequentist": {
            "sigmaSubjects": float(s_subj),
            "sigmaRaters": float(s_rater),
            "sigmaError": float(s_err),
            "iccAbsolute": float(s_subj / total_absolute) if total_absolute > 0 else 0.0,
            "iccConsistency": float(s_subj / total_consistency) if total_consistency > 0 else 0.0,
        },
    }


def simulated(n, k, subject_sd, rater_sd, error_sd, seed):
    r = np.random.default_rng(seed)
    subjects = r.normal(0, subject_sd, (n, 1))
    raters = r.normal(0, rater_sd, (1, k))
    error = r.normal(0, error_sd, (n, k))
    return 50 + subjects + raters + error


CASES = [
    ("highAgreement_large",
     "Sixty subjects, four raters, subject variance dominating. A high ICC on a design "
     "big enough that the prior should barely register.",
     simulated(60, 4, subject_sd=6.0, rater_sd=0.6, error_sd=1.2, seed=11), True),

    ("moderateAgreement_large",
     "Fifty subjects, five raters, subject and error variance comparable — the middle of "
     "the range, where an ICC is least determined by its bounds.",
     simulated(50, 5, subject_sd=2.5, rater_sd=0.8, error_sd=2.5, seed=12), True),

    ("lowAgreement_large",
     "Error swamping the subject effect: an ICC near zero, and the end of the range where "
     "a variance component is most likely to be clamped.",
     simulated(60, 4, subject_sd=0.8, rater_sd=0.5, error_sd=5.0, seed=13), True),

    ("raterEffect_large",
     "A strong rater effect as well. ICC(2,1) and ICC(3,1) diverge here, because only the "
     "first counts rater variance against agreement — a binding that confused the two "
     "would pass every case where raters agree.",
     simulated(50, 6, subject_sd=3.0, rater_sd=4.0, error_sd=1.5, seed=14), True),

    ("small_noisy",
     "Ten subjects, three raters. Too small for the posterior mean to have forgotten the "
     "prior, so the tight comparison does not apply — kept because the sampler must still "
     "produce a valid, bounded, reproducible answer on it.",
     simulated(10, 3, subject_sd=1.5, rater_sd=1.0, error_sd=2.0, seed=15), False),
]


def main() -> int:
    cases = [build_case(name, note, data, tight) for name, note, data, tight in CASES]

    payload = {
        "name": "bayesianICC",
        "reference": (f"statsmodels {statsmodels.__version__} anova_lm, via the "
                      f"frequentist variance decomposition"),
        "note": ("A Gibbs sampler cannot be compared draw by draw — two correct "
                 "implementations produce different sequences. What is checked is that "
                 "the posterior mean, under vague priors and adequate data, approaches "
                 "the ANOVA estimate, which is what a vague prior means. Cases marked "
                 "supportsTightComparison are large enough for that; the small one is "
                 "not, and is present to exercise validity and reproducibility only."),
        "cases": cases,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(cases)} designs")
    for c in cases:
        f = c["frequentist"]
        tight = "" if c["supportsTightComparison"] else "   (loose only)"
        print(f"  {c['name']:<26} {c['subjectCount']:>3}x{c['raterCount']:<2} "
              f"ICC(2,1)={f['iccAbsolute']:.4f} ICC(3,1)={f['iccConsistency']:.4f}{tight}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  statsmodels {statsmodels.__version__} · numpy {np.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
