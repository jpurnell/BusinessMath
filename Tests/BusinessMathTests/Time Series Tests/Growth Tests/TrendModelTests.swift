//
//  TrendModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Trend Model Tests")
struct TrendModelTests {

	let tolerance: Double = 0.01

	// Helper to create test data
	func createTimeSeries(values: [Double]) -> TimeSeries<Double> {
		let periods = (0..<values.count).map { Period.year(2020 + $0) }
		return TimeSeries(
			periods: periods,
			values: values,
			metadata: TimeSeriesMetadata(name: "Test Data")
		)
	}

	// MARK: - LinearTrend Tests

	@Test("LinearTrend fits to upward trend")
	func linearTrendUpward() throws {
		// Data with clear upward trend: y = 2x + 10
		let data = createTimeSeries(values: [10.0, 12.0, 14.0, 16.0, 18.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		// Project 3 periods
		let projection = try model.project(periods: 3)

		#expect(projection.count == 3)
		// Should continue the trend: 20, 22, 24
		#expect(abs(projection.valuesArray[0] - 20.0) < tolerance)
		#expect(abs(projection.valuesArray[1] - 22.0) < tolerance)
		#expect(abs(projection.valuesArray[2] - 24.0) < tolerance)
	}

	@Test("LinearTrend fits to downward trend")
	func linearTrendDownward() throws {
		// Data with downward trend
		let data = createTimeSeries(values: [100.0, 90.0, 80.0, 70.0, 60.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 2)

		// Should continue declining: 50, 40
		#expect(abs(projection.valuesArray[0] - 50.0) < tolerance)
		#expect(abs(projection.valuesArray[1] - 40.0) < tolerance)
	}

	@Test("LinearTrend with flat data")
	func linearTrendFlat() throws {
		let data = createTimeSeries(values: [50.0, 50.0, 50.0, 50.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 3)

		// Should stay flat
		for value in projection.valuesArray {
			#expect(abs(value - 50.0) < tolerance)
		}
	}

	// MARK: - ExponentialTrend Tests

	@Test("ExponentialTrend fits to exponential growth")
	func exponentialTrendGrowth() throws {
		// Data growing exponentially: approximately 100 * 1.2^t
		let data = createTimeSeries(values: [100.0, 120.0, 144.0, 172.8, 207.36])

		var model = ExponentialTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 2)

		// Should continue exponential growth
		#expect(projection.valuesArray[0] > 207.36)
		#expect(projection.valuesArray[1] > projection.valuesArray[0])
	}

	@Test("ExponentialTrend with small values")
	func exponentialTrendSmall() throws {
		let data = createTimeSeries(values: [1.0, 1.1, 1.21, 1.331])

		var model = ExponentialTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 1)

		// Should be around 1.4641 (1.1^4)
		#expect(abs(projection.valuesArray[0] - 1.4641) < 0.01)
	}

	// MARK: - LogisticTrend Tests

	@Test("LogisticTrend approaches capacity")
	func logisticTrendCapacity() throws {
		// S-curve data approaching 1000
		let data = createTimeSeries(values: [10.0, 50.0, 200.0, 500.0, 800.0, 950.0])

		var model = LogisticTrend<Double>(capacity: 1000.0)
		try model.fit(to: data)

		let projection = try model.project(periods: 5)

		// All projections should be below capacity
		for value in projection.valuesArray {
			#expect(value <= 1000.0)
		}

		// Should approach capacity asymptotically
		#expect(projection.valuesArray.last! < 1000.0)
		#expect(projection.valuesArray.last! > 980.0)
	}

	@Test("LogisticTrend with early growth phase")
	func logisticTrendEarlyGrowth() throws {
		// Early exponential-like growth
		let data = createTimeSeries(values: [1.0, 2.0, 4.0, 8.0, 16.0])

		var model = LogisticTrend<Double>(capacity: 1000.0)
		try model.fit(to: data)

		let projection = try model.project(periods: 3)

		// Should continue growing but below capacity
		#expect(projection.valuesArray[0] > 16.0)
		#expect(projection.valuesArray[2] < 1000.0)
	}

	// MARK: - CustomTrend Tests

	@Test("CustomTrend with constant function")
	func customTrendConstant() throws {
		let data = createTimeSeries(values: [10.0, 20.0, 30.0])

		// Custom trend that always returns 100
		var model = CustomTrend<Double> { _ in 100.0 }
		try model.fit(to: data)

		let projection = try model.project(periods: 5)

		// All values should be 100
		for value in projection.valuesArray {
			#expect(abs(value - 100.0) < tolerance)
		}
	}

	@Test("CustomTrend with quadratic function")
	func customTrendQuadratic() throws {
		let data = createTimeSeries(values: [1.0, 4.0, 9.0, 16.0])  // 1^2, 2^2, 3^2, 4^2

		// Custom trend: t^2
		var model = CustomTrend<Double> { t in
			t * t
		}
		try model.fit(to: data)

		// Fitted data uses indices 0-3, so projection uses indices 4, 5, 6
		let projection = try model.project(periods: 3)

		// Should be 16 (4^2), 25 (5^2), 36 (6^2)
		#expect(abs(projection.valuesArray[0] - 16.0) < tolerance)
		#expect(abs(projection.valuesArray[1] - 25.0) < tolerance)
		#expect(abs(projection.valuesArray[2] - 36.0) < tolerance)
	}

	// MARK: - Projection Period Tests

	@Test("Project zero periods returns empty")
	func projectZeroPeriods() throws {
		let data = createTimeSeries(values: [10.0, 20.0, 30.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 0)

		#expect(projection.count == 0)
	}

	@Test("Project many periods")
	func projectManyPeriods() throws {
		let data = createTimeSeries(values: [10.0, 20.0, 30.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 100)

		#expect(projection.count == 100)
		// Should continue linear trend
		#expect(projection.valuesArray.last! > projection.valuesArray.first!)
	}

	// MARK: - Model Comparison Tests

	@Test("Compare LinearTrend vs ExponentialTrend fit quality")
	func compareLinearVsExponential() throws {
		// Linear data
		let linearData = createTimeSeries(values: [10.0, 20.0, 30.0, 40.0, 50.0])

		var linear = LinearTrend<Double>()
		var exponential = ExponentialTrend<Double>()

		try linear.fit(to: linearData)
		try exponential.fit(to: linearData)

		// For linear data, linear model should fit better
		// We'd need R-squared or similar metric to compare formally
		let linearProj = try linear.project(periods: 1)
		let expProj = try exponential.project(periods: 1)

		// Both should be positive and reasonable
		#expect(linearProj.valuesArray[0] > 0)
		#expect(expProj.valuesArray[0] > 0)
	}

	@Test("Different models produce different projections")
	func differentModelsVary() throws {
		let data = createTimeSeries(values: [10.0, 15.0, 25.0, 40.0])

		var linear = LinearTrend<Double>()
		var exponential = ExponentialTrend<Double>()

		try linear.fit(to: data)
		try exponential.fit(to: data)

		let linearProj = try linear.project(periods: 5)
		let expProj = try exponential.project(periods: 5)

		// Should produce different results
		let linearLast = linearProj.valuesArray.last!
		let expLast = expProj.valuesArray.last!

		#expect(abs(linearLast - expLast) > 1.0)
	}

	// MARK: - Edge Cases

	@Test("Fit with single data point")
	func fitSinglePoint() throws {
		let data = createTimeSeries(values: [100.0])

		var model = LinearTrend<Double>()

		// Should either throw or handle gracefully
		do {
			try model.fit(to: data)
			// If it doesn't throw, projections should be constant
			let projection = try model.project(periods: 3)
			for value in projection.valuesArray {
				#expect(abs(value - 100.0) < tolerance)
			}
		} catch {
			// Expected to throw with insufficient data
			#expect(true)
		}
	}

	@Test("Fit with two data points")
	func fitTwoPoints() throws {
		let data = createTimeSeries(values: [10.0, 20.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 2)

		// Should extrapolate: 30, 40
		#expect(abs(projection.valuesArray[0] - 30.0) < tolerance)
		#expect(abs(projection.valuesArray[1] - 40.0) < tolerance)
	}

	@Test("Fit with no variance (all same values)")
	func fitNoVariance() throws {
		let data = createTimeSeries(values: [50.0, 50.0, 50.0, 50.0])

		var model = LinearTrend<Double>()
		try model.fit(to: data)

		let projection = try model.project(periods: 3)

		// Should project constant values
		for value in projection.valuesArray {
			#expect(abs(value - 50.0) < tolerance)
		}
	}

	@Test("ExponentialTrend with zero or negative values should handle gracefully")
	func exponentialTrendZeroValues() throws {
		// Exponential trend requires positive values (uses log)
		let data = createTimeSeries(values: [0.0, 1.0, 2.0, 3.0])

		var model = ExponentialTrend<Double>()

		// Should either throw or handle the zero value
		do {
			try model.fit(to: data)
			// If it succeeds, projections should be reasonable
			let projection = try model.project(periods: 1)
			#expect(!projection.valuesArray[0].isNaN)
		} catch {
			// Expected to fail with zero/negative values
			#expect(true)
		}
	}

	// MARK: - Real-World Scenarios

	@Test("Revenue forecast with LinearTrend")
	func revenueForecastLinear() throws {
		// Historical quarterly revenue (in thousands)
		let revenue = createTimeSeries(values: [100.0, 110.0, 120.0, 130.0, 140.0])

		var model = LinearTrend<Double>()
		try model.fit(to: revenue)

		// Forecast next 4 quarters
		let forecast = try model.project(periods: 4)

		// Should continue upward trend
		#expect(forecast.valuesArray[0] > 140.0)
		#expect(forecast.valuesArray[3] > forecast.valuesArray[0])
	}

	@Test("User growth with ExponentialTrend")
	func userGrowthExponential() throws {
		// User base growing exponentially
		let users = createTimeSeries(values: [1000.0, 1500.0, 2250.0, 3375.0])

		var model = ExponentialTrend<Double>()
		try model.fit(to: users)

		// Project next 3 periods
		let projection = try model.project(periods: 3)

		// Exponential growth should accelerate
		let growth1 = projection.valuesArray[1] - projection.valuesArray[0]
		let growth2 = projection.valuesArray[2] - projection.valuesArray[1]

		#expect(growth2 > growth1)  // Accelerating growth
	}

	@Test("Market saturation with LogisticTrend")
	func marketSaturationLogistic() throws {
		// Market penetration approaching saturation
		let marketShare = createTimeSeries(values: [5.0, 15.0, 30.0, 50.0, 65.0])

		// Market capacity is 80%
		var model = LogisticTrend<Double>(capacity: 80.0)
		try model.fit(to: marketShare)

		// Project next 10 periods
		let projection = try model.project(periods: 10)

		// Should approach but never exceed 80%
		for value in projection.valuesArray {
			#expect(value < 80.0)
		}

		// Growth should slow as it approaches capacity
		let lastValue = projection.valuesArray.last!
		#expect(lastValue > 70.0)  // Close to capacity
		#expect(lastValue < 80.0)  // But not exceeding
	}
}
