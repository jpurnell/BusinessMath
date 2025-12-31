//
//  StreamingForecastingExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to streaming forecasting (Phase 2.3)
//  Learn exponential smoothing, trend detection, and time series forecasting
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Simple Exponential Smoothing

func example1_SimpleExponentialSmoothing() async throws {
    print("=== Example 1: Simple Exponential Smoothing ===\n")

    // Daily website traffic
    let dailyVisitors = AsyncValueStream([
        1200.0, 1350.0, 1180.0, 1420.0, 1280.0,
        1510.0, 1380.0, 1450.0, 1320.0, 1480.0
    ])

    print("Website Traffic Forecasting (α = 0.3):")
    print("Day | Actual | Forecast | Error")
    print("----|--------|----------|-------")

    let visitors = [1200.0, 1350.0, 1180.0, 1420.0, 1280.0, 1510.0, 1380.0, 1450.0, 1320.0, 1480.0]
    var day = 1

    for try await forecast in dailyVisitors.simpleExponentialSmoothing(alpha: 0.3) {
        let actual = visitors[day - 1]
        let error = abs(actual - forecast)
        print(" \(String(format: "%2d", day)) | \(String(format: "%4.0f", actual))   | \(String(format: "%6.0f", forecast))   | \(String(format: "%4.0f", error))")
        day += 1
    }

    print("\nNote: Higher α (0.7-0.9) = more responsive to recent changes")
    print("      Lower α (0.1-0.3) = smoother, less reactive\n")
}

// MARK: - Example 2: Double Exponential Smoothing (Holt's Method)

func example2_DoubleExponentialSmoothing() async throws {
    print("=== Example 2: Double Exponential Smoothing (Trend) ===\n")

    // Growing user base
    let monthlyUsers = AsyncValueStream([
        1000.0, 1100.0, 1250.0, 1380.0, 1550.0,
        1720.0, 1890.0, 2100.0, 2280.0, 2500.0
    ])

    print("SaaS User Growth Forecasting:")
    print("Month | Actual | Level  | Trend | Next Month")
    print("------|--------|--------|-------|------------")

    let users = [1000.0, 1100.0, 1250.0, 1380.0, 1550.0, 1720.0, 1890.0, 2100.0, 2280.0, 2500.0]
    var month = 1

    for try await forecast in monthlyUsers.doubleExponentialSmoothing(alpha: 0.4, beta: 0.2) {
        let actual = users[month - 1]
        let nextMonth = forecast.forecast(steps: 1)
        print("  \(String(format: "%2d", month))  | \(String(format: "%4.0f", actual))   | \(String(format: "%6.0f", forecast.level)) | \(String(format: "%5.0f", forecast.trend)) | \(String(format: "%6.0f", nextMonth))")
        month += 1
    }
    print()
}

// MARK: - Example 3: Triple Exponential Smoothing (Seasonality)

func example3_TripleExponentialSmoothing() async throws {
    print("=== Example 3: Triple Exponential Smoothing (Seasonal) ===\n")

    // Quarterly sales with seasonality
    let quarterlySales = AsyncValueStream([
        100.0, 80.0, 110.0, 90.0,   // Year 1: Q1=100, Q2=80, Q3=110, Q4=90
        120.0, 100.0, 130.0, 110.0, // Year 2: +20% growth
        140.0, 120.0, 150.0, 130.0  // Year 3: +16.7% growth
    ])

    print("Retail Sales Forecasting with Seasonality:")
    print("Qtr | Actual | Level | Trend | Seasonal | Forecast")
    print("----|--------|-------|-------|----------|----------")

    let sales = [100.0, 80.0, 110.0, 90.0, 120.0, 100.0, 130.0, 110.0, 140.0, 120.0, 150.0, 130.0]
    let quarters = ["Q1Y1", "Q2Y1", "Q3Y1", "Q4Y1", "Q1Y2", "Q2Y2", "Q3Y2", "Q4Y2", "Q1Y3", "Q2Y3", "Q3Y3", "Q4Y3"]
    var idx = 0

    for try await forecast in quarterlySales.tripleExponentialSmoothing(
        alpha: 0.3,
        beta: 0.1,
        gamma: 0.2,
        seasonLength: 4
    ) {
        let actual = sales[idx]
        let seasonalIdx = idx % 4
        let seasonal = forecast.seasonalFactors[seasonalIdx]
        let nextForecast = forecast.forecast(steps: 1)

        print("\(quarters[idx]) | \(String(format: "%4.0f", actual))   | \(String(format: "%5.0f", forecast.level)) | \(String(format: "%5.1f", forecast.trend)) | \(String(format: "%8.2f", seasonal)) | \(String(format: "%6.0f", nextForecast))")
        idx += 1
    }

    print("\nSeasonal factors: Q1>1.0 (high), Q2<1.0 (low), Q3>1.0 (high), Q4~1.0\n")
}

// MARK: - Example 4: Moving Average Forecast

func example4_MovingAverageForecast() async throws {
    print("=== Example 4: Moving Average Forecast ===\n")

    // Inventory demand
    let dailyDemand = AsyncValueStream([
        45.0, 52.0, 48.0, 51.0, 49.0,
        55.0, 47.0, 50.0, 53.0, 48.0
    ])

    print("Inventory Demand Forecasting (5-day window):")
    print("Day | Actual | MA Forecast")
    print("----|--------|-------------")

    let demand = [45.0, 52.0, 48.0, 51.0, 49.0, 55.0, 47.0, 50.0, 53.0, 48.0]
    var day = 1

    for try await forecast in dailyDemand.movingAverageForecast(window: 5) {
        // Forecast is generated after filling the window
        let actualDay = day + 4  // Because we need 5 values for first forecast
        if actualDay <= demand.count {
            let actual = demand[actualDay - 1]
            print(" \(String(format: "%2d", actualDay)) | \(String(format: "%4.0f", actual))   | \(String(format: "%6.1f", forecast))")
        }
        day += 1
    }

    print("\nNote: Moving average is simple but lags behind trends\n")
}

// MARK: - Example 5: Trend Detection - Upward

func example5_TrendDetection() async throws {
    print("=== Example 5: Trend Detection ===\n")

    // Product adoption curve
    let weeklyAdoption = AsyncValueStream([
        100.0, 150.0, 250.0, 400.0, 650.0,
        1000.0, 1500.0, 2100.0, 2800.0, 3600.0
    ])

    print("Product Adoption Trend Analysis:")
    print("Week | Adoption | Trend      | Slope | R²")
    print("-----|----------|------------|-------|------")

    let adoption = [100.0, 150.0, 250.0, 400.0, 650.0, 1000.0, 1500.0, 2100.0, 2800.0, 3600.0]
    var week = 5  // Start after window fills

    for try await trend in weeklyAdoption.detectTrend(window: 5) {
        let actual = adoption[week - 1]
        let trendStr = trend.direction == .upward ? "Upward ↑  " :
                      trend.direction == .downward ? "Downward ↓" :
                      "Flat —    "

        print("  \(String(format: "%2d", week)) | \(String(format: "%6.0f", actual))   | \(trendStr) | \(String(format: "%5.0f", trend.slope)) | \(String(format: "%.3f", trend.rSquared))")
        week += 1
    }

    print("\nR² near 1.0 = strong trend, near 0.0 = weak/no trend\n")
}

// MARK: - Example 6: Trend Detection - All Directions

func example6_TrendDirections() async throws {
    print("=== Example 6: Different Trend Patterns ===\n")

    // Three different patterns
    let patterns = [
        ("Growth", [10.0, 15.0, 22.0, 30.0, 40.0, 52.0, 66.0, 82.0]),
        ("Decline", [100.0, 90.0, 82.0, 75.0, 70.0, 66.0, 63.0, 61.0]),
        ("Stable", [50.0, 51.0, 49.0, 50.5, 49.5, 50.2, 50.8, 49.7])
    ]

    for (name, values) in patterns {
        let stream = AsyncValueStream(values)

        print("\(name) Pattern:")
        var detections: [TrendDetection] = []
        for try await trend in stream.detectTrend(window: 4) {
            detections.append(trend)
        }

        if let trend = detections.last {
            let direction = trend.direction == .upward ? "Upward ↑" :
                           trend.direction == .downward ? "Downward ↓" :
                           "Flat —"
            print("  Direction: \(direction)")
            print("  Slope: \(String(format: "%.2f", trend.slope))")
            print("  Strength (R²): \(String(format: "%.3f", trend.rSquared))")
        }
        print()
    }
}

// MARK: - Example 7: Change Point Detection

func example7_ChangePointDetection() async throws {
    print("=== Example 7: Change Point Detection ===\n")

    // System performance with anomaly
    let responseTime = AsyncValueStream([
        15.0, 16.0, 15.5, 16.2, 15.8,  // Stable ~16ms
        15.9, 16.1, 45.0,               // Sudden spike!
        42.0, 44.0, 43.5, 45.2,        // New baseline ~44ms
        44.8, 43.9
    ])

    print("System Performance Change Detection:")
    print("Reading | Response Time | Change Type | Magnitude")
    print("--------|---------------|-------------|----------")

    let times = [15.0, 16.0, 15.5, 16.2, 15.8, 15.9, 16.1, 45.0, 42.0, 44.0, 43.5, 45.2, 44.8, 43.9]
    var reading = 3  // After window fills

    for try await change in responseTime.detectChangePoints(window: 3, threshold: 10.0) {
        let actual = times[reading - 1]
        let typeStr = change.type == .levelShift ? "Level Shift" :
                     change.type == .spike ? "Spike      " :
                     "Trend Chg  "

        let indicator = abs(change.magnitude) > 10.0 ? " 🚨" : ""
        print("   \(String(format: "%2d", reading))   | \(String(format: "%6.1f", actual))ms      | \(typeStr) | \(String(format: "%+6.1f", change.magnitude))\(indicator)")
        reading += 1
    }
    print()
}

// MARK: - Example 8: Forecast Error Metrics

func example8_ForecastErrors() async throws {
    print("=== Example 8: Forecast Error Metrics ===\n")

    // Historical forecasts vs actuals
    let actualValues = [100.0, 105.0, 110.0, 108.0, 115.0, 120.0, 118.0, 125.0]
    let forecastValues = [98.0, 107.0, 109.0, 110.0, 113.0, 121.0, 120.0, 123.0]

    let pairs = Swift.zip(actualValues, forecastValues).map {
        ForecastPair(actual: $0.0, forecast: $0.1)
    }
    let stream = AsyncValueStream(pairs)

    print("Forecast Quality Assessment:")
    print("Period | Actual | Forecast | MAE  | RMSE | MAPE")
    print("-------|--------|----------|------|------|------")

    var period = 1
    for try await error in stream.forecastErrors() {
        let pair = pairs[period - 1]
        print("  \(period)    | \(String(format: "%4.0f", pair.actual))   | \(String(format: "%6.0f", pair.forecast))   | \(String(format: "%.2f", error.mae)) | \(String(format: "%.2f", error.rmse)) | \(String(format: "%.1f", error.mape))%")
        period += 1
    }

    print("\nMAE  = Mean Absolute Error (avg magnitude)")
    print("RMSE = Root Mean Squared Error (penalizes large errors)")
    print("MAPE = Mean Absolute Percentage Error (% accuracy)\n")
}

// MARK: - Example 9: Multi-Step Ahead Forecasting

func example9_MultiStepForecasting() async throws {
    print("=== Example 9: Multi-Step Ahead Forecasting ===\n")

    // Historical monthly revenue
    let revenue = AsyncValueStream([
        100.0, 105.0, 112.0, 118.0, 127.0,
        135.0, 145.0, 155.0, 168.0, 180.0
    ])

    print("Revenue Forecasting - Next 6 Months:")

    // Get final forecast state
    var lastForecast: DoubleExponentialForecast?
    for try await forecast in revenue.doubleExponentialSmoothing(alpha: 0.4, beta: 0.2) {
        lastForecast = forecast
    }

    if let forecast = lastForecast {
        print("\nCurrent State:")
        print("  Level: $\(String(format: "%.0f", forecast.level))K")
        print("  Trend: $\(String(format: "%.0f", forecast.trend))K per month")
        print("\nProjected Revenue:")

        for step in 1...6 {
            let projected = forecast.forecast(steps: step)
            print("  Month +\(step): $\(String(format: "%.0f", projected))K")
        }

        print("\n6-month total projection: $\(String(format: "%.0f", (1...6).map { forecast.forecast(steps: $0) }.reduce(0, +)))K")
    }
    print()
}

// MARK: - Example 10: Real-World - Sales Forecasting Pipeline

func example10_SalesForecastingPipeline() async throws {
    print("=== Example 10: Real-World - Complete Sales Forecasting ===\n")

    // 2 years of monthly sales data with seasonality
    let monthlySales = AsyncValueStream([
        // Year 1
        85.0, 70.0, 95.0, 88.0, 92.0, 78.0, 102.0, 94.0, 98.0, 82.0, 108.0, 120.0,
        // Year 2
        95.0, 80.0, 105.0, 98.0, 102.0, 88.0, 112.0, 104.0, 108.0, 92.0, 118.0, 135.0
    ])

    print("Complete Forecasting Analysis:")
    print("\n1. Detecting Overall Trend...")

    // First, detect the long-term trend
    var trendCount = 0
    var avgSlope = 0.0
    for try await trend in monthlySales.detectTrend(window: 6) {
        avgSlope += trend.slope
        trendCount += 1
    }
    avgSlope /= Double(trendCount)
    let trendDirection = avgSlope > 0.5 ? "Growing ↑" : avgSlope < -0.5 ? "Declining ↓" : "Stable —"
    print("   Trend: \(trendDirection) (slope: \(String(format: "%.2f", avgSlope)))")

    // Apply seasonal forecasting
    print("\n2. Seasonal Forecast for Next Quarter:")

    var finalForecast: TripleExponentialForecast?
    for try await forecast in monthlySales.tripleExponentialSmoothing(
        alpha: 0.3,
        beta: 0.1,
        gamma: 0.2,
        seasonLength: 12
    ) {
        finalForecast = forecast
    }

    if let forecast = finalForecast {
        print("   Current Level: $\(String(format: "%.0f", forecast.level))K")
        print("   Monthly Trend: $\(String(format: "%.1f", forecast.trend))K")
        print("\n   Next 3 Months:")

        var quarterTotal = 0.0
        for month in 1...3 {
            let projected = forecast.forecast(steps: month)
            quarterTotal += projected
            print("     Month +\(month): $\(String(format: "%.0f", projected))K")
        }

        print("\n   Quarter Projection: $\(String(format: "%.0f", quarterTotal))K")
        print("   Monthly Average: $\(String(format: "%.0f", quarterTotal / 3))K")
    }
    print()
}

// MARK: - Example 11: Demand Planning with Uncertainty

func example11_DemandPlanningWithUncertainty() async throws {
    print("=== Example 11: Demand Planning with Confidence Intervals ===\n")

    // Historical weekly demand with variability
    let weeklyDemand = AsyncValueStream([
        450.0, 480.0, 465.0, 520.0, 495.0,
        510.0, 475.0, 530.0, 505.0, 545.0,
        520.0, 560.0, 535.0, 580.0, 555.0
    ])

    print("Inventory Planning with Forecast Uncertainty:")

    // Calculate both forecast and variability
    var forecasts: [DoubleExponentialForecast] = []
    var errors: [Double] = []
    let demand = [450.0, 480.0, 465.0, 520.0, 495.0, 510.0, 475.0, 530.0, 505.0, 545.0, 520.0, 560.0, 535.0, 580.0, 555.0]

    var idx = 0
    for try await forecast in weeklyDemand.doubleExponentialSmoothing(alpha: 0.4, beta: 0.2) {
        forecasts.append(forecast)
        if idx > 0 {
            let error = abs(demand[idx] - forecasts[idx - 1].forecast(steps: 1))
            errors.append(error)
        }
        idx += 1
    }

    if let lastForecast = forecasts.last {
        // Calculate forecast standard error
        let meanError = errors.reduce(0, +) / Double(errors.count)
        let variance = errors.map { pow($0 - meanError, 2) }.reduce(0, +) / Double(errors.count)
        let stdError = sqrt(variance)

        print("\nForecast Statistics:")
        print("  Mean Absolute Error: \(String(format: "%.1f", meanError)) units")
        print("  Std Error: \(String(format: "%.1f", stdError)) units")

        print("\nNext Week Demand Forecast:")
        let pointForecast = lastForecast.forecast(steps: 1)
        let lower95 = pointForecast - (1.96 * stdError)
        let upper95 = pointForecast + (1.96 * stdError)

        print("  Point Estimate: \(String(format: "%.0f", pointForecast)) units")
        print("  95% Confidence: [\(String(format: "%.0f", lower95)), \(String(format: "%.0f", upper95))] units")
        print("\nInventory Recommendation:")
        print("  Conservative (95% service level): \(String(format: "%.0f", upper95)) units")
        print("  Moderate (50% service level): \(String(format: "%.0f", pointForecast)) units")
    }
    print()
}

// MARK: - Run All Examples

@main
struct StreamingForecastingExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Streaming Forecasting Examples (Phase 2.3)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_SimpleExponentialSmoothing()
        try await example2_DoubleExponentialSmoothing()
        try await example3_TripleExponentialSmoothing()
        try await example4_MovingAverageForecast()
        try await example5_TrendDetection()
        try await example6_TrendDirections()
        try await example7_ChangePointDetection()
        try await example8_ForecastErrors()
        try await example9_MultiStepForecasting()
        try await example10_SalesForecastingPipeline()
        try await example11_DemandPlanningWithUncertainty()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
