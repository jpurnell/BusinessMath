//
//  PerformanceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

/// Performance tests for BusinessMath library.
///
/// These tests measure execution time for various operations to ensure
/// the library performs well with large datasets and complex calculations.
@Suite("Performance Tests")
struct PerformanceTests {

	// MARK: - Helper Functions

	/// Measures execution time of a block and returns duration in seconds.
	private func measure(_ block: () throws -> Void) rethrows -> TimeInterval {
		let start = Date()
		try block()
		let end = Date()
		return end.timeIntervalSince(start)
	}

	/// Measures execution time and returns both result and duration.
	private func measureWithResult<T>(_ block: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
		let start = Date()
		let result = try block()
		let end = Date()
		return (result, end.timeIntervalSince(start))
	}

	// MARK: - Time Series Performance

	@Test("Large time series creation - 10,000 periods")
	func largeTimeSeriesCreation10K() throws {
		let size = 10_000

		let duration = measure {
			// Use monthly periods (more realistic for business data and faster)
			let periods = (0..<size).map { (Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1), Double($0)) }
//			let values = (0..<size).map { print ("\(Double($0))"); return $0 }
			let _ = TimeSeries(periods: periods.map({$0.0}), values: periods.map({Double($0.1)}))
		}

		print("  Created 10K period time series in \(String(format: "%.3f", duration))s")
		#expect(duration < 30.0, "Should create 10K time series in reasonable time")
	}

	@Test("Large time series creation - 50,000 periods")
	func largeTimeSeriesCreation50K() throws {
		let size = 50_000

		let duration = measure {
			// Use monthly periods for performance
			let periods = (0..<size).map { (Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1), Double($0)) }
//			let values = (0..<size).map {print ("\(Double($0))"); return $0 }
			let _ = TimeSeries(periods: periods.map({$0.0}), values: periods.map({Double($0.1)}))
		}

		print("  Created 50K period time series in \(String(format: "%.3f", duration))s")
		#expect(duration < 70.0, "Should create 50K time series in reasonable time")
	}

	@Test("Large time series subscript access")
	func largeTimeSeriesAccess() throws {
		let size = 10_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { Double($0) }
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			// Random access 1000 times
			for _ in 0..<1000 {
				let idx = Int.random(in: 0..<size)
				let _ = ts[periods[idx]]
			}
		}

		print("  1000 random accesses in 10K time series: \(String(format: "%.3f", duration))s")
		#expect(duration < 1.0, "Should be fast (O(1) dictionary lookup)")
	}

	@Test("Large time series iteration")
	func largeTimeSeriesIteration() throws {
		let size = 10_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { Double($0) }
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			var sum = 0.0
			for value in ts {
				sum += value
			}
		}

		print("  Iterated 10K time series in \(String(format: "%.3f", duration))s")
		#expect(duration < 5.0, "Should iterate reasonably quickly")
	}

	// MARK: - Time Series Operations Performance

	@Test("Chained operations on large time series")
	func chainedOperations() throws {
		let size = 5_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { 100_000.0 + Double($0) * 100 + Double.random(in: -500...500) }
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure { 
			// Chain multiple operations
			let _ = ts
				.mapValues { $0 * 1.1 }  // Apply 10% increase
				.movingAverage(window: 12)  // 12-month MA
				.percentChange(lag: 1)  // Calculate changes
				.filterValues { !$0.isNaN }  // Remove NaN
		}

		print("  Chained 4 operations on 5K time series: \(String(format: "%.3f", duration))s")
		#expect(duration < 50.0, "Chained operations should complete in reasonable time")
	}

	@Test("Moving average on large time series")
	func movingAverageLarge() throws {
		let size = 10_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { _ in 100.0 + Double.random(in: -10...10) }
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			let _ = ts.movingAverage(window: 12)  // 12-month MA
		}

		print("  12-month MA on 10K series: \(String(format: "%.3f", duration))s")
		#expect(duration < 60.0, "Moving average should complete in reasonable time")
	}

	@Test("Exponential moving average on large time series")
	func exponentialMovingAverageLarge() throws {
		let size = 10_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { _ in 100.0 + Double.random(in: -10...10) }
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			let _ = ts.exponentialMovingAverage(alpha: 0.3)
		}

		print("  EMA on 10K series: \(String(format: "%.3f", duration))s")
		#expect(duration < 25.0, "EMA should complete in reasonable time")
	}

	// MARK: - NPV Performance

	@Test("NPV with 100 cash flows")
	func npv100CashFlows() throws {
		let cashFlows = (0..<100).map { $0 == 0 ? -1_000_000.0 : 50_000.0 }

		let duration = try measure {
			for _ in 0..<1000 {
				let _ = npv(discountRate: 0.10, cashFlows: cashFlows)
			}
		}

		print("  1000 NPV calculations (100 cash flows each): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "NPV should be very fast")
	}

	@Test("NPV with 1,000 cash flows")
	func npv1000CashFlows() throws {
		let cashFlows = (0..<1000).map { $0 == 0 ? -10_000_000.0 : 50_000.0 }

		let duration = try measure {
			for _ in 0..<100 {
				let _ = npv(discountRate: 0.10, cashFlows: cashFlows)
			}
		}

		print("  100 NPV calculations (1000 cash flows each): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "NPV should scale well")
	}

	// MARK: - IRR Performance

	@Test("IRR with 10 cash flows")
	func irr10CashFlows() throws {
		let cashFlows = [-100_000.0, 20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000, 55_000, 60_000]

		let duration = try measure {
			for _ in 0..<100 {
				let _ = try? irr(cashFlows: cashFlows)
			}
		}

		print("  100 IRR calculations (10 cash flows each): \(String(format: "%.3f", duration))s")
		#expect(duration < 1.0, "IRR should converge quickly for simple cases")
	}

	@Test("IRR with 50 cash flows")
	func irr50CashFlows() throws {
		let cashFlows = (0..<50).map { $0 == 0 ? -1_000_000.0 : 50_000.0 }

		let duration = try measure {
			for _ in 0..<50 {
				let _ = try? irr(cashFlows: cashFlows)
			}
		}

		print("  50 IRR calculations (50 cash flows each): \(String(format: "%.3f", duration))s")
		#expect(duration < 2.0, "IRR should handle larger arrays reasonably")
	}

	// MARK: - XIRR Performance

	@Test("XIRR with irregular dates")
	func xirrPerformance() throws {
		let baseDate = Date()
		let dates = (0..<20).map { baseDate.addingTimeInterval(Double($0 * 30) * 86400) }  // ~Monthly
		let cashFlows = (0..<20).map { $0 == 0 ? -100_000.0 : 10_000.0 }

		let duration = try measure {
			for _ in 0..<50 {
				let _ = try? xirr(dates: dates, cashFlows: cashFlows)
			}
		}

		print("  50 XIRR calculations (20 dates each): \(String(format: "%.3f", duration))s")
		#expect(duration < 3.0, "XIRR with date calculations should be reasonable")
	}

	@Test("XNPV with many dates")
	func xnpvPerformance() throws {
		let baseDate = Date()
		let dates = (0..<100).map { baseDate.addingTimeInterval(Double($0 * 7) * 86400) }  // Weekly
		let cashFlows = (0..<100).map { $0 == 0 ? -500_000.0 : 10_000.0 }

		let duration = try measure {
			for _ in 0..<100 {
				let _ = try? xnpv(rate: 0.12, dates: dates, cashFlows: cashFlows)
			}
		}

		print("  100 XNPV calculations (100 dates each): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "XNPV should be fast")
	}

	// MARK: - Trend Model Performance

	@Test("Linear trend fitting - 1,000 points")
	func linearTrendFitting1000() throws {
		let size = 1_000
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { 100_000.0 + Double($0) * 500 + Double.random(in: -1000...1000) }
		let ts = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()

		let duration = try measure {
			try model.fit(to: ts)
		}

		print("  Linear trend fit (1000 points): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "Trend fitting should be fast")
	}

	@Test("Linear trend projection - 1,000 periods")
	func linearTrendProjection() throws {
		let size = 100
		let periods = (0..<size).map { Period.month(year: 2020 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { 100_000.0 + Double($0) * 500 }
		let ts = TimeSeries(periods: periods, values: values)

		var model = LinearTrend<Double>()
		try model.fit(to: ts)

		let duration = try measure {
			let _ = try model.project(periods: 1000)
		}

		print("  Linear trend project 1000 periods: \(String(format: "%.3f", duration))s")
		#expect(duration < 3.0, "Projection should complete in reasonable time")
	}

	@Test("Exponential trend fitting")
	func exponentialTrendFitting() throws {
		let size = 500
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { 100_000.0 * pow(1.01, Double($0)) }
		let ts = TimeSeries(periods: periods, values: values)

		var model = ExponentialTrend<Double>()

		let duration = try measure {
			try model.fit(to: ts)
		}

		print("  Exponential trend fit (500 points): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "Exponential trend should fit quickly")
	}

	@Test("Logistic trend fitting")
	func logisticTrendFitting() throws {
		let size = 300
		let periods = (0..<size).map { Period.month(year: 2000 + $0/12, month: ($0 % 12) + 1) }
		let capacity = 10_000.0
		let values = (0..<size).map { _ in capacity / (1.0 + exp(Double.random(in: -2...2))) }
		let ts = TimeSeries(periods: periods, values: values)

		var model = LogisticTrend<Double>(capacity: capacity)

		let duration = try measure {
			try model.fit(to: ts)
		}

		print("  Logistic trend fit (300 points): \(String(format: "%.3f", duration))s")
		#expect(duration < 1.0, "Logistic trend should fit reasonably")
	}

	// MARK: - Seasonality Performance

	@Test("Seasonal indices calculation - 10 years monthly")
	func seasonalIndices10Years() throws {
		let size = 120  // 10 years × 12 months
		let periods = (0..<size).map { Period.month(year: 2015 + $0/12, month: ($0 % 12) + 1) }

		// Generate data with seasonal pattern
		let values = (0..<size).map { i -> Double in
			let trend = 100_000.0 + Double(i) * 500
			let seasonal = 1.0 + 0.2 * sin(Double(i % 12) * .pi / 6)
			return trend * seasonal
		}

		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			let _ = try seasonalIndices(timeSeries: ts, periodsPerYear: 12)
		}

		print("  Seasonal indices (120 months): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "Seasonal calculation should be efficient")
	}

	@Test("Seasonal adjustment - 10 years monthly")
	func seasonalAdjustment10Years() throws {
		let size = 120
		let periods = (0..<size).map { Period.month(year: 2015 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<size).map { i -> Double in
			let trend = 100_000.0 + Double(i) * 500
			let seasonal = 1.0 + 0.2 * sin(Double(i % 12) * .pi / 6)
			return trend * seasonal
		}
		let ts = TimeSeries(periods: periods, values: values)

		let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: 12)

		let duration = try measure {
			let _ = try seasonallyAdjust(timeSeries: ts, indices: indices)
		}

		print("  Seasonal adjustment (120 months): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "Adjustment should be reasonably fast")
	}

	@Test("Time series decomposition - 10 years quarterly")
	func decomposition10Years() throws {
		let size = 40  // 10 years × 4 quarters
		let periods = (0..<size).map { Period.quarter(year: 2015 + $0/4, quarter: ($0 % 4) + 1) }
		let values = (0..<size).map { i -> Double in
			let trend = 500_000.0 + Double(i) * 10_000
			let seasonal = [0.9, 1.0, 0.95, 1.15][i % 4]
			return trend * seasonal
		}
		let ts = TimeSeries(periods: periods, values: values)

		let duration = try measure {
			let _ = try decomposeTimeSeries(timeSeries: ts, periodsPerYear: 4, method: .multiplicative)
		}

		print("  Time series decomposition (40 quarters): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "Decomposition should complete quickly")
	}

	// MARK: - Real-World Workflow Performance

	@Test("Complete revenue forecasting workflow")
	func completeRevenueWorkflow() throws {
		// 3 years of monthly historical data
		let historicalSize = 36
		let periods = (0..<historicalSize).map { Period.month(year: 2022 + $0/12, month: ($0 % 12) + 1) }
		let values = (0..<historicalSize).map { i -> Double in
			let trend = 100_000.0 + Double(i) * 1_000
			let seasonal = [0.9, 0.95, 0.95, 1.15, 1.0, 1.05, 0.95, 0.90, 1.0, 1.05, 1.1, 1.2][i % 12]
			return trend * seasonal + Double.random(in: -2000...2000)
		}
		let historical = TimeSeries(periods: periods, values: values)

		let (_, duration) = try measureWithResult { () -> TimeSeries<Double> in
			// 1. Extract seasonality
			let indices = try seasonalIndices(timeSeries: historical, periodsPerYear: 12)

			// 2. Deseasonalize
			let deseasonalized = try seasonallyAdjust(timeSeries: historical, indices: indices)

			// 3. Fit trend
			var trend = LinearTrend<Double>()
			try trend.fit(to: deseasonalized)

			// 4. Project forward 12 months
			let forecast = try trend.project(periods: 12)

			// 5. Reapply seasonality
			return try applySeasonal(timeSeries: forecast, indices: indices)
		}

		print("  Complete forecast workflow (36→12 months): \(String(format: "%.3f", duration))s")
		#expect(duration < 0.5, "End-to-end workflow should be fast")
	}

	@Test("Complete investment analysis workflow")
	func completeInvestmentWorkflow() throws {
		let cashFlows = [-100_000.0, 20_000, 25_000, 30_000, 35_000, 40_000, 45_000, 50_000]
		let rate = 0.12

		let duration = try measure {
			// Calculate all investment metrics
			let _ = npv(discountRate: rate, cashFlows: cashFlows)
			let _ = try? irr(cashFlows: cashFlows)
			let _ = profitabilityIndex(rate: rate, cashFlows: cashFlows)
			let _ = paybackPeriod(cashFlows: cashFlows)
			let _ = discountedPaybackPeriod(rate: rate, cashFlows: cashFlows)
		}

		print("  Complete investment analysis: \(String(format: "%.3f", duration))s")
		#expect(duration < 0.1, "Investment analysis should be quick")
	}

	// MARK: - Memory Performance

	@Test("Memory usage with large time series")
	func memoryUsageLarge() throws {
		// This test verifies we can create multiple large time series without issues
		let size = 10_000

		let duration = try measure {
			var series: [TimeSeries<Double>] = []

			for i in 0..<10 {
				let periods = (0..<size).map { Period.month(year: 2000 + ($0 + i * size)/12, month: (($0 + i * size) % 12) + 1) }
				let values = (0..<size).map { Double($0) }
				let ts = TimeSeries(periods: periods, values: values)
				series.append(ts)
			}

			// Force use of series to prevent optimization
			let totalCount = series.reduce(0) { $0 + $1.count }
			#expect(totalCount == size * 10)
		}

		print("  Created 10 × 10K time series: \(String(format: "%.3f", duration))s")
		#expect(duration < 100.0, "Should handle multiple large series")
	}
}
