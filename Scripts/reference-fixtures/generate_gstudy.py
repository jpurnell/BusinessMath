#!/usr/bin/env python3
"""Reference values for the one-facet generalizability study.

Run once; commit the output. CI never executes this.

    .venv/bin/python generate_gstudy.py

## The oracle, and why there are two of them

`gStudy` decomposes score variance into person, facet and residual components using the
expected mean squares of a two-way ANOVA without replication:

    sigma_e^2 = MS_error
    sigma_p^2 = (MS_persons - MS_error) / n_r
    sigma_r^2 = (MS_facet   - MS_error) / n_p

Two independent things can be wrong there: the ANOVA that produces the mean squares, and
the EMS algebra that turns them into variance components. So both are checked, by
different means.

**The mean squares** come from `statsmodels.formula.api.ols` with an additive two-factor
model, run through `anova_lm`. That is a genuine external implementation, and it does not
know what a G-study is.

**The variance components** are then computed here from those mean squares by the EMS
formulas above, written out directly. That part is arithmetic on three numbers, so a
transcription in a second language is a real check on it — the same reasoning as §2.2 of
the coverage proposal, where a closed form is its own reference.

Both are recorded, so a failure says which half is wrong rather than merely that something
is.

## The truncation, and why the fixture forces it

Negative variance estimates are truncated to zero, which is standard and is what makes the
result usable, but it is also where an implementation can differ invisibly: a component
that should be clamped and is not comes out negative, and a proportion computed from it is
nonsense. One design below is built so the facet component is genuinely negative before
truncation, so the clamp is exercised rather than assumed.
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
          / "Tests" / "BusinessMathTests" / "Fixtures" / "gStudy.json")


def mean_squares_via_statsmodels(data):
    """MS_persons, MS_facet and MS_error from an additive two-way ANOVA."""
    n_p, n_r = data.shape
    frame = pd.DataFrame({
        "score": data.ravel(),
        "person": np.repeat(np.arange(n_p), n_r).astype(str),
        "rater": np.tile(np.arange(n_r), n_p).astype(str),
    })
    model = ols("score ~ C(person) + C(rater)", data=frame).fit()
    table = sm.stats.anova_lm(model, typ=2)
    ms_p = table.loc["C(person)", "sum_sq"] / table.loc["C(person)", "df"]
    ms_r = table.loc["C(rater)", "sum_sq"] / table.loc["C(rater)", "df"]
    ms_e = table.loc["Residual", "sum_sq"] / table.loc["Residual", "df"]
    return float(ms_p), float(ms_r), float(ms_e)


def build_case(name, note, data):
    data = np.asarray(data, float)
    n_p, n_r = data.shape
    ms_p, ms_r, ms_e = mean_squares_via_statsmodels(data)

    # The EMS algebra, written out. Negative estimates truncate to zero.
    raw_person = (ms_p - ms_e) / n_r
    raw_facet = (ms_r - ms_e) / n_p
    sigma_p = max(raw_person, 0.0)
    sigma_r = max(raw_facet, 0.0)
    sigma_e = ms_e

    return {
        "name": name,
        "note": note,
        "data": [[float(v) for v in row] for row in data],
        "personCount": int(n_p),
        "raterCount": int(n_r),
        "meanSquares": {"persons": ms_p, "facet": ms_r, "error": ms_e},
        # Before truncation, so a test can tell a clamp from a coincidence.
        "rawComponents": {"persons": float(raw_person), "facet": float(raw_facet)},
        "components": {
            "persons": float(sigma_p),
            "facet": float(sigma_r),
            "residual": float(sigma_e),
        },
        "totalVariance": float(sigma_p + sigma_r + sigma_e),
        "facetWasTruncated": bool(raw_facet < 0),
        "personWasTruncated": bool(raw_person < 0),
    }


rng = np.random.default_rng(20260906)


def simulated(n_p, n_r, person_sd, rater_sd, error_sd, seed):
    r = np.random.default_rng(seed)
    persons = r.normal(0, person_sd, (n_p, 1))
    raters = r.normal(0, rater_sd, (1, n_r))
    error = r.normal(0, error_sd, (n_p, n_r))
    return 50 + persons + raters + error


CASES = [
    ("handCheckable", "A small integer table. Every mean square can be worked out on "
                      "paper, so a disagreement here is arithmetic rather than anything "
                      "subtle.",
     [[4.0, 6.0, 8.0], [5.0, 7.0, 9.0], [3.0, 5.0, 7.0], [6.0, 8.0, 10.0]]),

    ("personDominant", "Large differences between persons, small between raters — the "
                       "usual shape of a reliable instrument.",
     simulated(20, 4, person_sd=5.0, rater_sd=0.5, error_sd=1.0, seed=1)),

    ("raterDominant", "Raters differ far more than persons do: a facet component that "
                      "should dominate. If persons and facet were transposed, this is "
                      "where it would show.",
     simulated(12, 6, person_sd=0.5, rater_sd=4.0, error_sd=1.0, seed=2)),

    ("noisy", "Error swamping both effects, so both components come out small.",
     simulated(15, 5, person_sd=1.0, rater_sd=1.0, error_sd=6.0, seed=3)),

    ("negativeFacet", "Built so the facet component is negative before truncation and "
                      "must be clamped to zero. Raters are identical by construction, so "
                      "MS_facet lands below MS_error on noise alone.",
     50 + np.random.default_rng(4).normal(0, 3, (10, 4))
        + np.zeros((1, 4))),

    ("twoByTwo", "The smallest design the function accepts. One degree of freedom "
                 "everywhere, which is where a df of zero would surface as a division.",
     [[10.0, 12.0], [14.0, 15.0]]),
]


def main() -> int:
    cases = [build_case(name, note, data) for name, note, data in CASES]

    payload = {
        "name": "gStudy",
        "reference": (f"statsmodels {statsmodels.__version__} anova_lm for the mean "
                      f"squares; the EMS algebra written out directly"),
        "note": ("Two oracles, because two independent things can be wrong: the ANOVA "
                 "producing the mean squares, and the expected-mean-square algebra "
                 "turning them into variance components. `meanSquares` comes from "
                 "statsmodels, which does not know what a G-study is; `components` is "
                 "the EMS arithmetic on those numbers. `rawComponents` is recorded "
                 "before truncation so a clamp can be told from a coincidence."),
        "cases": cases,
    }

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUTPUT.write_text(text)

    print(f"{OUTPUT.name}: {len(cases)} designs")
    for c in cases:
        comp = c["components"]
        flag = "  (facet truncated)" if c["facetWasTruncated"] else ""
        print(f"  {c['name']:<16} {c['personCount']:>3}x{c['raterCount']:<2} "
              f"person={comp['persons']:8.4f} facet={comp['facet']:8.4f} "
              f"residual={comp['residual']:8.4f}{flag}")
    print(f"  sha256 {hashlib.sha256(text.encode()).hexdigest()}")
    print(f"  statsmodels {statsmodels.__version__} · numpy {np.__version__} · "
          f"python {platform.python_version()}")
    print(f"  generated {datetime.now(timezone.utc).isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
