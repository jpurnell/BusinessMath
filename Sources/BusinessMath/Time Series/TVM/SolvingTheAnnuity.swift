//
//  SolvingTheAnnuity.swift
//  BusinessMath
//
//  The annuity identity, solved for the two variables this package could not solve
//  for, plus two growth functions that are one logarithm each.
//

import Foundation
import Numerics

// MARK: - The identity

/// The residual of the time-value identity, which every annuity function solves for one
/// of its variables.
///
/// ```
/// pv·(1+r)ⁿ  +  pmt·(1 + r·type)·((1+r)ⁿ − 1)/r  +  fv  =  0
/// ```
///
/// ## The sign convention, which is not decoration
///
/// Cash flows are **signed by direction**: money received is positive, money paid out is
/// negative. Borrowing 8,000 and repaying 200 a month is `pv: 8_000, pmt: -200`.
///
/// That differs from ``payment(presentValue:rate:periods:futureValue:type:)`` in this
/// same directory, which takes a positive present value and returns a positive payment —
/// a magnitude convention, which works because the direction is implied by which
/// variable you are asking for. It does not work here. Solving for a rate or a term
/// requires knowing that the payments oppose the principal; given only magnitudes the
/// equation has no solution, because nothing ever gets repaid.
///
/// - Parameters:
///   - rate: The periodic rate.
///   - periods: The number of periods, which may be fractional.
///   - payment: The amount paid each period, signed.
///   - presentValue: The value at time zero, signed.
///   - futureValue: The value after `periods`, signed.
///   - type: Whether payments fall at the end of each period or the beginning.
/// - Returns: Zero when the five quantities are consistent.
internal func annuityResidual<T: Real>(
	rate: T, periods: T, payment: T, presentValue: T, futureValue: T, type: AnnuityType
) -> T {
	let timing: T = type == .due ? T(1) : T.zero

	if rate == T.zero {
		let paid: T = payment * periods
		return presentValue + paid + futureValue
	}

	let growth: T = T.pow(T(1) + rate, periods)
	let annuityFactor: T = (growth - T(1)) / rate
	let adjustment: T = T(1) + rate * timing
	let paymentLeg: T = payment * adjustment * annuityFactor
	let principalLeg: T = presentValue * growth
	return principalLeg + paymentLeg + futureValue
}

// MARK: - Number of periods

/// How many periods it takes to get from a present value to a future value — Excel's `NPER`.
///
/// Solved in closed form from the annuity identity. Writing `k = pmt(1 + r·type)/r`, the
/// identity rearranges to `(1+r)ⁿ = (k − fv)/(pv + k)`, and one logarithm finishes it.
/// A zero rate degenerates to the linear case, `n = −(pv + fv)/pmt`.
///
/// The result is generally fractional: forty-two and a half periods means the last
/// payment is a part payment, not that the answer should be rounded.
///
/// ```swift
/// // A 20,000 balance, 250 a month against it, at 6% a year.
/// let months = try numberOfPeriods(rate: 0.005, payment: -250,
///                                  presentValue: 20_000, futureValue: 0)
/// ```
///
/// - Parameters:
///   - rate: The periodic rate.
///   - payment: The amount paid each period, signed — see `annuityResidual(rate:periods:payment:presentValue:futureValue:type:)`.
///   - presentValue: The value at time zero, signed.
///   - futureValue: The value at the end. Defaults to zero.
///   - type: Whether payments fall at the end of each period or the beginning.
/// - Returns: The number of periods, which may be fractional.
/// - Throws: `BusinessMathError.invalidInput` when no term satisfies the identity —
///   a zero payment at a zero rate, or a combination whose logarithm has no real value,
///   which means the payments never retire the balance.
public func numberOfPeriods<T: Real>(
	rate: T,
	payment: T,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary
) throws -> T {
	if rate == T.zero {
		guard payment != T.zero else {
			throw BusinessMathError.invalidInput(
				message: "With no interest and no payment there is no term that changes the balance",
				value: "payment \(payment)", expectedRange: "non-zero")
		}
		let total: T = presentValue + futureValue
		return -total / payment
	}

	let timing: T = type == .due ? T(1) : T.zero
	let adjustment: T = T(1) + rate * timing
	let paymentValue: T = payment * adjustment / rate

	let numerator: T = paymentValue - futureValue
	let denominator: T = presentValue + paymentValue
	guard denominator != T.zero else {
		throw BusinessMathError.invalidInput(
			message: "The payment exactly services the interest, so the balance never changes",
			value: "payment \(payment)", expectedRange: "a payment that amortises the principal")
	}

	let growth: T = numerator / denominator
	guard growth > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "No real term satisfies this combination — the payments never reach the future value",
			value: "(pmt/r − fv)/(pv + pmt/r) = \(growth)", expectedRange: "(0, ∞)")
	}

	return T.log(growth) / T.log(T(1) + rate)
}

// MARK: - Rate

/// The periodic rate implied by an annuity — Excel's `RATE`.
///
/// There is no closed form, so this is Newton's method on
/// `annuityResidual(rate:periods:payment:presentValue:futureValue:type:)`, safeguarded
/// by a bracket that bisection tightens whenever a Newton step would leave it. The
/// derivative is taken numerically: the analytic one is a page of algebra whose
/// transcription is the likeliest place for an error, and a central difference costs one
/// extra evaluation of an expression that is already cheap.
///
/// The safeguard matters here more than usual. The residual is very flat for small rates
/// and very steep near `-1`, so an unguarded Newton step from a poor guess readily jumps
/// below `-100%`, where `(1+r)ⁿ` has no real value.
///
/// ```swift
/// // 8,000 borrowed, 200 a month for four years: what rate is that?
/// let monthly = try periodicRate(periods: 48, payment: -200, presentValue: 8_000)
/// ```
///
/// - Parameters:
///   - periods: The number of periods. Must be positive.
///   - payment: The amount paid each period, signed.
///   - presentValue: The value at time zero, signed.
///   - futureValue: The value at the end. Defaults to zero.
///   - type: Whether payments fall at the end of each period or the beginning.
///   - guess: Where to start. Excel's default of 10% is used here too; a different one
///     changes the path taken, not the root found, because the bracket contains it.
/// - Returns: The periodic rate.
/// - Throws: `BusinessMathError.invalidInput` for a non-positive term, or when the
///   iteration cannot bracket a root — which means the cash flows never balance at any
///   rate above −100%.
public func periodicRate<T: Real>(
	periods: T,
	payment: T,
	presentValue: T,
	futureValue: T = T.zero,
	type: AnnuityType = .ordinary,
	guess: T = T(1) / T(10)
) throws -> T {
	guard periods > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Number of periods must be positive",
			value: "\(periods)", expectedRange: "(0, ∞)")
	}

	func residual(_ rate: T) -> T {
		annuityResidual(rate: rate, periods: periods, payment: payment,
						presentValue: presentValue, futureValue: futureValue, type: type)
	}

	// Just above −100%: at exactly −1 the growth factor is zero and below it the power
	// of a negative base has no real value for a fractional term.
	var low: T = T(-1) + T.ulpOfOne
	var high: T = T(1)
	var lowValue: T = residual(low)
	var highValue: T = residual(high)

	// Widen upward until the residual changes sign. A rate beyond this is not a
	// financing arrangement anyone is describing.
	var expansions = 0
	while lowValue * highValue > T.zero, expansions < 60 {
		high *= T(2)
		highValue = residual(high)
		expansions += 1
	}
	guard lowValue * highValue <= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "These cash flows do not balance at any rate above −100%; check the payment's sign",
			value: "pv \(presentValue), pmt \(payment), fv \(futureValue)",
			expectedRange: "a payment opposing the present value")
	}

	var rate: T = guess
	if rate <= low || rate >= high { rate = (low + high) / T(2) }

	let tolerance: T = T.ulpOfOne * T(4)
	let iterationLimit = bisectionStepsToFullPrecision(of: T.self)

	for _ in 0..<iterationLimit {
		let value: T = residual(rate)
		if value * lowValue > T.zero {
			low = rate
			lowValue = value
		} else {
			high = rate
			highValue = value
		}

		// A central difference, on a step scaled to the current estimate.
		let step: T = Swift.max(abs(rate), T.ulpOfOne) * T.sqrt(T.ulpOfOne)
		let ahead: T = residual(rate + step)
		let behind: T = residual(rate - step)
		let slope: T = (ahead - behind) / (T(2) * step)

		var delta: T = T.nan
		if slope != T.zero, slope.isFinite { delta = value / slope }

		let candidate: T = rate - delta
		let insideBracket = candidate > low && candidate < high
		let converged: T = tolerance * Swift.max(abs(rate), T.ulpOfOne)

		// Convergence before the bisection fallback — an exact hit makes the candidate
		// equal to a bracket endpoint, which the strict comparison would reject.
		if insideBracket, abs(delta) < converged { return candidate }

		if insideBracket {
			rate = candidate
		} else {
			let span: T = high - low
			rate = low + span / T(2)
			if span < converged { break }
		}
	}

	return rate
}

// MARK: - Growth

/// How many periods a value takes to grow from one amount to another — Excel's `PDURATION`.
///
/// ```
/// ln(fv / pv) / ln(1 + rate)
/// ```
///
/// No payments, no annuity: just compounding. This is the whole function, and it is
/// separate from ``numberOfPeriods(rate:payment:presentValue:futureValue:type:)`` because
/// the sign convention does not apply — both amounts are magnitudes of the same balance,
/// so both are positive.
///
/// - Parameters:
///   - rate: The periodic rate. Must be positive; at zero or below nothing grows.
///   - presentValue: The starting amount. Must be positive.
///   - futureValue: The target amount. Must be positive.
/// - Returns: The number of periods, generally fractional.
/// - Throws: `BusinessMathError.invalidInput` if any argument is out of range.
public func periodsToGrow<T: Real>(rate: T, presentValue: T, futureValue: T) throws -> T {
	guard rate > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Growth rate must be positive; at zero or below the value never reaches a larger target",
			value: "\(rate)", expectedRange: "(0, ∞)")
	}
	guard presentValue > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Present value must be positive",
			value: "\(presentValue)", expectedRange: "(0, ∞)")
	}
	guard futureValue > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Future value must be positive",
			value: "\(futureValue)", expectedRange: "(0, ∞)")
	}

	let ratio: T = futureValue / presentValue
	return T.log(ratio) / T.log(T(1) + rate)
}

/// The nominal annual rate behind an effective one — Excel's `NOMINAL`.
///
/// ```
/// npery · ((1 + effective)^(1/npery) − 1)
/// ```
///
/// The inverse of the effective-annual-rate calculation: given what a year actually
/// costs, this says what rate would be *quoted* if it compounded `periodsPerYear` times.
/// 10% effective, compounded monthly, is quoted as 9.569%.
///
/// The gap between the two is the whole reason both exist. A quoted rate is not
/// comparable across compounding frequencies and an effective one is, so a comparison
/// has to convert — and the direction of the conversion is easy to reverse.
///
/// - Parameters:
///   - effectiveRate: The effective annual rate. Must exceed −100%.
///   - periodsPerYear: How many times a year the nominal rate compounds. Must be
///     positive.
/// - Returns: The nominal annual rate.
/// - Throws: `BusinessMathError.invalidInput` if either argument is out of range.
///
/// ## See Also
/// - ``DebtInstrument/effectiveAnnualRate()``
public func nominalRate<T: Real>(effectiveRate: T, periodsPerYear: T) throws -> T {
	guard periodsPerYear > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Compounding periods per year must be positive",
			value: "\(periodsPerYear)", expectedRange: "(0, ∞)")
	}
	guard effectiveRate > T(-1) else {
		throw BusinessMathError.invalidInput(
			message: "Effective rate must exceed −100%",
			value: "\(effectiveRate)", expectedRange: "(−1, ∞)")
	}

	let exponent: T = T(1) / periodsPerYear
	let perPeriod: T = T.pow(T(1) + effectiveRate, exponent) - T(1)
	return periodsPerYear * perPeriod
}
