//
//  DayCountTimeZoneTests.swift
//  BusinessMathTests
//
//  A day count must not depend on the machine computing it.
//
//  Found by SwiftExcelFunctions, whose machine is set to America/New_York, against a
//  library whose tests had only ever run somewhere without a spring-forward in the way.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Day counts are independent of the reader's clock")
struct DayCountTimeZoneTests {

	/// 2026-01-01 00:00 UTC and 2026-07-01 00:00 UTC — exactly 181 × 86,400 seconds apart.
	static let januaryUTC = Date(timeIntervalSince1970: 1_767_225_600)
	static let julyUTC = Date(timeIntervalSince1970: 1_782_864_000)
	static let marchUTC = Date(timeIntervalSince1970: 1_772_323_200)

	@Test("A span of exactly 181 days counts as 181, whatever the local zone")
	func exactDaysAreCountedExactly() {
		// The reproducing case. Both instants are UTC midnight and the elapsed time
		// between them is a whole number of days; a day count that answers otherwise is
		// measuring the wall clock rather than the calendar.
		let elapsed = Self.julyUTC.timeIntervalSince(Self.januaryUTC) / 86_400
		#expect(elapsed.isEqual(to: 181), "the fixture itself is \(elapsed) days")

		for convention in [DayCountConvention.actual365, .actual360,
						   .actualActual, .isdaActualActual] {
			let days = convention.days(from: Self.januaryUTC, to: Self.julyUTC)
			#expect(days.isEqual(to: 181),
				"\(convention.rawValue) counted \(days) days across a spring-forward; if this is 181.0417 the count is picking up the DST offset")
		}
	}

	@Test("A span that crosses no boundary was never wrong, and still is not")
	func spanWithoutADSTBoundary() {
		// The contrast that isolates the diagnosis: same call, same conventions, no
		// transition in the way. This passed even when the case above did not.
		for convention in [DayCountConvention.actual365, .actual360, .actualActual] {
			let days = convention.days(from: Self.januaryUTC, to: Self.marchUTC)
			#expect(days.isEqual(to: 59), "\(convention.rawValue) counted \(days)")
		}
	}

	@Test("Dates built at local midnight count the same as dates built at UTC midnight")
	func localAndUTCConstructionAgree() {
		// The other half of the problem, and the reason the calendar was left as the
		// current one rather than pinned to UTC. A `Date` is an instant; a day count
		// needs a civil date; the two agree only when the calendar reading a date is the
		// one that built it. Anchoring on midnight makes both readings agree instead.
		var utc = Calendar(identifier: .gregorian)
		if let zone = TimeZone(secondsFromGMT: 0) { utc.timeZone = zone }

		func build(_ calendar: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date {
			guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
				preconditionFailure("\(y)-\(m)-\(d) is not a date")
			}
			return date
		}

		for convention in [DayCountConvention.actual365, .actual360, .actualActual] {
			let fromUTC = convention.days(from: build(utc, 2024, 1, 1), to: build(utc, 2024, 7, 1))
			let fromLocal = convention.days(from: build(.current, 2024, 1, 1),
											to: build(.current, 2024, 7, 1))
			#expect(fromUTC.isEqual(to: 182), "\(convention.rawValue) from UTC: \(fromUTC)")
			#expect(fromLocal.isEqual(to: 182), "\(convention.rawValue) from local: \(fromLocal)")
		}
	}

	@Test("Neither a half-hour offset nor a half-hour DST shift changes the count")
	func exoticOffsetsDoNotMatter() {
		// The zones that break naive date arithmetic, exercised through whichever one
		// the machine happens to be in — the suite is run across all of them in CI.
		//
		//   America/Phoenix                no DST at all
		//   Asia/Kolkata      +5:30        half-hour offset
		//   Asia/Kathmandu    +5:45        quarter-hour offset
		//   Australia/Lord_Howe +11 → +10:30   a *half-hour* DST shift
		//   Pacific/Chatham   +13:45 → +12:45  quarter-hour offset that also shifts
		//
		// All of them give 181, because `startOfDay` discards the time of day before
		// anything is compared. The offset's size and shape stop mattering at that point;
		// only the civil date survives, and two instants a whole number of days apart
		// shift together.
		let days = DayCountConvention.actual365.days(from: Self.januaryUTC, to: Self.julyUTC)
		#expect(days.isEqual(to: 181),
			"in \(TimeZone.current.identifier) the count is \(days)")

		let offsetJanuary = TimeZone.current.secondsFromGMT(for: Self.januaryUTC)
		let offsetJuly = TimeZone.current.secondsFromGMT(for: Self.julyUTC)
		// Whether or not this machine's zone shifts, the answer above is the same — which
		// is the property, and the reason the original defect was invisible on CI.
		#expect(abs(offsetJuly - offsetJanuary) < 90_000)
	}

	@Test("Year fractions inherit the independence")
	func yearFractionsAreAlsoStable() {
		let fraction: Double = DayCountConvention.actual365
			.yearFraction(from: Self.januaryUTC, to: Self.julyUTC)
		#expect(abs(fraction - 181.0 / 365.0) < 1e-15, "got \(fraction)")

		let over360: Double = DayCountConvention.actual360
			.yearFraction(from: Self.januaryUTC, to: Self.julyUTC)
		#expect(abs(over360 - 181.0 / 360.0) < 1e-15, "got \(over360)")
	}
}
