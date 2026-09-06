#!/usr/bin/env python3
"""Reference values for the Excel functions this package already computes.

The coverage matrix marks 86 Excel functions **bindable**: BusinessMath computes the
quantity, and no formula can reach it. That also means none of them has ever been
compared to a spreadsheet — they were checked against their own definitions, which is
exactly how `DayCountConvention.thirty360` shipped for months missing the NASD February
rule.

This generates the other side of that comparison. Same machinery as
`generate_excel_financial.py`: a flat-ODS with formulas and no cached values, evaluated
headless by LibreOffice, read back at about fifteen significant digits.

    python3 generate_excel_bindable.py

Dotted Excel names need ODF's namespaced spelling — `COM.MICROSOFT.T.DIST`, not
`T.DIST`, which silently yields nothing. Where a legacy name exists it is *not*
interchangeable: `TDIST` is the two-tailed survival function and `T.DIST` is the
left-tail CDF, so they disagree by construction.
"""

import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

OUT = (Path(__file__).resolve().parents[2]
       / "Tests" / "BusinessMathTests" / "Fixtures" / "excelBindable.json")

# Anscombe's quartet, set I. Chosen because `StatisticsReferenceValidationTests`
# already validates against it, so a disagreement here is about the spreadsheet rather
# than about which numbers were fed in.
XS = [10, 8, 13, 9, 11, 14, 6, 4, 12, 7]
YS = [8.04, 6.95, 7.58, 8.81, 8.33, 9.96, 7.24, 4.26, 10.84, 4.82]

X_RANGE = "[.A1:.J1]"
Y_RANGE = "[.A2:.J2]"


def cases():
    """(excel function, formula, named arguments recorded in the fixture)."""
    out = []

    def add(fn, formula, named):
        out.append({"fn": fn, "formula": formula, "named": named})

    # ---- Distributions, scalar arguments ----
    for x in [-2.5, -0.5, 0.0, 1.5, 3.0]:
        add("NORM.DIST", f"COM.MICROSOFT.NORM.DIST({x};2;3;1)",
            {"x": x, "mean": 2, "stdDev": 3})
    for p in [0.001, 0.025, 0.5, 0.975, 0.999]:
        add("NORM.INV", f"COM.MICROSOFT.NORM.INV({p};2;3)",
            {"p": p, "mean": 2, "stdDev": 3})
    for df in [1, 5, 8, 30]:
        for x in [-2.0, -0.5, 1.5]:
            add("T.DIST", f"COM.MICROSOFT.T.DIST({x};{df};1)", {"x": x, "df": df})
        for p in [0.025, 0.5, 0.975]:
            add("T.INV", f"COM.MICROSOFT.T.INV({p};{df})", {"p": p, "df": df})
    for (d1, d2) in [(5, 9), (1, 10), (20, 3)]:
        for x in [0.5, 2.5, 6.0]:
            add("F.DIST", f"COM.MICROSOFT.F.DIST({x};{d1};{d2};1)",
                {"x": x, "df1": d1, "df2": d2})
        for p in [0.05, 0.5, 0.95]:
            add("F.INV", f"COM.MICROSOFT.F.INV({p};{d1};{d2})",
                {"p": p, "df1": d1, "df2": d2})
    for df in [1, 5, 11]:
        for x in [0.5, 3.5, 12.0]:
            add("CHISQ.DIST", f"COM.MICROSOFT.CHISQ.DIST({x};{df};1)", {"x": x, "df": df})
    for (a, b) in [(2, 5), (0.5, 0.5), (5, 2)]:
        for x in [0.1, 0.4, 0.9]:
            add("BETA.DIST", f"BETADIST({x};{a};{b})", {"x": x, "a": a, "b": b})
    for (k, n, p) in [(3, 10, 0.3), (0, 5, 0.5), (5, 5, 0.5), (7, 20, 0.25)]:
        add("BINOM.DIST", f"BINOMDIST({k};{n};{p};0)", {"k": k, "n": n, "p": p})
    for (k, mean) in [(0, 2.5), (4, 2.5), (10, 7.0)]:
        add("POISSON.DIST", f"POISSON({k};{mean};1)", {"k": k, "mean": mean})
    for (x, n, M, N) in [(2, 5, 10, 50), (0, 3, 5, 20), (3, 6, 12, 30)]:
        add("HYPGEOM.DIST", f"HYPGEOMDIST({x};{n};{M};{N})",
            {"x": x, "draws": n, "successes": M, "population": N})
    for x in [0.5, 1.5, 4.0]:
        add("LOGNORM.DIST", f"LOGNORMDIST({x};0.5;0.75)",
            {"x": x, "mean": 0.5, "stdDev": 0.75})
    for x in [0.1, 0.8, 3.0]:
        add("EXPON.DIST", f"EXPONDIST({x};2.5;1)", {"x": x, "lambda": 2.5})
    for x in [-0.9, -0.25, 0.0, 0.5, 0.95]:
        add("FISHER", f"FISHER({x})", {"x": x})

    # ---- Descriptive statistics and regression, over the dataset ----
    add("CORREL", f"CORREL({X_RANGE};{Y_RANGE})", {})
    add("RSQ", f"RSQ({Y_RANGE};{X_RANGE})", {})
    add("SLOPE", f"SLOPE({Y_RANGE};{X_RANGE})", {})
    add("INTERCEPT", f"INTERCEPT({Y_RANGE};{X_RANGE})", {})
    add("SKEW", f"SKEW({X_RANGE})", {})
    add("KURT", f"KURT({X_RANGE})", {})
    add("GEOMEAN", f"GEOMEAN({X_RANGE})", {})
    add("HARMEAN", f"HARMEAN({X_RANGE})", {})
    add("DEVSQ", f"DEVSQ({X_RANGE})", {})
    add("STDEV.S", f"COM.MICROSOFT.STDEV.S({X_RANGE})", {})
    add("STDEV.P", f"COM.MICROSOFT.STDEV.P({X_RANGE})", {})
    add("VAR.S", f"COM.MICROSOFT.VAR.S({X_RANGE})", {})
    add("VAR.P", f"COM.MICROSOFT.VAR.P({X_RANGE})", {})
    add("COVARIANCE.P", f"COM.MICROSOFT.COVARIANCE.P({X_RANGE};{Y_RANGE})", {})
    add("COVARIANCE.S", f"COM.MICROSOFT.COVARIANCE.S({X_RANGE};{Y_RANGE})", {})
    add("AVERAGE", f"AVERAGE({X_RANGE})", {})
    add("MEDIAN", f"MEDIAN({X_RANGE})", {})
    for p in [0.1, 0.25, 0.5, 0.75, 0.9]:
        add("PERCENTILE.INC", f"COM.MICROSOFT.PERCENTILE.INC({X_RANGE};{p})", {"p": p})
    for (n, k) in [(10, 3), (5, 5), (52, 2)]:
        add("PERMUT", f"PERMUT({n};{k})", {"n": n, "k": k})
    add("STANDARDIZE", "STANDARDIZE(11;10;3.2041639575198)",
        {"x": 11, "mean": 10, "stdDev": 3.2041639575198})

    # ---- Prediction, ranking and confidence ----
    for at in [3, 7.5, 15]:
        add("TREND", f"TREND({Y_RANGE};{X_RANGE};{at})", {"x": at})
        add("GROWTH", f"GROWTH({Y_RANGE};{X_RANGE};{at})", {"x": at})
    add("LOGEST.BASE", f"INDEX(LOGEST({Y_RANGE};{X_RANGE});1;1)", {})
    add("LOGEST.COEFFICIENT", f"INDEX(LOGEST({Y_RANGE};{X_RANGE});1;2)", {})
    add("LINEST.SLOPE", f"INDEX(LINEST({Y_RANGE};{X_RANGE});1;1)", {})
    add("LINEST.INTERCEPT", f"INDEX(LINEST({Y_RANGE};{X_RANGE});1;2)", {})
    for alpha in [0.01, 0.05, 0.10]:
        add("CONFIDENCE.NORM",
            f"COM.MICROSOFT.CONFIDENCE.NORM({alpha};3.2041639575198;10)", {"alpha": alpha})
    for value in [4, 7, 10, 11, 14]:
        add("RANK.EQ", f"COM.MICROSOFT.RANK.EQ({value};{X_RANGE};0)", {"at": value})
        add("RANK.AVG", f"COM.MICROSOFT.RANK.AVG({value};{X_RANGE};0)", {"at": value})
        add("RANK.EQ.ASC", f"COM.MICROSOFT.RANK.EQ({value};{X_RANGE};1)", {"at": value})
        add("PERCENTRANK.INC", f"COM.MICROSOFT.PERCENTRANK.INC({X_RANGE};{value})", {"at": value})

    return out


def evaluate(entries):
    def data_row(values):
        return ("<table:table-row>" + "".join(
            f'<table:table-cell office:value-type="float" office:value="{v}"/>'
            for v in values) + "</table:table-row>")

    rows = data_row(XS) + data_row(YS) + "".join(
        '<table:table-row><table:table-cell table:formula="of:=IFERROR(TEXT({};'
        '&quot;0.000000000000000E+00&quot;);&quot;ERR&quot;)" '
        'office:value-type="string"/></table:table-row>'.format(e["formula"])
        for e in entries)

    document = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" '
        'office:mimetype="application/vnd.oasis.opendocument.spreadsheet">'
        '<office:body><office:spreadsheet><table:table table:name="Sheet1">'
        + rows +
        '</table:table></office:spreadsheet></office:body></office:document>')

    with tempfile.TemporaryDirectory() as work:
        source = Path(work) / "bindable.fods"
        source.write_text(document)
        result = subprocess.run(
            ["soffice", "--headless", "--calc",
             f"-env:UserInstallation=file://{Path(work) / 'profile'}",
             "--convert-to", "fods", "--outdir", work, str(source)],
            capture_output=True, text=True)
        produced = Path(work) / "bindable.fods"
        if not produced.exists():
            sys.exit(f"LibreOffice produced nothing:\n{result.stdout}\n{result.stderr}")
        computed = produced.read_text()

    values = re.findall(r'office:string-value="([^"]*)"', computed)
    if len(values) != len(entries):
        sys.exit(f"expected {len(entries)} values, read {len(values)}")

    failed = [e["formula"] for e, v in zip(entries, values) if v in ("ERR", "")]
    if failed:
        sys.exit("LibreOffice could not evaluate:\n  " + "\n  ".join(failed))
    return [float(v) for v in values]


def main():
    if shutil.which("soffice") is None:
        sys.exit("soffice not on PATH — install LibreOffice to regenerate this fixture")

    entries = cases()
    values = evaluate(entries)

    names = sorted({e["fn"] for e in entries})
    payload_cases = []
    for entry, value in zip(entries, values):
        payload_cases.append({**entry["named"], "value": value,
                              "function": float(names.index(entry["fn"]))})
    # The dataset travels with the fixture so both sides cannot drift apart.
    for index, (x, y) in enumerate(zip(XS, YS)):
        payload_cases.append({"index": float(index), "x": float(x), "y": y,
                              "value": 0.0, "function": float(names.index("DATASET"))
                              if "DATASET" in names else float(len(names))})
    names = names + ["DATASET"]

    version = subprocess.run(["soffice", "--version"], capture_output=True,
                             text=True).stdout.strip()
    payload = {
        "name": "excelBindable",
        "reference": f"LibreOffice Calc ({version})",
        "note": "Excel functions this package already computes but which no formula "
                "could reach, and which had therefore never been compared to a "
                "spreadsheet. The dataset is Anscombe's quartet set I and travels with "
                "the fixture under the DATASET marker, so the two sides cannot drift.",
        "functionOrder": names,
        "cases": payload_cases,
    }

    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUT.write_text(text)
    print(version)
    counts = {}
    for entry in entries:
        counts[entry["fn"]] = counts.get(entry["fn"], 0) + 1
    for fn in sorted(counts):
        print(f"  {fn:<16} {counts[fn]:>3}")
    print(f"\n{len(payload_cases)} cases → {OUT.name}  "
          f"sha256 {hashlib.sha256(text.encode()).hexdigest()[:16]}…")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
