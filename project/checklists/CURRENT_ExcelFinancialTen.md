# CURRENT — the Excel financial ten

**Spec:** `project/plans/proposals/excel-coverage/businessmath_work.tsv`, the ten
`excel-financial` rows, plus the two `DayCountConvention` cases §1.3 identified as their
prerequisite.
**Branch:** `feature/excel-financial-ten`.
**Reference:** LibreOffice Calc, through `Scripts/reference-fixtures/generate_excel_financial.py`.

---

## Done — 9 of 10, plus both day counts

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

`SLN` also gained the salvage value the two existing implementations lacked, and both
now delegate to it — see the commit for what that fixed in `RealEstateModel`.

---

## Not done — `ACCRINT`, and why it is blocked rather than merely unfinished

**The oracle is not trustworthy for this one function.** Everything above was verified
against LibreOffice Calc, and for ACCRINT LibreOffice contradicts *itself* in two
separate ways. Implementing against it would bake in a quirk that may not be Excel's,
in a bond-accrual function where being wrong prices something before anyone notices.

Excel documents ACCRINT as

```
par · (rate/frequency) · Σᵢ Aᵢ/NLᵢ
```

over the quasi-coupon periods between issue and settlement. That model, implemented
correctly — with `NLᵢ = 360/frequency` for the 30/360 bases rather than the 30/360 span
between the quasi-coupon dates, which was my first mistake — reproduces **15 of 20**
reference cases. The five it does not are two distinct problems:

**1. Basis 1 is a third thing again.** Measured from the reference values, LibreOffice's
ACCRINT basis 1 divides actual days by the length of the year containing the *issue*
date: 61/366 for a 2024 issue, 122/365 for a 2023 one. That is neither ISDA ACT/ACT
(which splits at the year boundary) nor Excel's documented basis-1 rule (which averages
the years spanned). It is also frequency-independent, where the documented formula is
not.

**2. Bases 0 and 4 disagree with LibreOffice's own day count.** For issue 2023-11-30,
settlement 2024-03-31, frequency 2, ACCRINT implies a 30/360 day count of **121**. In the
same spreadsheet, `DAYS360(issue, settlement, FALSE)` returns 120, `DAYS360(…, TRUE)`
returns 120, `YEARFRAC(…, 0)` returns exactly ⅓, and `COUPDAYBS` returns 120 against a
`COUPDAYS` of 180. Settling one day earlier gives 208.333, exactly 120/180 of a coupon.
Only ACCRINT counts the extra day, and only at a month end.

Our `thirty360` agrees with `DAYS360` at 120, so the disagreement is inside LibreOffice.

### What would unblock it

Real Excel values. The most promising source is the 79-workbook corpus in
SwiftExcelFunctions, whose cells carry Excel's own cached results — asked for
2026-09-05. A dozen ACCRINT cells with settlements at and away from a month end would
settle both questions.

Failing that, a handful of values typed out of Excel by hand would do; the two cases
that matter are a month-end settlement on basis 0, and any basis-1 case spanning a year
boundary.

### What not to do

Do not implement against the LibreOffice values as they stand. The 15 that agree are
agreement about the easy cases; the 5 that do not are precisely the ones a bond
calculation gets wrong.

---

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
