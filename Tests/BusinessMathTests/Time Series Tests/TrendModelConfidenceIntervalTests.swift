//
//  TrendModelConfidenceIntervalTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-01-15.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

@Suite("Trend Model Confidence Interval Tests")
struct TrendModelConfidenceIntervalTests {

	let tolerance: Double = 0.01

	// MARK: - LinearTrend Confidence Interval Tests

	@Test("LinearTrend produces valid confidence intervals")
	func linearTrendConfidenceIntervals() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// Add some noise to get meaningful confidence intervals (not perfect fit)
		let values: [Double] = [100, 103, 111, 117, 119, 126, 131, 133, 141, 146, 149, 157]
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 6,
			confidenceLevel: 0.95
		)

		// Verify structure
		#expect(forecastWithCI.forecast.count == 6)
		#expect(forecastWithCI.lowerBound.count == 6)
		#expect(forecastWithCI.upperBound.count == 6)
		#expect(abs(forecastWithCI.confidenceLevel - 0.95) < tolerance)

		// Verify bounds are ordered: lower < forecast < upper
		for i in 0..<6 {
			let lower = forecastWithCI.lowerBound.valuesArray[i]
			let forecast = forecastWithCI.forecast.valuesArray[i]
			let upper = forecastWithCI.upperBound.valuesArray[i]

			#expect(lower < forecast)
			#expect(forecast < upper)
		}

		// Verify intervals widen over time (forecast horizon effect)
		let width1 = forecastWithCI.upperBound.valuesArray[0] - forecastWithCI.lowerBound.valuesArray[0]
		let width6 = forecastWithCI.upperBound.valuesArray[5] - forecastWithCI.lowerBound.valuesArray[5]
		#expect(width6 > width1)
	}

	@Test("LinearTrend perfect fit has narrow confidence intervals")
	func linearTrendPerfectFit() throws {
		// Perfect linear data - no residuals
		let periods = (1...10).map { Period.month(year: 2024, month: $0) }
		let values: [Double] = (0..<10).map { Double($0) * 10.0 + 100.0 }
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 3,
			confidenceLevel: 0.95
		)

		// Perfect fit should have very narrow (or zero) confidence intervals
		for i in 0..<3 {
			let width = forecastWithCI.upperBound.valuesArray[i] - forecastWithCI.lowerBound.valuesArray[i]
			#expect(width < 1.0)  // Very narrow for perfect fit
		}
	}

	@Test("LinearTrend confidence level affects interval width")
	func linearTrendConfidenceLevels() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// Add some noise to get meaningful intervals
		let values: [Double] = [100, 103, 111, 117, 119, 126, 131, 133, 141, 146, 149, 157]
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		let ci90 = try model.projectWithConfidence(periods: 3, confidenceLevel: 0.90)
		let ci95 = try model.projectWithConfidence(periods: 3, confidenceLevel: 0.95)
		let ci99 = try model.projectWithConfidence(periods: 3, confidenceLevel: 0.99)

		// Higher confidence level = wider intervals
		let width90 = ci90.upperBound.valuesArray[0] - ci90.lowerBound.valuesArray[0]
		let width95 = ci95.upperBound.valuesArray[0] - ci95.lowerBound.valuesArray[0]
		let width99 = ci99.upperBound.valuesArray[0] - ci99.lowerBound.valuesArray[0]

		#expect(width95 > width90)
		#expect(width99 > width95)
	}

	// MARK: - ExponentialTrend Confidence Interval Tests

	@Test("ExponentialTrend produces valid confidence intervals")
	func exponentialTrendConfidenceIntervals() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// Exponential growth: 100 * 1.05^i
		let values: [Double] = (0..<12).map { 100.0 * pow(1.05, Double($0)) }
		let historical = TimeSeries(periods: periods, values: values)

		var model = ExponentialTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 6,
			confidenceLevel: 0.95
		)

		// Verify structure
		#expect(forecastWithCI.forecast.count == 6)
		#expect(forecastWithCI.lowerBound.count == 6)
		#expect(forecastWithCI.upperBound.count == 6)

		// Verify bounds are ordered
		for i in 0..<6 {
			let lower = forecastWithCI.lowerBound.valuesArray[i]
			let forecast = forecastWithCI.forecast.valuesArray[i]
			let upper = forecastWithCI.upperBound.valuesArray[i]

			#expect(lower < forecast)
			#expect(forecast < upper)
			#expect(lower > 0)  // Exponential should stay positive
		}
	}

	@Test("ExponentialTrend with noise has reasonable intervals")
	func exponentialTrendWithNoise() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// Exponential with noise
		let values: [Double] = [100, 107, 109, 118, 124, 128, 137, 141, 149, 158, 164, 174]
		let historical = TimeSeries(periods: periods, values: values)

		var model = ExponentialTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 4,
			confidenceLevel: 0.95
		)

		// Should have meaningful intervals (not collapsed to zero)
		for i in 0..<4 {
			let width = forecastWithCI.upperBound.valuesArray[i] - forecastWithCI.lowerBound.valuesArray[i]
			#expect(width > 1.0)  // Should have some uncertainty
		}
	}

	// MARK: - LogisticTrend Confidence Interval Tests

	@Test("LogisticTrend produces valid confidence intervals")
	func logisticTrendConfidenceIntervals() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// S-curve approaching 100
		let capacity = 100.0
		let values: [Double] = (0..<12).map { i in
			capacity / (1 + exp(-0.5 * (Double(i) - 6)))
		}
		let historical = TimeSeries(periods: periods, values: values)

		var model = LogisticTrend<Double>(capacity: capacity)
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 6,
			confidenceLevel: 0.95
		)

		// Verify structure
		#expect(forecastWithCI.forecast.count == 6)
		#expect(forecastWithCI.lowerBound.count == 6)
		#expect(forecastWithCI.upperBound.count == 6)

		// Verify bounds are ordered and below capacity
		for i in 0..<6 {
			let lower = forecastWithCI.lowerBound.valuesArray[i]
			let forecast = forecastWithCI.forecast.valuesArray[i]
			let upper = forecastWithCI.upperBound.valuesArray[i]

			#expect(lower < forecast)
			#expect(forecast < upper)
			#expect(upper <= capacity)  // Should not exceed capacity
		}
	}

	// MARK: - Edge Case Tests

	@Test("Handle empty forecast periods")
	func emptyForecast() throws {
		let periods = (1...10).map { Period.month(year: 2024, month: $0) }
		let values: [Double] = (0..<10).map { Double($0) * 10.0 + 100.0 }
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 0,
			confidenceLevel: 0.95
		)

		#expect(forecastWithCI.forecast.count == 0)
		#expect(forecastWithCI.lowerBound.count == 0)
		#expect(forecastWithCI.upperBound.count == 0)
	}

	@Test("Invalid confidence level throws error")
	func invalidConfidenceLevel() throws {
		let periods = (1...10).map { Period.month(year: 2024, month: $0) }
		let values: [Double] = (0..<10).map { Double($0) * 10.0 + 100.0 }
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		// Test confidence level > 1
		#expect(throws: ForecastError.self) {
			let _ = try model.projectWithConfidence(periods: 3, confidenceLevel: 1.5)
		}

		// Test confidence level < 0
		#expect(throws: ForecastError.self) {
			let _ = try model.projectWithConfidence(periods: 3, confidenceLevel: -0.1)
		}
	}

	@Test("Model not fitted throws error")
	func modelNotFitted() throws {
		let model = LinearTrend<Double>()
		// Don't fit the model

		#expect(throws: TrendModelError.self) {
			let _ = try model.projectWithConfidence(periods: 3, confidenceLevel: 0.95)
		}
	}

	// MARK: - Comparison Tests

	@Test("Compare trend models with same data")
	func compareTrendModels() throws {
		let periods = (1...12).map { Period.month(year: 2024, month: $0) }
		// Data that could fit multiple models
		let values: [Double] = [100, 105, 111, 117, 123, 130, 137, 144, 152, 160, 168, 177]
		let historical = TimeSeries(periods: periods, values: values)

		var linear = LinearTrend<Double>()
		try linear.fit(to: historical)
		let linearCI = try linear.projectWithConfidence(periods: 3, confidenceLevel: 0.95)

		var exponential = ExponentialTrend<Double>()
		try exponential.fit(to: historical)
		let expCI = try exponential.projectWithConfidence(periods: 3, confidenceLevel: 0.95)

		// Both should produce valid forecasts
		#expect(linearCI.forecast.count == 3)
		#expect(expCI.forecast.count == 3)

		// Forecasts should be different (exponential grows faster)
		#expect(expCI.forecast.valuesArray[2] > linearCI.forecast.valuesArray[2])
	}

	@Test("Periods match between forecast and bounds")
	func periodsMatch() throws {
		let periods = (1...10).map { Period.month(year: 2024, month: $0) }
		let values: [Double] = (0..<10).map { Double($0) * 10.0 + 100.0 }
		let historical = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: historical)

		let forecastWithCI = try model.projectWithConfidence(
			periods: 5,
			confidenceLevel: 0.95
		)

		// All time series should have same periods
		#expect(forecastWithCI.forecast.periods == forecastWithCI.lowerBound.periods)
		#expect(forecastWithCI.forecast.periods == forecastWithCI.upperBound.periods)

		// Periods should be contiguous and after historical data
		let lastHistoricalPeriod = historical.periods.last!
		let firstForecastPeriod = forecastWithCI.forecast.periods.first!
		#expect(firstForecastPeriod == lastHistoricalPeriod.next())
	}
}
