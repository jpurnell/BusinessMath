#!/usr/bin/env python3
"""Reference values for the tie-corrected concordance tests, from SciPy and R.

Run by hand; paste the printed Swift cases into ConcordanceReferenceTests.swift.
CI never executes this, and the tests do not need Python or R.

    .venv/bin/python generate_concordance.py            # SciPy and R (if Rscript is on PATH)
    R_LIBS_USER=... .venv/bin/python generate_concordance.py

## What needs an oracle

`concordanceAnalysis` reports Kendall's W corrected for tied ranks,
`W = 12 S / (m^2 (n^3 - n) - m * sum(t^3 - t))`, and a chi-squared of `m (n - 1) W`.
Untied data agrees under the corrected and uncorrected formulas alike and proves
nothing, so every case but the control has ties within judges: a tied pair, a
three-way tie, a judge who ties everything, ties in every judge, and a panel the
size of the 1976 Judgment of Paris (11 judges x 10 wines) built from integer scores,
where ties are the norm.

The references:

- SciPy `scipy.stats.friedmanchisquare(*items)` — tie-corrected Friedman chi-squared
  and its p-value. W is recovered as `chi2 / (m (n - 1))`.
- R `friedman.test(judges x items matrix)` — tie-corrected Friedman chi-squared and p.
- R `irr::kendall(t(matrix), correct = TRUE)` — tie-corrected W, its chi-squared and p.

The cases live in concordance_cases.txt so that both tools read exactly the same data.
"""

import platform
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
import scipy
from scipy import stats

HERE = Path(__file__).resolve().parent
CASES = HERE / "concordance_cases.txt"
R_SCRIPT = HERE / "generate_concordance.R"


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


def run_r():
    rscript = shutil.which("Rscript")
    if rscript is None:
        return None, None
    version = subprocess.run([rscript, "--version"], capture_output=True, text=True)
    out = subprocess.run([rscript, str(R_SCRIPT), str(CASES)],
                         capture_output=True, text=True, check=True)
    values = {}
    for line in out.stdout.splitlines():
        name, *nums = line.split("\t")
        values[name] = [float(v) for v in nums]
    return (version.stdout or version.stderr).strip(), values


def swift_row(row):
    return "[" + ", ".join(repr(float(v)) for v in row) + "]"


def main():
    cases = read_cases(CASES)
    r_version, r_values = run_r()
    print(f"// SciPy {scipy.__version__}, NumPy {np.__version__}, Python {platform.python_version()}")
    print(f"// {r_version or 'R not available'}")
    for name, values in cases:
        ranks = np.apply_along_axis(stats.rankdata, 1, values)
        m, n = ranks.shape
        sp = stats.friedmanchisquare(*ranks.T)
        sp_chi2, sp_p = float(sp.statistic), float(sp.pvalue)
        sp_w = sp_chi2 / (m * (n - 1))
        r = r_values.get(name) if r_values else None
        print(f"// {name}")
        print(f"//   scipy chi2={sp_chi2!r} p={sp_p!r} W={sp_w!r}")
        if r:
            print(f"//   R friedman chi2={r[0]!r} p={r[1]!r}; irr W={r[2]!r} chi2={r[3]!r} p={r[4]!r}")
        rows = ",\n                   ".join(swift_row(row) for row in ranks)
        print(f"ConcordanceCase(name: {name!r},".replace("'", '"'))
        print(f"    rankings: [{rows}],")
        print(f"    sciPyChiSquare: {sp_chi2!r}, sciPyPValue: {sp_p!r},")
        if r:
            print(f"    rChiSquare: {r[0]!r}, rPValue: {r[1]!r}, rW: {r[2]!r}),")
        else:
            print("    rChiSquare: nil, rPValue: nil, rW: nil),")
    return 0


if __name__ == "__main__":
    sys.exit(main())
