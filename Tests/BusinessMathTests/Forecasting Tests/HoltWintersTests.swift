import Testing
import Foundation
@testable import BusinessMath

@Suite("Holt-Winters Forecasting Tests")
struct HoltWintersTests {

	// MARK: - Helper Functions

	func makeTrendSeasonalData() -> TimeSeries<Double> {
		// Create data with trend and seasonality
		var periods: [Period] = []
		var values: [Double] = []

		for year in 2020...2023 {
			for month in 1...12 {
				let period = Period.month(year: year, month: month)
				periods.append(period)

				// Base value with trend
				let baseValue = Double(100 + (year - 2020) * 12 + month)

				// Add seasonality (higher in Q4)
				let seasonal = (month == 10 || month == 11 || month == 12) ? 20.0 : 0.0

				values.append(baseValue + seasonal)
			}
		}

		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - Training Tests

	@Test("Train model on seasonal data")
	func trainModel() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()

		try model.train(on: data)

		// Model should have initialized level, trend, and seasonality
		// (Actual values depend on implementation)
	}

	@Test("Insufficient data throws error")
	func insufficientData() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)

		// Only 10 periods (need at least 24 for seasonalPeriods=12)
		let periods = (0..<10).map { Period.month(year: 2024, month: $0 % 12 + 1) }
		let values = (0..<10).map { Double($0) }
		let data = TimeSeries(periods: periods, values: values)

		do {
			try model.train(on: data)
			Issue.record("Should have thrown insufficient data error")
		} catch ForecastError.insufficientData(let required, let got) {
			#expect(required == 24)
			#expect(got == 10)
		}
	}

	// MARK: - Prediction Tests

	@Test("Predict future values")
	func predictFuture() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()

		try model.train(on: data)

		let forecast = model.predict(periods: 12)

		#expect(forecast.periods.count == 12)
		#expect(forecast.valuesArray.count == 12)

		// Forecast should continue trend
		#expect(forecast.valuesArray.allSatisfy { $0 > 0 })
	}

	@Test("Forecast with confidence intervals")
	func forecastWithConfidence() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()

		try model.train(on: data)

		let forecast = model.predictWithConfidence(periods: 12, confidenceLevel: 0.95)

		#expect(forecast.forecast.periods.count == 12)
		#expect(forecast.lowerBound.periods.count == 12)
		#expect(forecast.upperBound.periods.count == 12)
		#expect(forecast.confidenceLevel == 0.95)

		// Check bounds make sense
		for i in 0..<12 {
			let point = forecast.forecast.valuesArray[i]
			let lower = forecast.lowerBound.valuesArray[i]
			let upper = forecast.upperBound.valuesArray[i]

			#expect(lower < point)
			#expect(point < upper)
		}
	}

	@Test("Different confidence levels")
	func differentConfidenceLevels() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()

		try model.train(on: data)

		let forecast90 = model.predictWithConfidence(periods: 6, confidenceLevel: 0.90)
		let forecast95 = model.predictWithConfidence(periods: 6, confidenceLevel: 0.95)
		let forecast99 = model.predictWithConfidence(periods: 6, confidenceLevel: 0.99)

		// 99% interval should be wider than 95% which should be wider than 90%
		for i in 0..<6 {
			let width90 = forecast90.upperBound.valuesArray[i] - forecast90.lowerBound.valuesArray[i]
			let width95 = forecast95.upperBound.valuesArray[i] - forecast95.lowerBound.valuesArray[i]
			let width99 = forecast99.upperBound.valuesArray[i] - forecast99.lowerBound.valuesArray[i]

			#expect(width90 < width95)
			#expect(width95 < width99)
		}
	}

	// MARK: - Smoothing Parameters

	@Test("Different alpha values")
	func differentAlphaValues() throws {
		let data = makeTrendSeasonalData()

		// Low alpha (more smoothing)
		var model1 = HoltWintersModel<Double>(
			alpha: 0.1,
			beta: 0.1,
			gamma: 0.1,
			seasonalPeriods: 12
		)
		try model1.train(on: data)

		// High alpha (less smoothing)
		var model2 = HoltWintersModel<Double>(
			alpha: 0.9,
			beta: 0.1,
			gamma: 0.1,
			seasonalPeriods: 12
		)
		try model2.train(on: data)

		// Both should produce reasonable forecasts
		let forecast1 = model1.predict(periods: 6)
		let forecast2 = model2.predict(periods: 6)

		#expect(forecast1.valuesArray.count == 6)
		#expect(forecast2.valuesArray.count == 6)
	}

	// MARK: - Seasonality Tests

	@Test("Capture seasonality pattern")
	func captureSeasonality() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()

		try model.train(on: data)

		let forecast = model.predict(periods: 24)  // 2 years

		// Q4 months (10, 11, 12) should be higher than others
		// Check second year of forecast
		let q4Months = [10, 11, 12].map { forecast.valuesArray[$0 + 12] }
		let otherMonths = [1, 2, 3, 4, 5, 6].map { forecast.valuesArray[$0 + 12] }

		let avgQ4 = q4Months.reduce(0, +) / Double(q4Months.count)
		let avgOther = otherMonths.reduce(0, +) / Double(otherMonths.count)

		#expect(avgQ4 > avgOther)
	}

	// MARK: - Edge Cases

	@Test("Constant data (no trend or seasonality)")
	func constantData() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 4)

		let periods = (0..<16).map { Period.quarter(year: 2024 + $0 / 4, quarter: $0 % 4 + 1) }
		let values = Array(repeating: 100.0, count: 16)
		let data = TimeSeries(periods: periods, values: values)

		try model.train(on: data)

		let forecast = model.predict(periods: 4)

		// Forecast should be close to 100
		for value in forecast.valuesArray {
			#expect(abs(value - 100.0) < 10.0)
		}
	}
}
