//
//  DayCountConventionAdditionsTests.swift
//  BusinessMathTests
//
//  actual/actual (ISDA) and 30E/360 — the two conventions Excel's YEARFRAC basis
//  argument selects that this package did not have.
//
//  Every expected value here is derived from the convention's definition and stated
//  alongside the assertion. These are not tabulated: a day count is short enough to
//  compute by hand, and a reader who cannot check the number cannot review the test.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

/// Several assertions below use `isEqual(to:)` rather than a tolerance. That is
/// deliberate and is the claim being made: a calendar year under ACT/ACT is *exactly*
/// one, and a month under 30E/360 is *exactly* thirty. A tolerance there would pass on
/// an implementation that merely got close, which is the defect these conventions
/// exist to rule out.
@Suite("Day count conventions — actual/actual and 30E/360")
struct DayCountConventionAdditionsTests {

	static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		guard let date = Calendar.current.date(from: components) else {
			preconditionFailure("\(year)-\(month)-\(day) is not a date")
		}
		return date
	}

	// MARK: - actual/actual (ISDA)

	@Test("A whole year is exactly one, leap or not")
	func actualActualWholeYearIsExactlyOne() {
		// The property the convention exists for. ACT/365 gives 366/365 across a leap
		// year and ACT/360 gives 366/360; only ACT/ACT gives one, because each year's
		// portion is divided by that year's own length.
		for year in [2023, 2024, 2025, 2100, 2000] {
			let start = Self.date(year, 1, 1)
			let end = Self.date(year + 1, 1, 1)
			let fraction: Double = DayCountConvention.actualActual.yearFraction(from: start, to: end)
			#expect(fraction.isEqual(to: 1.0),
				"\(year) → \(year + 1) came to \(fraction), not exactly one")
		}
	}

	@Test("Whole years accumulate exactly")
	func actualActualWholeYearsAccumulate() {
		// 2023 → 2026 spans 2024, a leap year. Three calendar years, each worth one.
		let fraction: Double = DayCountConvention.actualActual
			.yearFraction(from: Self.date(2023, 1, 1), to: Self.date(2026, 1, 1))
		#expect(fraction.isEqual(to: 3.0), "three calendar years came to \(fraction)")
	}

	@Test("A part-year is that year's days over that year's length")
	func actualActualPartialYear() {
		// 2024-01-01 → 2024-07-01 is 182 days inside a 366-day year.
		let fraction: Double = DayCountConvention.actualActual
			.yearFraction(from: Self.date(2024, 1, 1), to: Self.date(2024, 7, 1))
		#expect(abs(fraction - 182.0 / 366.0) < 1e-15, "got \(fraction)")

		// 2025-03-15 → 2025-09-15 is 184 days inside a 365-day year.
		let common: Double = DayCountConvention.actualActual
			.yearFraction(from: Self.date(2025, 3, 15), to: Self.date(2025, 9, 15))
		#expect(abs(common - 184.0 / 365.0) < 1e-15, "got \(common)")
	}

	@Test("A period straddling a year boundary is split at it")
	func actualActualSplitsAtTheYearBoundary() {
		// 2023-07-01 → 2024-07-01. The 2023 part is 184 days over 365; the 2024 part is
		// 182 days over 366. Not 365/365, and not 366/366 either — which is the whole
		// point of the convention and the reason a single divisor cannot express it.
		let expected = 184.0 / 365.0 + 182.0 / 366.0
		let fraction: Double = DayCountConvention.actualActual
			.yearFraction(from: Self.date(2023, 7, 1), to: Self.date(2024, 7, 1))
		#expect(abs(fraction - expected) < 1e-15, "got \(fraction), derived \(expected)")
		#expect(fraction > 1.0, "a year spanning a leap February is more than one year of 365 days")
	}

	@Test("actual/actual counts actual days")
	func actualActualCountsActualDays() {
		#expect(DayCountConvention.actualActual
			.days(from: Self.date(2024, 1, 1), to: Self.date(2024, 3, 1)).isEqual(to: 60.0))
		#expect(DayCountConvention.actualActual
			.days(from: Self.date(2025, 1, 1), to: Self.date(2025, 3, 1)).isEqual(to: 59.0))
	}

	@Test("actual/actual is antisymmetric")
	func actualActualIsAntisymmetric() {
		let early = Self.date(2023, 7, 1)
		let late = Self.date(2024, 7, 1)
		let forward: Double = DayCountConvention.actualActual.yearFraction(from: early, to: late)
		let backward: Double = DayCountConvention.actualActual.yearFraction(from: late, to: early)
		#expect(abs(forward + backward) < 1e-15,
			"forward \(forward) and backward \(backward) do not cancel")
	}

	@Test("actual/actual has no fixed year length, and says so")
	func actualActualHasNoFixedDivisor() {
		#expect(DayCountConvention.actualActual.hasFixedYearLength == false)
		for convention in [DayCountConvention.actual365, .actual360, .thirty360, .thirty360European] {
			#expect(convention.hasFixedYearLength,
				"\(convention) divides by a constant and should say so")
		}
	}

	// MARK: - 30E/360

	@Test("30E/360 pulls a 31st back to a 30th at both ends, unconditionally")
	func europeanThirty360AdjustsBothEnds() {
		// This is the whole difference from the US rule, which only pulls the end date
		// back when the start date was itself pulled back.
		//
		// 2026-01-15 → 2026-03-31:
		//   US: start 15 (unchanged), end 31 stays 31 because start was not 30
		//       → 30·2 + (31 − 15) = 76
		//   EU: start 15, end 31 → 30 regardless
		//       → 30·2 + (30 − 15) = 75
		let start = Self.date(2026, 1, 15)
		let end = Self.date(2026, 3, 31)
		#expect(DayCountConvention.thirty360.days(from: start, to: end).isEqual(to: 76.0))
		#expect(DayCountConvention.thirty360European.days(from: start, to: end).isEqual(to: 75.0))
	}

	@Test("30E/360 agrees with the US rule when neither end is a 31st")
	func europeanAgreesWhenNoThirtyFirstIsInvolved() {
		// 2026-01-31 → 2026-02-28: start pulled to 30 by both, end is 28 either way.
		//   30·1 + (28 − 30) = 28
		let cases: [(Date, Date, Double)] = [
			(Self.date(2026, 1, 31), Self.date(2026, 2, 28), 28),
			(Self.date(2026, 1, 30), Self.date(2026, 3, 31), 60),
			(Self.date(2025, 8, 31), Self.date(2026, 2, 28), 178)
		]
		for (start, end, expected) in cases {
			#expect(DayCountConvention.thirty360.days(from: start, to: end).isEqual(to: expected))
			#expect(DayCountConvention.thirty360European.days(from: start, to: end).isEqual(to: expected))
		}
	}

	@Test("30E/360 makes every month 30 days and every year 360")
	func europeanThirty360IsRegular() {
		// The property the 30/360 family exists for: equal coupons.
		for month in 1...12 {
			let start = Self.date(2025, month, 1)
			let end = month == 12 ? Self.date(2026, 1, 1) : Self.date(2025, month + 1, 1)
			#expect(DayCountConvention.thirty360European.days(from: start, to: end).isEqual(to: 30.0),
				"month \(month) is not 30 days")
		}
		let year: Double = DayCountConvention.thirty360European
			.yearFraction(from: Self.date(2025, 1, 1), to: Self.date(2026, 1, 1))
		#expect(year.isEqual(to: 1.0))
		#expect(DayCountConvention.thirty360European.daysInYear == 360)
	}

	@Test("Both new conventions are Codable and round-trip through their raw values")
	func newConventionsAreCodable() throws {
		for convention in [DayCountConvention.actualActual, .thirty360European] {
			let raw = convention.rawValue
			#expect(DayCountConvention(rawValue: raw) == convention,
				"\(raw) did not round-trip")
		}
		// CaseIterable must see them, or anything enumerating conventions misses them.
		#expect(DayCountConvention.allCases.count == 5)
		#expect(DayCountConvention.allCases.contains(.actualActual))
		#expect(DayCountConvention.allCases.contains(.thirty360European))
	}
}
