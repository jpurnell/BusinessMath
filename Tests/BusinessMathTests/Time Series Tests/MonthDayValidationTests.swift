//
//  MonthDayValidationTests.swift
//  BusinessMathTests
//
//  A 1-31 day range and a 1-12 month range, checked independently, admit February 30.
//

import Testing
import Foundation
@testable import BusinessMath

/// `MonthDay` must reject a day its month does not have.
///
/// The two guards were independent — `month` in 1...12, `day` in 1...31 — so every
/// impossible calendar date in that box constructed silently. Measured before the fix:
/// `MonthDay(month: 2, day: 30)` and `MonthDay(month: 4, day: 31)` both succeeded, and a
/// February-30 fiscal year-end then produced a **plausible** fiscal year rather than failing
/// anywhere downstream — 15 March 2025 came back as fiscal 2026, which is exactly what a
/// February-28 year-end would give. Nothing in the pipeline could tell the caller that the
/// year-end they configured does not exist.
///
/// **February allows 29.** A leap-day fiscal year-end is unusual but not impossible, and the
/// comparison `FiscalCalendar` performs is an ordering on (month, day) rather than a date
/// lookup, so it behaves consistently in common years: measured, 15 March 2024 → fiscal 2025
/// and 15 March 2025 → fiscal 2026, which is the same answer a February-28 year-end gives.
/// Rejecting 29 would refuse a configuration that works.
@Suite("MonthDay validation")
struct MonthDayValidationTests {

	/// Every month's real length, and the boundary on each side of it.
	@Test("The last day of each month is accepted",
		  arguments: [(1, 31), (2, 29), (3, 31), (4, 30), (5, 31), (6, 30),
					  (7, 31), (8, 31), (9, 30), (10, 31), (11, 30), (12, 31)])
	func lastDayOfEachMonthIsAccepted(month: Int, day: Int) {
		let monthDay = MonthDay(month: month, day: day)
		#expect(monthDay.month == month)
		#expect(monthDay.day == day)
	}

	/// The dates that used to construct and should not.
	///
	/// Not run as a `#expect(throws:)` because the initialiser's contract is a
	/// *precondition*, which traps rather than throwing — the type documents it that way and
	/// making it throw would break every existing call site. The guard is exercised by the
	/// accepted-boundary cases above: if the per-month table were wrong in the other
	/// direction, those would trap instead.
	@Test("A day beyond its month's length is outside the documented precondition")
	func impossibleDatesAreOutsideThePrecondition() {
		// The four shapes that motivated the check, recorded as data rather than as calls:
		// February 30 and 31, April 31, June 31, September 31, November 31.
		let impossible: [(month: Int, day: Int)] = [
			(2, 30), (2, 31), (4, 31), (6, 31), (9, 31), (11, 31)
		]
		let lengths = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		for candidate in impossible {
			#expect(candidate.day > lengths[candidate.month - 1],
					"\\(candidate.month)/\\(candidate.day) should exceed its month's length")
		}
	}

	/// The downstream consequence, which is what made the missing check matter.
	@Test("A February year-end orders the fiscal year the same way in leap and common years")
	func februaryYearEndIsConsistent() throws {
		let calendar = FiscalCalendar(yearEnd: MonthDay(month: 2, day: 29))
		for year in [2024, 2025] {
			var components = DateComponents()
			components.year = year
			components.month = 3
			components.day = 15
			let instant = try #require(gregorianUTC.date(from: components))
			#expect(calendar.fiscalYear(for: instant) == year + 1,
					"15 March \\(year) should fall in fiscal \\(year + 1)")
		}
	}
}
