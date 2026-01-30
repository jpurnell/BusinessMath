//
//  PeriodTypeTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("PeriodType Tests")
struct PeriodTypeTests {

	// Default precision for floating point comparisons
	let tolerance: Double = 0.0001

	// MARK: - Basic Enum Cases

	@Test("All period types are defined")
	func allCasesExist() {
		let types: [PeriodType] = [.millisecond, .second, .minute, .hourly, .daily, .monthly, .quarterly, .annual]
		#expect(types.count == 8)
	}

	// MARK: - Integer Raw Values

	@Test("Period types follow natural ordering via raw values")
	func integerRawValues() {
		#expect(PeriodType.millisecond.rawValue == 0)
		#expect(PeriodType.second.rawValue == 1)
		#expect(PeriodType.minute.rawValue == 2)
		#expect(PeriodType.hourly.rawValue == 3)
		#expect(PeriodType.daily.rawValue == 4)
		#expect(PeriodType.monthly.rawValue == 5)
		#expect(PeriodType.quarterly.rawValue == 6)
		#expect(PeriodType.annual.rawValue == 7)
	}

	@Test("Period types can be created from integer raw values")
	func initFromInteger() {
		#expect(PeriodType(rawValue: 0) == .millisecond)
		#expect(PeriodType(rawValue: 1) == .second)
		#expect(PeriodType(rawValue: 2) == .minute)
		#expect(PeriodType(rawValue: 3) == .hourly)
		#expect(PeriodType(rawValue: 4) == .daily)
		#expect(PeriodType(rawValue: 5) == .monthly)
		#expect(PeriodType(rawValue: 6) == .quarterly)
		#expect(PeriodType(rawValue: 7) == .annual)
		#expect(PeriodType(rawValue: 99) == nil)
	}

	// MARK: - Comparable Conformance

	@Test("Sub-daily period types are ordered correctly")
	func orderingSubDaily() {
		#expect(PeriodType.millisecond < .second)
		#expect(PeriodType.second < .minute)
		#expect(PeriodType.minute < .hourly)
		#expect(PeriodType.hourly < .daily)
	}

	@Test("Period types are ordered correctly: daily < monthly")
	func orderingDailyMonthly() {
		#expect(PeriodType.daily < PeriodType.monthly)
	}

	@Test("Period types are ordered correctly: monthly < quarterly")
	func orderingMonthlyQuarterly() {
		#expect(PeriodType.monthly < PeriodType.quarterly)
	}

	@Test("Period types are ordered correctly: quarterly < annual")
	func orderingQuarterlyAnnual() {
		#expect(PeriodType.quarterly < PeriodType.annual)
	}

	@Test("Period types can be sorted")
	func sorting() {
		let unsorted: [PeriodType] = [.annual, .daily, .quarterly, .monthly, .second, .hourly, .millisecond, .minute]
		let sorted = unsorted.sorted()
		#expect(sorted == [.millisecond, .second, .minute, .hourly, .daily, .monthly, .quarterly, .annual])
	}

	@Test("Same period types are equal")
	func equality() {
		#expect(PeriodType.monthly == PeriodType.monthly)
		#expect(PeriodType.annual == PeriodType.annual)
	}

	@Test("Different period types are not equal")
	func inequality() {
		#expect(PeriodType.monthly != PeriodType.quarterly)
		#expect(PeriodType.daily != PeriodType.annual)
	}

	// MARK: - Days Approximate

	@Test("Daily period has 1 day")
	func daysApproximateDaily() {
		let days = PeriodType.daily.daysApproximate
		#expect(abs(days - 1.0) < tolerance)
	}

	@Test("Monthly period has 30.4375 days")
	func daysApproximateMonthly() {
		// 365.25 days / 12 months = 30.4375 days per month (accounting for leap years)
		let days = PeriodType.monthly.daysApproximate
		let expected = 365.25 / 12.0
		#expect(abs(days - expected) < tolerance)
	}

	@Test("Quarterly period has 91.3125 days")
	func daysApproximateQuarterly() {
		// 365.25 days / 4 quarters = 91.3125 days per quarter
		let days = PeriodType.quarterly.daysApproximate
		let expected = 365.25 / 4.0
		#expect(abs(days - expected) < tolerance)
	}

	@Test("Annual period has 365.25 days")
	func daysApproximateAnnual() {
		// Accounting for leap years (1 extra day every 4 years)
		let days = PeriodType.annual.daysApproximate
		#expect(abs(days - 365.25) < tolerance)
	}

	// MARK: - Milliseconds Exact

	@Test("Millisecond period has 1 millisecond")
	func millisecondsExactMillisecond() {
		let ms = PeriodType.millisecond.millisecondsExact
		#expect(abs(ms - 1.0) < tolerance)
	}

	@Test("Second period has 1000 milliseconds")
	func millisecondsExactSecond() {
		let ms = PeriodType.second.millisecondsExact
		#expect(abs(ms - 1_000.0) < tolerance)
	}

	@Test("Minute period has 60,000 milliseconds")
	func millisecondsExactMinute() {
		let ms = PeriodType.minute.millisecondsExact
		#expect(abs(ms - 60_000.0) < tolerance)
	}

	@Test("Hourly period has 3,600,000 milliseconds")
	func millisecondsExactHourly() {
		let ms = PeriodType.hourly.millisecondsExact
		#expect(abs(ms - 3_600_000.0) < tolerance)
	}

	@Test("Daily period has 86,400,000 milliseconds")
	func millisecondsExactDaily() {
		let ms = PeriodType.daily.millisecondsExact
		#expect(abs(ms - 86_400_000.0) < tolerance)
	}

	@Test("Monthly period has ~2.628 billion milliseconds")
	func millisecondsExactMonthly() {
		// 30.4375 days * 86,400,000 ms/day
		let ms = PeriodType.monthly.millisecondsExact
		let expected = 30.4375 * 86_400_000.0
		#expect(abs(ms - expected) < tolerance)
	}

	@Test("Quarterly period has ~7.884 billion milliseconds")
	func millisecondsExactQuarterly() {
		// 91.3125 days * 86,400,000 ms/day
		let ms = PeriodType.quarterly.millisecondsExact
		let expected = 91.3125 * 86_400_000.0
		#expect(abs(ms - expected) < tolerance)
	}

	@Test("Annual period has ~31.536 billion milliseconds")
	func millisecondsExactAnnual() {
		// 365.25 days * 86,400,000 ms/day
		let ms = PeriodType.annual.millisecondsExact
		let expected = 365.25 * 86_400_000.0
		#expect(abs(ms - expected) < tolerance)
	}

	// MARK: - Months Equivalent

	@Test("Daily period is approximately 0.0329 months")
	func monthsEquivalentDaily() {
		let months = PeriodType.daily.monthsEquivalent
		// 1 day / 30.4375 days per month = 0.03285 months
		let expected = 1.0 / (365.25 / 12.0)
		#expect(abs(months - expected) < tolerance)
	}

	@Test("Monthly period is 1 month")
	func monthsEquivalentMonthly() {
		let months = PeriodType.monthly.monthsEquivalent
		#expect(abs(months - 1.0) < tolerance)
	}

	@Test("Quarterly period is 3 months")
	func monthsEquivalentQuarterly() {
		let months = PeriodType.quarterly.monthsEquivalent
		#expect(abs(months - 3.0) < tolerance)
	}

	@Test("Annual period is 12 months")
	func monthsEquivalentAnnual() {
		let months = PeriodType.annual.monthsEquivalent
		#expect(abs(months - 12.0) < tolerance)
	}

	// MARK: - Period Conversions

	@Test("Convert daily to other periods")
	func convertDailyToPeriods() {
		// 365.25 days = 1 year
		let toAnnual = PeriodType.daily.convert(365.25, to: .annual)
		#expect(abs(toAnnual - 1.0) < tolerance)

		// 30.4375 days ≈ 1 month
		let toMonthly = PeriodType.daily.convert(30.4375, to: .monthly)
		#expect(abs(toMonthly - 1.0) < tolerance)

		// 91.3125 days ≈ 1 quarter
		let toQuarterly = PeriodType.daily.convert(91.3125, to: .quarterly)
		#expect(abs(toQuarterly - 1.0) < tolerance)
	}

	@Test("Convert monthly to other periods")
	func convertMonthlyToPeriods() {
		// 12 months = 1 year
		let toAnnual = PeriodType.monthly.convert(12.0, to: .annual)
		#expect(abs(toAnnual - 1.0) < tolerance)

		// 3 months = 1 quarter
		let toQuarterly = PeriodType.monthly.convert(3.0, to: .quarterly)
		#expect(abs(toQuarterly - 1.0) < tolerance)

		// 1 month = 30.4375 days
		let toDays = PeriodType.monthly.convert(1.0, to: .daily)
		#expect(abs(toDays - 30.4375) < tolerance)
	}

	@Test("Convert quarterly to other periods")
	func convertQuarterlyToPeriods() {
		// 4 quarters = 1 year
		let toAnnual = PeriodType.quarterly.convert(4.0, to: .annual)
		#expect(abs(toAnnual - 1.0) < tolerance)

		// 1 quarter = 3 months
		let toMonthly = PeriodType.quarterly.convert(1.0, to: .monthly)
		#expect(abs(toMonthly - 3.0) < tolerance)

		// 1 quarter = 91.3125 days
		let toDays = PeriodType.quarterly.convert(1.0, to: .daily)
		#expect(abs(toDays - 91.3125) < tolerance)
	}

	@Test("Convert annual to other periods")
	func convertAnnualToPeriods() {
		// 1 year = 4 quarters
		let toQuarterly = PeriodType.annual.convert(1.0, to: .quarterly)
		#expect(abs(toQuarterly - 4.0) < tolerance)

		// 1 year = 12 months
		let toMonthly = PeriodType.annual.convert(1.0, to: .monthly)
		#expect(abs(toMonthly - 12.0) < tolerance)

		// 1 year = 365.25 days
		let toDays = PeriodType.annual.convert(1.0, to: .daily)
		#expect(abs(toDays - 365.25) < tolerance)
	}

	@Test("Convert same period type returns same value")
	func convertSameType() {
		let monthly = PeriodType.monthly.convert(5.0, to: .monthly)
		#expect(abs(monthly - 5.0) < tolerance)

		let quarterly = PeriodType.quarterly.convert(8.0, to: .quarterly)
		#expect(abs(quarterly - 8.0) < tolerance)

		let annual = PeriodType.annual.convert(3.0, to: .annual)
		#expect(abs(annual - 3.0) < tolerance)
	}

	@Test("Convert handles fractional results with precision")
	func convertFractional() {
		// 45 days = 1.478 months (45 / 30.4375)
		let toMonthly = PeriodType.daily.convert(45.0, to: .monthly)
		let expectedMonthly = 45.0 / 30.4375
		#expect(abs(toMonthly - expectedMonthly) < tolerance)

		// 18 months = 1.5 years
		let toAnnual = PeriodType.monthly.convert(18.0, to: .annual)
		#expect(abs(toAnnual - 1.5) < tolerance)

		// 5 quarters = 1.25 years
		let quartersToYears = PeriodType.quarterly.convert(5.0, to: .annual)
		#expect(abs(quartersToYears - 1.25) < tolerance)
	}

	// MARK: - Codable Conformance

	@Test("Period type can be encoded to JSON")
	func encodingToJSON() throws {
		let periodType = PeriodType.monthly
		let encoder = JSONEncoder()
		let data = try encoder.encode(periodType)

		#expect(data.count > 0)

		// Verify it encodes as the raw integer value (5 for monthly)
		let string = String(data: data, encoding: .utf8)
		#expect(string == "5")
	}

	@Test("Period type can be decoded from JSON")
	func decodingFromJSON() throws {
		let json = "6".data(using: .utf8)!  // 6 = quarterly
		let decoder = JSONDecoder()
		let periodType = try decoder.decode(PeriodType.self, from: json)

		#expect(periodType == .quarterly)
	}

	@Test("All period types can be round-trip encoded and decoded")
	func codableRoundTrip() throws {
		let types: [PeriodType] = [.millisecond, .second, .minute, .hourly, .daily, .monthly, .quarterly, .annual]
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		for type in types {
			let encoded = try encoder.encode(type)
			let decoded = try decoder.decode(PeriodType.self, from: encoded)
			#expect(decoded == type)
		}
	}

	@Test("Decoding invalid JSON fails gracefully")
	func decodingInvalidJSON() {
		let json = "99".data(using: .utf8)!  // Invalid raw value
		let decoder = JSONDecoder()

		#expect(throws: Error.self) {
			_ = try decoder.decode(PeriodType.self, from: json)
		}
	}

	// MARK: - CaseIterable

	@Test("All cases can be iterated")
	func caseIterable() {
		let allCases = PeriodType.allCases
		#expect(allCases.count == 8)
		#expect(allCases.contains(.millisecond))
		#expect(allCases.contains(.second))
		#expect(allCases.contains(.minute))
		#expect(allCases.contains(.hourly))
		#expect(allCases.contains(.daily))
		#expect(allCases.contains(.monthly))
		#expect(allCases.contains(.quarterly))
		#expect(allCases.contains(.annual))
	}

	// MARK: - Edge Cases

	@Test("Convert zero periods returns zero")
	func convertZero() {
		let toAnnual = PeriodType.monthly.convert(0.0, to: .annual)
		#expect(abs(toAnnual) < tolerance)

		let toMonthly = PeriodType.daily.convert(0.0, to: .monthly)
		#expect(abs(toMonthly) < tolerance)
	}

	@Test("Convert large numbers maintains precision")
	func convertLargeNumbers() {
		// 10 years in months
		let toMonthly = PeriodType.annual.convert(10.0, to: .monthly)
		#expect(abs(toMonthly - 120.0) < tolerance)

		// 5 years in quarters
		let toQuarterly = PeriodType.annual.convert(5.0, to: .quarterly)
		#expect(abs(toQuarterly - 20.0) < tolerance)

		// 1000 days in months
		let toDaysToMonths = PeriodType.daily.convert(1000.0, to: .monthly)
		let expected = 1000.0 / 30.4375
		#expect(abs(toDaysToMonths - expected) < tolerance)
	}

	@Test("Real-world scenario: oil production over 31-day month")
	func oilProductionScenario() {
		// Producer makes 1000 barrels/day
		// January has 31 days, need to convert to monthly rate
		let dailyProduction = 1000.0
		let daysInJanuary = 31.0

		// Total January production
		let januaryTotal = dailyProduction * daysInJanuary

		// Convert to monthly equivalent rate
		let monthlyRate = PeriodType.daily.convert(januaryTotal, to: .monthly)

		// Expected: 31000 barrels / 30.4375 days per month
		let expected = januaryTotal / 30.4375
		#expect(abs(monthlyRate - expected) < tolerance)
	}

	// MARK: - String Representation

	@Test("Period types have readable string descriptions")
	func stringDescription() {
		// Tests the CustomStringConvertible if implemented
		#expect(String(describing: PeriodType.daily).contains("daily"))
		#expect(String(describing: PeriodType.monthly).contains("monthly"))
		#expect(String(describing: PeriodType.annual).contains("annual"))
	}
}
