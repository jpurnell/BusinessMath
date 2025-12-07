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

		let forecast = try model.predictWithConfidence(periods: 12, confidenceLevel: 0.95)

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

		let forecast90 = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.90)
		let forecast95 = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.95)
		let forecast99 = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.99)

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
		// Q4 months (10, 11, 12), positions (9, 10, 11) should be higher than others
		// Check second year of forecast
		let q4Months = [9, 10, 11].map { /*print("getting \(forecast.valuesArray[$0 + 12])");*/ return forecast.valuesArray[$0 + 12] }
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

@Suite("Additional Holt-Winters Tests")
struct AdditionalHoltWintersTests {

	private func makeTrendSeasonalData() -> TimeSeries<Double> {
		var periods: [Period] = []
		var values: [Double] = []
		for year in 2020...2023 {
			for month in 1...12 {
				let p = Period.month(year: year, month: month)
				periods.append(p)
				let base = Double(100 + (year - 2020) * 12 + month)
				let seasonal = (10...12).contains(month) ? 20.0 : 0.0
				values.append(base + seasonal)
			}
		}
		return TimeSeries(periods: periods, values: values)
	}

	@Test("Forecast periods are contiguous after training series")
	func forecastPeriodsContiguous() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()
		try model.train(on: data)

		let forecast = model.predict(periods: 3)
		let expectedPeriods = [Period.month(year: 2024, month: 1),
							   Period.month(year: 2024, month: 2),
							   Period.month(year: 2024, month: 3)]
		#expect(forecast.periods == expectedPeriods)
	}

	@Test("Seasonality is captured across full non-Q4 months vs Q4")
	func seasonalityStrength() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()
		try model.train(on: data)

		let forecast = model.predict(periods: 24)
		// Focus on second forecast year for stability
		let year2 = Array(forecast.valuesArray[12..<24])
		let q4 = [year2[9], year2[10], year2[11]]
		let nonQ4 = Array(year2[0..<9])

		let avgQ4 = mean(q4)
		let avgNonQ4 = mean(nonQ4)
		#expect(avgQ4 > avgNonQ4)
	}

	@Test("Backtest: one-season-ahead accuracy on synthetic data")
	func backtestOneSeasonAhead() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let full = makeTrendSeasonalData()
		// Train on first 36 months (2020–2022), test on 2023
		let train = TimeSeries(
			periods: Array(full.periods[0..<36]),
			values: Array(full.valuesArray[0..<36])
		)
		let test = TimeSeries(
			periods: Array(full.periods[36..<48]),
			values: Array(full.valuesArray[36..<48])
		)

		try model.train(on: train)
		let fc = model.predict(periods: 12)
		#expect(fc.periods == test.periods)

		// MAPE on synthetic data should be reasonably low
		var apeSum = 0.0
		for i in 0..<12 {
			let actual = test.valuesArray[i]
			let pred = fc.valuesArray[i]
			// Avoid division by zero; actual is > 0 in our data
			apeSum += abs(actual - pred) / actual
		}
		let mape = apeSum / 12.0
		#expect(mape < 0.05) // 5% tolerance on clean synthetic data
	}

	@Test("Confidence interval width non-decreasing with horizon")
	func ciWidthByHorizon() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()
		try model.train(on: data)

		let fc = try model.predictWithConfidence(periods: 12, confidenceLevel: 0.95)
		let widths = zip(fc.lowerBound.valuesArray, fc.upperBound.valuesArray).map { $1 - $0 }

		// Width should not shrink sharply with horizon; allow minor noise but enforce non-decreasing in aggregate
		#expect(widths.first! <= widths.last!)
	}

	@Test("Invalid confidence level throws")
	func invalidConfidenceLevel() throws {
		var model = HoltWintersModel<Double>(seasonalPeriods: 12)
		let data = makeTrendSeasonalData()
		let confidenceLevel = 1.5
		try model.train(on: data)

		do {
			_ = try model.predictWithConfidence(periods: 6, confidenceLevel: confidenceLevel)
		} catch let error as ForecastError {
			switch error {
				case .invalidConfidenceLevel:
					#expect(true)
				default:
					Issue.record("Should have thrown for invalid confidenceLevel > 1")
			}
		}
	}
}
