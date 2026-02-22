import Testing
import Foundation
@testable import BusinessMath

@Suite("Moving Average Forecast Tests")
struct MovingAverageTests {

	// MARK: - Helper Functions

	func makeTrendData() -> TimeSeries<Double> {
		let periods = (0..<24).map { Period.month(year: 2024, month: $0 % 12 + 1) }
		let values = (0..<24).map { Double(100 + $0 * 5) }
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - Training Tests

	@Test("Train model with sufficient data")
	func trainModel() throws {
		var model = MovingAverageModel<Double>(window: 12)
		let data = makeTrendData()

		try model.train(on: data)

		// Should succeed without error
	}

	@Test("Insufficient data for window size")
	func insufficientData() throws {
		var model = MovingAverageModel<Double>(window: 12)

		let periods = (0..<6).map { Period.month(year: 2024, month: $0 + 1) }
		let values = (0..<6).map { Double($0) }
		let data = TimeSeries(periods: periods, values: values)

		do {
			try model.train(on: data)
			Issue.record("Should have thrown error")
		} catch ForecastError.insufficientData(let required, let got) {
			#expect(required == 12)
			#expect(got == 6)
		}
	}

	// MARK: - Prediction Tests

	@Test("Predict using simple moving average")
	func simpleMovingAverage() throws {
		var model = MovingAverageModel<Double>(window: 3)

		let periods = (0..<10).map { Period.month(year: 2024, month: $0 + 1) }
		let values: [Double] = [10, 12, 14, 16, 18, 20, 22, 24, 26, 28]
		let data = TimeSeries(periods: periods, values: values)

		try model.train(on: data)

		let forecast = model.predict(periods: 3)!

		// Average of last 3 values: (26 + 28 + 24) / 3 = 26
		// Forecast should be constant at that average
		#expect(forecast.valuesArray.count == 3)

		let avg = (26.0 + 28.0 + 24.0) / 3.0
		for value in forecast.valuesArray {
			#expect(abs(value - avg) < 0.1)
		}
	}

	@Test("Longer forecast horizon")
	func longForecast() throws {
		var model = MovingAverageModel<Double>(window: 12)
		let data = makeTrendData()

		try model.train(on: data)

		let forecast = model.predict(periods: 24)!

		#expect(forecast.periods.count == 24)
		#expect(forecast.valuesArray.count == 24)

		// All values should be the same (constant forecast)
		let first = forecast.valuesArray[0]
		for value in forecast.valuesArray {
			#expect(abs(value - first) < 0.01)
		}
	}

	// MARK: - Confidence Intervals

	@Test("Forecast with confidence intervals")
	func confidenceIntervals() throws {
		var model = MovingAverageModel<Double>(window: 6)
		let data = makeTrendData()

		try model.train(on: data)

		let forecast = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.95)

		#expect(forecast.forecast.valuesArray.count == 6)
		#expect(forecast.lowerBound.valuesArray.count == 6)
		#expect(forecast.upperBound.valuesArray.count == 6)

		// Check bounds
		for i in 0..<6 {
			let point = forecast.forecast.valuesArray[i]
			let lower = forecast.lowerBound.valuesArray[i]
			let upper = forecast.upperBound.valuesArray[i]

			#expect(lower < point)
			#expect(point < upper)
		}
	}

	@Test("Confidence interval width")
	func confidenceWidth() throws {
		var model = MovingAverageModel<Double>(window: 6)
		let data = makeTrendData()

		try model.train(on: data)

		let forecast95 = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.95)
		let forecast99 = try model.predictWithConfidence(periods: 6, confidenceLevel: 0.99)

		// 99% interval should be wider
		for i in 0..<6 {
			let width95 = forecast95.upperBound.valuesArray[i] - forecast95.lowerBound.valuesArray[i]
			let width99 = forecast99.upperBound.valuesArray[i] - forecast99.lowerBound.valuesArray[i]

			#expect(width99 > width95)
		}
	}

	// MARK: - Different Window Sizes

	@Test("Small window vs large window")
	func windowSizeComparison() throws {
		let data = makeTrendData()

		var model3 = MovingAverageModel<Double>(window: 3)
		try model3.train(on: data)
		let forecast3 = model3.predict(periods: 1)!

		var model12 = MovingAverageModel<Double>(window: 12)
		try model12.train(on: data)
		let forecast12 = model12.predict(periods: 1)!

		// Both should produce forecasts
		#expect(forecast3.valuesArray.count == 1)
		#expect(forecast12.valuesArray.count == 1)

		// Values will differ based on window size
	}

	// MARK: - Edge Cases

	@Test("Window size equals data length")
	func windowEqualsDataLength() throws {
		var model = MovingAverageModel<Double>(window: 10)

		let periods = (0..<10).map { Period.month(year: 2024, month: $0 + 1) }
		let values = (0..<10).map { Double($0 * 10) }
		let data = TimeSeries(periods: periods, values: values)

		try model.train(on: data)

		let forecast = model.predict(periods: 3)!

		// Forecast is average of all historical values
		let expectedAvg = (0..<10).map { Double($0 * 10) }.reduce(0, +) / 10.0

		for value in forecast.valuesArray {
			#expect(abs(value - expectedAvg) < 0.1)
		}
	}

	@Test("Constant data")
	func constantData() throws {
		var model = MovingAverageModel<Double>(window: 5)

		let periods = (0..<10).map { Period.month(year: 2024, month: $0 + 1) }
		let values = Array(repeating: 100.0, count: 10)
		let data = TimeSeries(periods: periods, values: values)

		try model.train(on: data)

		let forecast = model.predict(periods: 5)!

		// Forecast should be 100
		for value in forecast.valuesArray {
			#expect(abs(value - 100.0) < 0.1)
		}
	}
}

@Suite("Additional Moving Average Tests")
struct AdditionalMovingAverageTests {
	
		// Helpers
		private func dayPeriods(count: Int, start: TimeInterval = 0) -> [Period] {
			(0..<count).map { Period.day(Date(timeIntervalSince1970: start + Double($0 * 86400))) }
		}

		private func monthPeriods(yearStart: Int, monthCount: Int) -> [Period] {
			var periods = [Period]()
			var y = yearStart
			var m = 1
			for _ in 0..<monthCount {
				periods.append(Period.month(year: y, month: m))
				m += 1
				if m == 13 { m = 1; y += 1 }
			}
			return periods
		}

	@Test("Window of 1 is naive last-value forecast")
	func windowOneIsNaive() throws {
		var model = MovingAverageModel<Double>(window: 1)
		let periods = monthPeriods(yearStart: 2024, monthCount: 6)
		let values: [Double] = [10, 15, 18, 20, 22, 25]
		let data = TimeSeries(periods: periods, values: values)
		try model.train(on: data)

		let fc = model.predict(periods: 3)!
		#expect(fc.valuesArray.count == 3)
		for v in fc.valuesArray {
			#expect(abs(v - 25.0) < 1e-9)
		}
	}

	@Test("Predict zero periods returns empty forecast")
	func predictZeroPeriods() throws {
		var model = MovingAverageModel<Double>(window: 3)
		let periods = monthPeriods(yearStart: 2024, monthCount: 6)
		let values: [Double] = [10, 12, 14, 16, 18, 20]
		let data = TimeSeries(periods: periods, values: values)
		try model.train(on: data)

		let fc = model.predict(periods: 0)!
		#expect(fc.periods.isEmpty)
		#expect(fc.valuesArray.isEmpty)
	}

	@Test("Forecast periods are contiguous with monthly training series")
	func forecastPeriodContinuity() throws {
		var model = MovingAverageModel<Double>(window: 3)
		let trainPeriods = monthPeriods(yearStart: 2024, monthCount: 12)
		let values = (0..<12).map { Double(100 + $0) }
		let data = TimeSeries(periods: trainPeriods, values: values)
		try model.train(on: data)

		let fc = model.predict(periods: 3)!
		let expected = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		#expect(fc.periods == expected)
	}

	@Test("Constant data confidence intervals collapse to a point")
	func constantDataConfidenceIntervals() throws {
		var model = MovingAverageModel<Double>(window: 5)
		let periods = monthPeriods(yearStart: 2024, monthCount: 10)
		let values = Array(repeating: 100.0, count: 10)
		let data = TimeSeries(periods: periods, values: values)
		try model.train(on: data)

		let fc = try model.predictWithConfidence(periods: 4, confidenceLevel: 0.95)
		for i in 0..<4 {
			#expect(abs(fc.forecast.valuesArray[i] - 100.0) < 1e-9)
			#expect(abs(fc.lowerBound.valuesArray[i] - 100.0) < 1e-9)
			#expect(abs(fc.upperBound.valuesArray[i] - 100.0) < 1e-9)
		}
	}
}
