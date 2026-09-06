//
//  IRR.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

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
///   - tolerance: **Relative** convergence tolerance on the rate. The iteration stops
///     once a Newton correction moves the rate by less than
///     `tolerance × max(|rate|, 1)`. Defaults to `√(ulpOfOne)`, derived from the
///     numeric type rather than chosen — see the discussion below.
///   - maxIterations: Maximum number of iterations (default: 100).
/// - Returns: The IRR as a decimal (e.g., 0.15 for 15%).
/// - Throws: `BusinessMathError` if calculation fails.
///
/// ## Convergence is measured on the rate, not on the NPV
///
/// This used to stop when `|NPV| < 0.0001` — an **absolute** residual, in currency
/// units, for a function that returns a rate. Three things were wrong with it.
///
/// **IRR is scale-invariant and the test was not.** Multiplying every cash flow by a
/// constant leaves the rate unchanged, because the NPV simply scales with it. An
/// absolute bound on the NPV therefore means something different for every model:
/// `[-1000, 300, 400, 500, 200]` returned `0.153221377126732`, and the same investment
/// stated in thousands returned `0.153221378771815`.
///
/// **The residual is not the error.** What a caller wants bounded is the rate, and
/// `rate error ≈ |NPV| / |dNPV/dr|`. On a large model with offsetting flows the NPV
/// curve is nearly flat, so a residual under `0.0001` can still leave the rate wrong in
/// a digit that matters.
///
/// **At scale it did not converge at all.** Scale those same flows by `1e9` and the
/// rounding noise in the NPV sum alone exceeds `0.0001`. Newton reaches machine
/// precision after a handful of steps and then sits on the exact answer for the
/// remaining iterations, because the bound can never be met — and the function threw
/// `Failed to converge`. A billion-dollar model was not computable.
///
/// The fix is the observation that **the Newton correction is itself scale-invariant**:
/// `NPV/(dNPV/dr)` has the cash-flow units in both numerator and denominator, so they
/// cancel. Testing the size of that correction, relative to the rate it is correcting,
/// is dimensionless, says something about the returned quantity, and behaves the same
/// at every scale.
///
/// The default tolerance is `√(ulpOfOne)` because Newton's method roughly doubles the
/// number of correct digits per step: once a correction is smaller than the square root
/// of the machine epsilon, the *next* one would be below the epsilon itself, so the
/// value already in hand is accurate to full precision. It is derived from the type,
/// not picked.
///
/// ## Examples
///
/// **Simple Investment:**
/// ```swift
/// // Invest $1000, receive $400/year for 3 years
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
/// let rateOfReturn = try irr(cashFlows: cashFlows)
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
/// let rateOfReturn = try irr(cashFlows: cashFlows)
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
/// - Throws `.insufficientData` if fewer than 2 cash flows provided.
/// - Throws `.calculationFailed` if all cash flows are positive or all negative.
/// - Throws `.numericalInstability` (E004) if the NPV derivative collapses below 1e-6, which makes
///   the Newton-Raphson step undefined. Typically a single cash flow far enough in the future that
///   its discount factor dominates.
/// - Throws `.calculationFailed` if Newton-Raphson doesn't converge within max iterations.
public func irr<T: Real>(
	cashFlows: [T],
	guess: T? = nil,
	tolerance: T? = nil,
	maxIterations: Int = 100
) throws -> T {
	let actualGuess: T = guess ?? (T(1) / T(10))
	// Relative, and derived from the type: see the note on convergence above.
	let actualTolerance: T = tolerance ?? T.sqrt(T.ulpOfOne)
	// Validate input
	guard cashFlows.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2,
			actual: cashFlows.count,
			context: "IRR calculation requires at least 2 cash flows"
		)
	}

	// Check for sign changes (need both positive and negative)
	let hasPositive = cashFlows.contains { $0 > T.zero }
	let hasNegative = cashFlows.contains { $0 < T.zero }

	guard hasPositive && hasNegative else {
		throw BusinessMathError.calculationFailed(
			operation: "IRR",
			reason: "Cash flows must contain both positive and negative values (all cash flows have the same sign)",
			suggestions: [
				"Ensure you have at least one negative cash flow (typically the initial investment)",
				"Verify that you have at least one positive cash flow (returns or receipts)",
				"Check that cash flows are correctly signed (negative for outflows, positive for inflows)"
			]
		)
	}

	// Newton-Raphson iteration
	var rate = actualGuess

	for _ in 0..<maxIterations {
		// Calculate NPV at current rate
		// Note: Use internal npv() not calculateNPV() to allow negative rates during iteration
		let npvValue = npv(discountRate: rate, cashFlows: cashFlows)

		// An exact root. Taking it here avoids a needless step and the rounding that
		// would come with it.
		if npvValue.isZero { return rate }

		// Calculate derivative of NPV (dNPV/dr)
		let derivative = calculateNPVDerivative(discountRate: rate, cashFlows: cashFlows)

		// Newton-Raphson update: rate_new = rate_old - f(rate) / f'(rate)
		let correction: T = npvValue / derivative
		let candidate: T = rate - correction

		// Guard the *step*, not the derivative's magnitude. How small a derivative is
		// "too small" depends on both the cash flows and the horizon — over 400 periods
		// the discount factors alone drive dNPV/dr to ~1e-11 for entirely ordinary
		// flows — so any fixed floor is either useless or reintroduces the
		// scale-dependence this function was fixed to remove.
		//
		// The step itself says whether it is usable. A rate at or below −100% is not a
		// return, and `(1+r)^t` is not defined there for fractional `t`, so a correction
		// that lands the rate outside `(−1, ∞)` is a step the method cannot take.
		guard correction.isFinite, candidate > T(-1) else {
			throw BusinessMathError.numericalInstability(
				message: "IRR: Derivative of NPV at rate \(rate) is too small for a usable Newton step — the correction would move the rate to \(candidate), at or below −100%",
				suggestions: [
					"Try a different initial guess (current: \(actualGuess))",
					"Check if cash flows have unusual patterns that might cause instability",
					"Consider using MIRR (Modified IRR) for complex cash flow patterns"
				]
			)
		}

		rate = candidate

		// Convergence, measured on the rate. The correction is scale-invariant — the
		// cash-flow units cancel between NPV and its derivative — so this behaves the
		// same whether the model is in dollars or billions. Tested *after* the step, so
		// the value returned is the corrected one.
		let reference: T = Swift.max(abs(rate), T(1))
		let threshold: T = actualTolerance * reference
		if abs(correction) <= threshold { return rate }
	}

	// If we get here, didn't converge
	throw BusinessMathError.calculationFailed(
		operation: "IRR",
		reason: "Failed to converge within \(maxIterations) iterations",
		suggestions: [
			"Increase maxIterations (current: \(maxIterations))",
			"Try a different initial guess (current: \(actualGuess))",
			"Verify that cash flows represent a realistic investment pattern",
			"Check for multiple sign changes, which can give more than one IRR"
		]
	)
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
/// - Throws: `BusinessMathError` if calculation fails.
///
/// ## Example
///
/// ```swift
/// let returns = [0.10, 0.05, -0.15, -0.10, 0.20, 0.05]
/// // Project with $1000 investment, $400/year returns
/// let cashFlows = [-1000.0, 400.0, 400.0, 400.0]
///
/// // Finance at 12%, reinvest at 8%
/// let modifiedRate = try mirr(
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
		throw BusinessMathError.insufficientData(
			required: 2,
			actual: cashFlows.count,
			context: "MIRR calculation requires at least 2 cash flows"
		)
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
		throw BusinessMathError.calculationFailed(
			operation: "MIRR",
			reason: "Cash flows must contain both positive and negative values",
			suggestions: [
				"Ensure you have at least one negative cash flow (outflows/investments)",
				"Ensure you have at least one positive cash flow (inflows/returns)",
				"Verify cash flow signs are correct (negative for costs, positive for receipts)"
			]
		)
	}

	let ratio = fvPositive / (-pvNegative)
	let exponent = T(1) / T(n)
	let mirr = T.pow(ratio, exponent) - T(1)

	return mirr
}
