# Design Proposal: `thirty360`'s February rule — one zone bug, and one missing basis

**Status:** Draft, for the BusinessMath session
**Author:** SwiftExcelFunctions session, 2026-09-07
**Measured against:** BusinessMath `v2.14.0` (checkout `51bb6316`)
**Priority:** The bug is the **only** remaining source of Excel disagreement in the corpus.

---

## 1. Objective

Two separate things, deliberately kept apart:

1. **A defect.** `thirty360`'s February rule is implemented correctly and does not fire, because it
   reads dates through `Calendar.current`. Fix the zone.
2. **A gap.** Excel's basis 0 departs from the SIA/NASD standard it is named after. Per ADR-001,
   match Excel under the Excel-facing name and expose the standard beside it, named for the
   standard.

---

## 2. The defect

### 2.1 What we see

`YEARFRAC(2020-02-29, 2020-12-31, 0)`:

| | days | year fraction |
|---|---:|---|
| Excel's own cached value¹ | **301** | 0.83611111111111114 |
| BusinessMath 2.14.0 | 302 | 0.8388888888888889 |

¹ `Long Acre Team 2013 Probabilistic All.xlsx / Lease Renewal!L77`, a real workbook. Not a figure
computed from a specification — the value Excel itself wrote to the file.

### 2.2 The rule is right; the calendar is wrong

This is the part worth reading carefully, because the obvious diagnosis is wrong. `thirty360Days`
already implements the February rule, and implements it *the way Excel does*:

```swift
if !european, startIsFebruaryEnd, endIsFebruaryEnd { adjustedEndDay = 30 }
if !european, startIsFebruaryEnd { adjustedStartDay = 30 }

let endIsPulledBack = european ? (endDay == 31) : (endDay == 31 && startDay >= 30)
if endIsPulledBack { adjustedEndDay = 30 }
```

Note that the pull-back tests `startDay`, the **un-adjusted** day. That is exactly Excel's
behaviour and it is what produces 301 rather than 300. The code is correct.

What fails is `isLastDayOfFebruary`:

```swift
private let cachedCalendar = Calendar.current          // ← line 15

private static func isLastDayOfFebruary(_ date: Date) -> Bool {
    let calendar = cachedCalendar
    let parts = calendar.dateComponents([.month], from: date)
    guard parts.month == 2 else { return false }
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else { return false }
    return calendar.dateComponents([.month], from: tomorrow).month == 3
}
```

An Excel serial date is a **zone-free calendar date**, so the caller builds it as a UTC midnight.
Read back through `Calendar.current` in any negative-offset zone, that instant is the *previous*
day. 2020-02-29 00:00 UTC is 2020-02-28 19:00 in `America/New_York`; 28 February is not the last
day of February in a leap year; the rule does not fire; the answer is 302.

### 2.3 Measured, not argued

Same dates, same call, varying only the zone the `Date` was built in:

```
dates built in UTC             : 302 days
dates built in America/New_York: 301 days      ← matches Calendar.current
dates built in Asia/Tokyo      : 302 days
Calendar.current               : America/New_York
```

The convention agrees with Excel **only when the caller's zone happens to match the machine's.**
A UTC CI runner and a New York laptop would disagree about a bond accrual, and both would look
right to whoever was sitting in front of them.

### 2.4 This is the same defect 2.14.0 already fixed, at a fourth site

2.14.0 fixed the daylight-saving hour in `actual365`, `actual360` and `actualActual` — the same root
cause, elapsed time measured through a local calendar. `DayCountConvention.swift` even documents it:

> `thirty360` never had it, because it reads calendar components rather than an interval

That is true of the *day arithmetic* and not of `isLastDayOfFebruary`, which asks the calendar a
question about a specific instant. Three of four sites were fixed.

### 2.5 Proposed fix

```swift
private let cachedCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()
```

A day count is defined on **calendar dates**, not instants, so a fixed zone is the correct reading
for every method in the file, not only this one. Check the other users of `cachedCalendar` in the
same pass — anything extracting `.day` or `.month` from a caller-supplied `Date` has the same
exposure.

### 2.6 Why this one matters more than its size

Basis 0 is the basis **every one of the corpus's 3,425 `YEARFRAC` calls uses.** Downstream, this
single defect and its `IF`/`YEAR`/`AND` wrappers are the entire remaining disagreement list against
Excel: 260 + 202 + 142 + 140 cells. Nothing else is outstanding.

It is pinned downstream by `testTheFebruaryEndOfMonthRule` with `XCTExpectFailure`, so it will
report an *unexpected pass* the moment this lands — no coordination needed.

---

## 3. The gap: Excel is not NASD

### 3.1 Three defensible answers

The SIA's *Standard Securities Calculation Methods* states the US 30/360 rule as an **ordered** list:

1. If D1 is the last day of February **and** D2 is the last day of February, D2 = 30.
2. If D1 is the last day of February, D1 = 30.
3. If D2 = 31 **and** D1 is 30 or 31, D2 = 30.
4. If D1 = 31, D1 = 30.

Order is the whole point: rule 2 sets D1 = 30 *before* rule 3 tests it. For 2020-02-29 → 2020-12-31:

| | D1 | D2 | days |
|---|---|---|---:|
| **SIA/NASD, rules in order** | 29 → 30 (r2) | 31 → 30 (r3 sees D1 = 30) | **300** |
| **Excel basis 0** | 29 → 30 | 31 (r3 tests the *original* 29) | **301** |
| **No February rule** | 29 | 31 | 302 |

Excel applies rule 2 and then evaluates rule 3 against the pre-adjustment day. That is a departure
from the standard whose name it carries, and it is not a rounding difference — it is a whole day.

### 3.2 ADR-001 applies exactly

This is the same situation as basis 1, and it should be resolved the same way — which is the
precedent this package already set, and set well:

> Where Excel departs from a published standard, match Excel under the Excel-facing name and expose
> the standard beside it, named for the standard.

`actualActual` is the spreadsheet's rule and `isdaActualActual` is the standard. The parallel:

```swift
case thirty360     = "30/360"           // Excel basis 0 — unchanged, 301
case siaThirty360  = "30/360 (SIA)"     // the standard as published — 300
```

**`thirty360` keeps its current behaviour.** It is already Excel's, and changing it would break
every spreadsheet-facing caller to satisfy a standard those callers did not ask for. The new case is
additive.

### 3.3 A caution on the existing documentation

`thirty360` is currently documented as "(US, NASD)", and after §3.1 that is not accurate — it is
Excel's variant of NASD, differing by a day at a February month end. Worth correcting in the same
pass, with the reason stated, so the next reader does not "fix" the pull-back to match the standard
and silently break every spreadsheet.

---

## 4. Test Strategy

**For the defect (§2):**

- The reproduction above, asserting 301/360 for 2020-02-29 → 2020-12-31 with dates built in **UTC**.
- The same pair built in at least two other zones, asserting the same answer. That is the assertion
  that actually pins the bug: a single-zone test passes today on a New York machine.
- Run at least one case under `TZ=UTC` and one under a negative-offset zone in CI. The defect is
  invisible in the zone it was written in, which is how it survived.

**For the new basis (§3):**

- 2020-02-29 → 2020-12-31 = 300/360 under `siaThirty360`, against `thirty360`'s 301, in the same
  test, so the difference is the assertion rather than a footnote.
- The three other SIA rules exercised independently: both-ends-February, D2 = 31 with D1 = 30, and
  D1 = 31.

---

## 5. Open Questions

1. **Naming.** `siaThirty360` follows the `isdaActualActual` precedent — named for the body that
   publishes it. `nasdThirty360` is the more familiar name in US markets but is the name Excel is
   *already* claiming, which is the ambiguity worth avoiding. Recommend `siaThirty360`.
2. **Does anything downstream want the SIA variant today?** Nothing in the corpus asks for it — all
   3,425 calls are basis 0, which is Excel's. §3 is completeness, and only §2 is blocking. If it is
   easier to ship the zone fix alone, ship it alone.
3. **Is `Calendar.current` used elsewhere in the package for caller-supplied dates?** Not audited
   here — this proposal only measured `DayCountConvention`. Worth a sweep in the same pass, since
   the failure mode is silent everywhere it occurs.
