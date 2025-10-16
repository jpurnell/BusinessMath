//
//  IRR.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - IRR Error

/// Errors that can occur during IRR calculation.
public enum IRRError: Error, Sendable {
	/// All cash flows have the same sign (all positive or all negative).
	case invalidCashFlows

	/// The Newton-Raphson method failed to converge within the maximum iterations.
	case convergenceFailed

	/// Not enough cash flows provided (need at least 2).
	case insufficientData
}

// MARK: - IRR Functions

/// Calculates the Internal Rate of Return (IRR) for a series of cash flows.
///
/// IRR is the discount rate that makes the Net Present Value (NPV) equal to zero.
/// It represents the annualized effective compounded return rate.
///
/// **Method:** Uses Newton-Raphson iterative method to find the rate where NPV = 0.
///
/// **Formula:**
/// ```
/// Find r where: Σ(CF_t / (1+r)^t) = 0
/// ```
///
/// Where:
/// - CF_t = Cash flow at time t
/// - r = Internal rate of return
/// - t = Time period (0, 1, 2, ...)
///
/// - Parameters:
///   - cashFlows: Array of cash flows, where negative values represent outflows (investments)
///     and positive values represent inflows (returns). First value is typically negative (initial investment).
///   - guess: Initial guess for the rate (default: 0.1 or 10%).
///   - tolerance: Convergence tolerance (default: 0.0001 or 0.01%).
///   - maxIterations: Maximum number of iterations (default: 100).
/// - Returns: The IRR as a decimal (e.g., 0.15 for 15%).
/// - Throws: `IRRError` if calculation fails.
///
/// ## Examples
///
/// **Simple Investment:**
/// ```swift
/// // Invest $1000, receive $400/year for 3 years
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
/// let irr = try irr(cashFlows: cashFlows)
/// // Result: ~0.0970 (9.7%)
/// ```
///
/// **Real Estate Investment:**
/// ```swift
/// // $100k purchase, 5 years of rent, then sale
/// let cashFlows = [
///     -100000.0,  // Purchase
///     12000.0,    // Year 1 rent
///     12000.0,    // Year 2 rent
///     12000.0,    // Year 3 rent
///     12000.0,    // Year 4 rent
///     130000.0    // Year 5 rent + sale
/// ]
/// let irr = try irr(cashFlows: cashFlows)
/// // Result: ~0.152 (15.2%)
/// ```
///
/// **Project Evaluation:**
/// ```swift
/// // Compare two projects
/// let projectA = [-1000.0, 600.0, 600.0]
/// let projectB = [-1000.0, 200.0, 200.0, 800.0]
///
/// let irrA = try irr(cashFlows: projectA)  // Higher IRR (faster return)
/// let irrB = try irr(cashFlows: projectB)  // Lower IRR (delayed return)
/// ```
///
/// ## Important Notes
///
/// - **Conventional Cash Flows:** Most accurate when there's one sign change (e.g., negative investment followed by positive returns).
/// - **Multiple IRRs:** Cash flows with multiple sign changes may have multiple valid IRR solutions. The function returns one solution found from the initial guess.
/// - **NPV Relationship:** At IRR, NPV = 0. Projects with IRR > cost of capital are considered acceptable.
///
/// ## Error Cases
/// - Throws `.invalidCashFlows` if all cash flows are positive or all negative.
/// - Throws `.insufficientData` if fewer than 2 cash flows provided.
/// - Throws `.convergenceFailed` if Newton-Raphson doesn't converge within max iterations.
public func irr<T: Real>(
	cashFlows: [T],
	guess: T? = nil,
	tolerance: T? = nil,
	maxIterations: Int = 100
) throws -> T {
	let actualGuess: T = guess ?? (T(1) / T(10))
	let actualTolerance: T = tolerance ?? (T(1) / T(10000))
	// Validate input
	guard cashFlows.count >= 2 else {
		throw IRRError.insufficientData
	}

	// Check for sign changes (need both positive and negative)
	let hasPositive = cashFlows.contains { $0 > T.zero }
	let hasNegative = cashFlows.contains { $0 < T.zero }

	guard hasPositive && hasNegative else {
		throw IRRError.invalidCashFlows
	}

	// Newton-Raphson iteration
	var rate = actualGuess

	for _ in 0..<maxIterations {
		// Calculate NPV at current rate
		let npv = calculateNPV(cashFlows: cashFlows, rate: rate)

		// Check for convergence
		if abs(npv) < actualTolerance {
			return rate
		}

		// Calculate derivative of NPV (dNPV/dr)
		let derivative = calculateNPVDerivative(cashFlows: cashFlows, rate: rate)

		// Avoid division by zero
		let minDerivative = T(1) / T(1000000)  // 0.000001
		guard abs(derivative) > minDerivative else {
			throw IRRError.convergenceFailed
		}

		// Newton-Raphson update: rate_new = rate_old - f(rate) / f'(rate)
		rate = rate - npv / derivative
	}

	// If we get here, didn't converge
	throw IRRError.convergenceFailed
}

/// Calculates the Modified Internal Rate of Return (MIRR).
///
/// MIRR addresses some limitations of IRR by using different rates for financing and reinvestment.
/// It assumes:
/// - Negative cash flows (outflows) are financed at the finance rate
/// - Positive cash flows (inflows) are reinvested at the reinvestment rate
///
/// **Formula:**
/// ```
/// MIRR = (FV_positive / PV_negative)^(1/n) - 1
/// ```
///
/// Where:
/// - FV_positive = Future value of positive cash flows at reinvestment rate
/// - PV_negative = Present value of negative cash flows at finance rate
/// - n = Number of periods
///
/// - Parameters:
///   - cashFlows: Array of cash flows (negative for outflows, positive for inflows).
///   - financeRate: The rate at which negative cash flows are financed.
///   - reinvestmentRate: The rate at which positive cash flows are reinvested.
/// - Returns: The MIRR as a decimal.
/// - Throws: `IRRError` if calculation fails.
///
/// ## Example
///
/// ```swift
/// // Project with $1000 investment, $400/year returns
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
///
/// // Finance at 12%, reinvest at 8%
/// let mirr = try mirr(
///     cashFlows: cashFlows,
///     financeRate: 0.12,
///     reinvestmentRate: 0.08
/// )
/// // Result: ~0.085 (8.5%)
/// ```
///
/// ## MIRR vs IRR
///
/// - **IRR assumes reinvestment at IRR:** Often unrealistic for high-return projects.
/// - **MIRR uses realistic rates:** Separate rates for financing and reinvestment.
/// - **MIRR is always unique:** Unlike IRR, which can have multiple solutions.
/// - **When rates are equal:** MIRR ≈ IRR
///
/// ## Use Cases
/// - Comparing projects with different cash flow patterns
/// - More realistic return estimates than IRR
/// - Corporate finance and capital budgeting decisions
public func mirr<T: Real>(
	cashFlows: [T],
	financeRate: T,
	reinvestmentRate: T
) throws -> T {
	// Validate input
	guard cashFlows.count >= 2 else {
		throw IRRError.insufficientData
	}

	let n = cashFlows.count - 1  // Number of periods (excluding t=0)

	// Separate positive and negative cash flows
	var pvNegative = T.zero
	var fvPositive = T.zero

	for (period, cashFlow) in cashFlows.enumerated() {
		if cashFlow < T.zero {
			// Negative cash flow: discount to present value
			let pv = cashFlow / T.pow(T(1) + financeRate, T(period))
			pvNegative = pvNegative + pv
		} else if cashFlow > T.zero {
			// Positive cash flow: compound to future value
			let periodsToEnd = n - period
			let fv = cashFlow * T.pow(T(1) + reinvestmentRate, T(periodsToEnd))
			fvPositive = fvPositive + fv
		}
	}

	// Calculate MIRR
	// MIRR = (FV_positive / -PV_negative)^(1/n) - 1
	guard pvNegative < T.zero && fvPositive > T.zero else {
		throw IRRError.invalidCashFlows
	}

	let ratio = fvPositive / (-pvNegative)
	let exponent = T(1) / T(n)
	let mirr = T.pow(ratio, exponent) - T(1)

	return mirr
}

// MARK: - Helper Functions

/// Calculates Net Present Value at a given discount rate.
private func calculateNPV<T: Real>(cashFlows: [T], rate: T) -> T {
	var npv = T.zero

	for (period, cashFlow) in cashFlows.enumerated() {
		let discountFactor = T.pow(T(1) + rate, T(period))
		npv = npv + cashFlow / discountFactor
	}

	return npv
}

/// Calculates the derivative of NPV with respect to the discount rate.
///
/// This is used in the Newton-Raphson method:
/// ```
/// dNPV/dr = -Σ(t × CF_t / (1+r)^(t+1))
/// ```
private func calculateNPVDerivative<T: Real>(cashFlows: [T], rate: T) -> T {
	var derivative = T.zero

	for (period, cashFlow) in cashFlows.enumerated() {
		if period > 0 {  // Skip period 0 (derivative term is 0)
			let numerator = T(period) * cashFlow
			let denominator = T.pow(T(1) + rate, T(period + 1))
			derivative = derivative - numerator / denominator
		}
	}

	return derivative
}
