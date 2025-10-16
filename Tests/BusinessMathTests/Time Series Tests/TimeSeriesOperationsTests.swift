//
//  TimeSeriesOperationsTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("TimeSeries Operations Tests")
struct TimeSeriesOperationsTests {

	let tolerance: Double = 0.0001

	// MARK: - Map Tests

	@Test("map transforms all values")
	func mapTransform() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0])

		let doubled = ts.mapValues { $0 * 2.0 }

		#expect(doubled.count == 3)
		#expect(doubled[periods[0]] == 200.0)
		#expect(doubled[periods[1]] == 400.0)
		#expect(doubled[periods[2]] == 600.0)
	}

	@Test("map preserves periods and metadata")
	func mapPreservesMetadata() {
		let periods = (1...2).map { Period.month(year: 2025, month: $0) }
		let metadata = TimeSeriesMetadata(name: "Revenue", unit: "USD")
		let ts = TimeSeries(periods: periods, values: [100.0, 200.0], metadata: metadata)

		let doubled = ts.mapValues { $0 * 2.0 }

		#expect(doubled.periods == ts.periods)
		#expect(doubled.metadata.name == "Revenue")
		#expect(doubled.metadata.unit == "USD")
	}

	// MARK: - Filter Tests

	@Test("filterValues keeps matching values")
	func filterMatching() {
		let periods = (1...5).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 200.0, 150.0, 300.0, 175.0])

		let filtered = ts.filterValues { $0 > 150.0 }

		#expect(filtered.count == 3)
		#expect(filtered[periods[1]] == 200.0)
		#expect(filtered[periods[3]] == 300.0)
		#expect(filtered[periods[4]] == 175.0)
	}

	@Test("filterValues preserves metadata")
	func filterPreservesMetadata() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let metadata = TimeSeriesMetadata(name: "Revenue")
		let ts = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0], metadata: metadata)

		let filtered = ts.filterValues { $0 > 150.0 }

		#expect(filtered.metadata.name == "Revenue")
	}

	// MARK: - Zip Tests

	@Test("zip combines two time series with matching periods")
	func zipMatching() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts1 = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0])
		let ts2 = TimeSeries(periods: periods, values: [10.0, 20.0, 30.0])

		let combined = ts1.zip(with: ts2) { $0 + $1 }

		#expect(combined.count == 3)
		#expect(combined[periods[0]] == 110.0)
		#expect(combined[periods[1]] == 220.0)
		#expect(combined[periods[2]] == 330.0)
	}

	@Test("zip handles misaligned periods by keeping intersection")
	func zipMisaligned() {
		let periods1 = (1...4).map { Period.month(year: 2025, month: $0) }
		let periods2 = (2...5).map { Period.month(year: 2025, month: $0) }

		let ts1 = TimeSeries(periods: periods1, values: [100.0, 200.0, 300.0, 400.0])
		let ts2 = TimeSeries(periods: periods2, values: [20.0, 30.0, 40.0, 50.0])

		let combined = ts1.zip(with: ts2) { $0 + $1 }

		// Should only include Feb, Mar, Apr (periods in both)
		#expect(combined.count == 3)
		#expect(combined[Period.month(year: 2025, month: 2)] == 220.0)  // 200 + 20
		#expect(combined[Period.month(year: 2025, month: 3)] == 330.0)  // 300 + 30
		#expect(combined[Period.month(year: 2025, month: 4)] == 440.0)  // 400 + 40
	}

	@Test("zip with empty series returns empty")
	func zipWithEmpty() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts1 = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0])
		let ts2 = TimeSeries<Double>(periods: [], values: [])

		let combined = ts1.zip(with: ts2) { $0 + $1 }

		#expect(combined.isEmpty)
	}

	// MARK: - Fill Forward Tests

	@Test("fillForward propagates last known value")
	func fillForwardPropagation() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let apr = Period.month(year: 2025, month: 4)

		let allPeriods = [jan, feb, mar, apr]
		var data: [Period: Double] = [:]
		data[jan] = 100.0
		// feb is missing
		data[mar] = 300.0
		// apr is missing

		let sparse = TimeSeries(data: data)
		let filled = sparse.fillForward(over: allPeriods)

		#expect(filled[jan] == 100.0)
		#expect(filled[feb] == 100.0)  // Forward filled from Jan
		#expect(filled[mar] == 300.0)
		#expect(filled[apr] == 300.0)  // Forward filled from Mar
	}

	@Test("fillForward with no initial value leaves gaps")
	func fillForwardNoInitial() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let allPeriods = [jan, feb, mar]
		var data: [Period: Double] = [:]
		// jan is missing
		data[feb] = 200.0
		data[mar] = 300.0

		let sparse = TimeSeries(data: data)
		let filled = sparse.fillForward(over: allPeriods)

		#expect(filled[jan] == nil)  // No value to fill from
		#expect(filled[feb] == 200.0)
		#expect(filled[mar] == 300.0)
	}

	// MARK: - Fill Backward Tests

	@Test("fillBackward propagates next known value")
	func fillBackwardPropagation() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let apr = Period.month(year: 2025, month: 4)

		let allPeriods = [jan, feb, mar, apr]
		var data: [Period: Double] = [:]
		// jan is missing
		data[feb] = 200.0
		// mar is missing
		data[apr] = 400.0

		let sparse = TimeSeries(data: data)
		let filled = sparse.fillBackward(over: allPeriods)

		#expect(filled[jan] == 200.0)  // Backward filled from Feb
		#expect(filled[feb] == 200.0)
		#expect(filled[mar] == 400.0)  // Backward filled from Apr
		#expect(filled[apr] == 400.0)
	}

	// MARK: - Fill Missing Tests

	@Test("fillMissing replaces gaps with constant")
	func fillMissingConstant() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let allPeriods = [jan, feb, mar]
		var data: [Period: Double] = [:]
		data[jan] = 100.0
		// feb is missing
		data[mar] = 300.0

		let sparse = TimeSeries(data: data)
		let filled = sparse.fillMissing(with: 0.0, over: allPeriods)

		#expect(filled[jan] == 100.0)
		#expect(filled[feb] == 0.0)  // Filled with constant
		#expect(filled[mar] == 300.0)
	}

	// MARK: - Interpolate Tests

	@Test("interpolate fills gaps with linear interpolation")
	func interpolateLinear() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let apr = Period.month(year: 2025, month: 4)

		let allPeriods = [jan, feb, mar, apr]
		var data: [Period: Double] = [:]
		data[jan] = 100.0
		// feb and mar are missing
		data[apr] = 400.0

		let sparse = TimeSeries(data: data)
		let interpolated = sparse.interpolate(over: allPeriods)

		#expect(interpolated[jan] == 100.0)
		#expect(abs(interpolated[feb]! - 200.0) < tolerance)  // Linear: 100 + (400-100)/3 * 1
		#expect(abs(interpolated[mar]! - 300.0) < tolerance)  // Linear: 100 + (400-100)/3 * 2
		#expect(interpolated[apr] == 400.0)
	}

	@Test("interpolate with no endpoints leaves gaps")
	func interpolateNoEndpoints() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let allPeriods = [jan, feb, mar]
		let data: [Period: Double] = [:]
		// All missing - can't interpolate
		let sparse = TimeSeries(data: data)
		let interpolated = sparse.interpolate(over: allPeriods)

		#expect(interpolated[jan] == nil)
		#expect(interpolated[feb] == nil)
		#expect(interpolated[mar] == nil)
	}

	// MARK: - Aggregate Tests

	@Test("aggregate monthly to quarterly using sum")
	func aggregateMonthlyToQuarterlySum() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let apr = Period.month(year: 2025, month: 4)

		let monthly = TimeSeries(
			periods: [jan, feb, mar, apr],
			values: [100.0, 200.0, 300.0, 400.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .sum)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q2 = Period.quarter(year: 2025, quarter: 2)

		#expect(quarterly.count == 2)
		#expect(quarterly[q1] == 600.0)  // Jan + Feb + Mar
		#expect(quarterly[q2] == 400.0)  // Apr only (incomplete quarter)
	}

	@Test("aggregate monthly to quarterly using average")
	func aggregateMonthlyToQuarterlyAverage() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let monthly = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 200.0, 300.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .average)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		#expect(quarterly.count == 1)
		#expect(abs(quarterly[q1]! - 200.0) < tolerance)  // (100 + 200 + 300) / 3
	}

	@Test("aggregate monthly to annual")
	func aggregateMonthlyToAnnual() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }
		let values = Array(repeating: 100.0, count: 12)

		let monthly = TimeSeries(periods: periods, values: values)
		let annual = monthly.aggregate(to: .annual, method: .sum)

		let year2025 = Period.year(2025)

		#expect(annual.count == 1)
		#expect(annual[year2025] == 1200.0)  // 12 * 100
	}

	@Test("aggregate using first method")
	func aggregateFirst() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let monthly = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 200.0, 300.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .first)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		#expect(quarterly[q1] == 100.0)  // First value in Q1
	}

	@Test("aggregate using last method")
	func aggregateLast() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let monthly = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 200.0, 300.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .last)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		#expect(quarterly[q1] == 300.0)  // Last value in Q1
	}

	@Test("aggregate using min method")
	func aggregateMin() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let monthly = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 50.0, 300.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .min)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		#expect(quarterly[q1] == 50.0)  // Min value in Q1
	}

	@Test("aggregate using max method")
	func aggregateMax() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let monthly = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 50.0, 300.0]
		)

		let quarterly = monthly.aggregate(to: .quarterly, method: .max)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		#expect(quarterly[q1] == 300.0)  // Max value in Q1
	}

	// MARK: - Edge Cases

	@Test("mapValues on empty series returns empty")
	func mapEmpty() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		let mapped = ts.mapValues { $0 * 2.0 }
		#expect(mapped.isEmpty)
	}

	@Test("filterValues can return empty series")
	func filterToEmpty() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let ts = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0])

		let filtered = ts.filterValues { $0 > 1000.0 }

		#expect(filtered.isEmpty)
	}

	@Test("aggregate preserves metadata")
	func aggregatePreservesMetadata() {
		let periods = (1...3).map { Period.month(year: 2025, month: $0) }
		let metadata = TimeSeriesMetadata(name: "Monthly Revenue", unit: "USD")
		let monthly = TimeSeries(periods: periods, values: [100.0, 200.0, 300.0], metadata: metadata)

		let quarterly = monthly.aggregate(to: .quarterly, method: .sum)

		#expect(quarterly.metadata.name == "Monthly Revenue")
		#expect(quarterly.metadata.unit == "USD")
	}
}
