# CURRENT — the Excel financial ten

**Spec:** `project/plans/proposals/excel-coverage/businessmath_work.tsv`, the ten
`excel-financial` rows, plus the two `DayCountConvention` cases §1.3 identified as their
prerequisite.
**Branch:** `feature/excel-financial-ten`.
**Reference:** LibreOffice Calc, through `Scripts/reference-fixtures/generate_excel_financial.py`.

---

## Done — all ten, plus three day counts

| Item | Function | Reference cases |
|---|---|---|
| `DayCountConvention.actualActual` | the spreadsheet's rule — `YEARFRAC` basis 1 | 105 YEARFRAC cases |
| `DayCountConvention.isdaActualActual` | ISDA ACT/ACT | derived, 15 tests |
| `DayCountConvention.thirty360European` | 30E/360 | derived, 11 tests |
| `SLN` | `straightLineDepreciation(cost:salvage:life:)` | 5 |
| `SYD` | `sumOfYearsDigitsDepreciation(cost:salvage:life:period:)` | 16 |
| `DDB` | `decliningBalanceDepreciation(cost:salvage:life:period:factor:)` | 25 |
| `VDB` | `variableDecliningBalanceDepreciation(…)` | 15 |
| `RATE` | `periodicRate(periods:payment:presentValue:futureValue:type:guess:)` | 8 |
| `NPER` | `numberOfPeriods(rate:payment:presentValue:futureValue:type:)` | 8 |
| `PDURATION` | `periodsToGrow(rate:presentValue:futureValue:)` | 4 |
| `NOMINAL` | `nominalRate(effectiveRate:periodsPerYear:)` | 5 |
| `ACCRINT` | `accruedInterest(issue:firstInterest:settlement:rate:par:frequency:basis:)` | Excel, by hand |

`SLN` also gained the salvage value the two existing implementations lacked, and both
now delegate to it — see the commit for what that fixed in `RealEstateModel`.

---

## `ACCRINT` — done, and the only function here not verified by the workbook

Excel's value settled it on 2026-09-05:

```
=ACCRINT(DATE(2023,11,30), DATE(2024,11,30), DATE(2024,3,31), 0.0625, 10000, 2, 0)
Excel        208.333333      ← the documented formula, and what we compute
LibreOffice  210.069444      ← implies a 30/360 day count of 121
```

So the documented formula is right and **LibreOffice's ACCRINT is wrong**, in two
independent ways: the 121-day count above, which contradicts its own `DAYS360`,
`YEARFRAC` and `COUPDAYBS`; and a basis 1 that divides actual days by the length of the
year containing the *issue* date, which is neither actual/actual convention.

Its twenty cases have therefore been **removed from the generated workbook**, with the
reason recorded in `generate_excel_financial.py`. Leaving them would have put wrong
values in a committed fixture where they read as reference truth.

`AccruedInterestTests` uses Excel's own value plus identities instead. The identities are
worth reading for one thing they get right: *"a whole coupon period accrues exactly one
coupon"* is **false** for `actual360` and `actual365`. A real half-year is 182 actual days
against a nominal 180, so it accrues 182/180 of a coupon — which is what quoting a
360-day year against a 365-day calendar means, and forcing every basis to one would have
been forcing a bug.

## The naming, and a bug the naming exposed

**`actualActual` is the spreadsheet's rule; ISDA is `isdaActualActual`.** The plain name
goes to the convention a caller coming from a spreadsheet means, because binding
`YEARFRAC` basis 1 to ISDA would disagree with the sheet it came from by about a third
of a percent — silently, in a function whose output prices things. ISDA is still here and
still correct; it just says which standard it is.

Verified against `YEARFRAC(…, 1)` over a grid built to separate the branches of its rule:
inside one year, crossing one boundary with and without a 29 February in range, exactly a
year, and several years. 16 of 16 matched the published Excel algorithm before a line was
written.

**Adding that grid found a defect in `thirty360`, which has shipped for some time.** It
omitted the NASD February end-of-month rule entirely, so 28 February to 31 July counted
153 days against the spreadsheet's 151. Four of eight February cases were wrong. Two
details matter and neither is obvious:

- The last day of February is treated as a 30th — the 28th in a common year, the 29th in
  a leap one.
- The end-of-month pull-back on a 31st tests the start day **before** that February
  adjustment, not after. That ordering is the whole difference between 151 and 150.

The European rule has no February case, and needed no change.

The bug survived because the convention had only ever been checked against its own
definition. Nothing downstream broke when it was fixed: the existing bond and hazard-curve
tests happen never to use a February-end date, which is the same reason nobody noticed.

## Notes worth keeping

- **The workbook is the oracle, and it is generated.** §2.3 of the coverage proposal
  asked for one. `generate_excel_financial.py` writes formulas with no cached values,
  has LibreOffice evaluate them, and reads back `office:value` — about fifteen
  significant digits, which is what sets the 1e-12 tolerance in the tests rather than
  anything about the implementations.
- **DDB accepts a fractional period at or above one** and refuses anything below, and its
  closed form computes prior periods at the *uncapped* run rate. That is why declining
  balance does not reach the salvage value, and why VDB switches.
- **The annuity functions use signed cash flows** — money in positive, money out
  negative — where the neighbouring `payment()` uses magnitudes. Solving for a rate or a
  term cannot work with magnitudes: nothing ever gets repaid. `rateInvertsPayment` pins
  the flip between the two conventions.
- **Excel's YEARFRAC basis 1 is not ISDA ACT/ACT.** Confirmed here a second time:
  `YEARFRAC(2023-11-30, 2024-03-31, 1)` is exactly ⅓ in LibreOffice, where ISDA gives
  0.33357. `DayCountConvention.actualActual` implements ISDA, which is the bond-market
  convention worth having; the Excel binding is SwiftExcelFunctions' decision and the
  documentation says so.

---

## Closed 2026-09-06

All ten functions plus the three day-count conventions shipped in 2.12.0. Adding the Excel workbook grid found a defect in `thirty360` that had shipped for months — the entry above records it. Archived.
