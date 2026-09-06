# CURRENT — verifying the bindable functions

**Why:** the coverage matrix marks 86 Excel functions *bindable* — BusinessMath computes
the quantity and no formula reaches it. That also means none had been compared to
anything but its own definition, which is how `thirty360` shipped for months without the
NASD February rule and a green suite the whole time.

**Branch:** `feature/excel-bond-functions` (continues `feature/verify-bindables`).
**Reference:** LibreOffice Calc for the sweep; Excel's own cached values for the bond
family, read out of real workbooks by SwiftExcelFunctions.

---

## What the sweep found

Four defects, all in shipped code, none caught by any test this package had.

| Function | Defect | Size |
|---|---|---|
| `logFactorial` | Stirling's leading terms only above n = 20, dropping `1/(12n)` | **n! 0.4% wrong at n = 21**, and discontinuous there |
| `actual365`, `actual360`, both actual/actuals | measured elapsed time, not civil days | 2e-4 on every accrual, and machine-dependent |
| `interestPayment` with `.due` | period 1 charged a full period's interest | **CUMIPMT 9% high, CUMPRINC 41% low** in year one |
| `xnpv`, `xirr` | elapsed seconds ÷ 365 days, not whole days | 1.5e-5 → 6.5e-5, growing with the rate |

Two of those are the same mistake in two places — measuring an interval where a
spreadsheet counts civil days. `xnpv` now delegates to `DayCountConvention.actual365`
rather than repeating the arithmetic, so there is one implementation to be right.

The `interestPayment` one is worth remembering for its shape. An annuity **due** pays at
the start of each period, so payment one lands at time zero, before any interest has
accrued — Excel returns `IPMT(1, type=1) = 0`. The code returned `presentValue × rate`,
because the annuity-due correction `interest / (1 + rate)` was guarded by `period > 1`.
**The one period needing the most correction got none.** Every `type: 0` case passed,
which is the common path and the one the tests covered.

## What was verified clean

- **34 statistical functions, 127 cases.** Seven of nine groups matched on the first run:
  the distributions, regression and dispersion families. The two that failed were both
  the factorial bug.
- **`MIRR`, `CUMIPMT`/`CUMPRINC` at `type: 0`.**
- **`thirty360`, `thirty360European`, `actual360`, `actual365`, `actualActual`** against
  105 `YEARFRAC` cases across all five Excel bases.

## What was built, not verified

Excel's bond functions are defined on a coupon grid that `Bond` does not model, so
bending the existing type would have answered a different question. Written fresh from
Microsoft's definitions:

- `CouponPeriod` — `COUPPCD`, `COUPNCD`, `COUPDAYBS`, `COUPDAYSNC`, `COUPDAYS`, `COUPNUM`
- `bondPrice`, `bondYield`, `bondDuration`, `bondModifiedDuration` — `PRICE`, `YIELD`,
  `DURATION`, `MDURATION`
- `effectiveRate`, `equivalentRate` — `EFFECT`, `RRI`

All matched Excel's cached values on the first run, including the one case of the
twenty-eight that discriminates: `PRICE(1998-01-15, 2006-08-15, 0, 0.0639, 100, 1, 1)`
= 58.771794240682887, a zero-coupon bond whose mid-period settlement crosses a year
boundary, so the basis enters purely through the discounting exponent. The other
twenty-seven settle on a coupon date, where `A = 0` and `DSC/E = 1` and the day count
cannot affect the answer — they verify the coupon counting and the discounting, and that
is worth saying rather than letting a green suite imply more than it checked.

---

## Still unverified in this category

`LINEST`, `LOGEST`, `TREND`, `GROWTH`, `FORECAST*`, `CONFIDENCE.*`, `RANK.AVG`,
`STANDARDIZE` against ranges, and the 253 Excel functions the matrix marks
`unreviewed` — absence of an annotation, not absence of an implementation.

**The lesson to carry forward** is not about any one function. Every defect above was
in code with passing tests, and every one was found the same way: by comparing to an
independent implementation. A test written from the same understanding as the code
confirms the understanding, not the code.

---

## Closed 2026-09-06

Shipped in 2.12.0. Four defects found, all in shipped code, none caught by any test the package had at the time — the pattern that later motivated the oracle audit (`CURRENT_OracleAudit.md`). Archived.
