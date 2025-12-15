# Growth Modeling and Forecasting

Analyze trends, model growth patterns, and forecast future values.

## Overview

Growth modeling is essential for business planning, revenue forecasting, and strategic decision-making. BusinessMath provides three complementary approaches:

- **Growth Rates**: Calculate simple and compound growth rates (CAGR)
- **Trend Models**: Fit mathematical models to historical data
- **Seasonality**: Extract and apply seasonal patterns

Combined, these tools enable sophisticated forecasting that accounts for both long-term trends and recurring patterns.

## Growth Rates

Growth rates measure the rate of change between values.

### Simple Growth Rate

```swift
// Revenue grew from $100k to $120k
let growth = growthRate(from: 100_000, to: 120_000)
// Result: 0.20 (20% growth)

// Negative growth (decline)
let decline = growthRate(from: 120_000, to: 100_000)
// Result: -0.1667 (-16.67% decline)
```

**Formula:**

```
Growth Rate = (Ending Value - Beginning Value) / Beginning Value
            = (Ending / Beginning) - 1
```

### Compound Annual Growth Rate (CAGR)

CAGR smooths out volatility to show steady equivalent growth:

```swift
// Revenue trajectory: $100k → $110k → $125k → $150k over 3 years
let compoundGrowth = cagr(
    beginningValue: 100_000,
    endingValue: 150_000,
    years: 3
)
// Result: ~0.1447 (14.47% per year)

// Verify: does 14.47% compound for 3 years give $150k?
let verification = 100_000 * pow(1.1447, 3)
// Result: ~150,000 ✓
```

**Formula:**

```
CAGR = (Ending Value / Beginning Value)^(1/years) - 1
```

### Applying Growth

Project future values using growth rates:

```swift
// Project $100k base with 15% annual growth for 5 years
let projection = applyGrowth(
    baseValue: 100_000,
    rate: 0.15,
    periods: 5,
    compounding: .annual
)
// Result: [100k, 115k, 132.25k, 152.09k, 174.90k, 201.14k]
```

### Compounding Frequencies

Different compounding frequencies affect growth:

```swift
let base = 100_000.0
let rate = 0.12  // 12% annual rate
let years = 5

// Annual compounding
let annual = applyGrowth(baseValue: base, rate: rate, periods: years, compounding: .annual)
// Final: ~176,234

// Quarterly compounding (12%/4 = 3% per quarter, 20 quarters)
let quarterly = applyGrowth(baseValue: base, rate: rate, periods: years * 4, compounding: .quarterly)
// Final: ~180,611 (higher due to more frequent compounding)

// Monthly compounding (12%/12 = 1% per month, 60 months)
let monthly = applyGrowth(baseValue: base, rate: rate, periods: years * 12, compounding: .monthly)
// Final: ~181,670

// Daily compounding
let daily = applyGrowth(baseValue: base, rate: rate, periods: years * 365, compounding: .daily)
// Final: ~182,194

// Continuous compounding (e^(rt))
let continuous = applyGrowth(baseValue: base, rate: rate, periods: years, compounding: .continuous)
// Final: ~182,212 (theoretical maximum)
```

### Real-World Applications

**Revenue Growth Analysis:**

```swift
// Q1 2024: $500k, Q1 2025: $650k
let quarterlyGrowth = growthRate(from: 500_000, to: 650_000)
// Result: 30% year-over-year growth

// Project next 4 quarters at this rate
let forecast = applyGrowth(
    baseValue: 650_000,
    rate: 0.30 / 4,  // Quarterly rate
    periods: 4,
    compounding: .quarterly
)
```

**Population Growth:**

```swift
// City grew from 100k to 125k residents over 5 years
let populationCAGR = cagr(beginningValue: 100_000, endingValue: 125_000, years: 5)
// Result: ~4.56% per year

// Project 10 years forward
let population2035 = 125_000 * pow(1.0456, 10)
// Result: ~195,312 residents
```

**Investment Returns:**

```swift
// Portfolio: $50k → $87k over 8 years
let investmentReturn = cagr(beginningValue: 50_000, endingValue: 87_000, years: 8)
// Result: ~7.0% per year (good long-term return)
```

## Trend Models

Trend models fit mathematical functions to historical data for forecasting.

### Linear Trend

Linear trends model constant absolute growth:

```swift
// Historical revenue shows steady ~$5k/month increase
let periods = (1...12).map { Period.month(year: 2024, month: $0) }
let revenue: [Double] = [100, 105, 110, 108, 115, 120, 118, 125, 130, 128, 135, 140]

let historical = TimeSeries(periods: periods, values: revenue)

// Fit linear trend
var trend = LinearTrend<Double>()
try trend.fit(to: historical)

// Project 6 months forward
let forecast = try trend.project(periods: 6)
// Result: [142, 145, 148, 152, 155, 159] (approximately)
```

**Formula:**

```
y = mx + b

Where:
- y = predicted value
- m = slope (rate of change)
- x = time index
- b = intercept (starting value)
```

**Best for:**
- Steady absolute growth (e.g., adding same number of customers each month)
- Short-term forecasts
- Linear relationships

### Exponential Trend

Exponential trends model constant percentage growth:

```swift
// Revenue doubling every few years
let periods = (0..<10).map { Period.year(2015 + $0) }
let revenue: [Double] = [100, 115, 130, 155, 175, 200, 235, 265, 310, 350]

let historical = TimeSeries(periods: periods, values: revenue)

// Fit exponential trend
var trend = ExponentialTrend<Double>()
try trend.fit(to: historical)

// Project 5 years forward
let forecast = try trend.project(periods: 5)
// Result: Continues exponential growth pattern
```

**Formula:**

```
y = a × e^(bx)

Where:
- y = predicted value
- a = initial value
- b = growth rate
- x = time index
- e = Euler's number (2.71828...)
```

**Best for:**
- Constant percentage growth (e.g., 15% per year)
- Long-term trends
- Compound growth scenarios

### Logistic Trend

Logistic trends model growth that approaches a capacity limit (S-curve):

```swift
// User adoption starts slow, accelerates, then plateaus
let periods = (0..<24).map { Period.month(year: 2023 + $0/12, month: ($0 % 12) + 1) }
let users: [Double] = [100, 150, 250, 400, 700, 1200, 2000, 3500, 5500, 8000,
                        11000, 14000, 17000, 19500, 21500, 23000, 24000, 24500,
                        24800, 24900, 24950, 24970, 24985, 24990]

let historical = TimeSeries(periods: periods, values: users)

// Fit logistic trend with capacity of 25,000 users
var trend = LogisticTrend<Double>(capacity: 25_000)
try trend.fit(to: historical)

// Project 12 months forward
let forecast = try trend.project(periods: 12)
// Result: Approaches but never exceeds 25,000
```

**Formula:**

```
y = L / (1 + e^(-k(x-x₀)))

Where:
- y = predicted value
- L = capacity (maximum value)
- k = growth rate
- x = time index
- x₀ = midpoint of curve
```

**Best for:**
- Market saturation scenarios
- Product adoption curves
- Biological growth (population with carrying capacity)
- SaaS user growth with market limits

### Custom Trend

Define custom trend functions:

```swift
// Custom quadratic trend: y = 0.5x² + 10x + 100
// For playgrounds, define the closure separately with explicit type
let quadraticFunction: @Sendable (Double) -> Double = { x in
    return 0.5 * x * x + 10.0 * x + 100.0
}

var trend = CustomTrend<Double>(trendFunction: quadraticFunction)

// Fit to historical data to set metadata
let historical = TimeSeries(
    periods: [Period.month(year: 2025, month: 1)],
    values: [100.0]
)
try trend.fit(to: historical)

// Project future values using the custom function
let forecast = try trend.project(periods: 12)
```

### Comparing Trends

Evaluate which model fits best:

```swift
let historical = TimeSeries(periods: periods, values: values)

// Fit multiple models
var linear = LinearTrend<Double>()
try linear.fit(to: historical)

var exponential = ExponentialTrend<Double>()
try exponential.fit(to: historical)

var logistic = LogisticTrend<Double>(capacity: 10_000)
try logistic.fit(to: historical)

// Compare on holdout data
let trainData = historical.range(from: periods[0], to: periods[8])
let testData = historical.range(from: periods[9], to: periods[11])

// Fit on training data, evaluate on test data
var linearModel = LinearTrend<Double>()
try linearModel.fit(to: trainData)
let linearForecast = try linearModel.project(periods: 3)

// Calculate RMSE or MAE for each model
// Choose model with lowest error
```

## Seasonality

Seasonality captures recurring patterns (weekly, monthly, quarterly, annual).

### Seasonal Indices

Calculate seasonal factors:

```swift
// Quarterly revenue with Q4 holiday spike
let periods = (0..<12).map { Period.quarter(year: 2022 + $0/4, quarter: ($0 % 4) + 1) }
let revenue: [Double] = [100, 120, 110, 150,  // 2022
                         105, 125, 115, 160,  // 2023
                         110, 130, 120, 170]  // 2024

let ts = TimeSeries(periods: periods, values: revenue)

// Calculate seasonal indices (4 quarters per year)
let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: 4)
// Result: [~0.85, ~1.00, ~0.91, ~1.24]
// Q1: 16% below average
// Q2: 1% above average
// Q3: 7% below average
// Q4: 22% above average (holiday season!)
```

**Interpretation:**
- Index = 1.0: Average seasonal performance
- Index > 1.0: Above average (peak season)
- Index < 1.0: Below average (off season)

### Seasonal Adjustment

Remove seasonality to see underlying trend:

```swift
// Remove seasonal effects
let deseasonalized = try seasonallyAdjust(timeSeries: ts, indices: indices)

// Original: [100, 120, 110, 150, ...]
// Deseasonalized: [~119, ~119, ~118, ~123, ...]
// Now you can see the true trend without seasonal noise
```

**Use cases:**
- Compare performance across different seasons fairly
- Identify true growth vs. seasonal effects
- Fit trend models to deseasonalized data

### Applying Seasonal Patterns

Add seasonality back to forecasts:

```swift
// Project deseasonalized trend forward
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)
let trendForecast = try trend.project(periods: 4)

// Reapply seasonal pattern
let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)
// Result: Trend forecast × seasonal indices = realistic forecast
```

### Time Series Decomposition

Separate time series into components:

```swift
let decomposition = try decomposeTimeSeries(
    timeSeries: ts,
    periodsPerYear: 4,
    method: .multiplicative
)

print("Trend:", decomposition.trend.valuesArray)
// Long-term direction (increasing, decreasing, flat)

print("Seasonal:", decomposition.seasonal.valuesArray)
// Recurring patterns (same each cycle)

print("Residual:", decomposition.residual.valuesArray)
// Random noise (what's left after removing trend and seasonal)
```

**Multiplicative decomposition:**

```
Actual = Trend × Seasonal × Residual
```

Use when seasonal variation proportional to level (e.g., 20% spike in Q4).

**Additive decomposition:**

```
Actual = Trend + Seasonal + Residual
```

Use when seasonal variation is constant (e.g., +$10k in Q4).

### Real-World Seasonality Examples

**Retail Sales:**

```swift
// High seasonality: Back-to-school (Q3), Holidays (Q4)
let retailIndices = [0.85, 0.90, 1.10, 1.15]  // Q1-Q4
```

**SaaS Metrics:**

```swift
// Moderate seasonality: Lower in summer (Q3), higher year-end (Q4)
let saasIndices = [1.02, 1.03, 0.92, 1.03]  // Q1-Q4
```

**Ice Cream Sales:**

```swift
// Extreme seasonality: Summer peak
let iceCreamIndices = [0.60, 1.10, 1.50, 0.80]  // Q1-Q4
```

**B2B Software:**

```swift
// Minimal seasonality: Enterprise sales relatively stable
let b2bIndices = [0.98, 1.01, 0.99, 1.02]  // Q1-Q4
```

## Complete Forecasting Workflow

Combine all techniques for robust forecasting:

```swift
// 1. Load historical data
let historical = TimeSeries(periods: historicalPeriods, values: historicalRevenue)

// 2. Extract seasonal pattern
let seasonalIndices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)

// 3. Deseasonalize to reveal underlying trend
let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: seasonalIndices)

// 4. Fit trend model to deseasonalized data
var trend = LinearTrend<Double>()
try trend.fit(to: deseasonalized)

// 5. Project trend forward
let forecastPeriods = 4  // Next 4 quarters
let trendForecast = try trend.project(periods: forecastPeriods)

// 6. Reapply seasonality to trend forecast
let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: seasonalIndices)

// 7. Calculate confidence intervals (simple approach)
let residuals = /* Calculate residuals from historical fit */
let stdError = /* Standard deviation of residuals */
let confidenceInterval = 1.96 * stdError  // 95% confidence

// 8. Present forecast with ranges
for (period, value) in zip(seasonalForecast.periods, seasonalForecast.valuesArray) {
    let lower = value - confidenceInterval
    let upper = value + confidenceInterval
    print("\(period.label): \(value) [\(lower) - \(upper)]")
}
```

## Choosing the Right Approach

### Decision Tree

**Step 1: Does your data have seasonality?**
- Yes → Extract seasonal pattern first
- No → Skip to trend modeling

**Step 2: What kind of growth pattern?**
- Constant absolute growth ($X per period) → Linear Trend
- Constant percentage growth (X% per period) → Exponential Trend
- Growth approaching limit → Logistic Trend
- Complex pattern → Custom Trend or multiple models

**Step 3: How much history do you have?**
- < 2 full cycles → Use simple growth rates
- 2-3 cycles → Linear or exponential trend
- 3+ cycles → Full decomposition with seasonality

**Step 4: What's your forecast horizon?**
- Short-term (1-3 periods) → Any model works
- Medium-term (4-8 periods) → Trend models with seasonality
- Long-term (9+ periods) → Be cautious, validate assumptions

### Model Selection Guidelines

**Linear Trend:**
```swift
// Use when: Adding constant absolute amount each period
// Examples: Headcount growth, facility expansion
// Caution: Unrealistic for long-term (no limits)
```

**Exponential Trend:**
```swift
// Use when: Growing by constant percentage
// Examples: Revenue, user base, compound metrics
// Caution: Can explode unrealistically (no limits)
```

**Logistic Trend:**
```swift
// Use when: Growth has natural limit
// Examples: Market share, user adoption, saturation
// Caution: Requires good capacity estimate
```

**Seasonal + Trend:**
```swift
// Use when: Data has recurring patterns
// Examples: Retail sales, subscription metrics
// Caution: Requires 2+ full cycles of history
```

## Best Practices

### Validate Assumptions

```swift
// Check if exponential growth is reasonable
let currentRevenue = 1_000_000.0
let growthRate = 0.50  // 50% per year
let projection10y = currentRevenue * pow(1.50, 10)
// Result: $57.7M

// Is this realistic for your market?
// What would market share be?
// Are there capacity constraints?
```

### Use Multiple Scenarios

```swift
// Conservative scenario (5% growth)
let conservativeForecast = applyGrowth(baseValue: 1_000_000, rate: 0.05, periods: 5, compounding: .annual)

// Base case scenario (10% growth)
let baseForecast = applyGrowth(baseValue: 1_000_000, rate: 0.10, periods: 5, compounding: .annual)

// Optimistic scenario (15% growth)
let optimisticForecast = applyGrowth(baseValue: 1_000_000, rate: 0.15, periods: 5, compounding: .annual)

// Present all three with probabilities
```

### Backtest Your Models

```swift
// Split historical data
let allData = TimeSeries(periods: allPeriods, values: allValues)
let trainEnd = allPeriods[allPeriods.count - 4]  // Hold out last 4 periods

let trainData = allData.range(from: allPeriods[0], to: trainEnd)
let testData = allData.range(from: trainEnd + 1, to: allPeriods.last!)

// Fit on training data
var model = LinearTrend<Double>()
try model.fit(to: trainData)

// Predict test period
let predictions = try model.project(periods: 4)

// Compare to actual
// If predictions way off, model may not work for future either
```

### Update Regularly

```swift
// Don't set and forget!
// Update forecasts monthly/quarterly with latest data

let newData = TimeSeries(periods: newPeriods, values: newValues)

// Refit model
var updatedModel = LinearTrend<Double>()
try updatedModel.fit(to: newData)

// Generate updated forecast
let updatedForecast = try updatedModel.project(periods: forecastHorizon)
```

## See Also

- <doc:GettingStarted>
- <doc:TimeSeries>
- <doc:BuildingRevenueModel>
- ``TrendModel``
- ``LinearTrend``
- ``ExponentialTrend``
- ``LogisticTrend``
- ``seasonalIndices(timeSeries:periodsPerYear:)``
- ``decomposeTimeSeries(timeSeries:periodsPerYear:method:)``
