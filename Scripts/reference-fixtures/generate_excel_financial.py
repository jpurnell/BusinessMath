#!/usr/bin/env python3
"""Reference values for the Excel financial functions, computed by LibreOffice Calc.

`PROPOSAL_excel_function_coverage.md` §2.3 says these ten functions are defined by
what a spreadsheet computes, and asks for a workbook whose values are the oracle.
This is that workbook, built and evaluated rather than transcribed.

LibreOffice Calc implements the Excel-compatible forms of all of them. The script
writes a flat-ODS containing only formulas — no cached values, so Calc must evaluate
them — converts it back to flat-ODS, and reads the `office:value` attributes, which
carry about fifteen significant digits. Hence the 1e-12 relative tolerance on the
Swift side: the reference itself does not have more.

Run it when the case list changes; commit the JSON.

    python3 generate_excel_financial.py
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
       / "Tests" / "BusinessMathTests" / "Fixtures" / "excelFinancial.json")

# Excel's epoch for a date serial. 1900-01-01 is serial 1, and Excel's deliberate
# 1900-leap-year bug makes every date after 1900-02-28 one higher than a true count —
# which is why the dates below are given as serials rather than as dates: the serial
# is what the function actually receives, and it is unambiguous.
def serial(year, month, day):
    from datetime import date
    return (date(year, month, day) - date(1899, 12, 30)).days


def cases():
    """Every case, as (function, ordered args, named args for the fixture)."""
    out = []

    def add(fn, args, names, formula=None):
        entry = {"fn": fn, "args": args, "named": dict(zip(names, args))}
        if formula is not None:
            entry["formula"] = formula
        out.append(entry)

    # ---- SLN(cost, salvage, life) ----
    for a in [(10_000, 1_000, 5), (30_000, 7_500, 10), (1_000, 0, 3),
              (5_000, 5_000, 4), (2_750, 250, 27.5)]:
        add("SLN", a, ["cost", "salvage", "life"])

    # ---- SYD(cost, salvage, life, per) ----
    for life in [5, 10]:
        for per in range(1, life + 1):
            add("SYD", (30_000, 7_500, life, per), ["cost", "salvage", "life", "per"])
    add("SYD", (1_000, 0, 3, 3), ["cost", "salvage", "life", "per"])

    # ---- DDB(cost, salvage, life, period, factor) ----
    # Periods 1…life only: Excel rejects a period beyond the asset's life, and so does
    # this package. That rejection is asserted as a thrown error rather than a value.
    for factor in [1, 1.5, 2, 3]:
        for period in range(1, 6):
            add("DDB", (10_000, 1_000, 5, period, factor),
                ["cost", "salvage", "life", "period", "factor"])
    # Salvage reached early, so the cap binds.
    for period in range(1, 6):
        add("DDB", (10_000, 9_000, 5, period, 2),
            ["cost", "salvage", "life", "period", "factor"])

    # ---- VDB(cost, salvage, life, start, end, factor, no_switch) ----
    for no_switch in [0, 1]:
        for start, end in [(0, 1), (0, 5), (1, 3), (3, 5), (0, 2.5), (1.5, 3.5), (4, 5)]:
            add("VDB", (10_000, 1_000, 5, start, end, 2, no_switch),
                ["cost", "salvage", "life", "start", "end", "factor", "noSwitch"])
    add("VDB", (2_400, 300, 10, 0, 1, 1.5, 0),
        ["cost", "salvage", "life", "start", "end", "factor", "noSwitch"])

    # ---- PDURATION(rate, pv, fv) ----
    for a in [(0.025, 2_000, 2_200), (0.1, 1_000, 2_000), (0.005, 500, 501),
              (0.07, 10_000, 100_000)]:
        add("PDURATION", a, ["rate", "pv", "fv"])

    # ---- NOMINAL(effect_rate, npery) ----
    for a in [(0.053543, 4), (0.1, 12), (0.05, 1), (0.2, 365), (0.01, 2)]:
        add("NOMINAL", a, ["effectRate", "periodsPerYear"])

    # ---- NPER(rate, pmt, pv, fv, type) ----
    for kind in [0, 1]:
        for a in [(0.12 / 12, -100, -1_000, 10_000), (0.005, -250, 20_000, 0),
                  (0.08, -1_000, 5_000, 0), (0.0, -500, 10_000, 0)]:
            add("NPER", a + (kind,), ["rate", "pmt", "pv", "fv", "type"])

    # ---- RATE(nper, pmt, pv, fv, type) ----
    for kind in [0, 1]:
        for a in [(48, -200, 8_000, 0), (10, -1_000, 7_000, 0),
                  (360, -1_500, 250_000, 0), (5, -100, 0, 600)]:
            add("RATE", a + (kind,), ["nper", "pmt", "pv", "fv", "type"])

    # ---- XNPV / XIRR, on a fixed irregular schedule ----
    schedule = [(2024, 1, 1), (2024, 3, 15), (2024, 7, 1), (2025, 1, 10), (2026, 2, 28)]
    flows = [-10_000, 2_750, 4_250, 3_250, 2_950]
    dates = ";".join(str(serial(*d)) for d in schedule)
    amounts = ";".join(str(float(f)) for f in flows)
    for rate in [0.05, 0.09, 0.15]:
        add("XNPV", (rate,), ["rate"],
            formula=f"XNPV({rate};{{{amounts}}};{{{dates}}})")
    add("XIRR", (), [], formula=f"XIRR({{{amounts}}};{{{dates}}})")

    # ---- MIRR ----
    for (finance, reinvest) in [(0.10, 0.12), (0.05, 0.05), (0.08, 0.14)]:
        add("MIRR", (finance, reinvest), ["financeRate", "reinvestRate"],
            formula=f"MIRR({{-10000;2750;4250;3250;2950}};{finance};{reinvest})")

    # ---- CUMIPMT / CUMPRINC ----
    for (start, end) in [(1, 12), (13, 24), (1, 360), (350, 360)]:
        for kind in [0, 1]:
            add("CUMIPMT", (0.075 / 12, 360, 200_000, start, end, kind),
                ["rate", "nper", "pv", "start", "end", "type"],
                formula=f"CUMIPMT({0.075/12};360;200000;{start};{end};{kind})")
            add("CUMPRINC", (0.075 / 12, 360, 200_000, start, end, kind),
                ["rate", "nper", "pv", "start", "end", "type"],
                formula=f"CUMPRINC({0.075/12};360;200000;{start};{end};{kind})")

    # ---- EFFECT / RRI ----
    for (nominal, periods) in [(0.0525, 4), (0.10, 12), (0.05, 1), (0.20, 365)]:
        add("EFFECT", (nominal, periods), ["nominalRate", "periodsPerYear"],
            formula=f"EFFECT({nominal};{periods})")
    for (n, pv, fv) in [(96, 10_000, 11_000), (10, 1_000, 2_000), (4, 500, 400)]:
        add("RRI", (n, pv, fv), ["periods", "pv", "fv"],
            formula=f"RRI({n};{pv};{fv})")

    # ---- YEARFRAC(start, end, basis) ----
    # Every basis across a grid chosen to separate the conventions rather than to
    # exercise them: within a year, spanning a leap February, exactly one year, several
    # years, and month ends — which is where 30/360's two variants part company and
    # where basis 1's denominator rule changes.
    spans = [
        ((2025, 1, 1), (2025, 7, 1)),      ((2025, 3, 1), (2025, 5, 1)),
        ((2025, 6, 15), (2026, 1, 15)),    ((2024, 1, 1), (2024, 7, 1)),
        ((2024, 2, 1), (2024, 3, 1)),      ((2023, 12, 1), (2024, 3, 1)),
        ((2024, 3, 1), (2025, 2, 1)),      ((2024, 1, 1), (2025, 1, 1)),
        ((2023, 1, 1), (2024, 1, 1)),      ((2023, 7, 1), (2024, 7, 1)),
        ((2023, 1, 1), (2026, 1, 1)),      ((2020, 3, 15), (2025, 9, 15)),
        ((1998, 1, 15), (2006, 8, 15)),    ((2023, 11, 30), (2024, 3, 31)),
        ((2024, 1, 31), (2024, 2, 29)),    ((2023, 8, 31), (2024, 2, 29)),
        ((2026, 1, 15), (2026, 3, 31)),    ((2026, 1, 30), (2026, 3, 31)),
        ((2026, 1, 31), (2026, 2, 28)),    ((2025, 8, 31), (2026, 2, 28)),
        ((2026, 2, 28), (2026, 7, 31)),
    ]
    for (start, end) in spans:
        for basis in [0, 1, 2, 3, 4]:
            add("YEARFRAC", (serial(*start), serial(*end), basis),
                ["start", "end", "basis"])

    # ---- ACCRINT: deliberately absent ----
    #
    # LibreOffice is not an oracle for this one. For issue 2023-11-30, settlement
    # 2024-03-31 at semi-annual frequency it returns 210.069444, implying a 30/360 day
    # count of 121, while the same spreadsheet's DAYS360, YEARFRAC and COUPDAYBS all say
    # 120. Excel returns 208.333333 — confirmed by hand, 2026-09-05 — which is exactly
    # 120/180 of a coupon and what the documented formula gives.
    #
    # Its basis 1 is wrong in a second, independent way: it divides actual days by the
    # length of the year containing the *issue* date, which is neither of the two
    # actual/actual conventions.
    #
    # Generating cases here would put those values in a committed fixture where they
    # would read as reference truth. AccruedInterestTests uses Excel's own value and
    # identities instead.

    return out


def evaluate(entries):
    """Hand the formulas to LibreOffice and read back what it computed."""
    def literal(value):
        return repr(float(value))

    def call(entry):
        if "formula" in entry:
            return entry["formula"]
        return "{}({})".format(entry["fn"],
                               ";".join(literal(a) for a in entry["args"]))

    rows = "".join(
        '<table:table-row><table:table-cell table:formula="of:={}" '
        'office:value-type="float"/></table:table-row>'.format(call(e))
        for e in entries)

    document = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<office:document '
        'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" '
        'xmlns:of="urn:oasis:names:tc:opendocument:xmlns:of:1.2" '
        'office:mimetype="application/vnd.oasis.opendocument.spreadsheet">'
        '<office:body><office:spreadsheet><table:table table:name="Reference">'
        + rows +
        '</table:table></office:spreadsheet></office:body></office:document>')

    with tempfile.TemporaryDirectory() as work:
        source = Path(work) / "reference.fods"
        source.write_text(document)
        profile = Path(work) / "profile"
        result = subprocess.run(
            ["soffice", "--headless", "--calc",
             f"-env:UserInstallation=file://{profile}",
             "--convert-to", "fods", "--outdir", work, str(source)],
            capture_output=True, text=True)
        produced = Path(work) / "reference.fods"
        if not produced.exists():
            sys.exit(f"LibreOffice produced nothing:\n{result.stdout}\n{result.stderr}")
        computed = produced.read_text()

    if "Err:" in computed or "office:string-value" in computed:
        errors = set(re.findall(r"Err:\d+", computed))
        sys.exit(f"LibreOffice reported {errors or 'a non-numeric result'}")

    values = re.findall(r'office:value="([-0-9.eE+]+)"', computed)
    if len(values) != len(entries):
        sys.exit(f"expected {len(entries)} values, read {len(values)}")
    return [float(v) for v in values]


def main():
    if shutil.which("soffice") is None:
        sys.exit("soffice not on PATH — install LibreOffice to regenerate this fixture")

    entries = cases()
    values = evaluate(entries)

    by_function = {}
    payload_cases = []
    for entry, value in zip(entries, values):
        by_function[entry["fn"]] = by_function.get(entry["fn"], 0) + 1
        payload_cases.append({**entry["named"], "value": value})

    version = subprocess.run(["soffice", "--version"], capture_output=True,
                             text=True).stdout.strip()

    payload = {
        "name": "excelFinancial",
        "reference": f"LibreOffice Calc ({version})",
        "note": "Excel-compatible financial functions, evaluated by LibreOffice rather "
                "than transcribed. Values carry about fifteen significant digits, which "
                "is what sets the tolerance on the Swift side. Dates are Excel serials, "
                "because that is what the functions receive. Each case carries its "
                "arguments under the names the Swift signature uses; the `function` "
                "field says which function produced it.",
        "cases": payload_cases,
    }
    # Group markers, so a Swift test can select one function's cases.
    for entry, case in zip(entries, payload["cases"]):
        case["function"] = float(sorted(by_function).index(entry["fn"]))
    payload["functionOrder"] = sorted(by_function)

    text = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    OUT.write_text(text)
    digest = hashlib.sha256(text.encode()).hexdigest()

    print(f"{version}")
    for fn in sorted(by_function):
        print(f"  {fn:<10} {by_function[fn]:>3} cases")
    print(f"\n{len(payload_cases)} cases → {OUT.name}  sha256 {digest[:16]}…")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
