//
//  ThirtyThreeSixtyVariantTests.swift
//  BusinessMath
//
//  The three 30/360 variants, and the calendar they are counted on.
//
//  Two things are pinned here, and they fail in different ways.
//
//  **The calendar.** A day count is a statement about calendar dates: 29 February to
//  31 December is 301 days under the spreadsheet's 30/360 in every office in the
//  world. Reading those dates through `Calendar.current` made it a statement about
//  the machine instead — the host's time zone decides which day-of-month a `Date`
//  decomposes to, and every 30/360 rule is written in terms of day-of-month. Shift
//  the day by one and the February rule stops firing.
//
//  That is the same root cause as the daylight-saving defect fixed at the three
//  `actual/*` sites, which reached them by making a 24-hour day 23 or 25 hours long.
//  Here it moves the date across midnight instead. Fixing three of four sites left
//  the fourth looking like a rule defect, which is exactly what it was mistaken for.
//
//  **The variants.** `thirty360` returns what `YEARFRAC` basis 0 returns;
//  `siaThirty360` returns what the SIA standard defines. They differ by one line —
//  whether the end-of-month test reads the start day before or after the February
//  adjustment — and they agree everywhere neither end sits on a February month-end,
//  which is most of the time. That is what makes the disagreement dangerous rather
//  than obvious, and it is why the spreadsheet's answer keeps the plain name.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("30/360 variants and their calendar")
struct ThirtyThreeSixtyVariantTests {

	private static func utc() -> Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		return calendar
	}

	private static func date(_ calendar: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date? {
		calendar.date(from: DateComponents(year: y, month: m, day: d))
	}

	private static func days(_ convention: DayCountConvention,
							 _ calendar: Calendar,
							 _ from: (Int, Int, Int), _ to: (Int, Int, Int)) -> Int? {
		guard let start = date(calendar, from.0, from.1, from.2),
			  let end = date(calendar, to.0, to.1, to.2) else { return nil }
		let fraction: Double = convention.yearFraction(from: start, to: end)
		return Int((fraction * 360).rounded())
	}

	// MARK: - The calendar

	@Test("A day count does not depend on the machine's time zone")
	func countIsIndependentOfTheHostTimeZone() throws {
		// The same calendar dates, constructed through two different calendars. Under
		// `Calendar.current` these disagreed: a UTC-midnight 29 February decomposes to
		// the 28th anywhere west of Greenwich, and the February rule then does not
		// fire. Whichever calendar built the `Date`, the count must be the same.
		let utc = Self.utc()
		let local = Calendar.current

		let cases: [((Int, Int, Int), (Int, Int, Int))] = [
			((2020, 2, 29), (2020, 12, 31)),
			((2021, 2, 28), (2021, 12, 31)),
			((2020, 1, 31), (2020, 12, 31)),
			((2020, 2, 29), (2020, 3, 31)),
			((2021, 2, 28), (2021, 7, 31)),
			((2026, 1, 15), (2026, 3, 31)),
		]
		for convention in [DayCountConvention.thirty360, .siaThirty360, .thirty360European] {
			for (from, to) in cases {
				let byUTC = try #require(Self.days(convention, utc, from, to))
				let byLocal = try #require(Self.days(convention, local, from, to))
				#expect(byUTC == byLocal,
						"\(convention.rawValue) \(from) → \(to): \(byUTC) via UTC, \(byLocal) via \(TimeZone.current.identifier)")
			}
		}
	}

	// MARK: - The spreadsheet's rule

	@Test("thirty360 returns what YEARFRAC basis 0 returns")
	func spreadsheetRuleMatchesExcel() throws {
		let calendar = Self.utc()
		// 29 February start: the February rule pulls the start to a 30th, and the end
		// is *not* pulled back because the raw start day was 29, not 30 or 31.
		// 30·10 + (31 − 30) = 301.
		#expect(try #require(Self.days(.thirty360, calendar, (2020, 2, 29), (2020, 12, 31))) == 301)
		// 28 February start, same reasoning: 30·10 + (31 − 30) = 301.
		#expect(try #require(Self.days(.thirty360, calendar, (2021, 2, 28), (2021, 12, 31))) == 301)
		// The case the source comment cites: 151, not 153 and not 150.
		#expect(try #require(Self.days(.thirty360, calendar, (2021, 2, 28), (2021, 7, 31))) == 151)
		// A 31st start with no February involved: pulled back to a 30th, and the end
		// pulled back too because the raw start day was 31.
		#expect(try #require(Self.days(.thirty360, calendar, (2020, 1, 31), (2020, 12, 31))) == 330)
		// Both ends the last day of February: the end becomes a 30th as well.
		#expect(try #require(Self.days(.thirty360, calendar, (2020, 2, 29), (2021, 2, 28))) == 360)
	}

	// MARK: - The standard

	@Test("siaThirty360 tests the end-of-month rule after the February adjustment")
	func siaRuleDiffersByExactlyThatOrdering() throws {
		let calendar = Self.utc()
		// The same two intervals, one day shorter each: the start became a 30th by the
		// February rule, so the standard pulls the 31st end back too.
		#expect(try #require(Self.days(.siaThirty360, calendar, (2020, 2, 29), (2020, 12, 31))) == 300)
		#expect(try #require(Self.days(.siaThirty360, calendar, (2021, 2, 28), (2021, 12, 31))) == 300)
		#expect(try #require(Self.days(.siaThirty360, calendar, (2021, 2, 28), (2021, 7, 31))) == 150)
	}

	@Test("The two American variants agree everywhere February is not involved")
	func variantsAgreeAwayFromFebruary() throws {
		let calendar = Self.utc()
		// This is what makes the disagreement dangerous: it is invisible on ordinary
		// dates, so a suite of ordinary dates cannot tell the two apart, and someone
		// "correcting" the spreadsheet rule would see nothing fail.
		let ordinary: [((Int, Int, Int), (Int, Int, Int))] = [
			((2026, 1, 15), (2026, 3, 31)),
			((2025, 3, 31), (2025, 9, 30)),
			((2024, 6, 30), (2025, 6, 30)),
			((2025, 1, 1), (2025, 12, 31)),
			((2024, 5, 31), (2024, 8, 31)),
			((2023, 4, 15), (2023, 10, 15)),
		]
		var compared = 0
		for (from, to) in ordinary {
			let spreadsheet = try #require(Self.days(.thirty360, calendar, from, to))
			let sia = try #require(Self.days(.siaThirty360, calendar, from, to))
			#expect(spreadsheet == sia,
					"\(from) → \(to): spreadsheet \(spreadsheet), SIA \(sia) — expected agreement away from February")
			compared += 1
		}
		#expect(compared >= 6)

		// And they must differ where February *is* involved, or the pairing is a
		// distinction without a difference and one of the two is misimplemented.
		let februaryStart = try #require(Self.days(.thirty360, calendar, (2020, 2, 29), (2020, 12, 31)))
		let februaryStartSIA = try #require(Self.days(.siaThirty360, calendar, (2020, 2, 29), (2020, 12, 31)))
		#expect(februaryStart != februaryStartSIA,
				"the two variants agree on a February month-end start, so they are the same rule")
	}

	// MARK: - The European rule is unchanged

	@Test("thirty360European has no February rule and pulls a 31st back unconditionally")
	func europeanRuleIsUnchanged() throws {
		let calendar = Self.utc()
		// The table in the type's documentation: 2026-01-15 → 2026-03-31 is 76 US, 75 EU.
		#expect(try #require(Self.days(.thirty360, calendar, (2026, 1, 15), (2026, 3, 31))) == 76)
		#expect(try #require(Self.days(.thirty360European, calendar, (2026, 1, 15), (2026, 3, 31))) == 75)
		// No February rule: a 29 February start stays a 29th.
		// 30·10 + (30 − 29) = 301 — the same number as the spreadsheet here, by a
		// different route, which is why this case cannot stand in for the one above.
		#expect(try #require(Self.days(.thirty360European, calendar, (2020, 2, 29), (2020, 12, 31))) == 301)
	}

	// MARK: - The rest of the enum still behaves

	@Test("The new case carries the same denominator and fixed-length answers as its siblings")
	func newCaseIsWiredIntoEveryProperty() {
		#expect(DayCountConvention.siaThirty360.daysInYear == 360)
		#expect(DayCountConvention.siaThirty360.hasFixedYearLength)
		#expect(DayCountConvention.siaThirty360.rawValue == "30/360 (SIA)")
		// A year is exactly one year on any 30/360 basis.
		let calendar = Self.utc()
		if let start = Self.date(calendar, 2025, 1, 1), let end = Self.date(calendar, 2026, 1, 1) {
			let fraction: Double = DayCountConvention.siaThirty360.yearFraction(from: start, to: end)
			#expect(abs(fraction - 1.0) < 1e-12, "a calendar year is \(fraction) years")
		}
	}
}
