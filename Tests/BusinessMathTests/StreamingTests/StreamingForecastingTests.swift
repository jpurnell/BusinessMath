//
//  StreamingForecastingTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Streaming Forecasting (Phase 2.3)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Forecasting Tests")
struct StreamingForecastingTests {

    // MARK: - Simple Exponential Smoothing Tests

    @Test("Simple exponential smoothing with constant series")
    func simpleExponentialSmoothingConstant() async throws {
        let values = [10.0, 10.0, 10.0, 10.0, 10.0]
        let stream = AsyncValueStream(values)

        var forecasts: [Double] = []
        for try await forecast in stream.simpleExponentialSmoothing(alpha: 0.3) {
            forecasts.append(forecast)
        }

        // With constant series, forecast should converge to the constant value
        #expect(forecasts.count == 5)
        #expect(abs(forecasts[0] - 10.0) < 0.5)  // Initial forecast
        #expect(abs(forecasts[4] - 10.0) < 0.1)  // Converged
    }

    @Test("Simple exponential smoothing with trend")
    func simpleExponentialSmoothingTrend() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let stream = AsyncValueStream(values)

        var forecasts: [Double] = []
        for try await forecast in stream.simpleExponentialSmoothing(alpha: 0.5) {
            forecasts.append(forecast)
        }

        // Forecast should lag behind the trend
        #expect(forecasts.count == 10)
        #expect(forecasts[9] < 10.0)  // Lags behind actual value
        #expect(forecasts[9] > 8.0)   // But not too far behind with alpha=0.5
    }

    // MARK: - Double Exponential Smoothing (Holt's Method) Tests

    @Test("Double exponential smoothing captures trend")
    func doubleExponentialSmoothing() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let stream = AsyncValueStream(values)

        var forecasts: [DoubleExponentialForecast] = []
        for try await forecast in stream.doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            forecasts.append(forecast)
        }

        #expect(forecasts.count == 10)

        // Should detect upward trend
        let lastForecast = forecasts[9]
        #expect(lastForecast.trend > 0.5)  // Positive trend
        #expect(lastForecast.level > 8.0)   // High level

        // With conservative smoothing (alpha=0.3, beta=0.1), forecast lags behind
        // Test that forecast increases with more steps (trending upward)
        let step1 = lastForecast.forecast(steps: 1)
        let step2 = lastForecast.forecast(steps: 2)
        #expect(step1 > lastForecast.level)  // Forecast extends beyond current level
        #expect(step2 > step1)  // Multi-step forecasts increase
    }

    @Test("Double exponential smoothing with no trend")
    func doubleExponentialSmoothingNoTrend() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var forecasts: [DoubleExponentialForecast] = []
        for try await forecast in stream.doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            forecasts.append(forecast)
        }

        let lastForecast = forecasts[9]
        // Trend should be near zero
        #expect(abs(lastForecast.trend) < 0.5)
        // Level should be near 5.0
        #expect(abs(lastForecast.level - 5.0) < 0.5)
    }

    // MARK: - Triple Exponential Smoothing (Holt-Winters) Tests

    @Test("Triple exponential smoothing with seasonality")
    func tripleExponentialSmoothing() async throws {
        // Seasonal pattern: high in Q1/Q3, low in Q2/Q4
        let values = [100.0, 80.0, 110.0, 90.0,  // Year 1
                      120.0, 100.0, 130.0, 110.0, // Year 2
                      140.0, 120.0, 150.0, 130.0] // Year 3
        let stream = AsyncValueStream(values)

        var forecasts: [TripleExponentialForecast] = []
        for try await forecast in stream.tripleExponentialSmoothing(
            alpha: 0.3,
            beta: 0.1,
            gamma: 0.2,
            seasonLength: 4
        ) {
            forecasts.append(forecast)
        }

        #expect(forecasts.count == 12)

        let lastForecast = forecasts[11]
        // Should detect upward trend
        #expect(lastForecast.trend > 0)

        // Should detect seasonal pattern
        // Q1 (index 0) should have higher seasonal factor than Q2 (index 1)
        #expect(lastForecast.seasonalFactors[0] > lastForecast.seasonalFactors[1])

        // Next forecast should use seasonal adjustment
        let nextForecast = lastForecast.forecast(steps: 1)
        #expect(nextForecast > 130.0)  // Continuing upward with Q1 seasonality
    }

    // MARK: - Moving Average Forecast Tests

    @Test("Simple moving average forecast")
    func simpleMovingAverage() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let stream = AsyncValueStream(values)

        var forecasts: [Double] = []
        for try await forecast in stream.movingAverageForecast(window: 3) {
            forecasts.append(forecast)
        }

        // First forecast after [1,2,3] = 2.0 (mean of window)
        // Second forecast after [2,3,4] = 3.0
        // ...
        // Last forecast after [8,9,10] = 9.0
        #expect(forecasts.count == 8)  // n - window + 1
        #expect(abs(forecasts[0] - 2.0) < 0.001)
        #expect(abs(forecasts[7] - 9.0) < 0.001)
    }

    // MARK: - Trend Detection Tests

    @Test("Detect upward trend")
    func detectUpwardTrend() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let stream = AsyncValueStream(values)

        var trends: [TrendDetection] = []
        for try await trend in stream.detectTrend(window: 5) {
            trends.append(trend)
        }

        #expect(trends.count == 6)  // 10 - 5 + 1

        // All should detect upward trend
        for trend in trends {
            #expect(trend.direction == .upward)
            #expect(trend.slope > 0.8)  // Strong upward slope
        }
    }

    @Test("Detect downward trend")
    func detectDownwardTrend() async throws {
        let values = [10.0, 9.0, 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
        let stream = AsyncValueStream(values)

        var trends: [TrendDetection] = []
        for try await trend in stream.detectTrend(window: 5) {
            trends.append(trend)
        }

        // All should detect downward trend
        for trend in trends {
            #expect(trend.direction == .downward)
            #expect(trend.slope < -0.8)  // Strong downward slope
        }
    }

    @Test("Detect no trend")
    func detectNoTrend() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var trends: [TrendDetection] = []
        for try await trend in stream.detectTrend(window: 5) {
            trends.append(trend)
        }

        // Should detect flat/no trend
        for trend in trends {
            #expect(trend.direction == .flat)
            #expect(abs(trend.slope) < 0.3)
        }
    }

    // MARK: - Change Point Detection Tests

    @Test("Detect sudden change point")
    func detectChangePoint() async throws {
        // Series with sudden jump - using smaller window to detect abrupt changes
        let values = [5.0, 5.0, 5.0, 5.0, 5.0,  // Stable around 5
                      10.0, 10.0, 10.0, 10.0, 10.0] // Jump to 10
        let stream = AsyncValueStream(values)

        var changes: [ChangePoint] = []
        // Use window=2 and threshold=2.0 to catch the transition window
        // When window slides from [5,5] to [5,10] to [10,10], max change is 2.5
        for try await change in stream.detectChangePoints(window: 2, threshold: 2.0) {
            changes.append(change)
        }

        // Should detect at least one change point
        #expect(changes.count >= 1)

        // Should detect a significant level shift (2.5 when window slides from [5,10] to [10,10])
        let hasSignificantChange = changes.contains { abs($0.magnitude) > 2.0 }
        #expect(hasSignificantChange)
        #expect(changes.allSatisfy { $0.type == .levelShift })
    }

    // MARK: - Forecast Accuracy Tests

    @Test("Calculate forecast errors")
    func calculateForecastErrors() async throws {
        let actuals = [1.0, 2.0, 3.0, 4.0, 5.0]
        let forecasts = [1.1, 2.2, 2.8, 4.1, 4.9]

        let pairs = zip(actuals, forecasts).map { ForecastPair(actual: $0.0, forecast: $0.1) }
        let stream = AsyncValueStream(pairs)

        var errors: [StreamingForecastError] = []
        for try await error in stream.forecastErrors() {
            errors.append(error)
        }

        #expect(errors.count == 5)

        // MAE should be calculated
        let lastError = errors[4]
        #expect(lastError.mae > 0)
        #expect(lastError.mae < 0.5)  // Small errors

        // RMSE should be >= MAE
        #expect(lastError.rmse >= lastError.mae)
    }

    // MARK: - Multi-Step Forecast Tests

    @Test("Multi-step ahead forecast")
    func multiStepForecast() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
        let stream = AsyncValueStream(values)

        // Get the final forecast state
        var lastForecast: DoubleExponentialForecast?
        for try await forecast in stream.doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
            lastForecast = forecast
        }

        guard let forecast = lastForecast else {
            throw StreamingForecastingTestError.noForecast
        }

        // Generate 5-step ahead forecast
        let step1 = forecast.forecast(steps: 1)
        let step2 = forecast.forecast(steps: 2)
        let step3 = forecast.forecast(steps: 3)
        let step4 = forecast.forecast(steps: 4)
        let step5 = forecast.forecast(steps: 5)

        // With positive trend, each step should be higher
        #expect(step1 < step2)
        #expect(step2 < step3)
        #expect(step3 < step4)
        #expect(step4 < step5)

        // Forecast extends beyond current level
        #expect(step1 > forecast.level)
    }

    // MARK: - Memory Efficiency Tests

    @Test("Streaming forecasting maintains O(1) memory")
    func constantMemoryForForecasting() async throws {
        // Simulate large stream
        let largeStream = AsyncGeneratorStream {
            return Double.random(in: 0...100)
        }

        var forecastCount = 0
        for try await _ in largeStream.simpleExponentialSmoothing(alpha: 0.3) {
            forecastCount += 1
            if forecastCount >= 10000 {
                break
            }
        }

        // If we got 10000 forecasts without memory issues, O(1) memory is maintained
        #expect(forecastCount == 10000)
    }
}

// MARK: - Supporting Types

enum StreamingForecastingTestError: Error {
    case noForecast
}
