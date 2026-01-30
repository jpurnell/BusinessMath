//
//  ForecastErrorMetricsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-01-15.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Forecast Error Metrics Tests")
struct ForecastErrorMetricsTests {

	let tolerance: Double = 0.0001

	// MARK: - Basic Error Calculation Tests

	@Test("Perfect forecast has zero error")
	func perfectForecast() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0, 140.0])
		let forecast = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0, 140.0])

		let metrics = actual.forecastError(against: forecast)

		#expect(abs(metrics.rmse) < tolerance)
		#expect(abs(metrics.mae) < tolerance)
		#expect(abs(metrics.mape) < tolerance)
		#expect(metrics.count == 5)
	}

	@Test("RMSE calculation for simple forecast errors")
	func rmseCalculation() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0])
		let forecast = TimeSeries(periods: periods, values: [98.0, 112.0, 118.0, 132.0])

		// Errors: [2, -2, 2, -2]
		// Squared errors: [4, 4, 4, 4]
		// MSE: 16/4 = 4
		// RMSE: sqrt(4) = 2.0

		let metrics = actual.forecastError(against: forecast)

		#expect(abs(metrics.rmse - 2.0) < tolerance)
	}

	@Test("MAE calculation for simple forecast errors")
	func maeCalculation() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0])
		let forecast = TimeSeries(periods: periods, values: [95.0, 115.0, 115.0, 135.0])

		// Errors: [5, -5, 5, -5]
		// Absolute errors: [5, 5, 5, 5]
		// MAE: 20/4 = 5.0

		let metrics = actual.forecastError(against: forecast)

		#expect(abs(metrics.mae - 5.0) < tolerance)
	}

	@Test("MAPE calculation for simple forecast errors")
	func mapeCalculation() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 100.0, 100.0, 100.0])
		let forecast = TimeSeries(periods: periods, values: [90.0, 110.0, 95.0, 105.0])

		// Percentage errors: [10%, 10%, 5%, 5%]
		// MAPE: 30/4 = 7.5%

		let metrics = actual.forecastError(against: forecast)
		
		#expect(abs(metrics.mape - 0.075) < tolerance)
	}

	// MARK: - Edge Cases

	@Test("Handle mismatched periods gracefully")
	func mismatchedPeriods() {
		let periods1 = (1...5).map { Period.month(year: 2025, month: $0) }
		let periods2 = (3...7).map { Period.month(year: 2025, month: $0) }

		let actual = TimeSeries(periods: periods1, values: [100.0, 110.0, 120.0, 130.0, 140.0])
		let forecast = TimeSeries(periods: periods2, values: [120.0, 130.0, 140.0, 150.0, 160.0])

		// Only periods 3, 4, 5 overlap
		let metrics = actual.forecastError(against: forecast)

		#expect(metrics.count == 3)
		// Should only calculate error for overlapping periods
	}

	@Test("Handle empty series")
	func emptySeries() {
		let actual = TimeSeries<Double>(periods: [], values: [])
		let forecast = TimeSeries<Double>(periods: [], values: [])

		let metrics = actual.forecastError(against: forecast)

		#expect(metrics.count == 0)
		#expect(metrics.rmse.isNaN || metrics.rmse == 0)
		#expect(metrics.mae.isNaN || metrics.mae == 0)
		#expect(metrics.mape.isNaN || metrics.mape == 0)
	}

	@Test("Skip zero actual values in MAPE calculation")
	func mapeWithZeroActuals() {
		let periods = (1...4).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [0.0, 100.0, 0.0, 100.0])
		let forecast = TimeSeries(periods: periods, values: [10.0, 110.0, 10.0, 90.0])

		// Only periods 2 and 4 should count for MAPE (non-zero actuals)
		// Period 2: |100-110|/100 = 10%
		// Period 4: |100-90|/100 = 10%
		// MAPE: 20/2 = 10%

		let metrics = actual.forecastError(against: forecast)

		#expect(abs(metrics.mape - 0.1) < tolerance)
		// RMSE and MAE should still use all 4 periods
		#expect(metrics.count == 4)
	}

	// MARK: - Real-World Scenarios

	@Test("Linear trend forecast vs exponential growth actual")
	func linearVsExponentialError() {
		let periods = (1...6).map { Period.month(year: 2025, month: $0) }

		// Actual: exponential growth (1.2x each period)
		let actual = TimeSeries(periods: periods, values: [100.0, 120.0, 144.0, 172.8, 207.36, 248.832])

		// Forecast: linear trend (adds 20 each period)
		let forecast = TimeSeries(periods: periods, values: [100.0, 120.0, 140.0, 160.0, 180.0, 200.0])

		let metrics = actual.forecastError(against: forecast)

		// Errors should increase over time as exponential diverges from linear
		#expect(metrics.rmse > 0)
		#expect(metrics.mae > 0)
		#expect(metrics.mape > 0)

		// RMSE should be larger than MAE (due to squaring larger errors)
		#expect(metrics.rmse > metrics.mae)
	}

	@Test("Seasonal forecast accuracy")
	func seasonalForecastAccuracy() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }

		// Actual: seasonal pattern with noise
		let actual = TimeSeries(periods: periods, values: [
			100.0, 110.0, 115.0, 108.0,  // Q1
			105.0, 112.0, 120.0, 115.0,  // Q2
			102.0, 108.0, 118.0, 125.0   // Q3-Q4
		])

		// Forecast: captures pattern but not perfectly
		let forecast = TimeSeries(periods: periods, values: [
			98.0, 108.0, 113.0, 106.0,
			103.0, 110.0, 118.0, 113.0,
			100.0, 106.0, 116.0, 123.0
		])

		let metrics = actual.forecastError(against: forecast)

		// Good forecast should have relatively low error
		#expect(metrics.mape < 10.0)  // Less than 10% MAPE
		#expect(metrics.count == 12)
	}

	// MARK: - Comparison Tests

	@Test("Compare two forecast models by error metrics")
	func compareModels() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1, 146.41])

		// Model 1: Simple linear trend
		let model1 = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0, 140.0])

		// Model 2: Better exponential fit
		let model2 = TimeSeries(periods: periods, values: [100.0, 110.0, 121.0, 133.1, 146.41])

		let metrics1 = actual.forecastError(against: model1)
		let metrics2 = actual.forecastError(against: model2)

		// Model 2 should have lower error (perfect fit)
		#expect(metrics2.rmse < metrics1.rmse)
		#expect(metrics2.mae < metrics1.mae)
		#expect(metrics2.mape < metrics1.mape)
	}

	// MARK: - Properties Tests

	@Test("Error metrics struct has all required properties")
	func metricsStructureTest() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let actual = TimeSeries(periods: periods, values: [100.0, 110.0, 120.0])
		let forecast = TimeSeries(periods: periods, values: [95.0, 115.0, 125.0])

		let metrics = actual.forecastError(against: forecast)

		// Should have all properties accessible
		let _ = metrics.rmse
		let _ = metrics.mae
		let _ = metrics.mape
		let _ = metrics.count

		// Count should match number of comparable periods
		#expect(metrics.count == 3)
	}
}
