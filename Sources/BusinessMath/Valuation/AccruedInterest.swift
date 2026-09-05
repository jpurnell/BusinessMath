//
//  AccruedInterest.swift
//  BusinessMath
//
//  Interest accrued on a bond between its issue and a settlement date.
//

import Foundation
import Numerics

/// Interest accrued from issue to settlement — Excel's `ACCRINT`.
///
/// When a bond changes hands between coupon dates the buyer owes the seller the
/// interest earned so far. This is that amount.
///
/// ```
/// par · (rate / frequency) · Σᵢ Aᵢ / NLᵢ
/// ```
///
/// The sum runs over the **quasi-coupon periods** between issue and settlement: the
/// grid of dates counted backwards from the first interest payment at `frequency` a
/// year, whether or not a coupon is actually paid on each. `Aᵢ` is the accrued days
/// inside period *i* and `NLᵢ` is that period's normal length. A period wholly inside
/// the span contributes a whole coupon; the partial one at each end contributes its
/// fraction.
///
/// ## Why the sum, rather than a single year fraction
///
/// For four of the five day counts the two are the same number, because `NLᵢ` is a
/// fixed `360/frequency` or `365/frequency` and the frequency cancels. Under
/// ``DayCountConvention/actualActual`` it does not: each quasi-coupon period has its own
/// actual length, so the answer genuinely depends on the frequency, and a single year
/// fraction cannot express it.
///
/// ## The reference, and the one that turned out not to be
///
/// Verified against Excel. That is worth stating precisely, because the LibreOffice
/// workbook used as the oracle for the rest of this package's financial functions is
/// **wrong for this one**: for issue 2023-11-30, settlement 2024-03-31 at semi-annual
/// frequency it returns 210.069444, implying a 30/360 day count of 121, while the same
/// spreadsheet's own `DAYS360`, `YEARFRAC` and `COUPDAYBS` all say 120. Excel returns
/// 208.333333, which is what this computes and exactly 120/180 of a coupon.
///
/// - Parameters:
///   - issue: When the bond was issued and interest began accruing.
///   - firstInterest: The first interest payment date. Sets the phase of the
///     quasi-coupon grid; it need not fall before `settlement`.
///   - settlement: When the trade settles and accrual stops.
///   - rate: The annual coupon rate.
///   - par: The face value. Defaults to 1,000, as Excel does.
///   - frequency: How many coupons a year. Excel allows annual, semi-annual and
///     quarterly.
///   - basis: The day count. Defaults to ``DayCountConvention/thirty360``, Excel's
///     basis 0.
/// - Returns: The interest accrued between `issue` and `settlement`.
/// - Throws: `BusinessMathError.invalidInput` if `settlement` is not after `issue`,
///   `rate` is negative, or `par` is not positive.
public func accruedInterest<T: Real & BinaryFloatingPoint>(
	issue: Date,
	firstInterest: Date,
	settlement: Date,
	rate: T,
	par: T = T(1000),
	frequency: PaymentFrequency = .semiAnnual,
	basis: DayCountConvention = .thirty360
) throws -> T {
	guard settlement > issue else {
		throw BusinessMathError.invalidInput(
			message: "Settlement must fall after issue for interest to have accrued",
			value: "\(settlement)", expectedRange: "after \(issue)")
	}
	guard rate >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Coupon rate cannot be negative",
			value: "\(rate)", expectedRange: "[0, ∞)")
	}
	guard par > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Par value must be positive",
			value: "\(par)", expectedRange: "(0, ∞)")
	}

	let periodsPerYear = frequency.periodsPerYear
	let grid = try quasiCouponDates(firstInterest: firstInterest, issue: issue,
									settlement: settlement, periodsPerYear: periodsPerYear)

	var accrued: T = T.zero
	for index in 0..<(grid.count - 1) {
		let periodStart = grid[index]
		let periodEnd = grid[index + 1]
		let from = Swift.max(periodStart, issue)
		let to = Swift.min(periodEnd, settlement)
		guard to > from else { continue }

		let days: T = T(basis.days(from: from, to: to))
		let normalLength: T = normalPeriodLength(basis: basis,
												 periodsPerYear: periodsPerYear,
												 periodStart: periodStart,
												 periodEnd: periodEnd)
		guard normalLength > T.zero else { continue }
		accrued += days / normalLength
	}

	let couponRate: T = rate / T(periodsPerYear)
	return par * couponRate * accrued
}

/// The quasi-coupon grid spanning issue to settlement, in order.
///
/// Counted backwards from `firstInterest` so that the grid keeps the bond's actual
/// coupon phase, then forwards if settlement runs past it — which happens when a trade
/// settles after the first payment.
private func quasiCouponDates(
	firstInterest: Date, issue: Date, settlement: Date, periodsPerYear: Int
) throws -> [Date] {
	guard periodsPerYear > 0, 12 % periodsPerYear == 0 else {
		throw BusinessMathError.invalidInput(
			message: "Coupon frequency must divide the year into whole months",
			value: "\(periodsPerYear) per year", expectedRange: "1, 2, 3, 4, 6 or 12")
	}
	let step = 12 / periodsPerYear
	let calendar = Calendar.current

	var dates: [Date] = [firstInterest]

	var earlier = firstInterest
	var steps = 0
	while earlier > issue, steps < Self_.maximumPeriods {
		guard let previous = calendar.date(byAdding: .month, value: -step, to: earlier) else { break }
		dates.append(previous)
		earlier = previous
		steps += 1
	}

	var later = firstInterest
	steps = 0
	while later < settlement, steps < Self_.maximumPeriods {
		guard let next = calendar.date(byAdding: .month, value: step, to: later) else { break }
		dates.append(next)
		later = next
		steps += 1
	}

	return dates.sorted()
}

/// The normal length of one quasi-coupon period, in the units the basis counts.
///
/// Fixed for every convention with a fixed year length — a semi-annual period is 180
/// days on any 30/360 or actual/360 basis, whatever the calendar says. The
/// actual/actual conventions are the exception, and the reason the sum in
/// ``accruedInterest(issue:firstInterest:settlement:rate:par:frequency:basis:)`` cannot
/// be collapsed into one year fraction: there, a period is as long as it actually is.
private func normalPeriodLength<T: Real & BinaryFloatingPoint>(
	basis: DayCountConvention, periodsPerYear: Int, periodStart: Date, periodEnd: Date
) -> T {
	switch basis {
	case .actualActual, .isdaActualActual:
		return T(basis.days(from: periodStart, to: periodEnd))
	case .actual365:
		return T(365) / T(periodsPerYear)
	case .actual360, .thirty360, .thirty360European:
		return T(360) / T(periodsPerYear)
	}
}

/// Bounds on the quasi-coupon walk.
private enum Self_ {
	/// The most periods the grid may extend in either direction.
	///
	/// A backstop against a non-terminating walk, not a limit on realistic instruments:
	/// twelve hundred monthly periods is a century, and no accrual spans one.
	static let maximumPeriods = 1_200
}
