#!/usr/bin/env swift
//
// Proposed API for adding confidence intervals to TrendModel
//
// This shows what a consistent API would look like across all forecast models.
//

/*
PROPOSED API ENHANCEMENT:

// 1. Add optional method to TrendModel protocol
public protocol TrendModel<Value>: Sendable {
    associatedtype Value: Real

    mutating func fit(to timeSeries: TimeSeries<Value>) throws
    func project(periods: Int) throws -> TimeSeries<Value>

    // NEW: Optional confidence interval support
    func projectWithConfidence(
        periods: Int,
        confidenceLevel: Value
    ) throws -> ForecastWithConfidence<Value>
}

// 2. Extend LinearTrend to store residuals during fitting
public struct LinearTrend<T: Real & Sendable>: TrendModel, Sendable {
    // ... existing properties ...
    private var residuals: [T] = []  // NEW

    public mutating func fit(to timeSeries: TimeSeries<T>) throws {
        // ... existing fitting code ...

        // Calculate and store residuals
        self.residuals = []
        for (i, period) in timeSeries.periods.enumerated() {
            let fitted = fittedSlope! * T(i) + fittedIntercept!
            let actual = timeSeries[period]!
            residuals.append(actual - fitted)
        }
    }

    // NEW: Confidence interval support
    public func projectWithConfidence(
        periods: Int,
        confidenceLevel: T
    ) throws -> ForecastWithConfidence<T> where T: BinaryFloatingPoint {
        let forecast = try project(periods: periods)

        // Calculate standard error from residuals
        let mse = residuals.map { $0 * $0 }.reduce(T.zero, +) /
                  T(max(residuals.count - 2, 1))
        let standardError = T.sqrt(mse)

        // Z-score for confidence level
        let zScore = try getZScore(for: confidenceLevel)

        // Calculate bounds with widening intervals
        var lowerValues: [T] = []
        var upperValues: [T] = []

        for (h, value) in forecast.valuesArray.enumerated() {
            let horizon = T(h + 1)
            let n = T(fittedDataCount)

            // Forecast standard error increases with horizon
            let forecastSE = standardError * T.sqrt(
                T(1) + (T(1) / n) + (horizon * horizon) / (T(12) * n)
            )

            let margin = zScore * forecastSE
            lowerValues.append(value - margin)
            upperValues.append(value + margin)
        }

        let lowerSeries = TimeSeries(periods: forecast.periods, values: lowerValues)
        let upperSeries = TimeSeries(periods: forecast.periods, values: upperValues)

        return ForecastWithConfidence(
            forecast: forecast,
            lowerBound: lowerSeries,
            upperBound: upperSeries,
            confidenceLevel: confidenceLevel
        )
    }
}

// 3. Usage becomes consistent across all models:

// Trend models - NOW WITH CI SUPPORT
var linear = LinearTrend<Double>()
try linear.fit(to: historical)
let linearCI = try linear.projectWithConfidence(periods: 12, confidenceLevel: 0.95)

// Holt-Winters - ALREADY HAS CI SUPPORT
var hw = HoltWintersModel<Double>(seasonalPeriods: 12)
try hw.train(on: historical)
let hwCI = try hw.predictWithConfidence(periods: 12, confidenceLevel: 0.95)

// Consistent API! ✨
*/

print("This file shows what a future API enhancement could look like")
print("to add confidence interval support to TrendModel implementations.")
print()
print("Benefits:")
print("✓ Consistent API across all forecast models")
print("✓ Built-in residual tracking")
print("✓ Automatic forecast horizon adjustments")
print("✓ No manual calculations needed")
print()
print("Current workaround:")
print("- Use HoltWintersModel or MovingAverageModel if you need CIs")
print("- Or calculate manually (see trend_confidence_intervals_example.swift)")
