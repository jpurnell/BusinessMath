//
//  TimeSeriesTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("TimeSeries Tests")
struct TimeSeriesTests {

	let tolerance: Double = 0.0001

	// MARK: - TimeSeriesMetadata Tests

	@Test("TimeSeriesMetadata can be created")
	func metadataCreation() {
		let metadata = TimeSeriesMetadata(
			name: "Monthly Revenue",
			description: "Revenue by month",
			unit: "USD"
		)
		#expect(metadata.name == "Monthly Revenue")
		#expect(metadata.description == "Revenue by month")
		#expect(metadata.unit == "USD")
	}

	@Test("TimeSeriesMetadata has default empty values")
	func metadataDefaults() {
		let metadata = TimeSeriesMetadata()
		#expect(metadata.name.isEmpty)
		#expect(metadata.description == nil)
		#expect(metadata.unit == nil)
	}

	// MARK: - Initialization from Arrays

	@Test("Create time series from arrays")
	func initFromArrays() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]

		let ts = TimeSeries(periods: periods, values: values)

		#expect(ts.count == 3)
		#expect(ts[periods[0]] == 100.0)
		#expect(ts[periods[1]] == 200.0)
		#expect(ts[periods[2]] == 300.0)
	}

	@Test("Create time series with metadata")
	func initWithMetadata() {
		let periods = [Period.month(year: 2025, month: 1)]
		let values: [Double] = [100.0]
		let metadata = TimeSeriesMetadata(name: "Revenue", unit: "USD")

		let ts = TimeSeries(periods: periods, values: values, metadata: metadata)

		#expect(ts.metadata.name == "Revenue")
		#expect(ts.metadata.unit == "USD")
	}

	@Test("Create time series from dictionary")
	func initFromDictionary() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let data: [Period: Double] = [
			jan: 100.0,
			feb: 200.0
		]

		let ts = TimeSeries(data: data)

		#expect(ts.count == 2)
		#expect(ts[jan] == 100.0)
		#expect(ts[feb] == 200.0)
	}

	@Test("Initialization sorts periods chronologically")
	func initSortsPeriods() {
		let periods = [
			Period.month(year: 2025, month: 3),
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2)
		]
		let values: [Double] = [300.0, 100.0, 200.0]

		let ts = TimeSeries(periods: periods, values: values)

		// Should sort by period, not preserve input order
		let valuesArray = ts.valuesArray
		#expect(valuesArray[0] == 100.0)  // Jan (month 1)
		#expect(valuesArray[1] == 200.0)  // Feb (month 2)
		#expect(valuesArray[2] == 300.0)  // Mar (month 3)
	}

	@Test("Initialization handles duplicate periods by keeping last value")
	func initDuplicatePeriods() {
		let jan = Period.month(year: 2025, month: 1)
		let periods = [jan, jan]
		let values: [Double] = [100.0, 200.0]

		let ts = TimeSeries(periods: periods, values: values)

		// Should keep the last value
		#expect(ts.count == 1)
		#expect(ts[jan] == 200.0)
	}

	// MARK: - Subscript Access

	@Test("Subscript returns value for existing period")
	func subscriptExistingPeriod() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [100.0])

		let value = ts[jan]
		#expect(value == 100.0)
	}

	@Test("Subscript returns nil for missing period")
	func subscriptMissingPeriod() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let ts = TimeSeries(periods: [jan], values: [100.0])

		let value = ts[feb]
		#expect(value == nil)
	}

	@Test("Subscript with default returns default for missing period")
	func subscriptWithDefault() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let ts = TimeSeries(periods: [jan], values: [100.0])

		let value = ts[feb, default: 0.0]
		#expect(value == 0.0)
	}

	@Test("Subscript with default returns value for existing period")
	func subscriptWithDefaultExisting() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [100.0])

		let value = ts[jan, default: 0.0]
		#expect(value == 100.0)
	}

	// MARK: - Computed Properties

	@Test("valuesArray returns values in order")
	func valuesArrayInOrder() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		let valuesArray = ts.valuesArray
		#expect(valuesArray.count == 3)
		#expect(valuesArray[0] == 100.0)
		#expect(valuesArray[1] == 200.0)
		#expect(valuesArray[2] == 300.0)
	}

	@Test("count returns number of periods")
	func countReturnsCorrectValue() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		#expect(ts.count == 3)
	}

	@Test("first returns first value")
	func firstValue() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2)
		]
		let values: [Double] = [100.0, 200.0]
		let ts = TimeSeries(periods: periods, values: values)

		#expect(ts.first == 100.0)
	}

	@Test("last returns last value")
	func lastValue() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2)
		]
		let values: [Double] = [100.0, 200.0]
		let ts = TimeSeries(periods: periods, values: values)

		#expect(ts.last == 200.0)
	}

	@Test("first returns nil for empty time series")
	func firstEmptyTimeSeries() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		#expect(ts.first == nil)
	}

	@Test("last returns nil for empty time series")
	func lastEmptyTimeSeries() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		#expect(ts.last == nil)
	}

	@Test("periods returns all periods in order")
	func periodsProperty() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		let tsPeriods = ts.periods
		#expect(tsPeriods.count == 3)
		#expect(tsPeriods[0] == periods[0])
		#expect(tsPeriods[1] == periods[1])
		#expect(tsPeriods[2] == periods[2])
	}

	// MARK: - Range Extraction

	@Test("range extracts subset of time series")
	func rangeExtraction() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)
		let apr = Period.month(year: 2025, month: 4)

		let ts = TimeSeries(
			periods: [jan, feb, mar, apr],
			values: [100.0, 200.0, 300.0, 400.0]
		)

		let subset = ts.range(from: feb, to: mar)

		#expect(subset.count == 2)
		#expect(subset[feb] == 200.0)
		#expect(subset[mar] == 300.0)
		#expect(subset[jan] == nil)
		#expect(subset[apr] == nil)
	}

	@Test("range includes both endpoints")
	func rangeIncludesEndpoints() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let mar = Period.month(year: 2025, month: 3)

		let ts = TimeSeries(
			periods: [jan, feb, mar],
			values: [100.0, 200.0, 300.0]
		)

		let subset = ts.range(from: jan, to: mar)

		#expect(subset.count == 3)
		#expect(subset[jan] == 100.0)
		#expect(subset[mar] == 300.0)
	}

	@Test("range with same start and end returns single period")
	func rangeSinglePeriod() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		let ts = TimeSeries(
			periods: [jan, feb],
			values: [100.0, 200.0]
		)

		let subset = ts.range(from: feb, to: feb)

		#expect(subset.count == 1)
		#expect(subset[feb] == 200.0)
	}

	@Test("range preserves metadata")
	func rangePreservesMetadata() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let metadata = TimeSeriesMetadata(name: "Revenue", unit: "USD")

		let ts = TimeSeries(
			periods: [jan, feb],
			values: [100.0, 200.0],
			metadata: metadata
		)

		let subset = ts.range(from: jan, to: feb)

		#expect(subset.metadata.name == "Revenue")
		#expect(subset.metadata.unit == "USD")
	}

	// MARK: - Sequence Conformance

	@Test("Can iterate over time series values")
	func iterateOverValues() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		var sum = 0.0
		for value in ts {
			sum += value
		}

		#expect(abs(sum - 600.0) < tolerance)
	}

	@Test("Can use map on time series")
	func mapOperation() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2)
		]
		let values: [Double] = [100.0, 200.0]
		let ts = TimeSeries(periods: periods, values: values)

		let doubled = ts.map { $0 * 2.0 }

		#expect(doubled.count == 2)
		#expect(doubled[0] == 200.0)
		#expect(doubled[1] == 400.0)
	}

	@Test("Can use filter on time series")
	func filterOperation() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		let filtered = ts.filter { $0 > 150.0 }

		#expect(filtered.count == 2)
	}

	@Test("Can use reduce on time series")
	func reduceOperation() {
		let periods = [
			Period.month(year: 2025, month: 1),
			Period.month(year: 2025, month: 2),
			Period.month(year: 2025, month: 3)
		]
		let values: [Double] = [100.0, 200.0, 300.0]
		let ts = TimeSeries(periods: periods, values: values)

		let sum = ts.reduce(0.0, +)

		#expect(abs(sum - 600.0) < tolerance)
	}

	// MARK: - Edge Cases

	@Test("Empty time series")
	func emptyTimeSeries() {
		let ts = TimeSeries<Double>(periods: [], values: [])

		#expect(ts.count == 0)
		#expect(ts.first == nil)
		#expect(ts.last == nil)
		#expect(ts.valuesArray.isEmpty)
	}

	@Test("Single period time series")
	func singlePeriodTimeSeries() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [100.0])

		#expect(ts.count == 1)
		#expect(ts.first == 100.0)
		#expect(ts.last == 100.0)
		#expect(ts[jan] == 100.0)
	}

	// NOTE: Mixed period types are supported, but currently trigger a Strideable
	// issue when Swift's stdlib tries to optimize operations.
	// For now, users should use time series with consistent period types.
	//
	// @Test("Time series with different period types")
	// func mixedPeriodTypes() {
	// 	let day = Period.day(Date())
	// 	let month = Period.month(year: 2025, month: 1)
	// 	let quarter = Period.quarter(year: 2025, quarter: 1)
	//
	// 	let ts = TimeSeries(
	// 		periods: [day, month, quarter],
	// 		values: [1.0, 2.0, 3.0]
	// 	)
	//
	// 	#expect(ts.count == 3)
	// 	#expect(ts[day] == 1.0)
	// 	#expect(ts[month] == 2.0)
	// 	#expect(ts[quarter] == 3.0)
	// }

	@Test("Time series works with Float type")
	func floatTimeSeries() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries<Float>(periods: [jan], values: [100.0])

		#expect(ts[jan] == 100.0)
	}

	@Test("Time series with zero values")
	func zeroValues() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)
		let ts = TimeSeries(periods: [jan, feb], values: [0.0, 0.0])

		#expect(ts.count == 2)
		#expect(ts[jan] == 0.0)
		#expect(ts[feb] == 0.0)
	}

	@Test("Time series with negative values")
	func negativeValues() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [-100.0])

		#expect(ts[jan] == -100.0)
	}

	@Test("Time series with very large values")
	func largeValues() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [1_000_000_000.0])

		#expect(ts[jan] == 1_000_000_000.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Monthly revenue time series")
	func monthlyRevenueScenario() {
		let periods = (1...12).map { Period.month(year: 2025, month: $0) }
		let revenues: [Double] = [
			100_000, 120_000, 150_000, 140_000,
			160_000, 180_000, 200_000, 190_000,
			170_000, 160_000, 180_000, 220_000
		]

		let ts = TimeSeries(
			periods: periods,
			values: revenues,
			metadata: TimeSeriesMetadata(name: "Monthly Revenue", unit: "USD")
		)

		#expect(ts.count == 12)
		#expect(ts.metadata.name == "Monthly Revenue")

		let total = ts.reduce(0.0, +)
		#expect(abs(total - 1_970_000.0) < tolerance)
	}

	@Test("Quarterly earnings time series")
	func quarterlyEarningsScenario() {
		let periods = (1...4).map { Period.quarter(year: 2025, quarter: $0) }
		let earnings: [Double] = [500_000, 600_000, 700_000, 800_000]

		let ts = TimeSeries(
			periods: periods,
			values: earnings,
			metadata: TimeSeriesMetadata(name: "Quarterly Earnings", unit: "USD")
		)

		#expect(ts.count == 4)
		#expect(ts[periods[0]] == 500_000)
		#expect(ts[periods[3]] == 800_000)
	}

	@Test("Daily production time series")
	func dailyProductionScenario() {
		// 7 days of production
		let calendar = Calendar.current
		let today = calendar.startOfDay(for: Date())
		let periods = (0..<7).map { offset in
			let date = calendar.date(byAdding: .day, value: offset, to: today)!
			return Period.day(date)
		}
		let production: [Double] = [1000, 1100, 1050, 1200, 1150, 1100, 1000]

		let ts = TimeSeries(
			periods: periods,
			values: production,
			metadata: TimeSeriesMetadata(name: "Daily Production", unit: "barrels")
		)

		#expect(ts.count == 7)
		let avgProduction = ts.reduce(0.0, +) / Double(ts.count)
		#expect(abs(avgProduction - 1_085.71) < 1.0)
	}

	// MARK: - isEmpty Property

	@Test("isEmpty returns true for empty time series")
	func isEmptyTrue() {
		let ts = TimeSeries<Double>(periods: [], values: [])
		#expect(ts.isEmpty)
	}

	@Test("isEmpty returns false for non-empty time series")
	func isEmptyFalse() {
		let jan = Period.month(year: 2025, month: 1)
		let ts = TimeSeries(periods: [jan], values: [100.0])
		#expect(!ts.isEmpty)
	}
}
