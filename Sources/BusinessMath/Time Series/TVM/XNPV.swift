//
//  XNPV.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - XNPV Error

/// Errors that can occur during XNPV/XIRR calculation.
public enum XNPVError: Error, Sendable {
	/// Dates and cash flows arrays have different lengths.
	case mismatchedArrays

	/// All cash flows have the same sign (all positive or all negative).
	case invalidCashFlows

	/// Not enough data provided (need at least 2 cash flows).
	case insufficientData

	/// The Newton-Raphson method failed to converge for XIRR.
	case convergenceFailed
}

// MARK: - XNPV Functions

/// Calculates the Net Present Value for irregular cash flow dates.
///
/// XNPV is similar to NPV but uses actual dates to calculate fractional years
/// between cash flows, rather than assuming regular periods.
///
/// **Formula:**
/// ```
/// XNPV = Σ(CF_i / (1+r)^((date_i - date_0) / 365))
/// ```
///
/// Where:
/// - CF_i = Cash flow at date i
/// - r = Discount rate (annual)
/// - date_i = Date of cash flow i
/// - date_0 = Date of first cash flow
///
/// - Parameters:
///   - rate: The annual discount rate (e.g., 0.10 for 10%).
///   - dates: Array of dates for each cash flow (must be same length as cashFlows).
///   - cashFlows: Array of cash flow amounts.
/// - Returns: The net present value.
/// - Throws: `XNPVError` if calculation fails.
///
/// ## Examples
///
/// **Regular Intervals:**
/// ```swift
/// let calendar = Calendar.current
/// // Annual cash flows on Jan 1
/// let dates = [
///     calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? Date()
/// ]
/// let cashFlows = [-1000.0, 600.0, 600.0]
/// let presentValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
/// // Result: ~81.82 (similar to regular NPV)
/// ```
///
/// **Irregular Intervals:**
/// ```swift
/// let calendar = Calendar.current
/// // Cash flows at irregular dates
/// let dates = [
///     calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2025, month: 4, day: 15)) ?? Date(),  // ~3.5 months later
///     calendar.date(from: DateComponents(year: 2025, month: 9, day: 20)) ?? Date(),  // ~8.5 months from start
///     calendar.date(from: DateComponents(year: 2026, month: 3, day: 10)) ?? Date()   // ~14 months from start
/// ]
/// let cashFlows = [-1000.0, 300.0, 400.0, 500.0]
/// let presentValue = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
/// ```
///
/// ## Use Cases
/// - Real estate investments with irregular rent payments
/// - Business loans with non-standard payment schedules
/// - Venture capital investments with multiple funding rounds
/// - Stock portfolios with irregular dividends
///
/// ## Important Notes
/// - Dates are used to calculate exact fractional years
/// - Uses 365 days per year (not accounting for leap years in fractional calculation)
/// - First date is used as the reference point (time 0)
/// - Dates should generally be in chronological order
public func xnpv<T: Real & BinaryFloatingPoint>(
	rate: T,
	dates: [Date],
	cashFlows: [T]
) throws -> T {
	// Validate input
	guard dates.count == cashFlows.count else {
		throw XNPVError.mismatchedArrays
	}

	guard dates.count >= 1 else {
		throw XNPVError.insufficientData
	}

	// First date is the reference point (time 0)
	let baseDate = dates[0]
	var xnpv = T.zero

	for (date, cashFlow) in zip(dates, cashFlows) {
		// Whole calendar days over 365, which is what the spreadsheet computes — not
		// elapsed seconds over a year's worth of them. The two differ by an hour across
		// a daylight-saving boundary, that difference lands in an exponent, and it showed
		// as a few parts in a hundred thousand on the discounted total, growing with the
		// rate. ``DayCountConvention/actual365`` already counts civil days midnight to
		// midnight, so this reuses it rather than repeating the arithmetic.
		let yearsDouble: Double = DayCountConvention.actual365
			.yearFraction(from: baseDate, to: date)

		// Convert to T type. Exact for Double, correctly rounded for narrower scalars —
		// crucially the fractional part of the offset survives.
		let years = T(yearsDouble)

		// Discount cash flow: CF / (1 + r)^years
		let discountFactor = T.pow(T(1) + rate, years)
		xnpv = xnpv + cashFlow / discountFactor
	}

	return xnpv
}

/// Calculates the Internal Rate of Return for irregular cash flow dates.
///
/// XIRR is similar to IRR but uses actual dates to calculate fractional years,
/// rather than assuming regular periods. It finds the rate that makes XNPV = 0.
///
/// **Method:** Uses Newton-Raphson iterative method with XNPV.
///
/// **Formula:**
/// ```
/// Find r where: XNPV(r, dates, cash flows) = 0
/// ```
///
/// - Parameters:
///   - dates: Array of dates for each cash flow.
///   - cashFlows: Array of cash flow amounts (negative for outflows, positive for inflows).
///   - guess: Initial guess for the rate (default: 0.1 or 10%).
///   - tolerance: **Relative** convergence tolerance on the rate. The iteration stops
///     once a Newton correction moves the rate by less than `tolerance × max(|rate|, 1)`.
///     Defaults to `√(ulpOfOne)`, derived from the numeric type. See
///     ``irr(cashFlows:guess:tolerance:maxIterations:)`` for why this is measured on the
///     rate rather than on the XNPV residual — the same reasoning applies here, and the
///     failure it fixes is the same: at a large enough cash-flow scale the old absolute
///     bound could never be met and this function threw rather than returning the answer
///     it had already found.
///   - maxIterations: Maximum number of iterations (default: 100).
/// - Returns: The annualized internal rate of return as a decimal.
/// - Throws: `XNPVError` if calculation fails.
///
/// ## Examples
///
/// **Regular Intervals:**
/// ```swift
/// let calendar = Calendar.current
/// // Annual cash flows (should match regular IRR)
/// let dates = [
///     calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2028, month: 1, day: 1)) ?? Date()
/// ]
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
/// let rate = try xirr(dates: dates, cashFlows: cashFlows)
/// // Result: ~0.0970 (9.7%, similar to regular IRR)
/// ```
///
/// **Irregular Intervals:**
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// let calendar = Calendar.current
/// // Investment with irregular returns
/// let dates = [
///     calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2025, month: 5, day: 15)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2025, month: 11, day: 30)) ?? Date(),
///     calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)) ?? Date()
/// ]
/// let cashFlows = [-1000.0, 200.0, 300.0, 600.0]
/// let rate = try xirr(dates: dates, cashFlows: cashFlows)
/// ```
///
/// ## Real-World Applications
///
/// **Real Estate Investment:**
/// ```swift
/// let calendar = Calendar.current
/// let dates = [
///     calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)) ?? Date(),  // Purchase
///     calendar.date(from: DateComponents(year: 2025, month: 6, day: 3)) ?? Date(),   // Irregular rent payment 1
///     calendar.date(from: DateComponents(year: 2025, month: 11, day: 22)) ?? Date(), // Irregular rent payment 2
///     calendar.date(from: DateComponents(year: 2026, month: 4, day: 9)) ?? Date()    // Sale + final rent
/// ]
/// let cashFlows = [-100000.0, 3000.0, 3000.0, 105000.0]
/// let rate = try xirr(dates: dates, cashFlows: cashFlows)
/// ```
///
/// **Venture Capital:**
/// ```swift
/// let calendar = Calendar.current
/// let dates = [
///     calendar.date(from: DateComponents(year: 2019, month: 3, day: 1)) ?? Date(),  // Seed round
///     calendar.date(from: DateComponents(year: 2020, month: 9, day: 15)) ?? Date(), // Series A
///     calendar.date(from: DateComponents(year: 2022, month: 2, day: 7)) ?? Date(),  // Series B
///     calendar.date(from: DateComponents(year: 2025, month: 8, day: 30)) ?? Date()  // Exit
/// ]
/// let cashFlows = [-500000.0, -1000000.0, -2000000.0, 10000000.0]
/// let rate = try xirr(dates: dates, cashFlows: cashFlows)
/// ```
///
/// ## Important Notes
/// - Returns annualized rate regardless of actual time period
/// - More accurate than IRR for irregular cash flows
/// - Like IRR, can have multiple solutions for complex cash flows
/// - At XIRR, XNPV = 0
///
/// ## Error Cases
/// - Throws `.invalidCashFlows` if all cash flows are positive or all negative.
/// - Throws `.insufficientData` if fewer than 2 cash flows provided.
/// - Throws `.mismatchedArrays` if dates and cash flows have different lengths.
/// - Throws `.convergenceFailed` if Newton-Raphson doesn't converge.
public func xirr<T: Real & BinaryFloatingPoint>(
	dates: [Date],
	cashFlows: [T],
	guess: T? = nil,
	tolerance: T? = nil,
	maxIterations: Int = 100
) throws -> T {
	let actualGuess: T = guess ?? (T(1) / T(10))
	// Relative, and derived from the type — see the parameter documentation.
	let actualTolerance: T = tolerance ?? T.sqrt(T.ulpOfOne)

	// Validate input
	guard dates.count == cashFlows.count else {
		throw XNPVError.mismatchedArrays
	}

	guard dates.count >= 2 else {
		throw XNPVError.insufficientData
	}

	// Check for sign changes (need both positive and negative)
	let hasPositive = cashFlows.contains { $0 > T.zero }
	let hasNegative = cashFlows.contains { $0 < T.zero }

	guard hasPositive && hasNegative else {
		throw XNPVError.invalidCashFlows
	}

	// Newton-Raphson iteration
	var rate = actualGuess

	for _ in 0..<maxIterations {
		// Calculate XNPV at current rate
		let npv = try xnpv(rate: rate, dates: dates, cashFlows: cashFlows)

		// An exact root needs no correction.
		if npv.isZero { return rate }

		// Calculate derivative of XNPV (dXNPV/dr)
		let derivative = calculateXNPVDerivative(rate: rate, dates: dates, cashFlows: cashFlows)

		// Newton-Raphson update: rate_new = rate_old - f(rate) / f'(rate)
		let correction: T = npv / derivative
		let candidate: T = rate - correction

		// The step, not the derivative's magnitude, is what says whether the method can
		// proceed — see ``irr(cashFlows:guess:tolerance:maxIterations:)``. A rate at or
		// below −100% is not a return and `(1+r)^t` is undefined there for fractional
		// `t`, which every XNPV term has.
		guard correction.isFinite, candidate > T(-1) else {
			throw XNPVError.convergenceFailed
		}

		rate = candidate

		// Convergence on the rate. The correction is scale-invariant — the cash-flow
		// units cancel between XNPV and its derivative — so a model in dollars and the
		// same model in billions stop at the same place. Tested after the step, so the
		// returned value is the corrected one.
		let reference: T = Swift.max(abs(rate), T(1))
		let threshold: T = actualTolerance * reference
		if abs(correction) <= threshold { return rate }
	}

	// If we get here, didn't converge
	throw XNPVError.convergenceFailed
}

// MARK: - Helper Functions

/// Calculates the derivative of XNPV with respect to the discount rate.
///
/// This is used in the Newton-Raphson method:
/// ```
/// dXNPV/dr = -Σ(years_i × CF_i / (1+r)^(years_i+1))
/// ```
private func calculateXNPVDerivative<T: Real & BinaryFloatingPoint>(
	rate: T,
	dates: [Date],
	cashFlows: [T]
) -> T {
	let baseDate = dates[0]
	var derivative = T.zero

	for (date, cashFlow) in zip(dates, cashFlows) {
		// Whole calendar days over 365, which is what the spreadsheet computes — not
		// elapsed seconds over a year's worth of them. The two differ by an hour across
		// a daylight-saving boundary, that difference lands in an exponent, and it showed
		// as a few parts in a hundred thousand on the discounted total, growing with the
		// rate. ``DayCountConvention/actual365`` already counts civil days midnight to
		// midnight, so this reuses it rather than repeating the arithmetic.
		let yearsDouble: Double = DayCountConvention.actual365
			.yearFraction(from: baseDate, to: date)

		// Convert to T type (see `xnpv` — the fractional part must survive).
		let years = T(yearsDouble)

		// Skip zero years (derivative term is 0)
		let minYears = T(1) / T(10000)  // 0.0001
		if abs(years) > minYears {
			let numerator = years * cashFlow
			let denominator = T.pow(T(1) + rate, years + T(1))
			derivative = derivative - numerator / denominator
		}
	}

	return derivative
}
