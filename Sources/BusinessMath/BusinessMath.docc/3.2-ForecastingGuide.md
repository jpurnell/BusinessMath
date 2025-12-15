# Time Series Forecasting

Predict future values using statistical forecasting methods with BusinessMath.

## Overview

Forecasting is essential for business planning. BusinessMath provides battle-tested forecasting algorithms that help you predict future sales, demand, costs, and other business metrics.

This guide covers:
- Holt-Winters triple exponential smoothing for seasonal data
- Moving average forecasts for trend identification
- Anomaly detection for unusual patterns
- Confidence intervals for forecast uncertainty

## Holt-Winters Forecasting

Holt-Winters is one of the most widely used forecasting methods. It handles three components: level, trend, and seasonality.

### Monthly Sales Forecast

```swift
import BusinessMath

// Historical monthly sales (2 years)
let months = (1...24).map { Period.month(year: 2023 + ($0 - 1) / 12, month: (($0 - 1) % 12) + 1) }
let sales: [Double] = [
    // Year 1
    100, 110, 95, 105, 115, 125, 140, 135, 120, 110, 130, 150,
    // Year 2
    105, 115, 100, 110, 120, 130, 145, 140, 125, 115, 135, 155
]

let salesTimeSeries = TimeSeries(
    periods: months,
    values: sales,
    metadata: TimeSeriesMetadata(name: "Monthly Sales", unit: "Units")
)

// Create Holt-Winters model
let model = HoltWintersModel(
    alpha: 0.2,  // Level smoothing
    beta: 0.1,   // Trend smoothing
    gamma: 0.1,  // Seasonal smoothing
    seasonalPeriods: 12  // Monthly data with annual seasonality
)

// Generate forecast
let forecast = model.forecast(
    timeSeries: salesTimeSeries,
    periods: 6  // Predict next 6 months
)

print("6-month forecast:")
for (period, value) in zip(forecast.periods, forecast.values) {
    print("\(period.label): \(Int(value)) units")
}
```

### Revenue Forecast with Confidence Intervals

```swift
// Forecast with uncertainty bounds
let revenueTimeSeries = TimeSeries(
    periods: months,
    values: sales.map { $0 * 299.99 },  // $299.99 per unit
    metadata: TimeSeriesMetadata(name: "Revenue", unit: "USD")
)

let revenueForecast = model.forecastWithConfidence(
    timeSeries: revenueTimeSeries,
    periods: 12,
    confidenceLevel: 0.95
)

print("\n12-month revenue forecast:")
for i in 0..<12 {
    let period = revenueForecast.periods[i]
    let forecast = revenueForecast.forecasts[i]
    let lower = revenueForecast.lowerBounds[i]
    let upper = revenueForecast.upperBounds[i]

    print("\(period.label):")
    print("  Forecast: $\(Int(forecast))")
    print("  95% CI: [$\(Int(lower)), $\(Int(upper))]")
}
```

## Moving Average Forecasts

Moving averages smooth out short-term fluctuations to reveal underlying trends.

### Simple Moving Average

```swift
// 3-month moving average for trend identification
let sma = salesTimeSeries.movingAverage(window: 3)

print("Last 6 months - Actual vs Trend:")
for i in (sales.count - 6)..<sales.count {
    print("\(months[i].label): Actual \(sales[i]), Trend \(Int(sma.values[i]))")
}
```

### Weighted Moving Average

```swift
// Weight recent months more heavily
let weights = [0.5, 0.3, 0.2]  // Most recent = 50%, then 30%, then 20%

func weightedForecast(history: [Double], weights: [Double]) -> Double {
    let recent = Array(history.suffix(weights.count))
    return zip(recent.reversed(), weights).map(*).reduce(0, +)
}

let nextMonthForecast = weightedForecast(history: sales, weights: weights)
print("Next month forecast (weighted): \(Int(nextMonthForecast)) units")
```

## Anomaly Detection

Identify unusual values that don't fit the pattern.

### Statistical Anomaly Detection

```swift
let anomalyDetector = AnomalyDetector(sensitivity: 2.5)

// Detect anomalies in sales data
let anomalies = anomalyDetector.detect(timeSeries: salesTimeSeries)

if !anomalies.isEmpty {
    print("Anomalies detected:")
    for anomaly in anomalies {
        print("\(anomaly.period.label): \(anomaly.value) (expected: \(Int(anomaly.expectedValue)))")
        print("  Deviation: \(anomaly.standardDeviations) standard deviations")
    }
} else {
    print("No anomalies detected - data follows expected pattern")
}
```

### Business Rule Anomalies

```swift
// Flag months where sales dropped >20% from prior month
func detectDrops(sales: [Double], threshold: Double = 0.20) -> [(month: Int, drop: Double)] {
    var drops: [(Int, Double)] = []

    for i in 1..<sales.count {
        let change = (sales[i] - sales[i-1]) / sales[i-1]
        if change < -threshold {
            drops.append((i, change))
        }
    }

    return drops
}

let significantDrops = detectDrops(sales: sales)
if !significantDrops.isEmpty {
    print("\nSignificant sales drops:")
    for (month, drop) in significantDrops {
        print("\(months[month].label): \(Int(drop * 100))% decrease")
    }
}
```

## Forecast Accuracy

Measure how good your forecasts are.

### Mean Absolute Percentage Error (MAPE)

```swift
func calculateMAPE(actual: [Double], forecast: [Double]) -> Double {
    let errors = zip(actual, forecast).map { abs(($0 - $1) / $0) }
    return mean(errors) * 100  // As percentage
}

// Hold out last 6 months for validation
let trainData = Array(sales.prefix(18))
let testData = Array(sales.suffix(6))

let trainPeriods = Array(months.prefix(18))
let trainTimeSeries = TimeSeries(periods: trainPeriods, values: trainData)

let validationForecast = model.forecast(timeSeries: trainTimeSeries, periods: 6)

let mape = calculateMAPE(actual: testData, forecast: validationForecast.valuesArray)
print("Forecast accuracy: MAPE = \(String(format: "%.1f", mape))%")

if mape < 10 {
    print("Excellent forecast accuracy")
} else if mape < 20 {
    print("Good forecast accuracy")
} else {
    print("Consider adjusting model parameters or collecting more data")
}
```

## Tuning Forecast Parameters

### Grid Search for Optimal Parameters

```swift
// Try different parameter combinations
let alphaValues = [0.1, 0.2, 0.3]
let betaValues = [0.05, 0.1, 0.15]
let gammaValues = [0.05, 0.1, 0.15]

var bestMAPE = Double.infinity
var bestParams = (alpha: 0.2, beta: 0.1, gamma: 0.1)

for alpha in alphaValues {
    for beta in betaValues {
        for gamma in gammaValues {
            let testModel = HoltWintersModel(
                alpha: alpha,
                beta: beta,
                gamma: gamma,
                seasonalPeriods: 12
            )

            let testForecast = testModel.forecast(
                timeSeries: trainTimeSeries,
                periods: 6
            )

            let testMAPE = calculateMAPE(
                actual: testData,
                forecast: testForecast.valuesArray
            )

            if testMAPE < bestMAPE {
                bestMAPE = testMAPE
                bestParams = (alpha, beta, gamma)
            }
        }
    }
}

print("Best parameters: α=\(bestParams.alpha), β=\(bestParams.beta), γ=\(bestParams.gamma)")
print("Best MAPE: \(String(format: "%.1f", bestMAPE))%")
```

## Practical Tips

### Choosing Forecast Horizons

- **Short-term (1-3 periods)**: Most accurate, use for operational planning
- **Medium-term (4-12 periods)**: Good for tactical planning, budget forecasts
- **Long-term (>12 periods)**: Least accurate, use with wide confidence intervals

### Seasonal Periods

Common seasonal patterns:
```swift
let dailyWithWeekly = HoltWintersModel(..., seasonalPeriods: 7)      // Weekly pattern
let weeklyWithMonthly = HoltWintersModel(..., seasonalPeriods: 4)    // Monthly pattern
let monthlyWithAnnual = HoltWintersModel(..., seasonalPeriods: 12)   // Annual pattern
let quarterlyWithAnnual = HoltWintersModel(..., seasonalPeriods: 4)  // Annual pattern
```

### When to Retrain

Update forecasts when:
1. New data becomes available (monthly/quarterly)
2. Business conditions change significantly
3. Forecast errors exceed acceptable thresholds
4. Seasonality patterns shift

## Next Steps

- Learn <doc:ScenarioAnalysisGuide> to model multiple forecast scenarios
- Explore <doc:OptimizationGuide> to optimize forecast parameters
- See <doc:RiskAnalyticsGuide> for forecast uncertainty analysis

## See Also

- ``HoltWintersModel``
- ``AnomalyDetector``
- ``ForecastWithConfidence``
- ``TimeSeries/movingAverage(window:)``
- ``TimeSeries/growthRate(lag:)``
