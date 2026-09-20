//
//  PeriodNextOracleTests.swift
//  BusinessMath
//
//  An oracle for `Period.next()`, which steps ten period types and was directly tested on
//  one.
//
//  Searching the suite for `next()` finds three call sites. Two are semiannual — `H1 -> H2`
//  and `H2 -> H1` of the following year, which is the right pair for that rung — and one is
//  an equality inside a trend-model test that would pass for any self-consistent stepping.
//  `nextIfSteppable()` is checked for returning `nil` on a custom range. **Millisecond,
//  second, minute, hourly, daily, monthly, quarterly and annual have no direct assertion at
//  all**, and those are the rungs where the interesting boundaries live: December into
//  January, Q4 into Q1, the last millisecond of a day, and February in a leap year.
//
//  ## Where the expected values come from
//
//  Not from `Calendar`. `next()` is implemented with `Calendar.date(byAdding:value:to:)` and
//  then reads the result back through `dateComponents`, so an oracle built the same way would
//  share the arithmetic it is supposed to be checking and could only catch a wrong *unit* or
//  a wrong *count*.
//
//  This file converts civil dates to **Julian day numbers** with the standard integer
//  algorithm and back again, and does all stepping as integer addition on a millisecond
//  count. It touches no date API, so it is wrong in different ways than `Calendar` is — which
//  is the only property that makes it an oracle. `Period` uses a proleptic Gregorian calendar
//  in UTC, which is exactly what the JDN conversion implements, so agreement should be exact.
//
//  ## The boundaries the ladders are chosen for
//
//  - **2024-02-27**: a leap year by the ordinary rule.
//  - **2023-02-26**: the same dates in a non-leap year.
//  - **2000-02-27**: a century that *is* a leap year, by the 400 rule.
//  - **2100-02-26**: a century that is *not*, by the 100 rule — the case a naive
//    `year % 4 == 0` gets wrong, and the one no fixture in this package reached before.
//  - **1999-12-30** and **2023-12-30**: year rollover.
//  - **23:59:59.999**: every sub-daily rung carrying into the next day at once.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Period.next against integer calendar arithmetic")
struct PeriodNextOracleTests {

	// MARK: - A calendar built from integers

	/// A civil timestamp, with no date type behind it.
	private struct Stamp: Equatable, Sendable, CustomStringConvertible {
		var year: Int, month: Int, day: Int
		var hour: Int, minute: Int, second: Int, millisecond: Int

		var description: String {
			// Not `String(format:)`: that bridges to the C printf ABI, which the safety
			// checker forbids for the reason that a `%s` against a Swift String is a
			// runtime SIGSEGV rather than a compile error.
			let date = "\(padded(year, 4))-\(padded(month, 2))-\(padded(day, 2))"
			let clock = "\(padded(hour, 2)):\(padded(minute, 2)):\(padded(second, 2))"
			return "\(date) \(clock).\(padded(millisecond, 3))"
		}

		/// Left-pads with zeros, which is all `%0Nd` was being used for.
		private func padded(_ value: Int, _ width: Int) -> String {
			let digits = String(value)
			guard digits.count < width else { return digits }
			return String(repeating: "0", count: width - digits.count) + digits
		}
	}

	/// Julian day number for a proleptic Gregorian civil date.
	private static func julianDay(year: Int, month: Int, day: Int) -> Int {
		let a = (14 - month) / 12
		let y = year + 4800 - a
		let m = month + 12 * a - 3
		let leapPart = y / 4 - y / 100 + y / 400
		let monthPart = (153 * m + 2) / 5
		return day + monthPart + 365 * y + leapPart - 32045
	}

	/// The inverse: a proleptic Gregorian civil date from a Julian day number.
	private static func civilDate(fromJulianDay jdn: Int) -> (year: Int, month: Int, day: Int) {
		let a = jdn + 32044
		let b = (4 * a + 3) / 146097
		let c = a - 146097 * b / 4
		let d = (4 * c + 3) / 1461
		let e = c - 1461 * d / 4
		let m = (5 * e + 2) / 153
		let day = e - (153 * m + 2) / 5 + 1
		let month = m + 3 - 12 * (m / 10)
		let year = 100 * b + d - 4800 + m / 10
		return (year, month, day)
	}

	private static let millisPerDay = 86_400_000

	private static func milliseconds(from stamp: Stamp) -> Int {
		let days = julianDay(year: stamp.year, month: stamp.month, day: stamp.day)
		let hourPart = stamp.hour * 3_600_000
		let minutePart = stamp.minute * 60_000
		let secondPart = stamp.second * 1_000
		let timeOfDay = hourPart + minutePart + secondPart + stamp.millisecond
		return days * millisPerDay + timeOfDay
	}

	private static func stamp(fromMilliseconds total: Int) -> Stamp {
		// Floor division, so a negative total still lands on the right day.
		var days = total / millisPerDay
		var rest = total % millisPerDay
		if rest < 0 { rest += millisPerDay; days -= 1 }
		let civil = civilDate(fromJulianDay: days)
		let hour = rest / 3_600_000
		let minute = (rest % 3_600_000) / 60_000
		let second = (rest % 60_000) / 1_000
		let milli = rest % 1_000
		return Stamp(year: civil.year, month: civil.month, day: civil.day,
					 hour: hour, minute: minute, second: second, millisecond: milli)
	}

	// MARK: - Reading a Period back as a stamp

	/// The UTC calendar is hand-built here on purpose: a test that checks the stepping must
	/// not read its expectation through the same constant the source steps with.
	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		guard let zone = TimeZone(secondsFromGMT: 0) else { return c }
		c.timeZone = zone
		return c
	}()

	private static func stamp(of period: Period) -> Stamp {
		let parts = utc.dateComponents(
			[.year, .month, .day, .hour, .minute, .second, .nanosecond], from: period.startDate)
		return Stamp(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0,
					 hour: parts.hour ?? 0, minute: parts.minute ?? 0,
					 second: parts.second ?? 0,
					 millisecond: Int((Double(parts.nanosecond ?? 0) / 1_000_000).rounded()))
	}

	// MARK: - Sub-daily and daily rungs

	private struct Ladder: Sendable {
		let name: String
		let start: Stamp
		let stepMillis: Int
		let steps: Int
		let make: @Sendable (Stamp) -> Period
	}

	private static let ladders: [Ladder] = [
		Ladder(name: "millisecond across midnight",
			   start: Stamp(year: 2023, month: 12, day: 31,
							hour: 23, minute: 59, second: 59, millisecond: 997),
			   stepMillis: 1, steps: 6,
			   make: { Period.millisecond(year: $0.year, month: $0.month, day: $0.day,
										  hour: $0.hour, minute: $0.minute,
										  second: $0.second, millisecond: $0.millisecond) }),
		Ladder(name: "second across midnight",
			   start: Stamp(year: 2024, month: 2, day: 28,
							hour: 23, minute: 59, second: 57, millisecond: 0),
			   stepMillis: 1_000, steps: 6,
			   make: { Period.second(year: $0.year, month: $0.month, day: $0.day,
									 hour: $0.hour, minute: $0.minute, second: $0.second) }),
		Ladder(name: "minute across an hour",
			   start: Stamp(year: 2100, month: 2, day: 28,
							hour: 23, minute: 57, second: 0, millisecond: 0),
			   stepMillis: 60_000, steps: 6,
			   make: { Period.minute(year: $0.year, month: $0.month, day: $0.day,
									 hour: $0.hour, minute: $0.minute) }),
		Ladder(name: "hour across a day",
			   start: Stamp(year: 1999, month: 12, day: 31,
							hour: 21, minute: 0, second: 0, millisecond: 0),
			   stepMillis: 3_600_000, steps: 6,
			   make: { Period.hour(year: $0.year, month: $0.month, day: $0.day, hour: $0.hour) }),
		Ladder(name: "day across a leap February",
			   start: Stamp(year: 2024, month: 2, day: 27,
							hour: 0, minute: 0, second: 0, millisecond: 0),
			   stepMillis: millisPerDay, steps: 5,
			   make: { dayPeriod(from: $0) }),
		Ladder(name: "day across a non-leap February",
			   start: Stamp(year: 2023, month: 2, day: 26,
							hour: 0, minute: 0, second: 0, millisecond: 0),
			   stepMillis: millisPerDay, steps: 5,
			   make: { dayPeriod(from: $0) }),
		Ladder(name: "day across the 400-year leap century",
			   start: Stamp(year: 2000, month: 2, day: 27,
							hour: 0, minute: 0, second: 0, millisecond: 0),
			   stepMillis: millisPerDay, steps: 5,
			   make: { dayPeriod(from: $0) }),
		Ladder(name: "day across the 100-year non-leap century",
			   start: Stamp(year: 2100, month: 2, day: 26,
							hour: 0, minute: 0, second: 0, millisecond: 0),
			   stepMillis: millisPerDay, steps: 5,
			   make: { dayPeriod(from: $0) }),
		Ladder(name: "day across a year end",
			   start: Stamp(year: 1999, month: 12, day: 30,
							hour: 0, minute: 0, second: 0, millisecond: 0),
			   stepMillis: millisPerDay, steps: 4,
			   make: { dayPeriod(from: $0) })
	]

	private static func dayPeriod(from stamp: Stamp) -> Period {
		var parts = DateComponents()
		parts.year = stamp.year
		parts.month = stamp.month
		parts.day = stamp.day
		guard let date = utc.date(from: parts) else {
			return Period.day(Date(timeIntervalSince1970: 0))
		}
		return Period.day(date)
	}

	@Test("Sub-daily and daily steps match integer calendar arithmetic")
	func fixedWidthRungsStepCorrectly() throws {
		var compared = 0
		for ladder in Self.ladders {
			var period = ladder.make(ladder.start)
			var expected = Self.milliseconds(from: ladder.start)

			// The starting period must already be where the ladder says it is, or the walk
			// below would be checking `next()` against a different question.
			#expect(Self.stamp(of: period) == ladder.start,
					"\(ladder.name): starts at \(Self.stamp(of: period)), not \(ladder.start)")

			for step in 1...ladder.steps {
				period = period.next()
				expected += ladder.stepMillis
				let want = Self.stamp(fromMilliseconds: expected)
				let got = Self.stamp(of: period)
				#expect(got == want, "\(ladder.name) step \(step): \(got), expected \(want)")
				compared += 1
			}
		}
		#expect(compared >= 40, "only \(compared) steps compared")
	}

	// MARK: - Month-based rungs

	@Test("Monthly steps roll the year at December")
	func monthlyStepsRollTheYear() throws {
		var period = Period.month(year: 2023, month: 10)
		var index = 2023 * 12 + (10 - 1)
		for step in 1...8 {
			period = period.next()
			index += 1
			let wantYear = index / 12
			let wantMonth = index % 12 + 1
			#expect(period.year == wantYear && period.month == wantMonth,
					"step \(step): \(period.year)-\(period.month), expected \(wantYear)-\(wantMonth)")
		}
	}

	@Test("Quarterly steps roll the year at Q4")
	func quarterlyStepsRollTheYear() throws {
		// The rung with no direct assertion anywhere in the suite, and the one where the
		// implementation recomputes the quarter from the resulting month rather than
		// incrementing an index — so Q4 -> Q1 is where a wrong month-to-quarter map shows.
		var period = Period.quarter(year: 2023, quarter: 3)
		var index = 2023 * 4 + (3 - 1)
		for step in 1...7 {
			period = period.next()
			index += 1
			let wantYear = index / 4
			let wantQuarter = index % 4 + 1
			#expect(period.year == wantYear && period.quarter == wantQuarter,
					"step \(step): \(period.year) Q\(period.quarter), expected \(wantYear) Q\(wantQuarter)")
		}
	}

	@Test("Semiannual steps roll the year at H2")
	func semiannualStepsRollTheYear() throws {
		var period = Period.semiannual(year: 2023, half: 1)
		var index = 2023 * 2 + (1 - 1)
		for step in 1...5 {
			period = period.next()
			index += 1
			let wantYear = index / 2
			let wantHalf = index % 2 + 1
			#expect(period.year == wantYear && period.half == wantHalf,
					"step \(step): \(period.year) H\(period.half), expected \(wantYear) H\(wantHalf)")
		}
	}

	@Test("Annual steps advance the year")
	func annualStepsAdvanceTheYear() throws {
		var period = Period.year(1999)
		for step in 1...5 {
			period = period.next()
			#expect(period.year == 1999 + step,
					"step \(step): \(period.year), expected \(1999 + step)")
		}
	}

	// MARK: - Guards on the oracle itself

	@Test("The integer calendar agrees with itself and knows its leap years")
	func integerCalendarIsSound() throws {
		// A round trip over a long span, so a wrong constant in either direction shows.
		let first = Self.julianDay(year: 1900, month: 1, day: 1)
		let last = Self.julianDay(year: 2200, month: 1, day: 1)
		for jdn in stride(from: first, through: last, by: 7) {
			let civil = Self.civilDate(fromJulianDay: jdn)
			let back = Self.julianDay(year: civil.year, month: civil.month, day: civil.day)
			#expect(back == jdn, "round trip failed at \(jdn): \(civil)")
		}

		// The three leap rules, each by counting the days in February.
		let cases: [(year: Int, days: Int)] = [
			(2023, 28),  // ordinary
			(2024, 29),  // divisible by 4
			(1900, 28),  // divisible by 100
			(2000, 29),  // divisible by 400
			(2100, 28)   // divisible by 100
		]
		for entry in cases {
			let march = Self.julianDay(year: entry.year, month: 3, day: 1)
			let february = Self.julianDay(year: entry.year, month: 2, day: 1)
			#expect(march - february == entry.days,
					"February \(entry.year) has \(march - february) days, expected \(entry.days)")
		}
	}

	/// The assertions above can actually fail.
	///
	/// Four mutations of `next()` were tried against this file and all four passed, which
	/// looked like a hole in the oracle and was not: every one of them was behaviourally
	/// equivalent. A quarterly `Period` re-anchors to a quarter-start month on every step, so
	/// the month-to-quarter map is only ever evaluated at 1, 4, 7 and 10 — exactly where
	/// `((m - 1) / 3) + 1` and the off-by-one `(m / 3) + 1` agree. Stepping four months
	/// instead of three lands on 5, 8, 11 and 2, whose quarters are the same sequence as 4,
	/// 7, 10 and 1. The semiannual map is unfalsifiable for the same reason, and a
	/// millisecond step of 1,000,001 nanoseconds is below the resolution of the type.
	///
	/// Those expressions therefore carry neither risk nor the possibility of proof, which is
	/// worth knowing but is not evidence about this file. This test supplies that evidence
	/// directly: it shows the comparison separates a correct step from a doubled one, which
	/// is the class of error a real mutation would introduce.
	@Test("A mis-step would not pass: the comparison discriminates")
	func theComparisonDiscriminates() throws {
		for ladder in Self.ladders {
			let stepped = ladder.make(ladder.start).next()
			let base = Self.milliseconds(from: ladder.start)
			let correct = Self.stamp(fromMilliseconds: base + ladder.stepMillis)
			let doubled = Self.stamp(fromMilliseconds: base + 2 * ladder.stepMillis)
			let got = Self.stamp(of: stepped)
			#expect(got == correct, "\(ladder.name): \(got), expected \(correct)")
			#expect(got != doubled,
					"\(ladder.name): a doubled step would also satisfy this comparison")
		}

		// The month-based rungs, where the step is an index rather than a duration.
		let month = Period.month(year: 2023, month: 12).next()
		#expect(month.year == 2024 && month.month == 1, "\(month.year)-\(month.month)")
		#expect(!(month.year == 2024 && month.month == 2), "a doubled month step would pass")

		let quarter = Period.quarter(year: 2023, quarter: 4).next()
		#expect(quarter.year == 2024 && quarter.quarter == 1)
		#expect(!(quarter.year == 2024 && quarter.quarter == 2), "a doubled quarter step would pass")

		let year = Period.year(2023).next()
		#expect(year.year == 2024)
		#expect(year.year != 2025, "a doubled year step would pass")
	}

	@Test("The ladders reach the boundaries they are named for")
	func laddersCrossTheirBoundaries() throws {
		// A ladder that never leaves the month it starts in would assert nothing about
		// rollover, and would still pass.
		for ladder in Self.ladders {
			let start = ladder.start
			let endMillis = Self.milliseconds(from: start) + ladder.stepMillis * ladder.steps
			let end = Self.stamp(fromMilliseconds: endMillis)
			let movedDay = end.day != start.day
			let movedMonth = end.month != start.month
			let movedYear = end.year != start.year
			#expect(movedDay || movedMonth || movedYear,
					"\(ladder.name) never leaves \(start.year)-\(start.month)-\(start.day)")
		}
	}
}
