//
//  DayCountConvention.swift
//  BusinessMath
//
//  Turning a calendar interval into a year fraction.
//

import Foundation
import Numerics

/// A cached calendar.
///
/// Creating `Calendar` instances is expensive and every method here does calendar
/// arithmetic, so the instance is created once, following ``Period``'s own pattern.
private let cachedCalendar = Calendar.current

/// How an interval on the calendar is converted into a fraction of a year.
///
/// Every accrual in fixed income and credit — a coupon, a CDS premium leg, the
/// integral of a hazard curve — is a rate multiplied by a length of time. The rate
/// is quoted per annum, so the length has to be expressed in years, and there is no
/// single right way to do that: February is 28 days, a year is 365 or 366, and some
/// markets have simply agreed to pretend otherwise. A day count convention is that
/// agreement written down. It is a *market* fact, not a numerical detail, and the
/// same cash flows priced on two different conventions give different answers.
///
/// Each case is a fraction. The numerator is the number of days the convention
/// counts in the interval; the denominator is the number of days it calls a year.
///
/// | Convention | Numerator | Denominator | Where it is used |
/// | --- | --- | --- | --- |
/// | ``actual365`` | actual calendar days | 365 | Sterling and most Asian markets; the common default for hazard curves |
/// | ``actual360`` | actual calendar days | 360 | USD and EUR money markets, CDS premium legs |
/// | ``thirty360`` | every month treated as 30 days | 360 | US corporate and agency bonds |
///
/// ## Why the choice is material
///
/// Over a 365-day year, ``actual360`` accrues 365/360 — 1.389% — more than
/// ``actual365``. On a 500 bp credit that is roughly 7 bp a year, compounding across
/// the term of a curve. It is far larger than any rounding error, and it is the
/// difference between two answers that both look perfectly plausible.
///
/// ``thirty360`` is the odd one out: because it treats every month as 30 days, every
/// calendar year is exactly 360/360 = 1, so it is the only one of the three under
/// which a leap year and a common year have the same length.
///
/// ## Example
///
/// ```swift
/// let january = Period.month(year: 2025, month: 1)   // 31 actual days
///
/// let act365: Double = DayCountConvention.actual365.yearFraction(of: january)  // 31/365 = 0.084932
/// let act360: Double = DayCountConvention.actual360.yearFraction(of: january)  // 31/360 = 0.086111
/// let bond30: Double = DayCountConvention.thirty360.yearFraction(of: january)  // 30/360 = 0.083333
/// ```
///
/// ## Topics
///
/// ### Conventions
/// - ``actual365``
/// - ``actual360``
/// - ``thirty360``
///
/// ### Measuring
/// - ``daysInYear``
/// - ``days(in:)``
/// - ``days(from:to:)``
/// - ``yearFraction(of:)``
/// - ``yearFraction(from:to:)``
public enum DayCountConvention: String, Codable, Hashable, CaseIterable, Sendable {

	/// Actual days elapsed, divided by 365.
	///
	/// The numerator is the real number of calendar days, so a common year is
	/// 365/365 = 1 exactly and a leap year is 366/365 ≈ 1.00274. Sterling, Australian
	/// and most Asian money markets quote on this basis, and it is the usual default
	/// for a hazard or survival curve because it keeps a calendar year worth one year.
	///
	/// Also written ACT/365F, the F standing for *fixed*: the denominator stays 365
	/// even in a leap year, which is what distinguishes it from ACT/ACT.
	case actual365 = "ACT/365"

	/// Actual days elapsed, divided by 360.
	///
	/// Same numerator as ``actual365``, smaller denominator, so every interval is
	/// 365/360 = 1.389% longer in year terms. This is the money-market basis in USD
	/// and EUR, and the basis on which a standard CDS premium leg accrues — which is
	/// why a hazard curve bootstrapped from CDS quotes is often integrated on it too.
	case actual360 = "ACT/360"

	/// Every month treated as 30 days, divided by 360.
	///
	/// The numerator ignores the calendar: `360 × Δyears + 30 × Δmonths + Δdays`,
	/// with the US (NASD) end-of-month rule that a 31st is treated as a 30th, and a
	/// second 31st only when the first date has already been pulled back to a 30th.
	/// Every month is worth exactly 1/12 of a year and every year exactly 1, which is
	/// what makes a bond schedule's coupons all equal. Standard for US corporate,
	/// municipal and agency bonds.
	///
	/// Because the numerator is derived from the two dates' month and day numbers, a
	/// stub that starts or ends mid-month is *not* the same as its actual length: a
	/// 1 August to 31 December stub counts 150 days here against 152 actual.
	case thirty360 = "30/360"

	/// Actual days elapsed, each calendar year divided by its own length — ISDA ACT/ACT.
	///
	/// The only convention in this enum with no fixed divisor. An interval is split at
	/// every 1 January and each piece is divided by the length of the year it falls in,
	/// 365 or 366, then the pieces are added:
	///
	/// ```
	/// 2023-07-01 → 2024-07-01  =  184/365  +  182/366  ≈  1.001377
	/// ```
	///
	/// That is what makes a calendar year worth **exactly** one, leap or not — ``actual365``
	/// gives 366/365 across a leap year and ``actual360`` gives 366/360. For an
	/// instrument whose coupon is defined per calendar year rather than per fixed
	/// day-count, this is the convention that does not drift.
	///
	/// The ISDA definition is the one used here and the one most government bond markets
	/// quote. Note that **Excel's `YEARFRAC` basis 1 is not this**: Excel applies its own
	/// rule for the denominator, which for a period inside a single year depends on
	/// whether that period contains a 29 February, and for longer periods averages the
	/// years it spans. A binding to Excel should not assume the two agree.
	///
	/// - Note: ``daysInYear`` cannot answer for this case; see ``hasFixedYearLength``.
	case actualActual = "ACT/ACT"

	/// Every month treated as 30 days, divided by 360, with the European end-of-month rule.
	///
	/// Identical to ``thirty360`` except in one place, and the difference is worth stating
	/// exactly because it is easy to describe wrongly. Both pull a start date on the 31st
	/// back to the 30th. They differ on the *end* date:
	///
	/// | | End date on the 31st becomes the 30th |
	/// |---|---|
	/// | ``thirty360`` (US, NASD) | only when the start date was itself pulled back to a 30th |
	/// | ``thirty360European`` (30E/360) | always |
	///
	/// So they agree whenever neither end is a 31st, and whenever the start is. They part
	/// company when the end is a 31st and the start is not:
	///
	/// ```
	/// 2026-01-15 → 2026-03-31    US: 30·2 + (31 − 15) = 76
	///                            EU: 30·2 + (30 − 15) = 75
	/// ```
	///
	/// One day in seventy-six is a 1.3% error in an accrual, which is the kind of
	/// difference that prices something before anyone notices. Eurobonds and most
	/// continental European issues quote on 30E/360; US corporates and municipals on the
	/// US rule.
	case thirty360European = "30E/360"

	// MARK: - Denominator

	/// The number of days this convention calls a year — the divisor.
	///
	/// 365 for ``actual365``; 360 for ``actual360`` and ``thirty360``.
	public var daysInYear: Int {
		switch self {
		case .actual365: return 365
		case .actual360: return 360
		case .thirty360: return 360
		case .thirty360European: return 360
		case .actualActual: return 365
		}
	}

	/// Whether ``daysInYear`` is the whole story for this convention.
	///
	/// `false` only for ``actualActual``, which divides each calendar year's portion by
	/// that year's own length and therefore has no single divisor. The 365 it reports
	/// from ``daysInYear`` is a nominal figure and is **wrong for any interval touching a
	/// leap year** — check this property before using that one, or call
	/// ``yearFraction(from:to:)``, which is correct for every case.
	public var hasFixedYearLength: Bool {
		switch self {
		case .actual365, .actual360, .thirty360, .thirty360European: return true
		case .actualActual: return false
		}
	}

	// MARK: - Numerator

	/// The number of days this convention counts between two instants.
	///
	/// This is the numerator of the year fraction, exposed on its own because it is
	/// what a market convention is usually quoted in terms of, and because it makes
	/// the difference between conventions inspectable without a division.
	///
	/// - Parameters:
	///   - start: The start of the interval, inclusive.
	///   - end: The end of the interval, exclusive.
	/// - Returns: The counted days. Negative when `end` precedes `start`. Fractional
	///   only for an actual-day convention over an interval that does not land on a
	///   day boundary; ``thirty360`` is defined on dates and always returns a whole
	///   number.
	public func days(from start: Date, to end: Date) -> Double {
		let counted = countedDays(from: start, to: end)
		guard counted.seconds != 0 else { return Double(counted.days) }
		return Double(counted.days) + Double(counted.seconds) / 86_400.0 // fp-safety:disable — seconds per day, a positive literal
	}

	/// The number of days this convention counts in a period.
	///
	/// - Parameter period: The period to measure.
	/// - Returns: The counted days, from the period's start up to but not including
	///   the instant at which it ends.
	public func days(in period: Period) -> Double {
		return days(from: period.startDate, to: Self.exclusiveEnd(of: period))
	}

	// MARK: - Year Fraction

	/// The length of an interval as a fraction of a year under this convention.
	///
	/// - Parameters:
	///   - start: The start of the interval, inclusive.
	///   - end: The end of the interval, exclusive.
	/// - Returns: ``days(from:to:)`` divided by ``daysInYear``. Negative when `end`
	///   precedes `start`.
	public func yearFraction<T: Real>(from start: Date, to end: Date) -> T {
		// ACT/ACT has no single denominator, so it cannot go through the shared path
		// below: the divisor changes at every 1 January the interval crosses.
		if case .actualActual = self {
			return Self.actualActualYearFraction(from: start, to: end)
		}

		let counted = countedDays(from: start, to: end)
		// The divisor is 360 or 365 — a positive constant of the convention, so the
		// quotient is always defined.
		let denominator = T(daysInYear)
		let whole = T(counted.days) / denominator // fp-safety:disable — daysInYear is 360 or 365
		guard counted.seconds != 0 else { return whole }
		return whole + T(counted.seconds) / (denominator * T(86_400)) // fp-safety:disable — daysInYear is 360 or 365
	}

	/// The length of a period as a fraction of a year under this convention.
	///
	/// Defined for every period, including a ``PeriodType/custom`` transition stub,
	/// which reports the length of the range it was constructed with rather than any
	/// type-level average.
	///
	/// Note that this is deliberately *not* ``Period/durationInDays`` divided by
	/// ``daysInYear``. `durationInDays` answers with the granularity ladder's
	/// nominal average — 365.25 for any annual period, 30.4375 for any month —
	/// which is the right answer to "how long is a period of this type" and the
	/// wrong one for a convention whose numerator is defined to be *actual* days.
	/// Under the ladder no calendar year would ever be worth exactly one year.
	///
	/// - Parameter period: The period to measure.
	/// - Returns: The period's length in years under this convention.
	///
	/// ## Example
	///
	/// ```swift
	/// let common: Double = DayCountConvention.actual365.yearFraction(of: Period.year(2025))  // 365/365 = 1.0
	/// let leap: Double   = DayCountConvention.actual365.yearFraction(of: Period.year(2024))  // 366/365 ≈ 1.00274
	/// let bond: Double   = DayCountConvention.thirty360.yearFraction(of: Period.year(2024))  // 360/360 = 1.0
	/// ```
	public func yearFraction<T: Real>(of period: Period) -> T {
		return yearFraction(from: period.startDate, to: Self.exclusiveEnd(of: period))
	}

	// MARK: - Implementation

	/// The instant at which a period stops, exclusive.
	///
	/// ``Period/endDate`` is the *last* instant inside a ladder period — one tick
	/// short of the boundary — whereas a day count is measured to the boundary
	/// itself, so the next rung's start is what is wanted. A
	/// ``PeriodType/custom`` range already stores the end it was built with
	/// verbatim, and cannot be stepped, so it answers for itself.
	private static func exclusiveEnd(of period: Period) -> Date {
		guard period.type.isRegular else { return period.endDate }
		return period.next().startDate
	}

	/// The counted days, split into whole calendar days and a sub-day remainder.
	///
	/// Split rather than returned as one `Double` for two reasons. Whole days must
	/// come from calendar arithmetic and not from elapsed seconds: a daylight-saving
	/// transition makes a day 23 or 25 hours long, and dividing seconds by 86,400
	/// would report March 2025 as 30.958 days. And keeping the two parts as integers
	/// lets ``yearFraction(of:)`` build the ratio out of `T(Int)` values, so a
	/// calendar year under ``actual365`` is `T(365) / T(365)` — exactly 1, with no
	/// `Double`-to-`T` conversion in the path.
	private func countedDays(from start: Date, to end: Date) -> (days: Int, seconds: Int) {
		switch self {
		case .actual365, .actual360, .actualActual:
			let calendar = cachedCalendar
			let wholeDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
			guard let boundary = calendar.date(byAdding: .day, value: wholeDays, to: start) else {
				return (wholeDays, 0)
			}
			let leftover = end.timeIntervalSince(boundary).rounded()
			return (wholeDays, Int(exactly: leftover) ?? 0)

		case .thirty360:
			return (Self.thirty360Days(from: start, to: end, european: false), 0)
		case .thirty360European:
			return (Self.thirty360Days(from: start, to: end, european: true), 0)
		}
	}

	/// The 30/360 (US, NASD) day count between two dates.
	///
	/// `360 × Δyears + 30 × Δmonths + Δdays`, after pulling a 31st back to a 30th on
	/// the first date, and on the second date only when the first has already been
	/// pulled back. That second condition is the part that is easy to get wrong: it
	/// is what stops a 30 January to 31 March interval from losing a day.
	/// ISDA actual/actual: split the interval at every 1 January and divide each piece
	/// by the length of the year it falls in.
	///
	/// ```
	/// ─────┬──── 2023 ────┬──── 2024 ────┬─────
	///    start           Jan 1         Jan 1   end
	///      └── 184/365 ───┴──── 1.0 ────┴─ d/366
	/// ```
	///
	/// Whole intervening years contribute exactly one each, which is why a span of
	/// calendar years comes out as an exact integer rather than accumulating rounding.
	private static func actualActualYearFraction<T: Real>(from start: Date, to end: Date) -> T {
		// Antisymmetric by construction rather than by a separate backwards path, so the
		// two directions cannot drift apart.
		if end < start {
			let forward: T = actualActualYearFraction(from: end, to: start)
			return -forward
		}

		let calendar = cachedCalendar
		guard let startYear = calendar.dateComponents([.year], from: start).year,
			  let endYear = calendar.dateComponents([.year], from: end).year else {
			return T.zero
		}

		if startYear == endYear {
			let elapsed: T = actualDays(from: start, to: end)
			return elapsed / T(daysInYear(of: startYear))
		}

		guard let firstBoundary = calendar.date(from: DateComponents(year: startYear + 1, month: 1, day: 1)),
			  let lastBoundary = calendar.date(from: DateComponents(year: endYear, month: 1, day: 1)) else {
			return T.zero
		}

		let leadingDays: T = actualDays(from: start, to: firstBoundary)
		let leading: T = leadingDays / T(daysInYear(of: startYear))

		let wholeYears = T(endYear - startYear - 1)

		let trailingDays: T = actualDays(from: lastBoundary, to: end)
		let trailing: T = trailingDays / T(daysInYear(of: endYear))

		return leading + wholeYears + trailing
	}

	/// Actual elapsed days, carrying any sub-day remainder as a fraction.
	private static func actualDays<T: Real>(from start: Date, to end: Date) -> T {
		let calendar = cachedCalendar
		let wholeDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0
		guard let boundary = calendar.date(byAdding: .day, value: wholeDays, to: start) else {
			return T(wholeDays)
		}
		let leftover = end.timeIntervalSince(boundary).rounded()
		guard let seconds = Int(exactly: leftover), seconds != 0 else { return T(wholeDays) }
		return T(wholeDays) + T(seconds) / T(86_400) // fp-safety:disable — seconds per day, a positive literal
	}

	/// 366 in a leap year, 365 otherwise.
	///
	/// The Gregorian rule, derived rather than looked up: every fourth year, except
	/// centuries, except every fourth century. 2000 is a leap year and 2100 is not.
	private static func daysInYear(of year: Int) -> Int {
		let divisibleByFour = year % 4 == 0
		let divisibleByHundred = year % 100 == 0
		let divisibleByFourHundred = year % 400 == 0
		let isLeap = divisibleByFour && (!divisibleByHundred || divisibleByFourHundred)
		return isLeap ? 366 : 365
	}

	private static func thirty360Days(from start: Date, to end: Date, european: Bool) -> Int {
		let calendar = cachedCalendar
		let from = calendar.dateComponents([.year, .month, .day], from: start)
		let to = calendar.dateComponents([.year, .month, .day], from: end)

		guard let startYear = from.year, let startMonth = from.month, let startDay = from.day,
			  let endYear = to.year, let endMonth = to.month, let endDay = to.day else {
			return 0
		}

		// Both rules pull a start date on the 31st back to the 30th. They differ only on
		// the end date: the European rule does it unconditionally, the US rule only when
		// the start was itself pulled back.
		let adjustedStartDay = startDay == 31 ? 30 : startDay
		let endIsPulledBack = european ? (endDay == 31) : (endDay == 31 && adjustedStartDay == 30)
		let adjustedEndDay = endIsPulledBack ? 30 : endDay

		return 360 * (endYear - startYear)
			+ 30 * (endMonth - startMonth)
			+ (adjustedEndDay - adjustedStartDay)
	}
}
