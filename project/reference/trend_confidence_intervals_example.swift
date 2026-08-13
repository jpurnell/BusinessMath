#!/usr/bin/env swift
//
// Manual Confidence Interval Calculation for Trend Models
//
// Since LinearTrend and ExponentialTrend don't have built-in confidence intervals,
// this shows how to calculate them manually using residuals.
//

import Foundation

/*
import BusinessMath

let periods = (1...24).map { Period.month(year: 2024, month: ($0 - 1) % 12 + 1) }
let values: [Double] = [/* your historical data */]
let historical = TimeSeries(periods: periods, values: values)

// 1. Fit the trend model
var trend = LinearTrend<Double>()
try trend.fit(to: historical)

// 2. Calculate residuals (actual - fitted)
var residuals: [Double] = []
for (i, period) in historical.periods.enumerated() {
    // Fitted value from the model: y = slope * x + intercept
    let fittedValue = (trend.slopeValue ?? 0) * Double(i) + (trend.interceptValue ?? 0)
    let actualValue = historical[period] ?? 0
    residuals.append(actualValue - fittedValue)
}

// 3. Calculate standard error from residuals
let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(0, +)
let mse = sumSquaredResiduals / Double(max(residuals.count - 2, 1))  // -2 for df
let standardError = sqrt(mse)

// 4. Generate forecast
let forecastPeriods = 12
let forecast = try trend.project(periods: forecastPeriods)

// 5. Calculate confidence intervals
let confidenceLevel = 0.95  // 95% confidence
let zScore = 1.96  // For 95% CI

// Confidence interval widens as we forecast further into the future
var lowerBounds: [Double] = []
var upperBounds: [Double] = []

for (h, value) in forecast.valuesArray.enumerated() {
    // Standard error increases with forecast horizon
    let horizon = Double(h + 1)
    let forecastStdError = standardError * sqrt(1 + (1.0 / Double(historical.count)) +
                          (horizon * horizon) / (12 * Double(historical.count)))

    let margin = zScore * forecastStdError
    lowerBounds.append(value - margin)
    upperBounds.append(value + margin)
}

// 6. Create ForecastWithConfidence (optional)
let lowerSeries = TimeSeries(periods: forecast.periods, values: lowerBounds)
let upperSeries = TimeSeries(periods: forecast.periods, values: upperBounds)

let forecastWithCI = ForecastWithConfidence(
    forecast: forecast,
    lowerBound: lowerSeries,
    upperBound: upperSeries,
    confidenceLevel: confidenceLevel
)

// 7. Display results
print("Forecast with \((confidenceLevel * 100).number(0))% Confidence Intervals")
print("=" * 70)
for i in 0..<forecast.count {
    let period = forecast.periods[i]
    let point = forecast.valuesArray[i]
    let lower = lowerBounds[i]
    let upper = upperBounds[i]

    print("\(period.label): \(point.currency(0)) [\(lower.currency(0)) - \(upper.currency(0))]")
}

// Key insights:
print("\nKey Points:")
print("1. Standard error: \(standardError.number(2))")
print("2. Confidence interval widens over time (forecast horizon effect)")
print("3. Better fit (lower residuals) = narrower confidence intervals")
print("4. More historical data = more confidence = narrower intervals")
*/

print("This example shows how to manually calculate confidence intervals")
print("for TrendModel forecasts that don't have built-in CI support.")
print()
print("For production use, consider using HoltWintersModel or MovingAverageModel")
print("which have built-in predictWithConfidence() methods.")
