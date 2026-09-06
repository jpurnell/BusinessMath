//
//  ExcelBondFunctions.swift
//  BusinessMath
//
//  PRICE, YIELD, DURATION and MDURATION as Microsoft defines them.
//

import Foundation
import Numerics

// MARK: - Price

/// The price of a bond per 100 of face value — Excel's `PRICE`.
///
/// Microsoft's definition, term for term:
///
/// ```
///                redemption                 N        100·rate/frq
/// PRICE = ─────────────────────────  +  Σ  ──────────────────────────  −  100·(rate/frq)·(A/E)
///          (1 + yld/frq)^(N−1+DSC/E)     k=1  (1 + yld/frq)^(k−1+DSC/E)
/// ```
///
/// Three parts: the redemption discounted over the whole remaining life, the coupons
/// discounted one by one, and the accrued interest subtracted — because the quoted
/// price is *clean* and the buyer pays the accrual separately.
///
/// `A`, `DSC`, `E` and `N` come from ``CouponPeriod``, which is where the day count
/// actually enters. On any basis with a fixed year length the accrual fraction is the
/// same whatever the frequency; under actual/actual it is not, which is why this cannot
/// be collapsed into a single discount factor.
///
/// ## Why this is not `Bond.price(yield:)`
///
/// That method discounts a cash-flow schedule it builds itself. This is the
/// spreadsheet's formula, on the spreadsheet's coupon grid, and the two differ whenever
/// settlement falls between coupon dates. Both are correct for what they model; only
/// one of them answers `=PRICE(...)`.
///
/// - Parameters:
///   - settlement: When the trade settles.
///   - maturity: When the bond redeems.
///   - rate: The annual coupon rate.
///   - yield: The annual yield to maturity.
///   - redemption: Redemption value per 100 of face. Usually 100.
///   - frequency: Coupons a year.
///   - basis: The day count. Defaults to Excel's basis 0.
/// - Returns: The clean price per 100 of face value.
/// - Throws: `BusinessMathError.invalidInput` for a settlement at or after maturity, a
///   negative rate or yield, or a non-positive redemption.
public func bondPrice<T: Real & BinaryFloatingPoint & Sendable>(
	settlement: Date,
	maturity: Date,
	rate: T,
	yield: T,
	redemption: T = T(100),
	frequency: PaymentFrequency = .semiAnnual,
	basis: DayCountConvention = .thirty360
) throws -> T {
	guard rate >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Coupon rate cannot be negative", value: "\(rate)", expectedRange: "[0, ∞)")
	}
	guard yield >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Yield cannot be negative", value: "\(yield)", expectedRange: "[0, ∞)")
	}
	guard redemption > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Redemption value must be positive", value: "\(redemption)",
			expectedRange: "(0, ∞)")
	}

	let period = try CouponPeriod<T>(settlement: settlement, maturity: maturity,
									 frequency: frequency, basis: basis)
	let perYear = T(frequency.periodsPerYear)
	let periodicYield: T = yield / perYear
	let coupon: T = T(100) * rate / perYear
	let unexpired: T = period.remainingFraction
	let growth: T = T(1) + periodicYield

	// N is the number of coupons still payable; a settlement on a coupon date has
	// already been passed over by the walk in CouponPeriod, so N counts what remains.
	let remaining = period.couponsRemaining

	var total: T = T.zero
	if remaining > 0 {
		for k in 1...remaining {
			let exponent: T = T(k - 1) + unexpired
			total += coupon / T.pow(growth, exponent)
		}
		let redemptionExponent: T = T(remaining - 1) + unexpired
		total += redemption / T.pow(growth, redemptionExponent)
	} else {
		total = redemption / T.pow(growth, unexpired)
	}

	let accrued: T = coupon * period.accruedFraction
	return total - accrued
}

// MARK: - Yield

/// The yield implied by a bond's price — Excel's `YIELD`.
///
/// The inverse of ``bondPrice(settlement:maturity:rate:yield:redemption:frequency:basis:)``,
/// found by bisection on the price. Price falls monotonically as yield rises, so a
/// bracket cannot miss the root and bisection cannot diverge — worth the extra
/// iterations over a Newton step whose derivative would have to be differenced anyway.
///
/// - Parameters:
///   - settlement: When the trade settles.
///   - maturity: When the bond redeems.
///   - rate: The annual coupon rate.
///   - price: The clean price per 100 of face value.
///   - redemption: Redemption value per 100 of face. Usually 100.
///   - frequency: Coupons a year.
///   - basis: The day count.
/// - Returns: The annual yield to maturity.
/// - Throws: `BusinessMathError.invalidInput` for invalid arguments, or when no yield in
///   `[0, 100]` produces the given price.
public func bondYield<T: Real & BinaryFloatingPoint & Sendable>(
	settlement: Date,
	maturity: Date,
	rate: T,
	price: T,
	redemption: T = T(100),
	frequency: PaymentFrequency = .semiAnnual,
	basis: DayCountConvention = .thirty360
) throws -> T {
	guard price > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Price must be positive", value: "\(price)", expectedRange: "(0, ∞)")
	}

	func priceAt(_ candidate: T) throws -> T {
		try bondPrice(settlement: settlement, maturity: maturity, rate: rate,
					  yield: candidate, redemption: redemption,
					  frequency: frequency, basis: basis)
	}

	var low: T = T.zero
	var high: T = T(1)
	var highPrice: T = try priceAt(high)
	var expansions = 0
	while highPrice > price, expansions < 20 {
		high *= T(2)
		highPrice = try priceAt(high)
		expansions += 1
	}
	guard highPrice <= price else {
		throw BusinessMathError.invalidInput(
			message: "No yield below 100% produces this price; check the price and redemption",
			value: "\(price)", expectedRange: "a price reachable at a plausible yield")
	}

	let tolerance: T = T.ulpOfOne * T(4)
	for _ in 0..<bisectionStepsToFullPrecision(of: T.self) {
		let span: T = high - low
		let middle: T = low + span / T(2)
		if middle <= low || middle >= high { break }
		if try priceAt(middle) > price { low = middle } else { high = middle }
		if span < tolerance * Swift.max(middle, T.ulpOfOne) { break }
	}
	let span: T = high - low
	return low + span / T(2)
}

// MARK: - Duration

/// Macaulay duration in years — Excel's `DURATION`.
///
/// The present-value-weighted average time to a bond's cash flows: how long, on
/// average, the money takes to arrive. It is also the point on the yield curve at which
/// a bond's price is insensitive to a parallel shift, which is what makes it the unit
/// of interest-rate risk.
///
/// Each flow's time is measured in **periods from settlement** — `k − 1 + DSC/E` — and
/// converted to years at the end, so a mid-period settlement shortens every term by the
/// same fraction.
///
/// - Parameters:
///   - settlement: When the trade settles.
///   - maturity: When the bond redeems.
///   - rate: The annual coupon rate.
///   - yield: The annual yield to maturity.
///   - frequency: Coupons a year.
///   - basis: The day count.
/// - Returns: Macaulay duration, in years.
/// - Throws: `BusinessMathError.invalidInput` for invalid arguments.
public func bondDuration<T: Real & BinaryFloatingPoint & Sendable>(
	settlement: Date,
	maturity: Date,
	rate: T,
	yield: T,
	frequency: PaymentFrequency = .semiAnnual,
	basis: DayCountConvention = .thirty360
) throws -> T {
	guard rate >= T.zero, yield >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Rate and yield cannot be negative",
			value: "rate \(rate), yield \(yield)", expectedRange: "[0, ∞)")
	}

	let period = try CouponPeriod<T>(settlement: settlement, maturity: maturity,
									 frequency: frequency, basis: basis)
	let perYear = T(frequency.periodsPerYear)
	let periodicYield: T = yield / perYear
	let coupon: T = T(100) * rate / perYear
	let unexpired: T = period.remainingFraction
	let growth: T = T(1) + periodicYield
	let remaining = Swift.max(1, period.couponsRemaining)

	var weighted: T = T.zero
	var present: T = T.zero
	for k in 1...remaining {
		let periodsAway: T = T(k - 1) + unexpired
		let flow: T = k == remaining ? coupon + T(100) : coupon
		let discounted: T = flow / T.pow(growth, periodsAway)
		present += discounted
		weighted += discounted * periodsAway
	}

	guard present > T.zero else { return T.zero }
	let inPeriods: T = weighted / present
	return inPeriods / perYear
}

/// Modified duration in years — Excel's `MDURATION`.
///
/// ```
/// MDURATION = DURATION / (1 + yld/frq)
/// ```
///
/// Macaulay duration says when the money arrives; modified duration says what a change
/// in yield does to the price. The division converts one into the other, and it is the
/// only difference between them.
///
/// - Returns: Modified duration, in years.
/// - Throws: `BusinessMathError.invalidInput` for invalid arguments.
public func bondModifiedDuration<T: Real & BinaryFloatingPoint & Sendable>(
	settlement: Date,
	maturity: Date,
	rate: T,
	yield: T,
	frequency: PaymentFrequency = .semiAnnual,
	basis: DayCountConvention = .thirty360
) throws -> T {
	let macaulay: T = try bondDuration(settlement: settlement, maturity: maturity,
									   rate: rate, yield: yield,
									   frequency: frequency, basis: basis)
	let perYear = T(frequency.periodsPerYear)
	return macaulay / (T(1) + yield / perYear)
}

// MARK: - Two rate conversions

/// The effective annual rate behind a nominal one — Excel's `EFFECT`.
///
/// ```
/// (1 + nominal/npery)^npery − 1
/// ```
///
/// The inverse of ``nominalRate(effectiveRate:periodsPerYear:)``. A quoted rate is not
/// comparable across compounding frequencies and an effective one is, so a comparison
/// has to convert — and 10% quoted monthly is 10.4713% actually.
///
/// - Parameters:
///   - nominalRate: The quoted annual rate.
///   - periodsPerYear: How many times a year it compounds. Must be positive.
/// - Returns: The effective annual rate.
/// - Throws: `BusinessMathError.invalidInput` if `periodsPerYear` is not positive.
public func effectiveRate<T: Real>(nominalRate: T, periodsPerYear: T) throws -> T {
	guard periodsPerYear > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Compounding periods per year must be positive",
			value: "\(periodsPerYear)", expectedRange: "(0, ∞)")
	}
	let perPeriod: T = T(1) + nominalRate / periodsPerYear
	return T.pow(perPeriod, periodsPerYear) - T(1)
}

/// The equivalent periodic rate of an investment's growth — Excel's `RRI`.
///
/// ```
/// (fv / pv)^(1/nper) − 1
/// ```
///
/// The constant rate that would have taken `pv` to `fv` over `nper` periods. Not an
/// annuity: no payments, just compounding, so this is the geometric mean growth rate.
///
/// - Parameters:
///   - periods: How many periods the growth took. Must be positive.
///   - presentValue: The starting value. Must be positive.
///   - futureValue: The ending value. Must be non-negative.
/// - Returns: The periodic rate. Negative when the value fell.
/// - Throws: `BusinessMathError.invalidInput` for arguments outside those ranges.
public func equivalentRate<T: Real>(periods: T, presentValue: T, futureValue: T) throws -> T {
	guard periods > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Number of periods must be positive",
			value: "\(periods)", expectedRange: "(0, ∞)")
	}
	guard presentValue > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Present value must be positive",
			value: "\(presentValue)", expectedRange: "(0, ∞)")
	}
	guard futureValue >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Future value cannot be negative",
			value: "\(futureValue)", expectedRange: "[0, ∞)")
	}
	let ratio: T = futureValue / presentValue
	return T.pow(ratio, T(1) / periods) - T(1)
}
