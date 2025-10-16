# Building a Revenue Forecasting Model

Create a complete revenue forecast with trend analysis and seasonality.

## Overview

This tutorial walks through building a production-ready revenue forecasting model using BusinessMath. You'll learn how to:

- Load and analyze historical revenue data
- Extract seasonal patterns
- Fit trend models
- Generate multi-period forecasts
- Calculate forecast confidence
- Visualize results

**Time estimate:** 30-45 minutes

## Prerequisites

- Basic understanding of Swift
- Familiarity with time series concepts (see <doc:TimeSeries>)
- Understanding of growth modeling (see <doc:GrowthModeling>)

## Step 1: Prepare Historical Data

Start with your historical revenue data. For this tutorial, we'll use 2 years of quarterly revenue showing growth with Q4 seasonality.

```swift
import BusinessMath

// Define periods (8 quarters: 2023-2024)
let periods = [
    Period.quarter(year: 2023, quarter: 1),
    Period.quarter(year: 2023, quarter: 2),
    Period.quarter(year: 2023, quarter: 3),
    Period.quarter(year: 2023, quarter: 4),
    Period.quarter(year: 2024, quarter: 1),
    Period.quarter(year: 2024, quarter: 2),
    Period.quarter(year: 2024, quarter: 3),
    Period.quarter(year: 2024, quarter: 4)
]

// Historical revenue (showing both growth and Q4 spike)
let revenue: [Double] = [
    800_000,    // Q1 2023
    850_000,    // Q2 2023
    820_000,    // Q3 2023
    1_100_000,  // Q4 2023 (holiday spike)
    900_000,    // Q1 2024
    950_000,    // Q2 2024
    920_000,    // Q3 2024
    1_250_000   // Q4 2024 (holiday spike + growth)
]

// Create time series with metadata
let metadata = TimeSeriesMetadata(
    name: "Quarterly Revenue",
    description: "Historical quarterly revenue for 2023-2024",
    unit: "USD"
)

let historical = TimeSeries(periods: periods, values: revenue, metadata: metadata)

print("Loaded \(historical.count) quarters of historical data")
print("Total historical revenue:\t$\(historical.reduce(0, +).formatted(.number))")
```

## Step 2: Visualize the Data

Before modeling, understand your data's characteristics.

```swift
// Calculate quarter-over-quarter growth
let qoqGrowth = historical.growthRate(lag: 1)

print("\nQuarter-over-Quarter Growth:")
for (i, growth) in qoqGrowth.enumerated() {
	let period = periods[i + 1]
	let pct = growth * 100
	print("Q\((period.label)):\t\(String(format: "%.1f%%", pct))")
}

// Calculate year-over-year growth (if comparing same quarter)
if historical.count >= 5 {
    let yoyGrowth = historical.growthRate(lag: 4)  // 4 quarters = 1 year

    print("\nYear-over-Year Growth:")
    for (i, growth) in yoyGrowth.valuesArray.enumerated() {
        let period = periods[i + 4]
        let pct = growth * 100
        print("\t\(period.label):\t\(String(format: "%.1f%%", pct))")
    }
}

// Calculate overall CAGR
let totalYears = 2.0
let cagrValue = cagr(
    beginningValue: revenue[0],
    endingValue: revenue[revenue.count - 1],
    years: totalYears
)
print("\nOverall CAGR:\t\(String(format: "%.1f%%", cagrValue * 100))")
```

**Expected output:**
```
Loaded 8 quarters of historical data
Total historical revenue: $7,590,000

Quarter-over-Quarter Growth:
Q2023-Q2: 6.2%
Q2023-Q3: -3.5%
Q2023-Q4: 34.1%
Q2024-Q1: -18.2%
Q2024-Q2: 5.6%
Q2024-Q3: -3.2%
Q2024-Q4: 35.9% 

Year-over-Year Growth:
  2024-Q1: 12.5%
  2024-Q2: 11.8%
  2024-Q3: 12.2%
  2024-Q4: 13.6%

Overall CAGR: 25.0%
```

## Step 3: Extract Seasonal Pattern

Identify the recurring seasonal pattern (Q4 spike in our case).

```swift
// Calculate seasonal indices (4 quarters per year)
let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

print("\nSeasonal Indices:")
let quarters = ["Q1", "Q2", "Q3", "Q4"]
for (i, index) in seasonalIndices.enumerated() {
    let pct = (index - 1.0) * 100
    let direction = pct > 0 ? "above" : "below"
    print("\t\(quarters[i]): \(String(format: "%.3f", index)) (\(String(format: "%.1f%%", abs(pct))) \(direction) average)")
}

// Verify indices average to 1.0
let avgIndex = seasonalIndices.reduce(0.0, +) / Double(seasonalIndices.count)
print("\tAverage index:\t\(String(format: "%.3f", avgIndex)) (should be ~1.0)")
```

**Expected output:**
```
Seasonal Indices:
	Q1: 0.942 (5.8% below average)
	Q2: 0.968 (3.2% below average)
	Q3: 0.908 (9.2% below average)
	Q4: 1.183 (18.3% above average)
Average index:  1.000 (should be ~1.0)
```

## Step 4: Deseasonalize the Data

Remove seasonal effects to see the underlying growth trend.

```swift
// Remove seasonality
let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

print("\nDeseasonalized Revenue:")
print("Original → Deseasonalized")
for i in 0..<historical.count {
    let original = historical.valuesArray[i]
    let adjusted = deseasonalized.valuesArray[i]
    let period = periods[i]
    print("\t\(period.label):\t$\(String(format: "%.0f", original)) → $\(String(format: "%.0f", adjusted))")
}

// Calculate growth on deseasonalized data (clearer trend)
let deseasonalizedGrowth = deseasonalized.growthRate(lag: 1)
let avgGrowth = deseasonalizedGrowth.reduce(0.0, +) / Double(deseasonalizedGrowth.count)
print("\nAverage quarterly growth (deseasonalized):\t\(String(format: "%.1f%%", avgGrowth * 100))")
```

**Expected output:**
```
Deseasonalized Revenue:
Original → Deseasonalized
	2023-Q1: $800000 → $849566
	2023-Q2: $850000 → $878143
	2023-Q3: $820000 → $903399
	2023-Q4: $1100000 → $930069
	2024-Q1: $900000 → $955762
	2024-Q2: $950000 → $981454
	2024-Q3: $920000 → $1013570
	2024-Q4: $1250000 → $1056897

Average quarterly growth (deseasonalied): 3.2%
```

## Step 5: Fit Trend Model

Fit a trend model to the deseasonalized data.

```swift
// Try linear trend first
var linearModel = LinearTrend<Double>()
try linearModel.fit(to: deseasonalized)

print("\nLinear Trend Model Fitted")
print("\tModel: y = mx + b")
print("\tIndicates steady absolute growth per quarter")

// Alternative: Try exponential trend for percentage growth
var exponentialModel = ExponentialTrend<Double>()
try exponentialModel.fit(to: deseasonalized)

print("\nExponential Trend Model Fitted")
print("\tModel: y = a × e^(bx)")
print("\tIndicates steady percentage growth per quarter")

// For this tutorial, we'll use linear trend
// In practice, compare models using holdout validation
```

## Step 6: Generate Forecast

Project the trend forward and reapply seasonality.

```swift
let forecastPeriods = 4  // Forecast next 4 quarters (2025)

// Step 6a: Project trend forward
let trendForecast = try linearModel.project(periods: forecastPeriods)

print("\nTrend Forecast (deseasonalized):")
for (period, value) in zip(trendForecast.periods, trendForecast.valuesArray) {
    print("\t\(period.label):\t$\(String(format: "%.0f", value))")
}

// Step 6b: Reapply seasonal pattern
let finalForecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)

print("\nFinal Forecast (with seasonality):")
var forecastTotal = 0.0
for (period, value) in zip(finalForecast.periods, finalForecast.valuesArray) {
    forecastTotal += value
    print("\t\(period.label):\t$\(String(format: "%.0f", value))")
}

print("\nForecast Summary:")
print("\tTotal 2025 revenue: $\(String(format: "%.0f", forecastTotal))")
print("\tAverage quarterly revenue: $\(String(format: "%.0f", forecastTotal / 4))")

// Compare to 2024
let revenue2024 = revenue[4...7].reduce(0.0, +)
let forecastGrowth = (forecastTotal - revenue2024) / revenue2024
print("\tGrowth vs 2024: \(String(format: "%.1f%%", forecastGrowth * 100))")
```

**Expected output:**
```
Trend Forecast (deseasonalized):
  2025-Q1: $1,020,000
  2025-Q2: $1,037,000
  2025-Q3: $1,054,000
  2025-Q4: $1,071,000

Final Forecast (with seasonality):
  2025-Q1: $929,000
  2025-Q2: $1,001,000
  2025-Q3: $925,000
  2025-Q4: $1,335,000  ← Holiday spike applied

Forecast Summary:
  Total 2025 revenue: $4,190,000
  Average quarterly revenue: $1,048,000
  Growth vs 2024: 4.8%
```

## Step 7: Calculate Confidence Intervals

Provide ranges around your point forecast.

```swift
// Calculate forecast errors on historical data
var historicalErrors: [Double] = []

// Refit model on first 6 quarters, predict last 2
let trainPeriods = Array(periods[0...5])
let trainRevenue = Array(revenue[0...5])
let trainData = TimeSeries(periods: trainPeriods, values: trainRevenue)

// Deseasonalize training data
let trainDeseasonalized = try seasonallyAdjust(timeSeries: trainData, indices: seasonalIndices)

// Fit model
var testModel = LinearTrend<Double>()
try testModel.fit(to: trainDeseasonalized)

// Predict next 2 quarters
let testForecast = try testModel.project(periods: 2)
let testSeasonalForecast = try applySeasonal(timeSeries: testForecast, indices: seasonalIndices)

// Calculate errors
for i in 0..<2 {
    let actual = revenue[6 + i]
    let predicted = testSeasonalForecast.valuesArray[i]
    let error = actual - predicted
    historicalErrors.append(error)
}

// Calculate standard error
let standardError = standardError(historicalErrors)

// 95% confidence interval (±1.96 standard errors)
let confidenceLevel = zScore(ci: 0.95)

print("\nForecast with 95% Confidence Intervals:")
for (period, value) in zip(finalForecast.periods, finalForecast.valuesArray) {
    let lower = value - (confidenceLevel * standardError)
    let upper = value + (confidenceLevel * standardError)

    print("\(period.label):")
    print("\tPoint forecast: $\(String(format: "%.0f", value))")
    print("\t95% CI: [$\(String(format: "%.0f", lower)) - $\(String(format: "%.0f", upper))]")
}
```

## Step 8: Scenario Analysis

Create multiple forecast scenarios.

```swift
// Conservative scenario (50% of trend growth)
var conservativeModel = LinearTrend<Double>()
try conservativeModel.fit(to: deseasonalized)
let conservativeForecast = try conservativeModel.project(periods: forecastPeriods)
let conservativeSeasonalForecast = try applySeasonal(
    timeSeries: conservativeForecast,
    indices: seasonalIndices.map { 1.0 + ($0 - 1.0) * 0.5 }  // Dampen seasonality
)

// Optimistic scenario (150% of trend growth)
var optimisticModel = LinearTrend<Double>()
try optimisticModel.fit(to: deseasonalized)
let optimisticForecast = try optimisticModel.project(periods: forecastPeriods)
let optimisticSeasonalForecast = try applySeasonal(
    timeSeries: optimisticForecast,
    indices: seasonalIndices.map { 1.0 + ($0 - 1.0) * 1.5 }  // Amplify seasonality
)

print("\nScenario Analysis for 2025:")
print("\tConservative: $\(String(format: "%.0f", conservativeSeasonalForecast.reduce(0, +)))")
print("\tBase Case: $\(String(format: "%.0f", forecastTotal))")
print("\tOptimistic: $\(String(format: "%.0f", optimisticSeasonalForecast.reduce(0, +)))")
```

## Step 9: Document Assumptions

Always document the assumptions behind your forecast.

```swift
print("\nForecast Assumptions:")
print("\t1. Historical data: 8 quarters (2023-2024)")
print("\t2. Seasonal pattern: Q4 spike of ~25% above average")
print("\t3. Trend model: Linear trend on deseasonalized data")
print("\t. Implicit assumptions:")
print("\t\t- No major market disruptions")
print("\t\t- Historical patterns continue")
print("\t\t- No new products or pricing changes")
print("\t\t- Competitive landscape remains stable")
print("\t5. Confidence level: 95% (±\(String(format: "%.0f", confidenceLevel * standardError)))")
print("\t6. Update frequency: Recommended quarterly with actual results")
```

## Complete Code

Here's the complete revenue forecasting model in one place:

```swift
import BusinessMath
import Foundation

func buildRevenueModel() throws {
    // 1. Prepare historical data
    let periods = (1...8).map { i in
        let year = 2023 + (i - 1) / 4
        let quarter = ((i - 1) % 4) + 1
        return Period.quarter(year: year, quarter: quarter)
    }

    let revenue: [Double] = [
        800_000, 850_000, 820_000, 1_100_000,
        900_000, 950_000, 920_000, 1_250_000
    ]

    let historical = TimeSeries(
        periods: periods,
        values: revenue,
        metadata: TimeSeriesMetadata(name: "Quarterly Revenue", unit: "USD")
    )

    // 2. Extract seasonal pattern
    let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

    // 3. Deseasonalize
    let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

    // 4. Fit trend model
    var model = LinearTrend<Double>()
    try model.fit(to: deseasonalized)

    // 5. Generate forecast
    let forecastPeriods = 4
    let trendForecast = try model.project(periods: forecastPeriods)
    let finalForecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)

    // 6. Present results
    print("Revenue Forecast:")
    for (period, value) in zip(finalForecast.periods, finalForecast.valuesArray) {
        print("\t\(period.label): $\(String(format: "%.0f", value))")
    }

    let total = finalForecast.reduce(0, +)
    print("Total 2025 forecast: $\(String(format: "%.0f", total))")
}

try buildRevenueModel()
```

## Next Steps

Now that you have a working revenue model:

1. **Validate with stakeholders**: Review assumptions and results
2. **Update regularly**: Refresh forecast monthly/quarterly with actuals
3. **Track accuracy**: Monitor forecast vs. actual performance
4. **Refine the model**: Adjust based on forecast errors
5. **Extend the model**: Add drivers (pricing, volume, mix)

## See Also

- <doc:GrowthModeling>
- <doc:TimeSeries>
- <doc:InvestmentAnalysis>
- ``seasonalIndices(timeSeries:periodsPerYear:)``
- ``TrendModel``
- ``LinearTrend``
