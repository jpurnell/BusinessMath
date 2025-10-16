# Time Series Usage Examples

**Purpose:** Practical examples demonstrating Time Series functionality
**Audience:** Developers using the BusinessMath library

---

## Table of Contents

1. [Period Management](#1-period-management)
2. [Time Series Basics](#2-time-series-basics)
3. [Time Value of Money](#3-time-value-of-money)
4. [Growth & Projections](#4-growth--projections)
5. [Real-World Scenarios](#5-real-world-scenarios)

---

## 1. Period Management

### Creating Periods

```swift
import BusinessMath

// Create individual periods
let jan2025 = Period.month(year: 2025, month: 1)
let q1_2025 = Period.quarter(year: 2025, quarter: 1)
let fy2025 = Period.year(2025)
let today = Period.day(Date())

// Create period ranges
let allMonths2025 = Period.year(2025).months()
// Returns: [Jan2025, Feb2025, ..., Dec2025]

let quartersInYear = Period.year(2025).quarters()
// Returns: [Q1-2025, Q2-2025, Q3-2025, Q4-2025]

// Create custom ranges
let firstHalf = Period.month(year: 2025, month: 1)...Period.month(year: 2025, month: 6)
let periodArray = Array(firstHalf)
// Returns: [Jan2025, Feb2025, Mar2025, Apr2025, May2025, Jun2025]
```

### Period Arithmetic

```swift
// Add/subtract periods
let jan = Period.month(year: 2025, month: 1)
let mar = jan + 2  // March 2025
let lastYear = jan - 12  // January 2024

// Calculate distance between periods
let start = Period.quarter(year: 2024, quarter: 1)
let end = Period.quarter(year: 2025, quarter: 4)
let numQuarters = start.distance(to: end)  // 7

// Compare periods
if mar > jan {
    print("March comes after January")
}

// Period properties
print(jan.startDate)  // 2025-01-01 00:00:00
print(jan.endDate)    // 2025-01-31 23:59:59
print(jan.label)      // "Jan 2025" or "2025-01"
```

### Fiscal Calendar

```swift
// Default calendar year (ends Dec 31)
let calendarYear = FiscalCalendar.standard

// Custom fiscal year (ends June 30)
let fiscalYear = FiscalCalendar(yearEnd: MonthDay(month: 6, day: 30))

// Get fiscal year for a date
let date = Date()  // e.g., August 2025
let fy = fiscalYear.fiscalYear(for: date)  // FY2026

// Get fiscal quarter
let fq = fiscalYear.fiscalQuarter(for: date)  // Q1-FY2026

// Create periods aligned to fiscal year
let fiscalPeriod = Period.fiscalQuarter(
    fiscalYear: 2025,
    quarter: 1,
    calendar: fiscalYear
)
```

---

## 2. Time Series Basics

### Creating Time Series

```swift
// Create from arrays
let periods = [
    Period.month(year: 2025, month: 1),
    Period.month(year: 2025, month: 2),
    Period.month(year: 2025, month: 3)
]
let values: [Double] = [100.0, 110.0, 121.0]

let revenue = TimeSeries(
    periods: periods,
    values: values,
    metadata: TimeSeriesMetadata(
        name: "Monthly Revenue",
        units: "USD",
        category: "Revenue"
    )
)

// Create from dictionary
let valueDict = [
    Period.month(year: 2025, month: 1): 100.0,
    Period.month(year: 2025, month: 2): 110.0,
    Period.month(year: 2025, month: 3): 121.0
]
let revenue2 = TimeSeries(values: valueDict, metadata: ...)

// Create with builder pattern
let revenue3 = TimeSeries<Double>
    .monthly(name: "Revenue", units: "USD")
    .from(year: 2025, month: 1)
    .values([100.0, 110.0, 121.0])
```

### Accessing Values

```swift
// Subscript access
let jan = Period.month(year: 2025, month: 1)
let janRevenue = revenue[jan]  // Optional<Double>

// Safe access with default
let febRevenue = revenue[Period.month(year: 2025, month: 2), default: 0.0]

// Array access
let allValues = revenue.valuesArray  // [100.0, 110.0, 121.0]
let allPeriods = revenue.periods

// Range access
let q1Start = Period.month(year: 2025, month: 1)
let q1End = Period.month(year: 2025, month: 3)
let q1Revenue = revenue.range(from: q1Start, to: q1End)
```

### Transforming Time Series

```swift
// Map values
let revenueInThousands = revenue.map { $0 / 1000.0 }

// Filter periods
let highRevenue = revenue.filter { $0 > 100.0 }

// Combine two series
let costs = TimeSeries(...)
let profit = revenue.zip(costs) { revenue, cost in
    revenue - cost
}

// Reduce to single value
let totalRevenue = revenue.reduce(0.0, +)
let avgRevenue = revenue.reduce(0.0, +) / Double(revenue.count)
```

### Handling Missing Values

```swift
// Forward fill
let filled = revenue.fillForward()

// Backward fill
let backfilled = revenue.fillBackward()

// Linear interpolation
let interpolated = revenue.interpolate()

// Fill with specific value
let zeroFilled = revenue.fillMissing(with: 0.0)

// Custom fill logic
let customFilled = revenue.fillMissing { period in
    // Custom logic based on period
    return 100.0
}
```

### Aggregation

```swift
// Monthly to quarterly
let quarterlyRevenue = revenue.aggregate(
    by: .quarterly,
    method: .sum
)

// Quarterly to annual
let annualRevenue = quarterlyRevenue.aggregate(
    by: .annual,
    method: .sum
)

// Different aggregation methods
let avgMonthly = dailyData.aggregate(by: .monthly, method: .average)
let endOfMonth = dailyData.aggregate(by: .monthly, method: .last)
let firstOfMonth = dailyData.aggregate(by: .monthly, method: .first)
```

---

## 3. Time Value of Money

### Present Value Calculations

```swift
// Single future value
let futureAmount: Double = 10000
let discountRate: Double = 0.08
let years = 5

let pv = presentValue(
    futureValue: futureAmount,
    rate: discountRate,
    periods: years
)
// Result: ~6,805.83

// Annuity (equal periodic payments)
let monthlyPayment: Double = 500
let monthlyRate = 0.06 / 12
let months = 36

let pvAnnuity = presentValueAnnuity(
    payment: monthlyPayment,
    rate: monthlyRate,
    periods: months,
    type: .ordinary  // payments at end of period
)
// Result: ~16,435.51
```

### Future Value Calculations

```swift
// Single present value
let investment: Double = 5000
let annualRate: Double = 0.07
let years = 10

let fv = futureValue(
    presentValue: investment,
    rate: annualRate,
    periods: years
)
// Result: ~9,835.76

// Annuity future value
let monthlyDeposit: Double = 200
let monthlyRate = 0.05 / 12
let months = 60

let fvAnnuity = futureValueAnnuity(
    payment: monthlyDeposit,
    rate: monthlyRate,
    periods: months
)
// Result: ~13,563.15
```

### Loan Amortization

```swift
// Calculate monthly payment
let loanAmount: Double = 250000
let annualRate: Double = 0.045
let monthlyRate = annualRate / 12
let years = 30
let months = years * 12

let monthlyPayment = payment(
    presentValue: loanAmount,
    rate: monthlyRate,
    periods: months,
    type: .ordinary
)
// Result: ~1,266.71

// Generate amortization schedule
var balance = loanAmount
var schedule: [(period: Int, payment: Double, principal: Double, interest: Double, balance: Double)] = []

for period in 1...months {
    let interestPmt = interestPayment(
        rate: monthlyRate,
        period: period,
        totalPeriods: months,
        presentValue: loanAmount
    )

    let principalPmt = principalPayment(
        rate: monthlyRate,
        period: period,
        totalPeriods: months,
        presentValue: loanAmount
    )

    balance -= principalPmt

    schedule.append((
        period: period,
        payment: monthlyPayment,
        principal: principalPmt,
        interest: interestPmt,
        balance: balance
    ))
}

// First payment breakdown
print("Month 1:")
print("  Payment: \(schedule[0].payment)")
print("  Principal: \(schedule[0].principal)")
print("  Interest: \(schedule[0].interest)")
print("  Balance: \(schedule[0].balance)")
```

### NPV and IRR

```swift
// Net Present Value
let cashFlows = [-100000.0, 30000.0, 30000.0, 30000.0, 30000.0]
let discountRate = 0.10

let npvValue = npv(
    discountRate: discountRate,
    cashFlows: cashFlows
)
// Result: ~-4,641.92 (negative NPV, don't invest)

// Internal Rate of Return
let profitableCashFlows = [-100000.0, 35000.0, 35000.0, 35000.0, 35000.0]

let irrValue = try irr(
    cashFlows: profitableCashFlows,
    guess: 0.10
)
// Result: ~0.1498 (14.98% return)

// Modified Internal Rate of Return
let mirrValue = try mirr(
    cashFlows: profitableCashFlows,
    financeRate: 0.08,      // Cost of borrowing
    reinvestmentRate: 0.05  // Return on reinvestment
)
// Result: More conservative than IRR
```

### Irregular Cash Flows (XNPV, XIRR)

```swift
// Cash flows at irregular intervals
let dates = [
    Date(year: 2025, month: 1, day: 1),
    Date(year: 2025, month: 3, day: 15),
    Date(year: 2025, month: 7, day: 22),
    Date(year: 2025, month: 12, day: 31)
]
let cashFlows = [-50000.0, 10000.0, 20000.0, 25000.0]

let xnpvValue = xnpv(
    rate: 0.10,
    dates: dates,
    cashFlows: cashFlows
)

let xirrValue = try xirr(
    dates: dates,
    cashFlows: cashFlows
)
```

---

## 4. Growth & Projections

### Simple Growth Rates

```swift
// Period-over-period growth
let initialValue: Double = 100.0
let finalValue: Double = 110.0

let growth = growthRate(from: initialValue, to: finalValue)
// Result: 0.10 (10% growth)

// Compound Annual Growth Rate (CAGR)
let beginningValue: Double = 1000.0
let endingValue: Double = 1500.0
let years: Double = 3.0

let compoundGrowth = cagr(
    beginningValue: beginningValue,
    endingValue: endingValue,
    years: years
)
// Result: ~0.1447 (14.47% CAGR)
```

### Growth Projections

```swift
// Apply constant growth rate
let baseRevenue: Double = 1000000
let growthRate: Double = 0.15
let numYears = 5

let projectedRevenue = applyGrowth(
    baseValue: baseRevenue,
    rate: growthRate,
    periods: numYears,
    compounding: .annual
)
// Result: [1,000,000, 1,150,000, 1,322,500, 1,520,875, 1,749,006]

// Monthly compounding
let monthlyGrowth = applyGrowth(
    baseValue: baseRevenue,
    rate: growthRate,
    periods: 12,
    compounding: .monthly
)
```

### Time Series Growth Analytics

```swift
let revenue = TimeSeries(...)

// Period-over-period growth
let momGrowth = revenue.growthRate(lag: 1)  // Month-over-month

// Year-over-year growth (for monthly data)
let yoyGrowth = revenue.growthRate(lag: 12)

// CAGR for specific range
let start = Period.year(2020)
let end = Period.year(2025)
let cagr = revenue.cagr(from: start, to: end)

// Moving average
let smoothed = revenue.movingAverage(window: 3)

// Exponential moving average
let ema = revenue.exponentialMovingAverage(alpha: 0.3)
```

### Trend Models

```swift
let historicalRevenue = TimeSeries(...)

// Linear trend
let linearModel = LinearTrend<Double>()
linearModel.fit(to: historicalRevenue)
let linearProjection = linearModel.project(periods: 12)

// Exponential trend
let exponentialModel = ExponentialTrend<Double>()
exponentialModel.fit(to: historicalRevenue)
let expProjection = exponentialModel.project(periods: 12)

// Logistic (S-curve) trend
let logisticModel = LogisticTrend<Double>(
    capacity: 10_000_000  // Market saturation point
)
logisticModel.fit(to: historicalRevenue)
let logisticProjection = logisticModel.project(periods: 12)

// Custom trend function
let customModel = CustomTrend { period in
    // Custom projection logic
    return baseValue * pow(1.15, Double(period))
}
let customProjection = customModel.project(periods: 12)
```

### Seasonality

```swift
let monthlyRevenue = TimeSeries(...)  // 3 years of monthly data

// Calculate seasonal indices
let indices = seasonalIndices(monthlyRevenue, periodsPerYear: 12)
// Result: [0.85, 0.90, 1.05, 1.10, 1.20, 1.15, 0.95, 0.90, 0.95, 1.05, 1.10, 1.15]
//         Jan   Feb   Mar   Apr   May   Jun   Jul   Aug   Sep   Oct   Nov   Dec

// Apply seasonal adjustment
let deseasonalized = seasonallyAdjust(monthlyRevenue, indices: indices)

// Decompose time series
let decomposition = decomposeTimeSeries(
    monthlyRevenue,
    periodsPerYear: 12,
    method: .multiplicative
)

let trend = decomposition.trend
let seasonal = decomposition.seasonal
let residual = decomposition.residual

// Project with seasonality
let baseProjection = linearModel.project(periods: 12)
let seasonalProjection = baseProjection.applySeasonal(indices: indices)
```

---

## 5. Real-World Scenarios

### Scenario A: SaaS Revenue Projection

```swift
// Historical MRR (Monthly Recurring Revenue)
let historicalMRR = TimeSeries<Double>.monthly(
    name: "MRR",
    units: "USD"
)
.from(year: 2024, month: 1)
.values([
    50000, 52500, 55125, 57881, 60775,
    63814, 67005, 70355, 73873, 77566,
    81444, 85516
])

// Calculate growth metrics
let avgMonthlyGrowth = historicalMRR.growthRate(lag: 1).mean()
print("Average MoM Growth: \(avgMonthlyGrowth * 100)%")

// Project next 12 months
let projection = applyGrowth(
    baseValue: historicalMRR.last!,
    rate: avgMonthlyGrowth,
    periods: 12,
    compounding: .monthly
)

// Build projection time series
let projectedMRR = TimeSeries<Double>.monthly(
    name: "Projected MRR",
    units: "USD"
)
.from(year: 2025, month: 1)
.values(projection)

// Calculate ARR (Annual Recurring Revenue)
let currentARR = historicalMRR.last! * 12
let projectedARR = projectedMRR.last! * 12

print("Current ARR: $\(currentARR)")
print("Projected ARR (1 year): $\(projectedARR)")
```

### Scenario B: Equipment Purchase Analysis

```swift
// Purchase decision: Buy equipment or lease?

// Purchase option
let purchasePrice: Double = 50000
let salvageValue: Double = 5000
let usefulLife = 5

// Lease option
let annualLeasePayment: Double = 12000

// Calculate NPV of lease payments
let discountRate = 0.08
let leaseCashFlows = Array(repeating: -annualLeasePayment, count: usefulLife)
let leaseNPV = npv(discountRate: discountRate, cashFlows: leaseCashFlows)

// Calculate NPV of purchase
let purchaseCashFlows = [-purchasePrice] + Array(repeating: 0.0, count: usefulLife - 1) + [salvageValue]
let purchaseNPV = npv(discountRate: discountRate, cashFlows: purchaseCashFlows)

// Compare
print("Lease NPV: $\(leaseNPV)")
print("Purchase NPV: $\(purchaseNPV)")

if purchaseNPV > leaseNPV {
    print("Recommendation: Purchase")
} else {
    print("Recommendation: Lease")
}
```

### Scenario C: Quarterly Revenue Forecast with Seasonality

```swift
// Historical quarterly revenue (3 years)
let quarters = (1...12).map { q in
    let year = 2022 + (q - 1) / 4
    let quarter = ((q - 1) % 4) + 1
    return Period.quarter(year: year, quarter: quarter)
}

let revenue = TimeSeries(
    periods: quarters,
    values: [
        850000, 920000, 1100000, 980000,  // 2022: Q1-Q4
        900000, 980000, 1200000, 1050000, // 2023: Q1-Q4
        980000, 1080000, 1350000, 1150000 // 2024: Q1-Q4
    ],
    metadata: TimeSeriesMetadata(name: "Quarterly Revenue", units: "USD")
)

// Calculate seasonal indices
let indices = seasonalIndices(revenue, periodsPerYear: 4)
// Typical pattern: [~0.85, ~0.95, ~1.30, ~1.00]
// Q1 is weak, Q2 better, Q3 peak (summer), Q4 strong

// Deseasonalize to find trend
let deseasonalized = seasonallyAdjust(revenue, indices: indices)

// Fit trend model
let trendModel = LinearTrend<Double>()
trendModel.fit(to: deseasonalized)

// Project next 4 quarters (without seasonality)
let trendProjection = trendModel.project(periods: 4)

// Apply seasonality back
let seasonalProjection = trendProjection.applySeasonal(indices: indices)

// Display forecast
for (period, value) in seasonalProjection.enumerated() {
    print("2025 Q\(period + 1): $\(value)")
}
```

### Scenario D: Investment Portfolio Valuation

```swift
// Initial investment
let initialInvestment: Double = 100000

// Historical returns (monthly)
let monthlyReturns: [Double] = [
    0.02, -0.01, 0.03, 0.015, -0.02, 0.025,
    0.01, 0.03, -0.015, 0.02, 0.01, 0.015
]

// Calculate portfolio values
var portfolioValues: [Double] = [initialInvestment]
for returnRate in monthlyReturns {
    let newValue = portfolioValues.last! * (1 + returnRate)
    portfolioValues.append(newValue)
}

// Create time series
let periods = (0...12).map { Period.month(year: 2024, month: max(1, $0)) }
let portfolio = TimeSeries(
    periods: Array(periods.prefix(13)),
    values: portfolioValues,
    metadata: TimeSeriesMetadata(name: "Portfolio Value", units: "USD")
)

// Calculate metrics
let finalValue = portfolio.last!
let totalReturn = (finalValue - initialInvestment) / initialInvestment
let annualReturn = cagr(
    beginningValue: initialInvestment,
    endingValue: finalValue,
    years: 1.0
)

print("Initial: $\(initialInvestment)")
print("Final: $\(finalValue)")
print("Total Return: \(totalReturn * 100)%")
print("Annualized Return: \(annualReturn * 100)%")

// Risk metrics
let returns = TimeSeries(
    periods: Array(periods.prefix(12)),
    values: monthlyReturns,
    metadata: TimeSeriesMetadata(name: "Monthly Returns")
)

let avgReturn = mean(monthlyReturns)
let volatility = stdDev(monthlyReturns, pop: .sample)
let sharpeRatio = avgReturn / volatility

print("Average Monthly Return: \(avgReturn * 100)%")
print("Monthly Volatility: \(volatility * 100)%")
print("Sharpe Ratio: \(sharpeRatio)")
```

### Scenario E: Break-Even Analysis Over Time

```swift
// Fixed costs
let monthlyFixedCosts: Double = 50000

// Variable costs per unit
let variableCostPerUnit: Double = 25

// Price per unit
let pricePerUnit: Double = 50

// Calculate break-even units
let contributionMargin = pricePerUnit - variableCostPerUnit
let breakEvenUnits = monthlyFixedCosts / contributionMargin

print("Break-even units per month: \(breakEvenUnits)")

// Project sales growth scenario
let initialSales: Double = 800  // units per month
let salesGrowthRate: Double = 0.10
let months = 12

let projectedSales = applyGrowth(
    baseValue: initialSales,
    rate: salesGrowthRate,
    periods: months,
    compounding: .monthly
)

// Calculate profitability over time
let periods = (1...months).map { Period.month(year: 2025, month: $0) }

let revenue = projectedSales.map { $0 * pricePerUnit }
let variableCosts = projectedSales.map { $0 * variableCostPerUnit }
let profit = revenue.map { $0 - monthlyFixedCosts - variableCosts[revenue.firstIndex(of: $0)!] }

let profitSeries = TimeSeries(
    periods: periods,
    values: profit,
    metadata: TimeSeriesMetadata(name: "Monthly Profit", units: "USD")
)

// Find break-even month
if let breakEvenMonth = profitSeries.periods.first(where: { profitSeries[$0]! >= 0 }) {
    print("Break-even achieved in: \(breakEvenMonth.label)")
} else {
    print("Break-even not achieved in projection period")
}

// Calculate cumulative profit
let cumulativeProfit = profit.reduce(into: [Double]()) { result, value in
    let last = result.last ?? 0
    result.append(last + value)
}

print("Cumulative profit after 12 months: $\(cumulativeProfit.last!)")
```

---

## Best Practices

### 1. Always Use Typed Periods
```swift
// Good
let jan = Period.month(year: 2025, month: 1)

// Avoid raw Date manipulation
// let jan = Date(...)  // Less clear intent
```

### 2. Leverage Metadata
```swift
let series = TimeSeries(
    periods: periods,
    values: values,
    metadata: TimeSeriesMetadata(
        name: "Revenue",
        units: "USD",
        category: "Sales"
    )
)
// Makes debugging and reporting much easier
```

### 3. Handle Missing Values Explicitly
```swift
// Good - explicit strategy
let filled = series.fillForward()

// Less good - implicit behavior
let value = series[period] ?? 0.0  // Why zero? Document this!
```

### 4. Use Appropriate Aggregation
```swift
// For revenue/costs - sum
let quarterlyRevenue = monthlyRevenue.aggregate(by: .quarterly, method: .sum)

// For prices/rates - average
let quarterlyPrice = monthlyPrice.aggregate(by: .quarterly, method: .average)

// For ending balances - last
let quarterlyBalance = dailyBalance.aggregate(by: .quarterly, method: .last)
```

### 5. Validate Financial Calculations
```swift
// Always validate NPV and IRR results
let npv = npv(discountRate: rate, cashFlows: flows)
assert(!npv.isNaN && !npv.isInfinite, "Invalid NPV calculation")

// Check IRR convergence
do {
    let irr = try irr(cashFlows: flows)
    print("IRR: \(irr * 100)%")
} catch IRRError.convergenceFailed {
    print("IRR did not converge - check cash flows")
}
```

---

## Related Documents

- [Master Plan](00_MASTER_PLAN.md)
- [Coding Rules](01_CODING_RULES.md)
- [DocC Guidelines](03_DOCC_GUIDELINES.md)
- [Implementation Checklist](04_IMPLEMENTATION_CHECKLIST.md)
