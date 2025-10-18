# Time Value of Money

Calculate present value, future value, and investment returns for financial analysis.

## Overview

The time value of money (TVM) is a fundamental concept in finance: money available now is worth more than the same amount in the future due to its earning potential. BusinessMath provides comprehensive TVM functions for:

- **Present and Future Value**: Single amounts and annuities
- **Payment Calculations**: Loan payments, amortization schedules
- **Investment Analysis**: NPV, IRR, profitability index, payback periods
- **Irregular Cash Flows**: XNPV and XIRR for real-world scenarios

All functions support generic numeric types (`Double`, `Float`, etc.) and handle edge cases like zero rates and negative rates (deflation).

## Present Value

Present value (PV) calculates what future cash flows are worth today.

### Single Amount

The present value of a single future amount:

```swift
// What is $110,000 in 1 year worth today at 10% discount rate?
let pv = presentValue(futureValue: 110_000, rate: 0.10, periods: 1)
// Result: 100,000

// What is $1,000,000 in 30 years worth today at 8% discount rate?
let pv30 = presentValue(futureValue: 1_000_000, rate: 0.08, periods: 30)
// Result: ~99,377 (only 10% of future value!)
```

**Formula:**

```
PV = FV / (1 + r)^n

Where:
- PV = Present Value
- FV = Future Value
- r = discount rate per period
- n = number of periods
```

### Annuity (Series of Payments)

The present value of a stream of equal payments:

```swift
// How much is $1,000/month for 30 years worth today at 6% annual rate?
let pv = presentValueAnnuity(
    payment: 1_000,
    rate: 0.06 / 12,  // Monthly rate
    periods: 360,     // 30 years × 12 months
    type: .ordinary   // Payments at end of period
)
// Result: ~166,792 (much less than 1000×360 = $360,000)

// Annuity due (payments at beginning of period)
let pvDue = presentValueAnnuity(
    payment: 1_000,
    rate: 0.06 / 12,
    periods: 360,
    type: .due
)
// Result: ~167,625 (slightly more than ordinary)
```

**Formula (Ordinary):**

```
PV = PMT × [(1 - (1+r)^-n) / r]

Where:
- PMT = payment per period
- r = discount rate per period
- n = number of periods
```

**Formula (Due):**

```
PV_due = PV_ordinary × (1 + r)
```

### Real-World Applications

**Car Loan Valuation:**

```swift
// What is a $400/month car payment for 5 years worth today at 6%?
let carLoan = presentValueAnnuity(
    payment: 400,
    rate: 0.06 / 12,
    periods: 60,
    type: .ordinary
)
// Result: ~20,690 (the car's financed value)
```

**Lottery Annuity vs Lump Sum:**

```swift
// $50,000/year for 20 years vs lump sum today at 5% discount
let annuityValue = presentValueAnnuity(
    payment: 50_000,
    rate: 0.05,
    periods: 20,
    type: .ordinary
)
// Result: ~623,111

// If lump sum offer is $600,000, take it!
// If lump sum offer is $650,000, definitely take it!
```

**Bond Valuation:**

```swift
// Bond pays $50 coupon annually for 10 years plus $1,000 face value
// Market rate is 6%

let couponPV = presentValueAnnuity(payment: 50, rate: 0.06, periods: 10, type: .ordinary)
let facePV = presentValue(futureValue: 1_000, rate: 0.06, periods: 10)
let bondValue = couponPV + facePV
// Result: ~926.40 (bond trades below par when market rate > coupon rate)
```

## Future Value

Future value (FV) calculates what an amount today will grow to in the future.

### Single Amount

```swift
// $100,000 invested for 5 years at 8% annual return
let fv = futureValue(presentValue: 100_000, rate: 0.08, periods: 5)
// Result: ~146,933 (the power of compound growth)

// $10,000 over 30 years at 10% (stock market historical average)
let fv30 = futureValue(presentValue: 10_000, rate: 0.10, periods: 30)
// Result: ~174,494 (17× growth!)
```

**Formula:**

```
FV = PV × (1 + r)^n
```

### Annuity (Regular Savings)

```swift
// Saving $500/month for 30 years at 7% annual return (401k scenario)
let retirement = futureValueAnnuity(
    payment: 500,
    rate: 0.07 / 12,
    periods: 360,
    type: .ordinary
)
// Result: ~609,985 (only deposited $180,000!)

// With employer match (effectively $1,000/month)
let withMatch = futureValueAnnuity(
    payment: 1_000,
    rate: 0.07 / 12,
    periods: 360,
    type: .ordinary
)
// Result: ~1,19,971 (over $1 million!)
```

**Formula (Ordinary):**

```
FV = PMT × [((1+r)^n - 1) / r]
```

### Real-World Applications

**College Savings:**

```swift
// Save $300/month for 18 years at 6% for child's education
let collegeFund = futureValueAnnuity(
    payment: 300,
    rate: 0.06 / 12,
    periods: 216,
    type: .ordinary
)
// Result: ~116,206 (deposited only $64,800)
```

**Comparing Savings Plans:**

```swift
// Plan A: $10,000 lump sum today
let planA = futureValue(presentValue: 10_000, rate: 0.08, periods: 10)
// Result: ~21,589

// Plan B: $1,000/year for 10 years
let planB = futureValueAnnuity(payment: 1_000, rate: 0.08, periods: 10, type: .ordinary)
// Result: ~14,487

// Plan A wins! (lump sum advantage)
```

## Payment Calculations

Calculate loan payments and analyze amortization.

### Loan Payment

```swift
// $300,000 mortgage, 30 years, 6% annual rate
let monthlyPayment = payment(
    presentValue: 300_000,
    rate: 0.06 / 12,
    periods: 360,
    futureValue: 0,
    type: .ordinary
)
// Result: ~1,799/month

// Total paid over life of loan
let totalPaid = monthlyPayment * 360
// Result: ~647,515 (more than double the principal!)
```

**Formula:**

```
PMT = [PV × r(1+r)^n - FV × r] / [(1+r)^n - 1]

For standard loan (FV = 0):
PMT = PV × [r(1+r)^n] / [(1+r)^n - 1]
```

### Principal and Interest Breakdown

```swift
let principal = 300_000.0
let rate = 0.06 / 12
let periods = 360

// First payment breakdown
let firstInterest = interestPayment(
    rate: rate,
    period: 1,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~1,500 (mostly interest!)

let firstPrincipal = principalPayment(
    rate: rate,
    period: 1,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~299 (only 17% goes to principal)

// Last payment breakdown
let lastInterest = interestPayment(
    rate: rate,
    period: 360,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~9 (almost all principal now)

let lastPrincipal = principalPayment(
    rate: rate,
    period: 360,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~1,790 (99% goes to principal)
```

### Cumulative Calculations

```swift
// Total interest paid in first year
let firstYearInterest = cumulativeInterest(
    rate: rate,
    startPeriod: 1,
    endPeriod: 12,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~17,900 (almost all interest in early years)

// Total principal paid in first year
let firstYearPrincipal = cumulativePrincipal(
    rate: rate,
    startPeriod: 1,
    endPeriod: 12,
    totalPeriods: periods,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
// Result: ~3,684 (only paid down 1.2% of loan)
```

## Net Present Value (NPV)

NPV discounts all cash flows to present value and sums them.

### Basic NPV

```swift
// Initial investment, then returns
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

let npv = npv(discountRate: 0.10, cashFlows: cashFlows)
// Result: ~38,877

// Positive NPV → accept project
// Negative NPV → reject project
// NPV = 0 → breakeven
```

**Formula:**

```
NPV = Σ [CF_t / (1+r)^t]

Where:
- CF_t = cash flow at time t
- r = discount rate
- t = time period (0, 1, 2, ...)
```

### NPV with Time Series

```swift
let periods = [
    Period.year(2025),
    Period.year(2026),
    Period.year(2027)
]
let cashFlows: [Double] = [-100_000, 50_000, 80_000]

let ts = TimeSeries(periods: periods, values: cashFlows)
let npvValue = npv(rate: 0.10, timeSeries: ts)
// Result: ~11,570
```

### Excel-Compatible NPV

```swift
// Excel treats first cash flow as period 1, not period 0
let futureCashFlows = [30_000.0, 40_000, 50_000, 60_000]

let npvExcelResult = npvExcel(rate: 0.10, cashFlows: futureCashFlows)
// Result: ~138,877

// Add initial investment separately
let totalNPV = -100_000 + npvExcelResult
// Result: ~38,877
```

### Investment Metrics

**Profitability Index:**

```swift
let pi = profitabilityIndex(rate: 0.10, cashFlows: cashFlows)
// Result: ~1.38

// PI > 1.0 → accept project
// PI < 1.0 → reject project
// PI = 1.0 → breakeven
```

**Payback Periods:**

```swift
// Simple payback (ignoring time value)
let payback = paybackPeriod(cashFlows: cashFlows)
// Result: 3 periods (recovered after 3rd payment)

// Discounted payback (considering time value)
let discountedPayback = discountedPaybackPeriod(rate: 0.10, cashFlows: cashFlows)
// Result: 4 periods (takes longer with discounting)

// nil means never recovers initial investment
```

## Internal Rate of Return (IRR)

IRR finds the discount rate where NPV = 0.

### Basic IRR

```swift
let cashFlows = [-100_000.0, 30_000, 40_000, 50_000, 60_000]

let irr = try irr(cashFlows: cashFlows)
// Result: ~24.9%

// Compare to required rate of return:
// IRR > required return → accept project
// IRR < required return → reject project
```

**Relationship to NPV:**

```swift
// Verify: NPV at IRR should be ~0
let npvAtIRR = npv(discountRate: irr, cashFlows: cashFlows)
// Result: ~0.0000001 (essentially zero within tolerance)
```

### Modified IRR (MIRR)

MIRR separates financing and reinvestment rates:

```swift
// Finance negative flows at 8%, reinvest positive flows at 12%
let mirr = try mirr(
    cashFlows: cashFlows,
    financeRate: 0.08,
    reinvestmentRate: 0.12
)
// Result: ~20.1%

// MIRR is more realistic than IRR for projects with
// multiple sign changes or different borrowing/investing rates
```

### Error Handling

```swift
do {
    // All positive cash flows → no IRR
    let allPositive = [100.0, 200.0, 300.0]
    let irrValue = try irr(cashFlows: allPositive)
} catch IRRError.invalidCashFlows {
    print("Need both positive and negative cash flows")
}

do {
    // Convergence failure
    let problematic = [-100.0, 10.0, -50.0, 200.0]
    let irrValue = try irr(cashFlows: problematic, maxIterations: 10)
} catch IRRError.convergenceFailed {
    print("IRR calculation did not converge")
}
```

## Irregular Cash Flows (XNPV/XIRR)

Real-world cash flows rarely occur at regular intervals. XNPV and XIRR handle irregular timing.

### XNPV

```swift
// Investment with irregular cash flows
let dates = [
    Date(),  // Today: initial investment
    Date(timeIntervalSinceNow: 100 * 86400),   // 100 days later
    Date(timeIntervalSinceNow: 250 * 86400),   // 250 days later
    Date(timeIntervalSinceNow: 400 * 86400)    // 400 days later
]
let cashFlows = [-100_000.0, 30_000, 50_000, 40_000]

let xnpvValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
// Result: ~12,100 (accounts for actual timing)

// Compare to regular NPV (assumes annual periods)
let regularNPV = npv(discountRate: 0.10, cashFlows: cashFlows)
// Result: ~$(1,352) (different due to timing assumptions)
```

**Formula:**

```
XNPV = Σ [CF_i / (1+r)^((date_i - date_0) / 365)]

Where:
- CF_i = cash flow i
- date_i = date of cash flow i
- date_0 = date of first cash flow
- r = annual discount rate
```

### XIRR

```swift
// Find IRR for irregular cash flows
let xirrValue = try xirr(dates: dates, cashFlows: cashFlows)
// Result: ~29.4%

// Verify: XNPV at XIRR should be ~0
let xnpvAtXIRR = try xnpv(rate: xirrValue, dates: dates, cashFlows: cashFlows)
// Result: ~0.0000001
```

### Real-World Application: Venture Capital

```swift
// VC investment with multiple rounds and exit
let vcDates = [
    Date(),  // Series A
    Date(timeIntervalSinceNow: 365 * 86400),    // Series B (1 year)
    Date(timeIntervalSinceNow: 750 * 86400),    // Series C (2+ years)
    Date(timeIntervalSinceNow: 1825 * 86400)    // Exit (5 years)
]
let vcCashFlows = [-5_000_000.0, -3_000_000, -2_000_000, 40_000_000]

let vcXIRR = try xirr(dates: vcDates, cashFlows: vcCashFlows)
// Result: ~37.1% (excellent return)

let vcXNPV = try xnpv(rate: 0.20, dates: vcDates, cashFlows: vcCashFlows)
// NPV at 20% hurdle rate
```

## Choosing the Right Function

### Decision Guide

**Single Amount:**
- Use ``presentValue(futureValue:rate:periods:)`` to discount future value to today
- Use ``futureValue(presentValue:rate:periods:)`` to project current value to future

**Regular Payments:**
- Use ``presentValueAnnuity(payment:rate:periods:type:)`` for loan valuation
- Use ``futureValueAnnuity(payment:rate:periods:type:)`` for savings projections
- Use ``payment(presentValue:rate:periods:futureValue:type:)`` for loan payments

**Investment Analysis (Regular Periods):**
- Use ``npv(discountRate:cashFlows:)`` for project valuation
- Use ``irr(cashFlows:guess:tolerance:maxIterations:)`` for return calculation
- Use ``mirr(cashFlows:financeRate:reinvestmentRate:)`` for more realistic returns

**Investment Analysis (Irregular Periods):**
- Use ``xnpv(rate:dates:cashFlows:)`` for irregular cash flow valuation
- Use ``xirr(dates:cashFlows:guess:tolerance:maxIterations:)`` for irregular return calculation

**Loan Analysis:**
- Use ``principalPayment(rate:period:totalPeriods:presentValue:futureValue:type:)`` for amortization
- Use ``interestPayment(rate:period:totalPeriods:presentValue:futureValue:type:)`` for interest tracking
- Use ``cumulativeInterest(rate:startPeriod:endPeriod:totalPeriods:presentValue:futureValue:type:)`` for tax calculations

**Quick Screening:**
- Use ``profitabilityIndex(rate:cashFlows:)`` to rank projects
- Use ``paybackPeriod(cashFlows:)`` for simple risk assessment
- Use ``discountedPaybackPeriod(rate:cashFlows:)`` for risk-adjusted assessment

## Best Practices

### Use Appropriate Rates

```swift
// Convert annual rates to period rates
let annualRate = 0.06
let monthlyRate = annualRate / 12      // 0.005
let quarterlyRate = annualRate / 4     // 0.015

// For monthly payments, use monthly rate
let monthlyPmt = payment(presentValue: 100_000, rate: monthlyRate, periods: 360)
```

### Consider Payment Timing

```swift
// Ordinary annuity: payments at END of period (most common)
// - Mortgage payments
// - Bond coupons
// - Loan payments

// Annuity due: payments at BEGINNING of period
// - Rent payments
// - Lease payments
// - Insurance premiums
```

### Validate Inputs

```swift
// Check for sensible ranges
guard rate > -1.0 && rate < 10.0 else {
    // Rate should be between -100% and 1000%
    throw ValidationError.unreasonableRate
}

// Ensure cash flows have sign changes for IRR
let hasPositive = cashFlows.contains { $0 > 0 }
let hasNegative = cashFlows.contains { $0 < 0 }
guard hasPositive && hasNegative else {
    // IRR requires both positive and negative cash flows
    throw ValidationError.invalidCashFlows
}
```

### Use Realistic Assumptions

```swift
// Stock market historical returns: ~10% nominal, ~7% real
let stockReturn = 0.07

// Bond returns: ~4-5%
let bondReturn = 0.045

// Risk-free rate (Treasury): ~2-3%
let riskFreeRate = 0.025

// Inflation: ~2-3% long-term
let inflation = 0.025

// Discount rates for projects
let lowRisk = 0.08    // Established business
let mediumRisk = 0.12  // Growth company
let highRisk = 0.20   // Startup/venture
```

## See Also

- <doc:GettingStarted>
- <doc:TimeSeries>
- <doc:LoanAmortization>
- <doc:InvestmentAnalysis>
- ``npv(discountRate:cashFlows:)``
- ``irr(cashFlows:guess:tolerance:maxIterations:)``
- ``presentValueAnnuity(payment:rate:periods:type:)``
