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
/// // Annual cash flows on Jan 1
/// let dates = [
///     Date(year: 2025, month: 1, day: 1),
///     Date(year: 2026, month: 1, day: 1),
///     Date(year: 2027, month: 1, day: 1)
/// ]
/// let cashFlows = [-1000.0, 600.0, 600.0]
/// let xnpv = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
/// // Result: ~81.82 (similar to regular NPV)
/// ```
///
/// **Irregular Intervals:**
/// ```swift
/// // Cash flows at irregular dates
/// let dates = [
///     Date(year: 2025, month: 1, day: 1),
///     Date(year: 2025, month: 4, day: 15),  // ~3.5 months later
///     Date(year: 2025, month: 9, day: 20),  // ~8.5 months from start
///     Date(year: 2026, month: 3, day: 10)   // ~14 months from start
/// ]
/// let cashFlows = [-1000.0, 300.0, 400.0, 500.0]
/// let xnpv = try xnpv(rate: 0.10, dates: dates, cashFlows: cashFlows)
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
public func xnpv<T: Real>(
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
		// Calculate fractional years from base date
		let timeInterval = date.timeIntervalSince(baseDate)
		let secondsPerYear = 365.0 * 24.0 * 60.0 * 60.0
		let yearsDouble = timeInterval / secondsPerYear

		// Convert to T type
		let years: T
		if let d = yearsDouble as? T {
			years = d
		} else {
			years = T(Int(yearsDouble))  // Fallback for types that don't support Double conversion
		}

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
///   - tolerance: Convergence tolerance (default: 0.0001 or 0.01%).
///   - maxIterations: Maximum number of iterations (default: 100).
/// - Returns: The annualized internal rate of return as a decimal.
/// - Throws: `XNPVError` if calculation fails.
///
/// ## Examples
///
/// **Regular Intervals:**
/// ```swift
/// // Annual cash flows (should match regular IRR)
/// let dates = [
///     Date(year: 2025, month: 1, day: 1),
///     Date(year: 2026, month: 1, day: 1),
///     Date(year: 2027, month: 1, day: 1),
///     Date(year: 2028, month: 1, day: 1)
/// ]
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
/// let xirr = try xirr(dates: dates, cashFlows: cashFlows)
/// // Result: ~0.0970 (9.7%, similar to regular IRR)
/// ```
///
/// **Irregular Intervals:**
/// ```swift
/// // Investment with irregular returns
/// let dates = [
///     Date(year: 2025, month: 1, day: 1),
///     Date(year: 2025, month: 5, day: 15),
///     Date(year: 2025, month: 11, day: 30),
///     Date(year: 2026, month: 6, day: 1)
/// ]
/// let cashFlows = [-1000.0, 200.0, 300.0, 600.0]
/// let xirr = try xirr(dates: dates, cashFlows: cashFlows)
/// ```
///
/// ## Real-World Applications
///
/// **Real Estate Investment:**
/// ```swift
/// let dates = [
///     Date(...),  // Purchase
///     Date(...),  // Irregular rent payment 1
///     Date(...),  // Irregular rent payment 2
///     Date(...),  // Sale + final rent
/// ]
/// let cashFlows = [-100000.0, 3000.0, 3000.0, 105000.0]
/// let xirr = try xirr(dates: dates, cashFlows: cashFlows)
/// ```
///
/// **Venture Capital:**
/// ```swift
/// let dates = [
///     Date(...),  // Seed round
///     Date(...),  // Series A
///     Date(...),  // Series B
///     Date(...),  // Exit
/// ]
/// let cashFlows = [-500000.0, -1000000.0, -2000000.0, 10000000.0]
/// let xirr = try xirr(dates: dates, cashFlows: cashFlows)
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
public func xirr<T: Real>(
	dates: [Date],
	cashFlows: [T],
	guess: T? = nil,
	tolerance: T? = nil,
	maxIterations: Int = 100
) throws -> T {
	let actualGuess: T = guess ?? (T(1) / T(10))
	let actualTolerance: T = tolerance ?? (T(1) / T(10000))

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

		// Check for convergence
		if abs(npv) < actualTolerance {
			return rate
		}

		// Calculate derivative of XNPV (dXNPV/dr)
		let derivative = calculateXNPVDerivative(rate: rate, dates: dates, cashFlows: cashFlows)

		// Avoid division by zero
		let minDerivative = T(1) / T(1000000)
		guard abs(derivative) > minDerivative else {
			throw XNPVError.convergenceFailed
		}

		// Newton-Raphson update: rate_new = rate_old - f(rate) / f'(rate)
		rate = rate - npv / derivative
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
private func calculateXNPVDerivative<T: Real>(
	rate: T,
	dates: [Date],
	cashFlows: [T]
) -> T {
	let baseDate = dates[0]
	var derivative = T.zero

	for (date, cashFlow) in zip(dates, cashFlows) {
		// Calculate fractional years from base date
		let timeInterval = date.timeIntervalSince(baseDate)
		let secondsPerYear = 365.0 * 24.0 * 60.0 * 60.0
		let yearsDouble = timeInterval / secondsPerYear

		// Convert to T type
		let years: T
		if let d = yearsDouble as? T {
			years = d
		} else {
			years = T(Int(yearsDouble))
		}

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
