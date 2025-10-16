# Getting Started with BusinessMath

Learn how to use BusinessMath for business calculations and financial modeling.

## Overview

BusinessMath provides a comprehensive toolkit for temporal data analysis, financial calculations, and business forecasting. This guide will walk you through the core concepts and show you how to get started with common tasks.

## Installation

### Swift Package Manager

Add BusinessMath to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/BusinessMath.git", from: "1.0.0")
]
```

Then import it in your Swift files:

```swift
import BusinessMath
```

## Core Concepts

### Periods

Periods represent time intervals in your data. BusinessMath supports four period types:

```swift
// Create different period types
let jan2025 = Period.month(year: 2025, month: 1)
let q1_2025 = Period.quarter(year: 2025, quarter: 1)
let fy2025 = Period.year(2025)
let today = Period.day(Date())

// Use period arithmetic
let feb2025 = jan2025 + 1  // Next month
let yearRange = jan2025...jan2025 + 11  // Full year of months
```

### Time Series

Time series associate values with periods, enabling temporal analysis:

```swift
// Create a time series
let periods = [
    Period.month(year: 2025, month: 1),
    Period.month(year: 2025, month: 2),
    Period.month(year: 2025, month: 3)
]
let revenue: [Double] = [100_000, 120_000, 115_000]

let ts = TimeSeries(periods: periods, values: revenue)

// Access values
if let janRevenue = ts[periods[0]] {
    print("January revenue: \(janRevenue)")
}

// Iterate over values
for value in ts {
    print(value)
}
```

### Time Value of Money

Calculate present value, future value, and payments:

```swift
// Present value of a future amount
let pv = presentValue(futureValue: 110_000, rate: 0.10, periods: 1)
// Result: 100,000

// Future value of an investment
let fv = futureValue(presentValue: 100_000, rate: 0.08, periods: 5)
// Result: ~146,933

// Monthly loan payment
let pmt = payment(
    presentValue: 300_000,
    rate: 0.06 / 12,
    periods: 360,
    futureValue: 0,
    type: .ordinary
)
// Result: ~1,799 per month
```

### Net Present Value and IRR

Evaluate investments and projects:

```swift
// Cash flows: initial investment, then returns
let cashFlows = [-250000.0, 100_000, 150_000, 200_000, 250_000, 300_000]

// Calculate NPV at 10% discount rate
let netPresentValue = npv(discountRate: 0.10, cashFlows: cashFlows)
// Result: ~472,169 (positive NPV → good investment)

// Calculate IRR (rate where NPV = 0)
let internalRate = try irr(cashFlows: cashFlows)
// Result: ~56.7% return
```

### Growth Rates

Analyze and project growth:

```swift
// Simple growth rate
let growth = growthRate(from: 100_000, to: 120_000)
// Result: 0.20 (20% growth)

// Compound annual growth rate
let compoundGrowth = cagr(
    beginningValue: 100_000,
    endingValue: 150_000,
    years: 3
)
// Result: ~14.5% per year

// Project future values
let projection = applyGrowth(
    baseValue: 100_000,
    rate: 0.15,
    periods: 5,
    compounding: .annual
)
// Result: [100k, 115k, 132.25k, 152k, 175k, 201k]
```

### Trend Models

Fit trends to historical data and forecast:

```swift
// Historical revenue
let historical = TimeSeries(
    periods: (0..<12).map { Period.month(year: 2024, month: $0 + 1) },
    values: [100, 105, 110, 108, 115, 120, 118, 125, 130, 128, 135, 140]
)

// Fit a linear trend
var trend = LinearTrend<Double>()
try trend.fit(to: historical)

// Project 6 months forward
let forecast = try trend.project(periods: 6)
// Result: TimeSeries with forecasted values for 6 future months
```

### Seasonal Analysis

Extract and apply seasonal patterns:

```swift
// Quarterly revenue with seasonal pattern
let revenue = [100, 120, 110, 150, 105, 125, 115, 160]  // Q4 holiday spike

let ts = TimeSeries(
    periods: (0..<8).map { Period.quarter(year: 2023 + $0/4, quarter: ($0 % 4) + 1) },
    values: revenue
)

// Calculate seasonal indices (4 quarters per year)
let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: 4)
// Result: [~0.85, ~1.01, ~0.91, ~1.23] (Q4 is 23% above average)

// Remove seasonality to see underlying trend
let deseasonalized = try seasonallyAdjust(timeSeries: ts, indices: indices)

// Decompose into trend, seasonal, and residual components
let decomposition = try decomposeTimeSeries(
    timeSeries: ts,
    periodsPerYear: 4,
    method: .multiplicative
)

print("Trend:", decomposition.trend.valuesArray)
print("Seasonal:", decomposition.seasonal.valuesArray)
print("Residual:", decomposition.residual.valuesArray)
```

## Common Workflows

### Revenue Forecasting

```swift
// 1. Load historical data
let historical = TimeSeries(periods: historicalPeriods, values: historicalRevenue)

// 2. Extract seasonality
let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

// 3. Deseasonalize
let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

// 4. Fit trend to deseasonalized data
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)

// 5. Project trend forward
let trendForecast = try trend.project(periods: 4)

// 6. Reapply seasonality
let forecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)
```

### Investment Analysis

```swift
// Define investment cash flows with dates
let dates = [
Date(),			// Today: Initial Investment
	Date(timeIntervalSinceNow: 365 * 86400 * 1),	// Year 1
	Date(timeIntervalSinceNow: 365 * 86400 * 2),	// Year 2
	Date(timeIntervalSinceNow: 365 * 86400 * 3),	// Year 3
	Date(timeIntervalSinceNow: 365 * 86400 * 4),	// Year 4
	Date(timeIntervalSinceNow: 365 * 86400 * 5)		// Year 5
]
let cashFlows = [-250000.0, 100_000, 150_000, 200_000, 250_000, 300_000]

// Calculate XNPV (irregular intervals)
let npvValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)

// Calculate XIRR
let irrValue = try xirr(dates: dates, cashFlows: cashFlows)

// Payback period
let payback = paybackPeriod(cashFlows: cashFlows)

// Discounted payback period
let discountedPayback = discountedPaybackPeriod(rate: 0.10, cashFlows: cashFlows)
```

### Loan Amortization

```swift
let principal = 300_000.0
let annualRate = 0.06
let monthlyRate = annualRate / 12
let totalPayments = 360  // 30 years

// Calculate monthly payment
let monthlyPayment = payment(
    presentValue: principal,
    rate: monthlyRate,
    periods: totalPayments,
    futureValue: 0,
    type: .ordinary
)

// Analyze first payment
let principalPortion = principalPayment(
    rate: monthlyRate,
    period: 1,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

let interestPortion = interestPayment(
    rate: monthlyRate,
    period: 1,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)

// Cumulative totals over first year
let yearInterest = cumulativeInterest(
    rate: monthlyRate,
    startPeriod: 1,
    endPeriod: 12,
    totalPeriods: totalPayments,
    presentValue: principal,
    futureValue: 0,
    type: .ordinary
)
```

## Next Steps

- Read the <doc:TimeSeries> concept guide for in-depth time series operations
- Explore <doc:TimeValueOfMoney> for financial calculations
- Learn about <doc:GrowthModeling> for forecasting
- Follow the <doc:BuildingRevenueModel> tutorial for a complete example
- Check the <doc:InvestmentAnalysis> tutorial for valuation workflows

## See Also

- ``Period``
- ``TimeSeries``
- ``npv(discountRate:cashFlows:)``
- ``irr(cashFlows:guess:tolerance:maxIterations:)``
- ``TrendModel``
