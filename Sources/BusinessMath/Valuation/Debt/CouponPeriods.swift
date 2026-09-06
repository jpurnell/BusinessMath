//
//  CouponPeriods.swift
//  BusinessMath
//
//  The coupon grid Excel's bond functions are defined on.
//

import Foundation
import Numerics

/// Where a settlement date sits within a bond's coupon schedule.
///
/// Excel defines `PRICE`, `YIELD`, `DURATION`, `MDURATION` and `ACCRINT` in terms of
/// four quantities, and they are all read off this:
///
/// ```
///   previous coupon        settlement              next coupon
///        │                      │                       │
///        ├──────── A ───────────┼────────── DSC ────────┤
///        ├──────────────── E ───────────────────────────┤
/// ```
///
/// - `A`  — days from the previous coupon to settlement, Excel's `COUPDAYBS`
/// - `DSC` — days from settlement to the next coupon, `COUPDAYSNC`
/// - `E`  — days in the coupon period containing settlement, `COUPDAYS`
/// - `N`  — coupons remaining after settlement, `COUPNUM`
///
/// ## The grid runs backwards from maturity
///
/// Coupon dates are counted back from maturity, not forward from settlement, because a
/// bond's last coupon falls on its redemption date and every earlier one is a whole
/// number of periods before it. Counting forward from settlement would put the grid on
/// the wrong phase whenever settlement is not itself a coupon date, which is the case
/// the accrual fraction exists for.
///
/// ## `E` is nominal on a 30/360 or actual/360 basis
///
/// Under a fixed year length a semi-annual period is 180 days on a 30/360 basis and 180
/// on actual/360 — even when the calendar says 182 or 184. Only the actual/actual
/// conventions measure the period as long as it really is, which is why they are the
/// only ones that make a bond's price depend on the coupon frequency in a way a single
/// year fraction cannot express.
public struct CouponPeriod<T: Real & BinaryFloatingPoint>: Sendable where T: Sendable {

	/// The coupon date at or before settlement — Excel's `COUPPCD`.
	public let previousCouponDate: Date

	/// The first coupon date after settlement — Excel's `COUPNCD`.
	public let nextCouponDate: Date

	/// Days from the previous coupon to settlement — `COUPDAYBS`, the `A` above.
	public let daysAccrued: T

	/// Days from settlement to the next coupon — `COUPDAYSNC`, the `DSC` above.
	public let daysToNextCoupon: T

	/// Days in the coupon period containing settlement — `COUPDAYS`, the `E` above.
	public let daysInPeriod: T

	/// Coupons payable between settlement and maturity — `COUPNUM`, the `N` above.
	public let couponsRemaining: Int

	/// The settled fraction of the current period, `A/E`.
	///
	/// What a buyer owes the seller, as a proportion of one coupon.
	public var accruedFraction: T {
		guard daysInPeriod > T.zero else { return T.zero }
		return daysAccrued / daysInPeriod
	}

	/// The unexpired fraction of the current period, `DSC/E`.
	///
	/// The exponent every cash flow is discounted by beyond its whole periods.
	public var remainingFraction: T {
		guard daysInPeriod > T.zero else { return T.zero }
		return daysToNextCoupon / daysInPeriod
	}

	/// Locates `settlement` within the coupon schedule of a bond maturing on `maturity`.
	///
	/// - Parameters:
	///   - settlement: When the trade settles. Must precede `maturity`.
	///   - maturity: When the bond redeems.
	///   - frequency: Coupons a year. Excel allows annual, semi-annual and quarterly.
	///   - basis: The day count. Defaults to ``DayCountConvention/thirty360``, Excel's
	///     basis 0.
	/// - Throws: `BusinessMathError.invalidInput` if `settlement` is not before
	///   `maturity`, or the frequency does not divide the year into whole months.
	public init(
		settlement: Date,
		maturity: Date,
		frequency: PaymentFrequency = .semiAnnual,
		basis: DayCountConvention = .thirty360
	) throws {
		guard settlement < maturity else {
			throw BusinessMathError.invalidInput(
				message: "Settlement must fall before maturity",
				value: "\(settlement)", expectedRange: "before \(maturity)")
		}
		let periodsPerYear = frequency.periodsPerYear
		guard periodsPerYear > 0, 12 % periodsPerYear == 0 else {
			throw BusinessMathError.invalidInput(
				message: "Coupon frequency must divide the year into whole months",
				value: "\(periodsPerYear) per year", expectedRange: "1, 2, 3, 4, 6 or 12")
		}

		let step = 12 / periodsPerYear
		let calendar = Calendar.current

		// Walk back from maturity until the date at or before settlement is found. The
		// bound is a backstop against a non-terminating walk, not a limit on realistic
		// instruments: a century of monthly coupons is 1,200.
		var next = maturity
		var previous = maturity
		var remaining = 0
		var steps = 0
		while previous > settlement, steps < 1_200 {
			next = previous
			guard let earlier = calendar.date(byAdding: .month, value: -step, to: previous) else {
				break
			}
			previous = earlier
			remaining += 1
			steps += 1
		}

		self.previousCouponDate = previous
		self.nextCouponDate = next
		self.couponsRemaining = remaining

		self.daysAccrued = T(basis.days(from: previous, to: settlement))
		self.daysToNextCoupon = T(basis.days(from: settlement, to: next))

		// A period's *normal* length, which is not its calendar length unless the basis
		// measures actual days over an actual year. See the note on the type.
		switch basis {
		case .actualActual, .isdaActualActual:
			self.daysInPeriod = T(basis.days(from: previous, to: next))
		case .actual365:
			self.daysInPeriod = T(365) / T(periodsPerYear)
		case .actual360, .thirty360, .thirty360European:
			self.daysInPeriod = T(360) / T(periodsPerYear)
		}
	}
}
