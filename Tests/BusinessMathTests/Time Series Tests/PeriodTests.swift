//
//  PeriodTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Period Tests")
struct PeriodTests {

	let tolerance: Double = 0.0001

	// MARK: - Note on Fiscal Years
	// Period uses calendar years by default. Fiscal year support (e.g., Apple's Sept 30 year-end)
	// will be provided through integration with FiscalCalendar (Phase 1.4), which will map
	// calendar periods to fiscal periods.

	// MARK: - Factory Methods: Sub-Daily

	@Test("Can create millisecond period")
	func createMillisecondPeriod() {
		let period = Period.millisecond(
			year: 2025, month: 1, day: 29,
			hour: 14, minute: 30, second: 45, millisecond: 123
		)
		#expect(period.type == .millisecond)

		let calendar = Calendar.current
		let components = calendar.dateComponents(
			[.year, .month, .day, .hour, .minute, .second, .nanosecond],
			from: period.date
		)
		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 29)
		#expect(components.hour == 14)
		#expect(components.minute == 30)
		#expect(components.second == 45)
		// Allow small precision difference due to Date/Calendar rounding
		let expectedNanos = 123_000_000
		let actualNanos = components.nanosecond ?? 0
		#expect(abs(actualNanos - expectedNanos) < 1_000_000) // Within 1ms tolerance
	}

	@Test("Can create second period")
	func createSecondPeriod() {
		let period = Period.second(
			year: 2025, month: 1, day: 29,
			hour: 14, minute: 30, second: 45
		)
		#expect(period.type == .second)

		let calendar = Calendar.current
		let components = calendar.dateComponents(
			[.year, .month, .day, .hour, .minute, .second],
			from: period.date
		)
		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 29)
		#expect(components.hour == 14)
		#expect(components.minute == 30)
		#expect(components.second == 45)
	}

	@Test("Can create minute period")
	func createMinutePeriod() {
		let period = Period.minute(
			year: 2025, month: 1, day: 29,
			hour: 14, minute: 30
		)
		#expect(period.type == .minute)

		let calendar = Calendar.current
		let components = calendar.dateComponents(
			[.year, .month, .day, .hour, .minute],
			from: period.date
		)
		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 29)
		#expect(components.hour == 14)
		#expect(components.minute == 30)
	}

	@Test("Can create hour period")
	func createHourPeriod() {
		let period = Period.hour(
			year: 2025, month: 1, day: 29,
			hour: 14
		)
		#expect(period.type == .hourly)

		let calendar = Calendar.current
		let components = calendar.dateComponents(
			[.year, .month, .day, .hour],
			from: period.date
		)
		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 29)
		#expect(components.hour == 14)
	}

	// MARK: - Factory Methods: Daily

	@Test("Create daily period from Date")
	func createDailyPeriod() {
		let date = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
		let period = Period.day(date)

		#expect(period.type == .daily)

		// Compare date components rather than exact Date (timezone-aware)
		let calendar = Calendar.current
		let inputComponents = calendar.dateComponents([.year, .month, .day], from: date)
		let periodComponents = calendar.dateComponents([.year, .month, .day], from: period.date)

		#expect(inputComponents.year == periodComponents.year)
		#expect(inputComponents.month == periodComponents.month)
		#expect(inputComponents.day == periodComponents.day)
	}

	// MARK: - Factory Methods: Monthly

	@Test("Create monthly period")
	func createMonthlyPeriod() {
		let period = Period.month(year: 2025, month: 1)
		#expect(period.type == .monthly)
	}

	@Test("Create monthly period for all 12 months")
	func createAllMonths() {
		for month in 1...12 {
			let period = Period.month(year: 2025, month: month)
			#expect(period.type == .monthly)
		}
	}

	@Test("Monthly period invalid month causes precondition failure",
	      .disabled("Test crashes the test runner - precondition() failures cannot be caught in Swift Testing"))
	func monthlyPeriodInvalidMonth() {
		// Month must be 1-12, otherwise precondition failure
		// Swift Testing cannot catch precondition failures, so this test is disabled
		// to prevent crashing the entire test suite.

		// NOTE: This test documents that Period.month() validates input with precondition(),
		// which is intentional API design for programmer errors (not runtime errors).

		withKnownIssue("precondition() cannot be caught in Swift Testing") {
			_ = Period.month(year: 2025, month: 0)  // Should trigger precondition failure
		}

		withKnownIssue("precondition() cannot be caught in Swift Testing") {
			_ = Period.month(year: 2025, month: 13)  // Should trigger precondition failure
		}
	}

	// MARK: - Factory Methods: Quarterly

	@Test("Create quarterly period Q1")
	func createQuarterlyQ1() {
		let period = Period.quarter(year: 2025, quarter: 1)
		#expect(period.type == .quarterly)
	}

	@Test("Create all 4 quarters")
	func createAllQuarters() {
		for quarter in 1...4 {
			let period = Period.quarter(year: 2025, quarter: quarter)
			#expect(period.type == .quarterly)
		}
	}

	@Test("Quarterly period invalid quarter causes precondition failure",
	      .disabled("Test crashes the test runner - precondition() failures cannot be caught in Swift Testing"))
	func quarterlyPeriodInvalidQuarter() {
		// Quarter must be 1-4, otherwise precondition failure
		// Swift Testing cannot catch precondition failures, so this test is disabled
		// to prevent crashing the entire test suite.

		// NOTE: This test documents that Period.quarter() validates input with precondition(),
		// which is intentional API design for programmer errors (not runtime errors).

		withKnownIssue("precondition() cannot be caught in Swift Testing") {
			_ = Period.quarter(year: 2025, quarter: 0)  // Should trigger precondition failure
		}

		withKnownIssue("precondition() cannot be caught in Swift Testing") {
			_ = Period.quarter(year: 2025, quarter: 5)  // Should trigger precondition failure
		}
	}

	// MARK: - Factory Methods: Annual

	@Test("Create annual period")
	func createAnnualPeriod() {
		let period = Period.year(2025)

		#expect(period.type == .annual)
	}

	@Test("Create annual periods for multiple years")
	func createMultipleYears() {
		for year in 2020...2030 {
			let period = Period.year(year)
			#expect(period.type == .annual)
		}
	}

	// MARK: - Start Date

	@Test("Daily period start date is beginning of day")
	func dailyStartDate() {
		let period = Period.month(year: 2025, month: 1)
		let startDate = period.startDate

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate)

		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 1)
		#expect(components.hour == 0)
		#expect(components.minute == 0)
		#expect(components.second == 0)
	}

	@Test("Monthly period start date is first of month")
	func monthlyStartDate() {
		let period = Period.month(year: 2025, month: 3)
		let startDate = period.startDate

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: startDate)

		#expect(components.year == 2025)
		#expect(components.month == 3)
		#expect(components.day == 1)
	}

	@Test("Quarterly period start date is first day of first month")
	func quarterlyStartDate() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q2 = Period.quarter(year: 2025, quarter: 2)
		let q3 = Period.quarter(year: 2025, quarter: 3)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		let calendar = Calendar.current

		let q1Start = calendar.dateComponents([.year, .month, .day], from: q1.startDate)
		#expect(q1Start.month == 1)
		#expect(q1Start.day == 1)

		let q2Start = calendar.dateComponents([.year, .month, .day], from: q2.startDate)
		#expect(q2Start.month == 4)
		#expect(q2Start.day == 1)

		let q3Start = calendar.dateComponents([.year, .month, .day], from: q3.startDate)
		#expect(q3Start.month == 7)
		#expect(q3Start.day == 1)

		let q4Start = calendar.dateComponents([.year, .month, .day], from: q4.startDate)
		#expect(q4Start.month == 10)
		#expect(q4Start.day == 1)
	}

	@Test("Annual period start date is January 1")
	func annualStartDate() {
		let period = Period.year(2025)
		let startDate = period.startDate

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: startDate)

		#expect(components.year == 2025)
		#expect(components.month == 1)
		#expect(components.day == 1)
	}

	// MARK: - End Date

	@Test("Monthly period end date is last moment of last day")
	func monthlyEndDate() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		let calendar = Calendar.current

		let janEnd = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: jan.endDate)
		#expect(janEnd.year == 2025)
		#expect(janEnd.month == 1)
		#expect(janEnd.day == 31)
		#expect(janEnd.hour == 23)
		#expect(janEnd.minute == 59)
		#expect(janEnd.second == 59)

		let febEnd = calendar.dateComponents([.year, .month, .day], from: feb.endDate)
		#expect(febEnd.year == 2025)
		#expect(febEnd.month == 2)
		#expect(febEnd.day == 28) // 2025 is not a leap year
	}

	@Test("February leap year end date")
	func februaryLeapYear() {
		let feb2024 = Period.month(year: 2024, month: 2) // 2024 is a leap year

		let calendar = Calendar.current
		let components = calendar.dateComponents([.day], from: feb2024.endDate)

		#expect(components.day == 29)
	}

	@Test("Quarterly period end date is last day of third month")
	func quarterlyEndDate() {
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: q1.endDate)

		#expect(components.year == 2025)
		#expect(components.month == 3)
		#expect(components.day == 31)
	}

	@Test("Annual period end date is December 31")
	func annualEndDate() {
		let period = Period.year(2025)

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: period.endDate)

		#expect(components.year == 2025)
		#expect(components.month == 12)
		#expect(components.day == 31)
	}

	// MARK: - Label

	@Test("Monthly period label uses compact format")
	func monthlyLabel() {
		let jan = Period.month(year: 2025, month: 1)
		let dec = Period.month(year: 2025, month: 12)

		// Compact format: "2025-01", "2025-12"
		#expect(jan.label == "2025-01")
		#expect(dec.label == "2025-12")
	}

	@Test("Quarterly period label uses compact format")
	func quarterlyLabel() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		// Compact format: "2025-Q1", "2025-Q4"
		#expect(q1.label == "2025-Q1")
		#expect(q4.label == "2025-Q4")
	}

	@Test("Annual period label uses compact format")
	func annualLabel() {
		let period = Period.year(2025)

		// Compact format: "2025"
		#expect(period.label == "2025")
	}

	@Test("Daily period label uses compact format")
	func dailyLabel() {
		// Create a specific date: Jan 15, 2025
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!
//		print(date)
		let period = Period.day(date)
//		print(period)
		// Compact format: "2025-01-15"
		#expect(period.label == "2025-01-15")
	}

	@Test("Period can be formatted with custom DateFormatter")
	func customFormatting() {
		let jan = Period.month(year: 2025, month: 1)

		let formatter = DateFormatter()
		formatter.dateFormat = "MMMM yyyy"

		let formatted = jan.formatted(using: formatter)

		// Should produce "January 2025" or similar based on locale
		#expect(formatted.contains("2025"))
		#expect(formatted.contains("January") || formatted.contains("Jan"))
	}

	// MARK: - Hashable

	@Test("Periods with same values are equal")
	func periodsEqual() {
		let period1 = Period.month(year: 2025, month: 1)
		let period2 = Period.month(year: 2025, month: 1)

		#expect(period1 == period2)
	}

	@Test("Periods with different values are not equal")
	func periodsNotEqual() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		#expect(jan != feb)
	}

	@Test("Periods can be used as dictionary keys")
	func periodsAsDictionaryKeys() {
		var dict: [Period: Double] = [:]

		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		dict[jan] = 100.0
		dict[feb] = 200.0

		#expect(dict[jan] == 100.0)
		#expect(dict[feb] == 200.0)
	}

	@Test("Same period retrieves same value from dictionary")
	func dictionaryRetrievalConsistency() {
		var dict: [Period: Double] = [:]

		let period1 = Period.month(year: 2025, month: 1)
		dict[period1] = 100.0

		let period2 = Period.month(year: 2025, month: 1)
		#expect(dict[period2] == 100.0)
	}

	// MARK: - Comparable

	@Test("Earlier period is less than later period")
	func periodOrdering() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		#expect(jan < feb)
	}

	@Test("Periods can be sorted chronologically")
	func periodSorting() {
		let mar = Period.month(year: 2025, month: 3)
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		let unsorted = [mar, jan, feb]
		let sorted = unsorted.sorted()

		#expect(sorted[0] == jan)
		#expect(sorted[1] == feb)
		#expect(sorted[2] == mar)
	}

	@Test("Periods from different years sort correctly")
	func crossYearSorting() {
		let dec2024 = Period.month(year: 2024, month: 12)
		let jan2025 = Period.month(year: 2025, month: 1)

		#expect(dec2024 < jan2025)
	}

	@Test("Different period types are ordered by type first, then date")
	func compareDifferentTypes() {
		// All start on Jan 1, 2025, but ordered by type (shorter first)
		let day = Period.day(Date(timeIntervalSince1970: 1735689600)) // 2025-01-01
		let jan = Period.month(year: 2025, month: 1)
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let year = Period.year(2025)

		// Order: daily < monthly < quarterly < annual
		#expect(day < jan)
		#expect(jan < q1)
		#expect(q1 < year)
	}

	@Test("Same type periods with different dates are ordered by date")
	func sameTypeOrdering() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		#expect(jan < feb)
	}

	@Test("Sorting mixed period types and dates")
	func sortMixedPeriods() {
		let feb = Period.month(year: 2025, month: 2)
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let jan = Period.month(year: 2025, month: 1)
		let year = Period.year(2025)

		let unsorted = [feb, q1, jan, year]
		let sorted = unsorted.sorted()

		// Expected: jan (monthly), feb (monthly), q1 (quarterly), year (annual)
		#expect(sorted[0] == jan)
		#expect(sorted[1] == feb)
		#expect(sorted[2] == q1)
		#expect(sorted[3] == year)
	}

	// MARK: - Codable

	@Test("Period can be encoded to JSON")
	func encodeToJSON() throws {
		let period = Period.month(year: 2025, month: 3)
		let encoder = JSONEncoder()
		let data = try encoder.encode(period)

		#expect(data.count > 0)
	}

	@Test("Period can be decoded from JSON")
	func decodeFromJSON() throws {
		let period = Period.month(year: 2025, month: 3)
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		let encoded = try encoder.encode(period)
		let decoded = try decoder.decode(Period.self, from: encoded)

		#expect(decoded == period)
	}

	@Test("All period types can round-trip encode/decode")
	func codableRoundTrip() throws {
		let periods = [
			Period.day(Date()),
			Period.month(year: 2025, month: 6),
			Period.quarter(year: 2025, quarter: 2),
			Period.year(2025)
		]

		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		for period in periods {
			let encoded = try encoder.encode(period)
			let decoded = try decoder.decode(Period.self, from: encoded)
			#expect(decoded == period)
		}
	}

	// MARK: - Period Subdivision: months()

	@Test("Year period can be subdivided into 12 months")
	func yearToMonths() {
		let year = Period.year(2025)
		let months = year.months()

		#expect(months.count == 12)

		// Check first and last months
		let calendar = Calendar.current
		let firstMonth = calendar.dateComponents([.month], from: months[0].startDate)
		let lastMonth = calendar.dateComponents([.month], from: months[11].startDate)

		#expect(firstMonth.month == 1)
		#expect(lastMonth.month == 12)
	}

	@Test("Quarter period can be subdivided into 3 months")
	func quarterToMonths() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let months = q1.months()

		#expect(months.count == 3)

		let calendar = Calendar.current
		let month1 = calendar.dateComponents([.month], from: months[0].startDate)
		let month2 = calendar.dateComponents([.month], from: months[1].startDate)
		let month3 = calendar.dateComponents([.month], from: months[2].startDate)

		#expect(month1.month == 1)
		#expect(month2.month == 2)
		#expect(month3.month == 3)
	}

	@Test("Monthly period months() returns single month")
	func monthToMonths() {
		let jan = Period.month(year: 2025, month: 1)
		let months = jan.months()

		#expect(months.count == 1)
		#expect(months[0] == jan)
	}

	@Test("Daily period cannot be subdivided into months")
	func dailyToMonths() {
		let day = Period.day(Date())
		let months = day.months()

		// Daily periods cannot be subdivided - should return empty array
		#expect(months.isEmpty)
	}

	// MARK: - Period Subdivision: quarters()

	@Test("Year period can be subdivided into 4 quarters")
	func yearToQuarters() {
		let year = Period.year(2025)
		let quarters = year.quarters()

		#expect(quarters.count == 4)

		// Check that each quarter starts in correct month
		let calendar = Calendar.current
		let q1Start = calendar.dateComponents([.month], from: quarters[0].startDate)
		let q2Start = calendar.dateComponents([.month], from: quarters[1].startDate)
		let q3Start = calendar.dateComponents([.month], from: quarters[2].startDate)
		let q4Start = calendar.dateComponents([.month], from: quarters[3].startDate)

		#expect(q1Start.month == 1)
		#expect(q2Start.month == 4)
		#expect(q3Start.month == 7)
		#expect(q4Start.month == 10)
	}

	@Test("Quarterly period quarters() returns self")
	func quarterToQuarters() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let quarters = q1.quarters()

		#expect(quarters.count == 1)
		#expect(quarters[0] == q1)
	}

	@Test("Daily period cannot be subdivided into quarters")
	func dailyToQuarters() {
		let day = Period.day(Date())
		let quarters = day.quarters()

		// Daily periods cannot be subdivided - should return empty array
		#expect(quarters.isEmpty)
	}

	@Test("Monthly period cannot be subdivided into quarters")
	func monthlyToQuarters() {
		let month = Period.month(year: 2025, month: 1)
		let quarters = month.quarters()

		// Monthly periods cannot be subdivided into quarters - should return empty array
		#expect(quarters.isEmpty)
	}

	// MARK: - Period Subdivision: days()

	@Test("Monthly period can be subdivided into days")
	func monthToDays() {
		let jan = Period.month(year: 2025, month: 1)
		let days = jan.days()

		#expect(days.count == 31) // January has 31 days
	}

	@Test("February non-leap year has 28 days")
	func februaryNonLeapYearDays() {
		let feb = Period.month(year: 2025, month: 2)
		let days = feb.days()

		#expect(days.count == 28)
	}

	@Test("February leap year has 29 days")
	func februaryLeapYearDays() {
		let feb = Period.month(year: 2024, month: 2) // 2024 is leap year
		let days = feb.days()

		#expect(days.count == 29)
	}

	@Test("Daily period days() returns self")
	func dayToDays() {
		let day = Period.day(Date())
		let days = day.days()

		#expect(days.count == 1)
		#expect(days[0] == day)
	}

	@Test("Quarterly period can be subdivided into days")
	func quarterToDays() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let days = q1.days()

		// Q1 2025: Jan (31) + Feb (28) + Mar (31) = 90 days
		#expect(days.count == 90)
	}

	@Test("Annual period can be subdivided into days")
	func yearToDays() {
		let year2025 = Period.year(2025)
		let days = year2025.days()

		// 2025 is not a leap year: 365 days
		#expect(days.count == 365)

		let year2024 = Period.year(2024)
		let leapDays = year2024.days()

		// 2024 is a leap year: 366 days
		#expect(leapDays.count == 366)
	}

	// MARK: - Period Subdivision: hours()

	@Test("Can subdivide day into hours")
	func dayToHours() {
		let day = Period.day(Date(timeIntervalSince1970: 1738195200)) // 2025-01-30
		let hours = day.hours()
		#expect(hours.count == 24)
		#expect(hours.first!.type == .hourly)
	}

	@Test("Can subdivide hour into itself")
	func hourToHours() {
		let hour = Period.hour(year: 2025, month: 1, day: 29, hour: 14)
		let hours = hour.hours()
		#expect(hours.count == 1)
		#expect(hours.first! == hour)
	}

	// MARK: - Period Subdivision: minutes()

	@Test("Can subdivide hour into minutes")
	func hourToMinutes() {
		let hour = Period.hour(year: 2025, month: 1, day: 29, hour: 14)
		let minutes = hour.minutes()
		#expect(minutes.count == 60)
		#expect(minutes.first!.type == .minute)
	}

	@Test("Can subdivide minute into itself")
	func minuteToMinutes() {
		let minute = Period.minute(year: 2025, month: 1, day: 29, hour: 14, minute: 30)
		let minutes = minute.minutes()
		#expect(minutes.count == 1)
		#expect(minutes.first! == minute)
	}

	// MARK: - Period Subdivision: seconds()

	@Test("Can subdivide minute into seconds")
	func minuteToSeconds() {
		let minute = Period.minute(year: 2025, month: 1, day: 29, hour: 14, minute: 30)
		let seconds = minute.seconds()
		#expect(seconds.count == 60)
		#expect(seconds.first!.type == .second)
	}

	@Test("Can subdivide second into itself")
	func secondToSeconds() {
		let second = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 45)
		let seconds = second.seconds()
		#expect(seconds.count == 1)
		#expect(seconds.first! == second)
	}

	// MARK: - Period Subdivision: milliseconds()

	@Test("Can subdivide second into milliseconds")
	func secondToMilliseconds() {
		let second = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 45)
		let milliseconds = second.milliseconds()
		#expect(milliseconds.count == 1000)
		#expect(milliseconds.first!.type == .millisecond)
	}

	@Test("Can subdivide millisecond into itself")
	func millisecondToMilliseconds() {
		let ms = Period.millisecond(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 45, millisecond: 123)
		let milliseconds = ms.milliseconds()
		#expect(milliseconds.count == 1)
		#expect(milliseconds.first! == ms)
	}

	// MARK: - Edge Cases

	@Test("Handle year boundaries correctly")
	func yearBoundaries() {
		let dec = Period.month(year: 2024, month: 12)
		let jan = Period.month(year: 2025, month: 1)

		#expect(dec < jan)

		let calendar = Calendar.current
		let decEnd = calendar.dateComponents([.year, .month, .day], from: dec.endDate)
		let janStart = calendar.dateComponents([.year, .month, .day], from: jan.startDate)

		#expect(decEnd.year == 2024)
		#expect(janStart.year == 2025)
	}

	@Test("Q4 to Q1 transition across years")
	func quarterYearBoundary() {
		let q4_2024 = Period.quarter(year: 2024, quarter: 4)
		let q1_2025 = Period.quarter(year: 2025, quarter: 1)

		#expect(q4_2024 < q1_2025)
	}

	@Test("Century leap year")
	func centuryLeapYear() {
		// 2000 is a leap year (divisible by 400)
		let feb2000 = Period.month(year: 2000, month: 2)
		let days = feb2000.days()
		#expect(days.count == 29)

		// 1900 is not a leap year (divisible by 100 but not 400)
		let feb1900 = Period.month(year: 1900, month: 2)
		let days1900 = feb1900.days()
		#expect(days1900.count == 28)
	}

	@Test("Very old and very future dates")
	func extremeDates() {
		let old = Period.year(1900)
		let future = Period.year(2100)

		#expect(old < future)
	}

	// MARK: - Period Properties

	@Test("Period exposes its type")
	func periodType() {
		let monthly = Period.month(year: 2025, month: 1)
		let quarterly = Period.quarter(year: 2025, quarter: 1)
		let annual = Period.year(2025)

		#expect(monthly.type == .monthly)
		#expect(quarterly.type == .quarterly)
		#expect(annual.type == .annual)
	}

	@Test("Period exposes its reference date")
	func periodDate() {
		let date = Date()
		let period = Period.day(date)

		// The stored date should be at the start of the day
		let calendar = Calendar.current
		let startOfDay = calendar.startOfDay(for: date)
		let components1 = calendar.dateComponents([.year, .month, .day], from: period.date)
		let components2 = calendar.dateComponents([.year, .month, .day], from: startOfDay)

		#expect(components1.year == components2.year)
		#expect(components1.month == components2.month)
		#expect(components1.day == components2.day)
	}

	// MARK: - String Description

	@Test("Periods have readable string descriptions")
	func stringDescription() {
		let monthly = Period.month(year: 2025, month: 1)
		let description = String(describing: monthly)

		// Should contain something meaningful
		#expect(description.count > 0)
	}
}
