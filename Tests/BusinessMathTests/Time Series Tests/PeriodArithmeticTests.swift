//
//  PeriodArithmeticTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Period Arithmetic Tests")
struct PeriodArithmeticTests {

	// MARK: - Addition: Sub-Daily Periods

	@Test("Add milliseconds to period")
	func addMilliseconds() {
		let start = Period.millisecond(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 45, millisecond: 500)
		let end = start + 750  // Add 750 milliseconds

		let calendar = Calendar.current
		let components = calendar.dateComponents([.second, .nanosecond], from: end.date)
		#expect(components.second == 46)  // Should advance to next second
		// 500ms + 750ms = 1250ms = 1 second + 250ms
		let expectedNanos = 250_000_000
		let actualNanos = components.nanosecond ?? 0
		#expect(abs(actualNanos - expectedNanos) < 1_000_000)
	}

	@Test("Add seconds to period")
	func addSeconds() {
		let start = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 0)
		let end = start + 1500  // Add 1500 seconds = 25 minutes

		let calendar = Calendar.current
		let components = calendar.dateComponents([.hour, .minute, .second], from: end.date)
		#expect(components.hour == 14)
		#expect(components.minute == 55)
		#expect(components.second == 0)
	}

	@Test("Add minutes to period")
	func addMinutes() {
		let start = Period.minute(year: 2025, month: 1, day: 29, hour: 14, minute: 0)
		let end = start + 150  // Add 150 minutes = 2.5 hours

		let calendar = Calendar.current
		let components = calendar.dateComponents([.hour, .minute], from: end.date)
		#expect(components.hour == 16)
		#expect(components.minute == 30)
	}

	@Test("Add hours to period")
	func addHours() {
		let start = Period.hour(year: 2025, month: 1, day: 29, hour: 10)
		let end = start + 5

		let calendar = Calendar.current
		let components = calendar.dateComponents([.hour], from: end.date)
		#expect(components.hour == 15)
	}

	@Test("Add hours across day boundary")
	func addHoursAcrossDayBoundary() {
		let start = Period.hour(year: 2025, month: 1, day: 29, hour: 22)
		let end = start + 4  // Should cross to next day

		let calendar = Calendar.current
		let components = calendar.dateComponents([.day, .hour], from: end.date)
		#expect(components.day == 30)
		#expect(components.hour == 2)
	}

	// MARK: - Subtraction: Period - Period (Sub-Daily)

	@Test("Subtract sub-daily periods")
	func subtractHours() throws {
		let start = Period.hour(year: 2025, month: 1, day: 29, hour: 15)
		let end = Period.hour(year: 2025, month: 1, day: 29, hour: 10)
		let difference = try start.distance(to: end)
		#expect(difference == -5)
	}

	@Test("Distance between seconds")
	func distanceBetweenSeconds() throws {
		let start = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 0)
		let end = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 31, second: 30)
		let difference = try start.distance(to: end)
		#expect(difference == 90)  // 1 minute 30 seconds = 90 seconds
	}

	// MARK: - Comparison: Mixed Granularity

	@Test("Periods with different granularity compare correctly")
	func mixedGranularityComparison() {
		let hourPeriod = Period.hour(year: 2025, month: 1, day: 29, hour: 14)
		let minutePeriod = Period.minute(year: 2025, month: 1, day: 29, hour: 14, minute: 30)
		// Smaller granularity (minute) comes before larger granularity (hourly)
		#expect(minutePeriod < hourPeriod)
	}

	@Test("Sub-daily periods sort correctly with daily periods")
	func subDailyWithDailySort() {
		let hour = Period.hour(year: 2025, month: 1, day: 29, hour: 10)
		let day = Period.day(Date(timeIntervalSince1970: 1738195200)) // 2025-01-30

		#expect(hour < day)
	}

	// MARK: - Addition: Period + Int

	@Test("Add 1 month to January gives February")
	func addOneMonth() {
		let jan = Period.month(year: 2025, month: 1)
		let feb = jan + 1

		#expect(feb.type == .monthly)

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: feb.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 2)
	}

	@Test("Add 3 months to January gives April")
	func addThreeMonths() {
		let jan = Period.month(year: 2025, month: 1)
		let apr = jan + 3

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: apr.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 4)
	}

	@Test("Add months across year boundary")
	func addMonthsAcrossYear() {
		let dec2024 = Period.month(year: 2024, month: 12)
		let jan2025 = dec2024 + 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan2025.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 1)
	}

	@Test("Add 12 months equals one year later")
	func addTwelveMonths() {
		let jan2025 = Period.month(year: 2025, month: 1)
		let jan2026 = jan2025 + 12

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan2026.startDate)
		#expect(components.year == 2026)
		#expect(components.month == 1)
	}

	@Test("Add 1 quarter to Q1 gives Q2")
	func addOneQuarter() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q2 = q1 + 1

		#expect(q2.type == .quarterly)

		let calendar = Calendar.current
		let components = calendar.dateComponents([.month], from: q2.startDate)
		#expect(components.month == 4) // Q2 starts in April
	}

	@Test("Add quarters across year boundary")
	func addQuartersAcrossYear() {
		let q4_2024 = Period.quarter(year: 2024, quarter: 4)
		let q1_2025 = q4_2024 + 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: q1_2025.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 1)
	}

	@Test("Add 1 day to a date")
	func addOneDay() {
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let day1 = Period.day(date)
		let day2 = day1 + 1

		let resultComponents = calendar.dateComponents([.year, .month, .day], from: day2.startDate)
		#expect(resultComponents.year == 2025)
		#expect(resultComponents.month == 1)
		#expect(resultComponents.day == 16)
	}

	@Test("Add days across month boundary")
	func addDaysAcrossMonth() {
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 31
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let jan31 = Period.day(date)
		let feb1 = jan31 + 1

		let resultComponents = calendar.dateComponents([.year, .month, .day], from: feb1.startDate)
		#expect(resultComponents.year == 2025)
		#expect(resultComponents.month == 2)
		#expect(resultComponents.day == 1)
	}

	@Test("Add 1 year to annual period")
	func addOneYear() {
		let year2025 = Period.year(2025)
		let year2026 = year2025 + 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year], from: year2026.startDate)
		#expect(components.year == 2026)
	}

	@Test("Add zero periods returns same period")
	func addZero() {
		let jan = Period.month(year: 2025, month: 1)
		let same = jan + 0

		#expect(same == jan)
	}

	// MARK: - Subtraction: Period - Int

	@Test("Subtract 1 month from February gives January")
	func subtractOneMonth() {
		let feb = Period.month(year: 2025, month: 2)
		let jan = feb - 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 1)
	}

	@Test("Subtract months across year boundary")
	func subtractMonthsAcrossYear() {
		let jan2025 = Period.month(year: 2025, month: 1)
		let dec2024 = jan2025 - 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: dec2024.startDate)
		#expect(components.year == 2024)
		#expect(components.month == 12)
	}

	@Test("Subtract 12 months equals one year earlier")
	func subtractTwelveMonths() {
		let jan2026 = Period.month(year: 2026, month: 1)
		let jan2025 = jan2026 - 12

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan2025.startDate)
		#expect(components.year == 2025)
		#expect(components.month == 1)
	}

	@Test("Subtract 1 quarter from Q2 gives Q1")
	func subtractOneQuarter() {
		let q2 = Period.quarter(year: 2025, quarter: 2)
		let q1 = q2 - 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.month], from: q1.startDate)
		#expect(components.month == 1) // Q1 starts in January
	}

	@Test("Subtract quarters across year boundary")
	func subtractQuartersAcrossYear() {
		let q1_2025 = Period.quarter(year: 2025, quarter: 1)
		let q4_2024 = q1_2025 - 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: q4_2024.startDate)
		#expect(components.year == 2024)
		#expect(components.month == 10)
	}

	@Test("Subtract 1 day from a date")
	func subtractOneDay() {
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 16
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let day2 = Period.day(date)
		let day1 = day2 - 1

		let resultComponents = calendar.dateComponents([.year, .month, .day], from: day1.startDate)
		#expect(resultComponents.year == 2025)
		#expect(resultComponents.month == 1)
		#expect(resultComponents.day == 15)
	}

	@Test("Subtract days across month boundary")
	func subtractDaysAcrossMonth() {
		var components = DateComponents()
		components.year = 2025
		components.month = 2
		components.day = 1
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let feb1 = Period.day(date)
		let jan31 = feb1 - 1

		let resultComponents = calendar.dateComponents([.year, .month, .day], from: jan31.startDate)
		#expect(resultComponents.year == 2025)
		#expect(resultComponents.month == 1)
		#expect(resultComponents.day == 31)
	}

	@Test("Subtract 1 year from annual period")
	func subtractOneYear() {
		let year2026 = Period.year(2026)
		let year2025 = year2026 - 1

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year], from: year2025.startDate)
		#expect(components.year == 2025)
	}

	@Test("Subtract zero periods returns same period")
	func subtractZero() {
		let jan = Period.month(year: 2025, month: 1)
		let same = jan - 0

		#expect(same == jan)
	}

	// MARK: - Distance: Period.distance(to:)

	@Test("Distance from January to February is 1")
	func distanceOneMonth() throws {
		let jan = Period.month(year: 2025, month: 1)
		let feb = Period.month(year: 2025, month: 2)

		let distance = try jan.distance(to: feb)
		#expect(distance == 1)
	}

	@Test("Distance from January to April is 3")
	func distanceThreeMonths() throws {
		let jan = Period.month(year: 2025, month: 1)
		let apr = Period.month(year: 2025, month: 4)

		let distance = try jan.distance(to: apr)
		#expect(distance == 3)
	}

	@Test("Distance backward is negative")
	func distanceBackward() throws {
		let apr = Period.month(year: 2025, month: 4)
		let jan = Period.month(year: 2025, month: 1)

		let distance = try apr.distance(to: jan)
		#expect(distance == -3)
	}

	@Test("Distance from same period to itself is 0")
	func distanceSame() throws {
		let jan = Period.month(year: 2025, month: 1)
		let distance = try jan.distance(to: jan)
		#expect(distance == 0)
	}

	@Test("Distance across years")
	func distanceAcrossYears() throws {
		let dec2024 = Period.month(year: 2024, month: 12)
		let mar2025 = Period.month(year: 2025, month: 3)

		let distance = try dec2024.distance(to: mar2025)
		#expect(distance == 3)
	}

	@Test("Distance for quarters")
	func distanceQuarters() throws {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q3 = Period.quarter(year: 2025, quarter: 3)

		let distance = try q1.distance(to: q3)
		#expect(distance == 2)
	}

	@Test("Distance for years")
	func distanceYears() throws {
		let year2020 = Period.year(2020)
		let year2025 = Period.year(2025)

		let distance = try year2020.distance(to: year2025)
		#expect(distance == 5)
	}

	@Test("Distance for days")
	func distanceDays() throws {
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 1
		let calendar = Calendar.current
		let date1 = calendar.date(from: components)!

		components.day = 10
		let date2 = calendar.date(from: components)!

		let day1 = Period.day(date1)
		let day10 = Period.day(date2)

		let distance = try day1.distance(to: day10)
		#expect(distance == 9)
	}

	@Test("Distance between different period types throws error")
	func distanceDifferentTypes() throws {
		let month = Period.month(year: 2025, month: 1)
		let quarter = Period.quarter(year: 2025, quarter: 1)

		// Verify that attempting to calculate distance throws the correct error
		#expect(throws: PeriodError.typeMismatch(from: .monthly, to: .quarterly)) {
			try month.distance(to: quarter)
		}

		// Also verify the reverse direction
		#expect(throws: PeriodError.typeMismatch(from: .quarterly, to: .monthly)) {
			try quarter.distance(to: month)
		}

		// Verify different combinations
		let day = Period.day(Date())
		#expect(throws: PeriodError.typeMismatch(from: .monthly, to: .daily)) {
			try month.distance(to: day)
		}
	}

	// MARK: - Range: Period...Period

	@Test("Range from January to March creates 3 months")
	func rangeThreeMonths() {
		let jan = Period.month(year: 2025, month: 1)
		let mar = Period.month(year: 2025, month: 3)

		let range = jan...mar
		let periods = Array(range)

		#expect(periods.count == 3)
		#expect(periods[0] == jan)
		#expect(periods[1] == Period.month(year: 2025, month: 2))
		#expect(periods[2] == mar)
	}

	@Test("Range across year boundary")
	func rangeAcrossYear() {
		let nov = Period.month(year: 2024, month: 11)
		let feb = Period.month(year: 2025, month: 2)

		let range = nov...feb
		let periods = Array(range)

		#expect(periods.count == 4)
		#expect(periods[0] == nov)
		#expect(periods[1] == Period.month(year: 2024, month: 12))
		#expect(periods[2] == Period.month(year: 2025, month: 1))
		#expect(periods[3] == feb)
	}

	@Test("Range with single period")
	func rangeSingle() {
		let jan = Period.month(year: 2025, month: 1)
		let range = jan...jan
		let periods = Array(range)

		#expect(periods.count == 1)
		#expect(periods[0] == jan)
	}

	@Test("Range for quarters")
	func rangeQuarters() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		let range = q1...q4
		let periods = Array(range)

		#expect(periods.count == 4)
		#expect(periods[0] == q1)
		#expect(periods[3] == q4)
	}

	@Test("Range for years")
	func rangeYears() {
		let year2020 = Period.year(2020)
		let year2024 = Period.year(2024)

		let range = year2020...year2024
		let periods = Array(range)

		#expect(periods.count == 5)
		#expect(periods[0] == year2020)
		#expect(periods[4] == year2024)
	}

	@Test("Range iteration with for-in loop")
	func rangeIteration() {
		let jan = Period.month(year: 2025, month: 1)
		let mar = Period.month(year: 2025, month: 3)

		var count = 0
		for _ in jan...mar {
			count += 1
		}

		#expect(count == 3)
	}

	@Test("Can use range in array operations")
	func rangeArrayOperations() {
		let q1 = Period.quarter(year: 2025, quarter: 1)
		let q4 = Period.quarter(year: 2025, quarter: 4)

		let quarters = Array(q1...q4)
		let labels = quarters.map { $0.label }

		#expect(labels.count == 4)
		#expect(labels[0] == "2025-Q1")
		#expect(labels[3] == "2025-Q4")
	}

	// MARK: - Edge Cases

	@Test("Add large number of periods")
	func addLargePeriods() {
		let jan2020 = Period.month(year: 2020, month: 1)
		let jan2030 = jan2020 + 120 // 10 years = 120 months

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan2030.startDate)
		#expect(components.year == 2030)
		#expect(components.month == 1)
	}

	@Test("Subtract large number of periods")
	func subtractLargePeriods() {
		let jan2030 = Period.month(year: 2030, month: 1)
		let jan2020 = jan2030 - 120 // 10 years = 120 months

		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month], from: jan2020.startDate)
		#expect(components.year == 2020)
		#expect(components.month == 1)
	}

	@Test("Arithmetic preserves period type")
	func arithmeticPreservesType() {
		let month = Period.month(year: 2025, month: 1)
		let result = month + 5
		#expect(result.type == .monthly)

		let quarter = Period.quarter(year: 2025, quarter: 1)
		let quarterResult = quarter + 2
		#expect(quarterResult.type == .quarterly)

		let year = Period.year(2025)
		let yearResult = year + 3
		#expect(yearResult.type == .annual)
	}

	@Test("Leap year handling in arithmetic")
	func leapYearArithmetic() {
		// Feb 29, 2024 (leap year) + 12 months = Feb 29, 2025?
		// No, 2025 is not a leap year, so should go to Feb 28, 2025
		var components = DateComponents()
		components.year = 2024
		components.month = 2
		components.day = 29
		let calendar = Calendar.current
		let leapDay = calendar.date(from: components)!

		let feb29_2024 = Period.day(leapDay)
		let oneYearLater = feb29_2024 + 365

		let resultComponents = calendar.dateComponents([.year, .month, .day], from: oneYearLater.startDate)
		// Should handle this gracefully - either Feb 28, 2025 or Mar 1, 2025
		#expect(resultComponents.year == 2025)
	}

	@Test("Negative arithmetic produces earlier periods")
	func negativeArithmetic() {
		let mar = Period.month(year: 2025, month: 3)
		let jan = mar + (-2) // Same as mar - 2

		let calendar = Calendar.current
		let components = calendar.dateComponents([.month], from: jan.startDate)
		#expect(components.month == 1)
	}

	@Test("Arithmetic with negative numbers")
	func arithmeticWithNegatives() {
		let feb = Period.month(year: 2025, month: 2)

		let dec = feb - 2 // January - 1 = December 2024
		let decAlt = feb + (-2) // Should be the same

		#expect(dec == decAlt)
	}

	@Test("Very long range creates many periods")
	func longRange() {
		let jan = Period.month(year: 2020, month: 1)
		let dec = Period.month(year: 2020, month: 12)

		let range = jan...dec
		let periods = Array(range)

		#expect(periods.count == 12)
	}

	@Test("Can create range spanning multiple years")
	func multiYearRange() {
		let year2020 = Period.year(2020)
		let year2025 = Period.year(2025)

		let range = year2020...year2025
		let years = Array(range)

		#expect(years.count == 6)
	}

	// MARK: - Validation

	@Test("Distance and arithmetic are consistent")
	func distanceArithmeticConsistency() throws {
		let jan = Period.month(year: 2025, month: 1)
		let apr = Period.month(year: 2025, month: 4)

		let distance = try jan.distance(to: apr)
		let computed = jan + distance

		#expect(computed == apr)
	}

	@Test("Addition and subtraction are inverses")
	func additionSubtractionInverse() {
		let jan = Period.month(year: 2025, month: 1)
		let result = (jan + 5) - 5

		#expect(result == jan)
	}

	@Test("Range count equals distance plus one")
	func rangeCountEqualsDistance() throws {
		let jan = Period.month(year: 2025, month: 1)
		let mar = Period.month(year: 2025, month: 3)

		let distance = try jan.distance(to: mar)
		let rangeCount = Array(jan...mar).count

		#expect(rangeCount == distance + 1)
	}
}
